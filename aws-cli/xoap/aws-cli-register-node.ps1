<#
.SYNOPSIS
    Registers an AWS Node with the XOAP platform.

.DESCRIPTION
    This script registers an AWS Node with the XOAP platform using the AWS CLI.
    The script executes an SSM command on the specified AWS instance to download
    and invoke the XOAP DSC policy configuration.
    Uses the following AWS CLI command:
    aws ssm send-command

.PARAMETER AwsInstanceId
    The AWS EC2 Instance ID of the node to register.

.PARAMETER AwsSsmDocumentName
    The name of the AWS SSM Document to execute.

.PARAMETER AwsSsmDocumentComment
    The comment for the AWS SSM Document execution.

.PARAMETER XOAPWorkspaceId
    The XOAP Workspace ID used to construct the policy download URL.

.PARAMETER XOAPGroupName
    The XOAP Group Name used to construct the policy download URL.

.EXAMPLE
    .\aws-cli-register-node.ps1 -AwsInstanceId "i-1234567890abcdef0" -AwsSsmDocumentName "AWS-RunPowerShellScript" -AwsSsmDocumentComment "Register XOAP node" -XOAPWorkspaceId "ws-12345678" -XOAPGroupName "MyGroup"

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
    https://docs.aws.amazon.com/cli/latest/reference/ssm/send-command.html

.COMPONENT
    AWS CLI SSM
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS EC2 Instance ID of the node to register")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$AwsInstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the AWS SSM Document to execute")]
    [ValidateNotNullOrEmpty()]
    [string]$AwsSsmDocumentName,

    [Parameter(Mandatory = $true, HelpMessage = "The comment for the AWS SSM Document execution")]
    [ValidateNotNullOrEmpty()]
    [string]$AwsSsmDocumentComment,

    [Parameter(Mandatory = $true, HelpMessage = "The XOAP Workspace ID used to construct the policy download URL")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$XOAPWorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The XOAP Group Name used to construct the policy download URL")]
    [ValidatePattern('^[a-zA-Z0-9._@\- ]{1,64}$')]
    [string]$XOAPGroupName
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $commandString = "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://api.xoap.io/dsc/Policy/$XOAPWorkspaceId/Download/$XOAPGroupName'))"
    aws ssm send-command `
        --instance-ids $AwsInstanceId `
        --document-name $AwsSsmDocumentName `
        --comment $AwsSsmDocumentComment `
        --parameters commands="[$([char]34)$commandString$([char]34)]"
    Write-Host "Successfully registered node $AwsInstanceId with XOAP group $XOAPGroupName in workspace $XOAPWorkspaceId." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
