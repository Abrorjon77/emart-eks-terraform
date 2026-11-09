# emart-eks-terraform

Terraform configuration to provision an AWS EKS cluster for the emart application.

---

## Prerequisites

Make sure you have these installed and configured before starting:

| Tool | Version | Install |
|---|---|---|
| Terraform | >= 1.10.0 | https://developer.hashicorp.com/terraform/downloads |
| AWS CLI | v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| kubectl | any recent | https://kubernetes.io/docs/tasks/tools/ |

Configure your AWS credentials:

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region (us-east-1), output format (json)
```

---

## Quick start (fresh AWS account, no bucket yet)

Run these in order. Each step depends on the one before it.

```bash
# 1. Create the state bucket, DNS zone and certificate (bootstrap keeps its own state locally)
cd bootstrap
terraform init
terraform plan          # 8 to add: bucket + 3 settings, hosted zone, certificate, 2 validation records
terraform apply         # type "yes"
terraform output name_servers   # paste these 4 into GoDaddy, see "Step 1b"
cd ..

# 2. Point the main config at the bucket
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {
    bucket       = "vprofile-terraform-state-1"
    key          = "emart-eks/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
EOF

# 3. Create the EKS cluster (its state goes into the S3 bucket)
terraform init
terraform plan
terraform apply
```

The steps below explain each part in more detail.

---

## Step 1 — Create the S3 state bucket with `bootstrap/`

The main config stores its state in S3, so the bucket must exist first. The [bootstrap/](bootstrap/) folder is a small, separate Terraform config that creates it (versioned, encrypted, public access blocked).

**Why this works:** `bootstrap/` has no `backend` block, so its state is saved as a local file (`bootstrap/terraform.tfstate`) and does not need S3. That is what lets it create the bucket the main config depends on.

Run it once:

```bash
cd bootstrap
terraform init
terraform apply                                   # uses the default bucket name
# or: terraform apply -var="bucket_name=<your-unique-bucket-name>"
cd ..
```

S3 bucket names are globally unique. If the default `vprofile-terraform-state-1` is taken, pass your own name as shown above, and use that same name in `backend.tf` (Step 2).

| Error | Cause | Fix |
|---|---|---|
| `NoSuchBucket` on root `terraform init` | The main config was initialised before the bucket existed | Run `bootstrap/` first |
| `BucketAlreadyExists` | Another AWS account owns that name | Pick a different `bucket_name` |
| `BucketAlreadyOwnedByYou` | The bucket exists but is not in bootstrap's state (created with the CLI, or `bootstrap/terraform.tfstate` was lost) | Import it, see below |

**Bucket already exists?** If it was created earlier with the AWS CLI, import it instead of creating it:

```bash
cd bootstrap
terraform init
for r in aws_s3_bucket aws_s3_bucket_versioning aws_s3_bucket_server_side_encryption_configuration aws_s3_bucket_public_access_block; do
  terraform import "$r.state" vprofile-terraform-state-1
done
terraform apply   # only fills in any missing settings or tags
cd ..
```

The bucket has `prevent_destroy` set, so `terraform destroy` in `bootstrap/` will refuse to delete it. Keep `bootstrap/terraform.tfstate` safe; it is gitignored.

---

## Step 1b — Point the GoDaddy domain at Route 53 (once)

`bootstrap/` also creates the Route 53 hosted zone for `registan.xyz` (change `domain_name` in `bootstrap/variables.tf` and `variables.tf` for another domain) and a free ACM certificate for `registan.xyz` and `*.registan.xyz`. Both are kept between cluster rebuilds, so the nameservers never change.

1. Get the zone's nameservers:
   ```bash
   cd bootstrap && terraform output name_servers && cd ..
   ```
2. In GoDaddy: **My Products → registan.xyz → DNS → Nameservers → Change nameservers → I'll use my own nameservers**. Enter the 4 values (without the trailing dot) and save.
3. Wait for the change to spread (minutes to a few hours), then check:
   ```bash
   dig +short NS registan.xyz          # should list the same 4 nameservers
   aws acm list-certificates --region us-east-1 \
     --query "CertificateSummaryList[?DomainName=='registan.xyz'].Status"   # should become ISSUED
   ```

The domain stays registered at GoDaddy; only its DNS is served by Route 53 ($0.50/month). Deploy the app only after the certificate is `ISSUED`, because the ALB's HTTPS listener needs it.

---

## Step 2 — Create `backend.tf`

This file is gitignored — you must create it manually. Create `backend.tf` in the root of the repo, using the bucket name from Step 1:

```hcl
terraform {
  backend "s3" {
    bucket       = "vprofile-terraform-state-1"
    key          = "emart-eks/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true   # state locking in S3, no DynamoDB table needed
  }
}
```

---

## Step 3 — (Optional) Override default variables

Default values are already set and will work out of the box:

| Variable | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region |
| `cluster_name` | `emart-eks-cluster` | EKS cluster name |
| `kubernetes_version` | `1.36` | EKS Kubernetes version |
| `instance_types` | `["t3.large", "t3a.large", "m5.large", "m5a.large"]` | Worker node instance types |
| `capacity_type` | `SPOT` | `SPOT` (cheaper, can be interrupted) or `ON_DEMAND` |
| `desired_nodes` | `1` | Number of nodes to run |
| `min_nodes` | `1` | Minimum nodes |
| `max_nodes` | `2` | Maximum nodes |

To override, create a `terraform.tfvars` file (also gitignored):

```hcl
cluster_name   = "my-cluster"
instance_types = ["t3.medium"]
capacity_type  = "ON_DEMAND"
desired_nodes  = 2
```

Or pass values inline at apply time:

```bash
terraform apply -var="capacity_type=ON_DEMAND"
```

---

## Step 4 — Initialise Terraform

Downloads providers and connects to the S3 backend:

```bash
terraform init
```

---

## Step 5 — Preview the changes

Shows everything that will be created before touching AWS:

```bash
terraform plan
```

---

## Step 6 — Create the cluster

```bash
terraform apply
```

Type `yes` when prompted. Takes **10–15 minutes** to complete.

When done, Terraform prints:

```
cluster_name     = "emart-eks-cluster"
cluster_endpoint = "https://xxxx.gr7.us-east-1.eks.amazonaws.com"
cluster_arn      = "arn:aws:eks:us-east-1:..."
```

---

## Step 7 — Connect kubectl to the cluster

```bash
aws eks update-kubeconfig --region us-east-1 --name emart-eks-cluster   # use your cluster_name if you overrode it
```

Verify the nodes are ready:

```bash
kubectl get nodes
```

Expected output:

```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-x-x.ec2.internal      Ready    <none>   2m    v1.36.x
```

---

## What gets created

- VPC (`10.0.0.0/16`) with 2 public subnets (`10.0.0.0/24`, `10.0.1.0/24`) and 1 private subnet (`10.0.10.0/24`). Load balancers use the public subnets; worker nodes run only in the private one. The second public subnet shares the private subnet's AZ, because a load balancer can only reach nodes in AZs where it has a subnet.
- NAT gateway in the public subnet so worker nodes in the private subnet can reach the internet
- Internet Gateway and route tables
- EKS control plane (Kubernetes 1.36)
- Managed node group — 1× Spot worker node (t3.large class) in the private subnet, scales to 2
- IAM roles for the cluster and nodes
- OIDC provider (enables pods to assume IAM roles)
- EBS CSI Driver addon (enables Kubernetes persistent volumes on EBS)
- AWS Load Balancer Controller (Helm chart in `kube-system`, IAM role via IRSA). It turns Kubernetes `Ingress` resources into ALBs. The IAM policy is the official one, kept in [policies/aws-load-balancer-controller.json](policies/aws-load-balancer-controller.json); when you bump `alb_controller_chart_version`, update the policy from the same release.
- ExternalDNS (Helm chart in `kube-system`, IAM role via IRSA, limited to the `registan.xyz` zone). It reads the hostnames on the Ingress and keeps the Route 53 records pointing at the current ALB, so a rebuild needs no DNS changes. With `policy=sync` it also deletes those records when the app is deleted.

---

## Destroy the cluster

The ALB is created by the controller, not by Terraform, so delete the app first. Otherwise the ALB is left behind, keeps billing, and blocks deleting the VPC:

```bash
# 1. Delete the app; the Argo CD finalizer also deletes its Ingress, so the controller removes the ALB
kubectl delete -f ~/emart-k8s-config/argocd/application.yaml

# 2. Wait until no ALB is left
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[].LoadBalancerName'

# 3. Tear down everything else
terraform destroy
```

> The EKS control plane costs **$0.10/hr** even when idle. Destroy when not in use.

This does not delete the S3 state bucket, which belongs to `bootstrap/` and has `prevent_destroy` set. The bucket costs only a few cents a month.

---

## Estimated cost

| Resource | Rate |
|---|---|
| EKS control plane | $0.10 / hr |
| t3.large-class node (×1) | ~$0.03 / hr Spot, $0.0832 / hr on-demand |
| NAT gateway | $0.045 / hr + $0.045 / GB processed |
| Route 53 hosted zone (kept between rebuilds) | $0.50 / month |
| ALB (created when the app is deployed) | ~$0.0225 / hr + LCU usage, plus ~$0.01 / hr for its 2 public IPs |
| **Total** | **~$0.21 / hr (~$155 / month) with Spot and the app deployed** |

---

## Related repositories

| Repo | Purpose |
|---|---|
| `emart-eks-terraform` | This repo — AWS infrastructure |
| `emart-k8s-config` | Kubernetes manifests (Deployments, Services, Ingress) |
| `emartapp` | Application source code and GitHub Actions CI/CD |
