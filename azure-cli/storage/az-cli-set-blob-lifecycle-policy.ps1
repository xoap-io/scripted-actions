<#
.SYNOPSIS
    Set a lifecycle management policy on an Azure Storage Account using the Azure CLI.

.DESCRIPTION
    This script sets a lifecycle management policy on an Azure Storage Account using the Azure CLI.
    The policy automatically moves blobs through access tiers (Hot -> Cool -> Archive) and
    deletes them after a configurable number of days.
    The script uses the following Azure CLI command:
    az storage account management-policy create --account-name $StorageAccountName --resource-group $ResourceGroupName

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the Storage Account.

.PARAMETER StorageAccountName
    Defines the name of the Azure Storage Account to apply the policy to.

.PARAMETER CoolAfterDays
    Defines the number of days after which blobs are moved to the Cool tier. Default: 30.

.PARAMETER ArchiveAfterDays
    Defines the number of days after which blobs are moved to the Archive tier. Default: 90.

.PARAMETER DeleteAfterDays
    Defines the number of days after which blobs are permanently deleted. Default: 365.

.PARAMETER PolicyName
    Defines the name of the lifecycle policy rule. Default: lifecycle-policy.

.EXAMPLE
    .\az-cli-set-blob-lifecycle-policy.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001"

.EXAMPLE
    .\az-cli-set-blob-lifecycle-policy.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -CoolAfterDays 7 -ArchiveAfterDays 30 -DeleteAfterDays 180 -PolicyName "aggressive-tiering"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/storage/account/management-policy

.COMPONENT
    Azure CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the Storage Account")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Storage Account to apply the lifecycle policy to")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false, HelpMessage = "Number of days after which blobs are moved to Cool tier (1-99999)")]
    [ValidateRange(1, 99999)]
    [int]$CoolAfterDays = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Number of days after which blobs are moved to Archive tier (1-99999)")]
    [ValidateRange(1, 99999)]
    [int]$ArchiveAfterDays = 90,

    [Parameter(Mandatory = $false, HelpMessage = "Number of days after which blobs are permanently deleted (1-99999)")]
    [ValidateRange(1, 99999)]
    [int]$DeleteAfterDays = 365,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the lifecycle policy rule")]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyName = 'lifecycle-policy'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Setting lifecycle management policy on storage account '$StorageAccountName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Validate day thresholds are in logical order
    if ($CoolAfterDays -ge $ArchiveAfterDays) {
        throw "CoolAfterDays ($CoolAfterDays) must be less than ArchiveAfterDays ($ArchiveAfterDays)."
    }
    if ($ArchiveAfterDays -ge $DeleteAfterDays) {
        throw "ArchiveAfterDays ($ArchiveAfterDays) must be less than DeleteAfterDays ($DeleteAfterDays)."
    }

    Write-Host "ℹ️  Policy configuration:" -ForegroundColor Yellow
    Write-Host "   Cool after:    $CoolAfterDays days" -ForegroundColor White
    Write-Host "   Archive after: $ArchiveAfterDays days" -ForegroundColor White
    Write-Host "   Delete after:  $DeleteAfterDays days" -ForegroundColor White

    # Build the lifecycle policy JSON
    $policyJson = @{
        rules = @(
            @{
                name    = $PolicyName
                enabled = $true
                type    = 'Lifecycle'
                definition = @{
                    filters = @{
                        blobTypes = @('blockBlob')
                    }
                    actions = @{
                        baseBlob = @{
                            tierToCool = @{
                                daysAfterModificationGreaterThan = $CoolAfterDays
                            }
                            tierToArchive = @{
                                daysAfterModificationGreaterThan = $ArchiveAfterDays
                            }
                            delete = @{
                                daysAfterModificationGreaterThan = $DeleteAfterDays
                            }
                        }
                    }
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    # Write policy to a temporary file (az CLI requires a file for complex JSON)
    $tempPolicyFile = [System.IO.Path]::GetTempFileName() + '.json'
    $policyJson | Set-Content -Path $tempPolicyFile -Encoding UTF8

    Write-Host "🔧 Applying lifecycle management policy '$PolicyName'..." -ForegroundColor Cyan

    az storage account management-policy create `
        --account-name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --policy $tempPolicyFile

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI management-policy create command failed with exit code $LASTEXITCODE"
    }

    Write-Host "`n✅ Lifecycle policy '$PolicyName' applied to storage account '$StorageAccountName'." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   StorageAccount: $StorageAccountName" -ForegroundColor White
    Write-Host "   PolicyName:     $PolicyName" -ForegroundColor White
    Write-Host "   CoolAfterDays:    $CoolAfterDays" -ForegroundColor White
    Write-Host "   ArchiveAfterDays: $ArchiveAfterDays" -ForegroundColor White
    Write-Host "   DeleteAfterDays:  $DeleteAfterDays" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up temporary policy file
    if ($tempPolicyFile -and (Test-Path $tempPolicyFile)) {
        Remove-Item -Path $tempPolicyFile -Force -ErrorAction SilentlyContinue
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
