<#
.SYNOPSIS
    Describes AWS VPCs using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script provides comprehensive information about VPCs including
    CIDR blocks, subnets, route tables, gateways, and network configurations.

.PARAMETER VpcId
    The ID of a specific VPC to describe.

.PARAMETER VpcIds
    Comma-separated list of VPC IDs to describe.

.PARAMETER State
    Filter VPCs by state (available, pending).

.PARAMETER IsDefault
    Filter to show only default VPCs (true/false).

.PARAMETER FilterByTag
    Filter VPCs by tag (format: Key=Value).

.PARAMETER ShowSubnets
    Show detailed subnet information for each VPC.

.PARAMETER ShowRouteTables
    Show route table information for each VPC.

.PARAMETER ShowGateways
    Show gateway information for each VPC.

.PARAMETER ShowNetworkAcls
    Show Network ACL information for each VPC.

.PARAMETER ShowSecurityGroups
    Show Security Group summary for each VPC.

.PARAMETER OutputFormat
    Output format: table, json, or detailed.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-describe-vpcs.ps1

.EXAMPLE
    .\aws-cli-describe-vpcs.ps1 -VpcId "vpc-12345678" -ShowSubnets -ShowRouteTables

.EXAMPLE
    .\aws-cli-describe-vpcs.ps1 -IsDefault "true" -OutputFormat "table"

.EXAMPLE
    .\aws-cli-describe-vpcs.ps1 -FilterByTag "Environment=Production" -ShowGateways

