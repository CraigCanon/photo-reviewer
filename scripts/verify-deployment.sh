#!/bin/bash
# Verify deployment is working

set -e

echo "Verifying Photo Scanner deployment..."

NAMESPACE="${NAMESPACE:-photo-scanner-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
API_ENDPOINT="${API_ENDPOINT:-}"
FRONTEND_URL="${FRONTEND_URL:-}"

# 1. Check DynamoDB tables
echo ""
echo "1. Checking DynamoDB tables..."
for table in photos photo-reviews photo-action-log; do
    FULL_TABLE_NAME="${NAMESPACE}-${table}"
    if aws dynamodb describe-table \
        --table-name $FULL_TABLE_NAME \
        --region $AWS_REGION &>/dev/null; then
        echo "✓ Table $FULL_TABLE_NAME exists"
    else
        echo "✗ Table $FULL_TABLE_NAME NOT found"
        exit 1
    fi
done

# 2. Check Cognito User Pool
echo ""
echo "2. Checking Cognito User Pool..."
USER_POOL_ID=$(aws cognito-idp list-user-pools \
    --max-results 10 \
    --region $AWS_REGION \
    --query "UserPools[?Name==\`${NAMESPACE}-user-pool\`].Id" \
    --output text)

if [ -n "$USER_POOL_ID" ]; then
    echo "✓ Cognito User Pool exists: $USER_POOL_ID"
else
    echo "✗ Cognito User Pool NOT found"
fi

# 3. Check Lambda functions
echo ""
echo "3. Checking Lambda functions..."
for func in submit_review rotate_photo get_photos admin_operations get_photo_url; do
    if aws lambda get-function \
        --function-name ${NAMESPACE}-${func} \
        --region $AWS_REGION &>/dev/null; then
        echo "✓ Lambda function ${func} exists"
    else
        echo "✗ Lambda function ${func} NOT found"
    fi
done

# 4. Check API Gateway
echo ""
echo "4. Checking API Gateway..."
API_ID=$(aws apigatewayv2 get-apis \
    --query "Items[?Name==\`${NAMESPACE}-api\`].ApiId" \
    --output text \
    --region $AWS_REGION)

if [ -n "$API_ID" ]; then
    echo "✓ API Gateway exists: $API_ID"
else
    echo "✗ API Gateway NOT found"
fi

# 5. Check S3 buckets
echo ""
echo "5. Checking S3 buckets..."
for bucket_type in frontend photos thumbnails; do
    BUCKET=$(aws s3api list-buckets \
        --query "Buckets[?contains(Name, '${NAMESPACE}-${bucket_type}')].Name" \
        --output text)
    
    if [ -n "$BUCKET" ]; then
        echo "✓ S3 bucket $bucket_type exists: $BUCKET"
    else
        echo "✗ S3 bucket $bucket_type NOT found"
    fi
done

# 6. Test API endpoint if provided
if [ -n "$API_ENDPOINT" ]; then
    echo ""
    echo "6. Testing API endpoint..."
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "${API_ENDPOINT}/photos")
    
    if [ "$RESPONSE" = "401" ]; then
        echo "✓ API endpoint responding (expected 401 without auth)"
    else
        echo "✗ API endpoint returned unexpected status: $RESPONSE"
    fi
fi

# 7. Test Frontend URL if provided
if [ -n "$FRONTEND_URL" ]; then
    echo ""
    echo "7. Testing Frontend URL..."
    
    FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL")
    
    if [ "$FRONTEND_STATUS" = "200" ]; then
        echo "✓ Frontend is accessible"
    else
        echo "✗ Frontend returned status: $FRONTEND_STATUS"
    fi
fi

echo ""
echo "✅ Deployment verification complete!"
