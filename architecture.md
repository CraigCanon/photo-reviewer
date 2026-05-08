# Photo Review App Architecture (AWS Low-Cost MVP)
## Overview
This design targets low cost, low operational overhead, and correctness for review workflow rules.
- Frontend: SPA (React/Vue) on S3 + CloudFront
- Auth: Amazon Cognito (email/password, groups for Reviewer/Admin)
- API: API Gateway (HTTP API) + AWS Lambda
- Data: DynamoDB (Photos, PhotoReviews, PhotoActionLog, optional UserProfile)
- Images: S3 originals + optional thumbnails
- Observability/Security: CloudWatch, IAM least privilege, pre-signed URLs
## High-Level Architecture
1. User signs in via Cognito.
2. SPA receives JWT and calls API Gateway.
3. API Gateway routes to Lambda handlers.
4. Handlers invoke domain services (review workflow, rotation, admin ops).
5. Services read/write DynamoDB and append audit logs.
6. Photo assets are served securely from S3 (typically via pre-signed URLs).
7. CloudWatch captures logs/metrics for monitoring.
## Why this is inexpensive
- Pay-per-use components (`Lambda`, `HTTP API`, `DynamoDB on-demand`, `S3`)
- No always-on compute/database required for MVP
- Cognito reduces custom auth/security implementation effort
- Rotation represented as metadata (`orientation_degrees`) to avoid image rewrite costs
## Core AWS Services
### Frontend Hosting
- **Amazon S3**: static app hosting
- **Amazon CloudFront**: CDN, TLS termination, improved performance
### Authentication & Authorization
- **Amazon Cognito User Pool**
  - Email/password authentication
  - Group-based RBAC: `reviewer`, `admin`
  - JWT tokens for API authorization
### API Layer
- **Amazon API Gateway (HTTP API)**
  - Routes requests to Lambda
  - JWT authorizer with Cognito
### Compute
- **AWS Lambda**
  - Stateless handlers for review, rotation, queries, and admin actions
### Data
- **Amazon DynamoDB**
  - `Photos` table
  - `PhotoReviews` table (immutable review events)
  - `PhotoActionLog` table (audit trail)
  - Optional `UserProfile` table (if app-level profile metadata is needed)
### Storage
- **Amazon S3**
  - Original photo files
  - Optional generated thumbnails
### Monitoring/Security
- **Amazon CloudWatch**: logs, metrics, alarms
- **IAM**: least-privilege roles per Lambda
- Optional later: **AWS WAF** if publicly exposed beyond trusted users
## Data/Domain Mapping to Requirements
- `Photos.current_state` captures lifecycle states:
  - Pending First Review
  - Pending Second Review
  - Approved to Publish
  - Rejected
  - Finalized
- `Photos.orientation_degrees`: `0|90|180|270`
- `PhotoReviews`: records reviewer/admin decisions and stage (`first|second|admin_override`)
- `PhotoActionLog`: audit trail for review/rotate/finalize/admin-update actions
## Key Business Rule Enforcement
- First `Bad` => `Rejected` (terminal)
- First `Good` or `Additional Review Required` => `Pending Second Review`
- Second review must be by a different user
- Second `Good` => `Approved to Publish`
- Second `Bad` => `Rejected`
- Second `Additional Review Required` => remains flagged
- Admin may override/finalize from any state
## Concurrency Strategy (important)
Use DynamoDB conditional writes / transactions to prevent duplicate or conflicting updates:
- Ensure second reviewer differs from first reviewer
- Ensure current state still matches expected state when submitting
- Persist review event + photo state update + action log atomically (transaction)
## Suggested Minimal API
- `GET /photos?state=...`
- `GET /photos/{id}`
- `POST /photos/{id}/review`
- `POST /photos/{id}/rotate`
- `POST /photos/{id}/finalize` (admin)
- `POST /admin/users` (admin)
- `GET /photos/{id}/history` (admin; optional reviewer visibility)
## Code Objects to Build
### Cross-Cutting
- `AuthMiddleware`
  - Validates Cognito JWT
  - Extracts `userId`, `role`
  - Enforces role checks
- `RequestValidator`
  - Validates DTOs/schemas for request payloads and query params
### Domain Services
- `ReviewWorkflowService`
  - Encodes status transitions and stage logic
  - Determines resulting photo state from review input
- `EligibilityService`
  - Ensures reviewers can only review eligible photos
  - Blocks same-user second review
- `RotationService`
  - Applies +/- 90° orientation updates
  - Persists orientation and emits action logs
- `AdminService`
  - Admin status updates/finalization
  - User account/role management hooks (if needed beyond Cognito)
  - Reopen flows if supported
- `PhotoQueryService`
  - Reviewer work queue retrieval
  - Photo detail + history views
### Persistence Layer
- `PhotoRepository`
  - Photo reads/updates/state transitions
- `ReviewRepository`
  - Immutable review-event writes and lookups
- `ActionLogRepository`
  - Append-only audit logging
- `ConcurrencyGuard`
  - Wraps conditional write/transaction logic for conflict prevention
### API Layer
- `PhotoController` / Lambda handlers
  - `getPhotos`, `getPhoto`, `submitReview`, `rotatePhoto`
- `AdminController` / Lambda handlers
  - `finalizePhoto`, `updatePhotoStatus`, `createUser`, `getHistory`
### Testing
- `ReviewWorkflowService` unit tests for all acceptance criteria transitions
- Repository tests for conditional write behavior and race scenarios
- API integration tests for auth, RBAC, and happy/error paths
## How Components Fit Together
1. Client calls API with Cognito JWT.
2. `AuthMiddleware` authorizes and identifies caller role.
3. Handler validates input and calls domain service.
4. Domain service checks eligibility/rules.
5. Service executes transactional persistence through repositories + concurrency guard.
6. Action log is appended for every review/rotate/admin action.
7. API returns updated state/orientation/history summary to client.
## Implementation Phasing
### Phase 1 (MVP)
- Auth, photo listing/detail, review submit, rotation, admin finalize, audit logging
### Phase 2
- History UI improvements, richer filtering/search, operational alarms/dashboards
### Phase 3
- Optional cost/perf optimizations (thumbnails pipeline, cache tuning, WAF hardening)
If you switch out of plan mode, I’ll write this directly to ./architecture.md for you.
