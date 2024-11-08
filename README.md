# Introduction

This setups Prometheus, Grafana, Loki and Syslog-NG infrastructure in AWS EKS Cluster dedicated for monitoring and receiving syslog from Prisma Cloud Console.

## Features

- [Prisma Cloud metrics and monitoring](https://github.com/PaloAltoNetworks/pcs-metrics-monitoring) utilising Kubernetes instead of Docker platform
- [Managing Secrets with AWS Secrets Manager](https://www.eksworkshop.com/docs/security/secrets-management/secrets-manager/)
- [Prisma Sending syslog messages to a network endpoint](https://docs.prismacloud.io/en/enterprise-edition/content-collections/runtime-security/audit/logging#sending-syslog-messages-to-a-network-endpoint)
- [SyslogNG Storing messages in a Grafana Loki database](https://syslog-ng.github.io/admin-guide/070_Destinations/125_Loki/README)
- [Loki - AWS deployment S3 Single Store](https://grafana.com/docs/loki/latest/configure/storage/#aws-deployment-s3-single-store)
- [View Agentless Scan Progress](https://pan.dev/prisma-cloud/api/cwpp/get-agentless-progress/) into Grafana Metrics
- [View Registry Scan Progress](https://pan.dev/prisma-cloud/api/cwpp/get-registry-progress/)
- [AWS Load Balancer Controller Installation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.9/deploy/installation/)

## Prerequisites

- AWS CLI
- Terraform
- kubectl

# Guides

1. [Create and Manage Access Keys](https://docs.prismacloud.io/en/enterprise-edition/content-collections/administration/create-access-keys) in Prisma Console and store it in **AWS Secrets Manager**
   - E.g.: `aws --region "$REGION" secretsmanager  create-secret --name MySecret --secret-string '{"username":"memeuser", "password":"hunter2"}'`
2. Edit **secretsmanager.tf** with the name of *MySecret* above.
3. Run ***terraform init*** then ***terraform apply --target module.eks*** to build the EKS cluster first
4. Then run ***terraform apply*** to build the rest
5. After that, setup kubeconfig to point to new EKS cluster
   - E.g.: `aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)`
6. Apply all the Kubernetes Manifests, i.e.: `kubectl apply -f manifests/`
7. Find out the AWS Load Balancer *EXTERNAL-IP* for use:
   - `kubectl -n logging get svc syslog-ng` for use to configure [Prisma Sending syslog messages to a network endpoint](https://docs.prismacloud.io/en/enterprise-edition/content-collections/runtime-security/audit/logging#sending-syslog-messages-to-a-network-endpoint)
   - `kubectl -n monitoring get svc grafana` for viewing the **Grafana** UI

# To-Do

- [SyslogNG Sending messages to AWS S3](https://syslog-ng.github.io/admin-guide/070_Destinations/225_Amazon-s3/README)
- [NLB TLS Termination](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.9/guide/use_cases/nlb_tls_termination/)
- [Configure RBAC in Grafana](https://grafana.com/docs/grafana/latest/administration/roles-and-permissions/access-control/configure-rbac/)

# References

- [Prometheus in Prisma Cloud Runtime Security](https://docs.prismacloud.io/en/enterprise-edition/content-collections/runtime-security/audit/prometheus)
- [Original PAN PCS Metrics Monitoring](https://github.com/PaloAltoNetworks/pcs-metrics-monitoring)
