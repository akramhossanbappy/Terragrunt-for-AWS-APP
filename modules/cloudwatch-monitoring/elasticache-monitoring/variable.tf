# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# ElastiCache
variable "replication_group_id" {
  description = "ElastiCache replication group ID. Used as the base for resource names and as the CloudWatch alarm prefix."
  type        = string
}

variable "primary_cluster_ids" {
  description = "List of PRIMARY node CacheClusterIds (e.g. singleapp-fifa-prod-0001-001). Used for CPU, memory, evictions, and connection alarms. CloudWatch metric math is capped at 10 data queries — keep this list ≤ 9 entries. Verify IDs from AWS Console → ElastiCache → Nodes tab."
  type        = list(string)
  default     = []
}

variable "replica_cluster_ids" {
  description = "List of REPLICA node CacheClusterIds (e.g. singleapp-fifa-prod-0001-002). Used exclusively for the ReplicationLag alarm. Keep ≤ 9 entries (CloudWatch 10-query limit)."
  type        = list(string)
  default     = []
}

variable "cpu_threshold" {
  description = "Alarm threshold for EngineCPUUtilization MAX across primary nodes (%). Redis is single-threaded — high engine CPU signals saturation."
  type        = number
  default     = 70
}

variable "memory_threshold_pct" {
  description = "Alarm threshold for DatabaseMemoryUsagePercentage MAX across primary nodes (%). Above 80% risks evictions or OOM."
  type        = number
  default     = 80
}

variable "evictions_threshold" {
  description = "Alarm threshold for total Evictions SUM across primary nodes per 5-min period. Any sustained evictions indicate memory pressure."
  type        = number
  default     = 100
}

variable "connections_threshold" {
  description = "Alarm threshold for total CurrConnections SUM across primary nodes. A spike indicates a connection leak or pool misconfiguration."
  type        = number
  default     = 5000
}

variable "replication_lag_threshold_sec" {
  description = "Alarm threshold for ReplicationLag MAX across replica nodes (seconds). Replicas lagging > 5s indicate write pressure or a network issue."
  type        = number
  default     = 5
}

# Notifications
variable "gchat_webhook_url" {
  description = "Google Chat webhook URL. Alarms are delivered via SNS → Lambda → POST to this URL."
  type        = string
  sensitive   = true
}
