"""
Lambda handler for admin operations (finalize, update status, user management)
Implements REQ-ADMIN-1 through REQ-ADMIN-4 and REQ-USER-1 through REQ-USER-4
"""
import uuid
from utils import (
    lambda_response, catch_errors, extract_user_context, validate_json_body,
    get_path_parameter, current_timestamp, AppError, is_admin
)
from repositories import PhotoRepository, PhotoReviewRepository, ActionLogRepository
from services import ReviewWorkflowService, AdminService

import os
import boto3

cognito = boto3.client("cognito-idp")

# Initialize repositories
photo_repo = PhotoRepository()
review_repo = PhotoReviewRepository()
action_log_repo = ActionLogRepository()


@catch_errors
def handler(event, context):
    """
    POST /admin/photos/{id}/finalize
    POST /admin/photos/{id}/status
    POST /admin/users
    GET /photos/{id}/history
    """
    # Extract user context (validates JWT)
    user_context = extract_user_context(event)
    user_id = user_context["user_id"]
    
    # Verify admin role
    if not is_admin(user_context):
        raise AppError("Admin access required", 403, "FORBIDDEN")
    
    # Route by method and path
    method = event.get("httpMethod", "").upper()
    path = event.get("path", "")
    
    if "/finalize" in path and method == "POST":
        return finalize_photo(event, user_id)
    elif "/status" in path and method == "POST":
        return update_photo_status(event, user_id)
    elif "/history" in path and method == "GET":
        return get_photo_history(event)
    elif path.startswith("/admin/users") and method == "POST":
        return create_user(event, user_id)
    else:
        raise AppError("Unknown admin operation", 400, "INVALID_OPERATION")


def finalize_photo(event, admin_id: str):
    """
    POST /admin/photos/{id}/finalize
    
    Request body:
    {
        "status": "Approved to Publish|Rejected",
        "reason": "Optional reason"
    }
    """
    photo_id = get_path_parameter(event, "id")
    body = validate_json_body(event)
    status = body.get("status")
    reason = body.get("reason")
    
    if not status or status not in ["Approved to Publish", "Rejected"]:
        raise AppError("Invalid status", 400, "INVALID_STATUS")
    
    # Get photo
    photo = photo_repo.get_photo(photo_id)
    if not photo:
        raise AppError("Photo not found", 404, "NOT_FOUND")
    
    # Finalize
    photo_repo.update_photo_state(photo_id, "Finalized")
    
    # Record finalization
    admin_data = AdminService.finalize_photo(photo_id, status, admin_id, reason)
    
    # Log action
    action_log_repo.log_action({
        "action_id": str(uuid.uuid4()),
        "photo_id": photo_id,
        "user_id": admin_id,
        "action_type": "Finalize",
        "previous_value": photo["current_state"],
        "new_value": "Finalized",
        "admin_status": status,
        "reason": reason,
        "created_at": current_timestamp(),
    })
    
    return lambda_response(200, {
        "success": True,
        "photo_id": photo_id,
        "finalized_status": status,
        "timestamp": admin_data["finalized_at"],
    })


def update_photo_status(event, admin_id: str):
    """
    POST /admin/photos/{id}/status
    
    Request body:
    {
        "new_status": "Pending First Review|Pending Second Review|Approved to Publish|Rejected"
    }
    """
    photo_id = get_path_parameter(event, "id")
    body = validate_json_body(event)
    new_status = body.get("new_status")
    
    valid_statuses = [
        "Pending First Review", "Pending Second Review",
        "Approved to Publish", "Rejected"
    ]
    
    if not new_status or new_status not in valid_statuses:
        raise AppError(f"Invalid status. Must be one of: {valid_statuses}", 400, "INVALID_STATUS")
    
    # Get photo
    photo = photo_repo.get_photo(photo_id)
    if not photo:
        raise AppError("Photo not found", 404, "NOT_FOUND")
    
    # Update status
    old_state = photo["current_state"]
    photo_repo.update_photo_state(photo_id, new_status)
    
    # Log action
    action_log_repo.log_action({
        "action_id": str(uuid.uuid4()),
        "photo_id": photo_id,
        "user_id": admin_id,
        "action_type": "Admin Update",
        "previous_value": old_state,
        "new_value": new_status,
        "created_at": current_timestamp(),
    })
    
    return lambda_response(200, {
        "success": True,
        "photo_id": photo_id,
        "old_state": old_state,
        "new_state": new_status,
    })


def get_photo_history(event):
    """
    GET /photos/{id}/history
    """
    photo_id = get_path_parameter(event, "id")
    
    # Get reviews and actions
    reviews = review_repo.get_reviews_for_photo(photo_id)
    action_log_repo_instance = ActionLogRepository()
    actions = action_log_repo_instance.get_photo_actions(photo_id)
    
    return lambda_response(200, {
        "success": True,
        "photo_id": photo_id,
        "reviews": reviews,
        "actions": actions,
    })


def create_user(event, admin_id: str):
    """
    POST /admin/users
    
    Request body:
    {
        "email": "user@example.com",
        "name": "User Name",
        "role": "reviewer|admin",
        "send_invite": true
    }
    """
    body = validate_json_body(event)
    email = body.get("email")
    name = body.get("name")
    role = body.get("role", "reviewer")
    send_invite = body.get("send_invite", True)
    
    if not email or not name:
        raise AppError("Missing required fields: email, name", 400, "MISSING_FIELD")
    
    if role not in ["reviewer", "admin"]:
        raise AppError("Invalid role. Must be 'reviewer' or 'admin'", 400, "INVALID_ROLE")
    
    user_pool_id = os.environ.get("COGNITO_USER_POOL_ID")
    
    try:
        # Create user in Cognito
        temp_password = str(uuid.uuid4())[:12]
        response = cognito.admin_create_user(
            UserPoolId=user_pool_id,
            Username=email,
            UserAttributes=[
                {"Name": "email", "Value": email},
                {"Name": "email_verified", "Value": "true"},
                {"Name": "name", "Value": name},
            ],
            TemporaryPassword=temp_password,
            MessageAction="SUPPRESS" if not send_invite else "RESEND",
        )
        
        # Add user to group
        group_name = "admins" if role == "admin" else "reviewers"
        cognito.admin_add_user_to_group(
            UserPoolId=user_pool_id,
            Username=email,
            GroupName=group_name,
        )
        
        # Log action
        action_log_repo.log_action({
            "action_id": str(uuid.uuid4()),
            "action_type": "Create User",
            "user_email": email,
            "user_name": name,
            "role": role,
            "created_by": admin_id,
            "created_at": current_timestamp(),
        })
        
        return lambda_response(201, {
            "success": True,
            "user_email": email,
            "user_name": name,
            "role": role,
            "message": "User created successfully",
        })
    
    except cognito.exceptions.UsernameExistsException:
        raise AppError(f"User already exists: {email}", 409, "USER_EXISTS")
    except Exception as e:
        raise AppError(f"Failed to create user: {str(e)}", 500, "COGNITO_ERROR")
