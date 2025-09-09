[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Specific Network Interface IDs to describe")]
    [ValidatePattern('^eni-[a-zA-Z0-9]+(,eni-[a-zA-Z0-9]+)*$', ErrorMessage = "NetworkInterfaceIds must be comma-separated valid ENI IDs (format: eni-xxxxxxxxx)")]
    [string]$NetworkInterfaceIds,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC ID")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$', ErrorMessage = "VpcId must be a valid VPC ID (format: vpc-xxxxxxxxx)")]
    [string]$VpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by subnet ID")]
    [ValidatePattern('^subnet-[a-zA-Z0-9]+$', ErrorMessage = "SubnetId must be a valid subnet ID (format: subnet-xxxxxxxxx)")]
    [string]$SubnetId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by instance ID")]
    [ValidatePattern('^i-[a-zA-Z0-9]+$', ErrorMessage = "InstanceId must be a valid EC2 instance ID (format: i-xxxxxxxxx)")]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by interface status")]
    [ValidateSet('available', 'associated', 'attaching', 'in-use', 'detaching')]
    [string]$Status,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by interface type")]
    [ValidateSet('interface', 'natGateway', 'efa', 'trunk')]
    [string]$InterfaceType,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text', 'yaml')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory = $false, HelpMessage = "Show detailed security group and IP information")]
    [switch]$Detailed
)

<#
.SYNOPSIS
Describes AWS Elastic Network Interfaces (ENIs).

.DESCRIPTION
This script retrieves detailed information about Elastic Network Interfaces in your AWS account. ENIs are virtual network interfaces that can be attached to EC2 instances.

.PARAMETER NetworkInterfaceIds
Comma-separated list of specific network interface IDs to describe. Must be in the format 'eni-xxxxxxxxx'.

.PARAMETER VpcId
Filter network interfaces by VPC ID.

.PARAMETER SubnetId
Filter network interfaces by subnet ID.

.PARAMETER InstanceId
Filter network interfaces by the instance they are attached to.

.PARAMETER Status
Filter by interface status: available, associated, attaching, in-use, or detaching.

.PARAMETER InterfaceType
Filter by interface type: interface, natGateway, efa, or trunk.

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region to query for network interfaces.

.PARAMETER OutputFormat
The output format for the results (json, table, text, yaml).

.PARAMETER Detailed
Show detailed information including security groups, IP addresses, and associations.

.EXAMPLE
.\aws-cli-describe-network-interfaces.ps1

Lists all network interfaces in the default region.

.EXAMPLE
.\aws-cli-describe-network-interfaces.ps1 -VpcId vpc-12345678

Lists all network interfaces in a specific VPC.

.EXAMPLE
.\aws-cli-describe-network-interfaces.ps1 -InstanceId i-12345678

Lists network interfaces attached to a specific instance.

.EXAMPLE
.\aws-cli-describe-network-interfaces.ps1 -Status available

Lists available (unattached) network interfaces.

.EXAMPLE
.\aws-cli-describe-network-interfaces.ps1 -NetworkInterfaceIds eni-12345678,eni-87654321 -Detailed

