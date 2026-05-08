# KMS Key for S3 encryption
resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 encryption in ${local.namespace}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${local.namespace}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# S3 Bucket for Frontend Assets
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.namespace}-frontend-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.s3_lifecycle_retention_days
    }
  }
}

# S3 Bucket for Photo Files
resource "aws_s3_bucket" "photos" {
  bucket = "${local.namespace}-photos-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "photos" {
  bucket = aws_s3_bucket.photos.id

  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "photos" {
  bucket = aws_s3_bucket.photos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "photos" {
  bucket = aws_s3_bucket.photos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "photos" {
  bucket = aws_s3_bucket.photos.id

  rule {
    id     = "intelligent-tiering"
    status = "Enabled"
    filter {}

    transition {
      days          = 90
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.s3_lifecycle_retention_days
    }
  }
}

# Enable server access logging for photos bucket
resource "aws_s3_bucket_logging" "photos" {
  bucket = aws_s3_bucket.photos.id

  target_bucket = aws_s3_bucket.photos_logs.id
  target_prefix = "photos-access-logs/"
}

# S3 Bucket for Photo Logs
resource "aws_s3_bucket" "photos_logs" {
  bucket = "${local.namespace}-photos-logs-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "photos_logs" {
  bucket = aws_s3_bucket.photos_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "photos_logs" {
  bucket = aws_s3_bucket.photos_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle for log cleanup
resource "aws_s3_bucket_lifecycle_configuration" "photos_logs" {
  bucket = aws_s3_bucket.photos_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = 90
    }
  }
}

# S3 Bucket for Thumbnails (optional)
resource "aws_s3_bucket" "thumbnails" {
  bucket = "${local.namespace}-thumbnails-${data.aws_caller_identity.current.account_id}"

  tags = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  rule {
    id     = "delete-old-thumbnails"
    status = "Enabled"
    filter {}

    expiration {
      days = 180
    }
  }
}

# CloudWatch alarm for large S3 uploads
resource "aws_cloudwatch_metric_alarm" "s3_large_uploads" {
  alarm_name          = "${local.namespace}-s3-large-uploads"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = "86400"
  statistic           = "Average"
  threshold           = "10000"
  alarm_description   = "Alert when photo bucket contains many objects"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = aws_s3_bucket.photos.id
    StorageType = "AllStorageTypes"
  }

  tags = local.common_tags
}
