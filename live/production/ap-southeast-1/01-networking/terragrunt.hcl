include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules/vpc"
}

inputs = {
  environment = "prod"
  project     = "tfdemo"
  tier        = "production"

  vpc_cidr                   = "10.0.0.0/16"
  public_subnets_cidr        = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  private_subnets_cidr       = ["10.0.64.0/19", "10.0.96.0/19", "10.0.128.0/19"]
  secure_subnets_cidr        = ["10.0.160.0/23", "10.0.162.0/23", "10.0.164.0/23"]
  availability_zones_public  = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  availability_zones_private = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  availability_zones_secure  = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  cidr_block-internet_gw     = "0.0.0.0/0"
  cidr_block-nat_gw          = "0.0.0.0/0"
}
