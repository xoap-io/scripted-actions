<#
.SYNOPSIS
    Modify security groups attached to EC2 instances using AWS CLI.

.DESCRIPTION
    This script provides functionality to add or remove security groups from EC2 instances
    in VPC environments, with validation and support for bulk operations.

.PARAMETER Action
    The action to perform: Add, Remove, or Replace.

.PARAMETER InstanceId
    The ID of the EC2 instance (for single instance operations).

.PARAMETER InstanceIds
    Comma-separated list of instance IDs (for bulk operations).

.PARAMETER SecurityGroupId
    The security group ID to add or remove (for single security group operations).

.PARAMETER SecurityGroupIds
    Comma-separated list of security group IDs (for multiple security groups).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-modify-instance-security-groups.ps1 -Action Add -InstanceId "i-1234567890abcdef0" -SecurityGroupId "sg-12345678"

.EXAMPLE
    .\aws-cli-modify-instance-security-groups.ps1 -Action Remove -InstanceId "i-1234567890abcdef0" -SecurityGroupId "sg-12345678"

.EXAMPLE
    .\aws-cli-modify-instance-security-groups.ps1 -Action Replace -InstanceId "i-1234567890abcdef0" -SecurityGroupIds "sg-123,sg-456,sg-789"

.EXAMPLE
    .\aws-cli-modify-instance-security-groups.ps1 -Action Add -InstanceIds "i-123,i-456" -SecurityGroupId "sg-12345678"

.NOTES
    Author: XOAP
    Date: 2025-08-06

    Requires: AWS CLI v2.16+
    Note: Only works with VPC instances, not EC2-Classic

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Add', 'Remove', 'Replace')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false)]
    [string]$InstanceIds,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,

    [Parameter(Mandatory = $false)]
    [string]$SecurityGroupIds,

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

    # Determine target instances
    $targetInstances = @()
    if ($InstanceId) {
        $targetInstances += $InstanceId
    }
    if ($InstanceIds) {
        $targetInstances += $InstanceIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($targetInstances.Count -eq 0) {
        throw "Either InstanceId or InstanceIds must be specified."
    }

    # Determine target security groups
    $targetSecurityGroups = @()
    if ($SecurityGroupId) {
        $targetSecurityGroups += $SecurityGroupId
    }
    if ($SecurityGroupIds) {
        $targetSecurityGroups += $SecurityGroupIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($targetSecurityGroups.Count -eq 0) {
        throw "Either SecurityGroupId or SecurityGroupIds must be specified."
    }

    Write-Output "$Action security groups for instances..."
    Write-Output "Target instances ($($targetInstances.Count)): $($targetInstances -join ', ')"
    Write-Output "Target security groups ($($targetSecurityGroups.Count)): $($targetSecurityGroups -join ', ')"

    # Validate security groups exist
    Write-Output "`nValidating security groups..."
    foreach ($sgId in $targetSecurityGroups) {
        $sgCheck = aws ec2 describe-security-groups --group-ids $sgId @awsArgs --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Security group $sgId not found or not accessible: $sgCheck"
        }

        $sgData = $sgCheck | ConvertFrom-Json
        $sg = $sgData.SecurityGroups[0]
        Write-Output "  ✅ $sgId ($($sg.GroupName)) - VPC: $($sg.VpcId)"
    }

    # Process each instance
    foreach ($instanceId in $targetInstances) {
        Write-Output "`n" + "=" * 50
        Write-Output "Processing instance: $instanceId"

        # Get current instance information
        $instanceResult = aws ec2 describe-instances --instance-ids $instanceId @awsArgs --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Instance $instanceId not found or not accessible: $instanceResult"
            continue
        }

        $instanceData = $instanceResult | ConvertFrom-Json
        $instance = $instanceData.Reservations[0].Instances[0]

        # Check if instance is in VPC
        if (-not $instance.VpcId) {
            Write-Warning "Instance $instanceId is not in a VPC. Security group modification only works for VPC instances."
            continue
        }

        Write-Output "Instance VPC: $($instance.VpcId)"
        Write-Output "Instance State: $($instance.State.Name)"

        # Get current security groups
        $currentSecurityGroups = @()
        foreach ($sg in $instance.SecurityGroups) {
            $currentSecurityGroups += $sg.GroupId
        }

        Write-Output "Current security groups: $($currentSecurityGroups -join ', ')"

        # Calculate new security group list based on action
        $newSecurityGroups = @()

        switch ($Action) {
            'Add' {
                $newSecurityGroups = $currentSecurityGroups + $targetSecurityGroups | Sort-Object -Unique
                Write-Output "Adding security groups: $($targetSecurityGroups -join ', ')"
            }
            'Remove' {
                $newSecurityGroups = $currentSecurityGroups | Where-Object { $_ -notin $targetSecurityGroups }
                Write-Output "Removing security groups: $($targetSecurityGroups -join ', ')"

                if ($newSecurityGroups.Count -eq 0) {
                    Write-Warning "Cannot remove all security groups from instance. At least one security group must remain."
                    continue
                }
            }
            'Replace' {
                $newSecurityGroups = $targetSecurityGroups
                Write-Output "Replacing all security groups with: $($targetSecurityGroups -join ', ')"
            }
        }

        Write-Output "New security groups: $($newSecurityGroups -join ', ')"

        # Check if any changes are needed
        $currentSorted = $currentSecurityGroups | Sort-Object
        $newSorted = $newSecurityGroups | Sort-Object

        if (Compare-Object $currentSorted $newSorted) {
            # Apply the changes
            Write-Output "Applying security group changes..."

            $modifyResult = aws ec2 modify-instance-attribute --instance-id $instanceId --groups $newSecurityGroups @awsArgs 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Security groups updated successfully for instance $instanceId"

                # Verify the changes
                Start-Sleep -Seconds 2
                $verifyResult = aws ec2 describe-instances --instance-ids $instanceId @awsArgs --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $verifiedGroups = $verifyResult -split '\s+' | Where-Object { $_ }
                    Write-Output "Verified security groups: $($verifiedGroups -join ', ')"
                }
            } else {
                Write-Warning "Failed to modify security groups for instance $instanceId : $modifyResult"
            }
        } else {
            Write-Output "ℹ️  No changes needed - security groups are already as requested"
        }
    }

    # Summary
    Write-Output "`n" + "=" * 50
    Write-Output "📊 Operation Summary:"
    Write-Output "Action: $Action"
    Write-Output "Instances processed: $($targetInstances.Count)"
    Write-Output "Security groups involved: $($targetSecurityGroups.Count)"

    Write-Output "`n💡 Tips:"
    Write-Output "- Security group changes take effect immediately"
    Write-Output "- Ensure new security groups allow necessary network access"
    Write-Output "- Use 'Replace' action to completely change security group assignments"

    if ($Action -eq 'Remove') {
        Write-Output "- At least one security group must always remain attached to an instance"
    }

    Write-Output "`n✅ Security group modification completed."

} catch {
    Write-Error "Failed to modify instance security groups: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
