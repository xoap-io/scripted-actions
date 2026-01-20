# vSphere CLI - Infrastructure Management Scripts

This directory contains PowerShell scripts for managing VMware vSphere infrastructure using PowerCLI.

## Prerequisites

- VMware PowerCLI 12.0 or later installed:
  - `Install-Module -Name VMware.PowerCLI -Scope CurrentUser`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- vCenter Server or ESXi access
- Appropriate vSphere permissions
- Network connectivity to vCenter/ESXi

## Available Scripts

Scripts for managing vSphere infrastructure components:

### Cluster Management

- Create and configure clusters
- Add/remove hosts
- DRS (Distributed Resource Scheduler) configuration
- HA (High Availability) settings
- vSAN configuration

### Datacenter Operations

- Datacenter creation
- Folder management
- Resource pool configuration
- Permissions management

### Host Management

- ESXi host configuration
- Maintenance mode operations
- Patch management
- License management

## Usage Examples

### Connect to vCenter

```powershell
# Install PowerCLI if not already installed
Install-Module -Name VMware.PowerCLI -Scope CurrentUser

# Set PowerCLI configuration (ignore certificate warnings for lab)
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

# Connect to vCenter
Connect-VIServer -Server vcenter.domain.com -User administrator@vsphere.local -Password 'P@ssw0rd'
```

### Create Datacenter and Cluster

```powershell
# Create datacenter
$datacenter = New-Datacenter -Location (Get-Folder -NoRecursion) -Name "Production"

# Create cluster
$cluster = New-Cluster -Location $datacenter -Name "Production-Cluster" -HAEnabled -DrsEnabled
```

### Add ESXi Host to Cluster

```powershell
# Add host to cluster
Add-VMHost -Name esxi01.domain.com `
    -Location $cluster `
    -User root `
    -Password 'P@ssw0rd!' `
    -Force

# Put host in maintenance mode
Set-VMHost -VMHost esxi01.domain.com -State Maintenance

# Exit maintenance mode
Set-VMHost -VMHost esxi01.domain.com -State Connected
```

### Configure DRS and HA

```powershell
# Configure DRS
Set-Cluster -Cluster "Production-Cluster" `
    -DrsEnabled $true `
    -DrsAutomationLevel FullyAutomated `
    -DrsMode Manual

# Configure HA
Set-Cluster -Cluster "Production-Cluster" `
    -HAEnabled $true `
    -HAAdmissionControlEnabled $true `
    -HAIsolationResponse PowerOff `
    -HARestartPriority High
```

## vSphere Infrastructure Best Practices

- **Cluster Design**:

  - Minimum 3 hosts for HA
  - Consistent hardware within cluster
  - Proper sizing for N+1 or N+2 redundancy
  - Use DRS for load balancing

- **High Availability**:

  - Enable vSphere HA
  - Configure admission control
  - Set appropriate isolation response
  - Configure datastore heartbeating

- **Resource Management**:

  - Implement resource pools
  - Use shares, reservations, limits wisely
  - Monitor resource usage
  - Balance workloads with DRS

- **Security**:

  - Use vCenter for centralized management
  - Implement role-based access control
  - Enable lockdown mode on hosts
  - Use certificate-based authentication
  - Regular security updates

- **Performance**:
  - Monitor cluster performance
  - Balance VM distribution
  - Use storage DRS
  - Implement network I/O control

## vSphere Features

### vSphere HA (High Availability)

- Automatic VM restart on host failure
- VM and application monitoring
- Proactive HA with hardware monitoring
- Orchestrated restart priorities

### vSphere DRS (Distributed Resource Scheduler)

- Automatic load balancing
- Initial placement
- Resource pools
- Affinity/anti-affinity rules

### vSphere vMotion

- Live VM migration
- Zero downtime
- Storage vMotion
- Cross-vCenter vMotion

### vSAN

- Software-defined storage
- Hyper-converged infrastructure
- Erasure coding or mirroring
- All-flash or hybrid configurations

## Error Handling

Scripts include:

- vCenter connectivity validation
- Permission checks
- Resource availability verification
- Cluster state validation
- Comprehensive error messages

## Related Documentation

- [VMware vSphere Documentation](https://docs.vmware.com/en/VMware-vSphere/index.html)
- [PowerCLI Documentation](https://developer.vmware.com/powercli)
- [PowerCLI Command Reference](https://developer.vmware.com/docs/powercli/latest/)

## Support

For issues or questions, please refer to the main repository documentation.
