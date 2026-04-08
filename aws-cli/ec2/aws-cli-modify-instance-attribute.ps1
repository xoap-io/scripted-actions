<#
.SYNOPSIS
    Modify EC2 instance attributes using AWS CLI.

.DESCRIPTION
    This script modifies various EC2 instance attributes including instance type, security groups,
    source/destination check, user data, monitoring, and termination protection using AWS CLI.

.PARAMETER InstanceId
    The ID of the EC2 instance to modify.

.PARAMETER InstanceType
    The new instance type for the instance (requires instance to be stopped).

.PARAMETER SecurityGroupIds
    Comma-separated list of security group IDs to assign to the instance.

.PARAMETER SourceDestCheck
    Enable or disable source/destination checking for the instance.

.PARAMETER DisableApiTermination
    Enable or disable termination protection for the instance.

.PARAMETER EnaSupport
    Enable or disable enhanced networking support.

.PARAMETER SriovNetSupport
    Enable or disable SR-IOV networking support.

.PARAMETER UserData
    Base64-encoded user data to assign to the instance.

.PARAMETER UserDataFile
    Path to a file containing user data to assign to the instance.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-modify-instance-attribute.ps1 -InstanceId "i-1234567890abcdef0" -InstanceType "t3.medium"

.EXAMPLE
    .\aws-cli-modify-instance-attribute.ps1 -InstanceId "i-1234567890abcdef0" -SecurityGroupIds "sg-123,sg-456" -DisableApiTermination $true

