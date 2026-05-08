"""
Shared utilities for Lambda functions
"""
import json
import logging
import os
from decimal import Decimal
from datetime import datetime
from functools import wraps
from typing import Any, Callable, Dict, Optional

logger = logging.getLogger()
logger.setLevel(logging.INFO if os.environ.get("ENVIRONMENT") == "prod" else logging.DEBUG)


def _json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        if value % 1 == 0:
            return int(value)
        return float(value)
    return str(value)


class AppError(Exception):
    """Base application error"""
    def __init__(self, message: str, status_code: int = 400, error_code: str = "INTERNAL_ERROR"):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        super().__init__(self.message)


def lambda_response(status_code: int, body: Dict[str, Any], headers: Optional[Dict] = None) -> Dict:
    """Format Lambda response"""
    default_headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
    }
    if headers:
        default_headers.update(headers)
    
    return {
        "statusCode": status_code,
        "headers": default_headers,
        "body": json.dumps(body, default=_json_default) if isinstance(body, dict) else body,
    }


def error_response(error: AppError) -> Dict:
    """Format error response"""
    return lambda_response(
        error.status_code,
        {
            "error": error.error_code,
            "message": error.message,
        },
    )


def catch_errors(func: Callable) -> Callable:
    """Decorator to catch and format errors"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except AppError as e:
            logger.error(f"Application error: {e.message}")
            return error_response(e)
        except Exception as e:
            logger.exception(f"Unexpected error: {str(e)}")
            return lambda_response(500, {"error": "INTERNAL_ERROR", "message": "An unexpected error occurred"})
    return wrapper


def extract_user_context(event: Dict) -> Dict[str, str]:
    """Extract user info from Cognito JWT claims"""
    try:
        claims = event.get("requestContext", {}).get("authorizer", {}).get("claims", {})
        return {
            "user_id": claims.get("sub"),
            "email": claims.get("email"),
            "username": claims.get("cognito:username"),
            "groups": claims.get("cognito:groups", []),
        }
    except Exception as e:
        logger.error(f"Failed to extract user context: {str(e)}")
        raise AppError("Invalid authorization token", 401, "UNAUTHORIZED")


def is_admin(user_context: Dict) -> bool:
    """Check if user is in admin group"""
    return "admins" in user_context.get("groups", [])


def validate_json_body(event: Dict) -> Dict:
    """Extract and validate JSON body from event"""
    try:
        body = event.get("body", "{}")
        if isinstance(body, str):
            return json.loads(body)
        return body
    except json.JSONDecodeError:
        raise AppError("Invalid JSON in request body", 400, "INVALID_JSON")


def get_path_parameter(event: Dict, name: str) -> str:
    """Get path parameter from event"""
    value = event.get("pathParameters", {}).get(name)
    if not value:
        raise AppError(f"Missing required path parameter: {name}", 400, "MISSING_PARAMETER")
    return value


def get_query_parameter(event: Dict, name: str, default: Optional[str] = None) -> Optional[str]:
    """Get query parameter from event"""
    return event.get("queryStringParameters", {}).get(name, default) if event.get("queryStringParameters") else default


def current_timestamp() -> int:
    """Get current timestamp in milliseconds"""
    return int(datetime.utcnow().timestamp() * 1000)
