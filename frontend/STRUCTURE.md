"""
React frontend structure for Photo Review Application

File structure:
- public/
  - index.html
  - favicon.ico
- src/
  - components/
    - Auth/
    - PhotoList/
    - PhotoDetail/
    - PhotoReview/
    - PhotoRotate/
    - AdminPanel/
  - services/
    - api.js (API client)
    - auth.js (Cognito auth)
  - store/
    - photos.js (Redux or Zustand)
    - auth.js
  - pages/
    - Home.jsx
    - PhotoReview.jsx
    - AdminDashboard.jsx
  - App.jsx
  - main.jsx

Dependencies:
- react
- react-dom
- react-router-dom (routing)
- axios (HTTP client)
- @aws-amplify/auth (Cognito integration)
- @aws-amplify/ui-react (Cognito UI)
- zustand or redux (state management)
- tailwind or material-ui (styling)

Environment variables (from Terraform outputs):
- VITE_API_ENDPOINT (API Gateway URL)
- VITE_COGNITO_DOMAIN
- VITE_COGNITO_CLIENT_ID
- VITE_COGNITO_USER_POOL_ID
- VITE_AWS_REGION
"""

# See frontend/package.json and frontend/src/ directory for actual implementation
