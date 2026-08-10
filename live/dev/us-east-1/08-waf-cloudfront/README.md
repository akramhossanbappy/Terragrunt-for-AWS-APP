# 08-waf-cloudfront — CloudFront WAF + monitoring

Provisions the dev CLOUDFRONT-scope WAF stack, wrapped by
`modules/waf-cloudfront`:

- `waf` — CLOUDFRONT WAFv2 web ACL (scope=`CLOUDFRANT`, region=`us-east-1`).
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

## WAF in dev

Dev's `waf_cloudfront_enabled = false` (set in
`dev/terragrunt.hcl`'s `settings = merge(...)`), so this unit does
nothing in dev today. The unit directory exists so the production-shaped
layout can be exercised end-to-end without WAF traffic hitting dev
CloudFront.

## Why us-east-1

AWS only allows `AWS WAF` associations on CloudFront distributions from
WAF ACLs created in `us-east-1`. Even when the underlying distributions
sit in `ap-southeast-1`, the WAF ACL must be created here.

## Run

```bash
cd projects/live/dev/us-east-1/08-waf-cloudfront
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — dev/us-east-1 region overview.
- [`../../../../CLAUDE.md`](../../../../CLAUDE.md) — WAF observe-vs-block
  rule, alarm rule-name coupling.