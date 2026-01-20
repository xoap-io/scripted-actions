<#
.SYNOPSIS
    Modifies subnet attributes in AWS using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script modifies subnet attributes such as auto-assign public IP,
    customer-owned IP, and map customer-owned IP on launch settings.

.PARAMETER SubnetId
    The ID of the subnet to modify.

.PARAMETER MapPublicIpOnLaunch
    Enable or disable automatic public IP assignment for instances launched in this subnet.

.PARAMETER MapCustomerOwnedIpOnLaunch
    Enable or disable automatic customer-owned IP assignment for instances launched in this subnet.

.PARAMETER CustomerOwnedIpv4Pool
    The customer-owned IPv4 address pool for the subnet.

.PARAMETER EnableDns64
    Enable or disable DNS64 for the subnet.

.PARAMETER EnableResourceNameDnsARecord
    Enable or disable resource-based naming for instances in the subnet.

.PARAMETER EnableResourceNameDnsAAAARecord
    Enable or disable resource-based IPv6 naming for instances in the subnet.

.PARAMETER PrivateDnsHostnameType
    The type of hostname to assign to instances (ip-name, resource-name).

.PARAMETER ShowCurrent
    Display current subnet attributes before making changes.

.PARAMETER DryRun
    Perform a dry run to validate parameters without making changes.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-modify-subnet-attribute.ps1 -SubnetId "subnet-12345678" -MapPublicIpOnLaunch $true

.EXAMPLE
    .\aws-cli-modify-subnet-attribute.ps1 -SubnetId "subnet-12345678" -MapPublicIpOnLaunch $false -ShowCurrent

