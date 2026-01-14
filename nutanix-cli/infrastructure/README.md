# Nutanix CLI - Infrastructure Management Scripts

This directory contains PowerShell scripts for managing Nutanix infrastructure using Nutanix REST API and CLI tools.

## Prerequisites

- Nutanix Prism Central or Prism Element access
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Nutanix REST API credentials
- Network access to Nutanix cluster
- Appropriate Nutanix permissions

## Available Scripts

Scripts for managing Nutanix infrastructure components:

### Cluster Management

- Cluster configuration
- Node operations
- Resource pool management

### Storage Configuration

- Storage container management
- Volume group operations
- Protection domain setup

### Network Management

- Virtual network configuration
- VLAN management
- IP address management (IPAM)

### Monitoring

- Cluster health checks
- Performance metrics
- Alert management

## Usage Examples

### Basic API Authentication

```powershell
# Set credentials
$prismCentral = "prism-central.example.com"
$username = "admin"
$password = ConvertTo-SecureString "password" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username, $password)

# Create auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))
$headers = @{
    "Authorization" = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

# Make API call
$response = Invoke-RestMethod `
    -Uri "https://${prismCentral}:9440/api/nutanix/v3/clusters/list" `
    -Method POST `
    -Headers $headers `
    -Body '{"kind":"cluster"}' `
    -SkipCertificateCheck
```

### Cluster Information

```powershell
# Get cluster list
$clusters = Invoke-RestMethod `
    -Uri "https://${prismCentral}:9440/api/nutanix/v3/clusters/list" `
    -Method POST `
    -Headers $headers `
    -Body '{"kind":"cluster"}' `
    -SkipCertificateCheck

$clusters.entities | Select-Object name, status
```

## Nutanix Best Practices

- **Infrastructure**:

  - Regular cluster health checks
  - Monitor storage capacity
  - Implement protection domains
  - Regular firmware updates
  - Network redundancy

- **Security**:

  - Use RBAC for access control
  - Enable audit logging
  - Implement network segmentation
  - Regular security patching
  - SSL/TLS for communications

- **Performance**:

  - Monitor cluster resources
  - Balance VM distribution
  - Optimize storage configuration
  - Use compression and deduplication
  - Regular performance reviews

- **Availability**:
  - Configure replication
  - Implement DR strategies
  - Use protection domains
  - Regular backup verification
  - Test failover procedures

## Nutanix AHV Features

- **Acropolis Hypervisor (AHV)**:

  - Native hypervisor
  - No licensing costs
  - Integrated management
  - VM-centric operations

- **Data Protection**:

  - Snapshots
  - Replication
  - Protection domains
  - Disaster recovery

- **Storage Optimization**:
  - Deduplication
  - Compression
  - Erasure coding
  - Tiering

## API Versions

- **v2 API**: Legacy API, being deprecated
- **v3 API**: Current recommended API
- **v4 API**: Future API version

## Error Handling

Scripts include:

- Connection validation
- Credential verification
- SSL certificate handling
- API response validation
- Comprehensive error messages

## Related Documentation

- [Nutanix Documentation](https://portal.nutanix.com/page/documents)
- [Nutanix REST API](https://www.nutanix.dev/)
- [Prism Central API](https://www.nutanix.dev/api_references/prism-central-v3/)

## Support

For issues or questions, please refer to the main repository documentation or Nutanix support.
