# 07-waf-regional — regional WAF + monitoring

Provisions the production REGIONAL-scope WAF stack, wrapped by
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

## WAF mode

`waf_count_mode_only = true` (observe, don't block). Flipping to
enforcing mode is a deliberate separate change after 48–72h of watching
CloudWatch metrics, not something to bundle into an unrelated change.

## Run

```bash
cd projects/live/production/ap-southeast-1/07-waf-regional
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — production/ap-southeast-1 region overview.
- [`../../../../CLAUDE.md`](../../../../CLAUDE.md) — WAF observe-vs-block
  rule, alarm rule-name coupling.