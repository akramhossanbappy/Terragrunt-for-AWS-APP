# Common
variable "project" {}
variable "environment" {}
variable "tier" {}
variable "aws_region" {}

# OpenSearch
variable "domain_name" {
  description = "OpenSearch domain name. Used as CloudWatch DomainName dimension and as the base for all resource names."
  type        = string
}

variable "cpu_threshold" {
  description = "Alarm threshold for data node CPUUtilization (%). Sustained above 80% degrades search/indexing."
  type        = number
  default     = 80
}

variable "master_cpu_threshold" {
  description = "Alarm threshold for dedicated master CPUUtilization (%). Masters above 50% may impact cluster stability."
  type        = number
  default     = 50
}

variable "jvm_threshold" {
  description = "Alarm threshold for JVMMemoryPressure (%). Sustained above 85% triggers GC pauses that stall requests."
  type        = number
  default     = 85
}

variable "free_storage_threshold_mb" {
  description = "Alarm threshold for FreeStorageSpace (MB, total across all data nodes). Default 204800 = 200 GB (~8% of 4×600 GB)."
  type        = number
  default     = 204800
}

variable "search_latency_threshold_ms" {
  description = "Alarm threshold for SearchLatency p99 (milliseconds)."
  type        = number
  default     = 500
}

variable "indexing_latency_threshold_ms" {
  description = "Alarm threshold for IndexingLatency p99 (milliseconds)."
  type        = number
  default     = 500
}

variable "write_queue_threshold" {
  description = "Alarm threshold for ThreadpoolWriteQueue (pending write requests). A growing queue means write throughput is falling behind ingestion."
  type        = number
  default     = 100
}

# Notifications
variable "gchat_webhook_url" {
  description = "Google Chat webhook URL. Alarms are delivered via SNS → Lambda → POST to this URL."
  type        = string
  sensitive   = true
}
