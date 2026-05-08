# DynamoDB Table: Photos
# Stores photo metadata and workflow state
resource "aws_dynamodb_table" "photos" {
  name           = "${local.namespace}-photos"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "photo_id"
  
  attribute {
    name = "photo_id"
    type = "S"
  }

  attribute {
    name = "current_state"
    type = "S"
  }

  # GSI for querying by current_state
  global_secondary_index {
    name            = "current_state-index"
    hash_key        = "current_state"
    projection_type = "ALL"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [billing_mode]
  }
}

# DynamoDB Table: PhotoReviews
# Immutable review event log
resource "aws_dynamodb_table" "photo_reviews" {
  name           = "${local.namespace}-photo-reviews"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "review_id"
  
  attribute {
    name = "review_id"
    type = "S"
  }

  attribute {
    name = "photo_id"
    type = "S"
  }

  attribute {
    name = "reviewer_user_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  # GSI for querying by photo_id
  global_secondary_index {
    name            = "photo_id-created_at-index"
    hash_key        = "photo_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # GSI for querying by reviewer_user_id
  global_secondary_index {
    name            = "reviewer_user_id-created_at-index"
    hash_key        = "reviewer_user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  tags = local.common_tags
}

# DynamoDB Table: PhotoActionLog
# Audit trail for all photo actions (review, rotate, finalize)
resource "aws_dynamodb_table" "photo_action_log" {
  name           = "${local.namespace}-photo-action-log"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "action_id"
  
  attribute {
    name = "action_id"
    type = "S"
  }

  attribute {
    name = "photo_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  # GSI for querying by photo_id (access patterns: get action history for a photo)
  global_secondary_index {
    name            = "photo_id-created_at-index"
    hash_key        = "photo_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # GSI for querying by user_id (access patterns: get user's actions)
  global_secondary_index {
    name            = "user_id-created_at-index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  tags = local.common_tags
}

# KMS Key for DynamoDB encryption
resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for DynamoDB encryption in ${local.namespace}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${local.namespace}-dynamodb"
  target_key_id = aws_kms_key.dynamodb.key_id
}

# CloudWatch alarms for DynamoDB
resource "aws_cloudwatch_metric_alarm" "photo_reviews_throttle" {
  alarm_name          = "${local.namespace}-photo-reviews-throttle"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ConsumedWriteCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "80"
  alarm_description   = "Alert when photo_reviews table approaches provisioned capacity"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.photo_reviews.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "photos_large_scan" {
  alarm_name          = "${local.namespace}-photos-large-scan"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ScannedItemCount"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10000"
  alarm_description   = "Alert on large table scans"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.photos.name
  }

  tags = local.common_tags
}
