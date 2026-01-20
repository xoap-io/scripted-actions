[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The VPC endpoint ID to delete")]
    [ValidatePattern('^vpce-[a-zA-Z0-9]+$', ErrorMessage = "VpcEndpointId must be a valid VPC endpoint ID (format: vpce-xxxxxxxxx)")]
    [string]$VpcEndpointId,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt")]
    [switch]$Force
)

<#
.SYNOPSIS
Deletes an AWS VPC endpoint.

.DESCRIPTION
This script deletes a VPC endpoint in AWS. It provides options to view endpoint details before deletion and includes safety confirmation prompts.

.PARAMETER VpcEndpointId
The ID of the VPC endpoint to delete. Must be in the format 'vpce-xxxxxxxxx'.

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region where the VPC endpoint is located.

.PARAMETER Force
Skip the confirmation prompt and delete the VPC endpoint immediately.

.EXAMPLE
.\aws-cli-delete-vpc-endpoint.ps1 -VpcEndpointId vpce-12345678

Deletes the specified VPC endpoint with confirmation prompt.

.EXAMPLE
.\aws-cli-delete-vpc-endpoint.ps1 -VpcEndpointId vpce-12345678 -Force

Deletes the specified VPC endpoint without confirmation prompt.

.EXAMPLE
.\aws-cli-delete-vpc-endpoint.ps1 -VpcEndpointId vpce-12345678 -Profile myprofile -Region us-west-2

Deletes the VPC endpoint using a specific AWS profile and region.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting VPC endpoint deletion process..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-vpc-endpoints', '--vpc-endpoint-ids', $VpcEndpointId)

    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # First, get endpoint details for confirmation
    Write-Host "Retrieving VPC endpoint details..." -ForegroundColor Yellow
    $endpointDetails = & aws @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve VPC endpoint details: $endpointDetails"
    }

    $endpointInfo = $endpointDetails | ConvertFrom-Json

    if ($endpointInfo.VpcEndpoints.Count -eq 0) {
        throw "VPC endpoint '$VpcEndpointId' not found"
    }

    $endpoint = $endpointInfo.VpcEndpoints[0]

    # Display endpoint information
    Write-Host "`nVPC Endpoint Details:" -ForegroundColor Cyan
    Write-Host "  Endpoint ID: $($endpoint.VpcEndpointId)" -ForegroundColor White
    Write-Host "  VPC ID: $($endpoint.VpcId)" -ForegroundColor White
    Write-Host "  Service Name: $($endpoint.ServiceName)" -ForegroundColor White
    Write-Host "  Type: $($endpoint.VpcEndpointType)" -ForegroundColor White
    Write-Host "  State: $($endpoint.State)" -ForegroundColor White
    Write-Host "  Creation Time: $($endpoint.CreationTimestamp)" -ForegroundColor White

    if ($endpoint.RouteTableIds) {
        Write-Host "  Route Tables: $($endpoint.RouteTableIds -join ', ')" -ForegroundColor White
    }

    if ($endpoint.SubnetIds) {
        Write-Host "  Subnets: $($endpoint.SubnetIds -join ', ')" -ForegroundColor White
    }

    if ($endpoint.NetworkInterfaceIds) {
        Write-Host "  Network Interfaces: $($endpoint.NetworkInterfaceIds -join ', ')" -ForegroundColor White
    }

    # Confirmation prompt unless Force is specified
    if (-not $Force) {
        Write-Host "`nWARNING: This action will permanently delete the VPC endpoint!" -ForegroundColor Red
        $confirmation = Read-Host "Are you sure you want to delete VPC endpoint '$VpcEndpointId'? (yes/no)"

        if ($confirmation -ne 'yes') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Delete the VPC endpoint
    Write-Host "`nDeleting VPC endpoint..." -ForegroundColor Yellow

    $deleteArgs = @('ec2', 'delete-vpc-endpoints', '--vpc-endpoint-ids', $VpcEndpointId)

    if ($Profile) {
        $deleteArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $deleteArgs += @('--region', $Region)
    }

    $deleteResult = & aws @deleteArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to delete VPC endpoint: $deleteResult"
    }

    $deleteInfo = $deleteResult | ConvertFrom-Json

    Write-Host "`nVPC endpoint deletion initiated successfully!" -ForegroundColor Green

    if ($deleteInfo.Unsuccessful -and $deleteInfo.Unsuccessful.Count -gt 0) {
        Write-Host "`nFailed deletions:" -ForegroundColor Red
        foreach ($failed in $deleteInfo.Unsuccessful) {
            Write-Host "  Endpoint ID: $($failed.ResourceId)" -ForegroundColor Red
            Write-Host "  Error: $($failed.Error.Message)" -ForegroundColor Red
        }
    }

    if ($deleteInfo.Successful -and $deleteInfo.Successful.Count -gt 0) {
        Write-Host "`nSuccessful deletions:" -ForegroundColor Green
        foreach ($success in $deleteInfo.Successful) {
            Write-Host "  Endpoint ID: $($success)" -ForegroundColor Green
        }
    }

    Write-Host "`nNOTE: VPC endpoint deletion may take a few minutes to complete." -ForegroundColor Cyan
    Write-Host "Use 'aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $VpcEndpointId' to check the deletion status." -ForegroundColor Cyan

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
