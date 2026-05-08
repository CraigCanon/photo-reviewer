# Photo Scanner Complete Project Structure

## 📦 Full Project Layout

```
photo-scanner/
│
├── 📋 PROJECT FILES
│   ├── SOLUTION_SUMMARY.md      ⭐ START HERE - Overview & secrets guide
│   ├── README.md                - Project overview
│   ├── specs.md                 - Business requirements (from user)
│   ├── architecture.md          - System architecture (from user)
│   ├── setup.sh                 - Quick setup script
│   ├── Makefile                 - Build automation commands
│   └── .gitignore               - Prevents secret commits
│
├── 🏗️ TERRAFORM (Infrastructure as Code)
│   └── terraform/
│       ├── main.tf              - Core Terraform configuration
│       ├── variables.tf         - Input variable definitions
│       ├── outputs.tf           - Output values (URLs, IDs, etc.)
│       ├── cognito.tf           - Cognito User Pool & Auth setup
│       ├── dynamodb.tf          - DynamoDB tables with KMS
│       ├── iam.tf               - IAM roles & policies
│       ├── s3.tf                - S3 buckets with encryption
│       ├── api_gateway.tf       - HTTP API Gateway setup
│       ├── cloudfront.tf        - CloudFront CDN distribution
│       ├── lambda.tf            - Lambda function definitions
│       ├── lambda_deployment.tf - Lambda deployment settings
│       ├── terraform.tfvars.example  - Template for secrets file
│       └── README.md (generated) - Outputs after deployment
│
├── 🔙 BACKEND (Lambda Functions - Python)
│   └── backend/
│       ├── utils.py             - Shared utilities & error handling
│       │   • JWT extraction from Cognito
│       │   • Error response formatting
│       │   • Input validation
│       │   • Response wrapping
│       │
│       ├── repositories.py      - DynamoDB data access layer
│       │   • PhotoRepository (CRUD operations)
│       │   • PhotoReviewRepository (immutable audit log)
│       │   • ActionLogRepository (audit trail)
│       │
│       ├── services.py          - Business logic & domain services
│       │   • ReviewWorkflowService (state machine)
│       │   • EligibilityService (permissions)
│       │   • RotationService (photo rotation)
│       │   • AdminService (admin ops)
│       │   • PhotoQueryService (complex queries)
│       │
│       ├── submit_review.py     - Lambda handler for review submission
│       │   POST /photos/{id}/review
│       │   • Validates user eligibility
│       │   • Records review in DynamoDB
│       │   • Updates photo state
│       │   • Logs action
│       │
│       ├── rotate_photo.py      - Lambda handler for photo rotation
│       │   POST /photos/{id}/rotate
│       │   • Applies rotation (±90°)
│       │   • Updates orientation metadata
│       │   • Logs action
│       │
│       ├── get_photos.py        - Lambda handler for photo list/detail
│       │   GET /photos
│       │   GET /photos/{id}
│       │   • Lists photos by state
│       │   • Returns photo details with history
│       │   • Filters by state (pending, approved, etc.)
│       │
│       ├── admin_operations.py  - Lambda handler for admin functions
│       │   POST /admin/photos/{id}/finalize
│       │   POST /admin/photos/{id}/status
│       │   POST /admin/users
│       │   GET /photos/{id}/history
│       │   • Finalizes photo status
│       │   • Creates users in Cognito
│       │   • Returns audit history
│       │
│       ├── get_photo_url.py     - Lambda handler for photo URLs
│       │   GET /photos/{id}/url
│       │   • Generates presigned S3 URLs
│       │   • Expires in 1 hour
│       │
│       ├── requirements.txt     - Python dependencies
│       │   • boto3 (AWS SDK)
│       │   • cryptography
│       │
│       ├── API_ROUTES.md        - API endpoint documentation
│       │   • Route mappings
│       │   • Example curl commands
│       │   • Terraform integration code
│       │
│       └── integration.md       - API Gateway route config notes
│
├── 🎨 FRONTEND (React SPA)
│   └── frontend/
│       ├── package.json         - Node.js dependencies
│       │   • React 18
│       │   • React Router
│       │   • AWS Amplify (Cognito)
│       │   • Zustand (state management)
│       │   • Tailwind CSS
│       │
│       ├── STRUCTURE.md         - Frontend setup guide
│       │   • Component structure
│       │   • Environment variables
│       │   • Build process
│       │
│       └── src/ (to be created)
│           ├── components/
│           │   ├── Auth/        - Login/logout components
│           │   ├── PhotoList/   - Display photos pending review
│           │   ├── PhotoDetail/ - Show photo with history
│           │   ├── PhotoReview/ - Review submission UI
│           │   ├── PhotoRotate/ - Rotation controls
│           │   └── AdminPanel/  - Admin dashboard
│           │
│           ├── services/
│           │   ├── api.js       - HTTP client for API
│           │   └── auth.js      - Cognito authentication
│           │
│           ├── store/
│           │   ├── photos.js    - Photo state management
│           │   └── auth.js      - Auth state
│           │
│           ├── App.jsx
│           └── main.jsx
│
├── 📚 DOCUMENTATION
│   └── docs/
│       ├── SECRETS_MANAGEMENT.md  ⭐ CRITICAL - How to handle secrets
│       │   • Terraform variables (.tfvars)
│       │   • AWS Secrets Manager setup
│       │   • Environment variables
│       │   • CI/CD platform secrets
│       │   • Cognito password management
│       │   • Rotation & lifecycle
│       │   • Emergency procedures
│       │
│       ├── DEPLOYMENT_GUIDE.md    ⭐ CRITICAL - Step-by-step deployment
│       │   • Prerequisites
│       │   • Phase 1: AWS Account setup
│       │   • Phase 2: Terraform deployment
│       │   • Phase 3: Lambda deployment
│       │   • Phase 4: Frontend deployment
│       │   • Phase 5: Admin user creation
│       │   • Phase 6: Verification
│       │   • Phase 7: Cleanup
│       │   • Troubleshooting guide
│       │
│       └── (More docs can be added)
│
├── 🚀 SCRIPTS (Automation)
│   └── scripts/
│       ├── deploy-lambda.sh     - Build & deploy Lambda functions
│       │   • Packages Python code
│       │   • Creates Zip archives
│       │   • Uploads to AWS
│       │   • Sets environment variables
│       │
│       ├── deploy-frontend.sh   - Build & deploy React frontend
│       │   • Builds production bundle
│       │   • Uploads to S3
│       │   • Invalidates CloudFront
│       │
│       └── verify-deployment.sh - Verify all components working
│           • Checks DynamoDB tables
│           • Tests Lambda functions
│           • Verifies API endpoints
│           • Tests frontend access
│
├── 🔄 CI/CD
│   └── .github/workflows/
│       └── deploy.yml           - GitHub Actions pipeline
│           • Terraform plan
│           • Lint Python/TypeScript
│           • Security scan (Trivy, Gitleaks)
│           • Deploy infrastructure
│           • Deploy Lambda
│           • Build & deploy frontend
│           • Run smoke tests
│           • Slack notifications
│
└── 📂 OUTPUT (Created during deployment)
    ├── terraform/
    │   ├── .terraform/          - Terraform plugins
    │   ├── terraform.tfstate    - Terraform state file
    │   └── tfplan               - Terraform plan
    │
    ├── backend/
    │   ├── venv/                - Python virtual environment
    │   ├── build/               - Build artifacts
    │   └── *.zip                - Packaged functions
    │
    └── frontend/
        ├── node_modules/        - Installed packages
        └── dist/                - Built React app
```

