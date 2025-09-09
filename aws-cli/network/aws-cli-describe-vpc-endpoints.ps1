[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Specific VPC endpoint IDs to describe")]
    [ValidatePattern('^vpce-[a-zA-Z0-9]+(,vpce-[a-zA-Z0-9]+)*$', ErrorMessage = "VpcEndpointIds must be comma-separated valid VPC endpoint IDs (format: vpce-xxxxxxxxx)")]
    [string]$VpcEndpointIds,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC ID")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]+$', ErrorMessage = "VpcId must be a valid VPC ID (format: vpc-xxxxxxxxx)")]
    [string]$VpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by service name")]
    [string]$ServiceName,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC endpoint type")]
    [ValidateSet('Interface', 'Gateway', 'GatewayLoadBalancer')]
    [string]$VpcEndpointType,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by VPC endpoint state")]
    [ValidateSet('PendingAcceptance', 'Pending', 'Available', 'Deleting', 'Deleted', 'Rejected', 'Failed', 'Expired')]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text', 'yaml')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory = $false, HelpMessage = "Show detailed information including DNS entries and policy documents")]
    [switch]$Detailed
)

<#
.SYNOPSIS
Describes AWS VPC endpoints.

.DESCRIPTION
This script retrieves detailed information about VPC endpoints in your AWS account. It supports filtering by various criteria and provides comprehensive endpoint details.

.PARAMETER VpcEndpointIds
Comma-separated list of specific VPC endpoint IDs to describe. Must be in the format 'vpce-xxxxxxxxx'.

.PARAMETER VpcId
Filter endpoints by VPC ID.

.PARAMETER ServiceName
Filter endpoints by AWS service name (e.g., com.amazonaws.us-east-1.s3).

.PARAMETER VpcEndpointType
Filter by endpoint type: Interface, Gateway, or GatewayLoadBalancer.

.PARAMETER State
Filter by endpoint state.

.PARAMETER Profile
The AWS CLI profile to use for the operation.

.PARAMETER Region
The AWS region to query for VPC endpoints.

.PARAMETER OutputFormat
The output format for the results (json, table, text, yaml).

.PARAMETER Detailed
Show detailed information including DNS entries and policy documents.

.EXAMPLE
.\aws-cli-describe-vpc-endpoints.ps1

Lists all VPC endpoints in the default region.

.EXAMPLE
.\aws-cli-describe-vpc-endpoints.ps1 -VpcId vpc-12345678

Lists all VPC endpoints in the specified VPC.

.EXAMPLE
.\aws-cli-describe-vpc-endpoints.ps1 -ServiceName "com.amazonaws.us-east-1.s3"

Lists all S3 gateway endpoints.

.EXAMPLE
.\aws-cli-describe-vpc-endpoints.ps1 -VpcEndpointType Interface -State Available

Lists all available interface endpoints.

.EXAMPLE
.\aws-cli-describe-vpc-endpoints.ps1 -VpcEndpointIds vpce-12345678,vpce-87654321 -Detailed

Shows detailed information for specific endpoints.

.EXAMPLE
.\aws-cli-describe-vpc-endpoints.ps1 -Profile myprofile -Region us-west-2 -OutputFormat json

Lists endpoints using a specific profile and region with JSON output.

