# Sentinel Split Architecture

A proof-of-concept implementation of Rapyd Sentinel's split architecture — two isolated Kubernetes clusters communicating privately over VPC peering, deployed entirely via GitHub Actions CI/CD with OIDC authentication.

## Architecture Overview

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                        AWS Account                           │
                    │                                                              │
  Internet ──►     │  ┌──────────────────┐    VPC Peering    ┌─────────────────┐  │
                    │  │   vpc-gateway     │◄────────────────►│   vpc-backend    │  │
                    │  │   10.0.0.0/16     │                  │   10.1.0.0/16    │  │
                    │  │                   │                  │                  │  │
                    │  │  ┌─────────────┐  │                  │  ┌────────────┐  │  │
                    │  │  │ eks-gateway │  │                  │  │eks-backend │  │  │
                    │  │  │             │  │                  │  │            │  │  │
                    │  │  │ NGINX Proxy │──┼──── private ────►│──│  Backend   │  │  │
                    │  │  │ (public LB) │  │    connection    │  │  (int. LB) │  │  │
                    │  │  └─────────────┘  │                  │  └────────────┘  │  │
                    │  └──────────────────┘                  └─────────────────┘  │
                    └─────────────────────────────────────────────────────────────┘
```

**Traffic flow:**
1. User hits the public NLB on the gateway
2. Gateway NGINX proxies the request to the backend's internal NLB
3. Traffic crosses VPCs via VPC peering (private, never touches the internet)
4. Backend responds with "Hello from backend"

---

## Repository Structure

```
.
├── .github/workflows/
│   └── deploy.yaml              # CI/CD pipeline (OIDC, Terraform, K8s deploy)
├── terraform/
│   ├── main.tf                  # Root module — orchestrates everything
│   ├── variables.tf             # Input variables (region, environment)
│   ├── outputs.tf               # Output values
│   ├── terraform.tfvars         # Variable values for this deployment
│   └── modules/
│       ├── networking/          # VPC, subnets, NAT, routing
│       ├── eks/                 # EKS cluster + node group + security groups
│       ├── iam/                 # IAM roles for EKS (cluster & node roles)
│       └── peering/             # VPC peering connection + routes
├── kubernetes/
│   ├── backend/
│   │   ├── namespace.yaml       # sentinel namespace
│   │   ├── deployment.yaml      # Backend app (nginx serving "Hello from backend")
│   │   ├── service.yaml         # Internal NLB (not internet-facing)
│   │   └── networkpolicy.yaml   # Pod-level firewall (only gateway VPC allowed)
│   └── gateway/
│       ├── namespace.yaml       # sentinel namespace
│       ├── deployment.yaml      # NGINX reverse proxy
│       └── service.yaml         # Public-facing NLB
└── README.md
```

---

## How to Clone and Run

```bash
# Clone the repository
git clone https://github.com/Faheema125/sentinel-split-architecture.git
cd sentinel-split-architecture

# Push to main to trigger the pipeline
git push origin main
```

The pipeline runs automatically on push to `main`. You can also trigger it manually from the GitHub Actions tab using the "Run workflow" button.

**Prerequisites:**
- AWS account with the OIDC provider configured for GitHub
- IAM role `sentinel-github-actions-faheema-v3` with appropriate permissions
- S3 bucket `sentinel-terraform-state-rapyd` for Terraform state
- EKS access entries granting the OIDC role cluster admin

---

## Networking Design

### VPC Layout

| VPC | CIDR | Purpose |
|-----|------|---------|
| vpc-gateway | 10.0.0.0/16 | Public-facing proxy, internet-accessible LB |
| vpc-backend | 10.1.0.0/16 | Internal services, no public access |

Each VPC contains:
- **2 private subnets** across `us-west-2a` and `us-west-2b` (EKS nodes run here)
- **2 public subnets** (NAT gateways and load balancers only)
- **NAT Gateway** for outbound internet access (pulling container images)
- **No public EC2 instances** — nodes have no public IPs

### Cross-VPC Communication

- **VPC Peering** connects the two VPCs with a private link
- Routes are added to private route tables in both VPCs:
  - Gateway private RT → `10.1.0.0/16` via peering connection
  - Backend private RT → `10.0.0.0/16` via peering connection
- DNS resolution is enabled across the peering connection

### How the Proxy Talks to the Backend

1. The backend service exposes an **internal NLB** (annotation: `aws-load-balancer-internal: "true"`)
2. The CI/CD pipeline retrieves the internal LB's DNS name after deployment
3. The gateway's NGINX config is injected with this DNS as the upstream (`sed` replacement of `BACKEND_SERVICE_HOST`)
4. Traffic from the gateway pods → backend internal LB → backend pods, all over private IPs via the VPC peering link

---

## Security Model

### Network-Level Security (AWS)

| Layer | Control | Effect |
|-------|---------|--------|
| Security Groups | Backend cluster SG allows ingress only from `10.0.0.0/16` | Only gateway VPC can reach backend |
| Security Groups | Gateway cluster SG allows ingress only from `10.1.0.0/16` | Only backend VPC can reach gateway (responses) |
| Subnets | EKS nodes in private subnets only | No direct internet access to nodes |
| Load Balancer | Backend uses internal NLB | Backend is not internet-accessible |
| NAT Gateway | Outbound only | Nodes can pull images but can't be reached inbound |

### Pod-Level Security (Kubernetes NetworkPolicy)

The backend has a `NetworkPolicy` that:
- **Allows ingress** only from `10.0.0.0/16` (gateway VPC) on port 80
- **Allows egress** only to DNS (port 53)
- **Denies all other traffic** (default deny for both ingress and egress)

This provides defense-in-depth: even if the security group is misconfigured, the pod-level policy still blocks unauthorized access.

### CI/CD Security (OIDC)

- **No static AWS credentials** stored in GitHub Secrets
- GitHub Actions authenticates via OIDC federation (short-lived tokens, ~1 hour)
- The IAM role trust policy restricts access to this specific repository only
- Credentials are never stored, rotated, or at risk of leaking

---

## CI/CD Pipeline

```
push to main
    │
    ├──► Terraform Validate & Lint (fmt, validate, tflint)
    │         │
    │         ├──► Terraform Plan (saves plan artifact)
    │         │         │
    │         │         └──► Terraform Apply (only on main, auto-approve saved plan)
    │         │                   │
    │         └──► Validate K8s Manifests (kubeconform)
    │                             │
    │                   ┌─────────┴─────────┐
    │                   │                   │
    │              Deploy Backend      (waits for backend)
    │              - apply manifests         │
    │              - wait for pods      Deploy Gateway
    │              - get internal LB    - inject backend DNS
    │                                  - apply manifests
    │                                  - smoke test
    └──► (PR only: validate + plan, no apply)
