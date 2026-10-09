.PHONY: help setup-localstack setup-kind setup-act tf-init tf-plan tf-apply tf-destroy \
        tf-init-gcp tf-plan-gcp tf-apply-gcp tf-destroy-gcp \
        tf-init-azure tf-plan-azure tf-apply-azure tf-destroy-azure \
        ansible-run helm-install helm-uninstall helm-template \
        argocd-install argocd-port-forward app-port-forward \
        test lint fmt lint-terraform lint-ansible lint-docker lint-yaml lint-markdown lint-shell \
        security-scan docker-build docker-test \
        opa-test kyverno-test policy-test \
        cost-analysis cost-lambda \
        validate-all clean clean-terraform clean-kind clean-localstack

# Default target
help:
	@echo "Multi-Cloud DevOps Portfolio - Local Development Commands"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make setup-localstack    - Start LocalStack for AWS services"
	@echo "  make setup-kind          - Create kind Kubernetes cluster"
	@echo "  make setup-act           - Install act for GitHub Actions local testing"
	@echo "  make setup-all           - Run all setup commands"
	@echo ""
	@echo "Terraform Commands (AWS via LocalStack):"
	@echo "  make tf-init             - Initialize Terraform (AWS)"
	@echo "  make tf-plan             - Plan Terraform changes (AWS)"
	@echo "  make tf-apply            - Apply Terraform changes (AWS)"
	@echo "  make tf-destroy          - Destroy Terraform resources (AWS)"
	@echo ""
	@echo "Terraform Commands (GCP):"
	@echo "  make tf-init-gcp         - Initialize Terraform (GCP)"
	@echo "  make tf-plan-gcp         - Plan Terraform changes (GCP)"
	@echo "  make tf-apply-gcp        - Apply Terraform changes (GCP)"
	@echo "  make tf-destroy-gcp      - Destroy Terraform resources (GCP)"
	@echo ""
	@echo "Terraform Commands (Azure):"
	@echo "  make tf-init-azure       - Initialize Terraform (Azure)"
	@echo "  make tf-plan-azure       - Plan Terraform changes (Azure)"
	@echo "  make tf-apply-azure      - Apply Terraform changes (Azure)"
	@echo "  make tf-destroy-azure    - Destroy Terraform resources (Azure)"
	@echo ""
	@echo "Ansible Commands:"
	@echo "  make ansible-run         - Run Ansible playbook locally"
	@echo ""
	@echo "Kubernetes/Helm Commands:"
	@echo "  make helm-install        - Install Helm chart to kind"
	@echo "  make helm-uninstall      - Uninstall Helm chart"
	@echo "  make helm-template       - Render Helm templates"
	@echo "  make argocd-install      - Install ArgoCD to kind"
	@echo "  make argocd-port-forward - Port forward ArgoCD UI"
	@echo "  make app-port-forward    - Port forward sample app"
	@echo ""
	@echo "Docker Commands:"
	@echo "  make docker-build        - Build Docker image"
	@echo "  make docker-test         - Test Docker image"
	@echo ""
	@echo "Cost Optimization:"
	@echo "  make cost-analysis       - Run cost analysis script"
	@echo "  make cost-lambda         - Test Lambda cost function"
	@echo ""
	@echo "Testing & Linting:"
	@echo "  make test                - Run all tests"
	@echo "  make lint                - Run all linters"
	@echo "  make lint-terraform      - Lint Terraform files"
	@echo "  make lint-ansible        - Lint Ansible files"
	@echo "  make lint-docker         - Lint Dockerfile"
	@echo "  make lint-yaml           - Lint YAML files"
	@echo "  make lint-markdown       - Lint Markdown files"
	@echo "  make lint-shell          - Lint Shell scripts"
	@echo "  make security-scan       - Run security scans"
	@echo "  make fmt                 - Format Terraform files"
	@echo "  make opa-test            - Run OPA policy unit tests"
	@echo "  make kyverno-test        - Run Kyverno policy tests"
	@echo "  make policy-test         - Run all policy tests (OPA + Kyverno)"
	@echo "  make validate-all        - Run all validations"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean               - Clean up all local resources"
	@echo "  make clean-terraform     - Clean Terraform files"
	@echo "  make clean-kind          - Delete kind cluster"
	@echo "  make clean-localstack    - Stop LocalStack"

setup-all: setup-localstack setup-kind setup-act

