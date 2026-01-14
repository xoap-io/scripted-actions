
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Region,
    [Parameter(Mandatory)]
    [Parameter(Mandatory)]
    [string]$AwsCliProfile,[switch]$RemoveCloudTrail,
    [switch]$RemoveGuardDuty,
    [switch]$RemoveSecurityHub,
    [switch]$RemoveConfigRecorder,
    [switch]$RemoveS3BucketPolicies,
    [switch]$RemoveIAMPasswordPolicy,
    [switch]$RemoveVPCFlowLogs,
    [switch]$RemoveSSMSettings,
    [switch]$RemoveAccountAlias,
    [switch]$RemoveDefaultTags
)

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

<#
.SYNOPSIS
    Reverts AWS account hardening actions performed by aws-ps-account-hardening.ps1, with switches for selective removal.
.DESCRIPTION
    This script disables, deletes, or resets to default all resources and settings created or modified by the hardening script. Use switches to control which resources/settings to revert. Intended for lab, test, or teardown scenarios only. Use with caution in production environments.
.PARAMETER Region
    AWS region to target for resource changes.
.PARAMETER Profile
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
    Switch to reset IAM password policy.
.PARAMETER RemoveVPCFlowLogs
    Switch to delete VPC Flow Logs.
.PARAMETER RemoveSSMSettings
    Switch to reset SSM settings.
.PARAMETER RemoveAccountAlias
    Switch to remove account alias.
.PARAMETER RemoveDefaultTags
    Switch to remove default resource tags.
.EXAMPLE
    .\aws-ps-account-unhardening.ps1 -Region 'us-east-1' -Profile 'default' -RemoveCloudTrail -RemoveGuardDuty
#>


[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$Region,
    [Parameter(Mandatory)]
    [string]$Profile,
    [switch]$RemoveCloudTrail,
    [switch]$RemoveGuardDuty,
    [switch]$RemoveSecurityHub,
    [switch]$RemoveConfigRecorder,
    [switch]$RemoveS3BucketPolicies,
    [switch]$RemoveIAMPasswordPolicy,
    [switch]$RemoveVPCFlowLogs,
    [switch]$RemoveSSMSettings,
    [switch]$RemoveAccountAlias,
    [switch]$RemoveDefaultTags
)

$ErrorActionPreference = 'Stop'


function Remove-CloudTrail {
    Write-Log "Removing CloudTrails..." 'INFO'
    Invoke-Safe {
        $trails = aws cloudtrail describe-trails --region $Region --profile $AwsProfile | ConvertFrom-Json
        foreach ($trail in $trails.trailList) {
            aws cloudtrail delete-trail --name $trail.Name --region $Region --profile $AwsProfile
        }
    } 'Remove-CloudTrail'
}


function Remove-GuardDuty {
    Write-Log "Disabling GuardDuty..." 'INFO'
    Invoke-Safe {
        $detectors = aws guardduty list-detectors --region $Region --profile $AwsProfile | ConvertFrom-Json
        foreach ($detectorId in $detectors.DetectorIds) {
            aws guardduty delete-detector --detector-id $detectorId --region $Region --profile $AwsProfile
        }
    } 'Remove-GuardDuty'
}


function Remove-SecurityHub {
    Write-Log "Disabling Security Hub..." 'INFO'
    Invoke-Safe {
        aws securityhub disable-security-hub --region $Region --profile $AwsProfile
    } 'Remove-SecurityHub'
}


function Remove-ConfigRecorder {
    Write-Log "Deleting AWS Config Recorder..." 'INFO'
    Invoke-Safe {
        $recorders = aws configservice describe-configuration-recorders --region $Region --profile $AwsProfile | ConvertFrom-Json
        foreach ($recorder in $recorders.ConfigurationRecorders) {
            aws configservice delete-configuration-recorder --configuration-recorder-name $recorder.name --region $Region --profile $AwsProfile
        }
    } 'Remove-ConfigRecorder'
}


function Remove-S3BucketPolicies {
    Write-Log "Removing S3 bucket policies..." 'INFO'
    Invoke-Safe {
        $buckets = aws s3api list-buckets --region $Region --profile $AwsProfile | ConvertFrom-Json
        foreach ($bucket in $buckets.Buckets) {
            aws s3api delete-bucket-policy --bucket $bucket.Name --region $Region --profile $AwsProfile
        }
    } 'Remove-S3BucketPolicies'
}


function Remove-IAMPasswordPolicy {
    Write-Log "Resetting IAM password policy to AWS default..." 'INFO'
    Invoke-Safe {
        aws iam delete-account-password-policy --profile $AwsProfile
    } 'Remove-IAMPasswordPolicy'
}


function Remove-VPCFlowLogs {
    Write-Log "Deleting VPC Flow Logs..." 'INFO'
    Invoke-Safe {
        $vpcs = aws ec2 describe-vpcs --region $Region --profile $AwsProfile | ConvertFrom-Json
        foreach ($vpc in $vpcs.Vpcs) {
            $logs = aws ec2 describe-flow-logs --filter Name=vpc-id,Values=$vpc.VpcId --region $Region --profile $AwsProfile | ConvertFrom-Json
            foreach ($log in $logs.FlowLogs) {
                aws ec2 delete-flow-logs --flow-log-ids $log.FlowLogId --region $Region --profile $AwsProfile
            }
        }
    } 'Remove-VPCFlowLogs'
}


function Remove-SSMSettings {
    Write-Log "Resetting SSM settings..." 'INFO'
    Invoke-Safe {
        $docs = aws ssm list-documents --region $Region --profile $AwsProfile | ConvertFrom-Json
        foreach ($doc in $docs.DocumentIdentifiers) {
            if ($doc.DocumentType -eq 'Command' -and $doc.Owner -eq 'Self') {
                aws ssm delete-document --name $doc.Name --region $Region --profile $AwsProfile
            }
        }
    } 'Remove-SSMSettings'
}


function Remove-AccountAlias {
    Write-Log "Removing account alias..." 'INFO'
    Invoke-Safe {
        $aliases = aws iam list-account-aliases --profile $AwsProfile | ConvertFrom-Json
        foreach ($alias in $aliases.AccountAliases) {
            aws iam delete-account-alias --account-alias $alias --profile $AwsProfile
        }
    } 'Remove-AccountAlias'
}


function Remove-DefaultTags {
    Write-Log "Removing default tags..." 'INFO'
    Invoke-Safe {
        $tags = aws resourcegroupstaggingapi get-tag-keys --region $Region --profile $AwsProfile | ConvertFrom-Json
        foreach ($tagKey in $tags.TagKeys) {
            aws resourcegroupstaggingapi untag-resources --tag-keys $tagKey --region $Region --profile $AwsProfile
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
} catch {
    Write-Log "Unhardening failed: $_" 'ERROR'
}
