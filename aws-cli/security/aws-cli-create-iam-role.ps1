<#
.SYNOPSIS
    Creates an AWS IAM role with a trust policy document.

.DESCRIPTION
    This script creates an IAM role using the AWS CLI and an assume-role trust
    policy document. The trust policy can be supplied as an inline JSON string
    or as a path to a JSON file on disk. Optionally sets a description, custom
    path, maximum session duration, and resource tags.
    Uses the following AWS CLI commands:
    aws iam create-role
    aws iam tag-role

.PARAMETER RoleName
    The name of the IAM role to create.

.PARAMETER TrustPolicy
    The trust relationship policy document. Accepts an inline JSON string or a
    path to a JSON file containing the policy document.

.PARAMETER Description
    An optional description for the IAM role.

.PARAMETER Path
    The path for the IAM role. Defaults to '/'.

.PARAMETER MaxSessionDuration
    The maximum session duration (in seconds) for the role. Valid range is
    3600–43200. Defaults to 3600.

.PARAMETER Tags
    Optional comma-separated key=value pairs to tag the role, e.g.
    "Env=prod,Team=platform".

.EXAMPLE
    .\aws-cli-create-iam-role.ps1 `
        -RoleName "MyLambdaRole" `
        -TrustPolicy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

.EXAMPLE
    .\aws-cli-create-iam-role.ps1 `
        -RoleName "MyEC2Role" `
        -TrustPolicy ".\trust-policy.json" `
        -Description "Role for EC2 instances" `
        -MaxSessionDuration 7200 `
        -Tags "Env=prod,Team=platform"

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
    https://docs.aws.amazon.com/cli/latest/reference/iam/create-role.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the IAM role to create.")]
    [ValidatePattern('^[\w+=,.@-]{1,64}$')]
    [string]$RoleName,

    [Parameter(Mandatory = $true, HelpMessage = "Inline JSON string or path to a JSON file for the assume-role trust policy.")]
    [ValidateNotNullOrEmpty()]
    [string]$TrustPolicy,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the IAM role.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "The path for the IAM role. Defaults to '/'.")]
    [string]$Path = '/',

    [Parameter(Mandatory = $false, HelpMessage = "Maximum session duration in seconds (3600-43200). Defaults to 3600.")]
    [ValidateRange(3600, 43200)]
    [int]$MaxSessionDuration = 3600,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated Key=Value tag pairs, e.g. 'Env=prod,Team=platform'.")]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Starting IAM role creation: $RoleName" -ForegroundColor Green

    # Resolve trust policy — file path or inline JSON
    if (Test-Path $TrustPolicy -ErrorAction SilentlyContinue) {
        Write-Host "🔍 Loading trust policy from file: $TrustPolicy" -ForegroundColor Cyan
        $policyArg = "file://$((Resolve-Path $TrustPolicy).Path)"
    } else {
        Write-Host "🔍 Using inline trust policy JSON." -ForegroundColor Cyan
        $policyArg = $TrustPolicy
    }

    Write-Host "🔧 Creating IAM role..." -ForegroundColor Cyan

    $createArgs = @(
        'iam', 'create-role',
        '--role-name', $RoleName,
        '--assume-role-policy-document', $policyArg,
        '--path', $Path,
        '--max-session-duration', $MaxSessionDuration,
        '--output', 'json'
    )

    if ($Description) {
        $createArgs += '--description', $Description
    }

    $result = aws @createArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create IAM role: $result"
    }

    $roleData = $result | ConvertFrom-Json

    Write-Host "✅ IAM role created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   RoleName : $($roleData.Role.RoleName)"
    Write-Host "   RoleId   : $($roleData.Role.RoleId)"
    Write-Host "   RoleArn  : $($roleData.Role.Arn)"

    # Apply tags if provided
    if ($Tags) {
        Write-Host "🔧 Applying tags to role..." -ForegroundColor Cyan

        $tagList = $Tags -split ',' | ForEach-Object {
            $kv = $_ -split '=', 2
            "Key=$($kv[0].Trim()),Value=$($kv[1].Trim())"
        }

        $tagResult = aws iam tag-role `
            --role-name $RoleName `
            --tags ($tagList -join ' ') 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Tags could not be applied: $tagResult" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Tags applied successfully." -ForegroundColor Green
        }
    }

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Attach a permissions policy with: aws iam attach-role-policy --role-name $RoleName --policy-arn <PolicyArn>"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
