locals {

  common_tags = {

    Project = "eks-study"

    Environment = var.environment

    Terraform = "true"

    ManagedBy = "Terraform"

    Owner = "JoaoMarcelo"

  }

}