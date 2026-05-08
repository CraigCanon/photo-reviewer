output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_client_id" {
  description = "Cognito Client ID for frontend"
  value       = aws_cognito_user_pool_client.frontend.id
  sensitive   = true
}

output "cognito_domain" {
  description = "Cognito domain for hosted UI"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.main.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.frontend.id
}

output "s3_photos_bucket" {
  description = "S3 bucket for photos"
  value       = aws_s3_bucket.photos.id
}

output "s3_frontend_bucket" {
  description = "S3 bucket for frontend assets"
  value       = aws_s3_bucket.frontend.id
}

output "dynamodb_photos_table" {
  description = "DynamoDB Photos table name"
  value       = aws_dynamodb_table.photos.name
}

output "dynamodb_reviews_table" {
  description = "DynamoDB PhotoReviews table name"
  value       = aws_dynamodb_table.photo_reviews.name
}

output "dynamodb_action_log_table" {
  description = "DynamoDB PhotoActionLog table name"
  value       = aws_dynamodb_table.photo_action_log.name
}

output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value = {
    frontend_upload = "aws s3 cp frontend/dist s3://${aws_s3_bucket.frontend.id}/ --recursive --region ${var.aws_region}"
    api_deploy      = "Deploy Lambda functions: see backend/ directory"
    frontend_url    = "https://${aws_cloudfront_distribution.frontend.domain_name}"
    api_url         = aws_apigatewayv2_stage.main.invoke_url
  }
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}
