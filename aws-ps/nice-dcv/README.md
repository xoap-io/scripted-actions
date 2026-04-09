# NICE DCV Scripts

PowerShell scripts for deploying, configuring, and managing NICE DCV
(Desktop Cloud Visualization) servers on AWS EC2 using AWS Tools for
PowerShell.

## Prerequisites

- AWS Tools for PowerShell:
  - `Install-Module -Name AWS.Tools.EC2`
  - `Install-Module -Name AWS.Tools.SimpleSystemsManagement`
- EC2 instances must have the SSM Agent installed and an instance
  profile with `AmazonSSMManagedInstanceCore` permissions for scripts
  that use SSM
- Appropriate AWS credentials configured

## Available Scripts

| Script                                 | Description                                                                    |
| -------------------------------------- | ------------------------------------------------------------------------------ |
| `nice-dcv-authorize-dcv-ports.ps1`     | Adds TCP and UDP DCV port rules to an existing EC2 security group              |
| `nice-dcv-create-ami-windows.ps1`      | Creates an AMI from a Windows EC2 instance with NICE DCV installed             |
| `nice-dcv-create-security-group.ps1`   | Creates a new EC2 security group pre-configured with DCV port 8443 rules       |
| `nice-dcv-create-user.ps1`             | Creates a DCV user on a Linux EC2 instance via SSM                             |
| `nice-dcv-delete-instance-windows.ps1` | Terminates a Windows EC2 instance running NICE DCV                             |
| `nice-dcv-describe-sessions.ps1`       | Lists active DCV sessions on an instance via SSM                               |
| `nice-dcv-get-connection-info.ps1`     | Retrieves and displays the public IP and DCV URL for an instance               |
| `nice-dcv-install-linux.ps1`           | Remotely installs NICE DCV on a Linux EC2 instance via SSM                     |
| `nice-dcv-install-windows.ps1`         | Remotely installs NICE DCV on a Windows EC2 instance via SSM                   |
| `nice-dcv-quickstart.ps1`              | Launches an EC2 instance, authorizes DCV ports, and waits for it to be running |
| `nice-dcv-reboot-instance-windows.ps1` | Reboots a Windows EC2 instance running NICE DCV                                |
| `nice-dcv-start-instance-windows.ps1`  | Starts a stopped Windows EC2 instance running NICE DCV                         |
| `nice-dcv-stop-instance-windows.ps1`   | Stops a running Windows EC2 instance running NICE DCV                          |
| `nice-dcv-terminate-session.ps1`       | Terminates a DCV session by session ID via SSM                                 |
| `nice-dcv-uninstall-windows.ps1`       | Uninstalls NICE DCV from a Windows EC2 instance via SSM                        |
| `nice-dcv-update-windows.ps1`          | Updates NICE DCV to the latest version on a Windows EC2 instance via SSM       |

## Usage Examples

### NICE DCV Quickstart

```powershell
.\nice-dcv-quickstart.ps1 `
    -AmiId ami-0abcdef1234567890 `
    -InstanceType g4dn.xlarge `
    -KeyPairName my-key-pair `
    -SecurityGroupId sg-0abcdef1234567890 `
    -SubnetId subnet-0abcdef1234567890 `
    -DcvPort 8443
```

### Create Security Group for DCV

```powershell
.\nice-dcv-create-security-group.ps1 `
    -GroupName "nice-dcv-sg" `
    -Description "Security group for NICE DCV access" `
    -VpcId vpc-0abcdef1234567890
```

### Install NICE DCV on Linux via SSM

```powershell
.\nice-dcv-install-linux.ps1 -InstanceId i-0abcdef1234567890
```

### Install NICE DCV on Windows via SSM

```powershell
.\nice-dcv-install-windows.ps1 -InstanceId i-0abcdef1234567890
```

### Get DCV Connection URL

```powershell
.\nice-dcv-get-connection-info.ps1 `
    -InstanceId i-0abcdef1234567890 `
    -DcvPort 8443 `
    -UserName dcvuser
```

### Terminate a DCV Session

```powershell
.\nice-dcv-terminate-session.ps1 `
    -InstanceId i-0abcdef1234567890 `
    -SessionId session-1234
```

### Create an AMI from a Configured DCV Instance

```powershell
.\nice-dcv-create-ami-windows.ps1 `
    -InstanceId i-0abcdef1234567890 `
    -AmiName "nice-dcv-windows-2025-04"
```

## Notes

- DCV uses port 8443 for both TCP (HTTPS web client) and UDP (QUIC
  protocol). Scripts that open ports authorize both protocols.
- Scripts that interact with the DCV server (install, create-user,
  describe-sessions, terminate-session, uninstall, update) use AWS
  Systems Manager and require the instance to have SSM Agent running.
- GPU instance types (G4, G5 families) are recommended for
  graphics-intensive workloads.
