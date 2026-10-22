# Infrastructure

Terraform, applied **from a workstation only**. CI never runs Terraform; it only
uploads a zip and calls `aws lambda update-function-code`.

```
bootstrap/            state bucket, artifact bucket, deploy IAM users (local state)
modules/app/          one Lambda + one HTTP API + IAM + log groups
envs/staging/         stage_name = "dev"  ->  https://<id>.execute-api.<region>.amazonaws.com/dev/
envs/prod/            stage_name = "api"  ->  https://<id>.execute-api.<region>.amazonaws.com/api/
```

Two separate HTTP APIs, not one API with two stages: routes and integrations are
API-scoped, so stages of a single API cannot point at different functions.

## 1. Bootstrap (once)

```bash
cd infra/bootstrap
terraform init
terraform apply
terraform output -json deploy_secret_access_keys
```

It keeps **local** state (`terraform.tfstate`, gitignored) because it creates the
bucket that holds every other stack's state. Do not lose it: it owns the only copy
of the CI access keys. `terraform output` is how you retrieve them after the fact.

Copy into GitHub:

| Output | Destination |
|---|---|
| `artifact_bucket` | variable `ARTIFACT_BUCKET` |
| `region` | variable `AWS_REGION` |
| `deploy_access_key_ids["staging"]` / `deploy_secret_access_keys["staging"]` | secrets `AWS_ACCESS_KEY_ID_STAGING` / `AWS_SECRET_ACCESS_KEY_STAGING` |
| same for `prod` | `AWS_ACCESS_KEY_ID_PROD` / `AWS_SECRET_ACCESS_KEY_PROD` |

Each user's policy only reaches its own function ARN, so the staging key cannot
touch prod.

## 2. Environments

```bash
cd infra/envs/staging && terraform init && terraform plan && terraform apply
terraform output api_url      # -> API_URL_STAGING
terraform output function_name # -> LAMBDA_STAGING

cd infra/envs/prod && terraform init && terraform plan && terraform apply
```

Then set `API_URL_*` and `LAMBDA_*` and push to `development`.

## 3. Destroy (reverse order)

Three applies means three destroys, in the opposite direction:

```bash
cd infra/envs/prod    && terraform destroy
cd infra/envs/staging && terraform destroy
cd infra/bootstrap    && terraform destroy
```

Every stack is destroyable as committed: both buckets carry `force_destroy`, so
object versions and CI-uploaded zips go with them, and nothing is left in the
account. No manual console cleanup, no pre-editing of `.tf` files.

Staging and prod keep their state **inside** the bucket bootstrap creates. Destroy
bootstrap first and the other two lose their remote state: the next `init` starts
from empty and the functions and APIs they created are orphaned, with nothing left
to destroy them with. Environments go down before bootstrap, always.

Config, not just resources, has to go too — the bootstrap stack is what mints the
CI credentials:

- `terraform destroy` in `infra/bootstrap` revokes the deploy access keys, so
  `AWS_ACCESS_KEY_ID_*` goes dead and CI uploads start failing with
  `InvalidAccessKeyId`. Re-applying bootstrap mints new keys: re-copy all four
  GitHub secrets.
- `API_URL_*` and `LAMBDA_*` point at resources that no longer exist; clear them
  or leave them for the next apply to overwrite.

Locally, `terraform destroy` leaves the (now empty) state files, `.terraform/`
provider caches and `bootstrap/.bootstrap/placeholder.zip` behind. Run
`terraform state list` in each directory to confirm it is empty; delete
`terraform.tfstate*`, the state backups and `.terraform/` if you want the checkout
clean as well. Those files are gitignored, so nothing leaks into a commit either
way.

## Current state: Terraform ships the code

For the first end-to-end test the module uses the local build directly:

```hcl
filename         = var.source_zip                 # ../../../dist/lambda.zip
source_code_hash = filebase64sha256(var.source_zip)
```

so `terraform apply` in `envs/staging` and `envs/prod` deploys the same zip to both
functions. Build before planning:

```bash
./scripts/build_lambda.sh      # dist/ is gitignored, so a fresh clone must build first
```

**Before CI deploys for real, restore single ownership** — otherwise the next
`terraform apply` reverts whatever CI shipped:

```hcl
  s3_bucket = var.artifact_bucket
  s3_key    = "bootstrap/placeholder.zip"

  lifecycle {
    ignore_changes = [s3_bucket, s3_key, s3_object_version, filename, source_code_hash]
  }
```

With that block, Terraform creates the function from `bootstrap/placeholder.zip`
(HTTP 503 until the first CI run) and never touches code again. It also means
`terraform apply` will not report code drift — `aws lambda get-function` is the only
way to see what is actually running.

Also note `prevent_destroy` on the state bucket, and that `terraform destroy` in
`envs/prod` deletes the prod function and API while leaving the artifacts intact.

## Verify before the first apply

- `python3.14` must be an available Lambda runtime in the target region; a plan
  will not catch an unsupported runtime, only the apply will.
- `architecture = "x86_64"` must match `--python-platform x86_64-manylinux2014`
  in `scripts/build_lambda.sh`. Switching to `arm64` means changing both.
