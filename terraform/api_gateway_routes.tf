# API Gateway Lambda integrations
resource "aws_apigatewayv2_integration" "get_photos" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_photos.invoke_arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_integration" "submit_review" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.submit_review.invoke_arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_integration" "rotate_photo" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.rotate_photo.invoke_arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_integration" "admin_operations" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.admin_operations.invoke_arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_integration" "get_photo_url" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_photo_url.invoke_arn
  payload_format_version = "1.0"
}

# API Gateway routes
resource "aws_apigatewayv2_route" "get_photos_list" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /photos"
  target             = "integrations/${aws_apigatewayv2_integration.get_photos.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_photos_detail" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /photos/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.get_photos.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "submit_review" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /photos/{id}/review"
  target             = "integrations/${aws_apigatewayv2_integration.submit_review.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "rotate_photo" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /photos/{id}/rotate"
  target             = "integrations/${aws_apigatewayv2_integration.rotate_photo.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_photo_url" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /photos/{id}/url"
  target             = "integrations/${aws_apigatewayv2_integration.get_photo_url.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "get_photo_history" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /photos/{id}/history"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "admin_finalize" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /admin/photos/{id}/finalize"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "admin_update_status" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /admin/photos/{id}/status"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "admin_create_user" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /admin/users"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# CloudFront-compatible routes (path includes /api prefix)
resource "aws_apigatewayv2_route" "api_get_photos_list" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /api/photos"
  target             = "integrations/${aws_apigatewayv2_integration.get_photos.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_get_photos_detail" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /api/photos/{id}"
  target             = "integrations/${aws_apigatewayv2_integration.get_photos.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_submit_review" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /api/photos/{id}/review"
  target             = "integrations/${aws_apigatewayv2_integration.submit_review.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_rotate_photo" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /api/photos/{id}/rotate"
  target             = "integrations/${aws_apigatewayv2_integration.rotate_photo.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_get_photo_url" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /api/photos/{id}/url"
  target             = "integrations/${aws_apigatewayv2_integration.get_photo_url.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_get_photo_history" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /api/photos/{id}/history"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_admin_finalize" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /api/admin/photos/{id}/finalize"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_admin_update_status" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /api/admin/photos/{id}/status"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "api_admin_create_user" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /api/admin/users"
  target             = "integrations/${aws_apigatewayv2_integration.admin_operations.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# Lambda invoke permissions for API Gateway
resource "aws_lambda_permission" "api_get_photos" {
  statement_id  = "AllowApiGatewayInvokeGetPhotos"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_photos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_submit_review" {
  statement_id  = "AllowApiGatewayInvokeSubmitReview"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.submit_review.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_rotate_photo" {
  statement_id  = "AllowApiGatewayInvokeRotatePhoto"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotate_photo.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_admin_operations" {
  statement_id  = "AllowApiGatewayInvokeAdminOperations"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin_operations.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_get_photo_url" {
  statement_id  = "AllowApiGatewayInvokeGetPhotoUrl"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_photo_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
