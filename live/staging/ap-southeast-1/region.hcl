locals {
  aws_region = "ap-southeast-1"

  availability_zones = [
    "ap-southeast-1a",
    "ap-southeast-1b",
    "ap-southeast-1c"
  ]

  region_tags = {
    Region = "ap-southeast-1"
  }
}