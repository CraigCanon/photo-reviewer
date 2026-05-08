# Secrets and Credentials Management for Photo Scanner

## Overview

This document explains where to store and manage sensitive information (database credentials, API keys, passwords, secrets) for the Photo Scanner application across all deployment environments.

## 1. Terraform Variables & Secrets

### Store in `.tfvars` (DO NOT commit to git)

Create `terraform/terraform.tfvars` based on `terraform.tfvars.example`. Add sensitive values:

```hcl
environment = "dev"
aws_region  = "us-east-1"
admin_email = "admin@example.com"  # Real admin email

# Store any custom domain info
frontend_domain_name = "photos.yourdomain.com"  # Optional
acm_certificate_arn  = "arn:aws:acm:..."       # For HTTPS custom domain
```

**Add to `.gitignore`:**
```
terraform/terraform.tfvars
terraform/.terraform/
terraform/terraform.tfstate*
terraform/crash.log
```

## 2. AWS Secrets Manager (Recommended)

Use AWS Secrets Manager for runtime secrets that must be accessed by Lambda functions.

### Create Secrets via Terraform

Add to `terraform/secrets.tf`:

```hcl
# Database credentials, API keys, etc.
resource "aws_secretsmanager_secret" "db_credentials" {
  name       = "${local.namespace}-db-credentials"
  description = "Database credentials for Photo Scanner"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# API keys for third-party services
resource "aws_secretsmanager_secret" "api_keys" {
  name       = "${local.namespace}-api-keys"
  description = "Third-party API keys"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    sendgrid_api_key = var.sendgrid_api_key
    slack_webhook_url = var.slack_webhook_url
  })
}
```

### Add Variables to `terraform/variables.tf`

```hcl
variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "sendgrid_api_key" {
  description = "SendGrid API key"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
  sensitive   = true
}
```

### Store Variables in AWS Parameter Store or CI/CD Secrets

For CI/CD pipelines (GitHub Actions, GitLab CI, etc.), store these in your platform's secret manager:

**GitHub Actions:** Settings → Secrets and variables → Actions
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
TF_VAR_db_username
TF_VAR_db_password
TF_VAR_sendgrid_api_key
TF_VAR_slack_webhook_url
```

**GitLab CI:** Settings → CI/CD → Variables
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
TF_VAR_DB_USERNAME
TF_VAR_DB_PASSWORD
```

### Access Secrets from Lambda Functions

Update Lambda IAM policy in `terraform/iam.tf` (already included):

```python
# In Lambda function
import boto3
import json
import os

secrets_client = boto3.client("secretsmanager")

def get_secret(secret_name: str) -> dict:
    """Retrieve secret from AWS Secrets Manager"""
    try:
        response = secrets_client.get_secret_value(
            SecretId=f"{os.environ['NAMESPACE']}-{secret_name}"
        )
        return json.loads(response["SecretString"])
    except Exception as e:
        logger.error(f"Failed to retrieve secret {secret_name}: {str(e)}")
        return {}

# Usage in handler
def handler(event, context):
    db_creds = get_secret("db-credentials")
    username = db_creds.get("username")
    password = db_creds.get("password")
```

## 3. Environment Variables in Lambda

Set non-sensitive environment variables in Terraform:

```hcl
resource "aws_lambda_function" "submit_review" {
  # ... other config ...
  
  environment {
    variables = {
      PHOTOS_TABLE        = aws_dynamodb_table.photos.name
      PHOTOS_REVIEWS_TABLE = aws_dynamodb_table.photo_reviews.name
      ACTION_LOG_TABLE    = aws_dynamodb_table.photo_action_log.name
      ENVIRONMENT         = var.environment
      NAMESPACE           = local.namespace
      # Do NOT put sensitive values here!
    }
  }
}
```

## 4. Cognito Passwords & Credentials

### Admin User Creation

Create initial admin via AWS Console:

1. Go to Cognito → User pools → photo-scanner-{env}-user-pool
2. Click "Users" → "Create user"
3. Enter email, name, temporary password
4. Add to "admins" group
5. User receives welcome email with temporary password

Or via AWS CLI:

```bash
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_xxxxx \
  --username admin@example.com \
  --temporary-password "TempPassword123!" \
  --message-action RESEND
```

### User Password Reset

Users can self-service reset via login flow (Cognito handles secure reset emails).

Admins can force reset:

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_xxxxx \
  --username user@example.com \
  --password "NewPassword123!" \
  --permanent
