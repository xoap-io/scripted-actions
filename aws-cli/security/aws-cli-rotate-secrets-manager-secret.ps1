<#
.SYNOPSIS
    Rotates an AWS Secrets Manager secret and optionally configures a rotation schedule.

.DESCRIPTION
    This script rotates an AWS Secrets Manager secret using the AWS CLI. An
    optional Lambda ARN can be provided to configure or update the rotation
    function. A rotation schedule in days can also be set. Use the
    -RotateImmediately switch to trigger an immediate rotation in addition to
    configuring the schedule. The -WhatIf switch previews what would happen
    without making any changes.
    Uses the following AWS CLI commands:
    aws secretsmanager describe-secret
    aws secretsmanager rotate-secret

.PARAMETER Region
    The AWS region where the secret is stored (e.g. us-east-1).

.PARAMETER SecretId
    The name or ARN of the Secrets Manager secret to rotate.

.PARAMETER RotationLambdaArn
    Optional ARN of the Lambda function that performs the rotation. If not
    specified the existing rotation configuration on the secret is used.

.PARAMETER RotationDays
    Optional rotation schedule in days (1-365). Sets an automatic rotation
    schedule on the secret.

.PARAMETER RotateImmediately
    If specified, triggers an immediate rotation in addition to any schedule
    configuration.

.PARAMETER WhatIf
    If specified, displays what the script would do without making changes.

.EXAMPLE
    .\aws-cli-rotate-secrets-manager-secret.ps1 `
        -Region "us-east-1" `
        -SecretId "prod/myapp/dbpassword" `
        -RotateImmediately

.EXAMPLE
    .\aws-cli-rotate-secrets-manager-secret.ps1 `
        -Region "eu-west-1" `
        -SecretId "arn:aws:secretsmanager:eu-west-1:123456789012:secret:my-secret" `
        -RotationLambdaArn "arn:aws:lambda:eu-west-1:123456789012:function:MyRotationFn" `
        -RotationDays 30 `
        -RotateImmediately

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
    https://docs.aws.amazon.com/cli/latest/reference/secretsmanager/rotate-secret.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region where the secret is stored (e.g. us-east-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name or ARN of the Secrets Manager secret to rotate.")]
    [ValidateNotNullOrEmpty()]
    [string]$SecretId,

    [Parameter(Mandatory = $false, HelpMessage = "ARN of the Lambda rotation function. Uses existing config if not specified.")]
    [string]$RotationLambdaArn,

    [Parameter(Mandatory = $false, HelpMessage = "Rotation schedule in days (1-365).")]
    [ValidateRange(1, 365)]
    [int]$RotationDays,

    [Parameter(Mandatory = $false, HelpMessage = "Trigger an immediate rotation.")]
    [switch]$RotateImmediately,

    [Parameter(Mandatory = $false, HelpMessage = "Preview what the script would do without making changes.")]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Inspecting secret: $SecretId (region: $Region)" -ForegroundColor Green

    # Describe the secret first
    $descResult = aws secretsmanager describe-secret `
        --region $Region `
        --secret-id $SecretId `
        --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe secret '$SecretId': $descResult"
    }

    $secretData = $descResult | ConvertFrom-Json

    Write-Host "🔍 Secret found." -ForegroundColor Cyan
    Write-Host "   SecretName      : $($secretData.Name)"
    Write-Host "   RotationEnabled : $($secretData.RotationEnabled)"
    if ($secretData.NextRotationDate) {
        Write-Host "   NextRotationDate: $($secretData.NextRotationDate)"
    }

    # Build rotate-secret arguments
    $rotateArgs = @(
        'secretsmanager', 'rotate-secret',
        '--region', $Region,
        '--secret-id', $SecretId,
        '--output', 'json'
    )

    if ($RotationLambdaArn) {
        $rotateArgs += '--rotation-lambda-arn', $RotationLambdaArn
    }

    if ($RotationDays) {
        $rotateArgs += '--rotation-rules', "AutomaticallyAfterDays=$RotationDays"
    }

    if (-not $RotateImmediately) {
        $rotateArgs += '--no-rotate-immediately'
    }

    if ($WhatIf) {
        Write-Host "ℹ️  WhatIf mode — no changes will be made." -ForegroundColor Yellow
        Write-Host "   Would execute: aws $($rotateArgs -join ' ')"
        exit 0
    }

    Write-Host "🔧 Rotating secret..." -ForegroundColor Cyan

    $rotateResult = aws @rotateArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to rotate secret: $rotateResult"
    }

    $rotateData = $rotateResult | ConvertFrom-Json

    Write-Host "✅ Secret rotation initiated successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   SecretName       : $($rotateData.Name)"
    Write-Host "   VersionId        : $($rotateData.VersionId)"

    # Refresh description for updated rotation info
    $refreshResult = aws secretsmanager describe-secret `
        --region $Region `
        --secret-id $SecretId `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {
        $refreshData = $refreshResult | ConvertFrom-Json
        Write-Host "   RotationEnabled  : $($refreshData.RotationEnabled)"
        if ($refreshData.NextRotationDate) {
            Write-Host "   NextRotationDate : $($refreshData.NextRotationDate)"
        }
    }

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Monitor rotation status with: aws secretsmanager describe-secret --region $Region --secret-id $SecretId"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
