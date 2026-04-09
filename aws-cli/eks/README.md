# AWS CLI — EKS (Elastic Kubernetes Service)

This directory contains PowerShell scripts for automating Amazon Elastic Kubernetes
Service (EKS) operations using the AWS CLI. The scripts cover cluster creation and
managed node group provisioning, providing a consistent, scriptable approach to
deploying Kubernetes infrastructure on AWS.

## Prerequisites

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
  installed and configured with appropriate credentials (`aws configure` or environment
  variables)
- Sufficient IAM permissions to create EKS clusters and node groups
- Pre-existing VPC with subnets and an IAM role for the EKS control plane (for cluster
  creation) and an IAM role for EC2 nodes (for node group creation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed for interacting with
  the cluster after creation

## Scripts

| Script                                                               | Description                                                                     |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| [aws-cli-create-eks-cluster.ps1](aws-cli-create-eks-cluster.ps1)     | Create an EKS cluster (asynchronous — transitions to ACTIVE after provisioning) |
| [aws-cli-create-eks-nodegroup.ps1](aws-cli-create-eks-nodegroup.ps1) | Create a managed node group in an existing EKS cluster                          |
