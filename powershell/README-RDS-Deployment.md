# RDS Multi-Server Deployment Script

## Overview

The `rds-deployment.ps1` script automates the deployment of a complete Remote Desktop Services (RDS) environment across multiple Windows servers. It provides flexible deployment options allowing you to skip optional components like RD Gateway and RD Licensing based on your environment's needs.

## Features

- **Multi-Server RDS Deployment**: Configures RDS across 3-5 servers depending on selected components
- **Windows Features Installation**: Automatically installs required RDS roles and features
- **SMB Share Creation**: Sets up secure file shares for User Profile Disks and roaming profiles
- **User Profile Disks (UPD)**: Configures UPD with proper permissions and size limits
- **Certificate Integration**: Supports SSL certificate configuration for RD Gateway and Connection Broker
- **Flexible Component Selection**: Optional RD Gateway and RD Licensing deployment
- **Language-Agnostic**: Uses SIDs for permissions to work across different Windows language versions
- **Error Handling**: Comprehensive error checking and validation throughout the process

## Architecture

### Full Deployment (Default)
```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   File Server   │  │ RD Session Host │  │  RD Gateway     │
│                 │  │                 │  │                 │
│ - File Services │  │ - RD Session    │  │ - RD Gateway    │
│ - UPD Share     │  │   Host          │  │ - SSL Certs     │
│ - Profile Share │  │                 │  │                 │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
┌─────────────────┐  ┌─────────────────┐
│ Connection      │  │ RD Licensing    │
│ Broker + Web    │  │ Server          │
│                 │  │                 │
│ - RD Broker     │  │ - RD Licensing  │
│ - Web Access    │  │ - CAL Management│
│ - SSL Certs     │  │                 │
└─────────────────┘  └─────────────────┘
```

### Minimal Deployment (with Skip Options)
```
┌─────────────────┐  ┌─────────────────┐
│   File Server   │  │ RD Session Host │
│                 │  │                 │
│ - File Services │  │ - RD Session    │
│ - UPD Share     │  │   Host          │
│ - Profile Share │  │                 │
└─────────────────┘  └─────────────────┘
         │                     │
         └─────────────────────┘
                     │
      ┌─────────────────┐
      │ Connection      │
      │ Broker + Web    │
      │                 │
      │ - RD Broker     │
      │ - Web Access    │
      └─────────────────┘
```

## Prerequisites

### System Requirements

- Windows Server 2016 or later on all target servers
- Active Directory domain environment
- PowerShell 5.1 or later
- Administrative privileges on all target servers

### Network Requirements

- PowerShell Remoting (WinRM) enabled on all servers
- SMB file sharing ports (445) open between servers
- RDP ports (3389) configured as needed
- HTTPS (443) for RD Gateway if used

### Domain Requirements

- All servers must be domain-joined
- Service account or user with domain admin privileges
- DNS resolution working between all servers

## Parameters

### Core Server Parameters

- **`DomainFqdn`** - FQDN of the Active Directory domain
- **`FileServer`** - Hostname of the File Server
- **`BrokerAndWeb`** - Hostname of the RD Connection Broker + Web Access (run script here)
- **`SessionHost`** - Hostname of the RD Session Host
- **`LicensingServer`** - Hostname of the RD Licensing Server
- **`GatewayServer`** - Hostname of the RD Gateway Server

### Configuration Parameters

- **`CollectionName`** - Name of the RDS session collection (default: 'MainCollection')
- **`CollectionDesc`** - Description of the session collection
- **`CollectionUserGroup`** - Domain group allowed to log on to the collection
- **`UPDShareName`** - Name of the UPD SMB share (default: 'RDS-ProfileDisks$')
- **`ProfilesShareName`** - Name of the roaming profiles SMB share (default: 'RDS-Profiles$')
- **`UPDLocalPath`** - Local path for UPD share on File Server
- **`ProfilesLocalPath`** - Local path for profiles share on File Server (default: 'C:\UserProfiles')
- **`UPDMaxSizeGB`** - Max size (GB) for User Profile Disks (default: 30)
- **`RdsLicenseMode`** - Licensing mode: 'PerUser' or 'PerDevice' (default: 'PerUser')

### Optional Components

