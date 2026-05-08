#!/bin/bash
# Deploy Lambda functions to AWS

set -e

NAMESPACE="${NAMESPACE:-photo-scanner-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "Deploying Lambda functions for $NAMESPACE..."

cd backend

# Function to deploy a Lambda function
deploy_lambda() {
    local handler_name=$1
    local function_suffix=$2
    local function_name="${NAMESPACE}-${function_suffix}"
    
    echo "Packaging $handler_name..."
    
    # Create build directory
    mkdir -p build/$handler_name
    
    # Copy source files
    cp utils.py repositories.py services.py build/$handler_name/
    cp ${handler_name}.py build/$handler_name/index.py
    
    # Install dependencies
    echo "Installing dependencies..."
    pip install -r requirements.txt -t build/$handler_name/ --quiet 2>/dev/null || true
    
    # Create zip archive
    cd build/$handler_name
    zip -r ../${handler_name}.zip . -q
    cd ../..
    
    # Get Lambda execution role ARN
    ROLE_ARN=$(aws iam get-role \
        --role-name ${NAMESPACE}-lambda-role \
        --query 'Role.Arn' \
        --output text \
        --region $AWS_REGION 2>/dev/null || echo "")
    
    if [ -z "$ROLE_ARN" ]; then
        echo "ERROR: Lambda role not found. Run terraform apply first."
        exit 1
    fi
    
    # Check if function exists
    if aws lambda get-function \
        --function-name $function_name \
        --region $AWS_REGION &>/dev/null; then
        
        # Update function code
        echo "Updating $function_name code..."
        aws lambda update-function-code \
            --function-name $function_name \
            --zip-file fileb://build/${handler_name}.zip \
            --region $AWS_REGION \
            --publish > /dev/null
    else
        echo "Creating $function_name..."
        aws lambda create-function \
            --function-name $function_name \
            --runtime python3.11 \
            --role $ROLE_ARN \
            --handler index.handler \
            --zip-file fileb://build/${handler_name}.zip \
            --timeout 30 \
            --memory-size 256 \
            --environment Variables="{ENVIRONMENT=${ENVIRONMENT},NAMESPACE=${NAMESPACE}}" \
            --region $AWS_REGION > /dev/null
    fi
    
    echo "✓ Deployed $function_name"
}

# Deploy all Lambda functions
deploy_lambda "submit_review" "submit-review"
deploy_lambda "rotate_photo" "rotate-photo"
deploy_lambda "get_photos" "get-photos"
deploy_lambda "admin_operations" "admin-operations"
deploy_lambda "get_photo_url" "get-photo-url"

# Clean up
rm -rf build/

echo ""
echo "✅ All Lambda functions deployed successfully!"