.NOTES
    Author: XOAP
    Date: 2025-08-06

    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false)]
    [string]$VpcIds,

    [Parameter(Mandatory = $false)]
    [ValidateSet('available', 'pending')]
    [string]$State,

    [Parameter(Mandatory = $false)]
    [ValidateSet('true', 'false')]
    [string]$IsDefault,

    [Parameter(Mandatory = $false)]
    [string]$FilterByTag,

    [Parameter(Mandatory = $false)]
    [switch]$ShowSubnets,

    [Parameter(Mandatory = $false)]
    [switch]$ShowRouteTables,

    [Parameter(Mandatory = $false)]
    [switch]$ShowGateways,

    [Parameter(Mandatory = $false)]
    [switch]$ShowNetworkAcls,

    [Parameter(Mandatory = $false)]
    [switch]$ShowSecurityGroups,

    [Parameter(Mandatory = $false)]
    [ValidateSet('table', 'json', 'detailed')]
    [string]$OutputFormat = 'detailed',

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

    Write-Output "🌐 Describing AWS VPCs"
    if ($Region) { Write-Output "Region: $Region" }

    # Build describe command
    $describeArgs = @('ec2', 'describe-vpcs') + $awsArgs

    # Add filters
    $filters = @()

    if ($State) {
        $filters += "Name=state,Values=$State"
        Write-Output "Filter: State = $State"
    }

    if ($IsDefault) {
        $filters += "Name=is-default,Values=$IsDefault"
        Write-Output "Filter: Is Default = $IsDefault"
    }

    if ($FilterByTag) {
        if ($FilterByTag -match '^(.+)=(.+)$') {
            $tagKey = $matches[1]
            $tagValue = $matches[2]
            $filters += "Name=tag:$tagKey,Values=$tagValue"
            Write-Output "Filter: Tag $tagKey = $tagValue"
        } else {
            throw "FilterByTag must be in format 'Key=Value'"
        }
    }

    if ($filters.Count -gt 0) {
        $describeArgs += @('--filters')
        $describeArgs += $filters
    }

    # Add specific VPC IDs
    $targetVpcIds = @()
    if ($VpcId) {
        $targetVpcIds += $VpcId
    }
    if ($VpcIds) {
        $targetVpcIds += $VpcIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($targetVpcIds.Count -gt 0) {
        $describeArgs += @('--vpc-ids')
        $describeArgs += $targetVpcIds
        Write-Output "Specific VPCs: $($targetVpcIds -join ', ')"
    }

    # Execute the describe command
    $describeResult = aws @describeArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to describe VPCs: $describeResult"
    }

    $vpcsData = $describeResult | ConvertFrom-Json

    if ($vpcsData.Vpcs.Count -eq 0) {
        Write-Output "No VPCs found matching the specified criteria."
        exit 0
    }

    Write-Output "`n📊 Found $($vpcsData.Vpcs.Count) VPC(s)"

    # Display results based on output format
    switch ($OutputFormat) {
        'json' {
            Write-Output "`n📄 VPCs (JSON):"
            $vpcsData.Vpcs | ConvertTo-Json -Depth 5
        }

        'table' {
            Write-Output "`n📊 VPCs Summary:"
            Write-Output "=" * 120
            Write-Output "VPC ID`t`t`tCIDR Block`t`tState`t`tDefault`tName"
            Write-Output "-" * 120

            foreach ($vpc in $vpcsData.Vpcs) {
                $name = "N/A"
                if ($vpc.Tags) {
                    $nameTag = $vpc.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -First 1
                    if ($nameTag) { $name = $nameTag.Value }
                }

                Write-Output "$($vpc.VpcId)`t$($vpc.CidrBlock.PadRight(15))`t$($vpc.State.PadRight(10))`t$($vpc.IsDefault)`t$name"
            }
        }

        'detailed' {
            foreach ($vpc in $vpcsData.Vpcs) {
                Write-Output "`n" + "=" * 80
                Write-Output "VPC: $($vpc.VpcId)"
                Write-Output "=" * 80

                # Basic information
                Write-Output "State: $($vpc.State)"
                Write-Output "CIDR Block: $($vpc.CidrBlock)"
                Write-Output "Default VPC: $($vpc.IsDefault)"
                Write-Output "Owner ID: $($vpc.OwnerId)"
                Write-Output "Instance Tenancy: $($vpc.InstanceTenancy)"

                # Additional CIDR blocks
                if ($vpc.CidrBlockAssociationSet -and $vpc.CidrBlockAssociationSet.Count -gt 1) {
                    Write-Output "`n🔗 Additional CIDR Blocks:"
                    foreach ($cidrAssoc in $vpc.CidrBlockAssociationSet) {
                        if ($cidrAssoc.CidrBlock -ne $vpc.CidrBlock) {
                            Write-Output "  • $($cidrAssoc.CidrBlock) (State: $($cidrAssoc.CidrBlockState.State))"
                        }
                    }
                }

                # IPv6 CIDR blocks
                if ($vpc.Ipv6CidrBlockAssociationSet -and $vpc.Ipv6CidrBlockAssociationSet.Count -gt 0) {
                    Write-Output "`n🔗 IPv6 CIDR Blocks:"
                    foreach ($ipv6Assoc in $vpc.Ipv6CidrBlockAssociationSet) {
                        Write-Output "  • $($ipv6Assoc.Ipv6CidrBlock) (State: $($ipv6Assoc.Ipv6CidrBlockState.State))"
                    }
                }

                # DHCP Options
                if ($vpc.DhcpOptionsId) {
                    Write-Output "`n⚙️  DHCP Options Set: $($vpc.DhcpOptionsId)"
                }

                # Tags
                if ($vpc.Tags -and $vpc.Tags.Count -gt 0) {
                    Write-Output "`n🏷️  Tags:"
                    foreach ($tag in $vpc.Tags) {
                        Write-Output "  • $($tag.Key): $($tag.Value)"
                    }
                }

                # Subnets
                if ($ShowSubnets -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🏠 Subnets:"

                    $subnetsResult = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$($vpc.VpcId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $subnetsData = $subnetsResult | ConvertFrom-Json

                        if ($subnetsData.Subnets.Count -eq 0) {
                            Write-Output "  No subnets found"
                        } else {
                            Write-Output "  Subnet ID`t`tCIDR`t`t`tAZ`t`tPublic`tAvailable IPs"
                            Write-Output "  " + "-" * 70

                            foreach ($subnet in $subnetsData.Subnets) {
                                Write-Output "  $($subnet.SubnetId)`t$($subnet.CidrBlock.PadRight(15))`t$($subnet.AvailabilityZone)`t$($subnet.MapPublicIpOnLaunch)`t$($subnet.AvailableIpAddressCount)"
                            }

                            # Subnet statistics
                            $publicSubnets = ($subnetsData.Subnets | Where-Object { $_.MapPublicIpOnLaunch }).Count
                            $privateSubnets = $subnetsData.Subnets.Count - $publicSubnets
                            $totalAvailableIps = ($subnetsData.Subnets | ForEach-Object { $_.AvailableIpAddressCount } | Measure-Object -Sum).Sum

                            Write-Output "`n  📊 Summary: $($subnetsData.Subnets.Count) total, $publicSubnets public, $privateSubnets private"
                            Write-Output "  📊 Available IPs: $totalAvailableIps"
                        }
                    }
                }

                # Route Tables
                if ($ShowRouteTables -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🛣️  Route Tables:"

                    $routeTablesResult = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$($vpc.VpcId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $routeTablesData = $routeTablesResult | ConvertFrom-Json

                        if ($routeTablesData.RouteTables.Count -eq 0) {
                            Write-Output "  No route tables found"
                        } else {
                            foreach ($routeTable in $routeTablesData.RouteTables) {
                                $isMain = $null -ne ($routeTable.Associations | Where-Object { $_.Main -eq $true })
                                $associationCount = $routeTable.Associations.Count

                                Write-Output "  • $($routeTable.RouteTableId) $(if ($isMain) {'(Main)'} else {'(Custom)'}) - $($routeTable.Routes.Count) routes, $associationCount associations"
                            }

                            $customRtbs = $routeTablesData.RouteTables.Count - 1

                            Write-Output "`n  📊 Summary: 1 main, $customRtbs custom route tables"
                        }
                    }
                }

                # Gateways
                if ($ShowGateways -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🌉 Gateways:"

                    # Internet Gateways
                    $igwResult = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$($vpc.VpcId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $igwData = $igwResult | ConvertFrom-Json

                        if ($igwData.InternetGateways.Count -gt 0) {
                            foreach ($igw in $igwData.InternetGateways) {
                                $attachment = $igw.Attachments | Where-Object { $_.VpcId -eq $vpc.VpcId }
                                Write-Output "  • Internet Gateway: $($igw.InternetGatewayId) (State: $($attachment.State))"
                            }
                        } else {
                            Write-Output "  • No Internet Gateway attached"
                        }
                    }

                    # NAT Gateways
                    $natResult = aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$($vpc.VpcId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $natData = $natResult | ConvertFrom-Json

                        if ($natData.NatGateways.Count -gt 0) {
                            foreach ($nat in $natData.NatGateways) {
                                Write-Output "  • NAT Gateway: $($nat.NatGatewayId) (State: $($nat.State), Subnet: $($nat.SubnetId))"
                            }
                        } else {
                            Write-Output "  • No NAT Gateways found"
                        }
                    }

                    # VPC Endpoints
                    $endpointResult = aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$($vpc.VpcId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $endpointData = $endpointResult | ConvertFrom-Json

                        if ($endpointData.VpcEndpoints.Count -gt 0) {
                            Write-Output "  • VPC Endpoints: $($endpointData.VpcEndpoints.Count)"
                            foreach ($endpoint in $endpointData.VpcEndpoints) {
                                Write-Output "    - $($endpoint.VpcEndpointId): $($endpoint.ServiceName) ($($endpoint.VpcEndpointType))"
                            }
                        } else {
                            Write-Output "  • No VPC Endpoints found"
                        }
                    }
                }

                # Network ACLs
                if ($ShowNetworkAcls -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🛡️  Network ACLs:"

                    $naclResult = aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$($vpc.VpcId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $naclData = $naclResult | ConvertFrom-Json

                        foreach ($nacl in $naclData.NetworkAcls) {
                            $associationCount = $nacl.Associations.Count
                            Write-Output "  • $($nacl.NetworkAclId) $(if ($nacl.IsDefault) {'(Default)'} else {'(Custom)'}) - $($nacl.Entries.Count) entries, $associationCount associations"
                        }

                        $defaultNacls = ($naclData.NetworkAcls | Where-Object { $_.IsDefault }).Count
                        $customNacls = $naclData.NetworkAcls.Count - $defaultNacls

                        Write-Output "`n  📊 Summary: $defaultNacls default, $customNacls custom Network ACLs"
                    }
                }

                # Security Groups
                if ($ShowSecurityGroups -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🔒 Security Groups:"

                    $sgResult = aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$($vpc.VpcId)" @awsArgs --output json 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        $sgData = $sgResult | ConvertFrom-Json

                        $defaultSgs = ($sgData.SecurityGroups | Where-Object { $_.GroupName -eq 'default' }).Count
                        $customSgs = $sgData.SecurityGroups.Count - $defaultSgs

                        Write-Output "  • Total Security Groups: $($sgData.SecurityGroups.Count)"
                        Write-Output "  • Default: $defaultSgs, Custom: $customSgs"

                        if ($OutputFormat -eq 'detailed') {
                            foreach ($sg in $sgData.SecurityGroups | Select-Object -First 5) {
                                Write-Output "    - $($sg.GroupId): $($sg.GroupName) ($($sg.IpPermissions.Count) inbound, $($sg.IpPermissionsEgress.Count) outbound rules)"
                            }

                            if ($sgData.SecurityGroups.Count -gt 5) {
                                Write-Output "    ... and $($sgData.SecurityGroups.Count - 5) more"
                            }
                        }
                    }
                }

                # VPC Analysis
                Write-Output "`n🔍 VPC Analysis:"

                # CIDR analysis
                $cidrParts = $vpc.CidrBlock -split '/'
                $networkBits = [int]$cidrParts[1]
                $hostBits = 32 - $networkBits
                $totalIps = [math]::Pow(2, $hostBits)

                Write-Output "  📊 CIDR Block Analysis:"
                Write-Output "    • Network: /$networkBits"
                Write-Output "    • Total IP addresses: $totalIps"
                Write-Output "    • Usable for hosts: $($totalIps - 2)"

                if ($networkBits -le 16) {
                    Write-Output "    ✅ Large address space - good for enterprise workloads"
                } elseif ($networkBits -le 20) {
                    Write-Output "    ✅ Medium address space - suitable for most workloads"
                } else {
                    Write-Output "    ⚠️  Small address space - consider planning carefully"
                }

                # Connectivity analysis
                Write-Output "  🌐 Connectivity:"
                if ($igwData.InternetGateways.Count -gt 0) {
                    Write-Output "    ✅ Internet connectivity available"
                } else {
                    Write-Output "    🔒 No internet gateway - private VPC"
                }

                if ($natData.NatGateways.Count -gt 0) {
                    Write-Output "    ✅ NAT Gateways available for private subnet internet access"
                }

                # High availability analysis
                if ($subnetsData.Subnets.Count -gt 0) {
                    $azCount = ($subnetsData.Subnets | Group-Object AvailabilityZone).Count
                    Write-Output "  🏗️  High Availability:"
                    Write-Output "    • Spans $azCount Availability Zones"

                    if ($azCount -ge 2) {
                        Write-Output "    ✅ Multi-AZ deployment possible"
                    } else {
                        Write-Output "    ⚠️  Single AZ - consider multi-AZ for redundancy"
                    }
                }
            }
        }
    }

    # Overall summary statistics
    if ($OutputFormat -eq 'detailed') {
        Write-Output "`n📈 Overall Summary:"

        $defaultVpcs = ($vpcsData.Vpcs | Where-Object { $_.IsDefault }).Count
        $customVpcs = $vpcsData.Vpcs.Count - $defaultVpcs

        Write-Output "  • Total VPCs: $($vpcsData.Vpcs.Count)"
        Write-Output "  • Default VPCs: $defaultVpcs"
        Write-Output "  • Custom VPCs: $customVpcs"

        # CIDR analysis
        $cidrSizes = $vpcsData.Vpcs | ForEach-Object {
            $networkBits = [int](($_.CidrBlock -split '/')[1])
            $networkBits
        } | Group-Object | Sort-Object Name

        Write-Output "`n📊 CIDR Block Distribution:"
        foreach ($group in $cidrSizes) {
            Write-Output "  • /$($group.Name): $($group.Count) VPC(s)"
        }
    }

    Write-Output "`n💡 Useful Commands:"
    Write-Output "# Create a subnet in VPC:"
    Write-Output "aws ec2 create-subnet --vpc-id vpc-xxxxxxxx --cidr-block 10.0.1.0/24"
    Write-Output ""
    Write-Output "# Attach Internet Gateway to VPC:"
    Write-Output "aws ec2 attach-internet-gateway --internet-gateway-id igw-xxxxxxxx --vpc-id vpc-xxxxxxxx"

    Write-Output "`n✅ VPC description completed."

} catch {
    Write-Error "Failed to describe VPCs: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
