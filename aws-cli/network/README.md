# AWS CLI - Network Scripts

This directory contains PowerShell scripts for managing AWS networking resources using the AWS CLI.

## Prerequisites

- AWS CLI v2.16+ installed and configured
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`aws configure`)
- Appropriate IAM permissions for VPC and networking operations

## Available Scripts

### VPC Management

- **aws-cli-create-vpc.ps1** - Creates Virtual Private Clouds
- **aws-cli-delete-vpc.ps1** - Deletes VPCs
- **aws-cli-describe-vpcs.ps1** - Lists and describes VPCs

### Subnet Management

- **aws-cli-create-subnet.ps1** - Creates subnets within VPCs
- **aws-cli-delete-subnet.ps1** - Deletes subnets
- **aws-cli-describe-subnets.ps1** - Lists and describes subnets

### Routing

- **aws-cli-create-route-table.ps1** - Creates route tables
- **aws-cli-describe-route-tables.ps1** - Lists route tables
- **aws-cli-associate-route-table.ps1** - Associates route tables with subnets

### Internet and NAT Gateways

- **aws-cli-create-internet-gateway.ps1** - Creates internet gateways
- **aws-cli-create-nat-gateway.ps1** - Creates NAT gateways
- **aws-cli-attach-internet-gateway.ps1** - Attaches internet gateways to VPCs

### Network Security

- **aws-cli-create-network-acl.ps1** - Creates network ACLs
- **aws-cli-update-network-acl.ps1** - Updates network ACL rules

### VPC Flow Logs

- **aws-cli-get-vpc-flow-logs.ps1** - Retrieves VPC flow log information
- **aws-cli-create-flow-logs.ps1** - Creates VPC flow logs

### Elastic Network Interfaces

- **aws-cli-describe-network-interfaces.ps1** - Lists network interfaces

## Usage Examples

### Create a VPC

```powershell
.\aws-cli-create-vpc.ps1 `
    -CidrBlock "10.0.0.0/16" `
    -Name "MyVPC"
```

### Create a Subnet

```powershell
.\aws-cli-create-subnet.ps1 `
    -VpcId vpc-12345678 `
    -CidrBlock "10.0.1.0/24" `
    -AvailabilityZone us-east-1a
```

### View VPC Flow Logs

```powershell
.\aws-cli-get-vpc-flow-logs.ps1 -VpcId vpc-12345678
```

## Network Architecture Best Practices

- Use multiple availability zones for high availability
- Implement proper CIDR block planning
- Enable VPC Flow Logs for security monitoring
- Use private subnets with NAT gateways for backend resources
- Implement network ACLs and security groups in layers

## Error Handling

All scripts include:

- CIDR block validation
- VPC/subnet existence checks
- Resource dependency validation
- Comprehensive error messages

## Related Documentation

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [AWS CLI Command Reference - EC2 VPC](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/index.html)

## Support

For issues or questions, please refer to the main repository documentation.
