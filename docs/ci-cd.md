# CI/CD

Two workflows:

| Workflow | Trigger | AWS | Purpose |
|---|---|---|---|
| `ci.yml` | every PR, pushes to `development` / `main` | no | lint, tests, build + verify `lambda.zip` |
| `deploy.yml` | push to `development` / `main`, manual dispatch | yes | build once → staging → approval → production → semantic-release |

## Split of responsibilities

Infrastructure is managed by **Pulumi, locally only** (`infra/`). CI never runs
Pulumi and never needs Pulumi credentials. CI only ships code to functions that
already exist:

```
CI:   build zip → s3://$ARTIFACT_BUCKET/lambda/<sha>.zip → aws lambda update-function-code
You:  pulumi up   (when infra changes: memory, timeout, env vars, routes, IAM…)
```

Setup order and stack-by-stack details live in [`infra/README.md`](../infra/README.md).

Consequence worth remembering: **a change to Lambda configuration is not deployed by
CI.** If you edit `infra/`, you must run `pulumi up` yourself for staging and prod.
CI will happily redeploy the previous configuration with new code on top of it.

## Flow

```
push development ──► build ──► deploy staging ──► smoke test $API_URL_STAGING
                                                      │
                                    (merge PR to main)
                                                      ▼
push main ─────────► build ──► [production approval] ──► deploy prod ──► smoke test $API_URL_PROD
                                                                    └──► semantic-release (tag + CHANGELOG)
```

`deploy.yml` also has `workflow_dispatch`, so you can redeploy or promote a specific
`ref` without merging:

```bash
# re-deploy staging from a branch
gh workflow run deploy.yml -f environment=staging -f ref=development

# promote the exact bytes staging deployed: no rebuild at all
gh workflow run deploy.yml -f environment=production \
  -f artifact_key=lambda/<sha256>.zip      # key from the staging run summary
```

## Artifacts are content-addressed

The build uploads `lambda-<sha>` to GitHub Artifacts, then the deploy job copies it
to `s3://$ARTIFACT_BUCKET/lambda/<sha256>.zip` — the key is the **hash of the zip**,
not the commit sha. Consequences:

- Identical code always resolves to the same object, so a merge to `main` that
  rebuilds the same bytes deploys the object staging already validated instead of
  a look-alike (`publish artifact` reports `Reusing … already exists`).
- Objects are immutable in practice: a key can never mean two different things, so
  the prod job re-hashes the S3 object and fails if it disagrees with its name.
- Passing `artifact_key` to `workflow_dispatch` skips the build entirely — that is
the literal "promote what staging tested" path.

S3 is the durable copy (and your rollback source). The GitHub artifact is only a
hand-off between `build` and the deploy jobs and disappears after 30 days.

## One-time repository setup

### 1. Environments — names must match exactly

`deploy.yml` references `staging` and `production` (lowercase). GitHub environment
names are **case-sensitive**: an environment named `Staging` will not match, and the
job would run without any protection rules.

- `staging` — no protection rules needed.
- `production` — add yourself under **Required reviewers**. That reviewer prompt is
  the approval gate between staging and prod.
  - If you work alone, do **not** enable *Prevent self-review*, or nobody can approve.

Keep the prod AWS keys as **environment** secrets on `production` if you want them
unreachable before approval; repo-level secrets are readable by any job that
references them.

### 2. Repository variables (Settings → Secrets and variables → Actions → Variables)

| Variable | Example | Notes |
|---|---|---|
| `AWS_REGION` | `ap-southeast-1` | |
| `ARTIFACT_BUCKET` | `hello-world-api-artifacts` | created by `infra/` |
| `LAMBDA_STAGING` | `hello-world-api-staging` | function name from `infra/` |
| `LAMBDA_PROD` | `hello-world-api-prod` | function name from `infra/` |
| `API_URL_STAGING` | `https://abc123.execute-api.ap-southeast-1.amazonaws.com/dev` | base URL, no trailing path |
| `API_URL_PROD` | `https://def456.execute-api.ap-southeast-1.amazonaws.com/api` | base URL |
| `LAMBDA_ALIAS_STAGING` | `live` (optional) | if set, publishes a version and moves the alias instead of updating `$LATEST` |
| `LAMBDA_ALIAS_PROD` | `live` (optional) | same for prod |

