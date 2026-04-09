# Network Scripts

PowerShell scripts for managing AWS networking resources using the AWS
CLI. Covers VPCs, subnets, route tables, gateways, VPN connections,
VPC peering, endpoints, and Elastic IPs.

## Prerequisites

- AWS CLI v2
- Appropriate AWS credentials configured

## Available Scripts

| Script                                         | Description                                                                     |
| ---------------------------------------------- | ------------------------------------------------------------------------------- |
| `aws-cli-accept-vpc-peering-connection.ps1`    | Accepts a pending VPC peering connection request                                |
| `aws-cli-allocate-elastic-ip.ps1`              | Allocates one or more Elastic IP addresses in VPC or EC2-Classic domain         |
| `aws-cli-associate-route-table.ps1`            | Associates a route table with a subnet                                          |
| `aws-cli-attach-internet-gateway.ps1`          | Attaches an internet gateway to a VPC                                           |
| `aws-cli-create-customer-gateway.ps1`          | Creates a customer gateway for VPN connections to on-premises networks          |
| `aws-cli-create-internet-gateway.ps1`          | Creates an internet gateway                                                     |
| `aws-cli-create-nat-gateway.ps1`               | Creates a public or private NAT gateway in a specified subnet                   |
| `aws-cli-create-route-table.ps1`               | Creates a route table for a VPC                                                 |
| `aws-cli-create-route.ps1`                     | Creates a route in a route table                                                |
| `aws-cli-create-subnet.ps1`                    | Creates a subnet within a VPC with IPv4 and IPv6 CIDR blocks                    |
| `aws-cli-create-transit-gateway.ps1`           | Creates a Transit Gateway to interconnect VPCs and on-premises networks         |
| `aws-cli-create-vpc-endpoint.ps1`              | Creates a VPC endpoint for private connectivity to AWS services                 |
| `aws-cli-create-vpc-peering-connection.ps1`    | Creates a VPC peering connection (same-account, cross-account, or cross-region) |
| `aws-cli-create-vpc.ps1`                       | Creates a VPC with a specified IPv4 CIDR block                                  |
| `aws-cli-create-vpn-connection.ps1`            | Creates a VPN connection between a VPC and a customer gateway                   |
| `aws-cli-delete-internet-gateway.ps1`          | Deletes an internet gateway                                                     |
| `aws-cli-delete-nat-gateway.ps1`               | Deletes a NAT gateway                                                           |
| `aws-cli-delete-route.ps1`                     | Deletes a route from a route table                                              |
| `aws-cli-delete-subnet.ps1`                    | Deletes a subnet                                                                |
| `aws-cli-delete-vpc-endpoint.ps1`              | Deletes a VPC endpoint                                                          |
| `aws-cli-delete-vpc-peering-connection.ps1`    | Deletes a VPC peering connection                                                |
| `aws-cli-delete-vpc.ps1`                       | Deletes a VPC                                                                   |
| `aws-cli-describe-elastic-ips.ps1`             | Lists and describes allocated Elastic IP addresses                              |
| `aws-cli-describe-internet-gateways.ps1`       | Lists and describes internet gateways                                           |
| `aws-cli-describe-nat-gateways.ps1`            | Lists and describes NAT gateways                                                |
| `aws-cli-describe-network-interfaces.ps1`      | Lists and describes elastic network interfaces                                  |
| `aws-cli-describe-route-tables.ps1`            | Lists and describes route tables                                                |
| `aws-cli-describe-subnets.ps1`                 | Lists and describes subnets                                                     |
| `aws-cli-describe-vpc-endpoints.ps1`           | Lists and describes VPC endpoints                                               |
| `aws-cli-describe-vpc-peering-connections.ps1` | Lists and describes VPC peering connections                                     |
| `aws-cli-describe-vpcs.ps1`                    | Lists and describes VPCs                                                        |
| `aws-cli-detach-internet-gateway.ps1`          | Detaches an internet gateway from a VPC                                         |
| `aws-cli-disassociate-route-table.ps1`         | Disassociates a route table from a subnet                                       |
| `aws-cli-get-vpc-flow-logs.ps1`                | Retrieves VPC flow log information                                              |
| `aws-cli-modify-subnet-attribute.ps1`          | Modifies an attribute of a subnet                                               |
| `aws-cli-release-elastic-ip.ps1`               | Releases an allocated Elastic IP address                                        |
| `aws-cli-replace-route.ps1`                    | Replaces an existing route in a route table                                     |
| `aws-cli-enable-vpc-flow-logs.ps1`             | Enables VPC Flow Logs to S3, CloudWatch Logs, or Kinesis Data Firehose          |
| `aws-cli-create-network-acl-entry.ps1`         | Adds an inbound or outbound rule to a Network ACL                               |
| `aws-cli-create-private-hosted-zone.ps1`       | Creates a Route 53 private hosted zone and associates it with a VPC             |

## Usage Examples

### Create a VPC

```powershell
.\aws-cli-create-vpc.ps1 -CidrBlock "10.0.0.0/16"
```

### Create a Subnet

```powershell
.\aws-cli-create-subnet.ps1 `
    -AwsVpcId "vpc-0a1b2c3d4e5f67890" `
    -AwsCidrBlock "10.0.1.0/24" `
    -AwsIpv6CidrBlock "2001:db8::/64" `
    -AwsTagSpecifications "ResourceType=subnet,Tags=[{Key=Name,Value=MySubnet}]"
```

### Create a NAT Gateway

```powershell
.\aws-cli-create-nat-gateway.ps1 `
    -SubnetId "subnet-0a1b2c3d4e5f67890" `
    -AllocationId "eipalloc-0a1b2c3d4e5f67890" `
    -WaitForAvailable
```

### Create a VPC Peering Connection

```powershell
.\aws-cli-create-vpc-peering-connection.ps1 `
    -VpcId "vpc-0a1b2c3d4e5f67890" `
    -PeerVpcId "vpc-0f9e8d7c6b5a43210"
```

### Allocate an Elastic IP

```powershell
.\aws-cli-allocate-elastic-ip.ps1 -Domain "vpc"
```

### Create a Customer Gateway

```powershell
.\aws-cli-create-customer-gateway.ps1 `
    -BgpAsn 65000 `
    -IpAddress "203.0.113.12" `
    -Name "Office-Gateway"
```

## Notes

- After creating a VPC peering connection, route tables in both VPCs
  must be updated to enable traffic routing between them.
- Public NAT gateways require an unassociated Elastic IP and must
  reside in a subnet with a route to an internet gateway.
- Ensure CIDR blocks do not overlap when creating VPC peering
  connections.
