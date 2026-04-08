<#
.SYNOPSIS
    Get detailed status information for EC2 instances using AWS CLI.

.DESCRIPTION
    This script retrieves comprehensive status information for EC2 instances including
    instance status, system status, and reachability checks using AWS CLI.

.PARAMETER InstanceId
    The ID of the EC2 instance to check status for (optional - if not provided, checks all instances).

.PARAMETER IncludeAllInstances
    Include all instances regardless of their status.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.PARAMETER OutputFormat
    The output format for the results.

.EXAMPLE
    .\aws-cli-get-instance-status.ps1 -InstanceId "i-1234567890abcdef0"

.EXAMPLE
    .\aws-cli-get-instance-status.ps1 -IncludeAllInstances -OutputFormat table

.EXAMPLE
    .\aws-cli-get-instance-status.ps1 -Region "us-west-2" -Profile "production"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instance-status.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The ID of the EC2 instance to check status for (optional - if not provided, checks all instances).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "Include all instances regardless of their status.")]
    [switch]$IncludeAllInstances,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use (optional, uses default if not specified).")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use (optional).")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "The output format for the results.")]
    [ValidateSet('json', 'table', 'text')]
    [string]$OutputFormat = 'json'
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

    Write-Output "Retrieving instance status information..."

    # Build describe-instance-status command
    $statusArgs = @('ec2', 'describe-instance-status')
    $statusArgs += $awsArgs
    $statusArgs += @('--output', $OutputFormat)

    if ($InstanceId) {
        Write-Output "Checking status for instance: $InstanceId"
        $statusArgs += @('--instance-ids', $InstanceId)
    }

    if ($IncludeAllInstances) {
        $statusArgs += @('--include-all-instances')
    }

    # Execute the status check
    $result = & aws @statusArgs 2>&1

    if ($LASTEXITCODE -eq 0) {
        if ($OutputFormat -eq 'json') {
            $statusData = $result | ConvertFrom-Json

            Write-Output "`n📊 Instance Status Summary:"
            Write-Output "=" * 50

            if ($statusData.InstanceStatuses.Count -eq 0) {
                Write-Output "No instance status information found."
                if (-not $IncludeAllInstances) {
                    Write-Output "💡 Tip: Use -IncludeAllInstances to see stopped instances."
                }
            } else {
                foreach ($instance in $statusData.InstanceStatuses) {
                    Write-Output "`nInstance ID: $($instance.InstanceId)"
                    Write-Output "Availability Zone: $($instance.AvailabilityZone)"

                    # Instance Status
                    $instanceStatus = $instance.InstanceStatus.Status
                    $instanceStatusIcon = switch ($instanceStatus) {
                        'ok' { '✅' }
                        'impaired' { '❌' }
                        'insufficient-data' { '⚠️' }
                        'not-applicable' { 'ℹ️' }
                        default { '❓' }
                    }
                    Write-Output "Instance Status: $instanceStatusIcon $instanceStatus"

                    if ($instance.InstanceStatus.Details) {
                        foreach ($detail in $instance.InstanceStatus.Details) {
                            Write-Output "  - $($detail.Name): $($detail.Status)"
                        }
                    }

                    # System Status
                    $systemStatus = $instance.SystemStatus.Status
                    $systemStatusIcon = switch ($systemStatus) {
                        'ok' { '✅' }
                        'impaired' { '❌' }
                        'insufficient-data' { '⚠️' }
                        'not-applicable' { 'ℹ️' }
                        default { '❓' }
                    }
                    Write-Output "System Status: $systemStatusIcon $systemStatus"

                    if ($instance.SystemStatus.Details) {
                        foreach ($detail in $instance.SystemStatus.Details) {
                            Write-Output "  - $($detail.Name): $($detail.Status)"
                        }
                    }

                    # Events
                    if ($instance.Events) {
                        Write-Output "📅 Scheduled Events:"
                        foreach ($scheduledEvent in $instance.Events) {
                            Write-Output "  - Code: $($scheduledEvent.Code)"
                            Write-Output "    Description: $($scheduledEvent.Description)"
                            Write-Output "    Not Before: $($scheduledEvent.NotBefore)"
                            Write-Output "    Not After: $($scheduledEvent.NotAfter)"
                        }
                    }

                    Write-Output "-" * 30
                }
            }
        } else {
            # For table and text output, display raw results
            Write-Output $result
        }

        Write-Output "`n✅ Instance status check completed successfully."

    } else {
        throw "Failed to retrieve instance status: $result"
    }

    # Also get basic instance information for context
    if ($InstanceId -and $OutputFormat -eq 'json') {
        Write-Output "`n🔍 Additional Instance Information:"
        Write-Output "=" * 50

        $instanceArgs = @('ec2', 'describe-instances', '--instance-ids', $InstanceId)
        $instanceArgs += $awsArgs
        $instanceArgs += @('--output', 'json')

        $instanceResult = & aws @instanceArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            $instanceData = $instanceResult | ConvertFrom-Json
            $instance = $instanceData.Reservations[0].Instances[0]

            Write-Output "Instance Type: $($instance.InstanceType)"
            Write-Output "State: $($instance.State.Name)"
            Write-Output "Launch Time: $($instance.LaunchTime)"
            Write-Output "Private IP: $($instance.PrivateIpAddress)"

            if ($instance.PublicIpAddress) {
                Write-Output "Public IP: $($instance.PublicIpAddress)"
            }

            if ($instance.Tags) {
                $nameTag = $instance.Tags | Where-Object { $_.Key -eq 'Name' } | Select-Object -First 1
                if ($nameTag) {
                    Write-Output "Name: $($nameTag.Value)"
                }
            }
        }
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
