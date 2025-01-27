<#
.SYNOPSIS
    This script registers an AWS Node with the XOAP platform.

.DESCRIPTION
    This script registers an AWS Node with the XOAP platform.
    The script uses the AWS CLI to execute an SSM command on the specified AWS Node.
    The script uses the following AWS CLI command:
    aws ssm send-command --instance-ids $AwsInstanceId --document-name $AwsSsmDocumentName --comment $AwsSsmDocumentComment --parameters commands='["Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://api.dev.xoap.io/dsc/Policy/$XOAPWorkspaceId/Download/$XOAPGroupName'))"]'
    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    AWS CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AwsInstanceId
    Defines the AWS Instance ID.

.PARAMETER AwsSsmDocumentName
    Defines the name of the AWS SSM Document.

.PARAMETER AwsSsmDocumentComment
    Defines the comment for the AWS SSM Document.

.PARAMETER XOAPWorkspaceId
    Defines the XOAP Workspace ID.

.PARAMETER XOAPGroupName
    Defines the XOAP Group Name.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsInstanceId = "myInstanceId",
    [Parameter(Mandatory)]
    [string]$AwsSsmDocumentName = "myDocumentName",
    [Parameter(Mandatory)]
    [string]$AwsSsmDocumentComment = "myDocumentComment",
    [Parameter(Mandatory)]
    [string]$XOAPWorkspaceId = "myWorkspaceId",
    [Parameter(Mandatory)]
    [string]$XOAPGroupName = "XOAP unassigned"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

Send-SSMCommand `
    --instance-ids @($AwsInstanceId) `
    --document-name $AwsSsmDocumentName `
    --comment $AwsSsmDocumentComment `
    --parameters @{'commands'=@('"Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(\"https://api.dev.xoap.io/dsc/Policy/$XOAPWorkspaceId/Download/$XOAPGroupName\"))"')}
