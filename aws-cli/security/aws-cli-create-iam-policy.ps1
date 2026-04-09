<#
.SYNOPSIS
    Creates an AWS managed IAM policy and optionally attaches it to a role or user.

.DESCRIPTION
    This script creates a managed IAM policy using the AWS CLI. The policy
    document can be supplied as an inline JSON string or as a path to a JSON
    file on disk. After creation the policy can optionally be attached to an
    IAM role or IAM user.
    Uses the following AWS CLI commands:
    aws iam create-policy
    aws iam attach-role-policy
    aws iam attach-user-policy

.PARAMETER PolicyName
    The name of the managed IAM policy to create.

.PARAMETER PolicyDocument
    The policy document. Accepts an inline JSON string or a path to a JSON file
    containing the policy document.

.PARAMETER Description
    An optional description for the IAM policy.

.PARAMETER Path
    The path for the IAM policy. Defaults to '/'.

.PARAMETER AttachToRole
    Optional IAM role name to attach the new policy to after creation.

.PARAMETER AttachToUser
    Optional IAM user name to attach the new policy to after creation.

.EXAMPLE
    .\aws-cli-create-iam-policy.ps1 `
        -PolicyName "MyS3ReadPolicy" `
        -PolicyDocument '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:ListBucket"],"Resource":"*"}]}'

.EXAMPLE
    .\aws-cli-create-iam-policy.ps1 `
        -PolicyName "MyEC2Policy" `
        -PolicyDocument ".\ec2-policy.json" `
        -Description "Allows EC2 describe actions" `
        -AttachToRole "MyEC2Role" `
        -AttachToUser "deploy-user"

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
    https://docs.aws.amazon.com/cli/latest/reference/iam/create-policy.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the managed IAM policy to create.")]
    [ValidatePattern('^[\w+=,.@-]{1,128}$')]
    [string]$PolicyName,

    [Parameter(Mandatory = $true, HelpMessage = "Inline JSON string or path to a JSON file for the policy document.")]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyDocument,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the IAM policy.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "The path for the IAM policy. Defaults to '/'.")]
    [string]$Path = '/',

    [Parameter(Mandatory = $false, HelpMessage = "IAM role name to attach the policy to after creation.")]
    [string]$AttachToRole,

    [Parameter(Mandatory = $false, HelpMessage = "IAM user name to attach the policy to after creation.")]
    [string]$AttachToUser
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Starting IAM policy creation: $PolicyName" -ForegroundColor Green

    # Resolve policy document — file path or inline JSON
    if (Test-Path $PolicyDocument -ErrorAction SilentlyContinue) {
        Write-Host "🔍 Loading policy document from file: $PolicyDocument" -ForegroundColor Cyan
        $docArg = "file://$((Resolve-Path $PolicyDocument).Path)"
    } else {
        Write-Host "🔍 Using inline policy document JSON." -ForegroundColor Cyan
        $docArg = $PolicyDocument
    }

    Write-Host "🔧 Creating IAM policy..." -ForegroundColor Cyan

    $createArgs = @(
        'iam', 'create-policy',
        '--policy-name', $PolicyName,
        '--policy-document', $docArg,
        '--path', $Path,
        '--output', 'json'
    )

    if ($Description) {
        $createArgs += '--description', $Description
    }

    $result = aws @createArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create IAM policy: $result"
    }

    $policyData = $result | ConvertFrom-Json

    Write-Host "✅ IAM policy created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   PolicyName : $($policyData.Policy.PolicyName)"
    Write-Host "   PolicyId   : $($policyData.Policy.PolicyId)"
    Write-Host "   PolicyArn  : $($policyData.Policy.Arn)"

    $policyArn = $policyData.Policy.Arn

    # Attach to role if requested
    if ($AttachToRole) {
        Write-Host "🔧 Attaching policy to role: $AttachToRole" -ForegroundColor Cyan
        $attachRoleResult = aws iam attach-role-policy `
            --role-name $AttachToRole `
            --policy-arn $policyArn 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Failed to attach policy to role '$AttachToRole': $attachRoleResult" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Policy attached to role '$AttachToRole'." -ForegroundColor Green
        }
    }

    # Attach to user if requested
    if ($AttachToUser) {
        Write-Host "🔧 Attaching policy to user: $AttachToUser" -ForegroundColor Cyan
        $attachUserResult = aws iam attach-user-policy `
            --user-name $AttachToUser `
            --policy-arn $policyArn 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Failed to attach policy to user '$AttachToUser': $attachUserResult" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Policy attached to user '$AttachToUser'." -ForegroundColor Green
        }
    }

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Attach to additional targets with: aws iam attach-role-policy --role-name <RoleName> --policy-arn $policyArn"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