```

**Pipeline stages:**
1. **Terraform Validate & Lint** — format check, validate, tflint
2. **Terraform Plan** — shows what will change, saves plan artifact
3. **Terraform Apply** — applies saved plan (main branch only)
4. **Validate Kubernetes Manifests** — kubeconform strict validation
5. **Deploy Backend Service** — applies K8s manifests, waits for readiness, captures internal LB DNS
6. **Deploy Gateway Proxy** — injects backend address, deploys, runs smoke test

**Authentication:** GitHub OIDC → AWS STS → temporary credentials (no secrets)

---

## Trade-offs (3-Day Limit)

| Decision | Trade-off | Production Improvement |
|----------|-----------|----------------------|
| Broad IAM policies on OIDC role | Faster setup, less secure | Scope down to exact actions needed |
| Single NAT Gateway per VPC | Single AZ = single point of failure | Deploy NAT per AZ for HA |
| Public EKS API endpoint | Needed for GitHub Actions access | Use private endpoint + VPN/bastion |
| `t3.medium` nodes | Cost-effective for POC | Use compute-optimized or Graviton in prod |
| Hardcoded backend DNS via `sed` | Simple, works for POC | Use Service Mesh or ExternalDNS |
| No TLS between gateway and backend | Acceptable in private network for POC | Add mTLS via service mesh |
| NLB without WAF | Sufficient for POC | Add AWS WAF on ALB for production |

---

## Cost Optimization Notes

- **Single NAT Gateway per VPC** — saves ~$32/month per VPC vs multi-AZ NAT
- **t3.medium instances** — burstable, cost-effective for low-traffic POC ($0.0416/hr)
- **NLB over ALB** — NLB is cheaper for TCP-only traffic (no HTTP routing needed)
- **Internal LB for backend** — no additional public IP costs
- **2 nodes per cluster** — minimum for HA across AZs while staying cost-efficient

**Estimated monthly cost (POC):** ~$300-400 (4 EC2 nodes + 2 NAT GWs + 2 NLBs + data transfer)

---

## What I Would Do Next

### Security Enhancements
- **mTLS** between gateway and backend using a service mesh (Istio or Linkerd)
- **AWS WAF** on the public-facing load balancer
- **Private EKS endpoints** with VPN or AWS PrivateLink for CI/CD access
- **Secrets management** with AWS Secrets Manager or HashiCorp Vault
- **Pod Security Standards** (restricted profile)

### Operational Improvements
- **Observability** — Prometheus + Grafana for metrics, Fluentd/CloudWatch for logs
- **GitOps** — ArgoCD or Flux for declarative Kubernetes deployments
- **Ingress Controller** — NGINX Ingress or AWS ALB Controller for better routing
- **Auto-scaling** — Cluster Autoscaler or Karpenter for node scaling, HPA for pods
- **Multi-AZ NAT** for high availability

### Infrastructure
- **Terraform workspaces** or separate state files per environment (dev/staging/prod)
- **Terraform state locking** with DynamoDB
- **Module versioning** — pin module versions for reproducibility
- **Transit Gateway** instead of VPC peering if more VPCs are added
- **Scoped IAM policies** — replace FullAccess with least-privilege custom policies

---

## IAM Naming Convention

Per the challenge constraints, all IAM roles follow approved prefixes:
- `eks-cluster-role-dev` — EKS cluster service role
- `eks-node-gateway-role-dev` — Gateway node group role
- `eks-node-backend-role-dev` — Backend node group role
- `sentinel-github-actions-faheema-v3` — CI/CD OIDC role

---

## Assumptions & Limitations

1. **S3 backend bucket** (`sentinel-terraform-state-rapyd`) was pre-created by the account admin
2. **OIDC provider** for GitHub was pre-registered in the account
3. **DynamoDB state locking** was skipped due to missing `dynamodb:CreateTable` permission — in production this is critical for concurrent safety
4. **EKS cluster auth mode** was updated from `CONFIG_MAP` to `API_AND_CONFIG_MAP` to support access entries for the OIDC role
5. **GitHub OIDC sub claim** uses the newer format with embedded numeric IDs (`repo:Owner@ID/repo@ID:ref:...`) — trust policies must match this format
