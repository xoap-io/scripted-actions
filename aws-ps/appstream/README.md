# AppStream 2.0 Scripts

PowerShell scripts for deploying and managing Amazon AppStream 2.0
environments using AWS Tools for PowerShell.

## Prerequisites

- AWS Tools for PowerShell:
  - `Install-Module -Name AWS.Tools.AppStream`
  - `Install-Module -Name AWS.Tools.EC2`
  - `Install-Module -Name AWS.Tools.IdentityManagement`
- Appropriate AWS credentials configured

## Available Scripts

| Script                     | Description                                                                                                       |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `appstream-quickstart.ps1` | Deploys a complete AppStream 2.0 environment including VPC, subnets, NAT gateway, IAM roles, and an image builder |

## Usage Examples

### AppStream Quickstart

```powershell
.\appstream-quickstart.ps1 `
    -CreateAS2Role true `
    -Region us-east-1 `
    -VpcCidr 10.0.0.0/16 `
    -PublicSubnetCidr 10.0.1.0/24 `
    -PrivateSubnet1Cidr 10.0.2.0/24 `
    -PrivateSubnet2Cidr 10.0.3.0/24
```

## Notes

- The quickstart script creates all required networking resources
  (VPC, internet gateway, NAT gateway, route tables) from scratch.
- Set `-CreateAS2Role true` on first run to create the
  `AmazonAppStreamServiceAccess` service-linked IAM role. If the role
  already exists, set it to `false` to skip creation.
- Supported regions: `us-east-1`, `us-west-2`, `eu-west-1`,
  `ap-southeast-1`, `ap-northeast-2`.
- The image builder is launched into the first private subnet using
  the latest AWS-managed Windows Server 2022 general-purpose image.