.EXAMPLE
    .\aws-cli-modify-subnet-attribute.ps1 -SubnetId "subnet-12345678" -EnableDns64 $true -DryRun

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
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false)]
    [bool]$MapPublicIpOnLaunch,

    [Parameter(Mandatory = $false)]
    [bool]$MapCustomerOwnedIpOnLaunch,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^ipv4pool-coip-[a-zA-Z0-9]{8,}$')]
    [string]$CustomerOwnedIpv4Pool,

    [Parameter(Mandatory = $false)]
    [bool]$EnableDns64,

    [Parameter(Mandatory = $false)]
    [bool]$EnableResourceNameDnsARecord,

    [Parameter(Mandatory = $false)]
    [bool]$EnableResourceNameDnsAAAARecord,

    [Parameter(Mandatory = $false)]
    [ValidateSet("ip-name", "resource-name")]
    [string]$PrivateDnsHostnameType,

    [Parameter(Mandatory = $false)]
    [switch]$ShowCurrent,

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

    Write-Output "⚙️  Modifying subnet attributes for: $SubnetId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Get current subnet details
    Write-Output "`n🔍 Retrieving current subnet information..."
    $subnetResult = aws ec2 describe-subnets --subnet-ids $SubnetId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Subnet $SubnetId not found or not accessible: $subnetResult"
    }

    $subnetData = $subnetResult | ConvertFrom-Json

    if ($subnetData.Subnets.Count -eq 0) {
        Write-Error "Subnet $SubnetId not found"
    }

    $subnet = $subnetData.Subnets[0]

    # Display current subnet details
    Write-Output "✅ Subnet found:"
    Write-Output "  Subnet ID: $($subnet.SubnetId)"
    Write-Output "  State: $($subnet.State)"
    Write-Output "  VPC ID: $($subnet.VpcId)"
    Write-Output "  CIDR Block: $($subnet.CidrBlock)"
    Write-Output "  Availability Zone: $($subnet.AvailabilityZone)"

    if ($subnet.Tags -and $subnet.Tags.Count -gt 0) {
        $nameTag = $subnet.Tags | Where-Object { $_.Key -eq "Name" }
        if ($nameTag) {
            Write-Output "  Name: $($nameTag.Value)"
        }
    }

    # Show current attributes if requested or if no changes specified
    $parameterCount = 0
    if ($PSBoundParameters.ContainsKey('MapPublicIpOnLaunch')) { $parameterCount++ }
    if ($PSBoundParameters.ContainsKey('MapCustomerOwnedIpOnLaunch')) { $parameterCount++ }
    if ($PSBoundParameters.ContainsKey('CustomerOwnedIpv4Pool')) { $parameterCount++ }
    if ($PSBoundParameters.ContainsKey('EnableDns64')) { $parameterCount++ }
    if ($PSBoundParameters.ContainsKey('EnableResourceNameDnsARecord')) { $parameterCount++ }
    if ($PSBoundParameters.ContainsKey('EnableResourceNameDnsAAAARecord')) { $parameterCount++ }
    if ($PSBoundParameters.ContainsKey('PrivateDnsHostnameType')) { $parameterCount++ }

    if ($ShowCurrent -or $parameterCount -eq 0) {
        Write-Output "`n📋 Current Subnet Attributes:"
        Write-Output "  Map Public IP on Launch: $($subnet.MapPublicIpOnLaunch)"

        if ($null -ne $subnet.MapCustomerOwnedIpOnLaunch) {
            Write-Output "  Map Customer Owned IP on Launch: $($subnet.MapCustomerOwnedIpOnLaunch)"
        }

        if ($subnet.CustomerOwnedIpv4Pool) {
            Write-Output "  Customer Owned IPv4 Pool: $($subnet.CustomerOwnedIpv4Pool)"
        }

        if ($null -ne $subnet.EnableDns64) {
            Write-Output "  DNS64 Enabled: $($subnet.EnableDns64)"
        }

        if ($null -ne $subnet.EnableResourceNameDnsARecord) {
            Write-Output "  Resource Name DNS A Record: $($subnet.EnableResourceNameDnsARecord)"
        }

        if ($null -ne $subnet.EnableResourceNameDnsAAAARecord) {
            Write-Output "  Resource Name DNS AAAA Record: $($subnet.EnableResourceNameDnsAAAARecord)"
        }

        if ($subnet.PrivateDnsHostnameTypeOnLaunch) {
            Write-Output "  Private DNS Hostname Type: $($subnet.PrivateDnsHostnameTypeOnLaunch)"
        }
    }

    if ($parameterCount -eq 0) {
        Write-Output "`n💡 No attribute changes specified. Use parameters to modify subnet attributes."
        Write-Output "Available attributes to modify:"
        Write-Output "  -MapPublicIpOnLaunch <bool>"
        Write-Output "  -MapCustomerOwnedIpOnLaunch <bool>"
        Write-Output "  -CustomerOwnedIpv4Pool <pool-id>"
        Write-Output "  -EnableDns64 <bool>"
        Write-Output "  -EnableResourceNameDnsARecord <bool>"
        Write-Output "  -EnableResourceNameDnsAAAARecord <bool>"
        Write-Output "  -PrivateDnsHostnameType <ip-name|resource-name>"
        exit 0
    }

    # Check subnet state
    if ($subnet.State -ne "available") {
        Write-Warning "⚠️  Subnet is in '$($subnet.State)' state - modifications may not be possible"
    }

    # Validate VPC settings for certain attributes
    if ($PSBoundParameters.ContainsKey('EnableDns64') -or
        $PSBoundParameters.ContainsKey('EnableResourceNameDnsARecord') -or
        $PSBoundParameters.ContainsKey('EnableResourceNameDnsAAAARecord') -or
        $PSBoundParameters.ContainsKey('PrivateDnsHostnameType')) {

        Write-Output "`n🔍 Checking VPC DNS settings..."
        $vpcResult = aws ec2 describe-vpc-attribute --vpc-id $($subnet.VpcId) --attribute enableDnsHostnames @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $vpcDnsData = $vpcResult | ConvertFrom-Json
            if (-not $vpcDnsData.EnableDnsHostnames.Value) {
                Write-Warning "⚠️  VPC DNS hostnames are disabled. Some subnet DNS attributes may not function properly."
            }
        }

        $vpcDnsResult = aws ec2 describe-vpc-attribute --vpc-id $($subnet.VpcId) --attribute enableDnsSupport @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $vpcDnsSupportData = $vpcDnsResult | ConvertFrom-Json
            if (-not $vpcDnsSupportData.EnableDnsSupport.Value) {
                Write-Warning "⚠️  VPC DNS support is disabled. DNS-related subnet attributes will not function."
            }
        }
    }

    # Build modification commands
    $modifications = @()

    # Map Public IP on Launch
    if ($PSBoundParameters.ContainsKey('MapPublicIpOnLaunch')) {
        $currentValue = $subnet.MapPublicIpOnLaunch
        if ($currentValue -ne $MapPublicIpOnLaunch) {
            $modifications += [PSCustomObject]@{
                Attribute = "MapPublicIpOnLaunch"
                CurrentValue = $currentValue
                NewValue = $MapPublicIpOnLaunch
                Command = @('ec2', 'modify-subnet-attribute', '--subnet-id', $SubnetId, '--map-public-ip-on-launch', $MapPublicIpOnLaunch.ToString().ToLower())
            }
        } else {
            Write-Output "ℹ️  MapPublicIpOnLaunch is already set to $MapPublicIpOnLaunch"
        }
    }

    # Map Customer Owned IP on Launch
    if ($PSBoundParameters.ContainsKey('MapCustomerOwnedIpOnLaunch')) {
        $currentValue = $subnet.MapCustomerOwnedIpOnLaunch
        if ($currentValue -ne $MapCustomerOwnedIpOnLaunch) {
            $modifications += [PSCustomObject]@{
                Attribute = "MapCustomerOwnedIpOnLaunch"
                CurrentValue = $currentValue
                NewValue = $MapCustomerOwnedIpOnLaunch
                Command = @('ec2', 'modify-subnet-attribute', '--subnet-id', $SubnetId, '--map-customer-owned-ip-on-launch', $MapCustomerOwnedIpOnLaunch.ToString().ToLower())
            }
        } else {
            Write-Output "ℹ️  MapCustomerOwnedIpOnLaunch is already set to $MapCustomerOwnedIpOnLaunch"
        }
    }

    # Customer Owned IPv4 Pool
    if ($PSBoundParameters.ContainsKey('CustomerOwnedIpv4Pool')) {
        $currentValue = $subnet.CustomerOwnedIpv4Pool
        if ($currentValue -ne $CustomerOwnedIpv4Pool) {
            $modifications += [PSCustomObject]@{
                Attribute = "CustomerOwnedIpv4Pool"
                CurrentValue = $currentValue
                NewValue = $CustomerOwnedIpv4Pool
                Command = @('ec2', 'modify-subnet-attribute', '--subnet-id', $SubnetId, '--customer-owned-ipv4-pool', $CustomerOwnedIpv4Pool)
            }
        } else {
            Write-Output "ℹ️  CustomerOwnedIpv4Pool is already set to $CustomerOwnedIpv4Pool"
        }
    }

    # Enable DNS64
    if ($PSBoundParameters.ContainsKey('EnableDns64')) {
        $currentValue = $subnet.EnableDns64
        if ($currentValue -ne $EnableDns64) {
            $modifications += [PSCustomObject]@{
                Attribute = "EnableDns64"
                CurrentValue = $currentValue
                NewValue = $EnableDns64
                Command = @('ec2', 'modify-subnet-attribute', '--subnet-id', $SubnetId, '--enable-dns64', $EnableDns64.ToString().ToLower())
            }
        } else {
            Write-Output "ℹ️  EnableDns64 is already set to $EnableDns64"
        }
    }

    # Enable Resource Name DNS A Record
    if ($PSBoundParameters.ContainsKey('EnableResourceNameDnsARecord')) {
        $currentValue = $subnet.EnableResourceNameDnsARecord
        if ($currentValue -ne $EnableResourceNameDnsARecord) {
            $modifications += [PSCustomObject]@{
                Attribute = "EnableResourceNameDnsARecord"
                CurrentValue = $currentValue
                NewValue = $EnableResourceNameDnsARecord
                Command = @('ec2', 'modify-subnet-attribute', '--subnet-id', $SubnetId, '--enable-resource-name-dns-a-record', $EnableResourceNameDnsARecord.ToString().ToLower())
            }
        } else {
            Write-Output "ℹ️  EnableResourceNameDnsARecord is already set to $EnableResourceNameDnsARecord"
        }
    }

    # Enable Resource Name DNS AAAA Record
    if ($PSBoundParameters.ContainsKey('EnableResourceNameDnsAAAARecord')) {
        $currentValue = $subnet.EnableResourceNameDnsAAAARecord
        if ($currentValue -ne $EnableResourceNameDnsAAAARecord) {
            $modifications += [PSCustomObject]@{
                Attribute = "EnableResourceNameDnsAAAARecord"
                CurrentValue = $currentValue
                NewValue = $EnableResourceNameDnsAAAARecord
                Command = @('ec2', 'modify-subnet-attribute', '--subnet-id', $SubnetId, '--enable-resource-name-dns-aaaa-record', $EnableResourceNameDnsAAAARecord.ToString().ToLower())
            }
        } else {
            Write-Output "ℹ️  EnableResourceNameDnsAAAARecord is already set to $EnableResourceNameDnsAAAARecord"
        }
    }

    # Private DNS Hostname Type
    if ($PSBoundParameters.ContainsKey('PrivateDnsHostnameType')) {
        $currentValue = $subnet.PrivateDnsHostnameTypeOnLaunch
        if ($currentValue -ne $PrivateDnsHostnameType) {
            $modifications += [PSCustomObject]@{
                Attribute = "PrivateDnsHostnameType"
                CurrentValue = $currentValue
                NewValue = $PrivateDnsHostnameType
                Command = @('ec2', 'modify-subnet-attribute', '--subnet-id', $SubnetId, '--private-dns-hostname-type-on-launch', $PrivateDnsHostnameType)
            }
        } else {
            Write-Output "ℹ️  PrivateDnsHostnameType is already set to $PrivateDnsHostnameType"
        }
    }

    if ($modifications.Count -eq 0) {
        Write-Output "`n✅ No changes needed - all specified attributes are already set to the desired values"
        exit 0
    }

    # Display planned changes
    Write-Output "`n📋 Planned Changes:"
    foreach ($mod in $modifications) {
        Write-Output "  $($mod.Attribute):"
        Write-Output "    Current: $($mod.CurrentValue)"
        Write-Output "    New: $($mod.NewValue)"
    }

    # Special warnings for certain changes
    $hasPublicIpChange = $modifications | Where-Object { $_.Attribute -eq "MapPublicIpOnLaunch" }
    if ($hasPublicIpChange) {
        if ($hasPublicIpChange.NewValue -eq $true) {
            Write-Output "`n⚠️  WARNING: Enabling MapPublicIpOnLaunch will cause future instances to receive public IP addresses"
            Write-Output "   This may have security and cost implications"
        } else {
            Write-Output "`n⚠️  WARNING: Disabling MapPublicIpOnLaunch will prevent future instances from receiving public IP addresses"
            Write-Output "   This may affect connectivity for instances that need internet access"
        }
    }

    # Apply modifications
    if (-not $DryRun) {
        Write-Output "`n⚙️  Applying subnet attribute modifications..."

        foreach ($mod in $modifications) {
            Write-Output "  Modifying $($mod.Attribute)..."

            $modifyArgs = $mod.Command + $awsArgs + @('--output', 'json')
            $result = aws @modifyArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "  ✅ $($mod.Attribute) updated successfully"
            } else {
                Write-Error "Failed to update $($mod.Attribute): $result"
            }
        }

        # Verify changes
        Write-Output "`n🔍 Verifying attribute changes..."
        $verifyResult = aws ec2 describe-subnets --subnet-ids $SubnetId @awsArgs --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $verifyData = $verifyResult | ConvertFrom-Json
            $updatedSubnet = $verifyData.Subnets[0]

            Write-Output "✅ Updated Subnet Attributes:"
            foreach ($mod in $modifications) {
                $verifiedValue = switch ($mod.Attribute) {
                    "MapPublicIpOnLaunch" { $updatedSubnet.MapPublicIpOnLaunch }
                    "MapCustomerOwnedIpOnLaunch" { $updatedSubnet.MapCustomerOwnedIpOnLaunch }
                    "CustomerOwnedIpv4Pool" { $updatedSubnet.CustomerOwnedIpv4Pool }
                    "EnableDns64" { $updatedSubnet.EnableDns64 }
                    "EnableResourceNameDnsARecord" { $updatedSubnet.EnableResourceNameDnsARecord }
                    "EnableResourceNameDnsAAAARecord" { $updatedSubnet.EnableResourceNameDnsAAAARecord }
                    "PrivateDnsHostnameType" { $updatedSubnet.PrivateDnsHostnameTypeOnLaunch }
                }

                Write-Output "  $($mod.Attribute): $verifiedValue"

                if ($verifiedValue -eq $mod.NewValue) {
                    Write-Output "    ✅ Successfully updated"
                } else {
                    Write-Warning "    ⚠️  Value may still be propagating"
                }
            }
        }

        Write-Output "`n💡 Post-Modification Notes:"
        Write-Output "• Changes apply to new instances launched after the modification"
        Write-Output "• Existing instances are not affected by these attribute changes"
        Write-Output "• DNS-related changes may take a few minutes to fully propagate"

        if ($hasPublicIpChange) {
            Write-Output "• Review security groups to ensure appropriate access controls"
            Write-Output "• Monitor costs if enabling public IP assignment"
        }

    } else {
        Write-Output "`n✅ DRY RUN: Subnet attribute modifications validated successfully"
        Write-Output "Commands that would be executed:"

        foreach ($mod in $modifications) {
            $commandStr = ($mod.Command + $awsArgs) -join ' '
            Write-Output "aws $commandStr"
        }
    }

} catch {
    Write-Error "Failed to modify subnet attributes: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
