<#
.SYNOPSIS
    Associate or disassociate Elastic IP addresses with EC2 instances using AWS CLI.

.DESCRIPTION
    This script provides functionality to associate Elastic IP addresses with EC2 instances,
    disassociate them, or manage allocation and release of Elastic IPs.

.PARAMETER Action
    The action to perform: Associate, Disassociate, Allocate, or Release.

.PARAMETER InstanceId
    The ID of the EC2 instance (required for Associate/Disassociate).

.PARAMETER AllocationId
    The allocation ID of the Elastic IP (for VPC instances).

.PARAMETER PublicIp
    The public IP address (for EC2-Classic instances).

.PARAMETER AssociationId
    The association ID (required for disassociation in VPC).

.PARAMETER NetworkInterfaceId
    The network interface ID to associate with (optional).

.PARAMETER PrivateIpAddress
    The private IP address to associate with (optional).

.PARAMETER AllowReassociation
    Allow reassociation if the Elastic IP is already associated.

.PARAMETER Domain
    The domain for allocation (vpc or standard).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-associate-disassociate-elastic-ip.ps1 -Action Allocate -Domain vpc

.EXAMPLE
    .\aws-cli-associate-disassociate-elastic-ip.ps1 -Action Associate -InstanceId "i-1234567890abcdef0" -AllocationId "eipalloc-12345678"

.EXAMPLE
    .\aws-cli-associate-disassociate-elastic-ip.ps1 -Action Disassociate -AssociationId "eipassoc-12345678"

.EXAMPLE
    .\aws-cli-associate-disassociate-elastic-ip.ps1 -Action Release -AllocationId "eipalloc-12345678"

