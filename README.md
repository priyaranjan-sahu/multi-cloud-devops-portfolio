# Multi-Cloud DevOps & Security Portfolio

[![CI/CD Pipeline](https://github.com/priyaranjan-sahu/multi-cloud-devops-portfolio/actions/workflows/workflow.yaml/badge.svg)](https://github.com/priyaranjan-sahu/multi-cloud-devops-portfolio/actions/workflows/workflow.yaml)
[![Terraform](https://img.shields.io/badge/Terraform-1.9+-7B42BC?logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-3.14+-0F1689?logo=helm)](https://helm.sh/)
[![Ansible](https://img.shields.io/badge/Ansible-2.16+-EE0000?logo=ansible)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-24.0+-2496ED?logo=docker)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![LocalStack](https://img.shields.io/badge/LocalStack-3.5-FF4F00?logo=localstack)](https://localstack.cloud/)
[![Kind](https://img.shields.io/badge/Kind-0.22-0067B8?logo=kubernetes)](https://kind.sigs.k8s.io/)
[![Sponsor](https://img.shields.io/badge/Sponsor-❤️-EA4AAA?logo=github-sponsors)](https://github.com/sponsors/priyaranjan-sahu)

This repository showcases expertise in **Multi-Cloud (AWS, GCP, Azure)**, **DevOps**, **Cloud Security**, and **Automation** through hands-on projects. All implementations work **locally without cloud credentials** using LocalStack, Kind, and Act.

## 🔥 Projects Overview

Each folder contains a **real-world cloud project** covering **Infrastructure as Code (IaC), CI/CD, Kubernetes, Security, and Cost Optimization.**

### 1️⃣ **Multi-Cloud Infrastructure as Code**
**Purpose:** Deploy and manage cloud infrastructure using **Terraform** and **Ansible** across AWS, GCP, and Azure.

- `multi-cloud-infra/terraform-aws/` → Complete AWS infrastructure (VPC, EC2, ALB, S3, IAM, KMS, CloudTrail) - **works with LocalStack**
- `multi-cloud-infra/terraform-gcp/` → Complete GCP infrastructure (VPC, GCE, GCS, KMS, Load Balancer)
- `multi-cloud-infra/terraform-azure/` → Complete Azure infrastructure (VNet, VM, Blob Storage, Key Vault, Load Balancer)
- `multi-cloud-infra/ansible-config/` → Ansible playbook for local container/VM configuration

### 2️⃣ **Kubernetes with GitOps & Security**
**Purpose:** Manage Kubernetes clusters with **GitOps (ArgoCD)** and enforce security policies using **OPA & Helm.**

- `kubernetes-gitops-security/helm-charts/` → Production-ready Helm chart with HPA, NetworkPolicy, PodDisruptionBudget, ServiceMonitor
- `kubernetes-gitops-security/argocd-config/` → ArgoCD Application + AppProject for GitOps
- `kubernetes-gitops-security/security-policies/` → OPA/Rego policies for K8s admission control (20 unit tests, Rego v1)
- `kubernetes-gitops-security/kyverno-policies/` → Kyverno ClusterPolicies (immutable tags, required labels) with CLI test cases

### 3️⃣ **End-to-End CI/CD Pipeline**
**Purpose:** Automate software deployment using **Jenkins, GitHub Actions, and Docker.**

- `.github/workflows/workflow.yaml` → Complete CI/CD: lint, security scans, Go/Python tests, supply chain (SBOM, keyless signing, Trivy), gated deploy
- `cicd-pipeline/jenkins-pipelines/Jenkinsfile` → Jenkins pipeline compatible with `act` for local testing
- `cicd-pipeline/docker-builds/` → Multi-stage Dockerfile, Go app with unit tests, container structure tests

### 4️⃣ **Cloud Security & Compliance**
**Purpose:** Implement cloud security best practices using **Terraform Security, AWS GuardDuty, and CIS Benchmark.**

- `cloud-security/terraform-security/` → Secure baseline module (IAM, SG, KMS, S3, CloudTrail, Config, GuardDuty)
- `cloud-security/aws-guardduty/` → GuardDuty with threat intel, filters, CloudWatch alarms
- `cloud-security/compliance-checks/` → CIS AWS Foundations Benchmark as Terraform (password policy, CloudTrail, Config, monitoring)

### 5️⃣ **Automated Cloud Cost Optimization**
**Purpose:** Optimize cloud costs using **AWS Lambda, Cost Explorer API, and Reporting.**

- `cloud-cost-optimization/cost-explorer-api/` → Python script for cost analysis with anomaly detection
- `cloud-cost-optimization/lambda-cost-analysis/` → Lambda function for automated cost monitoring
- `cloud-cost-optimization/reports/` → Cost optimization strategies and expected savings

---

## 🚀 **Quick Start (Local Development - No Cloud Credentials Required!)**

### Prerequisites
- Docker Desktop / Docker Engine
- `kind` (Kubernetes in Docker)
- `terraform` >= 1.6
- `helm` >= 3.12
- `ansible` >= 2.15
- `python3` >= 3.10
- `make`

### One-Command Setup
```bash
# Clone the repo
git clone https://github.com/priyaranjan-sahu/multi-cloud-devops-portfolio.git
cd multi-cloud-devops-portfolio

# Install all local tools (LocalStack, Kind, Act)
make setup-all

# Run all validations
make validate-all
```

### Individual Service Setup

#### AWS with LocalStack
```bash
# Start LocalStack (AWS services locally)
make setup-localstack

# Deploy AWS infrastructure to LocalStack
make tf-init tf-plan tf-apply

# Verify resources
curl http://localhost:4566/_localstack/health
aws --endpoint-url=http://localhost:4566 ec2 describe-vpcs
aws --endpoint-url=http://localhost:4566 s3 ls
```

#### Kubernetes with Kind
```bash
# Create Kind cluster with ingress
make setup-kind

# Deploy Helm chart
make helm-install

# Access application
make app-port-forward
# Visit http://localhost:8081

# Install ArgoCD
make argocd-install
make argocd-port-forward
# Visit https://localhost:8080
```

#### CI/CD Local Testing
```bash
# Test GitHub Actions locally with act
act -W .github/workflows/workflow.yaml

# Test Jenkinsfile locally
act -j test -W cicd-pipeline/jenkins-pipelines/Jenkinsfile

# Or use the Makefile targets
make lint
make test
make security-scan
```

### Optional Deploy to Cloud (CI only)
The `deploy` job is **off by default** and only runs on push to `main` when enabled via repository variables:

| Variable / Secret | Purpose |
|-------------------|---------|
| `ENABLE_DEPLOY` (var) | Set to `true` to enable the deploy job |
| `AWS_DEPLOY_ROLE_ARN` (secret) | IAM role ARN assumed via OIDC for AWS deploy |

- The optional `test` integration job (LocalStack + Kind) only runs on `push`/`workflow_dispatch`.
- Supply chain steps (Trivy image scan, Syft SBOM, Cosign keyless signing) run on every `docker` job.

---

## 📋 **Available Make Commands**

| Command | Description |
|---------|-------------|
| `make setup-all` | Install LocalStack, Kind, Act |
| `make setup-localstack` | Start LocalStack for AWS |
| `make setup-kind` | Create Kind K8s cluster |
| `make tf-init` | Initialize Terraform (AWS) |
| `make tf-plan` | Plan Terraform changes |
| `make tf-apply` | Apply Terraform |
| `make tf-destroy` | Destroy Terraform |
| `make tf-init-gcp` | Initialize Terraform (GCP) |
| `make tf-init-azure` | Initialize Terraform (Azure) |
| `make ansible-run` | Run Ansible playbook locally |
| `make helm-install` | Install Helm chart to Kind |
| `make helm-template` | Render Helm templates |
| `make docker-build` | Build Docker image |
| `make docker-test` | Test Docker image |
| `make cost-analysis` | Run cost analysis (mock) |
| `make cost-lambda` | Test Lambda function (mock) |
| `make test` | Run all tests |
| `make lint` | Run all linters |
| `make security-scan` | Run security scans (Checkov, tfsec, Trivy) |
| `make fmt` | Format Terraform files |
| `make opa-test` | Run OPA policy unit tests |
| `make kyverno-test` | Run Kyverno policy tests |
| `make policy-test` | Run all policy tests (OPA + Kyverno) |
| `make validate-all` | Full validation pipeline |
| `make clean` | Clean up all resources |

---

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                     Multi-Cloud DevOps Portfolio                │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │     AWS      │  │     GCP      │  │    Azure     │          │
│  │  (LocalStack)│  │  (Terraform) │  │  (Terraform) │          │
│  │ VPC, EC2,    │  │ VPC, GCE,    │  │ VNet, VM,    │          │
│  │ ALB, S3,     │  │ GCS, KMS,    │  │ Blob, KV,    │          │
│  │ IAM, KMS,    │  │ LB, SQL      │  │ LB, KeyVault │          │
│  │ CloudTrail   │  │              │  │              │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                 │                 │                   │
│         └─────────────────┼─────────────────┘                   │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Terraform Security Module              │  │
│  │  IAM Roles • Security Groups • KMS • S3 • CloudTrail    │  │
│  │  Config • GuardDuty • Flow Logs • VPC Endpoints          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                     │
│         ┌─────────────────┼─────────────────┐                   │
│         ▼                 ▼                 ▼                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Kubernetes  │  │   GitOps     │  │   Security   │          │
│  │   (Kind)     │  │  (ArgoCD)    │  │   (OPA)      │          │
│  │ Helm Chart   │  │ Applications │  │ 100+ Rules   │          │
│  │ HPA, NetPol  │  │ AppProjects  │  │ Admission    │          │
│  │ PDB, SvcMon  │  │ Sync Waves   │  │ Controller   │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                 │                 │                   │
│         └─────────────────┼─────────────────┘                   │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      CI/CD Pipeline                       │  │
│  │  GitHub Actions • Jenkins • Docker • Security Scans      │  │
│  │  Lint → Validate → Test → Build → Deploy                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                     │
│         ┌─────────────────┼─────────────────┐                   │
│         ▼                 ▼                 ▼                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Ansible    │  │  Cost Opt    │  │  Compliance  │          │
│  │  Config Mgmt │  │  (Lambda +   │  │  (CIS Bench) │          │
│  │  Local/Remote│  │   Cost API)  │  │  as Code     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🧪 **Testing Locally**

### Full Integration Test
```bash
# This runs the complete pipeline locally
make setup-all
make validate-all

# Test AWS deployment to LocalStack
make tf-init tf-plan tf-apply

# Test K8s deployment to Kind
make helm-install
make app-port-forward
# curl http://localhost:8081/health

# Test cost optimization scripts
make cost-analysis
make cost-lambda
```

### Individual Component Tests
```bash
# Terraform validation for all clouds
cd multi-cloud-infra/terraform-aws && terraform validate
cd multi-cloud-infra/terraform-gcp && terraform validate
cd multi-cloud-infra/terraform-azure && terraform validate

# Helm chart validation
cd kubernetes-gitops-security/helm-charts && helm lint . && helm template test .

# Ansible validation
cd multi-cloud-infra/ansible-config && ansible-lint playbook.yml

# Docker validation
cd cicd-pipeline/docker-builds && hadolint Dockerfile

# OPA policy testing
opa test kubernetes-gitops-security/security-policies/ -v

# Kyverno policy testing
kyverno test kubernetes-gitops-security/kyverno-policies/

# Go unit tests
cd cicd-pipeline/docker-builds && go test ./... -race -count=1

# Python unit tests (mocked AWS)
python -m pytest cloud-cost-optimization -v

# Security scans
checkov -d multi-cloud-infra/ -d cloud-security/
tfsec multi-cloud-infra/ cloud-security/
trivy fs .
```

---

## 📁 **Repository Structure**

```
multi-cloud-devops-portfolio/
├── .github/
│   ├── workflows/workflow.yaml          # GitHub Actions CI/CD
│   └── dependabot.yml                   # Dependency updates
├── .yamllint.yml                        # YAML linting config
├── .markdownlint.json                   # Markdown linting config
├── docker-compose.localstack.yml        # LocalStack compose
├── kind-config.yaml                     # Kind cluster config
├── Makefile                             # Local dev commands
├── README.md                            # This file
├── cicd-pipeline/
│   ├── docker-builds/
│   │   ├── Dockerfile                   # Multi-stage Dockerfile
│   │   ├── main.go                      # Go sample app
│   │   ├── main_test.go                 # Go unit tests
│   │   ├── go.mod / go.sum              # Go dependencies (vetted)
│   │   └── container-structure-test.yaml
│   └── jenkins-pipelines/Jenkinsfile    # Jenkins pipeline
├── cloud-cost-optimization/
│   ├── requirements.txt                 # Python deps (Dependabot-managed)
│   ├── cost-explorer-api/
│   │   ├── cost_analysis.py
│   │   └── test_cost_analysis.py
│   ├── lambda-cost-analysis/
│   │   ├── lambda_function.py
│   │   └── test_lambda_function.py
│   └── reports/report.md
├── cloud-security/
│   ├── aws-guardduty/guardduty.tf
│   ├── compliance-checks/cis-benchmark.tf
│   └── terraform-security/security.tf
├── kubernetes-gitops-security/
│   ├── argocd-config/application.yaml
│   ├── helm-charts/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/ (deployment, service, ingress, hpa, netpol, pdb, etc.)
│   └── security-policies/
│       ├── policy.rego                  # OPA policies (Rego v1)
│       └── policy_test.rego             # OPA tests
│   └── kyverno-policies/
│       ├── policy-disallow-latest-tag.yaml
│       ├── policy-require-labels.yaml
│       └── kyverno-test.yaml            # CLI test cases
└── multi-cloud-infra/
    ├── ansible-config/
    │   ├── playbook.yml
    │   └── inventory.yml
    ├── terraform-aws/
    │   ├── main.tf                      # Complete AWS infra
    │   └── user_data.sh                 # EC2 bootstrap
    ├── terraform-gcp/main.tf            # Complete GCP infra
    └── terraform-azure/
        ├── main.tf                      # Complete Azure infra
        └── user_data.sh                 # VM bootstrap
```

---

## 🔒 **Security Features**

- **Policy as Code**: OPA/Rego (20 unit tests) + Kyverno (4 CLI test cases) for K8s admission control
- **Terraform Security**: Checkov, tfsec, Trivy integrated in CI/CD
- **Supply Chain**: Trivy image scan, Syft SBOM, Cosign keyless signing, SARIF upload
- **Dependency Management**: Dependabot for Actions, Go, Docker, Terraform, Python
- **Least Privilege IAM**: Dedicated roles for EC2, Lambda, K8s nodes
- **Encryption**: KMS for S3, EBS, RDS, Secrets Manager
- **Network Security**: Security Groups, Network Policies, VPC endpoints
- **Compliance**: CIS AWS Foundations Benchmark implemented as Terraform
- **Threat Detection**: GuardDuty with custom threat intel, CloudWatch alarms
- **Audit Logging**: CloudTrail with log validation, Config recorder

---

## 💰 **Cost Optimization Features**

- **Automated Analysis**: Daily Lambda checks Cost Explorer API
- **Anomaly Detection**: Statistical analysis (z-score, deviation %)
- **Budget Alerts**: SNS notifications for threshold breaches
- **RI/SP Monitoring**: Utilization tracking with <70% alerts
- **Rightsizing Recommendations**: Compute Optimizer integration
- **Storage Lifecycle**: Intelligent-Tiering, Glacier transitions
- **Expected Savings**: 40-50% reduction ($9K-15K/year)

---

## 📚 **Learning Resources**

| Topic | Resources |
|-------|-----------|
| Terraform | [Official Docs](https://developer.hashicorp.com/terraform/docs) |
| Kubernetes | [Kubernetes.io](https://kubernetes.io/docs/home/) |
| Helm | [Helm.sh](https://helm.sh/docs/) |
| ArgoCD | [ArgoCD Docs](https://argo-cd.readthedocs.io/) |
| OPA/Rego | [OPA Docs](https://www.openpolicyagent.org/docs/latest/) |
| GitHub Actions | [GitHub Actions Docs](https://docs.github.com/en/actions) |
| LocalStack | [LocalStack Docs](https://docs.localstack.cloud/) |
| Kind | [Kind Docs](https://kind.sigs.k8s.io/) |

---

## 💖 **Sponsor This Work**

If this repository helps you learn, land a job, or build something great — consider sponsoring to keep it maintained and evolving:

[![GitHub Sponsors](https://img.shields.io/badge/GitHub_Sponsors-Support_this_project-EA4AAA?style=for-the-badge&logo=github-sponsors)](https://github.com/sponsors/priyaranjan-sahu)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-Support-FFDD00?style=for-the-badge&logo=buy-me-a-coffee)](https://buymeacoffee.com/priyaranjan-sahu)
[![Patreon](https://img.shields.io/badge/Patreon-Become_a_Patron-F96854?style=for-the-badge&logo=patreon)](https://patreon.com/priyaranjan-sahu)

### **What Your Sponsorship Funds**

| Tier | Monthly | Benefits |
|------|---------|----------|
| ☕ **Coffee** | $5 | Name in README, Discord access |
| 🚀 **Contributor** | $25 | Priority issue review, monthly sync |
| 🏗️ **Architect** | $100 | 1hr architecture review/quarter, custom module |
| 🏢 **Enterprise** | $500 | Dedicated Slack, SLA, custom development |

> **Current Goal**: $500/mo to fund dedicated maintenance, new cloud provider modules (OCI, Alibaba), and video tutorials.

---

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run `make validate-all` to ensure quality
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

---

## 📜 License

This repository is open-source under the **MIT License**.

---

## 🙏 **Acknowledgments**

- [LocalStack](https://localstack.cloud/) for local AWS development
- [Kind](https://kind.sigs.k8s.io/) for local Kubernetes
- [Act](https://github.com/nektos/act) for local GitHub Actions testing
- [Checkov](https://www.checkov.io/) / [tfsec](https://github.com/aquasecurity/tfsec) / [Trivy](https://trivy.dev/) for security scanning
- [OPA](https://www.openpolicyagent.org/) for policy as code

---

🚀 *Star this repo if you find it useful! Contribute, fork, or reach out for improvements.*