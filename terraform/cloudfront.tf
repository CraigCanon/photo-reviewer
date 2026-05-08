# CloudFront Distribution for Frontend
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  http_version        = "http2and3"

  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3Frontend"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend.cloudfront_access_identity_path
    }
  }

  # Origin for API Gateway
  origin {
    domain_name = split("/", replace(aws_apigatewayv2_stage.main.invoke_url, "https://", ""))[0]
    origin_id   = "APIGateway"
    origin_path = "/${var.environment}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default behavior for S3 (frontend)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Frontend"
    compress         = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior for API requests
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "APIGateway"
    compress         = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Origin"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  # SPA routing: handle 404s by serving index.html
  custom_error_response {
    error_code            = 404
    error_caching_min_ttl = 300
    response_code         = 200
    response_page_path    = "/index.html"
  }

  custom_error_response {
    error_code            = 403
    error_caching_min_ttl = 300
    response_code         = 200
    response_page_path    = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.frontend_domain_name == null ? true : false
    acm_certificate_arn            = var.frontend_domain_name != null ? var.acm_certificate_arn : null
    ssl_support_method             = var.frontend_domain_name != null ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = local.common_tags
}

# CloudFront Origin Access Identity
# Already defined in iam.tf

# CloudFront cache invalidation (use after deploying frontend)
# resource "aws_cloudfront_invalidation" "frontend" {
#   distribution_id = aws_cloudfront_distribution.frontend.id
#   paths           = ["/*"]
# }

# CloudWatch alarm for CloudFront 4xx errors
resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_errors" {
  alarm_name          = "${local.namespace}-cloudfront-4xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "5"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "Alert on high 4xx error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.frontend.id
  }

  tags = local.common_tags
}

# CloudWatch alarm for CloudFront 5xx errors
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  alarm_name          = "${local.namespace}-cloudfront-5xx-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert on 5xx errors"
  alarm_actions       = var.environment == "prod" ? [aws_sns_topic.alerts.arn] : []
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.frontend.id
  }

  tags = local.common_tags
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${local.namespace}-alerts"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "admin_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}