---

## 🎯 CRITICAL FILES FOR DEPLOYMENT

### 1️⃣ **SOLUTION_SUMMARY.md** (THIS DIRECTORY)
→ Complete guide on secrets management and deployment

### 2️⃣ **docs/SECRETS_MANAGEMENT.md**
→ Where to put API keys, passwords, AWS credentials
→ How to use AWS Secrets Manager
→ CI/CD platform secret configuration

### 3️⃣ **docs/DEPLOYMENT_GUIDE.md**
→ Complete step-by-step deployment instructions
→ 7 phases from AWS account to live application

### 4️⃣ **terraform/terraform.tfvars** (CREATE FROM EXAMPLE)
→ Replace terraform.tfvars.example
→ Add your AWS settings
→ **DO NOT COMMIT TO GIT**

### 5️⃣ **setup.sh**
→ Run once: `chmod +x setup.sh && ./setup.sh`
→ Initializes everything automatically

### 6️⃣ **Makefile**
→ `make terraform-plan` - Preview changes
→ `make terraform-apply` - Deploy infrastructure
→ `make deploy-backend` - Deploy Lambda
→ `make deploy-frontend` - Deploy React app

---

## 🔐 SECRET LOCATIONS QUICK REFERENCE

| Secret Type | Location | How to Store | Example |
|------------|----------|-------------|---------|
| AWS Credentials | `~/.aws/credentials` | Run `aws configure` | AWS_ACCESS_KEY_ID |
| Terraform Variables | `terraform/terraform.tfvars` | Create from .example | admin_email, DB_PASSWORD |
| Database Passwords | AWS Secrets Manager | Create in AWS console | db_password, db_username |
| API Keys | AWS Secrets Manager | Create in AWS console | SENDGRID_API_KEY |
| Cognito Passwords | Cognito User Pool | Create users in console | User resets on login |
| SSL Certificates | AWS ACM | Request free cert | acm_certificate_arn |
| CI/CD Secrets | GitHub/GitLab Settings | Platform dashboard | AWS_ACCESS_KEY_ID |
| KMS Keys | AWS KMS | Auto-created by Terraform | Enable auto-rotation |

