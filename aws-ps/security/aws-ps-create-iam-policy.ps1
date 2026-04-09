<#
.SYNOPSIS
    Creates a managed IAM policy and optionally attaches it to a role or user.

.DESCRIPTION
    This script creates a managed IAM policy using the New-IAMPolicy cmdlet from
    AWS.Tools.IdentityManagement. After creation, the policy can optionally be
    attached to an IAM role (Register-IAMRolePolicy) or an IAM user
    (Register-IAMUserPolicy).

.PARAMETER PolicyName
    The name for the new managed IAM policy (1-128 alphanumeric and +=,.@-_ chars).

.PARAMETER PolicyDocument
    The JSON policy document defining the permissions granted by this policy.

.PARAMETER Description
    Optional description for the managed policy.

.PARAMETER Path
    Optional IAM path for the policy hierarchy (default: '/').

.PARAMETER AttachToRole
    Optional IAM role name to attach the policy to after creation.

.PARAMETER AttachToUser
    Optional IAM user name to attach the policy to after creation.

.EXAMPLE
    .\aws-ps-create-iam-policy.ps1 -PolicyName "S3ReadOnly" -PolicyDocument '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:ListBucket"],"Resource":"*"}]}'
    Creates a managed policy granting S3 read-only access.

.EXAMPLE
    .\aws-ps-create-iam-policy.ps1 -PolicyName "EC2FullAccess-Custom" -PolicyDocument '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"ec2:*","Resource":"*"}]}' -Description "Custom EC2 full access policy" -AttachToRole "MyAppRole" -AttachToUser "MyAppUser"
    Creates a policy and attaches it to both a role and a user.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.IdentityManagement

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/items/New-IAMPolicy.html

.COMPONENT
    AWS PowerShell IAM
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name for the new managed IAM policy (1-128 alphanumeric and +=,.@-_ chars).")]
    [ValidatePattern('^[\w+=,.@-]{1,128}$')]
    [string]$PolicyName,

    [Parameter(Mandatory = $true, HelpMessage = "The JSON policy document defining the permissions granted by this policy.")]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyDocument,

    [Parameter(HelpMessage = "Optional description for the managed policy.")]
    [string]$Description,

    [Parameter(HelpMessage = "Optional IAM path for the policy hierarchy (default: '/').")]
    [string]$Path = '/',

    [Parameter(HelpMessage = "Optional IAM role name to attach the policy to after creation.")]
    [string]$AttachToRole,

    [Parameter(HelpMessage = "Optional IAM user name to attach the policy to after creation.")]
    [string]$AttachToUser
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting IAM policy creation" -ForegroundColor Green
    Write-Host "🔍 Importing AWS.Tools.IdentityManagement module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.IdentityManagement -ErrorAction Stop

    # Validate policy document is valid JSON
    Write-Host "🔍 Validating policy document..." -ForegroundColor Cyan
    try {
        $null = ConvertFrom-Json $PolicyDocument -ErrorAction Stop
    }
    catch {
        throw "PolicyDocument is not valid JSON: $($_.Exception.Message)"
    }

    Write-Host "🔧 Creating managed IAM policy '$PolicyName'..." -ForegroundColor Cyan
    $createParams = @{
        PolicyName     = $PolicyName
        PolicyDocument = $PolicyDocument
        Path           = $Path
    }
    if ($Description) {
        $createParams['Description'] = $Description
    }

    $policy = New-IAMPolicy @createParams
    Write-Host "✅ IAM policy created: $($policy.Arn)" -ForegroundColor Green

    # Attach to role if requested
    if ($AttachToRole) {
        Write-Host "🔧 Attaching policy to role '$AttachToRole'..." -ForegroundColor Cyan
        Register-IAMRolePolicy -RoleName $AttachToRole -PolicyArn $policy.Arn
        Write-Host "✅ Policy attached to role '$AttachToRole'." -ForegroundColor Green
    }

    # Attach to user if requested
    if ($AttachToUser) {
        Write-Host "🔧 Attaching policy to user '$AttachToUser'..." -ForegroundColor Cyan
        Register-IAMUserPolicy -UserName $AttachToUser -PolicyArn $policy.Arn
        Write-Host "✅ Policy attached to user '$AttachToUser'." -ForegroundColor Green
    }

    Write-Host "" -ForegroundColor White
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   PolicyArn:  $($policy.Arn)" -ForegroundColor White
    Write-Host "   PolicyName: $($policy.PolicyName)" -ForegroundColor White
    Write-Host "   PolicyId:   $($policy.PolicyId)" -ForegroundColor White
    Write-Host "   Path:       $($policy.Path)" -ForegroundColor White
    if ($AttachToRole) {
        Write-Host "   AttachedToRole: $AttachToRole" -ForegroundColor White
    }
    if ($AttachToUser) {
        Write-Host "   AttachedToUser: $AttachToUser" -ForegroundColor White
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
