# AWS Load Balancer Controller: turns Kubernetes Ingress resources into ALBs
# (and LoadBalancer Services into NLBs). It runs in kube-system and uses IRSA
# to call the AWS APIs with its own IAM role.

# Official policy from the controller's repo (docs/install/iam_policy.json, v3.6.2)
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller"
  description = "IAM policy for the AWS Load Balancer Controller"
  policy      = file("${path.module}/policies/aws-load-balancer-controller.json")
}

data "aws_iam_policy_document" "alb_controller_assume" {
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

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume.json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version
  namespace  = "kube-system"

  set = [
    { name = "clusterName", value = aws_eks_cluster.main.name },
    { name = "region", value = var.region },
    # Set explicitly so the controller doesn't depend on the node metadata service
    { name = "vpcId", value = aws_vpc.main.id },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = "aws-load-balancer-controller" },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.alb_controller.arn },
  ]

  # The controller pods need a node to run on and their IAM permissions in place
  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.alb_controller,
  ]
}
