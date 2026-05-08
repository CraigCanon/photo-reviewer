"""
Lambda handler for rotating photos
Implements REQ-ROT-1 through REQ-ROT-5
"""
import json
import uuid
from utils import (
    lambda_response, catch_errors, extract_user_context, validate_json_body,
    get_path_parameter, current_timestamp, AppError
)
from repositories import PhotoRepository, ActionLogRepository
from services import RotationService

# Initialize repositories
photo_repo = PhotoRepository()
action_log_repo = ActionLogRepository()


@catch_errors
def handler(event, context):
    """
    POST /photos/{id}/rotate
    
    Request body:
    {
        "direction": "clockwise|counterclockwise"
    }
    """
    # Extract user context
    user_context = extract_user_context(event)
    user_id = user_context["user_id"]
    
    # Get photo ID
    photo_id = get_path_parameter(event, "id")
    
    # Validate request
    body = validate_json_body(event)
    direction = body.get("direction")
    
    if not direction or direction not in ["clockwise", "counterclockwise"]:
        raise AppError("Invalid direction. Must be 'clockwise' or 'counterclockwise'", 400, "INVALID_DIRECTION")
    
    # Get photo
    photo = photo_repo.get_photo(photo_id)
    if not photo:
        raise AppError(f"Photo not found: {photo_id}", 404, "NOT_FOUND")
    
    # Apply rotation
    current_orientation = photo.get("orientation_degrees", 0)
    new_orientation = RotationService.apply_rotation(current_orientation, direction)
    
    # Update photo
    if not photo_repo.update_photo_state(photo_id, photo["current_state"], new_orientation):
        raise AppError("Failed to update photo", 500, "DB_ERROR")
    
    # Log action
    action_log_repo.log_action({
        "action_id": str(uuid.uuid4()),
        "photo_id": photo_id,
        "user_id": user_id,
        "action_type": "Rotate",
        "previous_value": current_orientation,
        "new_value": new_orientation,
        "created_at": current_timestamp(),
    })
    
    return lambda_response(200, {
        "success": True,
        "photo_id": photo_id,
        "orientation_degrees": new_orientation,
    })
