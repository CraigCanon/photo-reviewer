#!/bin/bash
# Deploy frontend to S3 and CloudFront

set -e

NAMESPACE="${NAMESPACE:-photo-scanner-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
FRONTEND_DIR="frontend"
DIST_DIR="${FRONTEND_DIR}/dist"

echo "Deploying frontend for $NAMESPACE..."

# Get S3 bucket name from Terraform
FRONTEND_BUCKET=$(aws s3api list-buckets \
    --query "Buckets[?contains(Name, '${NAMESPACE}-frontend')].Name" \
    --output text)

if [ -z "$FRONTEND_BUCKET" ]; then
    echo "ERROR: Frontend bucket not found."
    echo "Run 'terraform apply' first."
    exit 1
fi

echo "Frontend bucket: $FRONTEND_BUCKET"

# Check if dist directory exists
if [ ! -d "$DIST_DIR" ]; then
    echo "ERROR: ${DIST_DIR}/ directory not found. Run 'npm run build' first."
    exit 1
fi

# Upload files to S3
echo "Uploading files to S3..."
aws s3 sync "$DIST_DIR/" s3://${FRONTEND_BUCKET}/ \
    --delete \
    --cache-control "public, max-age=3600" \
    --exclude "index.html" \
    --region $AWS_REGION

# Upload index.html with no cache
aws s3 cp "$DIST_DIR/index.html" s3://${FRONTEND_BUCKET}/index.html \
    --cache-control "public, max-age=0" \
    --content-type "text/html" \
    --region $AWS_REGION

echo "Clearing CloudFront cache..."

# Get CloudFront distribution ID from Terraform outputs first
DISTRIBUTION_ID=$(terraform -chdir=terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

# If Terraform output not available, try CloudFormation stack output
if [ -z "$DISTRIBUTION_ID" ]; then
    DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
        --stack-name ${NAMESPACE}-stack \
        --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
        --output text \
        --region $AWS_REGION 2>/dev/null || echo "")
fi

# If CloudFormation stack not found, look up by S3 origin
if [ -z "$DISTRIBUTION_ID" ]; then
    DISTRIBUTION_ID=$(aws cloudfront list-distributions \
        --query "DistributionList.Items[?contains(Origins.Items[].DomainName, '${FRONTEND_BUCKET}.s3.${AWS_REGION}.amazonaws.com')].Id" \
        --output text)
fi

if [ -n "$DISTRIBUTION_ID" ]; then
    echo "Invalidating CloudFront distribution: $DISTRIBUTION_ID"
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id $DISTRIBUTION_ID \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)
    
    echo "Invalidation created: $INVALIDATION_ID"
else
    echo "WARNING: CloudFront distribution not found. Cache may not be cleared."
fi

echo ""
echo "✅ Frontend deployed successfully!"
echo "Frontend URL: https://$FRONTEND_BUCKET.s3-website-${AWS_REGION}.amazonaws.com"
