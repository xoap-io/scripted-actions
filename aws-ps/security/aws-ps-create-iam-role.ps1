<#
.SYNOPSIS
    Creates an IAM role with a trust policy using AWS.Tools.IdentityManagement.

.DESCRIPTION
    This script creates an IAM role using the New-IAMRole cmdlet from
    AWS.Tools.IdentityManagement. A trust policy document (assume-role policy)
    must be provided as a JSON string. Optional tags can be applied to the role.

.PARAMETER RoleName
    The name for the new IAM role (alphanumeric and +=,.@-_ characters, 1-64 chars).

.PARAMETER TrustPolicyDocument
    The JSON string defining which principals are allowed to assume this role
    (the AssumeRolePolicyDocument / trust policy).

.PARAMETER Description
    Optional description for the IAM role.

.PARAMETER Path
    Optional path for the IAM role hierarchy (default: '/').

.PARAMETER MaxSessionDuration
    Maximum session duration in seconds when assuming this role
    (3600-43200, default 3600).

.PARAMETER Tags
    Optional comma-separated key=value pairs to tag the role
    (e.g. "Environment=Production,Project=WebApp").

.EXAMPLE
    .\aws-ps-create-iam-role.ps1 -RoleName "EC2-S3-ReadOnly" -TrustPolicyDocument '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    Creates an IAM role that EC2 instances can assume.

.EXAMPLE
    .\aws-ps-create-iam-role.ps1 -RoleName "Lambda-Execution-Role" -TrustPolicyDocument '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' -Description "Lambda execution role" -MaxSessionDuration 7200 -Tags "Environment=Production,Team=Platform"
    Creates an IAM role for Lambda with a 2-hour session duration and tags.

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
    https://docs.aws.amazon.com/powershell/latest/reference/items/New-IAMRole.html

.COMPONENT
    AWS PowerShell IAM
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name for the new IAM role (alphanumeric and +=,.@-_ characters, 1-64 chars).")]
    [ValidatePattern('^[\w+=,.@-]{1,64}$')]
    [string]$RoleName,

    [Parameter(Mandatory = $true, HelpMessage = "The JSON trust policy document that defines which principals can assume this role.")]
    [ValidateNotNullOrEmpty()]
    [string]$TrustPolicyDocument,

    [Parameter(HelpMessage = "Optional description for the IAM role.")]
    [string]$Description,

    [Parameter(HelpMessage = "Optional IAM path for the role hierarchy (default: '/').")]
    [string]$Path = '/',

    [Parameter(HelpMessage = "Maximum session duration in seconds when assuming this role (3600-43200, default 3600).")]
    [ValidateRange(3600, 43200)]
    [int]$MaxSessionDuration = 3600,

    [Parameter(HelpMessage = "Comma-separated key=value tag pairs to apply to the role (e.g. 'Environment=Production,Project=WebApp').")]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting IAM role creation" -ForegroundColor Green
    Write-Host "🔍 Importing AWS.Tools.IdentityManagement module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.IdentityManagement -ErrorAction Stop

    # Validate trust policy is valid JSON
    Write-Host "🔍 Validating trust policy document..." -ForegroundColor Cyan
    try {
        $null = ConvertFrom-Json $TrustPolicyDocument -ErrorAction Stop
    }
    catch {
        throw "TrustPolicyDocument is not valid JSON: $($_.Exception.Message)"
    }

    # Build tag list
    $iamTags = [System.Collections.Generic.List[Amazon.IdentityManagement.Model.Tag]]::new()
    if ($Tags) {
        foreach ($pair in ($Tags -split ',')) {
            $pair = $pair.Trim()
            if ($pair -match '^(.+)=(.+)$') {
                $tag       = [Amazon.IdentityManagement.Model.Tag]::new()
                $tag.Key   = $Matches[1].Trim()
                $tag.Value = $Matches[2].Trim()
                $iamTags.Add($tag)
                Write-Host "   Tag: $($tag.Key) = $($tag.Value)" -ForegroundColor Gray
            }
        }
    }

    Write-Host "🔧 Creating IAM role '$RoleName'..." -ForegroundColor Cyan
    $createParams = @{
        RoleName                 = $RoleName
        AssumeRolePolicyDocument = $TrustPolicyDocument
        Path                     = $Path
        MaxSessionDuration       = $MaxSessionDuration
    }
    if ($Description) {
        $createParams['Description'] = $Description
    }
    if ($iamTags.Count -gt 0) {
        $createParams['Tag'] = $iamTags
    }

    $role = New-IAMRole @createParams

    Write-Host "✅ IAM role created successfully." -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   RoleArn:  $($role.Arn)" -ForegroundColor White
    Write-Host "   RoleName: $($role.RoleName)" -ForegroundColor White
    Write-Host "   RoleId:   $($role.RoleId)" -ForegroundColor White
    Write-Host "   Path:     $($role.Path)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
