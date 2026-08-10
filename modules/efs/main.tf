resource "aws_efs_file_system" "elastic_file_system" {
  creation_token   = "${var.project}-efs-${var.environment}"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  protection {
    replication_overwrite = "ENABLED"
  }
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
    # transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }
  encrypted = true
  tags = {
    Name        = "${var.project}-efs-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_efs_backup_policy" "efa_backup_policy" {
  file_system_id = aws_efs_file_system.elastic_file_system.id
  backup_policy {
    status = "DISABLED"
  }
}

resource "aws_efs_access_point" "foo_access_point" {
  file_system_id = aws_efs_file_system.elastic_file_system.id

  root_directory {
    path = "/"
    creation_info {
      owner_uid   = "0"
      owner_gid   = "0"
      permissions = "0775"
    }
  }
  posix_user {
    uid            = 0
    gid            = 0
    secondary_gids = ["0"]
  }
  tags = {
    Name        = "${var.project}-efs-accesspoint-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_efs_mount_target" "efs_mount_target" {
  for_each        = toset(var.private_subnets)
  file_system_id  = aws_efs_file_system.elastic_file_system.id
  subnet_id       = each.key
  security_groups = ["${var.efs_sg}"]
}

