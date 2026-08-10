# 02-cluster — EKS + Kubernetes add-ons

Provisions the dev EKS cluster and the `kubernetes` module's add-ons
(ALB ingress controller IAM, FluxCD, IRSA, EKS access entries), wrapped
by the `modules/cluster` composer.

`kubernetes` directly consumes `eks`'s cluster outputs — keeping them in
the same composer module means they're always changed together (and they
share a single Terraform plan/apply).

## Dependencies

`dependency "networking"` pulls from `../01-networking`:

- `vpc_id`
- `aws_subnets_private`
- `secure_sg_id`, `alb_sg_id`, `cms_sg_id`

`mock_outputs` are configured for `validate` / `plan` so this unit can
be planned before `01-networking` has been applied.

## Inputs

See `terragrunt.hcl`. Dev-specific knobs:

- `fargate_profile` — namespaces that run on Fargate
  (`["kube-system", "dev", "flux-system"]` for dev).
- `eks_iam_user` — IAM users with cluster access
  (`["dev-user@example.com"]` for dev).

## Known issues

- `modules/cluster/main.tf` references `../kubernetes` as a sibling
  module directory. That symlink is currently broken in this checkout,
  so `terragrunt validate` fails with `Unreadable module directory`
  until the symlink is fixed. Tracked separately, out of scope here.

## Run

```bash
cd projects/live/dev/ap-southeast-1/02-cluster
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — dev/ap-southeast-1 region overview.