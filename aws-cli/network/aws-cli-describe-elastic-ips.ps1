<#
.SYNOPSIS
    Describes AWS Elastic IP addresses.

.DESCRIPTION
    This script retrieves detailed information about Elastic IP addresses in your AWS account.
    It supports filtering by allocation IDs, public IPs, instance ID, association status, and domain.
    Uses aws ec2 describe-addresses to perform the operation.

.PARAMETER AllocationIds
    Comma-separated list of specific Elastic IP allocation IDs to describe. Must be in the format 'eipalloc-xxxxxxxxx'.

.PARAMETER PublicIps
    Comma-separated list of specific public IP addresses to describe.

.PARAMETER InstanceId
    Filter Elastic IPs by the instance they are associated with.

.PARAMETER AssociationStatus
    Filter by association status: associated or unassociated.

.PARAMETER Domain
    Filter by domain: vpc or standard.

.PARAMETER Profile
    The AWS CLI profile to use for the operation.

.PARAMETER Region
    The AWS region to query for Elastic IP addresses.

.PARAMETER OutputFormat
    The output format for the results (json, table, text, yaml).

.PARAMETER ShowCostAnalysis
    Show cost analysis for unassociated Elastic IPs.

.EXAMPLE
    .\aws-cli-describe-elastic-ips.ps1

.EXAMPLE
    .\aws-cli-describe-elastic-ips.ps1 -AssociationStatus unassociated -ShowCostAnalysis

.EXAMPLE
    .\aws-cli-describe-elastic-ips.ps1 -InstanceId i-12345678

