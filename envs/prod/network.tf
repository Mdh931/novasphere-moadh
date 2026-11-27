module "vpc" {
  #checkov:skip=CKV_TF_1:module du registre public, version contrainte par version
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "novasphere-${var.environment}"
  cidr = var.vpc_cidr

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2)]

  enable_nat_gateway      = false
  map_public_ip_on_launch = true

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}
