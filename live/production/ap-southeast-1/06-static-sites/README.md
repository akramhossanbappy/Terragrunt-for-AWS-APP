# 06-static-sites — S3 + CloudFront static sites

Provisions the production static-content hosting stack, wrapped by
`modules/static-sites`:

- `s3-static` — static site bucket.
- `s3-cloudfront-static` (instance named `s3-cloudfront-static`) —
  CloudFront distribution + S3 origin for the static site.
- `s3-cloudfront-static` (instance named `s3-cloudfront-deeplink`) —
  CloudFront distribution + S3 origin for the deeplink site.

Both CloudFront distributions are associated with the
`08-waf-cloudfront` unit's WAF ACL via `web_acl_id`.

## Dependencies

`dependency "waf-cloudfront"` pulls `web_acl_arn` from
`../../us-east-1/08-waf-cloudfront` (note the `us-east-1/` region — the
WAF ACL lives there regardless of where the distributions themselves
are). The `inputs` block maps that to `web_acl_id` for both CDN
instances.

`mock_outputs` are configured for `validate` / `plan`.

## Run

```bash
cd projects/live/production/ap-southeast-1/06-static-sites
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — production/ap-southeast-1 region overview.
- [`../../us-east-1/README.md`](../../us-east-1/README.md) — why the WAF
  ACL must live in `us-east-1`.