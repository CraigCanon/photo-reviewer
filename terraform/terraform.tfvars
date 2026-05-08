# Example Terraform variables file
# Copy this to terraform.tfvars and update with your values

environment = "dev"  # dev, staging, or prod
aws_region  = "us-east-1"

# Admin email for CloudWatch alarms and Cognito notifications
admin_email = "craig@craigandelisa.com"

# DynamoDB configuration
dynamodb_billing_mode            = "PAY_PER_REQUEST"  # Cost-effective for variable workloads
dynamodb_point_in_time_recovery  = true

# Lambda configuration
lambda_memory_size = 256
lambda_timeout     = 30

# S3 configuration
enable_s3_versioning          = true
s3_lifecycle_retention_days   = 90

# Cognito configuration
cognito_mfa_configuration = "OPTIONAL"  # Set to "REQUIRED" for production

# Custom domain (optional)
# frontend_domain_name = "photos.example.com"
# acm_certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/..."

# Common tags
tags = {
  Application = "photo-scanner"
  Team        = "platform"
  Terraform   = true
}
