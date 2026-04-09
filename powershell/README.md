# PowerShell - RDS Deployment and Optimization Scripts

This directory contains PowerShell scripts for deploying and optimizing
Remote Desktop Services (RDS) environments on Windows Server.

## Prerequisites

- Windows Server 2016 or later (2019/2022 recommended)
- PowerShell 5.1 or later
- Administrator privileges
- Remote Desktop Services role available
- Active Directory (for production deployments)

## Subdirectories

| Directory         | Description                                                                                            |
| ----------------- | ------------------------------------------------------------------------------------------------------ |
| `windows-server/` | Windows Server management scripts: local users, Windows Update, WinRM configuration, and CIS hardening |

## Available Scripts

### RDS Deployment

- **rds-deployment.ps1** - Complete RDS deployment automation
  - Connection Broker setup
  - Session Host configuration
  - RD Web Access setup
  - RD Gateway configuration
  - Collection creation

### Windows Server 2019 RDS Optimization

- **ws2019-rds-optimization.ps1** - Optimize Windows Server 2019 for RDS

  - Disable unnecessary services
  - Configure visual effects for performance
  - Optimize disk usage
  - Network tuning
  - Configure user profile management

- **ws2019-rds-optimization-restore.ps1** - Restore original settings
  - Revert optimization changes
  - Re-enable services
  - Restore default configurations

### System Management

- **reset-os.ps1** - System reset and cleanup operations

## Usage Examples

### Deploy Complete RDS Environment

```powershell
# Review README-RDS-Deployment.md for detailed deployment guide
.\rds-deployment.ps1 `
    -ConnectionBroker "RDS-CB01.domain.com" `
    -SessionHosts @("RDS-SH01.domain.com", "RDS-SH02.domain.com") `
    -WebAccess "RDS-WEB01.domain.com" `
    -Gateway "RDS-GW01.domain.com" `
    -CollectionName "Production Desktop Collection"
```

### Optimize Windows Server 2019 RDS

```powershell
# Optimize RDS Session Host
.\ws2019-rds-optimization.ps1 -Verbose

# Create system restore point before optimization
Checkpoint-Computer -Description "Before RDS Optimization"

# Run optimization
.\ws2019-rds-optimization.ps1

# If needed, restore original settings
.\ws2019-rds-optimization-restore.ps1
```

## RDS Deployment Architecture

### Standard RDS Deployment Components

1. **Connection Broker**

   - Session load balancing
   - Session reconnection
   - RemoteApp management
   - High availability (HA) possible

1. **Session Hosts**

   - User sessions
   - Application execution
   - Resource consumption
   - Scale-out for capacity

1. **Web Access**

   - Web-based access portal
   - RemoteApp publishing
   - User-friendly interface

1. **Gateway**

   - External access via HTTPS
   - SSL/TLS encryption
   - RDP over HTTPS
   - Firewall traversal

1. **Licensing**
   - RDS CAL management
   - Per-user or per-device licensing
   - Grace period tracking

## Optimization Areas

### Performance Optimizations

- Disable visual effects
- Optimize for background services
- Disable unnecessary features
- Configure page file
- Network adapter tuning

### Services Optimization

- Disable unused services
- Configure startup types
- Optimize service dependencies
- Resource usage reduction

### User Experience

- Fast logon optimization
- Profile management
- Folder redirection
- Group Policy optimizations

### Storage Optimization

- Disk cleanup
- Temporary file management
- User profile optimization
- AppData cleanup

## Best Practices

### Deployment

- Use dedicated servers for each role (production)
- Implement high availability for Connection Broker
- Deploy multiple Session Hosts for load balancing
- Use certificates from trusted CA
- Implement proper network segmentation

### Security

- Use RD Gateway for external access
- Implement Network Level Authentication (NLA)
- Configure Windows Firewall appropriately
- Use least privilege principles
- Regular security updates
- Enable audit logging

### Performance

- Size Session Hosts appropriately (2-4 vCPUs per 10 users guideline)
- Adequate memory (minimum 4GB + 512MB per user)
- Use SSDs for Session Host OS drives
- Implement user profile management (FSLogix, UPD)
- Regular performance monitoring

### Scalability

- Plan for growth
- Use Session Collections
- Implement load balancing
- Consider Azure Virtual Desktop for cloud scenarios
- Profile disk management

### Maintenance

- Regular Windows Updates
- Monitor resource utilization
- Clean up disconnected sessions
- Regular backup of RDS configuration
- Test disaster recovery procedures

## Licensing Requirements

- Windows Server license
- RDS CALs (Client Access Licenses)
- Per-user or per-device licensing
- Windows Server CALs
- External Connector license (for external users)

## Troubleshooting

### Common Issues

- Session Host not appearing in collection
- Users cannot connect
- Performance degradation
- License server issues
- Certificate problems

### Diagnostic Commands

```powershell
# Check RDS role services
Get-WindowsFeature | Where-Object {$_.Name -like "RDS-*"}

# Check RDS deployment
Get-RDServer
Get-RDSessionHost
Get-RDSessionCollection

# Check user sessions
Get-RDUserSession -ConnectionBroker "RDS-CB01.domain.com"

# Test connectivity
Test-NetConnection -ComputerName "RDS-SH01.domain.com" -Port 3389
```

## Related Documentation

For detailed deployment instructions, see:

- [README-RDS-Deployment.md](README-RDS-Deployment.md)
- [README-WS2019-RDS-Optimization.md](README-WS2019-RDS-Optimization.md)

External Resources:

- [RDS Documentation](https://docs.microsoft.com/windows-server/remote/remote-desktop-services/welcome-to-rds)
- [RDS Architecture](https://docs.microsoft.com/windows-server/remote/remote-desktop-services/desktop-hosting-logical-architecture)
- [RDS Best Practices](https://docs.microsoft.com/windows-server/remote/remote-desktop-services/rds-plan-high-availability)

## Support

For issues or questions, please refer to the main repository documentation.
