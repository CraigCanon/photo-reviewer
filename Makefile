.PHONY: help terraform-init terraform-plan terraform-apply terraform-destroy \
         deploy-backend deploy-frontend deploy-all test lint verify clean

help:
	@echo "Photo Scanner Deployment Commands"
	@echo "=================================="
	@echo ""
	@echo "Setup:"
	@echo "  make terraform-init          - Initialize Terraform"
	@echo "  make terraform-plan          - Plan AWS infrastructure"
	@echo "  make terraform-apply         - Deploy AWS infrastructure"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-backend          - Deploy Lambda functions"
	@echo "  make deploy-frontend         - Build and deploy frontend"
	@echo "  make deploy-all              - Deploy backend and frontend"
	@echo ""
	@echo "Development:"
	@echo "  make lint                    - Lint Python backend"
	@echo "  make test                    - Run backend tests"
	@echo "  make verify                  - Verify all components"
	@echo ""
	@echo "Cleanup:"
	@echo "  make terraform-destroy       - Remove all AWS resources"
	@echo "  make clean                   - Clean build artifacts"

# Terraform commands
terraform-init:
	@echo "Initializing Terraform..."
	cd terraform && terraform init

terraform-plan:
	@echo "Planning Terraform deployment..."
	cd terraform && terraform plan -out=tfplan

terraform-apply:
	@echo "Applying Terraform configuration..."
	cd terraform && terraform apply tfplan
	@echo "✓ Infrastructure deployed!"

terraform-destroy:
	@echo "WARNING: This will destroy all AWS resources!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform && terraform destroy; \
	fi

# Backend deployment
deploy-backend:
	@echo "Deploying Lambda functions..."
	@bash scripts/deploy-lambda.sh

# Frontend deployment
deploy-frontend:
	@echo "Building frontend..."
	VITE_API_ENDPOINT="/api" \
	VITE_COGNITO_DOMAIN="$$(terraform -chdir=terraform output -raw cognito_domain)" \
	VITE_COGNITO_CLIENT_ID="$$(terraform -chdir=terraform output -json | jq -r '.cognito_client_id.value')" \
	VITE_COGNITO_USER_POOL_ID="$$(terraform -chdir=terraform output -raw cognito_user_pool_id)" \
	VITE_AWS_REGION="$${AWS_REGION:-us-east-1}" \
	sh -c 'cd frontend && npm install && npm run build'
	@echo "Deploying to S3..."
	@bash scripts/deploy-frontend.sh
	@echo "✓ Frontend deployed!"

# Combined deployment
deploy-all: deploy-backend deploy-frontend
	@echo "✓ Full deployment complete!"

# Development commands
lint:
	@echo "Linting Python code..."
	python -m pylint backend/*.py --disable=C0111,C0103 --max-line-length=120

test:
	@echo "Running tests..."
	python -m pytest tests/ -v

verify:
	@echo "Verifying deployment..."
	@bash scripts/verify-deployment.sh

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	rm -rf terraform/build
	rm -rf terraform/tfplan
	rm -rf frontend/dist
	rm -rf frontend/node_modules
	rm -rf backend/build
	rm -rf backend/*.zip
	@echo "✓ Cleanup complete"

# Show outputs
show-outputs:
	@terraform -chdir=terraform output -json | jq .

# Show logs
logs-api:
	aws logs tail /aws/apigateway/$$(terraform -chdir=terraform output -json | jq -r '.environment.value' | sed 's/-dev//') --follow

logs-lambda:
	aws logs tail /aws/lambda/$$(terraform -chdir=terraform output -json | jq -r '.environment.value' | sed 's/-dev//') --follow

# Local development
dev-frontend:
	cd frontend && npm install && npm run dev

dev-backend:
	pip install -r backend/requirements.txt
	python -m pytest tests/ -v --watch
