resource "aws_iam_role" "karpenter" {
  name               = "karpenter-role"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume.json

  tags = local.common_tags
}

# O controller precisa consultar capacidade e criar/remover recursos EC2.
#checkov:skip=CKV_AWS_290:Permissões de escrita são necessárias para o provisionamento de nós pelo Karpenter
#checkov:skip=CKV_AWS_355:Ações Describe e Pricing da AWS não suportam escopo por ARN
data "aws_partition" "current" {}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.cluster_name}-karpenter-controller"
  description = "Permissões do controller Karpenter no cluster ${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceAccessActions"
        Effect = "Allow"

        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]

        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::image/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::snapshot/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:security-group/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:subnet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:capacity-reservation/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:placement-group/*"
        ]
      },

      {
        Sid    = "AllowScopedEC2LaunchTemplateAccessActions"
        Effect = "Allow"

        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]

        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        ]

        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }

          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },

      {
        Sid    = "AllowScopedEC2InstanceCreationActions"
        Effect = "Allow"

        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]

        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:spot-instances-request/*"
        ]

        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }

          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid      = "AllowScopedEC2LaunchTemplateCreationActions"
        Effect   = "Allow"
        Action   = "ec2:CreateLaunchTemplate"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"

        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }

          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedEC2ResourceCreationTagging"
        Effect = "Allow"
        Action = "ec2:CreateTags"

        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:spot-instances-request/*"
        ]

        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"

            "ec2:CreateAction" = [
              "RunInstances",
              "CreateFleet",
              "CreateLaunchTemplate"
            ]
          }

          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },

      {
        Sid      = "AllowScopedEC2ResourceTagging"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*"

        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }

          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },

      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"

        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate"
        ]

        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        ]

        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }

          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },

      {
        Sid    = "AllowRegionalReadActions"
        Effect = "Allow"

        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeCapacityReservations",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribePlacementGroups",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },

      {
        Sid      = "AllowSSMReadActions"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::parameter/aws/service/*"
      },
      {
        Sid      = "AllowPricingReadActions"
        Effect   = "Allow"
        Action   = "pricing:GetProducts"
        Resource = "*"
      },

      {
        Sid      = "AllowUnscopedInstanceProfileListAction"
        Effect   = "Allow"
        Action   = "iam:ListInstanceProfiles"
        Resource = "*"
      },

      {
        Sid      = "AllowPassingInstanceRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.karpenter_nodes.arn

        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "ec2.amazonaws.com",
              "ec2.amazonaws.com.cn"
            ]
          }
        }
      },

      {
        Sid      = "AllowInstanceProfileReadActions"
        Effect   = "Allow"
        Action   = "iam:GetInstanceProfile"
        Resource = aws_iam_instance_profile.karpenter_nodes.arn
      },

      {
        Sid      = "AllowEKSClusterReadActions"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = aws_eks_cluster.srjm-eks.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "karpenter" {
  role       = aws_iam_role.karpenter.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

resource "aws_iam_role" "karpenter_nodes" {
  name = "KarpenterNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_instance_profile" "karpenter_nodes" {
  name = "KarpenterNodeInstanceProfile"
  role = aws_iam_role.karpenter_nodes.name

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_eks_access_entry" "karpenter_nodes" {
  cluster_name  = aws_eks_cluster.srjm-eks.name
  principal_arn = aws_iam_role.karpenter_nodes.arn
  type          = "EC2_LINUX"
}

resource "helm_release" "karpenter_crd" {
  name             = "karpenter-crd"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = var.karpenter_version
  wait             = true

  depends_on = [aws_eks_node_group.workers]
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version
  wait             = true
  timeout          = 600

  values = [yamlencode({
    settings = {
      clusterName = aws_eks_cluster.srjm-eks.name
    }
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter.arn
      }
    }
    controller = {
      resources = {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
    }
  })]

  depends_on = [
    helm_release.karpenter_crd,
    aws_iam_role_policy_attachment.karpenter,
    aws_eks_access_entry.karpenter_nodes
  ]
}
