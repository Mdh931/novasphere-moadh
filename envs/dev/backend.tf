terraform {
  backend "s3" {
    bucket       = "novasphere-moadh-tfstate-339712963210"
    key          = "novasphere/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
