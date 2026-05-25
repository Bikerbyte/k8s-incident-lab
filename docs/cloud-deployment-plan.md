# Cloud Deployment Plan

This document evaluates three options for running the k8s-incident-lab on AWS, estimates monthly cost under the AWS Free Tier, and recommends a path forward.

## Options Evaluated

### Option A: Amazon EKS

EKS provides a managed Kubernetes control plane.

**What you get:**
- Managed control plane (AWS handles etcd, API server, upgrades)
- Native integration with IAM, ALB, EBS, CloudWatch
- Production-grade cluster with minimal ops overhead

**Cost estimate:**

| Item | Price |
|---|---|
| EKS cluster fee | $0.10/hour = **~$73/month** |
| EC2 worker node (t3.medium, on-demand) | ~$0.042/hour = **~$30/month** |
| EBS storage (20 GB gp3) | ~$1.60/month |
| **Total** | **~$105/month** |

EKS is not covered by AWS Free Tier. The $0.10/hour cluster fee applies regardless of workload.

**Verdict:** Too expensive for a portfolio lab. The cluster fee alone exceeds the free tier.

---

### Option B: k3s on EC2 (Spot Instance)

Run k3s directly on a single EC2 instance using Spot pricing.

**What you get:**
- Full Kubernetes API (k3s is CNCF-certified)
- No cluster management fee — just EC2 cost
- Spot instances can be interrupted, but for a lab this is acceptable

**Instance sizing:**

| Instance | vCPU | RAM | On-demand | Spot (approx) |
|---|---|---|---|---|
| t3.micro | 2 | 1 GB | $0.0104/hr | ~$0.003/hr |
| t3.medium | 2 | 4 GB | $0.0416/hr | ~$0.013/hr |
| t3.large | 2 | 8 GB | $0.0832/hr | ~$0.025/hr |

**Recommended:** `t3.medium` (4 GB RAM) — minimum viable for this stack.

**Cost estimate:**

| Item | Price |
|---|---|
| EC2 t3.medium Spot | ~$0.013/hr = **~$9/month** |
| EBS storage (30 GB gp3) | ~$2.40/month |
| Elastic IP (optional) | $0/month if attached |
| Data transfer (minimal) | ~$0–1/month |
| **Total** | **~$11–13/month** |

**AWS Free Tier note:** The Free Tier includes 750 hours/month of `t2.micro` or `t3.micro` for 12 months. A `t3.micro` has only 1 GB RAM — not enough for this monitoring stack. After the free tier period, Spot pricing applies.

**Verdict:** Cheapest viable option on AWS. Acceptable for a portfolio lab.

---

### Option C: k3s on EC2 (On-Demand, Reserved)

Same as Option B but using a 1-year Reserved Instance to reduce cost.

**Cost estimate (1-year No Upfront Reserved t3.medium):**

| Item | Price |
|---|---|
| EC2 t3.medium Reserved (1yr) | ~$0.026/hr = **~$19/month** |
| EBS storage (30 GB gp3) | ~$2.40/month |
| **Total** | **~$21/month** |

Higher than Spot but no interruption risk. Suitable if you plan to keep the lab running for demos.

**Verdict:** Good middle ground if you want uptime guarantees.

---

## Recommendation

**Use Option B: k3s on EC2 Spot (t3.medium)** to start.

Reasons:
1. Lowest cost (~$11/month) — acceptable for a portfolio project
2. Full Kubernetes API — identical to what this lab already uses locally
3. No additional tooling needed — existing scripts work as-is
4. Spot interruptions are acceptable for a lab; a simple `scripts/lab.sh deploy` re-run restores state

If uptime for live demos becomes important, switch to a Reserved t3.medium (~$21/month) or add a spot interruption handler.

---

## Proposed Terraform File Structure

```text
terraform/
+-- main.tf           # Provider, backend config
+-- variables.tf      # Region, instance type, key pair name
+-- outputs.tf        # Public IP, SSH command, URLs
+-- vpc.tf            # VPC, subnet, internet gateway, route table
+-- security-group.tf # Allow SSH (22), HTTP (80), app ports (3000, 9090, 9898)
+-- ec2.tf            # Spot instance, EBS volume, user_data bootstrap script
+-- userdata.sh       # Install k3s, kubectl, helm, git-clone, run deploy scripts
```

### Key resources

**`ec2.tf`** — Spot instance with user_data bootstrap:
```hcl
resource "aws_spot_instance_request" "k8s_lab" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type  # t3.medium
  spot_type            = "persistent"
  key_name             = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.lab.id]
  subnet_id            = aws_subnet.public.id
  user_data            = file("userdata.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }
}
```

**`userdata.sh`** — Bootstrap script that runs on first boot:
```bash
#!/usr/bin/env bash
curl -sfL https://get.k3s.io | sh -
# Wait for k3s, install helm, clone repo, run deploy scripts
```

**`security-group.tf`** — Open ports for lab access:
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
}
# Add rules for 3000 (Grafana), 9090 (Prometheus), 9898 (Podinfo)
```

---

## Next Steps

1. Decide: Spot (Option B) or Reserved (Option C)?
2. Create an AWS key pair for SSH access.
3. Run `terraform init && terraform apply` to provision the instance.
4. SSH in, confirm k3s is running, then verify lab scripts work end-to-end.
5. Add the live Grafana URL to the README.
