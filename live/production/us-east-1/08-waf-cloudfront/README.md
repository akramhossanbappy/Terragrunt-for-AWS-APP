# 08-waf-cloudfront — CloudFront WAF + monitoring

Provisions the production CLOUDFRONT-scope WAF stack, wrapped by
`modules/waf-cloudfront`:

- `waf` — CLOUDFRONT WAFv2 web ACL (scope=`CLOUDFRONT`, region=`us-east-1`).
  Must live in `us-east-1` regardless of where the underlying
  CloudFront distributions themselves sit.
- `waf-cloudfront-monitoring` — CloudWatch alarms on the WAF's own
  CloudWatch metrics, delivered to Google Chat via a Lambda.

This unit's `waf` instance is the `waf-cloudfront` composer-module call
(matching the resource addresses used in the pre-Terragrunt root config).
Its `waf-cloudfront-monitoring` alarm rule-name suffixes are
hand-coupled to the WAF's rule config — keep both in sync by hand when
adding/removing rules.

`web_acl_arn` from this unit feeds `web_acl_id` on the CloudFront
distributions in `../ap-southeast-1/06-static-sites/` via that unit's
`dependency "waf-cloudfront"` block.

## WAF mode

`waf_count_mode_only = true` (observe, don't block). Flipping to
enforcing mode is a deliberate separate change after 48–72h of watching
CloudWatch metrics, not something to bundle into an unrelated change.

This unit's `inputs` block intentionally duplicates several values
(IP allow/block lists, managed-rule-group toggles, logging config) with
`../ap-southeast-1/07-waf-regional` — keep both in sync by hand when
changing these.

## Why us-east-1

AWS only allows `AWS WAF` associations on CloudFront distributions from
WAF ACLs created in `us-east-1`. Even when the underlying distributions
sit in `ap-southeast-1`, the WAF ACL must be created here.

## Run

```bash
cd projects/live/production/us-east-1/08-waf-cloudfront
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — production/us-east-1 region overview.
- [`../../../../CLAUDE.md`](../../../../CLAUDE.md) — WAF observe-vs-block
  rule, alarm rule-name coupling.