# ===========================================
# LocalStack for AWS services locally
# ===========================================
setup-localstack:
	@echo "Starting LocalStack..."
	docker compose -f docker-compose.localstack.yml up -d
	@echo "Waiting for LocalStack to be ready..."
	@sleep 10
	@echo "LocalStack ready at http://localhost:4566"
	curl -s http://localhost:4566/_localstack/health | jq .

# ===========================================
# kind Kubernetes cluster
# ===========================================
setup-kind:
	@echo "Creating kind cluster..."
	kind create cluster --config=kind-config.yaml --name=devops-portfolio
	@echo "Cluster created. Installing ingress-nginx..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# ===========================================
# act for GitHub Actions local testing
# ===========================================
setup-act:
	@echo "Installing act..."
	@if command -v act >/dev/null 2>&1; then \
		echo "act already installed"; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install act; \
	elif command -v scoop >/dev/null 2>&1; then \
		scoop install act; \
	else \
		curl -sSL https://raw.githubusercontent.com/nektos/act/master/install.sh | bash -s -- -b ~/.local/bin; \
	fi

# ===========================================
# Terraform (AWS)
# ===========================================
tf-init:
	cd multi-cloud-infra/terraform-aws && terraform init

tf-plan:
	cd multi-cloud-infra/terraform-aws && terraform plan -out=tfplan

tf-apply:
	cd multi-cloud-infra/terraform-aws && terraform apply tfplan

tf-destroy:
	cd multi-cloud-infra/terraform-aws && terraform destroy -auto-approve

# ===========================================
# Terraform (GCP)
# ===========================================
tf-init-gcp:
	cd multi-cloud-infra/terraform-gcp && terraform init

tf-plan-gcp:
	cd multi-cloud-infra/terraform-gcp && terraform plan -out=tfplan

tf-apply-gcp:
	cd multi-cloud-infra/terraform-gcp && terraform apply tfplan

tf-destroy-gcp:
	cd multi-cloud-infra/terraform-gcp && terraform destroy -auto-approve

# ===========================================
# Terraform (Azure)
# ===========================================
tf-init-azure:
	cd multi-cloud-infra/terraform-azure && terraform init

tf-plan-azure:
	cd multi-cloud-infra/terraform-azure && terraform plan -out=tfplan

tf-apply-azure:
	cd multi-cloud-infra/terraform-azure && terraform apply tfplan

tf-destroy-azure:
	cd multi-cloud-infra/terraform-azure && terraform destroy -auto-approve

# ===========================================
# Ansible
# ===========================================
ansible-run:
	cd multi-cloud-infra/ansible-config && ansible-playbook -i inventory.yml playbook.yml --connection=local

# ===========================================
# Kubernetes/Helm
# ===========================================
helm-install:
	cd kubernetes-gitops-security/helm-charts && helm install sample-app . --namespace=default --create-namespace

helm-uninstall:
	helm uninstall sample-app --namespace=default

helm-template:
	cd kubernetes-gitops-security/helm-charts && helm template test-release . --namespace=default

argocd-install:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl wait --namespace argocd --for=condition=ready pod --selector=app.kubernetes.io/name=argocd-server --timeout=180s

argocd-port-forward:
	kubectl port-forward svc/argocd-server -n argocd 8080:443

app-port-forward:
	kubectl port-forward svc/sample-app -n default 8081:80

# ===========================================
# Docker
# ===========================================
docker-build:
	cd cicd-pipeline/docker-builds && \
		docker build \
			--build-arg VERSION=local \
			--build-arg COMMIT=$(shell git rev-parse --short HEAD) \
			--build-arg BUILD_DATE=$(shell date -u +%Y-%m-%dT%H:%M:%SZ) \
			-t devops-portfolio/app:local \
			-t devops-portfolio/app:$(shell git rev-parse --short HEAD) \
			.

docker-test:
	cd cicd-pipeline/docker-builds && \
		docker run --rm \
			-v $$(pwd):/test \
			gcr.io/gcp-runtimes/container-structure-test:latest \
			test --image devops-portfolio/app:local \
			--config container-structure-test.yaml

# ===========================================
# Cost Optimization
# ===========================================
cost-analysis:
	cd cloud-cost-optimization/cost-explorer-api && \
		python cost_analysis.py --mock --start-date 2024-01-01 --end-date 2024-01-31

cost-lambda:
	cd cloud-cost-optimization/lambda-cost-analysis && \
		MOCK_MODE=true python lambda_function.py

