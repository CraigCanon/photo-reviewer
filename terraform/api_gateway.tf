# API Gateway HTTP API
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.namespace}-api"
  protocol_type = "HTTP"
  description   = "Photo Review Application API"

  cors_configuration {
    allow_headers     = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins     = ["*"]  # Tighten this in production to specific domains
    expose_headers    = ["Content-Type", "X-Amzn-RequestId"]
    max_age           = 300
  }

  tags = local.common_tags
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationLatency = "$context.integration.latency"
      error          = "$context.error.message"
    })
  }

  default_route_settings {
    logging_level            = var.enable_detailed_logging ? "INFO" : "ERROR"
    detailed_metrics_enabled = var.enable_detailed_logging
    throttling_burst_limit   = 100
    throttling_rate_limit    = 50
  }

  tags = local.common_tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.namespace}"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = local.common_tags
}

# Cognito Authorizer for API Gateway
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${local.namespace}-cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.frontend.id]
    issuer   = "https://${aws_cognito_user_pool.main.endpoint}"
  }
}
