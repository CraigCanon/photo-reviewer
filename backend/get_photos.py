"""
Lambda handler for retrieving photos and review status
Implements REQ-PHOTO-1 through REQ-PHOTO-4
"""
import json
from utils import (
    lambda_response, catch_errors, extract_user_context, get_query_parameter
)
from repositories import PhotoRepository, PhotoReviewRepository
from services import PhotoQueryService, ReviewWorkflowService

# Initialize repositories
photo_repo = PhotoRepository()
review_repo = PhotoReviewRepository()
query_service = PhotoQueryService(photo_repo, review_repo, None)


@catch_errors
def handler(event, context):
    """
    GET /photos?state=...
    GET /photos/{id}
    """
    # Extract user context
    user_context = extract_user_context(event)
    
    # Check if this is a list or detail request
    if event.get("pathParameters") and event["pathParameters"].get("id"):
        return get_photo_detail(event["pathParameters"]["id"])
    else:
        return list_photos(event)


def list_photos(event):
    """
    GET /photos?state=Pending%20First%20Review
    """
    state = get_query_parameter(event, "state")
    limit = int(get_query_parameter(event, "limit", "50"))
    
    if limit < 1 or limit > 100:
        limit = 50
    
    normalized_state = state.strip() if isinstance(state, str) else ""
    list_all_states = not normalized_state or normalized_state.lower() == "all"

    if list_all_states:
        photos = photo_repo.list_photos(limit)
        response_state = "ALL"
    else:
        photos = photo_repo.list_photos_by_state(normalized_state, limit)
        response_state = normalized_state
    
    # Enrich with review count and reviewer info
    for photo in photos:
        reviews = review_repo.get_reviews_for_photo(photo["photo_id"])
        photo["review_count"] = len(reviews)
        photo["reviewers"] = list(set(r.get("reviewer_user_id") for r in reviews))
    
    return lambda_response(200, {
        "success": True,
        "state": response_state,
        "photos": photos,
        "count": len(photos),
    })


def get_photo_detail(photo_id: str):
    """
    GET /photos/{id}
    """
    photo = photo_repo.get_photo(photo_id)
    if not photo:
        return lambda_response(404, {
            "success": False,
            "error": "NOT_FOUND",
            "message": f"Photo not found: {photo_id}",
        })
    
    # Get review history
    reviews = review_repo.get_reviews_for_photo(photo_id)
    
    # Determine if second review is needed and by whom
    first_reviewer = next((r["reviewer_user_id"] for r in reviews if r.get("review_stage") == "First Review"), None)
    eligible_reviewers = [] if not first_reviewer else ["Any reviewer except: " + first_reviewer]
    
    photo["reviews"] = reviews
    photo["first_reviewer_id"] = first_reviewer
    photo["eligible_reviewers_note"] = eligible_reviewers
    
    return lambda_response(200, {
        "success": True,
        "photo": photo,
    })