```

## 5. API Gateway & Lambda Secrets

### JWT Secret (Cognito-managed)

Cognito handles JWT signing internally. No manual secret management needed.

### CORS & API Keys (Optional)

If using API keys for rate limiting:

```hcl
resource "aws_apigateway_api_key" "main" {
  name        = "${local.namespace}-api-key"
  description = "API key for Photo Scanner"
  enabled     = true

  tags = local.common_tags
}
```

## 6. S3 Encryption Keys (KMS)

Terraform manages KMS keys automatically:

- `aws_kms_key.s3` - Encrypts S3 buckets
- `aws_kms_key.dynamodb` - Encrypts DynamoDB

Lambda has permission to decrypt via IAM policy in `terraform/iam.tf`.

## 7. CloudFront & SSL Certificates

### Self-signed (Default)

CloudFront provides default domain: `d123456.cloudfront.net`

### Custom Domain with ACM Certificate

1. **Request certificate in AWS Certificate Manager:**
   ```bash
   aws acm request-certificate \
     --domain-name photos.yourdomain.com \
     --validation-method DNS
   ```

2. **Validate DNS record** (follow ACM instructions)

3. **Update Terraform variables:**
   ```hcl
   frontend_domain_name = "photos.yourdomain.com"
   acm_certificate_arn  = "arn:aws:acm:us-east-1:123456:certificate/xxx"
   ```

4. **Create Route53 alias** (if using Route53):
   ```hcl
   resource "aws_route53_record" "frontend" {
     zone_id = aws_route53_zone.main.zone_id
     name    = "photos.yourdomain.com"
     type    = "A"
     alias {
       name                   = aws_cloudfront_distribution.frontend.domain_name
       zone_id               = aws_cloudfront_distribution.frontend.hosted_zone_id
       evaluate_target_health = false
     }
   }
   ```

## 8. Source Control Security

### .gitignore for secrets

```
# Terraform
terraform/terraform.tfvars
terraform/terraform.tfvars.json
terraform/.terraform/
terraform/crash.log
terraform/override.tf

# Local env
.env
.env.local
.env.*.local

# AWS/Credentials
.aws/credentials
.aws/config

# Backend
backend/.env
backend/venv/

# Frontend
frontend/.env
frontend/.env.local
frontend/node_modules/
```

### Pre-commit Hooks (Prevent accidental secrets commits)

Install `pre-commit`:
```bash
pip install pre-commit
```

Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.16.1
    hooks:
      - id: gitleaks
```

Enable:
```bash
pre-commit install
```

## 9. Deployment Workflow

### 1. Local Development

```bash
# Copy example files
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with local values (DO NOT commit)
nano terraform/terraform.tfvars

# Create admin secret
export TF_VAR_db_username="localadmin"
export TF_VAR_db_password="LocalSecure123!"

# Deploy
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. CI/CD Pipeline (GitHub Actions)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

env:
  AWS_REGION: us-east-1
  TF_VERSION: "1.5"

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TF_VERSION }}
      
      - name: Terraform Init
        run: cd terraform && terraform init
      
      - name: Terraform Plan
        run: cd terraform && terraform plan -out=tfplan
        env:
          TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
          TF_VAR_sendgrid_api_key: ${{ secrets.SENDGRID_API_KEY }}
      
      - name: Terraform Apply
        run: cd terraform && terraform apply tfplan
```

### 3. Sensitive Variables in CI/CD

GitHub Actions Example:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## 10. Rotation & Lifecycle

### Password Rotation Schedule

- **Development**: No requirements
- **Staging**: Quarterly rotation
- **Production**: Monthly rotation

### Automated rotation with AWS Secrets Manager

```hcl
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### Key Rotation

KMS keys auto-rotate annually (`enable_key_rotation = true` in Terraform).

## 11. Monitoring & Auditing

### CloudTrail (Log all API calls)

```hcl
resource "aws_cloudtrail" "main" {
  name           = "${local.namespace}-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id
  
  enable_log_file_validation = true
  include_global_service_events = true
  is_multi_region_trail = true
  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}
```

### CloudWatch Logs for sensitive operations

```python
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    # Log authentication events
    logger.info(f"User {user_id} performed action {action}", extra={
        "user_id": user_id,
        "action": action,
        "timestamp": datetime.utcnow().isoformat(),
    })
```

## 12. Emergency Access

### Lost AWS Credentials

1. Use AWS Root account to create new IAM user (if root has MFA)
2. Or contact AWS Support
3. Immediately revoke old credentials in IAM console

### Compromised Secrets

1. **Immediately rotate in Secrets Manager**
2. **Rotate all dependent credentials** (API keys, passwords)
3. **Review CloudTrail** for unauthorized access
4. **Enable MFA** on all accounts
5. **Update all environments** with new secrets

## Checklist for New Deployments

- [ ] Create `.tfvars` file with environment-specific values
- [ ] Set all `TF_VAR_*` environment variables
- [ ] Create secrets in AWS Secrets Manager
- [ ] Configure CI/CD platform secrets
- [ ] Enable CloudTrail logging
- [ ] Set up SNS alerts for unauthorized access attempts
- [ ] Document all secret locations and rotation procedures
- [ ] Test secret rotation process
- [ ] Review IAM permissions (least privilege)
- [ ] Enable MFA on all user accounts
