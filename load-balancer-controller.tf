data "aws_iam_policy_document" "load_balancer_controller_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.cluster_name}-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume.json
  tags               = local.common_tags
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-load-balancer-controller"
  description = "Permissões do AWS Load Balancer Controller no cluster ${var.cluster_name}"
  policy      = file("${path.module}/policies/load-balancer-controller.json")
  tags        = local.common_tags
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "helm_release" "load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.load_balancer_controller_chart_version
  wait       = true
  atomic     = true
  timeout    = 600

  values = [yamlencode({
    clusterName  = aws_eks_cluster.srjm-eks.name
    region       = var.aws_region
    vpcId        = aws_vpc.eks.id
    replicaCount = 2
    podAnnotations = {
      "checksum/irsa" = sha256(jsonencode({
        role_arn     = aws_iam_role.load_balancer_controller.arn
        trust_policy = data.aws_iam_policy_document.load_balancer_controller_assume.json
      }))
    }
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.load_balancer_controller.arn
      }
    }
  })]

  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller,
    aws_eks_node_group.workers,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns
  ]
}