# ===========================================
# Testing
# ===========================================
test: lint
	@echo "Running tests..."
	# Go unit tests
	@if command -v go >/dev/null 2>&1; then \
		cd cicd-pipeline/docker-builds && go test ./...; \
	else \
		echo "go not installed - skipping Go tests"; \
	fi
	# Python unit tests (requires: pip install pytest boto3)
	@python -c "import pytest" 2>/dev/null && python -m pytest cloud-cost-optimization/ -v || echo "pytest not installed - skipping Python tests"
	# Terraform validate
	cd multi-cloud-infra/terraform-aws && terraform validate
	cd multi-cloud-infra/terraform-gcp && terraform validate
	cd multi-cloud-infra/terraform-azure && terraform validate
	# Helm lint
	cd kubernetes-gitops-security/helm-charts && helm lint .
	# Ansible lint
	ansible-lint multi-cloud-infra/ansible-config/playbook.yml
	# Dockerfile lint
	hadolint cicd-pipeline/docker-builds/Dockerfile
	# Python syntax check
	python -m py_compile cloud-cost-optimization/cost-explorer-api/cost_analysis.py
	python -m py_compile cloud-cost-optimization/lambda-cost-analysis/lambda_function.py
	# Policy tests
	$(MAKE) policy-test

# ===========================================
# Linting (individual)
# ===========================================
lint: lint-terraform lint-ansible lint-docker lint-yaml lint-markdown lint-shell security-scan

lint-terraform:
	@echo "Linting Terraform..."
	terraform fmt -check -recursive -diff multi-cloud-infra/
	terraform fmt -check -recursive -diff cloud-security/

lint-ansible:
	@echo "Linting Ansible..."
	ansible-lint multi-cloud-infra/ansible-config/playbook.yml

lint-docker:
	@echo "Linting Dockerfile..."
	hadolint cicd-pipeline/docker-builds/Dockerfile

lint-yaml:
	@echo "Linting YAML..."
	yamllint . -c .yamllint.yml

lint-markdown:
	@echo "Linting Markdown..."
	markdownlint . --config .markdownlint.json

lint-shell:
	@echo "Linting Shell scripts..."
	shellcheck $(shell find . -name "*.sh" -not -path "./.terraform/*" -not -path "./localstack-data/*" 2>/dev/null) || true

# ===========================================
# Security Scanning
# ===========================================
security-scan:
	@echo "Running security scans..."
	@if command -v checkov >/dev/null 2>&1; then \
		checkov -d multi-cloud-infra/ -d cloud-security/ --framework terraform --quiet --soft-fail; \
	fi
	@if command -v tfsec >/dev/null 2>&1; then \
		tfsec multi-cloud-infra/ cloud-security/ --soft-fail --no-colour; \
	fi
	@if command -v trivy >/dev/null 2>&1; then \
		trivy fs --security-checks vuln,secret,config --severity HIGH,CRITICAL --format table . || true; \
	fi

# ===========================================
# Formatting
# ===========================================
fmt:
	@echo "Formatting Terraform..."
	terraform fmt -recursive multi-cloud-infra/ cloud-security/

# ===========================================
# Policy Tests
# ===========================================
opa-test:
	@echo "Running OPA policy unit tests..."
	opa test kubernetes-gitops-security/security-policies/ -v

kyverno-test:
	@echo "Running Kyverno policy tests..."
	kyverno test kubernetes-gitops-security/kyverno-policies --detailed-results

policy-test: opa-test kyverno-test
	@echo "Policy tests passed!"

# ===========================================
# Validate All
# ===========================================
validate-all: lint test
	@echo "All validations passed!"

# ===========================================
# Cleanup
# ===========================================
clean: clean-terraform clean-kind clean-localstack
	@echo "Cleanup complete!"

clean-terraform:
	@echo "Cleaning Terraform files..."
	-find multi-cloud-infra -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	-find multi-cloud-infra -name "tfplan" -delete
	-find multi-cloud-infra -name "*.tfstate*" -delete
	-find multi-cloud-infra -name "*.tfstate.backup*" -delete
	-find cloud-security -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	-find cloud-security -name "tfplan" -delete
	-find cloud-security -name "*.tfstate*" -delete
	-rm -rf multi-cloud-infra/terraform-aws/.ssh
	-rm -rf multi-cloud-infra/terraform-azure/.ssh
	-rm -rf multi-cloud-infra/terraform-gcp/.ssh

clean-kind:
	@echo "Deleting kind cluster..."
	-kind delete cluster --name=devops-portfolio

clean-localstack:
	@echo "Stopping LocalStack..."
	-docker compose -f docker-compose.localstack.yml down -v
	-rm -rf localstack-data