.NOTES
Author: Your Name
Date: 2024
Requires: AWS CLI v2.16+ and appropriate IAM permissions
#>

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving VPC endpoint information..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-vpc-endpoints')
    
    if ($VpcEndpointIds) {
        $endpointArray = $VpcEndpointIds -split ','
        $awsArgs += @('--vpc-endpoint-ids')
        $awsArgs += $endpointArray
    }

    # Build filters array
    $filters = @()
    
    if ($VpcId) {
        $filters += "Name=vpc-id,Values=$VpcId"
    }
    
    if ($ServiceName) {
        $filters += "Name=service-name,Values=$ServiceName"
    }
    
    if ($VpcEndpointType) {
        $filters += "Name=vpc-endpoint-type,Values=$VpcEndpointType"
    }
    
    if ($State) {
        $filters += "Name=state,Values=$State"
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
        throw "Failed to describe VPC endpoints: $result"
    }

    $endpointInfo = $result | ConvertFrom-Json

    if ($OutputFormat -eq 'json') {
        # Output raw JSON
        $result
        return
    }

    if ($endpointInfo.VpcEndpoints.Count -eq 0) {
        Write-Host "No VPC endpoints found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    # Display summary
    Write-Host "`nVPC Endpoints Summary:" -ForegroundColor Cyan
    Write-Host "Total endpoints found: $($endpointInfo.VpcEndpoints.Count)" -ForegroundColor White

    # Group by type
    $byType = $endpointInfo.VpcEndpoints | Group-Object VpcEndpointType
    foreach ($group in $byType) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Display detailed information for each endpoint
    foreach ($endpoint in $endpointInfo.VpcEndpoints) {
        Write-Host "`n" + "="*60 -ForegroundColor Gray
        Write-Host "VPC Endpoint: $($endpoint.VpcEndpointId)" -ForegroundColor Cyan
        Write-Host "  VPC ID: $($endpoint.VpcId)" -ForegroundColor White
        Write-Host "  Service Name: $($endpoint.ServiceName)" -ForegroundColor White
        Write-Host "  Type: $($endpoint.VpcEndpointType)" -ForegroundColor White
        Write-Host "  State: $($endpoint.State)" -ForegroundColor White
        Write-Host "  Creation Time: $($endpoint.CreationTimestamp)" -ForegroundColor White
        
        if ($endpoint.PolicyDocument) {
            Write-Host "  Policy Document: Present" -ForegroundColor White
        }
        
        if ($endpoint.RouteTableIds -and $endpoint.RouteTableIds.Count -gt 0) {
            Write-Host "  Route Tables: $($endpoint.RouteTableIds -join ', ')" -ForegroundColor White
        }
        
        if ($endpoint.SubnetIds -and $endpoint.SubnetIds.Count -gt 0) {
            Write-Host "  Subnets: $($endpoint.SubnetIds -join ', ')" -ForegroundColor White
        }
        
        if ($endpoint.Groups -and $endpoint.Groups.Count -gt 0) {
            Write-Host "  Security Groups:" -ForegroundColor White
            foreach ($group in $endpoint.Groups) {
                Write-Host "    - $($group.GroupId) ($($group.GroupName))" -ForegroundColor Gray
            }
        }
        
        if ($endpoint.NetworkInterfaceIds -and $endpoint.NetworkInterfaceIds.Count -gt 0) {
            Write-Host "  Network Interfaces: $($endpoint.NetworkInterfaceIds -join ', ')" -ForegroundColor White
        }
        
        if ($null -ne $endpoint.PrivateDnsEnabled) {
            Write-Host "  Private DNS Enabled: $($endpoint.PrivateDnsEnabled)" -ForegroundColor White
        }

        # Show detailed information if requested
        if ($Detailed) {
            if ($endpoint.DnsEntries -and $endpoint.DnsEntries.Count -gt 0) {
                Write-Host "  DNS Entries:" -ForegroundColor White
                foreach ($dns in $endpoint.DnsEntries) {
                    Write-Host "    - $($dns.DnsName) (Hosted Zone: $($dns.HostedZoneId))" -ForegroundColor Gray
                }
            }
            
            if ($endpoint.PolicyDocument) {
                Write-Host "  Policy Document:" -ForegroundColor White
                $policy = $endpoint.PolicyDocument | ConvertFrom-Json | ConvertTo-Json -Depth 10
                Write-Host $policy -ForegroundColor Gray
            }
            
            if ($endpoint.Tags -and $endpoint.Tags.Count -gt 0) {
                Write-Host "  Tags:" -ForegroundColor White
                foreach ($tag in $endpoint.Tags) {
                    Write-Host "    - $($tag.Key): $($tag.Value)" -ForegroundColor Gray
                }
            }
        }
    }

    Write-Host "`n" + "="*60 -ForegroundColor Gray
    Write-Host "`nTip: Use -Detailed switch for more comprehensive information including DNS entries and policies." -ForegroundColor Cyan

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
