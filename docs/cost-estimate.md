# NexusMidplane — AWS Cost Estimate

All prices are US East (N. Virginia) on-demand rates as of early 2024. Actual costs vary by region, usage patterns, and negotiated discounts.

---

## Dev Environment

Intended for active development and portfolio demos. Resources are sized minimally and should be **stopped when not in use**.

| Service | Configuration | Unit Cost | Monthly Est. |
|---|---|---|---|
| EC2 (Java/WildFly) | t3.small, 2 vCPU, 2 GB RAM | $0.0208/hr | **$15.00** |
| EC2 (.NET/Kestrel) | t3.small, 2 vCPU, 2 GB RAM | $0.0208/hr | **$15.00** |
| Application Load Balancer | 1 ALB, ~1 LCU | $0.008/hr + $0.008/LCU | **$8.00** |
| NAT Gateway | 1 per AZ, ~1 GB/day data | $0.045/hr + $0.045/GB | **$33.00** |
| S3 | State + artifacts, ~1 GB | $0.023/GB + requests | **$1.00** |
| CloudWatch Logs | ~500 MB/month ingestion | $0.50/GB | **$1.00** |
| Data transfer | ~5 GB out/month | $0.09/GB | **$0.45** |
| VPC (subnets, SGs, IGW) | No charge | — | **$0.00** |
| IAM / OIDC | No charge | — | **$0.00** |

**Dev total: ~$73/month** (24/7 running)

> **Cost tip:** Stop EC2 instances and delete the NAT Gateway when not in use. EBS volumes continue to accrue cost while stopped (~$0.08/GB-month). A t3.small with 20 GB EBS adds ~$1.60/month even when stopped.

---

## Production Environment

Sized for light production workloads with basic redundancy. Multi-AZ for the ALB, EC2 instances upgraded to t3.medium.

| Service | Configuration | Unit Cost | Monthly Est. |
|---|---|---|---|
| EC2 (Java/WildFly) | t3.medium, 2 vCPU, 4 GB RAM | $0.0416/hr | **$30.00** |
| EC2 (.NET/Kestrel) | t3.medium, 2 vCPU, 4 GB RAM | $0.0416/hr | **$30.00** |
| Application Load Balancer | 1 ALB, multi-AZ, ~5 LCU | $0.008/hr + $0.008/LCU | **$10.00** |
| NAT Gateway | 2 per AZ (HA), ~5 GB/day | $0.045/hr × 2 + data | **$68.00** |
| S3 | State + artifacts + ALB logs, ~5 GB | $0.023/GB | **$2.00** |
| CloudWatch Logs | ~2 GB/month ingestion | $0.50/GB | **$3.00** |
| CloudWatch Alarms | 5 alarms | $0.10/alarm | **$0.50** |
| ACM Certificate | Included with ALB | Free | **$0.00** |
| Data transfer | ~20 GB out/month | $0.09/GB | **$1.80** |
| EBS (gp3) | 20 GB × 2 instances | $0.08/GB | **$3.20** |

**Prod total: ~$148/month**

---

## Cost Comparison: On-Prem vs AWS

| Cost Factor | On-Prem (Simulated) | AWS Dev | AWS Prod |
|---|---|---|---|
| Compute | $0 (laptop/server) | ~$30/mo | ~$60/mo |
| Load balancing | $0 (Apache) | ~$8/mo | ~$10/mo |
| Networking | $0 | ~$33/mo (NAT) | ~$68/mo (NAT x2) |
| TLS certs | Staff time (~2hr/yr) | $0 (ACM) | $0 (ACM) |
| Backups/snapshots | Manual | S3 versioning | S3 versioning |
| **Total visible** | **$0** | **~$73/mo** | **~$148/mo** |
| **Hidden costs** | Server HW, power, datacenter space, staff | — | — |

> **Portfolio note:** On-prem "free" compute is an illusion at scale — hardware depreciation, power ($0.10–0.15/kWh per server), datacenter colocation ($500–2000/rack/month), and staff time often exceed AWS costs for small deployments. The break-even point for owned vs. cloud infrastructure is typically 3–5 years at enterprise scale.

---

## Cost Optimization Strategies

### Immediate (Dev Environment)

```bash
# Stop EC2 instances when not in use (saves ~$1/day per instance)
aws ec2 stop-instances --instance-ids <java-ec2-id> <dotnet-ec2-id>

# Delete NAT Gateway when not actively using (saves ~$1.08/day)
# Re-create with Terraform when needed:
# terraform apply -target=aws_nat_gateway.main

# Use S3 lifecycle rules to expire old artifacts
# (configured in terraform/modules/s3/main.tf)
```

### Medium-Term

| Strategy | Monthly Savings | Trade-off |
|---|---|---|
| Reserved Instances (1-yr) | ~40% on EC2 | Upfront commitment |
| Savings Plans (compute) | ~40% on EC2 | Flexible but committed |
| t3a vs t3 instances | ~10% | AMD CPU instead of Intel |
| Single NAT Gateway (dev) | ~$33 | No AZ-redundancy |
| Spot Instances (dev/CI) | ~70% on EC2 | Interruption risk |

### Architecture-Level

| Strategy | Notes |
|---|---|
| AWS Lambda for lightweight endpoints | Eliminate EC2 for low-traffic services; pay per invocation |
| ECS Fargate | Remove EC2 management; pay per task CPU/memory |
| Auto Scaling Groups | Scale to 0 during off-hours |
| CloudFront in front of ALB | Reduce data transfer costs, cache static assets |

---

## Monthly Spend Alerts

Set billing alarms to avoid surprises:

```bash
# Alert at $50 (dev) and $200 (prod)
aws cloudwatch put-metric-alarm \
  --alarm-name "billing-alert-50" \
  --alarm-description "Monthly spend > $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Currency,Value=USD \
  --evaluation-periods 1 \
  --alarm-actions <sns-topic-arn>
```

Or via AWS Console: Billing → Budgets → Create a cost budget.

---

## Teardown Reminder

```bash
# Full teardown to $0 (except S3 state storage)
bash scripts/teardown-aws.sh dev

# After teardown, residual costs:
# - S3 state bucket: ~$0.023/GB (< $0.01/month for TF state)
# - Nothing else
```
