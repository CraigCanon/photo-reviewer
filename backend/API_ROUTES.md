# Terraform API Gateway Route Configuration

This file documents how to connect API Gateway routes to Lambda functions.

## Manual Configuration via AWS Console

1. Go to API Gateway → photo-scanner-dev-api
2. Click "Routes" in sidebar
3. For each endpoint below, click "Create Route"

## API Routes & Lambda Mappings

### Photo Review Endpoints

| Method | Route | Lambda Function | Auth | Description |
|--------|-------|-----------------|------|-------------|
| GET | /photos | get_photos | JWT | List photos (optional filter by state) |
| GET | /photos/{id} | get_photos | JWT | Get photo detail |
| GET | /photos/{id}/history | admin_operations | JWT + Admin | Get photo review history |
| GET | /photos/{id}/url | get_photo_url | JWT | Generate presigned S3 URL |
| POST | /photos/{id}/review | submit_review | JWT | Submit photo review |
| POST | /photos/{id}/rotate | rotate_photo | JWT | Rotate photo |

### Admin Endpoints

| Method | Route | Lambda Function | Auth | Description |
|--------|-------|-----------------|------|-------------|
| POST | /admin/photos/{id}/finalize | admin_operations | JWT + Admin | Finalize photo status |
| POST | /admin/photos/{id}/status | admin_operations | JWT + Admin | Update photo status |
| POST | /admin/users | admin_operations | JWT + Admin | Create user account |

## Terraform Integration Configuration

In `terraform/api_gateway_routes.tf`:

```hcl
# Lambda integration for get_photos
resource "aws_apigatewayv2_integration" "get_photos" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  
  payload_format_version = "2.0"
  target                 = aws_lambda_function.get_photos.invoke_arn
}

# Route: GET /photos
resource "aws_apigatewayv2_route" "get_photos_list" {
  api_id       = aws_apigatewayv2_api.main.id
  route_key    = "GET /photos"
  target       = "integrations/${aws_apigatewayv2_integration.get_photos.id}"
  
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Route: GET /photos/{id}
resource "aws_apigatewayv2_route" "get_photos_detail" {
  api_id       = aws_apigatewayv2_api.main.id
  route_key    = "GET /photos/{id}"
  target       = "integrations/${aws_apigatewayv2_integration.get_photos.id}"
  
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "get_photos" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_photos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}

# ... repeat for other Lambda functions ...
```

## Submit Review Endpoint Example

```hcl
resource "aws_apigatewayv2_integration" "submit_review" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  
  payload_format_version = "2.0"
  target                 = aws_lambda_function.submit_review.invoke_arn
}

resource "aws_apigatewayv2_route" "submit_review" {
  api_id       = aws_apigatewayv2_api.main.id
  route_key    = "POST /photos/{id}/review"
  target       = "integrations/${aws_apigatewayv2_integration.submit_review.id}"
  
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_lambda_permission" "submit_review" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.submit_review.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*"
}
```

## Admin Authorization Custom Authorizer

For admin-only endpoints, add a post-authorizer check:

```python
# In admin_operations.py handler
def handler(event, context):
    user_context = extract_user_context(event)
    
    if not is_admin(user_context):
        return lambda_response(403, {
            "error": "FORBIDDEN",
            "message": "Admin access required"
        })
    
    # ... handle request ...
```

## Testing API Routes

### Using curl

```bash
# Get JWT token (from Cognito)
TOKEN=$(aws cognito-idp admin-initiate-auth \
  --user-pool-id us-east-1_xxxxx \
  --client-id yyyyy \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=user@example.com,PASSWORD="password" \
  --query 'AuthenticationResult.IdToken' \
  --output text)

# Test API endpoint
curl -X GET \
  -H "Authorization: Bearer $TOKEN" \
  https://api.example.com/photos
```

### Using AWS CLI

```bash
aws lambda invoke \
  --function-name photo-scanner-dev-get-photos \
  --payload '{"httpMethod": "GET", "path": "/photos"}' \
  response.json

cat response.json
```

## Troubleshooting

### 403 Forbidden on Auth Routes

- Verify Cognito authorizer is attached to route
- Check JWT token is valid and not expired
- Verify token includes required claims

### 502 Bad Gateway

- Check Lambda function execution role has DynamoDB permissions
- Look for Lambda timeout (default 30s)
- Check CloudWatch logs for Lambda errors

### CORS Errors

- Verify API Gateway CORS settings match frontend domain
- Ensure OPTIONS method is allowed
- Check `Access-Control-Allow-Origin` header

### Route Not Found 404

- Verify route key format matches exactly
- Use `{id}` syntax for path parameters
- Check route is attached to correct integration
