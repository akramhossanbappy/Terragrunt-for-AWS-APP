# 03-data — data services

Provisions the production data plane, wrapped by `modules/data`:

- `elasticache-cluster-01` — ElastiCache Redis replication group
  (private subnet tier).
- `efs` — EFS file system for shared cluster volumes.
- `opensearch` — OpenSearch domain for search/analytics
  (secure subnet tier — no internet route).
- `kibana-alb` — internal ALB fronting OpenSearch Dashboards (Kibana).

`modules/data/main.tf` adds an explicit `depends_on = [module.opensearch]`
on the `kibana-alb` module call to close a latent first-apply race the
old single-root config had.

## Dependencies

`dependency "networking"` pulls from `../01-networking`:

- `aws_subnets_secure`, `aws_subnets_private`, `aws_subnets_public`
- `secure_sg_id`, `efs_sg_id`, `kibana_alb_sg_id`

`mock_outputs` are configured for `validate` / `plan`.

## Secrets

`os_db_user` and `os_db_password` are **not** in this unit's
`inputs = {}` block — injected as `TF_VAR_*` env vars by the
`cicd-terraform (apply-from-local)` CodeBuild jobs, sourced from
Secrets Manager. Don't add real values for these here.

## Run

```bash
cd projects/live/production/ap-southeast-1/03-data
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — production/ap-southeast-1 region overview.
- [`../../../../CLAUDE.md`](../../../../CLAUDE.md) — repo-wide secrets handling.