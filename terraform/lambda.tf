# This file will contain Lambda function definitions and integrations
# For now, we'll create placeholder Lambda functions that will be deployed

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.namespace}"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = local.common_tags
}

# Lambda function: Get Photos
resource "aws_lambda_function" "get_photos" {
  filename            = "placeholder.zip"
  function_name       = "${local.namespace}-get-photos"
  role                = aws_iam_role.lambda_role.arn
  handler             = "index.handler"
  runtime             = "python3.11"
  timeout             = var.lambda_timeout
  memory_size         = var.lambda_memory_size
  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      PHOTOS_TABLE        = aws_dynamodb_table.photos.name
      PHOTOS_REVIEWS_TABLE = aws_dynamodb_table.photo_reviews.name
      ENVIRONMENT         = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_dynamodb,
    aws_iam_role_policy.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]

  tags = local.common_tags
}

# Lambda function: Submit Review
resource "aws_lambda_function" "submit_review" {
  filename            = "placeholder.zip"
  function_name       = "${local.namespace}-submit-review"
  role                = aws_iam_role.lambda_role.arn
  handler             = "index.handler"
  runtime             = "python3.11"
  timeout             = var.lambda_timeout
  memory_size         = var.lambda_memory_size
  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      PHOTOS_TABLE         = aws_dynamodb_table.photos.name
      PHOTOS_REVIEWS_TABLE = aws_dynamodb_table.photo_reviews.name
      ACTION_LOG_TABLE     = aws_dynamodb_table.photo_action_log.name
      ENVIRONMENT          = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_dynamodb,
    aws_iam_role_policy.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]

  tags = local.common_tags
}

# Lambda function: Rotate Photo
resource "aws_lambda_function" "rotate_photo" {
  filename            = "placeholder.zip"
  function_name       = "${local.namespace}-rotate-photo"
  role                = aws_iam_role.lambda_role.arn
  handler             = "index.handler"
  runtime             = "python3.11"
  timeout             = var.lambda_timeout
  memory_size         = var.lambda_memory_size
  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      PHOTOS_TABLE     = aws_dynamodb_table.photos.name
      ACTION_LOG_TABLE = aws_dynamodb_table.photo_action_log.name
      ENVIRONMENT      = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.lambda_dynamodb, aws_iam_role_policy.lambda_logs]

  tags = local.common_tags
}

# Lambda function: Admin operations (finalize, update status, create users)
resource "aws_lambda_function" "admin_operations" {
  filename            = "placeholder.zip"
  function_name       = "${local.namespace}-admin-operations"
  role                = aws_iam_role.lambda_role.arn
  handler             = "index.handler"
  runtime             = "python3.11"
  timeout             = var.lambda_timeout
  memory_size         = var.lambda_memory_size
  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      PHOTOS_TABLE         = aws_dynamodb_table.photos.name
      PHOTOS_REVIEWS_TABLE = aws_dynamodb_table.photo_reviews.name
      ACTION_LOG_TABLE     = aws_dynamodb_table.photo_action_log.name
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      ENVIRONMENT          = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_dynamodb,
    aws_iam_role_policy.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]

  tags = local.common_tags
}

# Lambda function: Get photo history (admin)
resource "aws_lambda_function" "get_photo_history" {
  filename            = "placeholder.zip"
  function_name       = "${local.namespace}-get-photo-history"
  role                = aws_iam_role.lambda_role.arn
  handler             = "index.handler"
  runtime             = "python3.11"
  timeout             = var.lambda_timeout
  memory_size         = var.lambda_memory_size
  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      PHOTOS_REVIEWS_TABLE = aws_dynamodb_table.photo_reviews.name
      ACTION_LOG_TABLE     = aws_dynamodb_table.photo_action_log.name
      ENVIRONMENT          = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.lambda_dynamodb, aws_iam_role_policy.lambda_logs]

  tags = local.common_tags
}

# Lambda function: Generate presigned URL for photo download
resource "aws_lambda_function" "get_photo_url" {
  filename            = "placeholder.zip"
  function_name       = "${local.namespace}-get-photo-url"
  role                = aws_iam_role.lambda_role.arn
  handler             = "index.handler"
  runtime             = "python3.11"
  timeout             = 10
  memory_size         = 128
  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      PHOTOS_BUCKET = aws_s3_bucket.photos.id
      ENVIRONMENT   = var.environment
    }
  }

  depends_on = [aws_iam_role_policy.lambda_s3, aws_iam_role_policy.lambda_logs]

  tags = local.common_tags
}

# CloudWatch alarms for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.namespace}-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert on Lambda function errors"
  alarm_actions       = var.environment == "prod" ? [aws_sns_topic.alerts.arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.submit_review.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.namespace}-lambda-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert on Lambda throttling"
  alarm_actions       = var.environment == "prod" ? [aws_sns_topic.alerts.arn] : []
  treat_missing_data  = "notBreaching"

  tags = local.common_tags
}
