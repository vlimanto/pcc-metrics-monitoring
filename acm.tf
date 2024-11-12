resource "aws_eip" "syslogng-public-ip-1" {
  domain           = "vpc"
  public_ipv4_pool = "amazon"
}

resource "aws_eip" "syslogng-public-ip-2" {
  domain           = "vpc"
  public_ipv4_pool = "amazon"
}

resource "aws_eip" "syslogng-public-ip-3" {
  domain           = "vpc"
  public_ipv4_pool = "amazon"
}

resource "tls_private_key" "syslog-ng" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "syslog-ng" {
  private_key_pem = tls_private_key.syslog-ng.private_key_pem

  subject {
    common_name  = "syslogng.origin.lab" # Adjust to desired DNS name
    organization = "Origin Lab"
  }

  ip_addresses = [resource.aws_eip.syslogng-public-ip-1.public_ip,resource.aws_eip.syslogng-public-ip-2.public_ip,resource.aws_eip.syslogng-public-ip-3.public_ip]

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "syslog-ng" {
  private_key      = tls_private_key.syslog-ng.private_key_pem
  certificate_body = tls_self_signed_cert.syslog-ng.cert_pem
}

resource "kubernetes_annotations" "syslogng" {
  api_version = "v1"
  kind        = "Service"
  metadata {
    name = "syslog-ng"
    namespace = "logging"
  }
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = resource.aws_acm_certificate.syslog-ng.arn
    "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "2514"
    "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy" = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    "service.beta.kubernetes.io/aws-load-balancer-eip-allocations" = "${resource.aws_eip.syslogng-public-ip-1.allocation_id},${resource.aws_eip.syslogng-public-ip-2.allocation_id},${resource.aws_eip.syslogng-public-ip-3.allocation_id}"
  }
}

resource "tls_private_key" "grafana" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "grafana" {
  private_key_pem = tls_private_key.grafana.private_key_pem

  subject {
    common_name  = "grafana.origin.lab" # Adjust to desired DNS name
    organization = "Origin Lab"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "grafana" {
  private_key      = tls_private_key.grafana.private_key_pem
  certificate_body = tls_self_signed_cert.grafana.cert_pem
}

resource "kubernetes_annotations" "grafana" {
  api_version = "v1"
  kind        = "Service"
  metadata {
    name = "grafana"
    namespace = "monitoring"
  }
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = resource.aws_acm_certificate.grafana.arn
    "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "3000"
    "service.beta.kubernetes.io/aws-load-balancer-ssl-negotiation-policy" = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#    "service.beta.kubernetes.io/aws-load-balancer-type" = "external"
#    "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
  }
}

