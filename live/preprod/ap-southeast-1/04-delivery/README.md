# 04-delivery — ECR + per-microservice CodePipelines

Provisions the dev per-microservice CI/CD stack, wrapped by
`modules/delivery`:

- `ecr` — one ECR repo per `ms_name` entry.
- `cicd` — one CodePipeline per `github_repository` entry, paired 1:1
  with the ECR repo. Each pipeline builds and pushes a Docker image to
  its repo, then deploys. The composer creates parallel stages for both
  `environment` ("prod") and `cls_environment` ("preprod") from the
  same `inputs` block.
- Lambda + SNS + EventBridge notification path (build failures, ECR
  pushes) to Google Chat via `modules/cicd/index.js`.

This unit is **not** what deploys this Terraform/Terragrunt repo — that
pipeline is bootstrapped separately by `cicd-terraform (apply-from-local)/`
at the true repo root (see `../../../../CLAUDE.md`).

## Secrets

`docker_password` is **not** in this unit's `inputs = {}` block —
injected as `TF_VAR_docker_password` env var at apply time from Secrets
Manager. Don't add a real value here.

## Known issues

- `modules/delivery/main.tf` has an `import` block adopting the
  pre-existing CI/CD pipeline log S3 bucket into
  `module.cicd.aws_s3_bucket.s3-bucket-backend`. The fix for an
  `AlreadyExists` error on that resource is usually adjusting this
  block, not `-replace`.
- `modules/cluster/main.tf` references `../kubernetes` as a sibling
  module directory. That symlink is currently broken in this checkout.

## Run

```bash
cd projects/live/dev/ap-southeast-1/04-delivery
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — dev/ap-southeast-1 region overview.