Shows detailed information for specific network interfaces.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving Elastic Network Interface information..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-network-interfaces')
    
    if ($NetworkInterfaceIds) {
        $eniArray = $NetworkInterfaceIds -split ','
        $awsArgs += @('--network-interface-ids')
        $awsArgs += $eniArray
    }

    # Build filters array
    $filters = @()
    
    if ($VpcId) {
        $filters += "Name=vpc-id,Values=$VpcId"
    }
    
    if ($SubnetId) {
        $filters += "Name=subnet-id,Values=$SubnetId"
    }
    
    if ($InstanceId) {
        $filters += "Name=attachment.instance-id,Values=$InstanceId"
    }
    
    if ($Status) {
        $filters += "Name=status,Values=$Status"
    }
    
    if ($InterfaceType) {
        $filters += "Name=interface-type,Values=$InterfaceType"
    }

    if ($filters.Count -gt 0) {
        $awsArgs += @('--filters')
        $awsArgs += $filters
    }
    
    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }
    
    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Execute the AWS CLI command
    $result = & aws @awsArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe network interfaces: $result"
    }

    $eniInfo = $result | ConvertFrom-Json

    if ($OutputFormat -eq 'json') {
        # Output raw JSON
        $result
        return
    }

    if ($eniInfo.NetworkInterfaces.Count -eq 0) {
        Write-Host "No network interfaces found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    # Display summary
    Write-Host "`nElastic Network Interfaces Summary:" -ForegroundColor Cyan
    Write-Host "Total interfaces found: $($eniInfo.NetworkInterfaces.Count)" -ForegroundColor White

    # Categorize interfaces
    $byStatus = $eniInfo.NetworkInterfaces | Group-Object Status
    foreach ($group in $byStatus) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Group by type
    $byType = $eniInfo.NetworkInterfaces | Group-Object InterfaceType
    Write-Host "`nBy Interface Type:" -ForegroundColor Cyan
    foreach ($group in $byType) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Display detailed information for each interface
    foreach ($eni in $eniInfo.NetworkInterfaces) {
        Write-Host "`n" + "="*70 -ForegroundColor Gray
        Write-Host "Network Interface: $($eni.NetworkInterfaceId)" -ForegroundColor Cyan
        
        # Basic information
        Write-Host "  Description: $($eni.Description)" -ForegroundColor White
        Write-Host "  Status: $($eni.Status)" -ForegroundColor White
        Write-Host "  Type: $($eni.InterfaceType)" -ForegroundColor White
        Write-Host "  MAC Address: $($eni.MacAddress)" -ForegroundColor White
        
        # Network location
        Write-Host "`n  Network Location:" -ForegroundColor Yellow
        Write-Host "    VPC ID: $($eni.VpcId)" -ForegroundColor White
        Write-Host "    Subnet ID: $($eni.SubnetId)" -ForegroundColor White
        Write-Host "    Availability Zone: $($eni.AvailabilityZone)" -ForegroundColor White
        Write-Host "    Private IP: $($eni.PrivateIpAddress)" -ForegroundColor White
        
        # Public IP information
        if ($eni.Association -and $eni.Association.PublicIp) {
            Write-Host "    Public IP: $($eni.Association.PublicIp)" -ForegroundColor Green
            if ($eni.Association.AllocationId) {
                Write-Host "    Elastic IP: $($eni.Association.AllocationId)" -ForegroundColor Green
            }
        }
        
        # Attachment information
        if ($eni.Attachment) {
            Write-Host "`n  Attachment:" -ForegroundColor Yellow
            Write-Host "    Instance ID: $($eni.Attachment.InstanceId)" -ForegroundColor White
            Write-Host "    Device Index: $($eni.Attachment.DeviceIndex)" -ForegroundColor White
            Write-Host "    Attachment ID: $($eni.Attachment.AttachmentId)" -ForegroundColor White
            Write-Host "    Attach Time: $($eni.Attachment.AttachTime)" -ForegroundColor White
            Write-Host "    Delete on Termination: $($eni.Attachment.DeleteOnTermination)" -ForegroundColor White
        } else {
            Write-Host "`n  Status: Not attached to any instance" -ForegroundColor Yellow
        }
        
        # Owner information
        Write-Host "`n  Ownership:" -ForegroundColor Yellow
        Write-Host "    Owner ID: $($eni.OwnerId)" -ForegroundColor White
        if ($eni.RequesterId) {
            Write-Host "    Requester ID: $($eni.RequesterId)" -ForegroundColor White
            Write-Host "    Requester Managed: Yes" -ForegroundColor White
        }
        
        # Show detailed information if requested
        if ($Detailed) {
            # Security groups
            if ($eni.Groups -and $eni.Groups.Count -gt 0) {
                Write-Host "`n  Security Groups:" -ForegroundColor Yellow
                foreach ($sg in $eni.Groups) {
                    Write-Host "    $($sg.GroupId) - $($sg.GroupName)" -ForegroundColor White
                }
            }
            
            # Private IP addresses
            if ($eni.PrivateIpAddresses -and $eni.PrivateIpAddresses.Count -gt 1) {
                Write-Host "`n  Private IP Addresses:" -ForegroundColor Yellow
                foreach ($ip in $eni.PrivateIpAddresses) {
                    $primaryText = if ($ip.Primary) { " (Primary)" } else { "" }
                    Write-Host "    $($ip.PrivateIpAddress)$primaryText" -ForegroundColor White
                    
                    if ($ip.Association) {
                        Write-Host "      Public IP: $($ip.Association.PublicIp)" -ForegroundColor Green
                        if ($ip.Association.AllocationId) {
                            Write-Host "      Elastic IP: $($ip.Association.AllocationId)" -ForegroundColor Green
                        }
                    }
                }
            }
            
            # IPv6 addresses
            if ($eni.Ipv6Addresses -and $eni.Ipv6Addresses.Count -gt 0) {
                Write-Host "`n  IPv6 Addresses:" -ForegroundColor Yellow
                foreach ($ipv6 in $eni.Ipv6Addresses) {
                    Write-Host "    $($ipv6.Ipv6Address)" -ForegroundColor White
                }
            }
            
            # Source/Destination check
            Write-Host "`n  Configuration:" -ForegroundColor Yellow
            Write-Host "    Source/Dest Check: $($eni.SourceDestCheck)" -ForegroundColor White
            
            # Outpost information
            if ($eni.OutpostArn) {
                Write-Host "    Outpost ARN: $($eni.OutpostArn)" -ForegroundColor White
            }
        }

        # Display tags if present
        if ($eni.TagSet -and $eni.TagSet.Count -gt 0) {
            Write-Host "`n  Tags:" -ForegroundColor Yellow
            foreach ($tag in $eni.TagSet) {
                Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n" + "="*70 -ForegroundColor Gray

    # Show unattached interfaces
    $unattachedEnis = $eniInfo.NetworkInterfaces | Where-Object { -not $_.Attachment }
    if ($unattachedEnis.Count -gt 0) {
        Write-Host "`nUnattached Network Interfaces:" -ForegroundColor Yellow
        foreach ($unattached in $unattachedEnis) {
            Write-Host "  $($unattached.NetworkInterfaceId) - $($unattached.Description)" -ForegroundColor Gray
            Write-Host "    Consider attaching to an instance or deleting if no longer needed" -ForegroundColor Gray
        }
    }

    # Show management commands
    Write-Host "`nManagement Commands:" -ForegroundColor Cyan
    Write-Host "Create ENI: aws ec2 create-network-interface --subnet-id <subnet-id> --groups <sg-id>" -ForegroundColor Gray
    Write-Host "Attach ENI: aws ec2 attach-network-interface --network-interface-id <eni-id> --instance-id <instance-id> --device-index <index>" -ForegroundColor Gray
    Write-Host "Detach ENI: aws ec2 detach-network-interface --attachment-id <attachment-id>" -ForegroundColor Gray
    Write-Host "Delete ENI: aws ec2 delete-network-interface --network-interface-id <eni-id>" -ForegroundColor Gray

    if (-not $Detailed) {
        Write-Host "`nTip: Use -Detailed switch for comprehensive security group and IP address information." -ForegroundColor Cyan
    }

    # Usage recommendations
    Write-Host "`nUse Cases:" -ForegroundColor Cyan
    Write-Host "- High availability: Attach ENI to standby instance for quick failover" -ForegroundColor White
    Write-Host "- Multi-homed instances: Multiple ENIs for different network segments" -ForegroundColor White
    Write-Host "- License management: Move ENI with specific MAC address between instances" -ForegroundColor White
    Write-Host "- Network appliances: Dedicated ENIs for specific network functions" -ForegroundColor White

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
