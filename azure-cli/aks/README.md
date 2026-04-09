# Azure CLI — AKS (Azure Kubernetes Service)

This directory contains PowerShell scripts for automating Azure Kubernetes Service
(AKS) operations using the Azure CLI. The scripts cover cluster provisioning, node
pool scaling, and kubeconfig credential management — enabling repeatable,
infrastructure-as-code-friendly Kubernetes cluster lifecycle management on Azure.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed
  and authenticated (`az login`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed for interacting with
  the cluster after credentials are downloaded
- An existing Azure Resource Group and (for node pool operations) an existing AKS
  cluster

## Scripts

| Script                                                           | Description                                                          |
| ---------------------------------------------------------------- | -------------------------------------------------------------------- |
| [az-cli-create-aks-cluster.ps1](az-cli-create-aks-cluster.ps1)   | Create an AKS cluster with optional autoscaling and managed identity |
| [az-cli-scale-aks-nodepool.ps1](az-cli-scale-aks-nodepool.ps1)   | Scale the node count of a node pool in an existing AKS cluster       |
| [az-cli-get-aks-credentials.ps1](az-cli-get-aks-credentials.ps1) | Download and merge kubeconfig credentials for an AKS cluster         |
