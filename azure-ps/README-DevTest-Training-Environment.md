# Azure DevTest Labs Training Environment Creator

## Overview

The `az-ps-create-devtest-training-environment.ps1` script provides a complete solution for creating, managing, and tearing down Azure DevTest Labs training environments. It's designed specifically for training scenarios where multiple students need access to VMs from the internet with proper cost management and automated lifecycle policies.

## Key Features

### **Complete Training Environment**

- **Multi-VM Deployment**: Create both Windows and Linux VMs for diverse training needs
- **User Management**: Automatically assign users with appropriate permissions
- **Internet Access**: Configure public IPs or shared IP addresses for external access
- **Cost Optimization**: Implement auto-shutdown, startup policies, and cost thresholds

### **DevTest Labs Benefits**

- **Claimable VMs**: Students can claim and release VMs as needed
- **Policy Enforcement**: Automatic limits on VM count, sizes, and usage
- **Template-Based**: Consistent VM configurations using formulas
- **Artifact Support**: Automated software installation during VM creation

### **Operational Simplicity**

- **One-Command Deployment**: Single script creates entire environment
- **Easy Cleanup**: Complete environment deletion with confirmation
- **Status Monitoring**: Check environment status and resource usage
- **Bulk Operations**: Start/stop all VMs simultaneously

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure DevTest Labs Environment                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Windows VM   │  │ Windows VM   │  │ Windows VM   │          │
│  │ (Claimable)  │  │ (Claimable)  │  │ (Claimable)  │   ...    │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Linux VM     │  │ Linux VM     │  │ Linux VM     │          │
│  │ (Claimable)  │  │ (Claimable)  │  │ (Claimable)  │   ...    │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                      Lab Policies                               │
│  • Auto-shutdown: 6:00 PM daily                               │
│  • Auto-startup: 8:00 AM daily                                │
│  • Max VMs per user: 3                                        │
│  • Max VMs per lab: 50                                        │
│  • Cost threshold: $500/month                                 │
├─────────────────────────────────────────────────────────────────┤
│                    User Access                                  │
│  • Students: DevTest Labs User role                           │
│  • Instructors: Owner role                                    │
│  • Internet access via public IPs                             │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### **Azure Requirements**

- Active Azure subscription with appropriate permissions
- Contributor role or higher in target subscription
- Sufficient quota for VMs in target region
- Azure PowerShell modules installed

### **PowerShell Modules**

```powershell
Install-Module -Name Az -AllowClobber -Force
Install-Module -Name Az.DevTestLabs -Force
```

### **User Management**

- Azure AD tenant with user accounts
- Email addresses for all training participants
- Proper permissions to assign Azure RBAC roles

## Usage Examples

### **1. Create Complete Training Environment**

Create a training environment for a PowerShell course with 20 students:

```powershell
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "PowerShellTraining2025" `
    -ResourceGroupName "training-rg" `
    -Location "East US 2" `
    -TrainingUserEmails @(
        "student1@contoso.com",
        "student2@contoso.com",
        "student3@contoso.com"
        # ... add all student emails
    ) `
    -InstructorEmails @("instructor@contoso.com") `
    -WindowsVMCount 15 `
    -LinuxVMCount 5 `
    -VMSize "Standard_B2s" `
    -AllowPublicIP $true `
    -AutoShutdownTime "1800" `
    -AutoStartupTime "0800" `
    -MaxVMsPerUser 2 `
    -CostThreshold 750 `
    -TrainingDuration 14 `
    -Action Create
```

### **2. Create Linux-Only Development Environment**

For a Python/Linux training course:

```powershell
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "PythonDevWorkshop" `
    -ResourceGroupName "python-training-rg" `
    -Location "West US 2" `
    -TrainingUserEmails @("dev1@company.com", "dev2@company.com") `
    -InstructorEmails @("mentor@company.com") `
    -WindowsVMCount 0 `
    -LinuxVMCount 10 `
    -VMSize "Standard_D2s_v3" `
    -AllowPublicIP $true `
    -InstallCommonTools $true `
    -Action Create
```

