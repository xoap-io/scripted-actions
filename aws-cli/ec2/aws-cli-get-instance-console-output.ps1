<#
.SYNOPSIS
    Retrieve console output from EC2 instances using AWS CLI.

.DESCRIPTION
    This script retrieves console output from EC2 instances for troubleshooting purposes.
    Console output is helpful for debugging boot issues, kernel problems, and system startup.

.PARAMETER InstanceId
    The ID of the EC2 instance to retrieve console output from.

.PARAMETER Latest
    Retrieve only the latest console output (default behavior).

.PARAMETER OutputFile
    Path to save the console output to a file (optional).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-get-instance-console-output.ps1 -InstanceId "i-1234567890abcdef0"

.EXAMPLE
    .\aws-cli-get-instance-console-output.ps1 -InstanceId "i-1234567890abcdef0" -OutputFile "C:\logs\console-output.txt"

.EXAMPLE
    .\aws-cli-get-instance-console-output.ps1 -InstanceId "i-1234567890abcdef0" -Region "us-west-2"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/get-console-output.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EC2 instance to retrieve console output from.")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "Retrieve only the latest console output (default behavior).")]
    [switch]$Latest,

    [Parameter(Mandatory = $false, HelpMessage = "Path to save the console output to a file (optional).")]
    [string]$OutputFile,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use (optional, uses default if not specified).")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use (optional).")]
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

    Write-Output "Retrieving console output for instance: $InstanceId"

    # Check if instance exists first
    Write-Output "Verifying instance exists..."
    $describeResult = aws ec2 describe-instances --instance-ids $InstanceId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe instance: $describeResult"
    }

    $instanceInfo = $describeResult | ConvertFrom-Json
    $instance = $instanceInfo.Reservations[0].Instances[0]
    $instanceState = $instance.State.Name

    Write-Output "Instance state: $instanceState"
    Write-Output "Instance type: $($instance.InstanceType)"

    # Build console output command
    $consoleArgs = @('ec2', 'get-console-output', '--instance-id', $InstanceId)
    $consoleArgs += $awsArgs

    if ($Latest) {
        $consoleArgs += @('--latest')
    }

    # Execute the console output retrieval
    Write-Output "Retrieving console output..."
    $result = & aws @consoleArgs --output json 2>&1

    if ($LASTEXITCODE -eq 0) {
        $consoleData = $result | ConvertFrom-Json

        if ($consoleData.Output) {
            # Decode the base64 output
            $decodedOutput = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($consoleData.Output))

            Write-Output "`n📄 Console Output for Instance: $InstanceId"
            Write-Output "Timestamp: $($consoleData.Timestamp)"
            Write-Output "=" * 80

            if ($OutputFile) {
                # Save to file
                $decodedOutput | Out-File -FilePath $OutputFile -Encoding UTF8
                Write-Output "✅ Console output saved to: $OutputFile"
                Write-Output "`nFirst 20 lines of console output:"
                $lines = $decodedOutput -split "`n"
                $lines[0..([Math]::Min(19, $lines.Count - 1))] | ForEach-Object { Write-Output $_ }

                if ($lines.Count -gt 20) {
                    Write-Output "..."
                    Write-Output "📄 Complete output saved to file: $OutputFile"
                }
            } else {
                # Display to console
                Write-Output $decodedOutput
            }

            Write-Output "`n=" * 80
            Write-Output "✅ Console output retrieved successfully."

            # Provide helpful information
            $lines = $decodedOutput -split "`n"
            Write-Output "`n📊 Output Summary:"
            Write-Output "Total lines: $($lines.Count)"

            # Check for common issues
            $errors = $lines | Where-Object { $_ -match "error|failed|panic|fatal" -and $_ -notmatch "error.*0" }
            if ($errors) {
                Write-Output "⚠️  Potential errors found:"
                $errors | Select-Object -First 5 | ForEach-Object { Write-Output "  - $_" }
                if ($errors.Count -gt 5) {
                    Write-Output "  ... and $($errors.Count - 5) more error(s)"
                }
            }

            # Check for successful boot indicators
            $bootSuccess = $lines | Where-Object { $_ -match "login:|systemd.*Reached target|cloud-init.*finished|rc.local.*started" }
            if ($bootSuccess) {
                Write-Output "✅ Boot completion indicators found"
            }

        } else {
            Write-Output "ℹ️  No console output available for this instance."
            Write-Output "This could mean:"
            Write-Output "  - Instance is still booting"
            Write-Output "  - Instance type doesn't support console output"
            Write-Output "  - Console output not yet generated"
        }

    } else {
        throw "Failed to retrieve console output: $result"
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
