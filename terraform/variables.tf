variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "photo-scanner"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Application = "photo-scanner"
    Terraform   = true
  }
}

# Cognito Configuration
variable "cognito_password_policy" {
  description = "Password policy for Cognito users"
  type = object({
    minimum_length                   = number
    require_uppercase                = bool
    require_lowercase                = bool
    require_numbers                  = bool
    require_special_characters       = bool
    temporary_password_validity_days = number
  })
  default = {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_special_characters       = true
    temporary_password_validity_days = 3
  }
}

variable "cognito_mfa_configuration" {
  description = "MFA configuration (OPTIONAL, REQUIRED)"
  type        = string
  default     = "OPTIONAL"
  validation {
    condition     = contains(["OPTIONAL", "REQUIRED"], var.cognito_mfa_configuration)
    error_message = "Must be OPTIONAL or REQUIRED."
  }
}

# Lambda Configuration
variable "lambda_memory_size" {
  description = "Memory size in MB for Lambda functions"
  type        = number
  default     = 256
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout in seconds for Lambda functions"
  type        = number
  default     = 30
  validation {
    condition     = var.lambda_timeout > 0 && var.lambda_timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "Must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "dynamodb_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB"
  type        = bool
  default     = true
}

# S3 Configuration
variable "enable_s3_versioning" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = true
}

variable "s3_lifecycle_retention_days" {
  description = "Days to retain old object versions in S3"
  type        = number
  default     = 90
  validation {
    condition     = var.s3_lifecycle_retention_days > 0
    error_message = "Retention days must be positive."
  }
}

# Frontend domain (optional for custom domain)
variable "frontend_domain_name" {
  description = "Custom domain for frontend (optional)"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (required if frontend_domain_name is set)"
  type        = string
  default     = null
}

# Notifications
variable "admin_email" {
  description = "Admin email for Cognito user pool notifications"
  type        = string
}

variable "enable_detailed_logging" {
  description = "Enable detailed logging for debugging"
  type        = bool
  default     = true
}
