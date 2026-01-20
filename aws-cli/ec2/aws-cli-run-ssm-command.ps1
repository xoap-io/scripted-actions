<#
.SYNOPSIS
    Execute SSM commands on EC2 instances using AWS CLI.

.DESCRIPTION
    This script executes Systems Manager Run Command on EC2 instances with support
    for shell commands, PowerShell, and AWS-managed documents. Includes monitoring
    of command execution status and output retrieval.

.PARAMETER InstanceIds
    Comma-separated list of instance IDs to execute the command on.

.PARAMETER DocumentName
    The SSM document name to execute (default: AWS-RunShellScript for Linux, AWS-RunPowerShellScript for Windows).

.PARAMETER Command
    The command(s) to execute (can be multiple commands separated by semicolons).

.PARAMETER CommandFile
    Path to a file containing the command(s) to execute.

.PARAMETER Parameters
    JSON string of parameters to pass to the SSM document.

.PARAMETER WorkingDirectory
    Working directory for command execution.

.PARAMETER ExecutionTimeout
    Timeout for command execution in seconds (default: 3600).

.PARAMETER OutputS3Bucket
    S3 bucket name to store command output (optional).

.PARAMETER OutputS3KeyPrefix
    S3 key prefix for output files (optional).

.PARAMETER WaitForCompletion
    Wait for command completion and display results.

.PARAMETER MaxWaitTime
    Maximum time to wait for completion in seconds (default: 300).

.PARAMETER Tags
    JSON string of tags to apply to the command execution.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-run-ssm-command.ps1 -InstanceIds "i-1234567890abcdef0" -Command "uptime; df -h"

.EXAMPLE
    .\aws-cli-run-ssm-command.ps1 -InstanceIds "i-123,i-456" -CommandFile "C:\scripts\patch-script.sh" -WaitForCompletion

.EXAMPLE
    .\aws-cli-run-ssm-command.ps1 -InstanceIds "i-1234567890abcdef0" -DocumentName "AWS-UpdateSSMAgent" -WaitForCompletion

