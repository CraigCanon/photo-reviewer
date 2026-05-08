# Photo Scanner Project Architecture

Complete photo review application built with AWS and Terraform.

## Directory Structure

```
photo-reviewer/
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                    # Core Terraform configuration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── cognito.tf                 # Cognito User Pool & Auth
│   ├── dynamodb.tf                # DynamoDB tables
│   ├── iam.tf                     # IAM roles & policies
│   ├── s3.tf                      # S3 buckets
│   ├── api_gateway.tf             # API Gateway configuration
│   ├── cloudfront.tf              # CloudFront CDN
│   ├── lambda.tf                  # Lambda function definitions
│   ├── lambda_deployment.tf       # Lambda deployment config
│   ├── terraform.tfvars.example   # Example variables file
│   └── .terraform/                # (generated)
│
├── backend/                       # Lambda function source code
│   ├── utils.py                   # Shared utilities & error handling
│   ├── repositories.py            # Data access layer
│   ├── services.py                # Business logic & domain services
│   ├── submit_review.py           # Review submission Lambda
│   ├── rotate_photo.py            # Photo rotation Lambda
│   ├── get_photos.py              # Photo listing/detail Lambda
│   ├── admin_operations.py        # Admin functions Lambda
│   ├── get_photo_url.py           # Presigned URL generation Lambda
│   ├── integration.md             # API route mappings
│   └── requirements.txt           # Python dependencies
│
├── frontend/                      # React SPA
│   ├── src/                       # React source code
│   ├── package.json               # Node dependencies
│   ├── STRUCTURE.md               # Frontend setup guide
│   └── dist/                      # (generated, built files)
│
├── docs/                          # Documentation
│   ├── SECRETS_MANAGEMENT.md      # How to handle secrets
│   ├── DEPLOYMENT_GUIDE.md        # Step-by-step deployment
│   └── ARCHITECTURE_DIAGRAM.md    # Visual architecture
│
├── scripts/                       # Deployment & utility scripts
│   ├── deploy-lambda.sh           # Deploy Lambda functions
│   ├── deploy-frontend.sh         # Deploy frontend to S3
│   └── verify-deployment.sh       # Verify deployment
│
├── .github/workflows/
│   └── deploy.yml                 # CI/CD pipeline (GitHub Actions)
│
├── specs.md                       # Product specifications
├── architecture.md                # System architecture
├── Makefile                       # Build automation
├── .gitignore                     # Git ignore rules
└── README.md                      # Project overview
```

## Key Components

### Infrastructure (Terraform)

- **Cognito**: User authentication with Reviewer/Admin groups
- **API Gateway**: HTTP API with JWT authorizer
- **Lambda**: 5+ functions for review, rotation, admin ops
- **DynamoDB**: Photos, PhotoReviews, PhotoActionLog tables
- **S3**: Frontend assets, photo storage, thumbnails
- **CloudFront**: CDN for frontend and API caching
- **KMS**: Encryption for S3 and DynamoDB
- **CloudWatch**: Logging and monitoring
- **SNS**: Email alerts for admins

### Backend (Python Lambda)

- **Services**: Review workflow, rotation, eligibility checks
- **Repositories**: DynamoDB data access
- **Handlers**: HTTP handlers for each API endpoint
- **Utils**: Error handling, auth, response formatting

### Frontend (React)

- **Authentication**: Cognito login via Amplify
- **Photo Management**: View, review, rotate
- **Admin Panel**: User management, photo finalization
- **Real-time Updates**: WebSocket planned for Phase 2

## Deployment Phases

### Phase 1: AWS Account & Terraform
1. Create AWS account
2. Configure IAM credentials
3. Deploy infrastructure with Terraform
4. Create initial admin user

### Phase 2: Lambda Deployment
1. Package Lambda functions
2. Deploy to AWS
3. Configure API Gateway routes
4. Test endpoints

### Phase 3: Frontend Deployment
1. Build React app
2. Upload to S3
3. Configure CloudFront
4. Test in browser

### Phase 4: Security & Testing
1. Enable WAF
2. Configure SSL/TLS
3. Run load tests
4. Set up monitoring

## Security Features

- **Encryption**: TLS for transit, KMS for DynamoDB/S3
- **Authentication**: Cognito email/password
- **Authorization**: JWT tokens, IAM policies
- **Audit Trail**: CloudTrail, CloudWatch Logs
- **Secrets Management**: AWS Secrets Manager
- **Network**: Pre-signed URLs for photo access
- **Rate Limiting**: API Gateway throttling

## Cost Optimization

- **Pay-per-use**: Lambda, API Gateway, DynamoDB on-demand
- **Data lifecycle**: S3 object lifecycle policies
- **Compression**: CloudFront gzip compression
- **Caching**: CloudFront + API Gateway
- **Log retention**: 7 days dev, 30 days prod

## Monitoring & Alarms

- **API Errors**: CloudWatch alarms for 4xx/5xx
- **Lambda Errors**: Alert on function failures
- **DynamoDB**: Throttling & capacity warnings
- **CloudFront**: Cache hit ratio, error rates
- **SNS**: Email notifications for critical events

## Next Steps

1. Edit `terraform/terraform.tfvars`
2. Run `make terraform-apply`
3. Run `make deploy-backend`
4. Build & deploy frontend with `make deploy-frontend`
5. Create admin user in Cognito
6. Test at CloudFront URL

See `docs/DEPLOYMENT_GUIDE.md` for detailed instructions.
