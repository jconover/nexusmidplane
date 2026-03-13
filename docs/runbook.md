# NexusMidplane — Operational Runbook

## Table of Contents

1. [Deploy a New Version](#1-deploy-a-new-version)
2. [Rollback Procedure](#2-rollback-procedure)
3. [SSL Certificate Renewal](#3-ssl-certificate-renewal)
4. [Troubleshooting Guide](#4-troubleshooting-guide)
5. [Monitoring & Alerts](#5-monitoring--alerts)
6. [Scaling Procedures](#6-scaling-procedures)
7. [Disaster Recovery](#7-disaster-recovery)

---

## 1. Deploy a New Version

### 1.1 AWS Deployment (via GitHub Actions)

**Prerequisites:** AWS OIDC role configured, `TF_STATE_BUCKET` secret set.

```bash
# Trigger via GitHub UI:
# Actions → NexusMidplane Deploy Pipeline → Run workflow
# Select: action=apply, environment=dev

# Or via CLI:
gh workflow run deploy.yml \
  -f action=apply \
  -f environment=dev
```

**Pipeline stages (automated):**
1. `lint` — Terraform fmt/validate, ansible-lint
2. `build-java` — Maven WAR, uploaded as artifact
3. `build-dotnet` — dotnet publish, uploaded as artifact
4. `terraform-plan` — plan output for review
5. `terraform-apply` — **requires manual approval** in GitHub environment
6. `ansible-configure` — deploys WAR + .NET binary to EC2
7. `smoke-tests` — curl health endpoints, fail pipeline on error

**Estimated time:** 12–18 minutes end to end.

---

### 1.2 On-Prem Deployment (local Docker)

```bash
# Full rebuild and restart
cd /path/to/nexusmidplane

# Rebuild apps
cd app/java-app && ./mvnw clean package -DskipTests && cd ../..
cd app/dotnet-app && dotnet publish -c Release -o publish/ && cd ../..

# Restart containers with new artifacts
docker compose -f docker/docker-compose.yml up -d --build

# Verify
bash scripts/smoke-test.sh
```

---

### 1.3 Ansible-Only Redeploy (no Terraform changes)

Use when you only need to push a new WAR/binary without infrastructure changes:

```bash
# Download latest artifacts from CI
gh run download --name java-app-war
gh run download --name dotnet-app-publish

# Run Ansible against AWS (dynamic inventory)
cd ansible
ansible-playbook \
  -i inventory/aws_ec2.yml \
  aws.yml \
  --private-key ~/.ssh/nexusmidplane.pem \
  -e "env=dev" \
  --tags "deploy"
```

---

## 2. Rollback Procedure

### 2.1 Application Rollback

```bash
# Step 1: Identify the last good artifact run
gh run list --workflow=deploy.yml --status=success --limit=5

# Step 2: Download previous artifact
gh run download <run-id> --name java-app-war --dir /tmp/rollback/

# Step 3: Deploy via Ansible
ansible-playbook \
  -i ansible/inventory/aws_ec2.yml \
  ansible/aws.yml \
  --private-key ~/.ssh/nexusmidplane.pem \
  -e "war_file=/tmp/rollback/app.war" \
  --tags "deploy"

# Step 4: Verify
TARGET_HOST=<alb-dns> bash scripts/smoke-test.sh
```

### 2.2 Infrastructure Rollback (Terraform)

```bash
# Option A: Revert to a previous Terraform state snapshot
aws s3 ls s3://$TF_STATE_BUCKET/nexusmidplane/dev/
aws s3 cp s3://$TF_STATE_BUCKET/nexusmidplane/dev/terraform.tfstate.backup \
  terraform/terraform.tfstate

# Then replan and apply
cd terraform
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars

# Option B: Git revert the Terraform change and re-run pipeline
git revert <bad-commit>
git push origin main
# Then trigger apply pipeline
```

### 2.3 ALB Target Group Rollback (quick swap)

If two target groups exist (blue/green pattern):

```bash
# Swap ALB listener rule to previous target group
aws elbv2 modify-listener \
  --listener-arn <listener-arn> \
  --default-actions Type=forward,TargetGroupArn=<previous-tg-arn>
```

---

## 3. SSL Certificate Renewal

### 3.1 On-Prem (Apache + WildFly)

**Check expiry first:**
```bash
bash scripts/ssl-renew.sh check
# or manually:
openssl x509 -enddate -noout -in /etc/ssl/nexusmidplane/nexusmidplane.internal.crt
```

**Self-signed renewal (dev/local):**
```bash
DOMAIN=nexusmidplane.internal bash scripts/ssl-renew.sh self-signed
```

**CA-signed renewal (production):**
```bash
# Step 1: Generate new CSR
DOMAIN=nexusmidplane.internal bash scripts/ssl-renew.sh ca-signed

# Step 2: Submit CSR to CA (DigiCert, Entrust, internal CA)
cat /etc/ssl/nexusmidplane/nexusmidplane.internal.csr

# Step 3: Receive .crt from CA, place at /etc/ssl/nexusmidplane/
# Step 4: Install to Apache + WildFly
DOMAIN=nexusmidplane.internal bash scripts/ssl-renew.sh install-ca

# Step 5: Restart Docker containers to pick up new cert
docker compose -f docker/docker-compose.yml restart apache wildfly
```

**Maintenance window:** Plan 30–60 minutes. Schedule outside business hours.

### 3.2 AWS (ACM)

ACM certificates auto-renew 60 days before expiry. No manual action required.

```bash
# Verify ACM cert status
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --query 'Certificate.{Status:Status,NotAfter:NotAfter,RenewalStatus:RenewalSummary.RenewalStatus}'
```

If renewal fails (DNS validation issue):
```bash
# Re-add CNAME record to Route 53
aws acm describe-certificate --certificate-arn <arn> \
  --query 'Certificate.DomainValidationOptions[*].ResourceRecord'
# Add the CNAME to Route 53 manually if missing
```

---

## 4. Troubleshooting Guide

### 4.1 Java app returning 503

**Symptoms:** ALB or Apache returns 503/Bad Gateway for `/java/*` paths.

```bash
# 1. Check WildFly status
# AWS:
ssh -i ~/.ssh/nexusmidplane.pem ec2-user@<ec2-ip> \
  'sudo systemctl status wildfly'
# On-prem:
docker compose -f docker/docker-compose.yml ps wildfly
docker compose -f docker/docker-compose.yml logs wildfly --tail=50

# 2. Check WAR deployment
# AWS:
ssh ec2-user@<ec2-ip> \
  'ls -la /opt/wildfly/standalone/deployments/'
# On-prem:
docker exec nexus-wildfly ls /opt/jboss/wildfly/standalone/deployments/

# 3. Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <java-tg-arn>

# 4. Check security group allows ALB → EC2 :8080
aws ec2 describe-security-groups --group-ids <sg-id>
```

### 4.2 Terraform apply fails with dependency error

```bash
# Re-run with targeted apply to resolve ordering
terraform apply -target=aws_vpc.main
terraform apply -target=aws_subnet.private
terraform apply  # then full apply
```

### 4.3 Ansible "Unreachable" errors

```bash
# Test SSH connectivity
ansible all -i ansible/inventory/aws_ec2.yml -m ping \
  --private-key ~/.ssh/nexusmidplane.pem

# Check dynamic inventory resolves correctly
ansible-inventory -i ansible/inventory/aws_ec2.yml --list

# Common fixes:
# - EC2 instance not yet Running: wait 60-90s after terraform apply
# - Security group missing :22 from your IP
# - Wrong key pair name in terraform.tfvars
```

### 4.4 Docker containers not starting (on-prem)

```bash
# Inspect container exit reason
docker compose -f docker/docker-compose.yml ps
docker compose -f docker/docker-compose.yml logs <service>

# Common causes:
# - Port 80/443/8080 already in use: sudo lsof -i :80
# - Volume mount path wrong: check docker-compose.yml volumes
# - Java app WAR not built: run setup-local.sh
# - Missing cert files: run ssl-renew.sh self-signed
```

### 4.5 GitHub Actions OIDC auth failure

```bash
# Verify trust policy includes the repo
aws iam get-role --role-name GithubActionsOIDC \
  --query 'Role.AssumeRolePolicyDocument'

# Should include:
# "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/nexusmidplane:*"

# Verify GitHub Actions workflow has:
# permissions:
#   id-token: write
#   contents: read
```

---

## 5. Monitoring & Alerts

### 5.1 CloudWatch dashboards

```bash
# View recent application logs
aws logs tail /nexusmidplane/java-app  --follow
aws logs tail /nexusmidplane/dotnet-app --follow

# Query error rate (last 1 hour)
aws logs start-query \
  --log-group-name /nexusmidplane/java-app \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'filter @message like /ERROR/ | stats count() by bin(5m)'
```

### 5.2 ALB health

```bash
# Check unhealthy targets
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`]'

# Get ALB access logs (if enabled)
aws s3 ls s3://$TF_STATE_BUCKET/alb-logs/ | tail -20
```

### 5.3 On-prem health

```bash
# Docker stats
docker stats --no-stream

# Health check status
docker inspect --format='{{.State.Health.Status}}' nexus-wildfly
docker inspect --format='{{.State.Health.Status}}' nexus-dotnet
docker inspect --format='{{.State.Health.Status}}' nexus-apache
```

### 5.4 Alert thresholds (recommended)

| Metric | Threshold | Action |
|---|---|---|
| ALB 5xx error rate | > 1% over 5 min | Page on-call |
| EC2 CPU | > 80% for 10 min | Scale out |
| Disk usage | > 85% | Clear old WAR deployments |
| Cert expiry | < 30 days | Trigger renewal |
| EC2 status check | Fail | Auto-recover or replace |

---

## 6. Scaling Procedures

### 6.1 Vertical scaling (resize EC2)

```bash
# Update terraform.tfvars
# instance_type = "t3.medium"  # was t3.small

# Plan and apply
terraform plan -var-file=environments/dev/terraform.tfvars
# Review: ~2 min downtime during stop/start
terraform apply -var-file=environments/dev/terraform.tfvars
```

### 6.2 Horizontal scaling (add EC2 instances)

```bash
# Update terraform.tfvars
# java_instance_count  = 2  # was 1
# dotnet_instance_count = 2

terraform apply -var-file=environments/dev/terraform.tfvars
# ALB auto-distributes traffic to new instances after health check passes
```

### 6.3 On-prem scaling

```bash
# Scale a Docker service
docker compose -f docker/docker-compose.yml up -d --scale wildfly=2

# Note: Apache mod_proxy_balancer config must list both backends
# Edit docker/apache/conf/vhost.conf and add BalancerMember entries
```

---

## 7. Disaster Recovery

### 7.1 RTO / RPO targets (reference)

| Tier | RTO | RPO | Strategy |
|---|---|---|---|
| AWS | 15 min | 0 (stateless app) | Re-run Terraform + Ansible |
| On-prem | 30 min | Last Docker image | Rebuild from git + run setup-local.sh |

### 7.2 Full AWS environment rebuild

```bash
# 1. Ensure Terraform state is intact in S3
aws s3 ls s3://$TF_STATE_BUCKET/nexusmidplane/prod/

# 2. Re-provision infrastructure
cd terraform
terraform init
terraform apply -var-file=environments/prod/terraform.tfvars -auto-approve

# 3. Re-deploy applications
cd ../ansible
ansible-playbook -i inventory/aws_ec2.yml aws.yml \
  --private-key ~/.ssh/nexusmidplane.pem

# 4. Verify
TARGET_HOST=$(cd ../terraform && terraform output -raw alb_dns_name) \
  bash ../scripts/smoke-test.sh
```

**Estimated time:** 15–20 minutes (EC2 provisioning + app deployment).

### 7.3 On-prem rebuild

```bash
git clone https://github.com/YOUR_ORG/nexusmidplane.git
cd nexusmidplane
bash scripts/setup-local.sh
```

**Estimated time:** 10–15 minutes (including Docker pulls and builds).
