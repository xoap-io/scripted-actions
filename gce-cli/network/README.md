# Google Cloud CLI - Network Management Scripts

PowerShell scripts for managing Google Cloud VPC networks, subnets, and
firewall rules using the gcloud CLI.

## Prerequisites

- Google Cloud SDK installed (includes gcloud CLI)
- PowerShell 5.1 or later
- Active Google Cloud project with Compute Engine API enabled
- Authenticated gcloud session (`gcloud auth login`)
- Default project set (`gcloud config set project PROJECT_ID`)

## Available Scripts

| Script                             | Description                                             |
| ---------------------------------- | ------------------------------------------------------- |
| `gce-cli-create-vpc.ps1`           | Create a VPC network with auto or custom subnet mode    |
| `gce-cli-create-firewall-rule.ps1` | Create a VPC firewall rule (ingress/egress, allow/deny) |
| `gce-cli-create-subnet.ps1`        | Create a subnetwork in an existing custom-mode VPC      |

## Usage Examples

### Create a VPC Network

```powershell
.\gce-cli-create-vpc.ps1 `
  -NetworkName "prod-network" `
  -SubnetMode custom `
  -Description "Production VPC network"
```

Create a VPC with automatic subnets (default mode):

```powershell
.\gce-cli-create-vpc.ps1 `
  -ProjectId "my-project-123" `
  -NetworkName "dev-network"
```

### Create a Firewall Rule

```powershell
.\gce-cli-create-firewall-rule.ps1 `
  -RuleName "allow-https" `
  -Network "prod-network" `
  -Protocol tcp `
  -Ports "443" `
  -SourceRanges "0.0.0.0/0"
```

Create a deny-all egress rule with elevated priority:

```powershell
.\gce-cli-create-firewall-rule.ps1 `
  -ProjectId "my-project-123" `
  -RuleName "deny-all-egress" `
  -Network "prod-network" `
  -Direction EGRESS `
  -Action deny `
  -Protocol all `
  -Priority 500
```

### Create a Subnet

```powershell
.\gce-cli-create-subnet.ps1 `
  -SubnetName "web-subnet" `
  -Network "prod-network" `
  -Region "us-central1" `
  -IpRange "10.0.1.0/24" `
  -EnablePrivateGoogleAccess
```

Create a subnet with flow logs enabled:

```powershell
.\gce-cli-create-subnet.ps1 `
  -ProjectId "my-project-123" `
  -SubnetName "private-subnet" `
  -Network "prod-network" `
  -Region "europe-west1" `
  -IpRange "10.1.0.0/20" `
  -EnablePrivateGoogleAccess `
  -EnableFlowLogs `
  -Description "Private workload subnet"
```
