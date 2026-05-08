"""
DynamoDB repository layer for data access
"""
import json
import os
from typing import Any, Dict, List, Optional
import boto3
from botocore.exceptions import ClientError
import logging

logger = logging.getLogger()

# Initialize DynamoDB resource
dynamodb = boto3.resource("dynamodb")

PHOTOS_TABLE = os.environ.get("PHOTOS_TABLE")
REVIEWS_TABLE = os.environ.get("PHOTOS_REVIEWS_TABLE")
ACTION_LOG_TABLE = os.environ.get("ACTION_LOG_TABLE")


class PhotoRepository:
    """Repository for Photo operations"""
    
    def __init__(self):
        self.table = dynamodb.Table(PHOTOS_TABLE)
    
    def get_photo(self, photo_id: str) -> Optional[Dict]:
        """Get a photo by ID"""
        try:
            response = self.table.get_item(Key={"photo_id": photo_id})
            return response.get("Item")
        except ClientError as e:
            logger.error(f"Error getting photo: {str(e)}")
            return None
    
    def list_photos_by_state(self, state: str, limit: int = 50) -> List[Dict]:
        """List photos by current state"""
        try:
            response = self.table.query(
                IndexName="current_state-index",
                KeyConditionExpression="current_state = :state",
                ExpressionAttributeValues={":state": state},
                Limit=limit,
            )
            return response.get("Items", [])
        except ClientError as e:
            logger.error(f"Error listing photos by state: {str(e)}")
            return []

    def list_photos(self, limit: int = 50) -> List[Dict]:
        """List photos across all states"""
        try:
            scan_kwargs = {}
            photos = []

            while len(photos) < limit:
                response = self.table.scan(**scan_kwargs)
                photos.extend(response.get("Items", []))

                last_evaluated_key = response.get("LastEvaluatedKey")
                if not last_evaluated_key:
                    break

                scan_kwargs["ExclusiveStartKey"] = last_evaluated_key

            return photos[:limit]
        except ClientError as e:
            logger.error(f"Error listing photos: {str(e)}")
            return []
    
    def update_photo_state(self, photo_id: str, new_state: str, orientation: Optional[int] = None) -> bool:
        """Update photo state and optionally orientation"""
        try:
            key = {"photo_id": photo_id}
            update_expr = "SET current_state = :state, updated_at = :updated_at"
            values = {":state": new_state, ":updated_at": int(__import__("time").time() * 1000)}
            
            if orientation is not None:
                update_expr += ", orientation_degrees = :orientation"
                values[":orientation"] = orientation
            
            self.table.update_item(
                Key=key,
                UpdateExpression=update_expr,
                ExpressionAttributeValues=values,
            )
            return True
        except ClientError as e:
            logger.error(f"Error updating photo state: {str(e)}")
            return False
    
    def create_photo(self, photo_id: str, source_file_path: str) -> bool:
        """Create a new photo entry"""
        try:
            timestamp = int(__import__("time").time() * 1000)
            self.table.put_item(
                Item={
                    "photo_id": photo_id,
                    "source_file_path": source_file_path,
                    "current_state": "Pending First Review",
                    "orientation_degrees": 0,
                    "ingested_at": timestamp,
                    "created_at": timestamp,
                    "updated_at": timestamp,
                }
            )
            return True
        except ClientError as e:
            logger.error(f"Error creating photo: {str(e)}")
            return False


class PhotoReviewRepository:
    """Repository for PhotoReview operations (immutable audit log)"""
    
    def __init__(self):
        self.table = dynamodb.Table(REVIEWS_TABLE)
    
    def create_review(self, review_data: Dict) -> Optional[str]:
        """Create a new review record"""
        try:
            self.table.put_item(Item=review_data)
            return review_data.get("review_id")
        except ClientError as e:
            logger.error(f"Error creating review: {str(e)}")
            return None
    
    def get_reviews_for_photo(self, photo_id: str) -> List[Dict]:
        """Get all reviews for a photo"""
        try:
            response = self.table.query(
                IndexName="photo_id-created_at-index",
                KeyConditionExpression="photo_id = :photo_id",
                ExpressionAttributeValues={":photo_id": photo_id},
            )
            return response.get("Items", [])
        except ClientError as e:
            logger.error(f"Error getting reviews for photo: {str(e)}")
            return []
    
    def get_user_reviews(self, user_id: str) -> List[Dict]:
        """Get all reviews by a user"""
        try:
            response = self.table.query(
                IndexName="reviewer_user_id-created_at-index",
                KeyConditionExpression="reviewer_user_id = :user_id",
                ExpressionAttributeValues={":user_id": user_id},
            )
            return response.get("Items", [])
        except ClientError as e:
            logger.error(f"Error getting user reviews: {str(e)}")
            return []
    
    def get_first_reviewer(self, photo_id: str) -> Optional[str]:
        """Get the first reviewer for a photo"""
        reviews = self.get_reviews_for_photo(photo_id)
        first_review = next((r for r in reviews if r.get("review_stage") == "First Review"), None)
        return first_review.get("reviewer_user_id") if first_review else None


class ActionLogRepository:
    """Repository for ActionLog operations (audit trail)"""
    
    def __init__(self):
        self.table = dynamodb.Table(ACTION_LOG_TABLE)
    
    def log_action(self, action_data: Dict) -> Optional[str]:
        """Create an action log entry"""
        try:
            self.table.put_item(Item=action_data)
            return action_data.get("action_id")
        except ClientError as e:
            logger.error(f"Error logging action: {str(e)}")
            return None
    
    def get_photo_actions(self, photo_id: str) -> List[Dict]:
        """Get all actions for a photo"""
        try:
            response = self.table.query(
                IndexName="photo_id-created_at-index",
                KeyConditionExpression="photo_id = :photo_id",
                ExpressionAttributeValues={":photo_id": photo_id},
            )
            return response.get("Items", [])
        except ClientError as e:
            logger.error(f"Error getting photo actions: {str(e)}")
            return []
    
    def get_user_actions(self, user_id: str) -> List[Dict]:
        """Get all actions by a user"""
        try:
            response = self.table.query(
                IndexName="user_id-created_at-index",
                KeyConditionExpression="user_id = :user_id",
                ExpressionAttributeValues={":user_id": user_id},
            )
            return response.get("Items", [])
        except ClientError as e:
            logger.error(f"Error getting user actions: {str(e)}")
            return []