### **3. Check Environment Status**

Monitor the current state of your training environment:

```powershell
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "PowerShellTraining2025" `
    -ResourceGroupName "training-rg" `
    -Action Status
```

### **4. Emergency Stop All VMs**

Stop all VMs immediately to control costs:

```powershell
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "PowerShellTraining2025" `
    -ResourceGroupName "training-rg" `
    -Action Stop
```

### **5. Clean Up Environment**

Complete environment deletion after training:

```powershell
.\az-ps-create-devtest-training-environment.ps1 `
    -LabName "PowerShellTraining2025" `
    -ResourceGroupName "training-rg" `
    -Action Delete
```

## Configuration Parameters

### **Core Environment Settings**

| Parameter           | Description         | Example                  | Required |
| ------------------- | ------------------- | ------------------------ | -------- |
| `LabName`           | DevTest Lab name    | "PowerShellTraining2025" | Yes      |
| `ResourceGroupName` | Resource group name | "training-rg"            | Yes      |
| `Location`          | Azure region        | "East US 2"              | Yes      |
| `SubscriptionId`    | Target subscription | "guid-here"              | Optional |

### **VM Configuration**

| Parameter        | Description              | Default      | Options                |
| ---------------- | ------------------------ | ------------ | ---------------------- |
| `WindowsVMCount` | Number of Windows VMs    | 10           | 0-50                   |
| `LinuxVMCount`   | Number of Linux VMs      | 5            | 0-50                   |
| `VMSize`         | VM size for all machines | Standard_B2s | B1s, B2s, D2s_v3, etc. |
| `AllowPublicIP`  | Enable internet access   | true         | true/false             |

### **Access Control**

| Parameter            | Description                | Format                     | Required |
| -------------------- | -------------------------- | -------------------------- | -------- |
| `TrainingUserEmails` | Student email addresses    | @("user1@domain.com")      | Optional |
| `InstructorEmails`   | Instructor email addresses | @("instructor@domain.com") | Optional |
| `MaxVMsPerUser`      | VM limit per user          | 3                          | 1-20     |
| `MaxVMsPerLab`       | Total VM limit             | 50                         | 5-100    |

### **Cost Management**

| Parameter          | Description                 | Default | Range         |
| ------------------ | --------------------------- | ------- | ------------- |
| `AutoShutdownTime` | Daily shutdown time         | "1800"  | "0000"-"2359" |
| `AutoStartupTime`  | Daily startup time          | "0800"  | "0000"-"2359" |
| `CostThreshold`    | Monthly cost alert (USD)    | 500     | 50-10000      |
| `TrainingDuration` | Environment lifetime (days) | 7       | 1-90          |

### **Advanced Options**

| Parameter            | Description               | Default |
| -------------------- | ------------------------- | ------- |
| `TimeZoneId`         | Timezone for scheduling   | "UTC"   |
| `InstallCommonTools` | Install development tools | true    |
| `EnableVPNGateway`   | Create VPN gateway        | false   |

## Student Access Process

### **For Students**

1. **Receive Lab URL** from instructor (provided in script output)
2. **Sign in** to Azure portal with provided credentials
3. **Navigate** to the DevTest Lab
4. **Claim a VM** from the "Claimable virtual machines" section
5. **Connect** to VM using RDP (Windows) or SSH (Linux)
6. **Release VM** when finished to allow others to use it

### **VM Credentials**

All training VMs use standard credentials:

- **Username**: `trainee`
- **Password**: `Training123!`

_(Instructors can customize these in the script)_

## Cost Management Features

### **Automatic Policies**

- **Auto-shutdown**: VMs shut down automatically at specified time
- **Auto-startup**: VMs start automatically for training sessions
- **Usage limits**: Maximum VMs per user and per lab
- **Size restrictions**: Only approved VM sizes available

### **Cost Monitoring**

- **Threshold alerts**: Email notifications when costs approach limits
- **Usage reports**: Track VM usage and costs in Azure portal
- **Expiration dates**: Automatic environment cleanup after training period

### **Manual Controls**

- **Bulk operations**: Start/stop all VMs with single command
- **Emergency shutdown**: Immediate cost control capabilities
- **Complete cleanup**: One-command environment deletion

## Internet Access Options

### **Public IP (Default)**

- Each VM gets its own public IP address
- Direct internet access for all VMs
- Students can access VMs from anywhere
- Higher cost but maximum flexibility

### **Shared IP (Alternative)**

- VMs share public IP addresses
- Network address translation for connections
- Lower cost but more complex access
- Requires specific port assignments

### **VPN Gateway (Optional)**

- Secure VPN connection to lab environment
- All VMs accessible through VPN tunnel
- Higher security but requires VPN client setup
- Additional cost for VPN gateway

## Security Considerations

### **Network Security**

- Network Security Groups automatically configured
- Only necessary ports opened (RDP 3389, SSH 22)
- Azure Firewall integration available
- VPN option for enhanced security

### **Access Control**

- Azure AD integration for user authentication
- Role-based access control (RBAC)
- Students can only access their claimed VMs
- Instructors have administrative access

### **VM Security**

- Standard VM security features enabled
- Windows Update automatic installation
- Basic antivirus on Windows VMs
- Regular security patches via Azure

## Troubleshooting

### **Common Issues**

#### **Authentication Failures**

```
Error: No Azure context found
```

**Solution**: Run `Connect-AzAccount` and ensure proper subscription access

#### **Quota Exceeded**

```
Error: Not enough cores available in region
```

**Solution**: Choose different region or request quota increase

#### **User Assignment Failures**

```
Warning: User email@domain.com not found in Azure AD
```

**Solution**: Verify user email addresses and Azure AD membership

#### **VM Creation Timeouts**

```
Error: VM deployment timed out
```

**Solution**: Check Azure service health and retry with smaller batch sizes

### **Monitoring Commands**

Check lab status:

```powershell
Get-AzResource -ResourceGroupName "training-rg" -ResourceType "Microsoft.DevTestLab/labs"
```

List all VMs:

```powershell
Get-AzResource -ResourceGroupName "training-rg" -ResourceType "Microsoft.DevTestLab/labs/virtualmachines"
```

Check costs:

```powershell
Get-AzConsumptionUsageDetail -ResourceGroupName "training-rg"
```

## Best Practices

### **Planning Phase**

- **Size appropriately**: Start with fewer VMs and scale up
- **Choose regions wisely**: Consider proximity to users and costs
- **Set realistic budgets**: Account for storage, networking, and compute
- **Plan for peak usage**: Ensure sufficient quota during training hours

### **During Training**

- **Monitor costs daily**: Use Azure Cost Management
- **Adjust auto-shutdown**: Based on actual training schedule
- **Communicate policies**: Ensure students understand VM claiming process
- **Have backup plan**: Alternative region or VM sizes if issues arise

### **After Training**

- **Export important data**: Before environment deletion
- **Document lessons learned**: For future training sessions
- **Clean up completely**: Avoid ongoing charges
- **Review costs**: Optimize for future deployments

## Integration Options

### **CI/CD Integration**

- Use script in Azure DevOps pipelines
- Automated environment creation for scheduled training
- Integration with approval workflows

### **Monitoring Integration**

- Azure Monitor alerts for cost thresholds
- Log Analytics for usage tracking
- Custom dashboards for environment oversight

### **Identity Integration**

- Azure AD group-based user assignment
- Integration with learning management systems
- Automated user provisioning

## Version History

- **v1.0**: Initial release with basic DevTest Labs functionality
- **v1.1**: Added cost management and auto-shutdown features
- **v1.2**: Enhanced user management and internet access options
- **v1.3**: Added bulk operations and status monitoring

## Support and Contribution

For issues, enhancements, or questions:

- Check Azure DevTest Labs documentation
- Review script parameters and examples
- Test in development environment first
- Monitor Azure costs during deployment

---

**Note**: This script creates real Azure resources that incur costs. Always monitor usage and clean up environments when training is complete to avoid unexpected charges.
