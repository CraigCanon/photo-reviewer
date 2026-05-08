#!/bin/bash
# Quick setup script for new development

set -e

echo "🚀 Photo Scanner Quick Setup"
echo "=============================="

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform not found. Install from https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install from https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found."
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Install from https://nodejs.org/"
    exit 1
fi

echo "✓ All prerequisites found"

# Verify AWS credentials
echo ""
echo "Verifying AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✓ AWS credentials valid (Account: $ACCOUNT_ID)"
else
    echo "❌ AWS credentials not configured. Run 'aws configure'"
    exit 1
fi

# Copy example files
echo ""
echo "Initializing configuration files..."

if [ ! -f "terraform/terraform.tfvars" ]; then
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    echo "✓ Created terraform/terraform.tfvars (edit with your values)"
else
    echo "✓ terraform/terraform.tfvars already exists"
fi

if [ ! -f ".gitignore" ]; then
    cat > .gitignore << 'EOF'
# Terraform
terraform/.terraform/
terraform/.terraform.lock.hcl
terraform/terraform.tfvars
terraform/terraform.tfstate*
terraform/tfplan
terraform/crash.log

# AWS
.aws/credentials
.aws/config

# Environment
.env
.env.local

# Python
backend/venv/
backend/__pycache__/
backend/*.pyc
backend/build/
backend/*.zip

# Node
frontend/node_modules/
frontend/dist/
frontend/.env.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
EOF
    echo "✓ Created .gitignore"
fi

# Initialize Terraform
echo ""
echo "Initializing Terraform..."
cd terraform
terraform init -upgrade
cd ..
echo "✓ Terraform initialized"

# Python setup
echo ""
echo "Setting up Python backend..."

if ! command -v python3.11 &> /dev/null; then
    echo "⚠️  Python 3.11 not found, using available python3"
    PYTHON_CMD="python3"
else
    PYTHON_CMD="python3.11"
fi

if [ ! -d "backend/venv" ]; then
    $PYTHON_CMD -m venv backend/venv
    source backend/venv/bin/activate
    pip install --upgrade pip setuptools wheel
    pip install -r backend/requirements.txt
    echo "✓ Python virtual environment created"
else
    source backend/venv/bin/activate
    echo "✓ Using existing Python virtual environment"
fi

# Node.js setup
echo ""
echo "Setting up frontend..."

cd frontend

if [ ! -d "node_modules" ]; then
    npm install
    echo "✓ Node modules installed"
else
    echo "✓ Node modules already installed"
fi

cd ..

# Verification
echo ""
echo "Running verification..."
echo ""

echo "📋 Next steps:"
echo ""
echo "1. Edit terraform/terraform.tfvars with your AWS account details:"
echo "   nano terraform/terraform.tfvars"
echo ""
echo "2. Review and plan infrastructure:"
echo "   make terraform-plan"
echo ""
echo "3. Deploy infrastructure:"
echo "   make terraform-apply"
echo ""
echo "4. Deploy backend (Lambda functions):"
echo "   make deploy-backend"
echo ""
echo "5. Build and deploy frontend:"
echo "   make deploy-frontend"
echo ""
echo "6. Create initial admin user in Cognito"
echo ""
echo "7. Access frontend at CloudFront URL from Terraform outputs"
echo ""
echo "For detailed deployment instructions, see: docs/DEPLOYMENT_GUIDE.md"
echo "For secrets management, see: docs/SECRETS_MANAGEMENT.md"
echo ""
echo "✅ Setup complete!"
