"""
Lambda integration with API Gateway
This file maps API Gateway routes to Lambda handlers
"""

# This would be configured in API Gateway console or via Terraform
# Route mappings:

# POST /photos/{id}/review -> submit_review.handler
# POST /photos/{id}/rotate -> rotate_photo.handler
# GET /photos -> get_photos.handler (list)
# GET /photos/{id} -> get_photos.handler (detail)
# GET /photos/{id}/history -> admin_operations.handler
# POST /admin/photos/{id}/finalize -> admin_operations.handler
# POST /admin/photos/{id}/status -> admin_operations.handler
# POST /admin/users -> admin_operations.handler

# For Terraform, these would be configured via aws_apigatewayv2_integration
# and aws_apigatewayv2_route resources
