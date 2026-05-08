# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${local.namespace}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB access policy for Lambda
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${local.namespace}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.photos.arn,
          "${aws_dynamodb_table.photos.arn}/index/*",
          aws_dynamodb_table.photo_reviews.arn,
          "${aws_dynamodb_table.photo_reviews.arn}/index/*",
          aws_dynamodb_table.photo_action_log.arn,
          "${aws_dynamodb_table.photo_action_log.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:ExecuteTransaction",
          "dynamodb:TransactWriteItems",
          "dynamodb:TransactGetItems"
        ]
        Resource = [
          aws_dynamodb_table.photos.arn,
          aws_dynamodb_table.photo_reviews.arn,
          aws_dynamodb_table.photo_action_log.arn
        ]
      }
    ]
  })
}

# S3 access policy for Lambda (for reading/writing photos and generating pre-signed URLs)
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${local.namespace}-lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:HeadObject"
        ]
        Resource = [
          "${aws_s3_bucket.photos.arn}/*",
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.photos.arn,
          aws_s3_bucket.thumbnails.arn
        ]
      }
    ]
  })
}

# KMS access policy for Lambda (for DynamoDB encryption)
resource "aws_iam_role_policy" "lambda_kms" {
  name = "${local.namespace}-lambda-kms-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.dynamodb.arn,
          aws_kms_key.s3.arn
        ]
      }
    ]
  })
}

# Secrets Manager access policy for Lambda
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${local.namespace}-lambda-secrets-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.namespace}/*"
        ]
      }
    ]
  })
}

# CloudWatch Logs policy for Lambda
resource "aws_iam_role_policy" "lambda_logs" {
  name = "${local.namespace}-lambda-logs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# CloudFront OAI (Origin Access Identity) for secure S3 access
resource "aws_cloudfront_origin_access_identity" "frontend" {
  comment = "OAI for ${local.namespace} frontend"
}

# S3 bucket policy for CloudFront OAI
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.frontend.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}
