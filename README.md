# Multi-Cloud "Lighthouse" Disaster Recovery Framework

A production-ready Terraform project demonstrating a hybrid-cloud Disaster Recovery (DR) strategy between **AWS (Primary)** and **GCP (Standby)**.



## 🚀 The Architecture
- **Primary Site (AWS):** A "Lighthouse" controller running on a t2.micro instance with K3s (Lightweight Kubernetes) pre-installed.
- **Standby Site (GCP):** A conditional environment that remains "dark" (zero cost) until a `dr_mode_active` toggle is flipped.
- **Automation:** Uses Terraform `count` logic to provision/tear down the GCP VPC, Subnet, and Compute instance in under 2 minutes.

## 🛠️ Key Technical Challenges Overcome
### 1. Resource Constraint Optimization
During testing, GCP `e2-micro` instances (1GB RAM) faced API timeouts. I resolved this by:
- Implementing a **2GB swap file** via startup scripts.
- Slimming down the K3s control plane by disabling non-essential components (Traefik/Metrics-Server) to reduce CPU overhead by ~60%.

### 2. Infrastructure as Code (IaC) Governance
- Managed cross-cloud state within a single Terraform directory.
- Implemented security best practices using `.gitignore` to prevent credential leakage.

## 📖 How to Use
1. Clone the repo.
2. Initialize with `terraform init`.
3. Deploy the primary site: `terraform apply`.
4. Trigger a DR event: Change `dr_mode_active = true` in `terraform.tfvars` and re-apply.