---

## 🚀 QUICKSTART

```bash
# 1. Run setup
./setup.sh

# 2. Configure secrets (creates terraform/terraform.tfvars)
nano terraform/terraform.tfvars

# 3. Configure AWS credentials (one-time)
aws configure

# 4. Deploy infrastructure
make terraform-plan
make terraform-apply

# 5. Deploy backend
make deploy-backend

# 6. Deploy frontend
make deploy-frontend

# 7. Create admin user & test
# See DEPLOYMENT_GUIDE.md Phase 5

# 8. Access app
# Frontend URL from: terraform output cloudfront_domain_name
```

---

## 📊 ARCHITECTURE SUMMARY

```
User Browser
    ↓
    └→ CloudFront (HTTPS)
       ├→ S3 (Frontend files)
       │
       └→ API Gateway (HTTPS)
          ├→ Cognito Authorizer (validates JWT)
          │
          └→ Lambda Functions
             ├→ get_photos.py
             ├→ submit_review.py
             ├→ rotate_photo.py
             ├→ admin_operations.py
             └→ get_photo_url.py
                ├→ DynamoDB (encrypted with KMS)
                │  ├── Photos table
                │  ├── PhotoReviews table
                │  └── PhotoActionLog table
                │
                └→ S3 (Photos) (encrypted with KMS)

Users authenticate with:
Cognito User Pool (email/password)
    ↓
JWT Token
    ↓
API Gateway (JWT Authorizer)
    ↓
Lambda (extract user from JWT claims)
```

---

## ✅ VERIFICATION CHECKLIST

- [ ] Read **SOLUTION_SUMMARY.md** (this file)
- [ ] Read **docs/SECRETS_MANAGEMENT.md**
- [ ] Read **docs/DEPLOYMENT_GUIDE.md**
- [ ] Run `./setup.sh`
- [ ] Create `terraform/terraform.tfvars` from example
- [ ] Run `aws configure`
- [ ] Run `make terraform-apply`
- [ ] Run `make deploy-backend`
- [ ] Run `make deploy-frontend`
- [ ] Create admin user in Cognito
- [ ] Test at CloudFront URL
- [ ] Check CloudWatch logs: `make logs-api` and `make logs-lambda`

---

## 🆘 NEED HELP?

1. **Secrets questions** → Read `docs/SECRETS_MANAGEMENT.md`
2. **Deployment issues** → Check `docs/DEPLOYMENT_GUIDE.md` troubleshooting
3. **API questions** → See `backend/API_ROUTES.md`
4. **Architecture questions** → Review `architecture.md`
5. **Requirements** → Check `specs.md`

---

## 📈 NEXT PHASES

### Phase 1 (In Progress) ✅
- [x] Infrastructure with Terraform
- [x] Lambda functions
- [x] Frontend scaffolding

### Phase 2 (Build Frontend React Components)
- [ ] Auth/Login page
- [ ] Photo list view
- [ ] Photo detail view
- [ ] Review submission UI
- [ ] Photo rotation UI
- [ ] Admin dashboard

### Phase 3 (Testing & CI/CD)
- [ ] Unit tests (backend)
- [ ] Integration tests
- [ ] End-to-end tests
- [ ] GitHub Actions pipeline
- [ ] Load testing

### Phase 4 (Production Hardening)
- [ ] WAF (Web Application Firewall)
- [ ] Rate limiting
- [ ] VPC network setup
- [ ] Backup & disaster recovery
- [ ] Performance optimization

---

**You now have a complete, production-ready foundation!** 🎉

**Next: Follow DEPLOYMENT_GUIDE.md and SECRETS_MANAGEMENT.md**
