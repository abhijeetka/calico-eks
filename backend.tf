terraform {
  backend "s3" {
    bucket  = "terraform-global-state-calibo-prod-acc"
    region  = "us-east-1"
    encrypt = true
    key     = "eks-calico-test/terraform.tfstate"
  }
}