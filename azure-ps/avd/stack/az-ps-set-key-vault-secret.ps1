<#
.SYNOPSIS
    Sets a secret in an Azure Key Vault.

.DESCRIPTION
    This script sets a secret in an Azure Key Vault with the specified parameters.
    Uses the Set-AzKeyVaultSecret cmdlet from the Az.KeyVault module.

.PARAMETER VaultName
    The name of the Azure Key Vault.

.PARAMETER Name
    The name of the secret.

.PARAMETER SecretValue
    The value of the secret as a secure string.

.PARAMETER Disable
    Indicates whether the secret should be disabled.

.PARAMETER Expires
    The expiration date of the secret.

.PARAMETER NotBefore
    The date before which the secret cannot be used.

.PARAMETER ContentType
    The content type of the secret.

.PARAMETER Tags
    A hashtable of tags to apply to the secret.

.EXAMPLE
    .\Set-AzKeyVaultSecret.ps1 -VaultName "MyKeyVault" -Name "MySecret" -SecretValue (ConvertTo-SecureString "MySecretValue" -AsPlainText -Force)

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.KeyVault

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.keyvault/set-azkeyvaultsecret?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Key Vault
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the Azure Key Vault.")]
    [ValidateNotNullOrEmpty()]
    [string]$VaultName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the secret.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The value of the secret as a SecureString.")]
    [ValidateNotNullOrEmpty()]
    [SecureString]$SecretValue,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates whether the secret should be disabled.")]
    [switch]$Disable,

    [Parameter(Mandatory=$false, HelpMessage = "The expiration date of the secret.")]
    [ValidateNotNullOrEmpty()]
    [DateTime]$Expires,

    [Parameter(Mandatory=$false, HelpMessage = "The date before which the secret cannot be used.")]
    [ValidateNotNullOrEmpty()]
    [DateTime]$NotBefore,

    [Parameter(Mandatory=$false, HelpMessage = "The content type of the secret.")]
    [ValidateNotNullOrEmpty()]
    [string]$ContentType,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the secret.")]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Splatting parameters
    $params = @{
        VaultName   = $VaultName
        Name        = $Name
        SecretValue = $SecretValue
    }

    if ($Disable) {
        $params['Disable'] = $true
    }

    if ($Expires) {
        $params['Expires'] = $Expires
    }

    if ($NotBefore) {
        $params['NotBefore'] = $NotBefore
    }

    if ($ContentType) {
        $params['ContentType'] = $ContentType
    }

    if ($Tags) {
        $params['Tag'] = $Tags
    }

    # Set the secret in the Key Vault
    $result = Set-AzKeyVaultSecret @params

    Write-Host "✅ Secret '$Name' set successfully in Key Vault '$VaultName'." -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
