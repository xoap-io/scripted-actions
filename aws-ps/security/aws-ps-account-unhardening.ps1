<#
.SYNOPSIS
    Reverts AWS account hardening actions performed by aws-ps-account-hardening.ps1.

.DESCRIPTION
    This script disables, deletes, or resets to default all resources and settings created or modified by the hardening script.
    Uses AWS CLI commands invoked via PowerShell. Use switches to control which resources or settings to revert.
    Intended for lab, test, or teardown scenarios only. Use with caution in production environments.

.PARAMETER Region
    AWS region to target for resource changes.

.PARAMETER AwsCliProfile
    AWS CLI profile to use for authentication.

.PARAMETER RemoveCloudTrail
    Switch to remove CloudTrail trails.

.PARAMETER RemoveGuardDuty
    Switch to disable GuardDuty.

.PARAMETER RemoveSecurityHub
    Switch to disable Security Hub.

.PARAMETER RemoveConfigRecorder
    Switch to delete AWS Config recorders.

.PARAMETER RemoveS3BucketPolicies
    Switch to remove S3 bucket policies.

.PARAMETER RemoveIAMPasswordPolicy
    Switch to reset IAM password policy to AWS default.

.PARAMETER RemoveVPCFlowLogs
    Switch to delete VPC Flow Logs.

.PARAMETER RemoveSSMSettings
    Switch to reset SSM settings.

.PARAMETER RemoveAccountAlias
    Switch to remove account alias.

.PARAMETER RemoveDefaultTags
    Switch to remove default resource tags.

.EXAMPLE
    .\aws-ps-account-unhardening.ps1 -Region 'us-east-1' -AwsCliProfile 'default' -RemoveCloudTrail -RemoveGuardDuty

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI (invoked via PowerShell)

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell Security
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "AWS region to target for resource changes (e.g. us-east-1).")]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "AWS CLI profile to use for authentication.")]
    [string]$AwsCliProfile,

    [Parameter(HelpMessage = "Switch to remove CloudTrail trails.")]
    [switch]$RemoveCloudTrail,

    [Parameter(HelpMessage = "Switch to disable GuardDuty.")]
    [switch]$RemoveGuardDuty,

    [Parameter(HelpMessage = "Switch to disable Security Hub.")]
    [switch]$RemoveSecurityHub,

    [Parameter(HelpMessage = "Switch to delete AWS Config recorders.")]
    [switch]$RemoveConfigRecorder,

    [Parameter(HelpMessage = "Switch to remove S3 bucket policies.")]
    [switch]$RemoveS3BucketPolicies,

    [Parameter(HelpMessage = "Switch to reset IAM password policy to AWS default.")]
    [switch]$RemoveIAMPasswordPolicy,

    [Parameter(HelpMessage = "Switch to delete VPC Flow Logs.")]
    [switch]$RemoveVPCFlowLogs,

    [Parameter(HelpMessage = "Switch to reset SSM settings.")]
    [switch]$RemoveSSMSettings,

    [Parameter(HelpMessage = "Switch to remove account alias.")]
    [switch]$RemoveAccountAlias,

    [Parameter(HelpMessage = "Switch to remove default resource tags.")]
    [switch]$RemoveDefaultTags
)

$ErrorActionPreference = 'Stop'

$LogFile = "aws-account-unhardening.log"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $entry = "$timestamp [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    if ($Level -eq 'ERROR') {
        Write-Error $Message
    } elseif ($Level -eq 'WARN') {
        Write-Warning $Message
    } else {
        Write-Host $Message
    }
}

function Invoke-Safe {
    param (
        [scriptblock]$Script,
        [string]$Action
    )
    try {
        & $Script
        Write-Log "$Action succeeded." 'INFO'
    } catch {
        Write-Log "$Action failed: $_" 'ERROR'
    }
}

function Remove-CloudTrail {
    Write-Log "Removing CloudTrails..." 'INFO'
    Invoke-Safe {
        $trails = aws cloudtrail describe-trails --region $Region --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($trail in $trails.trailList) {
            aws cloudtrail delete-trail --name $trail.Name --region $Region --profile $AwsCliProfile
        }
    } 'Remove-CloudTrail'
}


function Remove-GuardDuty {
    Write-Log "Disabling GuardDuty..." 'INFO'
    Invoke-Safe {
        $detectors = aws guardduty list-detectors --region $Region --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($detectorId in $detectors.DetectorIds) {
            aws guardduty delete-detector --detector-id $detectorId --region $Region --profile $AwsCliProfile
        }
    } 'Remove-GuardDuty'
}


