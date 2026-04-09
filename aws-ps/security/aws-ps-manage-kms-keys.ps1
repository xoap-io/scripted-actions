<#
.SYNOPSIS
    Creates and manages AWS KMS keys using AWS.Tools.KeyManagementService.

.DESCRIPTION
    This script provides key management operations using AWS KMS cmdlets from
    AWS.Tools.KeyManagementService:
    - Create: New-KMSKey — create a new CMK
    - Describe: Get-KMSKey — describe an existing key
    - List: Get-KMSKeyList — list all keys in the region
    - EnableRotation: Enable-KMSKeyRotation — enable automatic key rotation
    - DisableRotation: Disable-KMSKeyRotation — disable automatic key rotation
    - CreateAlias: New-KMSAlias — create an alias for a key

.PARAMETER Region
    The AWS region to operate in (e.g. eu-central-1).

.PARAMETER Action
    The action to perform: Create, Describe, List, EnableRotation,
    DisableRotation, or CreateAlias (default: Create).

.PARAMETER KeyId
    The KMS key ID or ARN. Required for Describe, EnableRotation,
    DisableRotation, and CreateAlias actions.

.PARAMETER Description
    Optional description for the KMS key when using the Create action.

.PARAMETER KeyUsage
    The intended use of the key: ENCRYPT_DECRYPT (default) or SIGN_VERIFY.

.PARAMETER KeySpec
    The key spec (type) to create: SYMMETRIC_DEFAULT (default), RSA_2048,
    RSA_4096, or ECC_NIST_P256.

.PARAMETER AliasName
    The alias name for CreateAlias action. Must start with 'alias/' and must
    not start with 'alias/aws/'.

.EXAMPLE
    .\aws-ps-manage-kms-keys.ps1 -Region eu-central-1 -Action Create -Description "Application data encryption key"
    Creates a new symmetric KMS key with a description.

.EXAMPLE
    .\aws-ps-manage-kms-keys.ps1 -Region us-east-1 -Action CreateAlias -KeyId "1234abcd-12ab-34cd-56ef-1234567890ab" -AliasName "alias/my-app-key"
    Creates an alias for an existing KMS key.

.EXAMPLE
    .\aws-ps-manage-kms-keys.ps1 -Region eu-central-1 -Action EnableRotation -KeyId "1234abcd-12ab-34cd-56ef-1234567890ab"
    Enables automatic annual key rotation for the specified key.

.EXAMPLE
    .\aws-ps-manage-kms-keys.ps1 -Region eu-central-1 -Action List
    Lists all KMS keys in the region.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.KeyManagementService

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/items/New-KMSKey.html

.COMPONENT
    AWS PowerShell KMS
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region to operate in (e.g. eu-central-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(HelpMessage = "The action to perform: Create, Describe, List, EnableRotation, DisableRotation, or CreateAlias (default: Create).")]
    [ValidateSet('Create', 'Describe', 'List', 'EnableRotation', 'DisableRotation', 'CreateAlias')]
    [string]$Action = 'Create',

    [Parameter(HelpMessage = "The KMS key ID or ARN. Required for Describe, EnableRotation, DisableRotation, and CreateAlias actions.")]
    [string]$KeyId,

    [Parameter(HelpMessage = "Optional description for the KMS key (used with Create action).")]
    [string]$Description,

    [Parameter(HelpMessage = "The intended use of the key: ENCRYPT_DECRYPT (default) or SIGN_VERIFY.")]
    [ValidateSet('ENCRYPT_DECRYPT', 'SIGN_VERIFY')]
    [string]$KeyUsage = 'ENCRYPT_DECRYPT',

    [Parameter(HelpMessage = "The key spec to create: SYMMETRIC_DEFAULT (default), RSA_2048, RSA_4096, or ECC_NIST_P256.")]
    [ValidateSet('SYMMETRIC_DEFAULT', 'RSA_2048', 'RSA_4096', 'ECC_NIST_P256')]
    [string]$KeySpec = 'SYMMETRIC_DEFAULT',

    [Parameter(HelpMessage = "The alias name for CreateAlias action. Must start with 'alias/' (e.g. alias/my-app-key).")]
    [string]$AliasName
)

$ErrorActionPreference = 'Stop'

# Validate that KeyId is provided when required
$actionsRequiringKeyId = @('Describe', 'EnableRotation', 'DisableRotation', 'CreateAlias')
if ($Action -in $actionsRequiringKeyId -and -not $KeyId) {
    Write-Host "`n❌ Script failed: -KeyId is required for the '$Action' action." -ForegroundColor Red
    exit 1
}
if ($Action -eq 'CreateAlias' -and -not $AliasName) {
    Write-Host "`n❌ Script failed: -AliasName is required for the 'CreateAlias' action." -ForegroundColor Red
    exit 1
}
if ($Action -eq 'CreateAlias' -and $AliasName -and -not $AliasName.StartsWith('alias/')) {
    Write-Host "`n❌ Script failed: -AliasName must start with 'alias/' (e.g. alias/my-app-key)." -ForegroundColor Red
    exit 1
}

