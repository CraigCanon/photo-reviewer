"""
Placeholder for get_photo_url Lambda function
Generates presigned URLs for secure photo access from S3
"""
import boto3
import os
from botocore.config import Config
from utils import lambda_response, catch_errors, extract_user_context, get_path_parameter

s3_client = boto3.client("s3", config=Config(signature_version="s3v4"))

@catch_errors
def handler(event, context):
    """
    GET /photos/{id}/url
    Returns a presigned URL for accessing the photo from S3
    """
    # Extract user context
    user_context = extract_user_context(event)
    
    # Get photo ID
    photo_id = get_path_parameter(event, "id")
    
    # Generate presigned URL (valid for 1 hour)
    url = s3_client.generate_presigned_url(
        "get_object",
        Params={
            "Bucket": os.environ.get("PHOTOS_BUCKET"),
            "Key": f"photos/{photo_id}",
        },
        ExpiresIn=3600,
    )
    
    return lambda_response(200, {
        "success": True,
        "photo_id": photo_id,
        "url": url,
    })