If you set an alias, the API Gateway integration in `infra/` must point at the alias
ARN (`…:function:NAME:live`), otherwise traffic keeps hitting `$LATEST`.

### 3. Repository secrets

| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID_STAGING` / `AWS_SECRET_ACCESS_KEY_STAGING` | uploads artifact, updates staging function |
| `AWS_ACCESS_KEY_ID_PROD` / `AWS_SECRET_ACCESS_KEY_PROD` | same for prod |
| `RELEASE_TOKEN` | PAT or GitHub App token with `contents: write`; must be able to push to `main` past branch protection |

The staging key never touches prod and vice versa. Minimum IAM policy per key:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["s3:PutObject"], "Resource": "arn:aws:s3:::ARTIFACT_BUCKET/lambda/*" },
    { "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode", "lambda:GetFunction",
        "lambda:GetFunctionConfiguration", "lambda:PublishVersion",
        "lambda:UpdateAlias", "lambda:GetAlias"
      ],
      "Resource": "arn:aws:lambda:REGION:ACCOUNT:function:FUNCTION_NAME*" }
  ]
}
```

Static keys do not expire. If you later want to drop them, `infra/` can create a
GitHub OIDC provider and one role per environment; the only change here is swapping
`configure-aws-credentials` inputs for `role-to-assume` and adding
`permissions: id-token: write` to each deploy job.

## Release behaviour

`release` runs only after `deploy-prod` succeeded, and only for merges to `main`.
A manual promotion of an older SHA deploys but does not tag: that commit is not the
head of `main`, so the release commit could not fast-forward.

1. `semantic-release version --print` — decide the next version. It prints the
   *current* version when nothing is releasable, so the job compares it to
   `uv version --short` and skips the rest on equality.
2. `semantic-release version --no-commit --no-tag --no-push` — rewrite
   `project.version` in `pyproject.toml` and prepend `CHANGELOG.md`.
3. `uv lock` — keep `uv.lock` in sync (PSR does not commit build side effects).
4. One commit `chore(release): X.Y.Z`, one annotated tag `vX.Y.Z`, pushed to `main`.
5. `semantic-release publish` — GitHub release for that tag.

A single commit is used deliberately: PSR's own commit/tag does not include the
refreshed `uv.lock`, which would leave `main` dirty and break `uv sync --frozen`.

The `preflight` job skips the whole pipeline when the head commit starts with
`chore(release):`, so the release push does not redeploy production.

Version semantics: `allow_zero_version = true`, so while on `0.x` a `feat` gives
`0.Y.0` and a `fix` gives `0.Y.Z`. A `BREAKING CHANGE:` footer still goes to `1.0.0`.

## Rollback

- Every deployed zip is kept in `s3://$ARTIFACT_BUCKET/lambda/<sha256>.zip` (find the
  key of an older build in that run's summary, or `aws s3 ls s3://$ARTIFACT_BUCKET/lambda/`).
- With `LAMBDA_ALIAS_*` set: `aws lambda update-alias --function-name … --name live --function-version <old>`.
- Without an alias: `aws lambda update-function-code --function-name … --s3-bucket … --s3-key lambda/<sha256>.zip`.
- Or re-run the workflow with `-f artifact_key=lambda/<sha256>.zip`, which goes through
  the same integrity check as a normal deploy.
- Add a lifecycle rule on the bucket in `infra/` if you don't want it to grow forever;
  keep at least a few generations or rollback loses its targets.

## Reproducing CI locally

```bash
uv sync --frozen --group dev
uv run ruff check . && uv run ruff format --check .
uv run pytest -q
./scripts/build_lambda.sh
```

The Lambda runtime is defined once in `.python-version`, which `uv`, the build
script and both workflows read. Changing it requires re-resolving the lockfile
(`uv lock`) because `uv.lock` pins wheels per Python version.

## Before the first deploy works

1. `infra/` applied locally for both stacks → artifact bucket, two functions, two APIs.
2. Fill in the six required repo variables and the four AWS secrets.
3. Push to `development`.

Until then `deploy.yml` skips itself with a notice rather than failing.
