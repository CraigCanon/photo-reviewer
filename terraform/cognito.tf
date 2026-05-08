# Cognito User Pool for authentication
resource "aws_cognito_user_pool" "main" {
  name = "${local.namespace}-user-pool"

  # Account recovery options
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  # Password policy
  password_policy {
    minimum_length                   = var.cognito_password_policy.minimum_length
    require_uppercase                = var.cognito_password_policy.require_uppercase
    require_lowercase                = var.cognito_password_policy.require_lowercase
    require_numbers                  = var.cognito_password_policy.require_numbers
    require_symbols                  = var.cognito_password_policy.require_special_characters
    temporary_password_validity_days = var.cognito_password_policy.temporary_password_validity_days
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # MFA configuration
  # mfa_configuration = var.cognito_mfa_configuration  # Disabled: requires explicit MFA method configuration

  # User attribute update settings
  user_attribute_update_settings {
    attributes_require_verification_before_update = ["email"]
  }

  # Schema with email, name, and custom attributes
  schema {
    name              = "email"
    attribute_data_type = "String"
    required          = true
    mutable           = true
  }

  schema {
    name              = "name"
    attribute_data_type = "String"
    required          = true
    mutable           = true
  }

  # Username attributes (allow email as username)
  username_attributes = ["email"]

  # Verification settings
  auto_verified_attributes = ["email"]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [schema] # Prevent drift from custom schemas added via API
  }
}

# Cognito User Pool Domain for hosted UI (use namespace alone - AWS will ensure uniqueness)
resource "aws_cognito_user_pool_domain" "main" {
  # Using just the namespace as domain name; Cognito ensures global uniqueness
  domain       = local.namespace
  user_pool_id = aws_cognito_user_pool.main.id
}

# Cognito User Pool Client for Frontend SPA
resource "aws_cognito_user_pool_client" "frontend" {
  name                   = "${local.namespace}-frontend"
  user_pool_id           = aws_cognito_user_pool.main.id
  generate_secret        = false # No secret for browser-based clients
  explicit_auth_flows    = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  prevent_user_existence_errors = "ENABLED"
  
  # Callback URLs (update based on your frontend domain)
  callback_urls = var.frontend_domain_name != null ? [
    "https://${var.frontend_domain_name}/auth/callback"
  ] : [
    "https://${aws_cloudfront_distribution.frontend.domain_name}/auth/callback"
  ]

  logout_urls = var.frontend_domain_name != null ? [
    "https://${var.frontend_domain_name}/auth/logout"
  ] : [
    "https://${aws_cloudfront_distribution.frontend.domain_name}/auth/logout"
  ]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  supported_identity_providers = ["COGNITO"]

  # Token validity periods
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# Cognito User Pool Client for Backend (M2M operations)
resource "aws_cognito_user_pool_client" "backend" {
  name                   = "${local.namespace}-backend"
  user_pool_id           = aws_cognito_user_pool.main.id
  generate_secret        = true
  explicit_auth_flows    = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"

  # Token validity periods
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# Cognito User Group for Reviewers
resource "aws_cognito_user_group" "reviewers" {
  name         = "reviewers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Reviewer role - can review photos"
}

# Cognito User Group for Admins
resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Admin role - can manage users and reviews"
}

# Identity Pool for AWS credentials (optional, for direct S3 access)
resource "aws_cognito_identity_pool" "main" {
  identity_pool_name             = "${local.namespace}-identity-pool"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id             = aws_cognito_user_pool_client.frontend.id
    provider_name         = aws_cognito_user_pool.main.endpoint
  }

  depends_on = [aws_cognito_user_pool.main]
}

# IAM role for authenticated Cognito users
resource "aws_iam_role" "cognito_authenticated" {
  name = "${local.namespace}-cognito-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          StringLike = {
            "cognito-identity.amazonaws.com:sub" = "*"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Policy for authenticated users to read photos from S3 (will use pre-signed URLs instead)
resource "aws_iam_role_policy" "cognito_authenticated_s3" {
  name = "${local.namespace}-cognito-s3-policy"
  role = aws_iam_role.cognito_authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.photos.arn}/*"
        Condition = {
          StringEquals = {
            "aws:userid" = "*:${aws_cognito_identity_pool.main.id}"
          }
        }
      }
    ]
  })
}

# Identity pool roles attachment
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    authenticated = aws_iam_role.cognito_authenticated.arn
  }
}
