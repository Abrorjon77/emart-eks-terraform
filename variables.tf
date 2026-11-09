variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "emart-eks-cluster"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (versions past standard support cost 6x more)"
  default     = "1.36"
}

variable "instance_types" {
  description = "EC2 instance types for worker nodes; several types make spot capacity easier to get"
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
}

variable "capacity_type" {
  description = "SPOT (about 60-70% cheaper, can be interrupted) or ON_DEMAND"
  default     = "SPOT"
}

variable "desired_nodes" {
  description = "Desired number of worker nodes"
  default     = 1
}

variable "min_nodes" {
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of worker nodes"
  default     = 2
}

variable "alb_controller_chart_version" {
  description = "Helm chart version of the AWS Load Balancer Controller (eks-charts)"
  default     = "3.6.2"
}

variable "domain_name" {
  description = "App domain; its Route 53 zone is created in bootstrap/"
  default     = "registan.xyz"
}

variable "external_dns_chart_version" {
  description = "Helm chart version of ExternalDNS (kubernetes-sigs)"
  default     = "1.23.0"
}

variable "external_secrets_chart_version" {
  description = "Helm chart version of External Secrets Operator"
  default     = "2.14.0"
}