- **`SkipGateway`** - Skip RD Gateway server deployment and configuration
- **`SkipLicensing`** - Skip RD Licensing server deployment and configuration

### Certificate Parameters

- **`GatewayExternalFqdn`** - External FQDN for RD Gateway (optional)
- **`BrokerCertThumbprint`** - SSL certificate thumbprint for Connection Broker
- **`GatewayCertThumbprint`** - SSL certificate thumbprint for RD Gateway

## Usage Examples

### 1. Full RDS Deployment

```powershell
# Deploy complete RDS environment with all components
.\rds-deployment.ps1 `
    -DomainFqdn "contoso.local" `
    -FileServer "rds-files.contoso.local" `
    -BrokerAndWeb "rds-broker.contoso.local" `
    -SessionHost "rds-session.contoso.local" `
    -LicensingServer "rds-license.contoso.local" `
    -GatewayServer "rds-gateway.contoso.local" `
    -CollectionName "Production"
```

### 2. Skip RD Gateway

```powershell
# Deploy without RD Gateway (internal-only environment)
.\rds-deployment.ps1 `
    -DomainFqdn "contoso.local" `
    -FileServer "rds-files.contoso.local" `
    -BrokerAndWeb "rds-broker.contoso.local" `
    -SessionHost "rds-session.contoso.local" `
    -LicensingServer "rds-license.contoso.local" `
    -SkipGateway
```

### 3. Skip RD Licensing

```powershell
# Deploy without RD Licensing (using grace period or separate licensing)
.\rds-deployment.ps1 `
    -DomainFqdn "contoso.local" `
    -FileServer "rds-files.contoso.local" `
    -BrokerAndWeb "rds-broker.contoso.local" `
    -SessionHost "rds-session.contoso.local" `
    -GatewayServer "rds-gateway.contoso.local" `
    -SkipLicensing
```

### 4. Minimal Deployment

```powershell
# Deploy only core RDS components
.\rds-deployment.ps1 `
    -DomainFqdn "contoso.local" `
    -FileServer "rds-files.contoso.local" `
    -BrokerAndWeb "rds-broker.contoso.local" `
    -SessionHost "rds-session.contoso.local" `
    -SkipGateway `
    -SkipLicensing
```

### 5. Custom UPD Configuration

```powershell
# Deploy with custom User Profile Disk settings
.\rds-deployment.ps1 `
    -DomainFqdn "contoso.local" `
    -FileServer "rds-files.contoso.local" `
    -BrokerAndWeb "rds-broker.contoso.local" `
    -SessionHost "rds-session.contoso.local" `
    -UPDMaxSizeGB 50 `
    -UPDShareName "UserDisks$" `
    -CollectionUserGroup "CONTOSO\RDS Users"
```

## Deployment Process

The script follows this sequential process:

1. **Pre-checks**
   - Validates execution context
   - Tests PowerShell Remoting to all servers
   - Imports required modules

2. **Windows Features Installation**
   - File Server: FS-FileServer, FS-Resource-Manager
   - Connection Broker/Web: RDS-Connection-Broker, RDS-Web-Access
   - Session Host: RDS-RD-Server
   - Licensing Server: RDS-Licensing, RDS-Licensing-UI (if not skipped)
   - Gateway Server: RDS-Gateway (if not skipped)

3. **File Share Creation**
   - Creates UPD and Profile directories on File Server
   - Configures SMB shares with proper permissions
   - Sets NTFS permissions using language-agnostic SIDs

4. **Server Manager Integration**
   - Adds all servers to Server Manager computer pool
   - Enables centralized management

5. **RDS Deployment Setup**
   - Creates new RDS deployment or extends existing
   - Configures Connection Broker and Web Access
   - Adds Session Host to deployment

6. **Optional Component Configuration**
   - RD Licensing: Adds licensing server and sets license mode
   - RD Gateway: Adds gateway server and configures access

7. **Session Collection Creation**
   - Creates RDS session collection
   - Configures user group access
   - Enables User Profile Disks

8. **Certificate Integration**
   - Applies SSL certificates to Connection Broker/Web
   - Applies SSL certificates to RD Gateway (if configured)

## File Shares and Permissions

### SMB Shares Created

