# vSphere CLI - Monitoring Scripts

This directory contains PowerShell scripts for monitoring VMware vSphere
infrastructure using PowerCLI.

## Prerequisites

- VMware PowerCLI 12.0 or later installed:
  - `Install-Module -Name VMware.PowerCLI -Scope CurrentUser`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- vCenter Server or ESXi access
- Read permissions at minimum

## Available Scripts

| Script                               | Description                                                                                                                                       |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `vsphere-cli-get-cluster-health.ps1` | Report cluster health including host state, CPU/memory usage, datastore capacity, and VM count using `Get-Cluster`, `Get-VMHost`, `Get-Datastore` |
| `vsphere-cli-create-alarm.ps1`       | Create a vCenter alarm definition using `New-AlarmDefinition`; supports metric-based triggers with warning and critical thresholds                |

Scripts for monitoring vSphere environments:

### Performance Monitoring

- VM performance metrics
- Host resource utilization
- Storage performance
- Network throughput

### Health Checks

- Cluster health status
- Host connectivity
- Datastore capacity
- VM compliance

### Alerting

- Custom alert creation
- Email notifications
- Event log monitoring
- Threshold-based alerts

### Reporting

- Capacity reports
- Performance trending
- Configuration reports
- Inventory reports

## Usage Examples

### Cluster Health Report

```powershell
$cred = Get-Credential

# Report all clusters
.\vsphere-cli-get-cluster-health.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred

# Report a specific cluster as JSON
.\vsphere-cli-get-cluster-health.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -ClusterName "Production" `
    -OutputFormat JSON
```

### Create Alarm

```powershell
$cred = Get-Credential

# VM CPU usage alarm
.\vsphere-cli-create-alarm.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -AlarmName "High CPU Alert" `
    -Entity VirtualMachine `
    -MetricId "cpu.usage.average" `
    -WarningThreshold 70 `
    -CriticalThreshold 90

# Basic host alarm definition
.\vsphere-cli-create-alarm.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -AlarmName "Host Disconnected" `
    -Description "Alert when a host disconnects" `
    -Entity HostSystem
```

### Connect and Basic Monitoring

```powershell
# Connect to vCenter
Connect-VIServer -Server vcenter.domain.com -User administrator@vsphere.local

# Get VM performance stats
Get-VM | Get-Stat -Stat cpu.usage.average, mem.usage.average -Realtime

# Get host performance
Get-VMHost | Select-Object Name,
    @{N="CPU Usage %"; E={[math]::Round($_.CpuUsageMhz / $_.CpuTotalMhz * 100, 2)}},
    @{N="Memory Usage %"; E={[math]::Round(
        $_.MemoryUsageGB / $_.MemoryTotalGB * 100, 2)}}
```

### Advanced Performance Monitoring

```powershell
# Get detailed VM stats over time
$vm = Get-VM "MyVM"
$stats = Get-Stat -Entity $vm `
    -Stat cpu.usage.average, mem.usage.average, disk.usage.average `
    -Start (Get-Date).AddHours(-24) `
    -Finish (Get-Date) `
    -IntervalMins 5

$stats | Select-Object Timestamp, MetricId, Value, Unit |
    Export-Csv -Path "vm-performance.csv" -NoTypeInformation
```

### Health Monitoring

```powershell
# Check cluster health
Get-Cluster | Select-Object Name,
    HAEnabled,
    HAFailoverLevel,
    DrsEnabled,
    DrsAutomationLevel

# Check host health
Get-VMHost | Select-Object Name,
    ConnectionState,
    PowerState,
    @{N="Overall Status"; E={$_.ExtensionData.OverallStatus}}

# Check datastore capacity
Get-Datastore | Select-Object Name,
    @{N="Capacity GB"; E={[math]::Round($_.CapacityGB, 2)}},
    @{N="Free GB"; E={[math]::Round($_.FreeSpaceGB, 2)}},
    @{N="Free %"; E={[math]::Round($_.FreeSpaceGB / $_.CapacityGB * 100, 2)}} |
    Where-Object {$_.'Free %' -lt 20} |
    Sort-Object 'Free %'
```

### Event Monitoring

```powershell
# Get recent events
Get-VIEvent -Start (Get-Date).AddHours(-24) -MaxSamples 1000 |
    Where-Object {$_.FullFormattedMessage -like "*error*"} |
    Select-Object CreatedTime, UserName, FullFormattedMessage

# Monitor specific event types
Get-VIEvent -Types Error, Warning -Start (Get-Date).AddHours(-1) |
    Select-Object CreatedTime, ObjectName, FullFormattedMessage
```

### Custom Alerts

```powershell
# Create custom alarm for high CPU usage
$alarm = New-AlarmDefinition -Name "High CPU Usage" `
    -Description "Alert when CPU usage exceeds 80%" `
    -Entity (Get-Cluster "Production-Cluster")

# Configure alarm trigger
$trigger = New-AlarmTrigger -Alarm $alarm `
    -Metric "cpu.usage.average" `
    -Operator GreaterThan `
    -Yellow 70 `
    -Red 80

# Configure alarm action
New-AlarmAction -Alarm $alarm -Email -To "admin@domain.com"
```

## Monitoring Best Practices

- **Performance Metrics**:

  - Monitor CPU, memory, storage, network
  - Track trends over time
  - Identify bottlenecks early
  - Use appropriate collection intervals

- **Capacity Planning**:

  - Regular capacity reports
  - Forecast growth
  - Monitor resource consumption
  - Plan for scaling

- **Alerting**:

  - Set meaningful thresholds
  - Avoid alert fatigue
  - Prioritize critical alerts
  - Document response procedures

- **Reporting**:
  - Automate regular reports
  - Track SLA compliance
  - Document changes
  - Share with stakeholders

## Key Metrics to Monitor

### VM Metrics

- CPU usage/ready time
- Memory usage/swap
- Disk latency/IOPS
- Network usage

### Host Metrics

- CPU/memory utilization
- Network throughput
- Storage latency
- Hardware health

### Cluster Metrics

- Resource usage
- HA failover capacity
- DRS recommendations
- vMotion activity

### Storage Metrics

- Datastore space
- Latency
- IOPS
- Throughput

## Monitoring Tools Integration

- **vRealize Operations**: Advanced analytics
- **vCenter Alarms**: Built-in alerting
- **PowerCLI**: Automation and scripting
- **Log Insight**: Log aggregation
- **Third-party**: Grafana, Prometheus, etc.

## Error Handling

Scripts include:

- Connection validation
- Permission checks
- Metric availability verification
- Timeout handling
- Comprehensive error messages

## Related Documentation

- [vSphere Monitoring Documentation](https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-monitoring-performance/GUID-3C1AED1F-7A24-4B17-939E-C9F2B61D5A1B.html)
- [PowerCLI Monitoring Guide](https://developer.vmware.com/docs/powercli/)
- [vSphere Performance Best Practices](https://www.vmware.com/content/dam/digitalmarketing/vmware/en/pdf/techpaper/performance/vsphere-esxi-vcenter-server-70-performance-best-practices.pdf)

## Support

For issues or questions, please refer to the main repository documentation.
