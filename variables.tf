variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "cluster_name" {
  type    = string
  default = "srjm-eks-new"
}

variable "eks_public_access_cidr" {
  type      = string
  sensitive = true

  validation {
    condition     = can(cidrhost(var.eks_public_access_cidr, 0))
    error_message = "eks_public_access_cidr deve ser um CIDR válido."
  }
}

variable "environment" {
  type    = string
  default = "lab"
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "karpenter_version" {
  type    = string
  default = "1.11.1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type = list(string)

  default = [
    "us-east-2a",
    "us-east-2b",
  ]
}

variable "public_subnets" {
  type = list(string)

  default = [
    "10.0.0.0/24",
    "10.0.1.0/24"
  ]
}

variable "node_instance_type" {
  type    = string
  default = "c7i-flex.large"
}

variable "desired_nodes" {
  type    = number
  default = 2
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 2
}

variable "name_s3_backend" {
  type    = string
  default = "eks-sjrm-tfstate"
}

variable "account_id" {
  type    = string
  default = "739871967137"
}