- **UPD Share** (`RDS-ProfileDisks$`): Stores User Profile Disks
- **Profiles Share** (`RDS-Profiles$`): Stores roaming user profiles

### Permissions Applied

- **Share Permissions**:
  - BUILTIN\Administrators: Full Control
  - NT AUTHORITY\SYSTEM: Full Control
  - Domain Users: Change

- **NTFS Permissions** (using SIDs for language compatibility):
  - BUILTIN\Administrators (S-1-5-32-544): Full Control
  - NT AUTHORITY\SYSTEM (S-1-5-18): Full Control
  - Domain Users (S-1-5-21-domain-513): Modify

## Security Considerations

### Account Requirements

- Run the script with domain administrator privileges
- Service accounts should follow least-privilege principles after deployment

### Network Security

- Ensure SMB signing is configured appropriately
- Use IPSec or network segmentation for server-to-server communication
- Configure Windows Firewall rules as needed

### Certificate Management

- Use valid SSL certificates for RD Gateway external access
- Regularly update and renew certificates
- Store certificate private keys securely

## Troubleshooting

### Common Issues

#### PowerShell Remoting Failures
```
Error: Cannot connect to server via PowerShell Remoting
```
**Solution:**
- Verify WinRM is enabled: `winrm quickconfig`
- Check firewall rules for PowerShell Remoting
- Ensure proper DNS resolution between servers

#### Permission Denied Errors

```
Error: Access denied when creating shares or setting permissions
```

**Solution:**
- Run script with domain administrator account
- Verify account has local admin rights on File Server
- Check if UAC is interfering with remote operations

#### Feature Installation Failures
```
Error: Failed to install Windows Feature
```
**Solution:**
- Verify Windows Update services are running
- Check if server requires restart from previous installations
- Ensure sufficient disk space for feature installation

#### License Server Issues
```
Error: Failed to set RD License configuration
```
**Solution:**
- Verify RD Licensing server is activated
- Check if appropriate CALs are installed
- Ensure license server is reachable from Connection Broker

### Log Locations

- **Event Logs**: Check System and Application logs on all servers
- **RDS Logs**: `%SystemRoot%\System32\LogFiles\`
- **PowerShell Logs**: Windows PowerShell event log

### Validation Commands

```powershell
# Check RDS deployment status
Get-RDServer -ConnectionBroker "broker.domain.com"

# Verify session collection
Get-RDSessionCollection -ConnectionBroker "broker.domain.com"

# Check UPD configuration
Get-RDSessionCollectionConfiguration -CollectionName "MainCollection" -ConnectionBroker "broker.domain.com"

# Verify file shares
Get-SmbShare | Where-Object {$_.Name -like "*RDS*"}
```

## Post-Deployment Tasks

### Immediate Tasks

1. **Activate RD Licensing Server**
   - Install appropriate CALs (User or Device)
   - Verify license server activation

2. **Configure RD Gateway Policies** (if deployed)
   - Set up Connection Authorization Policies (CAP)
   - Configure Resource Authorization Policies (RAP)

3. **Test User Connectivity**
   - Verify users can connect via RD Web Access
   - Test profile disk functionality

### Optional Enhancements

1. **Group Policy Configuration**
   - Configure RDS-specific Group Policy settings
   - Set session timeout and reconnection policies

2. **Monitoring Setup**
   - Configure performance monitoring
   - Set up event log monitoring

3. **Backup Configuration**
   - Include UPD and profile shares in backup strategy
   - Document RDS configuration for disaster recovery

## Version History

- **v1.0**: Initial release with full RDS deployment
- **v2.0**: Added optional component support (SkipGateway, SkipLicensing)
- **v2.1**: Enhanced error handling and validation
- **v2.2**: Added language-agnostic permission handling

## Support

For issues and feature requests:

- Check the troubleshooting section above
- Review Windows Event Logs on affected servers
- Consult Microsoft RDS documentation for role-specific issues

## Related Scripts

- `ws2019-rds-optimization.ps1` - RDS performance optimization
- `ws2019-rds-optimization-restore.ps1` - Restore optimization settings

---

**Note**: This script follows the repository conventions for parameter validation, error handling, and output formatting. It's designed to be run once per environment but can be safely re-executed if deployment needs to be extended or verified.