.NOTES
    Author: XOAP
    Date: 2025-08-06

    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Associate', 'Disassociate', 'Allocate', 'Release')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]{8,}$')]
    [string]$AllocationId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')]
    [string]$PublicIp,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^eipassoc-[a-zA-Z0-9]{8,}$')]
    [string]$AssociationId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^eni-[a-zA-Z0-9]{8,}$')]
    [string]$NetworkInterfaceId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')]
    [string]$PrivateIpAddress,

    [Parameter(Mandatory = $false)]
    [switch]$AllowReassociation,

    [Parameter(Mandatory = $false)]
    [ValidateSet('vpc', 'standard')]
    [string]$Domain = 'vpc',

    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    # Build base AWS CLI arguments
    $awsArgs = @()
    if ($Region) { $awsArgs += @('--region', $Region) }
    if ($Profile) { $awsArgs += @('--profile', $Profile) }

    Write-Output "Performing Elastic IP action: $Action"

    switch ($Action) {
        'Allocate' {
            Write-Output "Allocating new Elastic IP in domain: $Domain"

            $allocateArgs = @('ec2', 'allocate-address', '--domain', $Domain)
            $allocateArgs += $awsArgs
            $allocateArgs += @('--output', 'json')

            $result = & aws @allocateArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                $allocationData = $result | ConvertFrom-Json
                Write-Output "✅ Elastic IP allocated successfully!"
                Write-Output "Public IP: $($allocationData.PublicIp)"
                Write-Output "Allocation ID: $($allocationData.AllocationId)"

                if ($Domain -eq 'vpc') {
                    Write-Output "Domain: VPC"
                } else {
                    Write-Output "Domain: EC2-Classic"
                }
            } else {
                throw "Failed to allocate Elastic IP: $result"
            }
        }

        'Associate' {
            if (-not $InstanceId -and -not $NetworkInterfaceId) {
                throw "Either InstanceId or NetworkInterfaceId must be specified for association."
            }

            if (-not $AllocationId -and -not $PublicIp) {
                throw "Either AllocationId (for VPC) or PublicIp (for EC2-Classic) must be specified."
            }

            Write-Output "Associating Elastic IP with target..."

            # Verify instance exists if InstanceId is provided
            if ($InstanceId) {
                Write-Output "Verifying instance: $InstanceId"
                $instanceResult = aws ec2 describe-instances --instance-ids $InstanceId @awsArgs --output json 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to describe instance: $instanceResult"
                }

                $instanceData = $instanceResult | ConvertFrom-Json
                $instance = $instanceData.Reservations[0].Instances[0]
                Write-Output "Instance state: $($instance.State.Name)"

                if ($instance.State.Name -ne 'running') {
                    Write-Warning "Instance is not in running state. Current state: $($instance.State.Name)"
                }
            }

            # Build association command
            $associateArgs = @('ec2', 'associate-address')
            $associateArgs += $awsArgs

            if ($InstanceId) {
                $associateArgs += @('--instance-id', $InstanceId)
            }

            if ($NetworkInterfaceId) {
                $associateArgs += @('--network-interface-id', $NetworkInterfaceId)
            }

            if ($AllocationId) {
                $associateArgs += @('--allocation-id', $AllocationId)
            }

            if ($PublicIp) {
                $associateArgs += @('--public-ip', $PublicIp)
            }

            if ($PrivateIpAddress) {
                $associateArgs += @('--private-ip-address', $PrivateIpAddress)
            }

            if ($AllowReassociation) {
                $associateArgs += @('--allow-reassociation')
            }

            $associateArgs += @('--output', 'json')

            $result = & aws @associateArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                $associationData = $result | ConvertFrom-Json
                Write-Output "✅ Elastic IP associated successfully!"

                if ($associationData.AssociationId) {
                    Write-Output "Association ID: $($associationData.AssociationId)"
                }

                # Get updated instance information
                if ($InstanceId) {
                    Start-Sleep -Seconds 2
                    $updatedResult = aws ec2 describe-instances --instance-ids $InstanceId @awsArgs --output json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $updatedData = $updatedResult | ConvertFrom-Json
                        $updatedInstance = $updatedData.Reservations[0].Instances[0]

                        if ($updatedInstance.PublicIpAddress) {
                            Write-Output "Public IP Address: $($updatedInstance.PublicIpAddress)"
                        }
                    }
                }
            } else {
                throw "Failed to associate Elastic IP: $result"
            }
        }

        'Disassociate' {
            if (-not $AssociationId -and -not $PublicIp) {
                throw "Either AssociationId (for VPC) or PublicIp (for EC2-Classic) must be specified for disassociation."
            }

            Write-Output "Disassociating Elastic IP..."

            $disassociateArgs = @('ec2', 'disassociate-address')
            $disassociateArgs += $awsArgs

            if ($AssociationId) {
                $disassociateArgs += @('--association-id', $AssociationId)
            }

            if ($PublicIp) {
                $disassociateArgs += @('--public-ip', $PublicIp)
            }

            $result = & aws @disassociateArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Elastic IP disassociated successfully!"

                if ($AssociationId) {
                    Write-Output "Disassociated Association ID: $AssociationId"
                }

                if ($PublicIp) {
                    Write-Output "Disassociated Public IP: $PublicIp"
                }
            } else {
                throw "Failed to disassociate Elastic IP: $result"
            }
        }

        'Release' {
            if (-not $AllocationId -and -not $PublicIp) {
                throw "Either AllocationId (for VPC) or PublicIp (for EC2-Classic) must be specified for release."
            }

            # Check if the Elastic IP is currently associated
            Write-Output "Checking Elastic IP status before release..."

            if ($AllocationId) {
                $addressResult = aws ec2 describe-addresses --allocation-ids $AllocationId @awsArgs --output json 2>&1
            } else {
                $addressResult = aws ec2 describe-addresses --public-ips $PublicIp @awsArgs --output json 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                $addressData = $addressResult | ConvertFrom-Json
                $address = $addressData.Addresses[0]

                if ($address.AssociationId) {
                    Write-Warning "Elastic IP is currently associated with an instance."
                    Write-Output "Association ID: $($address.AssociationId)"
                    if ($address.InstanceId) {
                        Write-Output "Instance ID: $($address.InstanceId)"
                    }
                    Write-Output "You may need to disassociate it first."
                }
            }

            Write-Output "Releasing Elastic IP..."

            $releaseArgs = @('ec2', 'release-address')
            $releaseArgs += $awsArgs

            if ($AllocationId) {
                $releaseArgs += @('--allocation-id', $AllocationId)
            }

            if ($PublicIp) {
                $releaseArgs += @('--public-ip', $PublicIp)
            }

            $result = & aws @releaseArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Elastic IP released successfully!"

                if ($AllocationId) {
                    Write-Output "Released Allocation ID: $AllocationId"
                }

                if ($PublicIp) {
                    Write-Output "Released Public IP: $PublicIp"
                }
            } else {
                throw "Failed to release Elastic IP: $result"
            }
        }
    }

    Write-Output "`n✅ Elastic IP $Action operation completed successfully."

} catch {
    Write-Error "Failed to $Action Elastic IP: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
