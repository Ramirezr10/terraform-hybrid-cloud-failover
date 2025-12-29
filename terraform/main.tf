
# ==========================================
# AWS Compute (The Lighthouse Controller)
# ==========================================

#Security Group for the primary instance
resource "aws_security_group" "lighthouse_sg" {
  name        = "lighthouse-primary-sg"
  description = "Allow SSH and k3s traffic"
  vpc_id      = aws_vpc.primary.id

  # SSH Rule
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In prod, you'd restrict this to your IP
  }

  # K3s API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound Traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lighthouse-sg" }

}

# Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

#create key pair
resource "aws_key_pair" "lighthouse_auth" {
  key_name   = "lighthouse-key"
  public_key = file("~/.ssh/lighthouse_key.pub")

}
# Lighhouse EC2 Instance 
resource "aws_instance" "lighthouse_primary" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro" # 100% Free Tier
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.lighthouse_sg.id]


  key_name = aws_key_pair.lighthouse_auth.key_name

  # This script auto-installs a lightweight K8s (K3s) on boot
  user_data = <<-EOF
              #!/bin/bash
              curl -sfL https://get.k3s.io | sh -
              EOF

  tags = {
    Name        = "lighthouse-primary-node"
    Project     = "Lighthouse-DR"
    Environment = "Primary"
  }


}


resource "aws_vpc" "primary" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    Name        = "lighthouse-primary-vpc"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}


# Public Subent for out "Lighthouse" Controller
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # Critical for free-tier access without NAT Gateways

  tags = { Name = "lighthouse-public-sub-1" }

}

# Internet Gateway (require for Public Subnet access)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.primary.id
  tags   = { Name = "lighthouse-igw" }

}

# Route Table to send Traffic to the Internet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "lighthouse-public-rt" }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id

}

# ==========================================
# GCP Foundation (Standby Site)
# ==========================================


# The Standby VPC
resource "google_compute_network" "standby" {
  name                    = "lighthouse-standby-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

}

#Standby Subnet (conditional)
# Using 'count' allows us to keep the subnet (and its cost) at zero unless DR is active.
resource "google_compute_subnetwork" "standby_subnet" {
  count         = var.dr_mode_active ? 1 : 0
  name          = "lighthouse-standby-sub"
  ip_cidr_range = "10.2.1.0/24" #Not to overlap with AWS
  network       = google_compute_network.standby.id
  region        = var.gcp_region

  private_ip_google_access = true
  # Important for GKE: Allows pods to talk to Google APIs without public IPs  
}

#Virutal machine image
resource "google_compute_instance" "vm_instance" {
  count        = var.dr_mode_active ? 1 : 0
  name         = "lighthouse-dr-gcp"
  machine_type = "e2-micro"
  zone         = "${var.gcp_region}-a"

  allow_stopping_for_update = true


  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.standby_subnet[0].id

    access_config {
      # this will give the VM a external IP
    }
  }

  metadata_startup_script = <<-EOF
                            #!/bin/bash
                            curl -sfL https://get.k3s.io | sh -
                            EOF

  service_account {
    email = null
    # This scope allows the VM to interact with all Google Cloud services 
    # that the Service Account has IAM permissions for.
    scopes = ["cloud-platform"]
  }
}

# Security: Standby Firewall Rules 
# This rule allows internal health checks and SSH for debugging.
resource "google_compute_firewall" "allow_internal" {
  name    = "lighthouse-allow-internal"
  network = google_compute_network.standby.id

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  # Only allow traffic from within our own network and Google health checks
  source_ranges = ["10.2.1.0/24", "35.191.0.0/16", "130.211.0.0/22", "0.0.0.0/0"]
}










