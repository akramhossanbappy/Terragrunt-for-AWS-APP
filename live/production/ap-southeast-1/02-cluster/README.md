# 02-cluster — EKS + Kubernetes add-ons

Provisions the production EKS cluster and the `kubernetes` module's
add-ons (ALB ingress controller IAM, FluxCD, IRSA, EKS access entries),
wrapped by the `modules/cluster` composer. Direct consumers of `eks`'s
cluster outputs are kept in the same composer so they're always changed
together.

## Dependencies

`dependency "networking"` pulls from `../01-networking`:

- `vpc_id`
- `aws_subnets_private`
- `secure_sg_id`, `alb_sg_id`, `cms_sg_id`

`mock_outputs` are configured for `validate` / `plan`.

## Known issues

- `modules/cluster/main.tf` references `../kubernetes` as a sibling
  module directory. That symlink is currently broken in this checkout,
  so `terragrunt validate` fails with `Unreadable module directory`
  until the symlink is fixed. Tracked separately, out of scope here.

## Run

```bash
cd projects/live/production/ap-southeast-1/02-cluster
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — production/ap-southeast-1 region overview.