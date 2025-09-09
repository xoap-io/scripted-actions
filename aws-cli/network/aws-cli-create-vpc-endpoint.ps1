<#
.SYNOPSIS
    Creates VPC Endpoints in AWS using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script creates VPC endpoints for AWS services with comprehensive configuration options
    including interface and gateway endpoints, custom policies, and subnet/route table assignments.

.PARAMETER VpcId
    The ID of the VPC where the endpoint will be created.

.PARAMETER ServiceName
    The name of the AWS service for the endpoint (e.g., com.amazonaws.us-east-1.s3).

.PARAMETER VpcEndpointType
    The type of VPC endpoint (Gateway, Interface, GatewayLoadBalancer).

.PARAMETER SubnetId
    The IDs of subnets for interface endpoints. Can be a single ID or array of IDs.

.PARAMETER RouteTableId
    The IDs of route tables for gateway endpoints. Can be a single ID or array of IDs.

.PARAMETER SecurityGroupId
    The IDs of security groups for interface endpoints. Can be a single ID or array of IDs.

.PARAMETER PolicyDocument
    Custom policy document for the endpoint (JSON string or file path).

.PARAMETER PrivateDnsEnabled
    Enable private DNS for interface endpoints (default: true).

.PARAMETER DnsRecordIpType
    The IP address type for DNS records (ipv4, dualstack, ipv6).

.PARAMETER DnsOptions
    DNS options for the endpoint (JSON string).

.PARAMETER TagSpecifications
    Tags to apply to the endpoint (JSON string).

.PARAMETER ClientToken
    Unique client token for idempotency.

.PARAMETER DryRun
    Perform a dry run to validate parameters without creating the endpoint.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-create-vpc-endpoint.ps1 -VpcId "vpc-12345678" -ServiceName "com.amazonaws.us-east-1.s3" -VpcEndpointType "Gateway"

.EXAMPLE
    .\aws-cli-create-vpc-endpoint.ps1 -VpcId "vpc-12345678" -ServiceName "com.amazonaws.us-east-1.ec2" -VpcEndpointType "Interface" -SubnetId "subnet-12345678","subnet-87654321"

.EXAMPLE
    .\aws-cli-create-vpc-endpoint.ps1 -VpcId "vpc-12345678" -ServiceName "com.amazonaws.us-east-1.s3" -VpcEndpointType "Gateway" -RouteTableId "rtb-12345678" -PolicyDocument "s3-policy.json"

