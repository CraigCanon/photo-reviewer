"""
Business logic and domain services
"""
import logging
from typing import Dict, List, Optional
import uuid
from utils import current_timestamp, AppError

logger = logging.getLogger()


class ReviewWorkflowService:
    """Encodes photo review workflow rules and state transitions"""
    
    # Valid states
    PENDING_FIRST_REVIEW = "Pending First Review"
    PENDING_SECOND_REVIEW = "Pending Second Review"
    APPROVED_TO_PUBLISH = "Approved to Publish"
    REJECTED = "Rejected"
    FINALIZED = "Finalized"
    
    TERMINAL_STATES = {APPROVED_TO_PUBLISH, REJECTED, FINALIZED}
    
    @staticmethod
    def get_resulting_state(current_state: str, review_status: str, review_stage: str, is_admin: bool = False) -> str:
        """
        Determine the resulting state based on current state, review status, and stage.
        
        Implements BR-1 through BR-6 from specs
        """
        # BR-2: Bad reviews are always terminal (except for admin override)
        if review_status == "Bad":
            return ReviewWorkflowService.REJECTED
        
        # First review handling
        if review_stage == "First Review":
            if review_status == "Good":
                return ReviewWorkflowService.PENDING_SECOND_REVIEW
            elif review_status == "Additional Review Required":
                return ReviewWorkflowService.PENDING_SECOND_REVIEW
        
        # Second review handling
        elif review_stage == "Second Review":
            if review_status == "Good":
                return ReviewWorkflowService.APPROVED_TO_PUBLISH
            elif review_status == "Bad":
                return ReviewWorkflowService.REJECTED
            elif review_status == "Additional Review Required":
                # Remains in pending second review or escalates
                return ReviewWorkflowService.PENDING_SECOND_REVIEW
        
        # Admin override (BR-6)
        elif review_stage == "Admin Override":
            return ReviewWorkflowService.FINALIZED
        
        return current_state
    
    @staticmethod
    def can_perform_review(photo: Dict, user_id: str, first_reviewer_id: Optional[str]) -> bool:
        """
        Check if user can review this photo based on eligibility rules.
        
        Implements REQ-PHOTO-4 and BR-5
        """
        current_state = photo.get("current_state")
        
        # Can only review if in review-pending states
        if current_state not in [
            ReviewWorkflowService.PENDING_FIRST_REVIEW,
            ReviewWorkflowService.PENDING_SECOND_REVIEW,
        ]:
            return False
        
        # BR-5: Second reviewer must be different from first reviewer
        if current_state == ReviewWorkflowService.PENDING_SECOND_REVIEW and user_id == first_reviewer_id:
            return False
        
        return True


class EligibilityService:
    """Checks if user can perform actions on photos"""
    
    def __init__(self, photo_review_repo):
        self.photo_review_repo = photo_review_repo
    
    def can_review_photo(self, photo: Dict, user_id: str) -> bool:
        """Check if user is eligible to review this photo"""
        first_reviewer_id = self.photo_review_repo.get_first_reviewer(photo.get("photo_id"))
        return ReviewWorkflowService.can_perform_review(photo, user_id, first_reviewer_id)
    
    def get_reviewer_work_queue(self, user_id: str) -> List[Dict]:
        """Get photos available for a reviewer to review"""
        # This would join photos with reviews to find unreviewed ones
        # Simplified version - get all pending photos and filter
        return []


class RotationService:
    """Handles photo rotation operations"""
    
    @staticmethod
    def apply_rotation(current_orientation: int, direction: str) -> int:
        """
        Apply rotation to photo orientation.
        
        Args:
            current_orientation: 0, 90, 180, or 270
            direction: "clockwise" or "counterclockwise"
        
        Returns:
            New orientation (0, 90, 180, or 270)
        """
        if direction == "clockwise":
            return (current_orientation + 90) % 360
        elif direction == "counterclockwise":
            return (current_orientation - 90) % 360
        else:
            raise AppError(f"Invalid rotation direction: {direction}", 400, "INVALID_DIRECTION")


class AdminService:
    """Handles admin operations"""
    
    @staticmethod
    def finalize_photo(photo_id: str, final_status: str, admin_id: str, reason: Optional[str] = None) -> Dict:
        """
        Admin finalization of photo (BR-6).
        
        Records:
        - Admin user ID
        - Final status
        - Timestamp
        - Optional reason
        """
        return {
            "photo_id": photo_id,
            "final_status": final_status,
            "finalized_by_user_id": admin_id,
            "finalized_at": current_timestamp(),
            "reason": reason,
        }


class PhotoQueryService:
    """Handles complex photo queries for reviewers and admins"""
    
    def __init__(self, photo_repo, review_repo, action_log_repo):
        self.photo_repo = photo_repo
        self.review_repo = review_repo
        self.action_log_repo = action_log_repo
    
    def get_photos_for_review(self, state: str = None) -> List[Dict]:
        """Get photos pending review"""
        if state:
            return self.photo_repo.list_photos_by_state(state)
        return self.photo_repo.list_photos_by_state(ReviewWorkflowService.PENDING_FIRST_REVIEW)
    
    def get_photo_with_history(self, photo_id: str) -> Optional[Dict]:
        """Get photo with full review and action history"""
        photo = self.photo_repo.get_photo(photo_id)
        if not photo:
            return None
        
        photo["reviews"] = self.review_repo.get_reviews_for_photo(photo_id)
        photo["actions"] = self.action_log_repo.get_photo_actions(photo_id)
        
        return photo
