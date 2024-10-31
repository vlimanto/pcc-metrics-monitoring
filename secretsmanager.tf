provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

resource "helm_release" "secrets-store-csi-driver" {
  name       = "csi-secrets-store"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
}

data "aws_secretsmanager_secret" "by-name" {
  # Replace with Relevant Secret Name
  name = "App4PCC"
}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:*:prometheus"] # system:serviceaccount:<K8S_NAMESPACE>:<K8S_SERVICE_ACCOUNT>
    }

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"]
      type        = "Federated"
    }
  }
}

data "aws_iam_policy_document" "secretsmanager_policy" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"
    ]

    resources = [
      "${data.aws_secretsmanager_secret.by-name.arn}",
    ]
  }
}

resource "aws_iam_role" "prometheus_role" {
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
  name               = "${local.cluster_name}-prometheus-role"
}

resource "aws_iam_policy" "prometheus_policy" {
  name   = "${local.cluster_name}-prometheus-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.secretsmanager_policy.json
}

resource "aws_iam_role_policy_attachment" "prometheus_attach" {
  policy_arn = aws_iam_policy.prometheus_policy.arn
  role       = aws_iam_role.prometheus_role.name
}
