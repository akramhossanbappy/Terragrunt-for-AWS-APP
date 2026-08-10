variable "secure_subnets" {}
variable "secure_sg_id" {}
variable "project" {}
variable "environment" {}
variable "aws_region" {}
variable "tier" {}
variable "os_db_user" {}
variable "os_db_password" {
  sensitive = true
}

variable "opensearch_instance_type" {}
variable "opensearch_instance_count" {
  description = "Number of data nodes in the OpenSearch cluster."
  type        = number
  default     = 1
}
variable "opensearch_volume_size" {}
variable "opensearch_volume_type" {}

variable "opensearch_dedicated_master_enabled" {
  description = "Whether to enable dedicated master nodes."
  type        = bool
  default     = false
}
variable "opensearch_dedicated_master_type" {
  description = "Instance type for dedicated master nodes."
  type        = string
  default     = ""
}
variable "opensearch_dedicated_master_count" {
  description = "Number of dedicated master nodes. Must be 3 or 5."
  type        = number
  default     = 3
}

variable "opensearch_zone_awareness_enabled" {
  description = "Enable multi-AZ zone awareness."
  type        = bool
  default     = false
}
variable "opensearch_availability_zone_count" {
  description = "Number of AZs for zone awareness. Must be 2 or 3; instance_count must be a multiple of this value."
  type        = number
  default     = 2
}