resource "aws_ssm_parameter" "app_secret" {
  #checkov:skip=CKV_AWS_337:cle KMS geree par AWS (aws/ssm), CMK dediee decrite dans SECURITE.md
  name             = "/novasphere/${var.environment}/app_secret"
  type             = "SecureString"
  value_wo         = var.app_secret
  value_wo_version = var.app_secret_version
}
