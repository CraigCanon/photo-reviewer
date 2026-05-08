# Deployment Guide

## Prerequisites

- AWS Account (with appropriate permissions)
- Terraform >= 1.0
- AWS CLI v2 configured
- Python 3.11+
- Node.js 18+ (for frontend)
- Git

## Architecture Overview

```
┌─────────────────┐
│   CloudFront    │ ← CDN for frontend
└────────┬────────┘
         │
    ┌────┴─────────────────────┐
    │                           │
┌───┴────┐              ┌──────┴───────┐
│   S3   │              │ API Gateway   │
│Frontend│              │   (HTTP API)  │
└────────┘              └───────┬───────┘
                                │
                        ┌───────┴────────┐
                        │   Lambda Fn    │
                        │   Functions    │
                        └───────┬────────┘
                                │
                    ┌───────────┴────────────┐
                    │                        │
              ┌─────▼────┐           ┌──────▼────┐
              │ DynamoDB │           │ Cognito   │
              │ Tables   │           │ User Pool │
              └──────────┘           └───────────┘
                    │
              ┌─────▼──────┐
              │  S3 Photos │
              │  Bucket    │
              └────────────┘
```

## Phase 1: AWS Account Setup

### 1. Create AWS Account and Root User

1. Go to https://aws.amazon.com
2. Click "Create AWS Account"
3. Follow verification steps
4. **Enable MFA on root account immediately**

### 2. Create IAM User for Terraform Deployments

```bash
aws iam create-user --user-name terraform-deployer

# Create access key
aws iam create-access-key --user-name terraform-deployer

# Attach policy for Terraform operations
aws iam attach-user-policy \
  --user-name terraform-deployer \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Also attach this for Cognito:
aws iam attach-user-policy \
  --user-name terraform-deployer \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

**Save the access key and secret key** in a secure location!

### 3. Configure AWS CLI

```bash
aws configure
# Enter:
# AWS Access Key ID: [from above]
# AWS Secret Access Key: [from above]
# Default region name: us-east-1
# Default output format: json
```

Verify:
```bash
aws sts get-caller-identity
```

## Phase 2: Terraform Infrastructure Deployment

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

This creates `.terraform/` directory with provider plugins.

### 2. Create Environment-Specific Variables File

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Update with your values:
```hcl
environment = "dev"
aws_region  = "us-east-1"
admin_email = "your-email@example.com"

dynamodb_billing_mode = "PAY_PER_REQUEST"
lambda_memory_size    = 256
lambda_timeout        = 30

# For production
cognito_mfa_configuration = "REQUIRED"

tags = {
  Application = "photo-scanner"
  Team        = "platform"
  Terraform   = true
}
```

### 3. Plan Terraform Deployment

```bash
terraform plan -out=tfplan
```

Review the output to ensure it matches your expectations.

### 4. Apply Terraform Configuration

```bash
terraform apply tfplan
```

This will:
- Create S3 buckets (frontend, photos, logs)
- Create DynamoDB tables
- Create Cognito user pool
- Create API Gateway
- Create Lambda function stubs
- Create CloudFront distribution
- Create CloudWatch log groups
- Set up KMS encryption
- Configure IAM roles and policies

**Note:** Lambda functions have placeholder code. Update in Phase 3.

### 5. Capture Terraform Outputs

```bash
terraform output -json > outputs.json
```

Store these values - you'll need them for frontend configuration.

## Phase 3: Backend Deployment (Lambda Functions)

### 1. Package Lambda Functions

Create a deployment script `scripts/deploy-lambda.sh`:

```bash
#!/bin/bash
set -e

NAMESPACE="photo-scanner-dev"
AWS_REGION="us-east-1"
LAMBDA_ROLE="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/${NAMESPACE}-lambda-role"

cd backend

