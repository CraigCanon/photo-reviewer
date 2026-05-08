Requirements Document: Prom Photo Review Application
1. Purpose

The Photo Review Application supports a team of reviewers who evaluate prom photos after they are ingested into the system. Reviewers classify photos, optionally rotate them, and ensure photos marked for publication receive the required second review before approval.

The ingestion service and downstream publishing capabilities are out of scope and will be developed separately.

2. Scope
In Scope

The application shall support:

Viewing ingested photos
Reviewing photos
Assigning review statuses:
Good
Bad
Additional Review Required
Rotating photos:
90 degrees clockwise
90 degrees counterclockwise
Enforcing second-review rules
Admin user management
Admin override and finalization of photo status
Out of Scope

The following are not part of this application:

Copying photos from photographer cards
Reformatting photographer cards
Photo ingestion from storage
Publishing approved photos
Photographer workflow management
Storage infrastructure implementation
3. User Roles
Reviewer

A Reviewer may:

View photos available for review
Assign or update their own review decision
Rotate photos
Participate in first or second review
Review only photos they are eligible to review
Admin

An Admin may:

Do everything a Reviewer may do
Create user accounts
Create Reviewer or Admin accounts
Set user name, email, password, and role
Update the review status of any photo
Finalize a photo without requiring a second reviewer
View review history for any photo
4. Core Business Rules
BR-1: Review Statuses

Each review decision must use one of the following statuses:

Good
Bad
Additional Review Required
BR-2: Bad Photos

A photo marked Bad requires no further review.

BR-3: Good Photos

A photo marked Good by the first reviewer must be reviewed by a second, different reviewer.

A photo is approved for publishing only when a second reviewer also marks it Good.

BR-4: Additional Review Required

A photo marked Additional Review Required must be reviewed by a second, different reviewer.

BR-5: Second Reviewer Must Be Different

The same reviewer may not perform both the first and second review for the same photo.

BR-6: Admin Override

An Admin may finalize any photo status without requiring a second review.

BR-7: Rotation

Reviewers and Admins may rotate a photo 90 degrees clockwise or counterclockwise.

Rotation changes must persist and be visible to subsequent reviewers.

5. Photo Lifecycle
Initial State

When a photo is ingested, it enters the application in this state:

Pending First Review

State Transitions
Current State	Action	Actor	Resulting State
Pending First Review	Mark Bad	Reviewer/Admin	Rejected
Pending First Review	Mark Good	Reviewer/Admin	Pending Second Review
Pending First Review	Mark Additional Review Required	Reviewer/Admin	Pending Second Review
Pending Second Review	Second reviewer marks Good	Reviewer/Admin	Approved to Publish
Pending Second Review	Second reviewer marks Bad	Reviewer/Admin	Rejected
Pending Second Review	Second reviewer marks Additional Review Required	Reviewer/Admin	Additional Review Required
Any State	Admin finalizes status	Admin	Finalized
Any State	Admin updates status	Admin	Updated according to admin action
Terminal or Final States
Approved to Publish
Rejected
Finalized by Admin
6. Functional Requirements
6.1 Authentication

REQ-AUTH-1: The application shall require users to sign in before accessing photo review features.

REQ-AUTH-2: Users shall authenticate using email and password.

REQ-AUTH-3: The application shall associate every review action with the authenticated user.

6.2 User Management

REQ-USER-1: Admins shall be able to create user accounts.

REQ-USER-2: Each user account shall include:

Name
Email
Password
Role: Reviewer or Admin

REQ-USER-3: Admins shall be able to assign a user either the Reviewer or Admin role.

REQ-USER-4: Non-admin users shall not be able to create or manage user accounts.

6.3 Photo Viewing

REQ-PHOTO-1: Reviewers shall be able to view photos ingested into the application.

REQ-PHOTO-2: The application shall show each photo’s current review state.

REQ-PHOTO-3: The application shall indicate whether the photo is awaiting first review, second review, rejected, approved, or finalized.

REQ-PHOTO-4: The application shall prevent a reviewer from performing a second review on a photo they already reviewed.

6.4 Photo Review

REQ-REV-1: A Reviewer shall be able to assign one of the following statuses to an eligible photo:

Good
Bad
Additional Review Required

REQ-REV-2: The application shall record each review decision with:

Photo ID
Reviewer ID
Review status
Timestamp
Whether the review was first review, second review, or admin override

REQ-REV-3: If the first reviewer marks a photo Bad, the photo shall be marked Rejected.

REQ-REV-4: If the first reviewer marks a photo Good, the photo shall move to Pending Second Review.

REQ-REV-5: If the first reviewer marks a photo Additional Review Required, the photo shall move to Pending Second Review.

REQ-REV-6: If a second reviewer marks a photo Good, the photo shall be marked Approved to Publish.

