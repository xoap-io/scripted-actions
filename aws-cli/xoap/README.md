# XOAP Scripts

PowerShell scripts for integrating AWS resources with the XOAP
platform. These scripts use AWS Systems Manager (SSM) to apply XOAP
DSC policy configurations to EC2 instances.

## Prerequisites

- AWS CLI v2
- Appropriate AWS credentials configured
- EC2 instances must have the SSM Agent installed and the
  AmazonSSMManagedInstanceCore IAM policy attached
- A valid XOAP workspace and group configured in the XOAP platform

## Available Scripts

| Script | Description |
| --- | --- |
| `aws-cli-register-node.ps1` | Registers an EC2 instance with the XOAP platform by running a DSC policy configuration via AWS SSM |

## Usage Examples

### Register a Node with XOAP

```powershell
.\aws-cli-register-node.ps1 `
    -AwsInstanceId "i-0a1b2c3d4e5f67890" `
    -AwsSsmDocumentName "AWS-RunPowerShellScript" `
    -AwsSsmDocumentComment "Register XOAP node" `
    -XOAPWorkspaceId "ws-12345678" `
    -XOAPGroupName "MyGroup"
```

## Notes

- The script sends an SSM `send-command` to the target instance,
  which downloads and invokes the XOAP DSC policy from
  `https://api.xoap.io/dsc/Policy/{WorkspaceId}/Download/{GroupName}`.
- The EC2 instance must be in a running state and reachable by SSM
  before executing this script.
- Verify SSM connectivity with
  `aws ssm describe-instance-information` before registering nodes.