# Build packages for each Lambda function
for handler in submit_review rotate_photo get_photos admin_operations get_photo_url; do
    echo "Packaging $handler..."
    
    # Create temp directory
    mkdir -p build/$handler
    cp utils.py repositories.py services.py build/$handler/
    cp ${handler}.py build/$handler/index.py
    
    # Install dependencies
    pip install -r requirements.txt -t build/$handler/ --quiet
    
    # Create zip
    cd build/$handler
    zip -r ../${handler}.zip . -q
    cd ../../
    
    # Upload to Lambda
    aws lambda update-function-code \
        --function-name ${NAMESPACE}-${handler} \
        --zip-file fileb://build/${handler}.zip \
        --region $AWS_REGION
    
    echo "✓ Deployed $handler"
done

echo "All Lambda functions deployed!"
```

Run:
```bash
chmod +x scripts/deploy-lambda.sh
./scripts/deploy-lambda.sh
```

### 2. Configure API Gateway Routes

Create `scripts/setup-api-gateway.sh`:

```bash
#!/bin/bash

NAMESPACE="photo-scanner-dev"
API_ID=$(terraform output -json | jq -r '.api_gateway_id.value')
AUTHORIZER_ID=$(aws apigatewayv2 get-authorizers \
  --api-id $API_ID \
  --query "Items[0].AuthorizerId" \
  --output text)

LAMBDA_INVOKE_ARN_BASE="arn:aws:apigatewayv2:us-east-1:$(aws sts get-caller-identity --query Account --output text):lambda:"

# Function to create route
create_route() {
    local method=$1
    local path=$2
    local target=$3
    
    aws apigatewayv2 create-route \
        --api-id $API_ID \
        --route-key "$method $path" \
        --target "integrations/$target" \
        --authorization-type JWT \
        --authorizer-id $AUTHORIZER_ID
}

