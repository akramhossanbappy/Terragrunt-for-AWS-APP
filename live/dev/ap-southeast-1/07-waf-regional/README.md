# 07-waf-regional — regional WAF + monitoring

Provisions the dev REGIONAL-scope WAF stack, wrapped by
`modules/waf-regional`:

- `waf` — REGIONAL WAFv2 web ACL (scope=`REGIONAL`, region=`ap-southeast-1`),
  associated with the API ALB via `waf_alb_arn`.
- `waf-alb-monitoring` — CloudWatch alarms on the WAF's own CloudWatch
  metrics, delivered to Google Chat via a Lambda.

This unit's `waf` instance is the `waf-alb` composer-module call (matching
the resource addresses used in the pre-Terragrunt root config so state
moves cleanly). Its `waf-alb-monitoring` alarm rule-name suffixes are
hand-coupled to the WAF's rule config — keep both in sync by hand when
adding/removing rules.

## WAF in dev

Dev's `waf_regional_enabled = false` (set in
`dev/terragrunt.hcl`'s `settings = merge(...)`), so this unit does
nothing in dev today. The unit directory exists so the production-shaped
layout can be exercised end-to-end without WAF traffic hitting the dev
ALB.

## Run

```bash
cd projects/live/dev/ap-southeast-1/07-waf-regional
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — dev/ap-southeast-1 region overview.
- [`../../../../CLAUDE.md`](../../../../CLAUDE.md) — WAF observe-vs-block
  rule, alarm rule-name coupling.