<#
.SYNOPSIS
    Sets a secret in an Azure Key Vault.

.DESCRIPTION
    This script sets a secret in an Azure Key Vault with the specified parameters.

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

.PARAMETER Tag
    A hashtable of tags to apply to the secret.

.EXAMPLE
    .\Set-AzKeyVaultSecret.ps1 -VaultName "MyKeyVault" -Name "MySecret" -SecretValue (ConvertTo-SecureString "MySecretValue" -AsPlainText -Force)

.NOTES
    Author: Your Name
    Date:   2024-09-30
    Version: 1.0
    Requires: Az.KeyVault module

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.keyvault

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.keyvault/set-azkeyvaultsecret?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$VaultName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$SecretValue,

    [Parameter(Mandatory=$false)]
    [switch]$Disable,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [DateTime]$Expires,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [DateTime]$NotBefore,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ContentType,

    [Parameter(Mandatory=$false)]
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
        $params['Disable', $true
    }

    if ($Expires) {
        $params['Expires', $Expires
    }

    if ($NotBefore) {
        $params['NotBefore', $NotBefore
    }

    if ($ContentType) {
        $params['ContentType', $ContentType
    }

    if ($Tags) {
        $params['Tag', $Tags
    }

    # Set the secret in the Key Vault
    Set-AzKeyVaultSecret @params
    Write-Host "Secret '$Name' set successfully in Key Vault '$VaultName'."
}
catch {
    Write-Error "An error occurred while setting the secret: $_"
}
