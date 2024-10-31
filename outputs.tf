# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "loki_s3_bucket_name" {
  description = "Loki TSDB S3 Bucket Name to embed in Loki ConfigMap"
  value       = aws_s3_bucket.bucket.id
}

output "prometheus_iam_role" {
  description = "Prometheus IAM Role ARN to embed in Kubernetes ServiceAccount annotations"
  value       = aws_iam_role.prometheus_role.arn
}

output "loki_iam_role" {
  description = "Loki IAM Role ARN to embed in Kubernetes ServiceAccount annotations"
  value       = aws_iam_role.role.arn
}