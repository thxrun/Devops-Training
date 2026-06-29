module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = "devops-vpc"

  cidr = "10.0.0.0/16"

  azs = [
    "us-east-1a",
    "us-east-1b"
  ]

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
  "kubernetes.io/role/elb"                 = "1"
  "kubernetes.io/cluster/${var.cluster_name}" = "shared"
}

private_subnet_tags = {
  "kubernetes.io/role/internal-elb"        = "1"
  "kubernetes.io/cluster/${var.cluster_name}" = "shared"
}

  tags = {
    Project = "eks-production-platform"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.34"

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {}
    eks-pod-identity-agent = {}
  }

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  control_plane_subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {

      instance_types = ["t3.small"]

      capacity_type = "ON_DEMAND"

      ami_type = "AL2023_x86_64_STANDARD"

      desired_size = 1
      min_size     = 1
      max_size     = 2
    }
  }

  tags = {
    Project = "eks-production-platform"
  }
}