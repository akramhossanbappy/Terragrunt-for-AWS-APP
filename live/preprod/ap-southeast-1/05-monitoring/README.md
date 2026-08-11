# 05-monitoring — CloudWatch alarms

Provisions dev CloudWatch alarms for the data plane, wrapped by
`modules/monitoring`:

- `elasticache-monitoring` — alarms on the ElastiCache replication
  group's primary/replica nodes (6 shards split via CloudWatch
  metric-math to stay under the 10-query-per-alarm limit).
- `opensearch-monitoring` — alarms on the OpenSearch domain.

The composer takes resource identifiers as plain vars rather than
`dependency` outputs, with one deliberate exception: the
`elasticache_replication_group_id` input is wired via a
`dependency "data"` block to `data`'s
`elasticache_replication_group_id` output (instead of the old root's
manually-copied value).

Everything else in this unit (per-node primary/replica cluster IDs,
the OpenSearch domain name) is still a plain literal value in the
`inputs` block, same as before the Terragrunt migration. There is no
matching module output for those, and adding one was kept out of
scope for the migration.

## Dependencies

`dependency "data"` pulls `elasticache_replication_group_id` from
`../03-data`.

## Run

```bash
cd projects/live/dev/ap-southeast-1/05-monitoring
terragrunt init
terragrunt validate
terragrunt plan
terragrunt apply
```

## See also

- [`../README.md`](../README.md) — dev/ap-southeast-1 region overview.
- The 6-shard split is documented inline in `terragrunt.hcl` around
  `monitoring_redis_primary_cluster_ids`.