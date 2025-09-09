[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The allocation ID of the Elastic IP to release")]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]+$', ErrorMessage = "AllocationId must be a valid Elastic IP allocation ID (format: eipalloc-xxxxxxxxx)")]
    [string]$AllocationId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt")]
    [switch]$Force
)

<#
.SYNOPSIS
Releases an AWS Elastic IP address.

.DESCRIPTION
This script releases an Elastic IP address and returns it to the pool of available addresses. Once released, the IP address may be allocated to another AWS customer.

.PARAMETER AllocationId
The allocation ID of the Elastic IP address to release. Must be in the format 'eipalloc-xxxxxxxxx'.

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region where the Elastic IP is allocated.

.PARAMETER Force
Skip the confirmation prompt and release the Elastic IP immediately.

.EXAMPLE
.\aws-cli-release-elastic-ip.ps1 -AllocationId eipalloc-12345678

Releases the specified Elastic IP with confirmation prompt.

.EXAMPLE
.\aws-cli-release-elastic-ip.ps1 -AllocationId eipalloc-12345678 -Force

Releases the Elastic IP without confirmation prompt.

.EXAMPLE
.\aws-cli-release-elastic-ip.ps1 -AllocationId eipalloc-12345678 -Profile myprofile -Region us-west-2

Releases the Elastic IP using a specific AWS profile and region.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions

IMPORTANT NOTES:
- Releasing an Elastic IP that is associated with a running instance will cause connectivity issues
- The IP address will be returned to AWS and may be allocated to another customer
- This action cannot be undone
- You will no longer be charged for the Elastic IP after release
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting Elastic IP release process..." -ForegroundColor Green

    # Build AWS CLI arguments for describing the Elastic IP
    $describeArgs = @('ec2', 'describe-addresses', '--allocation-ids', $AllocationId)
    
    if ($Profile) {
        $describeArgs += @('--profile', $Profile)
    }
    
    if ($Region) {
        $describeArgs += @('--region', $Region)
    }

    # First, get Elastic IP details for confirmation
    Write-Host "Retrieving Elastic IP details..." -ForegroundColor Yellow
    $addressDetails = & aws @describeArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve Elastic IP details: $addressDetails"
    }

    $addressInfo = $addressDetails | ConvertFrom-Json
    
    if ($addressInfo.Addresses.Count -eq 0) {
        throw "Elastic IP with allocation ID '$AllocationId' not found"
    }

    $address = $addressInfo.Addresses[0]
    
    # Display Elastic IP information
    Write-Host "`nElastic IP Details:" -ForegroundColor Cyan
    Write-Host "  Allocation ID: $($address.AllocationId)" -ForegroundColor White
    Write-Host "  Public IP: $($address.PublicIp)" -ForegroundColor White
    Write-Host "  Domain: $($address.Domain)" -ForegroundColor White
    
    if ($address.AssociationId) {
        Write-Host "  Association ID: $($address.AssociationId)" -ForegroundColor White
        Write-Host "  Associated Instance: $($address.InstanceId)" -ForegroundColor White
        Write-Host "  Private IP: $($address.PrivateIpAddress)" -ForegroundColor White
        
        if ($address.NetworkInterfaceId) {
            Write-Host "  Network Interface: $($address.NetworkInterfaceId)" -ForegroundColor White
        }
        
        Write-Host "  STATUS: ASSOCIATED - This IP is currently in use!" -ForegroundColor Red
    } else {
        Write-Host "  STATUS: Not associated with any resource" -ForegroundColor Green
    }
    
    if ($address.NetworkBorderGroup) {
        Write-Host "  Network Border Group: $($address.NetworkBorderGroup)" -ForegroundColor White
    }
    
    if ($address.CustomerOwnedIp) {
        Write-Host "  Customer Owned IP: $($address.CustomerOwnedIp)" -ForegroundColor White
    }

    # Display tags if present
    if ($address.Tags -and $address.Tags.Count -gt 0) {
        Write-Host "`n  Tags:" -ForegroundColor White
        foreach ($tag in $address.Tags) {
            Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
        }
    }

    # Warning about associations
    if ($address.AssociationId) {
        Write-Host "`nWARNING: This Elastic IP is currently associated with resources!" -ForegroundColor Red
        Write-Host "Releasing it will cause the following impacts:" -ForegroundColor Yellow
        Write-Host "- The associated instance/interface will lose its public IP" -ForegroundColor Yellow
        Write-Host "- Incoming connections to this IP will fail" -ForegroundColor Yellow
        Write-Host "- Applications may experience connectivity issues" -ForegroundColor Yellow
        Write-Host "`nConsider disassociating the IP first before releasing it." -ForegroundColor Yellow
    }

    # Cost information
    Write-Host "`nCost Information:" -ForegroundColor Cyan
    if ($address.AssociationId) {
        Write-Host "- Currently not charged (associated with running instance)" -ForegroundColor Green
    } else {
        Write-Host "- Currently being charged for unassociated Elastic IP" -ForegroundColor Yellow
    }
    Write-Host "- Releasing will stop all charges for this Elastic IP" -ForegroundColor Green

    # Confirmation prompt unless Force is specified
    if (-not $Force) {
        Write-Host "`nWARNING: This action will permanently release the Elastic IP!" -ForegroundColor Red
        Write-Host "The IP address $($address.PublicIp) will be returned to AWS and may be allocated to another customer." -ForegroundColor Red
        $confirmation = Read-Host "Are you sure you want to release Elastic IP '$AllocationId'? (yes/no)"
        
        if ($confirmation -ne 'yes') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Release the Elastic IP
    Write-Host "`nReleasing Elastic IP..." -ForegroundColor Yellow
    
    $releaseArgs = @('ec2', 'release-address', '--allocation-id', $AllocationId)
    
    if ($Profile) {
        $releaseArgs += @('--profile', $Profile)
    }
    
    if ($Region) {
        $releaseArgs += @('--region', $Region)
    }

    $releaseResult = & aws @releaseArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to release Elastic IP: $releaseResult"
    }

    Write-Host "`nElastic IP released successfully!" -ForegroundColor Green
    Write-Host "  Released IP: $($address.PublicIp)" -ForegroundColor White
    Write-Host "  Allocation ID: $AllocationId" -ForegroundColor White

    # Display post-release information
    Write-Host "`nPost-Release Information:" -ForegroundColor Cyan
    Write-Host "- The IP address is no longer allocated to your account" -ForegroundColor White
    Write-Host "- Billing for this Elastic IP has stopped" -ForegroundColor White
    Write-Host "- The IP may be allocated to another AWS customer" -ForegroundColor White
    
    if ($address.AssociationId) {
        Write-Host "- The previously associated resource no longer has a public IP" -ForegroundColor Yellow
        Write-Host "- Update any DNS records pointing to $($address.PublicIp)" -ForegroundColor Yellow
        Write-Host "- Update security group rules referencing this IP" -ForegroundColor Yellow
    }

    Write-Host "`nRecommended Actions:" -ForegroundColor Cyan
    Write-Host "1. Update DNS records if they pointed to $($address.PublicIp)" -ForegroundColor White
    Write-Host "2. Review security group rules that may reference this IP" -ForegroundColor White
    Write-Host "3. Update application configurations that used this IP" -ForegroundColor White
    
    if ($address.AssociationId) {
        Write-Host "4. Consider allocating a new Elastic IP if public connectivity is still needed" -ForegroundColor White
    }

    Write-Host "`nNOTE: This action cannot be undone. The IP address $($address.PublicIp) is no longer available to your account." -ForegroundColor Cyan

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
