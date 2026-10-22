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

## Terraform owns the shape, CI owns the code

The function is created from `s3://<artifact bucket>/bootstrap/placeholder.zip`,
which returns HTTP 503 until the first deploy. `ignore_changes` on the code
attributes means:

- `terraform apply` will **not** roll back a CI deploy — and will not report code
  drift either. Comparing `aws lambda get-function` output is the only way to see it.
- To change code, use CI or `aws lambda update-function-code`, not Terraform.

Also note the buckets in `infra/bootstrap` are created with `force_destroy`, so
`terraform destroy` wipes them and their contents — remember that the state bucket
is the only place the other stacks' state lives.

## Verify before the first apply

- `python3.14` must be an available Lambda runtime in the target region; a plan
  will not catch an unsupported runtime, only the apply will.
- `architecture = "x86_64"` must match `--python-platform x86_64-manylinux2014`
  in `scripts/build_lambda.sh`. Switching to `arm64` means changing both.