.EXAMPLE
    .\aws-cli-describe-elastic-ips.ps1 -Domain vpc -Profile myprofile -Region us-west-2

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-addresses.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Specific allocation IDs to describe")]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]+(,eipalloc-[a-zA-Z0-9]+)*$')]
    [string]$AllocationIds,

    [Parameter(Mandatory = $false, HelpMessage = "Specific public IP addresses to describe")]
    [string]$PublicIps,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by instance ID")]
    [ValidatePattern('^i-[a-zA-Z0-9]+$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by association status")]
    [ValidateSet('associated', 'unassociated')]
    [string]$AssociationStatus,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by domain")]
    [ValidateSet('vpc', 'standard')]
    [string]$Domain,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text', 'yaml')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory = $false, HelpMessage = "Show cost analysis for unassociated Elastic IPs")]
    [switch]$ShowCostAnalysis
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving Elastic IP address information..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-addresses')

    if ($AllocationIds) {
        $allocationArray = $AllocationIds -split ','
        $awsArgs += @('--allocation-ids')
        $awsArgs += $allocationArray
    }

    if ($PublicIps) {
        $ipArray = $PublicIps -split ','
        $awsArgs += @('--public-ips')
        $awsArgs += $ipArray
    }

    # Build filters array
    $filters = @()

    if ($InstanceId) {
        $filters += "Name=instance-id,Values=$InstanceId"
    }

    if ($AssociationStatus) {
        if ($AssociationStatus -eq 'associated') {
            $filters += "Name=association-id,Values=*"
        } else {
            # For unassociated, we'll filter after getting results
        }
    }

    if ($Domain) {
        $filters += "Name=domain,Values=$Domain"
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
        throw "Failed to describe Elastic IP addresses: $result"
    }

    $addressInfo = $result | ConvertFrom-Json

    if ($OutputFormat -eq 'json') {
        # Output raw JSON
        $result
        return
    }

    # Filter unassociated if specified (since AWS CLI doesn't have a direct filter for this)
    if ($AssociationStatus -eq 'unassociated') {
        $addressInfo.Addresses = $addressInfo.Addresses | Where-Object { -not $_.AssociationId }
    }

    if ($addressInfo.Addresses.Count -eq 0) {
        Write-Host "No Elastic IP addresses found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    # Display summary
    Write-Host "`nElastic IP Addresses Summary:" -ForegroundColor Cyan
    Write-Host "Total addresses found: $($addressInfo.Addresses.Count)" -ForegroundColor White

    # Categorize addresses
    $associated = $addressInfo.Addresses | Where-Object { $_.AssociationId }
    $unassociated = $addressInfo.Addresses | Where-Object { -not $_.AssociationId }
    $vpcAddresses = $addressInfo.Addresses | Where-Object { $_.Domain -eq 'vpc' }
    $standardAddresses = $addressInfo.Addresses | Where-Object { $_.Domain -eq 'standard' }

    Write-Host "  Associated: $($associated.Count)" -ForegroundColor Green
    Write-Host "  Unassociated (incurring charges): $($unassociated.Count)" -ForegroundColor Yellow
    Write-Host "  VPC domain: $($vpcAddresses.Count)" -ForegroundColor White
    Write-Host "  Standard domain: $($standardAddresses.Count)" -ForegroundColor White

    # Cost analysis warning
    if ($unassociated.Count -gt 0) {
        $monthlyCost = $unassociated.Count * 3.65  # Approximate monthly cost per unassociated EIP
        Write-Host "`nCOST ALERT: $($unassociated.Count) unassociated Elastic IPs are incurring charges!" -ForegroundColor Red
        Write-Host "Estimated monthly cost: ~`$$([math]::Round($monthlyCost, 2))" -ForegroundColor Red
    }

    # Display detailed information for each address
    foreach ($address in $addressInfo.Addresses) {
        Write-Host "`n" + "="*60 -ForegroundColor Gray
        Write-Host "Elastic IP: $($address.PublicIp)" -ForegroundColor Cyan
        Write-Host "  Allocation ID: $($address.AllocationId)" -ForegroundColor White
        Write-Host "  Domain: $($address.Domain)" -ForegroundColor White

        # Association status
        if ($address.AssociationId) {
            Write-Host "  Status: Associated" -ForegroundColor Green
            Write-Host "  Association ID: $($address.AssociationId)" -ForegroundColor White

            if ($address.InstanceId) {
                Write-Host "  Instance ID: $($address.InstanceId)" -ForegroundColor White
                Write-Host "  Private IP: $($address.PrivateIpAddress)" -ForegroundColor White
            }

            if ($address.NetworkInterfaceId) {
                Write-Host "  Network Interface: $($address.NetworkInterfaceId)" -ForegroundColor White
                Write-Host "  Network Interface Owner: $($address.NetworkInterfaceOwnerId)" -ForegroundColor White
            }

            Write-Host "  Cost Status: No charges (associated)" -ForegroundColor Green
        } else {
            Write-Host "  Status: Unassociated" -ForegroundColor Yellow
            Write-Host "  Cost Status: Incurring charges (~`$0.12/day)" -ForegroundColor Red
        }

        # Additional information
        if ($address.NetworkBorderGroup) {
            Write-Host "  Network Border Group: $($address.NetworkBorderGroup)" -ForegroundColor White
        }

        if ($address.CustomerOwnedIp) {
            Write-Host "  Customer Owned IP: Yes" -ForegroundColor White
            Write-Host "  Customer Owned IPv4 Pool: $($address.CustomerOwnedIpv4Pool)" -ForegroundColor White
        }

        if ($address.CarrierIp) {
            Write-Host "  Carrier IP: $($address.CarrierIp)" -ForegroundColor White
        }

        # Display tags if present
        if ($address.Tags -and $address.Tags.Count -gt 0) {
            Write-Host "  Tags:" -ForegroundColor White
            foreach ($tag in $address.Tags) {
                Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n" + "="*60 -ForegroundColor Gray

    # Show cost analysis if requested or if there are unassociated IPs
    if ($ShowCostAnalysis -or $unassociated.Count -gt 0) {
        Write-Host "`nCost Optimization Analysis:" -ForegroundColor Cyan

        if ($unassociated.Count -gt 0) {
            Write-Host "`nUnassociated Elastic IPs (incurring charges):" -ForegroundColor Red
            foreach ($unassoc in $unassociated) {
                Write-Host "  $($unassoc.PublicIp) ($($unassoc.AllocationId))" -ForegroundColor Yellow
                Write-Host "    Daily cost: ~`$0.12" -ForegroundColor Red
                Write-Host "    Monthly cost: ~`$3.65" -ForegroundColor Red
                Write-Host "    Release command: aws ec2 release-address --allocation-id $($unassoc.AllocationId)" -ForegroundColor Gray
            }

            $totalMonthlyCost = $unassociated.Count * 3.65
            Write-Host "`n  Total estimated monthly cost: ~`$$([math]::Round($totalMonthlyCost, 2))" -ForegroundColor Red
        }

        if ($associated.Count -gt 0) {
            Write-Host "`nAssociated Elastic IPs (no additional charges):" -ForegroundColor Green
            foreach ($assoc in $associated) {
                Write-Host "  $($assoc.PublicIp) -> $($assoc.InstanceId)" -ForegroundColor Green
            }
        }
    }

    # Display management commands
    Write-Host "`nManagement Commands:" -ForegroundColor Cyan
    Write-Host "Associate to instance: aws ec2 associate-address --allocation-id <alloc-id> --instance-id <instance-id>" -ForegroundColor Gray
    Write-Host "Disassociate: aws ec2 disassociate-address --association-id <assoc-id>" -ForegroundColor Gray
    Write-Host "Release (delete): aws ec2 release-address --allocation-id <alloc-id>" -ForegroundColor Gray

    if ($unassociated.Count -gt 0) {
        Write-Host "`nRecommendation: Consider releasing unassociated Elastic IPs to reduce costs," -ForegroundColor Cyan
        Write-Host "or associate them with instances that need static public IP addresses." -ForegroundColor Cyan
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