.EXAMPLE
    .\aws-cli-modify-instance-attribute.ps1 -InstanceId "i-1234567890abcdef0" -UserDataFile "C:\scripts\userdata.txt"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/modify-instance-attribute.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EC2 instance to modify.")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "The new instance type for the instance (requires instance to be stopped).")]
    [ValidateSet('t2.nano','t2.micro','t2.small','t2.medium','t2.large','t2.xlarge','t2.2xlarge',
                't3.nano','t3.micro','t3.small','t3.medium','t3.large','t3.xlarge','t3.2xlarge',
                't3a.nano','t3a.micro','t3a.small','t3a.medium','t3a.large','t3a.xlarge','t3a.2xlarge',
                'm5.large','m5.xlarge','m5.2xlarge','m5.4xlarge','m5.8xlarge','m5.12xlarge','m5.16xlarge','m5.24xlarge',
                'm5a.large','m5a.xlarge','m5a.2xlarge','m5a.4xlarge','m5a.8xlarge','m5a.12xlarge','m5a.16xlarge','m5a.24xlarge',
                'c5.large','c5.xlarge','c5.2xlarge','c5.4xlarge','c5.9xlarge','c5.12xlarge','c5.18xlarge','c5.24xlarge',
                'r5.large','r5.xlarge','r5.2xlarge','r5.4xlarge','r5.8xlarge','r5.12xlarge','r5.16xlarge','r5.24xlarge')]
    [string]$InstanceType,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of security group IDs to assign to the instance.")]
    [string]$SecurityGroupIds,

    [Parameter(Mandatory = $false, HelpMessage = "Enable or disable source/destination checking for the instance.")]
    [bool]$SourceDestCheck,

    [Parameter(Mandatory = $false, HelpMessage = "Enable or disable termination protection for the instance.")]
    [bool]$DisableApiTermination,

    [Parameter(Mandatory = $false, HelpMessage = "Enable or disable enhanced networking support.")]
    [bool]$EnaSupport,

    [Parameter(Mandatory = $false, HelpMessage = "Enable or disable SR-IOV networking support.")]
    [ValidateSet('simple')]
    [string]$SriovNetSupport,

    [Parameter(Mandatory = $false, HelpMessage = "Base64-encoded user data to assign to the instance.")]
    [string]$UserData,

    [Parameter(Mandatory = $false, HelpMessage = "Path to a file containing user data to assign to the instance.")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$UserDataFile,

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

    Write-Output "Modifying instance attributes for: $InstanceId"

    # Check if instance exists and get current state
    Write-Output "Checking instance status..."
    $describeResult = aws ec2 describe-instances --instance-ids $InstanceId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe instance: $describeResult"
    }

    $instanceInfo = $describeResult | ConvertFrom-Json
    $instance = $instanceInfo.Reservations[0].Instances[0]
    $currentState = $instance.State.Name

    Write-Output "Current instance state: $currentState"

    # Modify instance type (requires stopped instance)
    if ($InstanceType) {
        if ($currentState -ne 'stopped') {
            Write-Warning "Instance must be stopped to change instance type. Current state: $currentState"
            Write-Output "Skipping instance type modification."
        }
        else {
            Write-Output "Modifying instance type to: $InstanceType"
            $result = aws ec2 modify-instance-attribute --instance-id $InstanceId --instance-type Value=$InstanceType @awsArgs 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Instance type changed to: $InstanceType"
            } else {
                Write-Warning "Failed to modify instance type: $result"
            }
        }
    }

    # Modify security groups (for instances in VPC)
    if ($SecurityGroupIds) {
        Write-Output "Modifying security groups..."
        $sgArray = $SecurityGroupIds -split ','
        $sgList = ($sgArray | ForEach-Object { $_.Trim() }) -join ' '

        $result = aws ec2 modify-instance-attribute --instance-id $InstanceId --groups $sgList @awsArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Security groups updated: $SecurityGroupIds"
        } else {
            Write-Warning "Failed to modify security groups: $result"
        }
    }

    # Modify source/destination check
    if ($PSBoundParameters.ContainsKey('SourceDestCheck')) {
        Write-Output "Modifying source/destination check to: $SourceDestCheck"
        $result = aws ec2 modify-instance-attribute --instance-id $InstanceId --source-dest-check Value=$($SourceDestCheck.ToString().ToLower()) @awsArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Source/destination check set to: $SourceDestCheck"
        } else {
            Write-Warning "Failed to modify source/destination check: $result"
        }
    }

    # Modify termination protection
    if ($PSBoundParameters.ContainsKey('DisableApiTermination')) {
        Write-Output "Modifying termination protection to: $DisableApiTermination"
        $result = aws ec2 modify-instance-attribute --instance-id $InstanceId --disable-api-termination Value=$($DisableApiTermination.ToString().ToLower()) @awsArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Termination protection set to: $DisableApiTermination"
        } else {
            Write-Warning "Failed to modify termination protection: $result"
        }
    }

    # Modify ENA support
    if ($PSBoundParameters.ContainsKey('EnaSupport')) {
        Write-Output "Modifying ENA support to: $EnaSupport"
        $result = aws ec2 modify-instance-attribute --instance-id $InstanceId --ena-support Value=$($EnaSupport.ToString().ToLower()) @awsArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ ENA support set to: $EnaSupport"
        } else {
            Write-Warning "Failed to modify ENA support: $result"
        }
    }

    # Modify SR-IOV support
    if ($SriovNetSupport) {
        Write-Output "Modifying SR-IOV support to: $SriovNetSupport"
        $result = aws ec2 modify-instance-attribute --instance-id $InstanceId --sriov-net-support Value=$SriovNetSupport @awsArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ SR-IOV support set to: $SriovNetSupport"
        } else {
            Write-Warning "Failed to modify SR-IOV support: $result"
        }
    }

    # Modify user data
    if ($UserData -or $UserDataFile) {
        $userData = $UserData
        if ($UserDataFile) {
            $userData = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content $UserDataFile -Raw)))
        }

        Write-Output "Modifying user data..."
        $result = aws ec2 modify-instance-attribute --instance-id $InstanceId --user-data Value=$userData @awsArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ User data updated successfully"
        } else {
            Write-Warning "Failed to modify user data: $result"
        }
    }

    Write-Output "Instance attribute modification completed for: $InstanceId"

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
