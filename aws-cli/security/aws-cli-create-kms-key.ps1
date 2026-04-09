<#
.SYNOPSIS
    Creates an AWS KMS key and optionally creates a key alias and enables rotation.

.DESCRIPTION
    This script creates a KMS customer-managed key using the AWS CLI. After
    creation an optional alias can be registered for the key. For symmetric
    keys automatic key rotation can be enabled with the -EnableRotation switch.
    Uses the following AWS CLI commands:
    aws kms create-key
    aws kms create-alias
    aws kms enable-key-rotation

.PARAMETER Region
    The AWS region in which to create the KMS key (e.g. us-east-1).

.PARAMETER Description
    An optional description for the KMS key.

.PARAMETER KeyUsage
    The cryptographic operation the key will be used for.
    Valid values: ENCRYPT_DECRYPT, SIGN_VERIFY, GENERATE_VERIFY_MAC.
    Defaults to ENCRYPT_DECRYPT.

.PARAMETER KeySpec
    The type of key material to generate.
    Valid values: SYMMETRIC_DEFAULT, RSA_2048, RSA_4096, ECC_NIST_P256, ECC_NIST_P384.
    Defaults to SYMMETRIC_DEFAULT.

.PARAMETER Alias
    Optional alias name to create for the key (e.g. alias/my-key).
    The prefix 'alias/' will be added automatically if not already present.

.PARAMETER EnableRotation
    If specified, enables automatic annual key rotation.
    Only valid for SYMMETRIC_DEFAULT keys.

.PARAMETER Tags
    Optional comma-separated Key=Value tag pairs, e.g. 'Env=prod,Team=platform'.

.EXAMPLE
    .\aws-cli-create-kms-key.ps1 `
        -Region "us-east-1" `
        -Description "Encryption key for application secrets" `
        -Alias "alias/app-secrets" `
        -EnableRotation

.EXAMPLE
    .\aws-cli-create-kms-key.ps1 `
        -Region "eu-west-1" `
        -KeyUsage "SIGN_VERIFY" `
        -KeySpec "RSA_2048" `
        -Alias "signing-key" `
        -Tags "Env=prod,Team=security"

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
    https://docs.aws.amazon.com/cli/latest/reference/kms/create-key.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to create the KMS key (e.g. us-east-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the KMS key.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Cryptographic usage for the key. Defaults to ENCRYPT_DECRYPT.")]
    [ValidateSet('ENCRYPT_DECRYPT', 'SIGN_VERIFY', 'GENERATE_VERIFY_MAC')]
    [string]$KeyUsage = 'ENCRYPT_DECRYPT',

    [Parameter(Mandatory = $false, HelpMessage = "Key material specification. Defaults to SYMMETRIC_DEFAULT.")]
    [ValidateSet('SYMMETRIC_DEFAULT', 'RSA_2048', 'RSA_4096', 'ECC_NIST_P256', 'ECC_NIST_P384')]
    [string]$KeySpec = 'SYMMETRIC_DEFAULT',

    [Parameter(Mandatory = $false, HelpMessage = "Alias name for the key, e.g. 'alias/my-key' or 'my-key'.")]
    [string]$Alias,

    [Parameter(Mandatory = $false, HelpMessage = "Enable automatic annual key rotation (symmetric keys only).")]
    [switch]$EnableRotation,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated Key=Value tag pairs, e.g. 'Env=prod,Team=platform'.")]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Starting KMS key creation in region: $Region" -ForegroundColor Green

    Write-Host "🔧 Creating KMS key..." -ForegroundColor Cyan

    $createArgs = @(
        'kms', 'create-key',
        '--region', $Region,
        '--key-usage', $KeyUsage,
        '--key-spec', $KeySpec,
        '--output', 'json'
    )

    if ($Description) {
        $createArgs += '--description', $Description
    }

    if ($Tags) {
        $tagList = $Tags -split ',' | ForEach-Object {
            $kv = $_ -split '=', 2
            "TagKey=$($kv[0].Trim()),TagValue=$($kv[1].Trim())"
        }
        $createArgs += '--tags', ($tagList -join ' ')
    }

    $result = aws @createArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create KMS key: $result"
    }

    $keyData = $result | ConvertFrom-Json
    $keyId  = $keyData.KeyMetadata.KeyId
    $keyArn = $keyData.KeyMetadata.Arn

    Write-Host "✅ KMS key created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   KeyId  : $keyId"
    Write-Host "   KeyArn : $keyArn"

    # Create alias
    $resolvedAlias = $null
    if ($Alias) {
        if (-not $Alias.StartsWith('alias/')) {
            $Alias = "alias/$Alias"
        }
        Write-Host "🔧 Creating key alias: $Alias" -ForegroundColor Cyan
        $aliasResult = aws kms create-alias `
            --region $Region `
            --alias-name $Alias `
            --target-key-id $keyId 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Failed to create alias: $aliasResult" -ForegroundColor Yellow
        } else {
            $resolvedAlias = $Alias
            Write-Host "   Alias  : $resolvedAlias"
            Write-Host "✅ Alias created successfully." -ForegroundColor Green
        }
    }

    # Enable rotation
    if ($EnableRotation) {
        if ($KeySpec -ne 'SYMMETRIC_DEFAULT') {
            Write-Host "⚠️  Key rotation is only supported for SYMMETRIC_DEFAULT keys. Skipping rotation." -ForegroundColor Yellow
        } else {
            Write-Host "🔧 Enabling automatic key rotation..." -ForegroundColor Cyan
            $rotResult = aws kms enable-key-rotation `
                --region $Region `
                --key-id $keyId 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "⚠️  Failed to enable key rotation: $rotResult" -ForegroundColor Yellow
            } else {
                Write-Host "✅ Automatic key rotation enabled." -ForegroundColor Green
            }
        }
    }

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Grant access with: aws kms create-grant --key-id $keyId --grantee-principal <PrincipalArn> --operations Encrypt Decrypt"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
