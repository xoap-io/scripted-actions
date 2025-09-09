<#
.SYNOPSIS
    Describes AWS Route Tables using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script provides comprehensive information about route tables including
    routes, associations, and related network components with filtering options.

.PARAMETER RouteTableId
    The ID of a specific route table to describe.

.PARAMETER RouteTableIds
    Comma-separated list of route table IDs to describe.

.PARAMETER VpcId
    Filter route tables by VPC ID.

.PARAMETER SubnetId
    Show route tables associated with a specific subnet.

.PARAMETER GatewayId
    Show route tables that have routes to a specific gateway.

.PARAMETER ShowRoutes
    Display detailed route information for each route table.

.PARAMETER ShowAssociations
    Display subnet and gateway associations for each route table.

.PARAMETER FilterByTag
    Filter route tables by tag (format: Key=Value).

.PARAMETER OutputFormat
    Output format: table, json, or detailed.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-describe-route-tables.ps1

.EXAMPLE
    .\aws-cli-describe-route-tables.ps1 -RouteTableId "rtb-12345678" -ShowRoutes -ShowAssociations

.EXAMPLE
    .\aws-cli-describe-route-tables.ps1 -VpcId "vpc-12345678" -OutputFormat "table"

.EXAMPLE
    .\aws-cli-describe-route-tables.ps1 -SubnetId "subnet-12345678"

