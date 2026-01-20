# AWS PowerShell - NICE DCV Scripts

This directory contains PowerShell scripts for managing NICE DCV (Desktop Cloud Visualization) servers using AWS Tools for PowerShell.

## Prerequisites

- AWS Tools for PowerShell installed (`Install-Module -Name AWS.Tools.EC2`)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`Set-AWSCredential` or AWS credential file)
- NICE DCV server installed on target EC2 instances
- Appropriate IAM permissions for EC2 and related operations

## About NICE DCV

NICE DCV is a high-performance remote display protocol that enables users to securely connect to remote desktops and application streaming. It's optimized for:

- 3D applications and graphics workloads
- CAD/CAM applications
- Video editing and rendering
- Scientific visualization
- Virtual workstations

## Available Scripts

Scripts in this directory help automate:

- DCV server deployment on EC2
- DCV session management
- License configuration
- Performance optimization
- Security configuration

## Usage Examples

### Typical Workflow

```powershell
# Set AWS credentials
Set-AWSCredential -ProfileName myprofile -Region us-east-1

# Deploy DCV server
.\dcv-deploy-server.ps1 -InstanceType g4dn.xlarge
```

## NICE DCV Best Practices

- **Instance Selection**:

  - Use GPU instances (G4, G5) for graphics-intensive workloads
  - T3/M5 instances for general-purpose applications
  - Consider network performance requirements

- **Security**:

  - Use QUIC protocol for better performance (UDP port 8443)
  - Enable TLS/SSL certificates
  - Restrict security group access to known IPs
  - Use IAM roles for EC2 instances

- **Performance**:

  - Enable GPU sharing when appropriate
  - Configure appropriate video codec (H.264, H.265, VP9)
  - Adjust quality settings based on network conditions
  - Use Amazon FSx for shared storage

- **Licensing**:
  - Use Extended licensing for production workloads
  - Monitor license usage
  - Use RMS (Rights Management Service) when available

## Common Configuration

### Required Ports

- **TCP 8443**: HTTPS connection (DCV web client)
- **UDP 8443**: QUIC protocol (recommended)
- **TCP 22**: SSH access (for administration)

### Environment Variables

- `DCV_SESSION_ID`: Session identifier
- `DCV_GL_DISPLAY`: OpenGL display configuration

## Error Handling

Scripts include:

- Instance state validation
- DCV service availability checks
- License validation
- Network connectivity tests
- Comprehensive error messages

## Related Documentation

- [NICE DCV Documentation](https://docs.aws.amazon.com/dcv/)
- [NICE DCV Administrator Guide](https://docs.aws.amazon.com/dcv/latest/adminguide/)
- [AWS Graphics Workstations](https://aws.amazon.com/graphics-workstations/)
- [AWS Tools for PowerShell](https://docs.aws.amazon.com/powershell/)

## Support

For issues or questions, please refer to the main repository documentation.

For NICE DCV specific issues, consult the [NICE DCV forum](https://forums.nice-dcv.com/).