try {
    Write-Host "🚀 Starting KMS key management — Action: $Action" -ForegroundColor Green
    Write-Host "🔍 Importing AWS.Tools.KeyManagementService module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.KeyManagementService -ErrorAction Stop

    switch ($Action) {
        'Create' {
            Write-Host "🔧 Creating KMS key..." -ForegroundColor Cyan
            $createParams = @{
                KeyUsage = $KeyUsage
                KeySpec  = $KeySpec
                Region   = $Region
            }
            if ($Description) {
                $createParams['Description'] = $Description
            }

            $key = New-KMSKey @createParams
            Write-Host "✅ KMS key created successfully." -ForegroundColor Green
            Write-Host "" -ForegroundColor White
            Write-Host "📊 Summary:" -ForegroundColor Blue
            Write-Host "   KeyId:    $($key.KeyMetadata.KeyId)" -ForegroundColor White
            Write-Host "   KeyArn:   $($key.KeyMetadata.Arn)" -ForegroundColor White
            Write-Host "   KeyState: $($key.KeyMetadata.KeyState)" -ForegroundColor White
            Write-Host "   KeyUsage: $($key.KeyMetadata.KeyUsage)" -ForegroundColor White
            Write-Host "   KeySpec:  $($key.KeyMetadata.KeySpec)" -ForegroundColor White
            Write-Host "   Region:   $Region" -ForegroundColor White
        }

        'Describe' {
            Write-Host "🔍 Describing KMS key: $KeyId..." -ForegroundColor Cyan
            $key = Get-KMSKey -KeyId $KeyId -Region $Region
            Write-Host "✅ KMS key details retrieved." -ForegroundColor Green
            Write-Host "" -ForegroundColor White
            Write-Host "📊 Key Details:" -ForegroundColor Blue
            Write-Host "   KeyId:              $($key.KeyMetadata.KeyId)" -ForegroundColor White
            Write-Host "   KeyArn:             $($key.KeyMetadata.Arn)" -ForegroundColor White
            Write-Host "   Description:        $($key.KeyMetadata.Description)" -ForegroundColor White
            Write-Host "   KeyState:           $($key.KeyMetadata.KeyState)" -ForegroundColor White
            Write-Host "   KeyUsage:           $($key.KeyMetadata.KeyUsage)" -ForegroundColor White
            Write-Host "   KeySpec:            $($key.KeyMetadata.KeySpec)" -ForegroundColor White
            Write-Host "   KeyManager:         $($key.KeyMetadata.KeyManager)" -ForegroundColor White
            Write-Host "   CreationDate:       $($key.KeyMetadata.CreationDate)" -ForegroundColor White
            Write-Host "   DeletionDate:       $($key.KeyMetadata.DeletionDate)" -ForegroundColor White
            Write-Host "   MultiRegion:        $($key.KeyMetadata.MultiRegion)" -ForegroundColor White
        }

        'List' {
            Write-Host "🔍 Listing all KMS keys in $Region..." -ForegroundColor Cyan
            $keys = @(Get-KMSKeyList -Region $Region)
            Write-Host "Found $($keys.Count) key(s):" -ForegroundColor Cyan
            foreach ($k in $keys) {
                Write-Host "   • KeyId: $($k.KeyId) | Arn: $($k.KeyArn)" -ForegroundColor White
            }
            Write-Host "✅ Listed $($keys.Count) KMS key(s)." -ForegroundColor Green
        }

        'EnableRotation' {
            Write-Host "🔧 Enabling automatic key rotation for: $KeyId..." -ForegroundColor Cyan
            Enable-KMSKeyRotation -KeyId $KeyId -Region $Region
            Write-Host "✅ Automatic key rotation enabled for $KeyId." -ForegroundColor Green
        }

        'DisableRotation' {
            Write-Host "🔧 Disabling automatic key rotation for: $KeyId..." -ForegroundColor Cyan
            Disable-KMSKeyRotation -KeyId $KeyId -Region $Region
            Write-Host "✅ Automatic key rotation disabled for $KeyId." -ForegroundColor Green
        }

        'CreateAlias' {
            Write-Host "🔧 Creating alias '$AliasName' for key: $KeyId..." -ForegroundColor Cyan
            New-KMSAlias -AliasName $AliasName -TargetKeyId $KeyId -Region $Region
            Write-Host "✅ Alias '$AliasName' created for key $KeyId." -ForegroundColor Green
            Write-Host "" -ForegroundColor White
            Write-Host "📊 Summary:" -ForegroundColor Blue
            Write-Host "   AliasName: $AliasName" -ForegroundColor White
            Write-Host "   TargetKey: $KeyId" -ForegroundColor White
            Write-Host "   Region:    $Region" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