.NOTES
    Author: XOAP
    Date: 2025-08-06
    Version: 1.0
    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^com\.amazonaws\.[a-z0-9\-]+\.[a-zA-Z0-9\-\.]+$')]
    [string]$ServiceName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Gateway", "Interface", "GatewayLoadBalancer")]
    [string]$VpcEndpointType,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string[]]$SubnetId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^rtb-[a-zA-Z0-9]{8,}$')]
    [string[]]$RouteTableId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string[]]$SecurityGroupId,

    [Parameter(Mandatory = $false)]
    [string]$PolicyDocument,

    [Parameter(Mandatory = $false)]
    [bool]$PrivateDnsEnabled = $true,

    [Parameter(Mandatory = $false)]
    [ValidateSet("ipv4", "dualstack", "ipv6")]
    [string]$DnsRecordIpType,

    [Parameter(Mandatory = $false)]
    [string]$DnsOptions,

    [Parameter(Mandatory = $false)]
    [string]$TagSpecifications,

    [Parameter(Mandatory = $false)]
    [string]$ClientToken,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

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
    if ($DryRun) { $awsArgs += @('--dry-run') }

    Write-Output "🔗 Creating VPC Endpoint..."
    Write-Output "  VPC: $VpcId"
    Write-Output "  Service: $ServiceName"
    Write-Output "  Type: $VpcEndpointType"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Validate VPC exists
    Write-Output "`n🔍 Verifying VPC..."
    $vpcResult = aws ec2 describe-vpcs --vpc-ids $VpcId @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "VPC $VpcId not found or not accessible: $vpcResult"
    }

    $vpcData = $vpcResult | ConvertFrom-Json
    $vpc = $vpcData.Vpcs[0]
    
    Write-Output "✅ VPC verified:"
    Write-Output "  VPC ID: $($vpc.VpcId)"
    Write-Output "  State: $($vpc.State)"
    Write-Output "  CIDR Block: $($vpc.CidrBlock)"

    # Validate service availability
    Write-Output "`n🔍 Checking service availability..."
    $serviceResult = aws ec2 describe-vpc-endpoint-services @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $serviceData = $serviceResult | ConvertFrom-Json
        $availableService = $serviceData.ServiceNames | Where-Object { $_ -eq $ServiceName }
        
        if ($availableService) {
            Write-Output "✅ Service $ServiceName is available in this region"
            
            # Get service details
            $serviceDetails = $serviceData.ServiceDetails | Where-Object { $_.ServiceName -eq $ServiceName }
            if ($serviceDetails) {
                Write-Output "  Service Type: $($serviceDetails.ServiceType -join ', ')"
                Write-Output "  Owner: $($serviceDetails.Owner)"
                if ($serviceDetails.AcceptanceRequired) {
                    Write-Output "  Acceptance Required: Yes"
                } else {
                    Write-Output "  Acceptance Required: No"
                }
            }
        } else {
            Write-Warning "⚠️  Service $ServiceName not found in available services list"
            Write-Output "   Proceeding anyway - service might be available but not listed"
        }
    }

    # Validate endpoint type requirements
    if ($VpcEndpointType -eq "Interface") {
        if (-not $SubnetId -or $SubnetId.Count -eq 0) {
            Write-Error "Interface endpoints require at least one subnet ID"
        }
        
        Write-Output "`n🔍 Validating subnets for interface endpoint..."
        foreach ($subnet in $SubnetId) {
            $subnetResult = aws ec2 describe-subnets --subnet-ids $subnet @awsArgs --output json 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Subnet $subnet not found or not accessible: $subnetResult"
            }
            
            $subnetData = $subnetResult | ConvertFrom-Json
            $subnetInfo = $subnetData.Subnets[0]
            
            if ($subnetInfo.VpcId -ne $VpcId) {
                Write-Error "Subnet $subnet is not in VPC $VpcId (found in $($subnetInfo.VpcId))"
            }
            
            Write-Output "  ✅ Subnet $subnet validated (AZ: $($subnetInfo.AvailabilityZone))"
        }
        
        # Validate security groups if provided
        if ($SecurityGroupId -and $SecurityGroupId.Count -gt 0) {
            Write-Output "`n🔍 Validating security groups..."
            foreach ($sg in $SecurityGroupId) {
                $sgResult = aws ec2 describe-security-groups --group-ids $sg @awsArgs --output json 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Security group $sg not found or not accessible: $sgResult"
                }
                
                $sgData = $sgResult | ConvertFrom-Json
                $sgInfo = $sgData.SecurityGroups[0]
                
                if ($sgInfo.VpcId -ne $VpcId) {
                    Write-Error "Security group $sg is not in VPC $VpcId (found in $($sgInfo.VpcId))"
                }
                
                Write-Output "  ✅ Security group $sg validated"
            }
        }
    }

    if ($VpcEndpointType -eq "Gateway") {
        if ($RouteTableId -and $RouteTableId.Count -gt 0) {
            Write-Output "`n🔍 Validating route tables for gateway endpoint..."
            foreach ($rtb in $RouteTableId) {
                $rtbResult = aws ec2 describe-route-tables --route-table-ids $rtb @awsArgs --output json 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Route table $rtb not found or not accessible: $rtbResult"
                }
                
                $rtbData = $rtbResult | ConvertFrom-Json
                $rtbInfo = $rtbData.RouteTables[0]
                
                if ($rtbInfo.VpcId -ne $VpcId) {
                    Write-Error "Route table $rtb is not in VPC $VpcId (found in $($rtbInfo.VpcId))"
                }
                
                Write-Output "  ✅ Route table $rtb validated"
            }
        } else {
            Write-Output "`n💡 No route tables specified - endpoint will be associated with all route tables in VPC"
        }
    }

    # Handle policy document
    $policyJson = $null
    if ($PolicyDocument) {
        if (Test-Path $PolicyDocument) {
            Write-Output "`n📄 Loading policy document from file: $PolicyDocument"
            $policyJson = Get-Content $PolicyDocument -Raw
        } else {
            Write-Output "`n📄 Using provided policy document"
            $policyJson = $PolicyDocument
        }
        
        # Validate JSON
        try {
            $null = ConvertFrom-Json $policyJson
            Write-Output "✅ Policy document JSON is valid"
        } catch {
            Write-Error "Invalid JSON in policy document: $($_.Exception.Message)"
        }
    }

    # Check for existing endpoints for this service
    Write-Output "`n🔍 Checking for existing endpoints for this service..."
    $existingResult = aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VpcId" "Name=service-name,Values=$ServiceName" @awsArgs --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $existingData = $existingResult | ConvertFrom-Json
        if ($existingData.VpcEndpoints.Count -gt 0) {
            Write-Output "⚠️  Found $($existingData.VpcEndpoints.Count) existing endpoint(s) for this service:"
            foreach ($endpoint in $existingData.VpcEndpoints) {
                Write-Output "  - Endpoint: $($endpoint.VpcEndpointId)"
                Write-Output "    Type: $($endpoint.VpcEndpointType)"
                Write-Output "    State: $($endpoint.State)"
            }
            Write-Output "   Multiple endpoints for the same service may increase costs"
        } else {
            Write-Output "✅ No existing endpoints found for this service"
        }
    }

    # Build create command
    $createArgs = @(
        'ec2', 'create-vpc-endpoint',
        '--vpc-id', $VpcId,
        '--service-name', $ServiceName,
        '--vpc-endpoint-type', $VpcEndpointType
    ) + $awsArgs

    # Add type-specific parameters
    if ($VpcEndpointType -eq "Interface") {
        if ($SubnetId -and $SubnetId.Count -gt 0) {
            $createArgs += @('--subnet-ids')
            $createArgs += $SubnetId
        }
        
        if ($SecurityGroupId -and $SecurityGroupId.Count -gt 0) {
            $createArgs += @('--security-group-ids')
            $createArgs += $SecurityGroupId
        }
        
        $createArgs += @('--private-dns-enabled', $PrivateDnsEnabled.ToString().ToLower())
        
        if ($DnsRecordIpType) {
            $createArgs += @('--ip-address-type', $DnsRecordIpType)
        }
        
        if ($DnsOptions) {
            $createArgs += @('--dns-options', $DnsOptions)
        }
    }

    if ($VpcEndpointType -eq "Gateway") {
        if ($RouteTableId -and $RouteTableId.Count -gt 0) {
            $createArgs += @('--route-table-ids')
            $createArgs += $RouteTableId
        }
    }

    # Add optional parameters
    if ($policyJson) {
        $createArgs += @('--policy-document', $policyJson)
    }

    if ($TagSpecifications) {
        $createArgs += @('--tag-specifications', $TagSpecifications)
    }

    if ($ClientToken) {
        $createArgs += @('--client-token', $ClientToken)
    }

    # Estimate costs
    Write-Output "`n💰 Cost Estimation:"
    if ($VpcEndpointType -eq "Interface") {
        $hourlyPerEndpoint = 0.01  # Approximate cost per hour per interface endpoint
        $subnetCount = if ($SubnetId) { $SubnetId.Count } else { 1 }
        $totalHourly = $hourlyPerEndpoint * $subnetCount
        
        Write-Output "  Interface endpoint cost: ~`$$hourlyPerEndpoint/hour per subnet"
        Write-Output "  Estimated hourly cost: ~`$$totalHourly (for $subnetCount subnet(s))"
        Write-Output "  Estimated monthly cost: ~`$$([math]::Round($totalHourly * 24 * 30, 2))"
        Write-Output "  Plus data processing charges"
    } elseif ($VpcEndpointType -eq "Gateway") {
        Write-Output "  Gateway endpoints: No hourly charges"
        Write-Output "  Only standard data transfer charges apply"
    }

    # Create the VPC endpoint
    if (-not $DryRun) {
        Write-Output "`n🔗 Creating VPC endpoint..."
        $result = aws @createArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $endpointData = $result | ConvertFrom-Json
            $endpoint = $endpointData.VpcEndpoint
            
            Write-Output "✅ VPC endpoint created successfully!"
            Write-Output "  Endpoint ID: $($endpoint.VpcEndpointId)"
            Write-Output "  Service Name: $($endpoint.ServiceName)"
            Write-Output "  Type: $($endpoint.VpcEndpointType)"
            Write-Output "  State: $($endpoint.State)"
            Write-Output "  Creation Time: $($endpoint.CreationTimestamp)"

            if ($endpoint.DnsEntries -and $endpoint.DnsEntries.Count -gt 0) {
                Write-Output "  DNS Entries:"
                foreach ($dns in $endpoint.DnsEntries) {
                    Write-Output "    - $($dns.DnsName)"
                }
            }

            if ($endpoint.NetworkInterfaceIds -and $endpoint.NetworkInterfaceIds.Count -gt 0) {
                Write-Output "  Network Interfaces: $($endpoint.NetworkInterfaceIds -join ', ')"
            }

            if ($endpoint.RouteTableIds -and $endpoint.RouteTableIds.Count -gt 0) {
                Write-Output "  Associated Route Tables: $($endpoint.RouteTableIds -join ', ')"
            }

            # Monitor endpoint state
            if ($endpoint.State -eq "Pending") {
                Write-Output "`n🔄 Monitoring endpoint state..."
                $maxAttempts = 10
                $attempt = 0
                
                do {
                    Start-Sleep -Seconds 30
                    $attempt++
                    
                    $statusResult = aws ec2 describe-vpc-endpoints --vpc-endpoint-ids $($endpoint.VpcEndpointId) @awsArgs --output json 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $statusData = $statusResult | ConvertFrom-Json
                        if ($statusData.VpcEndpoints.Count -gt 0) {
                            $currentState = $statusData.VpcEndpoints[0].State
                            Write-Output "  Status check $attempt/$maxAttempts - State: $currentState"
                            
                            if ($currentState -eq "Available") {
                                Write-Output "✅ VPC endpoint is now available!"
                                break
                            }
                            
                            if ($currentState -eq "Failed") {
                                Write-Warning "⚠️  VPC endpoint creation failed"
                                if ($statusData.VpcEndpoints[0].FailureReason) {
                                    Write-Output "  Failure reason: $($statusData.VpcEndpoints[0].FailureReason)"
                                }
                                break
                            }
                        }
                    }
                    
                } while ($attempt -lt $maxAttempts)
                
                if ($attempt -eq $maxAttempts) {
                    Write-Warning "⚠️  Monitoring timeout reached. Check endpoint status manually."
                }
            }

            Write-Output "`n💡 Next Steps:"
            Write-Output "• Test connectivity to the AWS service through the endpoint"
            Write-Output "• Update application configurations to use endpoint DNS names if needed"
            Write-Output "• Monitor endpoint usage and costs in CloudWatch"
            Write-Output "• Consider adding additional subnets for high availability (interface endpoints)"
            
            if ($VpcEndpointType -eq "Interface") {
                Write-Output "• Review security group rules for endpoint access"
                Write-Output "• Verify private DNS resolution is working correctly"
            }
            
            if ($VpcEndpointType -eq "Gateway") {
                Write-Output "• Check route tables to ensure endpoint routes are added"
                Write-Output "• Verify S3 or DynamoDB access through the endpoint"
            }

        } else {
            Write-Error "Failed to create VPC endpoint: $result"
        }
    } else {
        Write-Output "`n✅ DRY RUN: VPC endpoint creation command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws $($createArgs -join ' ')"
    }

} catch {
    Write-Error "Failed to create VPC endpoint: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
