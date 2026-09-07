provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}


#########K8S

provider "kubernetes" {
  host                   = aws_eks_cluster.srjm-eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.srjm-eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.srjm-eks.token
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.srjm-eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.srjm-eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.srjm-eks.token
  }
}
