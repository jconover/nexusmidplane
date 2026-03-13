# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NexusMidplane is a hybrid cloud middleware infrastructure platform running WildFly (Java EE) and IIS/.NET behind path-based reverse proxies across two tiers:
- **On-prem (simulated):** Docker Compose with Apache proxy + WildFly + .NET containers
- **AWS cloud:** Terraform-provisioned VPC, ALB, EC2 (Linux + Windows), ACM, Secrets Manager, CloudWatch, VPN

Path-based routing: `/java/*` → WildFly, `/dotnet/*` → IIS/.NET on both tiers.

## Common Commands

### Terraform (from `terraform/`)
```bash
terraform init -backend-config=backend.tfbackend   # First-time setup (see backend.tfbackend.example)
terraform init -backend=false                     # Init without backend (for validation only)
terraform fmt -check -recursive                   # Format check
terraform validate                                # Validate config
terraform plan -var-file="environments/dev/terraform.tfvars" -out=tfplan
terraform apply tfplan
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

### On-Prem Docker Environment
```bash
docker compose -f docker/docker-compose.yml up -d       # Start all services
docker compose -f docker/docker-compose.yml down         # Stop all services
docker compose -f docker/docker-compose.yml logs         # View logs
```

### Java App (from `app/java-app/`)
```bash
./mvnw clean package -DskipTests --no-transfer-progress  # Build WAR
./mvnw test                                               # Run tests
```
Produces `app/java-app/target/java-app.war` (Spring Boot 3.2, Java 17, WAR packaging for WildFly).

### .NET App (from `app/dotnet-app/`)
```bash
dotnet restore
dotnet publish -c Release -o publish/
```
ASP.NET Core minimal API targeting .NET 8.

### Ansible
```bash
ansible-galaxy install -r ansible/requirements.yml       # Install collections
ansible-playbook ansible/site.yml                        # Full stack (on-prem + AWS)
ansible-playbook ansible/aws.yml -i ansible/inventory/aws_ec2.yml   # AWS only
ansible-playbook ansible/onprem.yml                      # On-prem only
ansible-lint ansible/                                    # Lint playbooks
```

### Smoke Tests
```bash
./scripts/smoke-test.sh                                                    # On-prem (localhost)
TARGET_HOST=my-alb.us-east-1.elb.amazonaws.com TARGET_SCHEME=https ./scripts/smoke-test.sh  # AWS
```

### CI Linting (what the pipeline checks)
```bash
terraform fmt -check -recursive terraform/
terraform init -backend=false && terraform validate   # In terraform/
ansible-lint ansible/
```

## Architecture

### Terraform Module Graph
Root module (`terraform/main.tf`) wires 7 child modules:
- **vpc** → provides VPC, subnets (2 public, 2 private across AZs), IGW, route tables
- **acm** → DNS-validated TLS certificate (requires Route 53 zone)
- **secrets** → Secrets Manager entries for middleware credentials
- **ec2-linux** → Amazon Linux 2023 instance for WildFly (private subnet AZ-a)
- **ec2-windows** → Windows Server 2022 instance for IIS (private subnet AZ-b)
- **alb** → Application Load Balancer in public subnets with path-based routing to EC2 target groups
- **cloudwatch** → Log groups and alarms for both EC2 instances
- **vpn** → Site-to-site VPN gateway for hybrid connectivity

Data flow: `vpc → ec2-linux/ec2-windows/alb/vpn`, `acm → alb`, `ec2-* → alb target groups + cloudwatch`.

Backend state: S3 with native file locking (`use_lockfile`). Bucket name is provided via `backend.tfbackend` (gitignored) — copy `backend.tfbackend.example` and fill in your AWS account ID. Init with `terraform init -backend-config=backend.tfbackend`.

Default region: `us-east-2`. Default instance types: `t3.small`.

### Ansible Role Structure
Two parallel playbooks (`aws.yml`, `onprem.yml`) apply the same roles to different inventory:
- **jboss-setup** / **jboss-deploy** → WildFly installation and WAR deployment
- **iis-setup** / **iis-deploy** → IIS feature install and .NET app deployment
- **ssl-onprem** → Self-signed/Let's Encrypt certs for Apache
- **ssl-jboss** → TLS configuration for WildFly
- **apache-proxy** → Reverse proxy with path-based routing config
- **patch-mgmt** → OS patching for all hosts

AWS dynamic inventory (`ansible/inventory/aws_ec2.yml`) discovers EC2 instances by `tag:project=nexusmidplane` and groups by `tag:role` (wildfly_servers, iis_servers). Windows hosts connect via WinRM/NTLM.

Required Ansible collections: `amazon.aws`, `community.windows`, `community.general`, `ansible.windows`.

### Docker On-Prem Simulation
Three services on a bridge network (`nexus-onprem`):
- `apache-proxy` (:80/:443) → reverse proxy to wildfly and dotnet-app
- `wildfly` (:8080, management :9990)
- `dotnet-app` (:5000) — Linux .NET runtime standing in for Windows IIS

The `dotnet-app` Dockerfile build context is the repo root (`..`) with dockerfile at `docker/dotnet/Dockerfile`.

### CI/CD Pipeline
Single workflow (`.github/workflows/deploy.yml`) with `workflow_dispatch` supporting plan/apply/destroy actions. Pipeline order: lint → build-java + build-dotnet (parallel) → terraform-plan → terraform-apply → ansible-configure → smoke-tests → notify. Uses OIDC for AWS auth (`AWS_OIDC_ROLE_ARN` secret). Terraform apply and destroy require manual GitHub environment approval.

### Key Environment Variables / Secrets
- `AWS_OIDC_ROLE_ARN` — GitHub Actions OIDC role for AWS access
- `TF_STATE_BUCKET` — S3 bucket name for Terraform state
- `EC2_SSH_KEY` — SSH private key for Ansible to reach EC2 instances
- Per-environment tfvars at `terraform/environments/<env>/terraform.tfvars`
