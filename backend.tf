terraform {
  backend "s3" {
    bucket  = "YOUR-BUCEKT"
    region  = "us-east-1"
    encrypt = true
    key     = "eks-calico-test-1/terraform.tfstate"
  }
}