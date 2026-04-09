# Google Cloud CLI - GKE Scripts

PowerShell scripts for managing Google Kubernetes Engine (GKE) clusters using
the gcloud CLI.

## Prerequisites

- Google Cloud SDK installed (includes gcloud CLI)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Active Google Cloud project with Kubernetes Engine API enabled
- Authenticated gcloud session (`gcloud auth login`)
- kubectl installed for post-provisioning cluster access
- Appropriate IAM permissions (Kubernetes Engine Admin or Cluster Admin)

## Available Scripts

| Script                            | Description                                                            |
| --------------------------------- | ---------------------------------------------------------------------- |
| `gce-cli-create-gke-cluster.ps1`  | Create a new GKE cluster (zonal or regional) with optional autoscaling |
| `gce-cli-resize-gke-nodepool.ps1` | Resize a node pool in an existing GKE cluster to a target node count   |

## Usage Examples

### Create a Zonal GKE Cluster

```powershell
.\gce-cli-create-gke-cluster.ps1 `
  -ClusterName "my-cluster" `
  -Zone "us-central1-a"
```

### Create a Regional Cluster with Autoscaling

```powershell
.\gce-cli-create-gke-cluster.ps1 `
  -ClusterName "prod-cluster" `
  -Region "us-central1" `
  -ProjectId "my-project-123" `
  -NumNodes 3 `
  -MachineType "e2-standard-4" `
  -EnableAutoscaling `
  -MinNodes 2 `
  -MaxNodes 10
```

### Resize a Node Pool

```powershell
.\gce-cli-resize-gke-nodepool.ps1 `
  -ClusterName "my-cluster" `
  -NodePool "default-pool" `
  -NumNodes 5 `
  -Zone "us-central1-a"
```

### Scale Down a Node Pool in a Regional Cluster

```powershell
.\gce-cli-resize-gke-nodepool.ps1 `
  -ClusterName "prod-cluster" `
  -NodePool "high-memory-pool" `
  -NumNodes 2 `
  -Region "us-central1" `
  -ProjectId "my-project-123"
```

## Related Documentation

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [gcloud container clusters create](https://cloud.google.com/sdk/gcloud/reference/container/clusters/create)
- [gcloud container clusters resize](https://cloud.google.com/sdk/gcloud/reference/container/clusters/resize)
