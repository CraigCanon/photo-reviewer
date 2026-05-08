"""
Lambda handler for submitting photo reviews
Implements REQ-REV-1 through REQ-REV-8
"""
import json
import uuid
from utils import (
    lambda_response, catch_errors, extract_user_context, validate_json_body,
    get_path_parameter, current_timestamp, AppError, is_admin
)
from repositories import PhotoRepository, PhotoReviewRepository, ActionLogRepository
from services import ReviewWorkflowService, EligibilityService

# Initialize repositories
photo_repo = PhotoRepository()
review_repo = PhotoReviewRepository()
action_log_repo = ActionLogRepository()
eligibility_service = EligibilityService(review_repo)


@catch_errors
def handler(event, context):
    """
    POST /photos/{id}/review
    
    Request body:
    {
        "review_status": "Good|Bad|Additional Review Required"
    }
    """
    # Extract user context (validates JWT)
    user_context = extract_user_context(event)
    user_id = user_context["user_id"]
    is_admin_user = is_admin(user_context)
    
    # Get photo ID from path
    photo_id = get_path_parameter(event, "id")
    
    # Validate request body
    body = validate_json_body(event)
    review_status = body.get("review_status")
    
    if not review_status:
        raise AppError("Missing required field: review_status", 400, "MISSING_FIELD")
    
    if review_status not in ["Good", "Bad", "Additional Review Required"]:
        raise AppError(f"Invalid review_status: {review_status}", 400, "INVALID_STATUS")
    
    # Get photo
    photo = photo_repo.get_photo(photo_id)
    if not photo:
        raise AppError(f"Photo not found: {photo_id}", 404, "NOT_FOUND")
    
    # Check eligibility (unless admin)
    if not is_admin_user:
        first_reviewer_id = review_repo.get_first_reviewer(photo_id)
        if not ReviewWorkflowService.can_perform_review(photo, user_id, first_reviewer_id):
            raise AppError("You are not eligible to review this photo", 403, "INELIGIBLE")
    
    # Determine review stage
    reviews = review_repo.get_reviews_for_photo(photo_id)
    review_stage = "Admin Override" if is_admin_user else (
        "Second Review" if reviews and photo["current_state"] == "Pending Second Review" else "First Review"
    )
    
    # Create review record
    review_id = str(uuid.uuid4())
    review_record = {
        "review_id": review_id,
        "photo_id": photo_id,
        "reviewer_user_id": user_id,
        "review_status": review_status,
        "review_stage": review_stage,
        "created_at": current_timestamp(),
    }
    
    # Persist review
    if not review_repo.create_review(review_record):
        raise AppError("Failed to record review", 500, "DB_ERROR")
    
    # Calculate new state
    new_state = ReviewWorkflowService.get_resulting_state(
        photo["current_state"], review_status, review_stage, is_admin_user
    )
    
    # Update photo state
    if not photo_repo.update_photo_state(photo_id, new_state):
        raise AppError("Failed to update photo state", 500, "DB_ERROR")
    
    # Log action
    action_log_repo.log_action({
        "action_id": str(uuid.uuid4()),
        "photo_id": photo_id,
        "user_id": user_id,
        "action_type": "Review",
        "review_status": review_status,
        "review_stage": review_stage,
        "previous_value": photo["current_state"],
        "new_value": new_state,
        "created_at": current_timestamp(),
    })
    
    # Return updated photo state
    updated_photo = photo_repo.get_photo(photo_id)
    return lambda_response(200, {
        "success": True,
        "photo_id": photo_id,
        "review_id": review_id,
        "new_state": new_state,
        "photo": updated_photo,
    })
