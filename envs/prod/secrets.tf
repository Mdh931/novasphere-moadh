resource "aws_ssm_parameter" "app_secret" {
  name             = "/novasphere/${var.environment}/app_secret"
  type             = "SecureString"
  value_wo         = var.app_secret
  value_wo_version = var.app_secret_version
}