.NOTES
    Author: XOAP
    Date: 2025-08-06
    Version: 1.0
    Requires: AWS CLI v2.16+, SSM Agent on target instances

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstanceIds,

    [Parameter(Mandatory = $false)]
    [string]$DocumentName,

    [Parameter(Mandatory = $false)]
    [string]$Command,

    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CommandFile,

    [Parameter(Mandatory = $false)]
    [string]$Parameters,

    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 172800)]
    [int]$ExecutionTimeout = 3600,

    [Parameter(Mandatory = $false)]
    [string]$OutputS3Bucket,

    [Parameter(Mandatory = $false)]
    [string]$OutputS3KeyPrefix,

    [Parameter(Mandatory = $false)]
    [switch]$WaitForCompletion,

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 3600)]
    [int]$MaxWaitTime = 300,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

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

    # Parse instance IDs
    $instanceList = $InstanceIds -split ',' | ForEach-Object { $_.Trim() }
    Write-Output "Target instances ($($instanceList.Count)): $($instanceList -join ', ')"

    # Validate instances exist and are accessible
    Write-Output "Validating instances..."
    foreach ($instanceId in $instanceList) {
        if ($instanceId -notmatch '^i-[a-zA-Z0-9]{8,}$') {
            throw "Invalid instance ID format: $instanceId"
        }

        $instanceCheck = aws ec2 describe-instances --instance-ids $instanceId @awsArgs --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Instance $instanceId not found or not accessible: $instanceCheck"
        }
    }

    # Determine command to execute
    $commandToExecute = $Command
    if ($CommandFile) {
        if (Test-Path $CommandFile) {
            $commandToExecute = Get-Content $CommandFile -Raw
            Write-Output "Command loaded from file: $CommandFile"
        } else {
            throw "Command file not found: $CommandFile"
        }
    }

    if (-not $commandToExecute -and -not $Parameters) {
        throw "Either Command, CommandFile, or Parameters must be specified."
    }

    # Determine document name if not specified
    if (-not $DocumentName) {
        # Default to shell script document
        $DocumentName = "AWS-RunShellScript"
        Write-Output "Using default document: $DocumentName"
    }

    # Build parameters
    $ssmParameters = @{}

    if ($commandToExecute) {
        # Split commands by semicolon or newline
        $commandArray = $commandToExecute -split '[;\n]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $ssmParameters.commands = $commandArray
    }

    if ($WorkingDirectory) {
        $ssmParameters.workingDirectory = @($WorkingDirectory)
    }

    if ($ExecutionTimeout) {
        $ssmParameters.executionTimeout = @($ExecutionTimeout.ToString())
    }

    # Override with custom parameters if provided
    if ($Parameters) {
        try {
            $customParams = $Parameters | ConvertFrom-Json
            foreach ($key in $customParams.PSObject.Properties.Name) {
                $ssmParameters[$key] = $customParams.$key
            }
        } catch {
            throw "Invalid JSON format for Parameters: $($_.Exception.Message)"
        }
    }

    # Build send-command arguments
    $sendCommandArgs = @('ssm', 'send-command', '--document-name', $DocumentName)
    $sendCommandArgs += @('--instance-ids')
    $sendCommandArgs += $instanceList
    $sendCommandArgs += $awsArgs

    if ($ssmParameters.Count -gt 0) {
        $parametersJson = $ssmParameters | ConvertTo-Json -Depth 5 -Compress
        $sendCommandArgs += @('--parameters', $parametersJson)
    }

    if ($OutputS3Bucket) {
        $s3Config = @{
            S3BucketName = $OutputS3Bucket
        }
        if ($OutputS3KeyPrefix) {
            $s3Config.S3KeyPrefix = $OutputS3KeyPrefix
        }
        $s3Json = $s3Config | ConvertTo-Json -Compress
        $sendCommandArgs += @('--output-s3-location', $s3Json)
    }

    if ($Tags) {
        $sendCommandArgs += @('--tags', $Tags)
    }

    $sendCommandArgs += @('--output', 'json')

    # Display command information
    Write-Output "`n🚀 Executing SSM command:"
    Write-Output "Document: $DocumentName"
    Write-Output "Target instances: $($instanceList.Count)"
    if ($commandToExecute) {
        Write-Output "Commands to execute:"
        $commandArray | ForEach-Object { Write-Output "  $_" }
    }
    if ($WorkingDirectory) { Write-Output "Working directory: $WorkingDirectory" }
    Write-Output "Execution timeout: $ExecutionTimeout seconds"

    # Execute the command
    $result = & aws @sendCommandArgs 2>&1

    if ($LASTEXITCODE -eq 0) {
        $commandData = $result | ConvertFrom-Json
        $commandId = $commandData.Command.CommandId

        Write-Output "`n✅ Command sent successfully!"
        Write-Output "Command ID: $commandId"
        Write-Output "Status: $($commandData.Command.Status)"
        Write-Output "Requested DateTime: $($commandData.Command.RequestedDateTime)"

        if ($WaitForCompletion) {
            Write-Output "`n⏳ Waiting for command completion..."

            $waitTime = 0
            $checkInterval = 10

            do {
                Start-Sleep -Seconds $checkInterval
                $waitTime += $checkInterval

                # Check command status
                $statusResult = aws ssm get-command-invocation --command-id $commandId --instance-id $instanceList[0] @awsArgs --output json 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $statusData = $statusResult | ConvertFrom-Json
                    $status = $statusData.Status

                    Write-Output "[$([math]::Round($waitTime/60, 1)) min] Command status: $status"

                    if ($status -eq 'Success' -or $status -eq 'Failed' -or $status -eq 'Cancelled' -or $status -eq 'TimedOut') {
                        break
                    }
                } else {
                    Write-Output "[$([math]::Round($waitTime/60, 1)) min] Checking status..."
                }

            } while ($waitTime -lt $MaxWaitTime)

            # Get final results for all instances
            Write-Output "`n📊 Command Results:"
            Write-Output "=" * 80

            foreach ($instanceId in $instanceList) {
                Write-Output "`nInstance: $instanceId"
                Write-Output "-" * 40

                $invocationResult = aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId @awsArgs --output json 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $invocationData = $invocationResult | ConvertFrom-Json

                    Write-Output "Status: $($invocationData.Status)"
                    Write-Output "Status Details: $($invocationData.StatusDetails)"
                    Write-Output "Start Time: $($invocationData.ExecutionStartDateTime)"
                    Write-Output "End Time: $($invocationData.ExecutionEndDateTime)"

                    if ($invocationData.StandardOutputContent) {
                        Write-Output "`nStandard Output:"
                        Write-Output $invocationData.StandardOutputContent
                    }

                    if ($invocationData.StandardErrorContent) {
                        Write-Output "`nStandard Error:"
                        Write-Output $invocationData.StandardErrorContent
                    }

                } else {
                    Write-Warning "Failed to get command invocation for $instanceId : $invocationResult"
                }
            }

            if ($waitTime -ge $MaxWaitTime) {
                Write-Warning "`nCommand execution monitoring timed out after $MaxWaitTime seconds."
                Write-Output "Command may still be running. Check status with:"
                Write-Output "aws ssm get-command-invocation --command-id $commandId --instance-id <instance-id>"
            }
        } else {
            Write-Output "`n💡 To check command status later, use:"
            Write-Output "aws ssm get-command-invocation --command-id $commandId --instance-id <instance-id>"
            Write-Output ""
            Write-Output "To list all commands:"
            Write-Output "aws ssm list-commands --command-id $commandId"
        }

    } else {
        throw "Failed to send SSM command: $result"
    }

} catch {
    Write-Error "Failed to execute SSM command: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