REQ-REV-7: If a second reviewer marks a photo Bad, the photo shall be marked Rejected.

REQ-REV-8: If a second reviewer marks a photo Additional Review Required, the photo shall remain flagged as requiring additional review.

6.5 Photo Rotation

REQ-ROT-1: Reviewers and Admins shall be able to rotate a photo 90 degrees clockwise.

REQ-ROT-2: Reviewers and Admins shall be able to rotate a photo 90 degrees counterclockwise.

REQ-ROT-3: The application shall persist the current orientation of each photo.

REQ-ROT-4: Subsequent viewers shall see the photo using the latest saved orientation.

REQ-ROT-5: Rotation actions shall be recorded with user ID and timestamp.

6.6 Admin Review Controls

REQ-ADMIN-1: Admins shall be able to update the review status of any photo.

REQ-ADMIN-2: Admins shall be able to finalize a photo without second-review approval.

REQ-ADMIN-3: Admin finalization shall record:

Admin user ID
Final status
Timestamp
Optional reason or note

REQ-ADMIN-4: Admin-finalized photos shall not require further reviewer action unless reopened by an Admin.

7. Suggested Data Model
User
Field	Description
user_id	Unique user identifier
name	User’s full name
email	User’s email address
password_hash	Hashed password
role	Reviewer or Admin
created_at	Account creation timestamp
updated_at	Last update timestamp
Photo
Field	Description
photo_id	Unique photo identifier
source_file_path	Location or reference from ingestion service
thumbnail_path	Optional generated thumbnail location
orientation_degrees	0, 90, 180, or 270
current_state	Current workflow state
ingested_at	Timestamp when photo became available
finalized_at	Timestamp if finalized
finalized_by_user_id	Admin who finalized, if applicable
PhotoReview
Field	Description
review_id	Unique review identifier
photo_id	Related photo
reviewer_user_id	User who performed review
review_status	Good, Bad, or Additional Review Required
review_stage	First Review, Second Review, or Admin Override
created_at	Review timestamp
PhotoActionLog
Field	Description
action_id	Unique action identifier
photo_id	Related photo
user_id	User who performed action
action_type	Review, Rotate, Finalize, Admin Update
previous_value	Previous state or orientation
new_value	New state or orientation
created_at	Action timestamp
8. Permissions Matrix
Capability	Reviewer	Admin
Sign in	Yes	Yes
View photos	Yes	Yes
Review eligible photos	Yes	Yes
Rotate photos	Yes	Yes
Perform second review on own first review	No	Admin override only
Create users	No	Yes
Create Admin users	No	Yes
Update any photo status	No	Yes
Finalize without second review	No	Yes
View review history	Optional	Yes
9. Acceptance Criteria
Photo Review

AC-1: Given a newly ingested photo, when a reviewer marks it Bad, then the photo is marked Rejected and no second review is required.

AC-2: Given a newly ingested photo, when a reviewer marks it Good, then the photo moves to Pending Second Review.

AC-3: Given a photo pending second review, when the same reviewer attempts to review it again, then the application prevents the action.

AC-4: Given a photo pending second review, when a different reviewer marks it Good, then the photo is marked Approved to Publish.

AC-5: Given a photo pending second review, when a different reviewer marks it Bad, then the photo is marked Rejected.

AC-6: Given a photo pending second review, when a different reviewer marks it Additional Review Required, then the photo remains flagged for additional review.

Rotation

AC-7: Given a photo, when a reviewer rotates it clockwise, then the photo orientation changes by 90 degrees clockwise and persists.

AC-8: Given a rotated photo, when another reviewer opens it, then the reviewer sees the saved orientation.

Admin

AC-9: Given an Admin user, when they create a Reviewer account, then the new Reviewer can sign in.

AC-10: Given any photo, when an Admin finalizes its status, then the photo no longer requires second review.

AC-11: Given any photo, when an Admin updates its status, then the update is recorded in the audit history.

10. Non-Functional Requirements

REQ-NF-1: The application shall maintain an audit trail of review, rotation, and admin actions.

REQ-NF-2: Passwords shall be stored securely using a password hashing algorithm.

REQ-NF-3: The application shall prevent unauthorized access to admin features.

REQ-NF-4: The application shall support concurrent reviewers without allowing duplicate conflicting review submissions.

REQ-NF-5: The application shall be usable during a live prom-night review workflow.

REQ-NF-6: The system shall avoid destructive edits to original photo files unless explicitly designed and approved.

11. External Interfaces
Ingestion Service Interface

The ingestion service is expected to create photo records or otherwise make ingested photos available to the review application.

The review application assumes each ingested photo has:

Unique photo identifier
File location or storage reference
Ingestion timestamp
Initial state of Pending First Review
Publishing Interface

Publishing is out of scope.

The review application shall expose or store enough status information for a downstream publishing service to identify photos with state:

Approved to Publish
