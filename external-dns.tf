# ExternalDNS: reads the hostnames on Ingress resources and keeps Route 53
# records pointing at the current ALB. It runs in kube-system and uses IRSA.
# The hosted zone itself is created in bootstrap/.

data "aws_route53_zone" "main" {
  name = var.domain_name
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [data.aws_route53_zone.main.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResources",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  name        = "${var.cluster_name}-external-dns"
  description = "Lets ExternalDNS manage records in ${var.domain_name}"
  policy      = data.aws_iam_policy_document.external_dns.json
}

data "aws_iam_policy_document" "external_dns_assume" {
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
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_chart_version
  namespace  = "kube-system"

  set = [
    { name = "provider.name", value = "aws" },
    { name = "sources[0]", value = "ingress" },
    { name = "domainFilters[0]", value = var.domain_name },
    # sync: also deletes records when the Ingress is deleted, so DNS never
    # points at an ALB that no longer exists
    { name = "policy", value = "sync" },
    # TXT ownership records mark which records this cluster manages
    { name = "txtOwnerId", value = var.cluster_name },
    # Without a prefix the ownership record for the bare domain would be
    # "a-registan.xyz", which is outside the zone, so ExternalDNS never owned
    # registan.xyz and stopped updating it. This makes it "extdns-a.registan.xyz".
    { name = "txtPrefix", value = "extdns-%%{record_type}." },
    { name = "env[0].name", value = "AWS_DEFAULT_REGION" },
    { name = "env[0].value", value = var.region },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = "external-dns" },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.external_dns.arn },
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.external_dns,
  ]
}