# Create integrations and routes
# GET /photos
aws lambda add-permission \
    --function-name ${NAMESPACE}-get-photos \
    --statement-id AllowAPIGateway \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:us-east-1:*:$API_ID/*"

echo "API Gateway routes configured!"
```

Or configure manually in AWS Console:
1. Go to API Gateway → APIs → photo-scanner-dev-api
2. Click Routes
3. For each handler, create:
   - `POST /photos/{id}/review` → submit_review
   - `POST /photos/{id}/rotate` → rotate_photo
   - `GET /photos` → get_photos
   - `GET /photos/{id}` → get_photos
   - `POST /admin/photos/{id}/finalize` → admin_operations
   - `POST /admin/users` → admin_operations
   - `GET /photos/{id}/history` → admin_operations

## Phase 4: Frontend Deployment

### 1. Create React App

```bash
cd frontend

# Install dependencies
npm install

# Create .env file
cat > .env.local << EOF
VITE_API_ENDPOINT=$(terraform -json output | jq -r '.api_gateway_invoke_url.value')
VITE_COGNITO_DOMAIN=$(terraform output -json | jq -r '.cognito_domain.value')
VITE_COGNITO_CLIENT_ID=$(terraform output -json | jq -r '.cognito_client_id.value')
VITE_COGNITO_USER_POOL_ID=$(terraform output -json | jq -r '.cognito_user_pool_id.value')
VITE_AWS_REGION=us-east-1
EOF
```

### 2. Build Frontend

```bash
npm run build
```

This creates `dist/` directory with optimized production build.

### 3. Deploy to S3

```bash
FRONTEND_BUCKET=$(terraform output -json | jq -r '.s3_frontend_bucket.value')

aws s3 sync dist/ s3://${FRONTEND_BUCKET}/ \
    --delete \
    --cache-control "public, max-age=3600" \
    --exclude "index.html"

aws s3 cp dist/index.html s3://${FRONTEND_BUCKET}/index.html \
    --cache-control "public, max-age=0" \
    --content-type "text/html"
```

### 4. Invalidate CloudFront Cache

```bash
DISTRIBUTION_ID=$(terraform output -json | jq -r '.cloudfront_distribution_id.value')

aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/*"

echo "Frontend deployed to: $(terraform output -json | jq -r '.cloudfront_domain_name.value')"
```

## Phase 5: Create Initial Admin User

### Option A: AWS Console

1. Go to Cognito → User pools → photo-scanner-dev-user-pool
2. Click Users → Create user
3. Enter email and name
4. Uncheck "Send an email invitation"
5. Set temporary password manually
6. Click Create
7. Go to Groups → Create group "admins"
8. Add user to admins group

### Option B: AWS CLI

```bash
USER_POOL_ID=$(terraform output -json | jq -r '.cognito_user_pool_id.value')

aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username admin@example.com \
    --user-attributes \
        Name=email,Value=admin@example.com \
        Name=name,Value="Admin User" \
    --temporary-password "TempPassword123!" \
    --message-action SUPPRESS

# Add to admins group
aws cognito-idp admin-add-user-to-group \
    --user-pool-id $USER_POOL_ID \
    --username admin@example.com \
    --group-name admins

echo "Admin user created. They will be prompted to set password on first login."
```

## Phase 6: Verify Deployment

### 1. Test Frontend Access

```bash
CLOUDFRONT_URL=$(terraform output -json | jq -r '.cloudfront_domain_name.value')
open https://$CLOUDFRONT_URL
```

Should see login page.

### 2. Test API Endpoint

```bash
API_ENDPOINT=$(terraform output -json | jq -r '.api_gateway_invoke_url.value')

# This should return 401 (no auth token)
curl -X GET ${API_ENDPOINT}/photos
```

### 3. Check Logs

```bash
# API Gateway logs
aws logs tail /aws/apigateway/photo-scanner-dev --follow

# Lambda logs
aws logs tail /aws/lambda/photo-scanner-dev --follow

# DynamoDB
aws cloudwatch get-metric-statistics \
    --namespace AWS/DynamoDB \
    --metric-name ConsumedReadCapacityUnits \
    --dimensions Name=TableName,Value=photo-scanner-dev-photos \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum
```

## Phase 7: Cleanup & Teardown

To remove all AWS resources:

```bash
cd terraform

# Review what will be destroyed
terraform plan -destroy

# Destroy resources
terraform destroy

# Confirm when prompted
```

**WARNING:** This will delete:
- All photos in S3
- All reviews in DynamoDB
- Cognito users
- API Gateway configuration
- Everything created by Terraform!

Backup important data before destroying.

## Troubleshooting

### Lambda Functions Failing

Check CloudWatch logs:
```bash
aws logs tail /aws/lambda/photo-scanner-dev-submit-review --follow
```

### API Gateway 403 Errors

- Verify Cognito authorizer is attached to routes
- Check JWT token validity
- Verify CORS configuration

### S3 Access Errors

- Check bucket policies
- Verify IAM role has S3 permissions
- Check KMS key access

### DynamoDB Throttling

- Check CloudWatch metrics
- Increase provisioned capacity or switch to on-demand billing
- Look for inefficient queries (full table scans)

## Monitoring & Alerts

### Set Up SNS Email Notifications

```bash
aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:XXXX:photo-scanner-dev-alerts \
    --protocol email \
    --notification-endpoint admin@example.com
```

Confirm subscription from email.

### CloudWatch Dashboard

```bash
aws cloudwatch put-dashboard \
    --dashboard-name photo-scanner-dev \
    --dashboard-body file://dashboard.json
```

## Next Steps

1. **Frontend Development**: Start building React components
2. **Testing**: Write integration tests for Lambda functions
3. **CI/CD**: Set up GitHub Actions for automated deployments
4. **Load Testing**: Test performance with photos.example.com load testing
5. **Disaster Recovery**: Implement backup strategies
6. **Security Hardening**: Enable WAF, add VPC, implement rate limiting

## Support

- Terraform Docs: https://registry.terraform.io/providers/hashicorp/aws/latest
- AWS Documentation: https://docs.aws.amazon.com/
- Photo Scanner Issues: Check /docs/ directory for additional guides
