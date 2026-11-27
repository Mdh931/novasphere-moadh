data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

module "webstack" {
  #checkov:skip=CKV_TF_1:le cahier des charges impose un tag vX.Y.Z, jamais modifie apres publication
  source = "git::https://github.com/Mdh931/terraform-aws-webstack-moadh.git?ref=v1.3.0"

  project               = "novasphere"
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.public_subnets
  ami_id                = data.aws_ami.al2023.id
  instance_type         = var.instance_type
  secret_parameter_name = aws_ssm_parameter.app_secret.name
  app_message           = var.app_message
}
