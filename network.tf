resource "aws_vpc" "eks" {

  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true

  enable_dns_support = true

  tags = {
    Name = "${var.cluster_name}-vpc"
  }

}

resource "aws_subnet" "public_a" {

  vpc_id = aws_vpc.eks.id

  cidr_block = var.public_subnets[0]

  availability_zone = var.availability_zones[0]

  map_public_ip_on_launch = true

  tags = {

    Name = "${var.cluster_name}-public-2a"

    "kubernetes.io/cluster/${var.cluster_name}" = "shared"

    "kubernetes.io/role/elb" = "1"

  }

}

resource "aws_subnet" "public_b" {

  vpc_id = aws_vpc.eks.id

  cidr_block = var.public_subnets[1]

  availability_zone = var.availability_zones[1]

  map_public_ip_on_launch = true

  tags = {

    Name = "${var.cluster_name}-public-2b"

    "kubernetes.io/cluster/${var.cluster_name}" = "shared"

    "kubernetes.io/role/elb" = "1"

  }

}



resource "aws_internet_gateway" "eks" {

  vpc_id = aws_vpc.eks.id

  tags = {

    Name = "${var.cluster_name}-igw"

  }

}

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.eks.id

  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.eks.id

  }

}

resource "aws_route_table_association" "public_a" {

  subnet_id = aws_subnet.public_a.id

  route_table_id = aws_route_table.public.id

}

resource "aws_route_table_association" "public_b" {

  subnet_id = aws_subnet.public_b.id

  route_table_id = aws_route_table.public.id

}

resource "aws_default_security_group" "eks" {
  vpc_id = aws_vpc.eks.id

  tags = {
    Name = "${var.cluster_name}-default-deny-all"
  }
}

resource "aws_ec2_tag" "karpenter_cluster_security_group" {
  resource_id = aws_eks_cluster.srjm-eks.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc-flow-log/${var.cluster_name}"
  retention_in_days = 1

  tags = local.common_tags

}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.cluster_name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "eks" {
  vpc_id                   = aws_vpc.eks.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  max_aggregation_interval = 60

  tags = local.common_tags
}