function Remove-SecurityHub {
    Write-Log "Disabling Security Hub..." 'INFO'
    Invoke-Safe {
        aws securityhub disable-security-hub --region $Region --profile $AwsCliProfile
    } 'Remove-SecurityHub'
}


function Remove-ConfigRecorder {
    Write-Log "Deleting AWS Config Recorder..." 'INFO'
    Invoke-Safe {
        $recorders = aws configservice describe-configuration-recorders --region $Region --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($recorder in $recorders.ConfigurationRecorders) {
            aws configservice delete-configuration-recorder --configuration-recorder-name $recorder.name --region $Region --profile $AwsCliProfile
        }
    } 'Remove-ConfigRecorder'
}


function Remove-S3BucketPolicies {
    Write-Log "Removing S3 bucket policies..." 'INFO'
    Invoke-Safe {
        $buckets = aws s3api list-buckets --region $Region --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($bucket in $buckets.Buckets) {
            aws s3api delete-bucket-policy --bucket $bucket.Name --region $Region --profile $AwsCliProfile
        }
    } 'Remove-S3BucketPolicies'
}


function Remove-IAMPasswordPolicy {
    Write-Log "Resetting IAM password policy to AWS default..." 'INFO'
    Invoke-Safe {
        aws iam delete-account-password-policy --profile $AwsCliProfile
    } 'Remove-IAMPasswordPolicy'
}


function Remove-VPCFlowLogs {
    Write-Log "Deleting VPC Flow Logs..." 'INFO'
    Invoke-Safe {
        $vpcs = aws ec2 describe-vpcs --region $Region --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($vpc in $vpcs.Vpcs) {
            $logs = aws ec2 describe-flow-logs --filter Name=vpc-id,Values=$vpc.VpcId --region $Region --profile $AwsCliProfile | ConvertFrom-Json
            foreach ($log in $logs.FlowLogs) {
                aws ec2 delete-flow-logs --flow-log-ids $log.FlowLogId --region $Region --profile $AwsCliProfile
            }
        }
    } 'Remove-VPCFlowLogs'
}


function Remove-SSMSettings {
    Write-Log "Resetting SSM settings..." 'INFO'
    Invoke-Safe {
        $docs = aws ssm list-documents --region $Region --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($doc in $docs.DocumentIdentifiers) {
            if ($doc.DocumentType -eq 'Command' -and $doc.Owner -eq 'Self') {
                aws ssm delete-document --name $doc.Name --region $Region --profile $AwsCliProfile
            }
        }
    } 'Remove-SSMSettings'
}


function Remove-AccountAlias {
    Write-Log "Removing account alias..." 'INFO'
    Invoke-Safe {
        $aliases = aws iam list-account-aliases --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($alias in $aliases.AccountAliases) {
            aws iam delete-account-alias --account-alias $alias --profile $AwsCliProfile
        }
    } 'Remove-AccountAlias'
}


function Remove-DefaultTags {
    Write-Log "Removing default tags..." 'INFO'
    Invoke-Safe {
        $tags = aws resourcegroupstaggingapi get-tag-keys --region $Region --profile $AwsCliProfile | ConvertFrom-Json
        foreach ($tagKey in $tags.TagKeys) {
            aws resourcegroupstaggingapi untag-resources --tag-keys $tagKey --region $Region --profile $AwsCliProfile
        }
    } 'Remove-DefaultTags'
}


try {
    if ($RemoveCloudTrail) { Remove-CloudTrail }
    if ($RemoveGuardDuty) { Remove-GuardDuty }
    if ($RemoveSecurityHub) { Remove-SecurityHub }
    if ($RemoveConfigRecorder) { Remove-ConfigRecorder }
    if ($RemoveS3BucketPolicies) { Remove-S3BucketPolicies }
    if ($RemoveIAMPasswordPolicy) { Remove-IAMPasswordPolicy }
    if ($RemoveVPCFlowLogs) { Remove-VPCFlowLogs }
    if ($RemoveSSMSettings) { Remove-SSMSettings }
    if ($RemoveAccountAlias) { Remove-AccountAlias }
    if ($RemoveDefaultTags) { Remove-DefaultTags }
    Write-Log "Account unhardening complete." 'INFO'
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
