terraform {
  backend "s3" {
    bucket  = "jsbeserra-tfstates"
    key     = "eks/terraform.tfstate"
    encrypt = true
  }
}