terraform {
  backend "s3" {
    bucket       = "novasphere-moadh-tfstate-339712963210"
    key          = "novasphere/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
