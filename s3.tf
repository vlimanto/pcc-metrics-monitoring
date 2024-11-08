
resource "aws_s3_bucket" "bucket" {
  bucket = lower("${local.cluster_name}-bucket")
}

#resource "aws_s3_bucket_acl" "bucket_acl" {
#  bucket = aws_s3_bucket.bucket.id
#  acl    = "private"
#}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket  = aws_s3_bucket.bucket.id
  versioning_configuration {
    status  =   "Enabled"
  }
}

data "aws_iam_policy_document" "role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:*:backend"] # system:serviceaccount:<K8S_NAMESPACE>:<K8S_SERVICE_ACCOUNT>
    }

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"]
      type        = "Federated"
    }
  }
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions = [
      "s3:ListAllMyBuckets",
    ]

    resources = [
      "*",
    ]
  }
  statement {
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]

    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*"
    ]
  }
}

resource "aws_iam_role" "role" {
  assume_role_policy = data.aws_iam_policy_document.role_policy.json
  name               = "${local.cluster_name}-backend-role"
}

resource "aws_iam_policy" "policy" {
  name   = "${local.cluster_name}-backend-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.role.name
}

resource "kubernetes_manifest" "backend_service_account" {
  depends_on = [
    kubernetes_manifest.monitoring_namespace
  ]
  provider = kubernetes
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "name"      = "backend"
      "namespace" = "monitoring"
      "annotations" = {
        "eks.amazonaws.com/role-arn"  =  aws_iam_role.role.arn
      }
    }
  }
}

resource "kubernetes_manifest" "loki-config" {
  depends_on = [
    kubernetes_manifest.monitoring_namespace
  ]
  provider = kubernetes
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"      = "loki-config"
      "namespace" = "monitoring"
    }
    "data" = {
       "local-config.yaml" = <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 0.0.0.0
  path_prefix: /tmp/loki
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: s3
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /tmp/loki/index
    cache_location: /tmp/loki/cache
  aws:
    s3: s3://ap-southeast-2
    bucketnames: "${aws_s3_bucket.bucket.id}"

limits_config:
  max_query_lookback: 672h
  retention_period: 672h

compactor:
  working_directory: /tmp/loki/compactor
  compaction_interval: 5m
  delete_request_store: s3
  retention_enabled: true

ruler:
  alertmanager_url: http://localhost:9093
            EOF
    }
  }
}
