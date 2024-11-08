
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

resource "kubernetes_manifest" "monitoring_namespace" {
  provider = kubernetes
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "Namespace"
    "metadata" = {
      "name"      = "monitoring"
    }
  }
}

resource "kubernetes_manifest" "prometheus_service_account" {
  depends_on = [
    kubernetes_manifest.monitoring_namespace
  ]
  provider = kubernetes
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = "prometheus"
      "namespace" = "monitoring"
      "annotations" = {
        "eks.amazonaws.com/role-arn"  =  aws_iam_role.prometheus_role.arn
      }
    }
  }
}




data "http" "aws-provider-installer" {
  url = "https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml"
}
  
locals {
  raw_manifests = provider::kubernetes::manifest_decode_multi(data.http.aws-provider-installer.response_body)
}

resource "kubernetes_manifest" "aws-provider-installer" {
  for_each = {
    for manifest in local.raw_manifests:
    "${manifest.kind}--${manifest.metadata.name}" => manifest
  }
  provider = kubernetes
  manifest = each.value
}

