# Nutanix CLI - Infrastructure Management Scripts

This directory contains PowerShell scripts for managing Nutanix cluster
infrastructure including clusters, hosts, networks, and protection domains
via the Nutanix PowerShell SDK and REST API.

## Prerequisites

- Nutanix PowerShell SDK (`Nutanix.PowerShell.SDK`)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Nutanix Prism Central or Prism Element access
- Network access to the Nutanix cluster
- Appropriate Nutanix permissions

## Available Scripts

| Script                               | Description                                                                                                                |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `nutanix-cli-cluster-operations.ps1` | Cluster health monitoring, capacity planning, and maintenance operations via Prism Central or Element                      |
| `nutanix-cli-host-operations.ps1`    | Host health monitoring, maintenance mode toggling, and hardware/performance reporting                                      |
| `nutanix-cli-network-operations.ps1` | Network creation, VLAN management, IP pool configuration, and usage monitoring                                             |
| `nutanix-cli-protection-domains.ps1` | Protection domain creation, VM assignment, backup schedules, and replication management                                    |
| `nutanix-cli-alerts.ps1`             | List and manage Nutanix cluster alerts via the Prism Central REST API v3; supports severity filtering and bulk acknowledge |
| `nutanix-cli-prism-events.ps1`       | Query the Prism Central events log via the REST API v3; supports severity filtering and export to CSV or JSON              |

## Usage Examples

### Cluster Operations

```powershell
# Health check for a specific cluster
.\nutanix-cli-cluster-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Health" `
    -ClusterName "Prod-Cluster"

# Generate HTML report with full details
.\nutanix-cli-cluster-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Report" `
    -IncludeVMs -IncludeHosts -IncludeStorage `
    -OutputFormat "HTML" `
    -OutputPath "cluster-report.html"

# Continuous monitoring with alerts
.\nutanix-cli-cluster-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Monitor" `
    -ContinuousMonitoring `
    -RefreshInterval 60 `
    -AlertThresholds `
    -CPUThreshold 80 `
    -MemoryThreshold 85
```

### Host Operations

```powershell
# Health check for all hosts in a cluster
.\nutanix-cli-host-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Health" `
    -ClusterName "Prod-Cluster"

# Enable maintenance mode on a host
.\nutanix-cli-host-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Maintenance" `
    -HostName "Host01" `
    -MaintenanceMode Enable `
    -Force
```

### Network Operations

```powershell
# List all networks on a cluster
.\nutanix-cli-network-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "List" `
    -ClusterName "Prod-Cluster"

# Create a VLAN network
.\nutanix-cli-network-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Create" `
    -NetworkName "VLAN100" `
    -VlanId 100 `
    -NetworkDescription "Production Network"

# Create a network with DHCP IP pool
.\nutanix-cli-network-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "CreateWithPool" `
    -NetworkName "VLAN200" `
    -VlanId 200 `
    -IPPoolStart "192.168.200.10" `
    -IPPoolEnd "192.168.200.100" `
    -Gateway "192.168.200.1" `
    -SubnetMask "255.255.255.0"
```

### Alerts

```powershell
$pass = Read-Host -AsSecureString "Password"

# List all alerts as a table
.\nutanix-cli-alerts.ps1 `
    -PrismCentralHost "pc.domain.com" `
    -Username "admin" `
    -Password $pass

# List critical alerts as JSON and acknowledge them
.\nutanix-cli-alerts.ps1 `
    -PrismCentralHost "pc.domain.com" `
    -Username "admin" `
    -Password $pass `
    -Severity Critical `
    -AcknowledgeAll `
    -OutputFormat JSON
```

### Prism Events

```powershell
$pass = Read-Host -AsSecureString "Password"

# Retrieve last 100 events as a table
.\nutanix-cli-prism-events.ps1 `
    -PrismCentralHost "pc.domain.com" `
    -Username "admin" `
    -Password $pass `
    -Count 100

# Export critical events to CSV
.\nutanix-cli-prism-events.ps1 `
    -PrismCentralHost "pc.domain.com" `
    -Username "admin" `
    -Password $pass `
    -SeverityLevel Critical `
    -OutputFormat CSV
```

### Protection Domains

```powershell
# List protection domains
.\nutanix-cli-protection-domains.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "List" `
    -ClusterName "Prod-Cluster"

# Create a protection domain and assign VMs
.\nutanix-cli-protection-domains.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Create" `
    -ProtectionDomainName "PD-WebServers" `
    -VMNames @("Web01", "Web02", "Web03")
```