.EXAMPLE
    .\aws-cli-describe-route-tables.ps1 -FilterByTag "Environment=Production"

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
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^rtb-[a-zA-Z0-9]{8,}$')]
    [string]$RouteTableId,

    [Parameter(Mandatory = $false)]
    [string]$RouteTableIds,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false)]
    [string]$GatewayId,

    [Parameter(Mandatory = $false)]
    [switch]$ShowRoutes,

    [Parameter(Mandatory = $false)]
    [switch]$ShowAssociations,

    [Parameter(Mandatory = $false)]
    [string]$FilterByTag,

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

    Write-Output "📋 Describing AWS Route Tables"
    if ($Region) { Write-Output "Region: $Region" }

    # Build describe command
    $describeArgs = @('ec2', 'describe-route-tables') + $awsArgs

    # Add filters
    $filters = @()
    
    if ($VpcId) {
        $filters += "Name=vpc-id,Values=$VpcId"
        Write-Output "Filter: VPC ID = $VpcId"
    }

    if ($SubnetId) {
        $filters += "Name=association.subnet-id,Values=$SubnetId"
        Write-Output "Filter: Subnet ID = $SubnetId"
    }

    if ($GatewayId) {
        $filters += "Name=route.gateway-id,Values=$GatewayId"
        Write-Output "Filter: Gateway ID = $GatewayId"
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

    # Add specific route table IDs
    $targetRouteTableIds = @()
    if ($RouteTableId) {
        $targetRouteTableIds += $RouteTableId
    }
    if ($RouteTableIds) {
        $targetRouteTableIds += $RouteTableIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($targetRouteTableIds.Count -gt 0) {
        $describeArgs += @('--route-table-ids')
        $describeArgs += $targetRouteTableIds
        Write-Output "Specific Route Tables: $($targetRouteTableIds -join ', ')"
    }

    # Execute the describe command
    $describeResult = aws @describeArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to describe route tables: $describeResult"
    }

    $routeTablesData = $describeResult | ConvertFrom-Json

    if ($routeTablesData.RouteTables.Count -eq 0) {
        Write-Output "No route tables found matching the specified criteria."
        exit 0
    }

    Write-Output "`n📊 Found $($routeTablesData.RouteTables.Count) Route Table(s)"

    # Display results based on output format
    switch ($OutputFormat) {
        'json' {
            Write-Output "`n📄 Route Tables (JSON):"
            $routeTablesData.RouteTables | ConvertTo-Json -Depth 5
        }
        
        'table' {
            Write-Output "`n📊 Route Tables Summary:"
            Write-Output "=" * 120
            Write-Output "Route Table ID`t`tVPC ID`t`t`tMain`tRoutes`tAssociations`tName"
            Write-Output "-" * 120
            
            foreach ($routeTable in $routeTablesData.RouteTables) {
                $isMain = $null -ne ($routeTable.Associations | Where-Object { $_.Main -eq $true })
                $name = "N/A"
                
                if ($routeTable.Tags) {
                    $nameTag = $routeTable.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -First 1
                    if ($nameTag) { $name = $nameTag.Value }
                }
                
                Write-Output "$($routeTable.RouteTableId)`t$($routeTable.VpcId)`t$isMain`t$($routeTable.Routes.Count)`t$($routeTable.Associations.Count)`t`t$name"
            }
        }
        
        'detailed' {
            foreach ($routeTable in $routeTablesData.RouteTables) {
                Write-Output "`n" + "=" * 80
                Write-Output "Route Table: $($routeTable.RouteTableId)"
                Write-Output "=" * 80
                
                # Basic information
                Write-Output "VPC ID: $($routeTable.VpcId)"
                Write-Output "Owner ID: $($routeTable.OwnerId)"
                
                # Check if main route table
                $isMain = $null -ne ($routeTable.Associations | Where-Object { $_.Main -eq $true })
                Write-Output "Main Route Table: $isMain"
                
                # Tags
                if ($routeTable.Tags -and $routeTable.Tags.Count -gt 0) {
                    Write-Output "`n🏷️  Tags:"
                    foreach ($tag in $routeTable.Tags) {
                        Write-Output "  • $($tag.Key): $($tag.Value)"
                    }
                }

                # Routes
                if ($ShowRoutes -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🛣️  Routes ($($routeTable.Routes.Count)):"
                    Write-Output "Destination`t`t`tTarget`t`t`t`tState`t`tOrigin"
                    Write-Output "-" * 80
                    
                    foreach ($route in $routeTable.Routes) {
                        $destination = $route.DestinationCidrBlock
                        if (-not $destination) { $destination = $route.DestinationIpv6CidrBlock }
                        if (-not $destination) { $destination = $route.DestinationPrefixListId }
                        
                        $target = "local"
                        if ($route.GatewayId -and $route.GatewayId -ne "local") { $target = $route.GatewayId }
                        if ($route.NatGatewayId) { $target = $route.NatGatewayId }
                        if ($route.NetworkInterfaceId) { $target = $route.NetworkInterfaceId }
                        if ($route.InstanceId) { $target = $route.InstanceId }
                        if ($route.VpcPeeringConnectionId) { $target = $route.VpcPeeringConnectionId }
                        if ($route.TransitGatewayId) { $target = $route.TransitGatewayId }
                        
                        Write-Output "$($destination.PadRight(25))`t$($target.PadRight(25))`t$($route.State.PadRight(10))`t$($route.Origin)"
                    }
                }

                # Associations
                if ($ShowAssociations -or $OutputFormat -eq 'detailed') {
                    Write-Output "`n🔗 Associations ($($routeTable.Associations.Count)):"
                    
                    if ($routeTable.Associations.Count -eq 0) {
                        Write-Output "  No explicit associations"
                    } else {
                        Write-Output "Association ID`t`t`tSubnet/Gateway ID`t`tType`t`tState"
                        Write-Output "-" * 80
                        
                        foreach ($association in $routeTable.Associations) {
                            $associatedWith = "Main"
                            $type = "Main"
                            
                            if ($association.SubnetId) {
                                $associatedWith = $association.SubnetId
                                $type = "Subnet"
                            }
                            if ($association.GatewayId) {
                                $associatedWith = $association.GatewayId
                                $type = "Gateway"
                            }
                            
                            Write-Output "$($association.RouteTableAssociationId)`t$($associatedWith.PadRight(20))`t$($type.PadRight(10))`t$($association.AssociationState.State)"
                        }
                    }
                }

                # Route analysis
                Write-Output "`n🔍 Route Analysis:"
                
                # Check for internet connectivity
                $igwRoute = $routeTable.Routes | Where-Object { $_.GatewayId -like 'igw-*' -and ($_.DestinationCidrBlock -eq '0.0.0.0/0' -or $_.DestinationIpv6CidrBlock -eq '::/0') }
                if ($igwRoute) {
                    Write-Output "  ✅ Has Internet Gateway route (public connectivity)"
                }

                # Check for NAT Gateway
                $natRoute = $routeTable.Routes | Where-Object { $_.NatGatewayId -and ($_.DestinationCidrBlock -eq '0.0.0.0/0' -or $_.DestinationIpv6CidrBlock -eq '::/0') }
                if ($natRoute) {
                    Write-Output "  ✅ Has NAT Gateway route (private subnet with internet access)"
                }

                # Check for VPC Peering
                $peeringRoutes = $routeTable.Routes | Where-Object { $_.VpcPeeringConnectionId }
                if ($peeringRoutes.Count -gt 0) {
                    Write-Output "  ✅ Has VPC Peering routes ($($peeringRoutes.Count))"
                }

                # Check for Transit Gateway
                $tgwRoutes = $routeTable.Routes | Where-Object { $_.TransitGatewayId }
                if ($tgwRoutes.Count -gt 0) {
                    Write-Output "  ✅ Has Transit Gateway routes ($($tgwRoutes.Count))"
                }

                # Check for custom routes
                $customRoutes = $routeTable.Routes | Where-Object { $_.Origin -eq 'CreateRoute' }
                if ($customRoutes.Count -gt 0) {
                    Write-Output "  📝 Custom routes: $($customRoutes.Count)"
                }

                # Identify route table type
                if ($isMain) {
                    Write-Output "  📍 This is the main route table for the VPC"
                }
                
                $subnetAssociations = $routeTable.Associations | Where-Object { $_.SubnetId }
                if ($subnetAssociations.Count -gt 0) {
                    Write-Output "  📍 Associated with $($subnetAssociations.Count) subnet(s)"
                }
            }
        }
    }

    # Summary statistics
    if ($OutputFormat -eq 'detailed') {
        Write-Output "`n📈 Summary Statistics:"
        
        $totalRoutes = ($routeTablesData.RouteTables | ForEach-Object { $_.Routes.Count } | Measure-Object -Sum).Sum
        $totalAssociations = ($routeTablesData.RouteTables | ForEach-Object { $_.Associations.Count } | Measure-Object -Sum).Sum
        $mainRouteTables = ($routeTablesData.RouteTables | Where-Object { ($_.Associations | Where-Object { $_.Main -eq $true }) -ne $null }).Count
        
        Write-Output "  • Total Route Tables: $($routeTablesData.RouteTables.Count)"
        Write-Output "  • Main Route Tables: $mainRouteTables"
        Write-Output "  • Custom Route Tables: $($routeTablesData.RouteTables.Count - $mainRouteTables)"
        Write-Output "  • Total Routes: $totalRoutes"
        Write-Output "  • Total Associations: $totalAssociations"

        # VPC distribution
        $vpcGroups = $routeTablesData.RouteTables | Group-Object VpcId
        Write-Output "`n📊 Distribution by VPC:"
        foreach ($group in $vpcGroups) {
            Write-Output "  • $($group.Name): $($group.Count) route table(s)"
        }
    }

    Write-Output "`n💡 Useful Commands:"
    Write-Output "# Associate route table with subnet:"
    Write-Output "aws ec2 associate-route-table --route-table-id rtb-xxxxxxxx --subnet-id subnet-xxxxxxxx"
    Write-Output ""
    Write-Output "# Create a route:"
    Write-Output "aws ec2 create-route --route-table-id rtb-xxxxxxxx --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxxxxxxx"

    Write-Output "`n✅ Route table description completed."

} catch {
    Write-Error "Failed to describe route tables: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
