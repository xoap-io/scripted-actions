<#
.SYNOPSIS
    Retrieve the registration token for an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script retrieves the registration token for an Azure Virtual Desktop Host Pool using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Host Pool.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER IDs
    One or more resource IDs (space-delimited). When provided, Name and ResourceGroup parameters are ignored.

.EXAMPLE
    .\az-cli-avd-hostpool-retrieve-registration-token.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup"

.EXAMPLE
    .\az-cli-avd-hostpool-retrieve-registration-token.ps1 -IDs "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/hostPools/mypool"

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
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

.COMPONENT
    Azure CLI Virtual Desktop
#>

[CmdletBinding(DefaultParameterSetName='ByName')]
param(
    [Parameter(Mandatory, ParameterSetName='ByName', HelpMessage = "The name of the Azure Virtual Desktop Host Pool")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory, ParameterSetName='ByName', HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory, ParameterSetName='ByID', HelpMessage = "One or more resource IDs (space-delimited). When provided, Name and ResourceGroup parameters are ignored")]
    [ValidateNotNullOrEmpty()]
    [string]$IDs
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating Azure CLI is available..." -ForegroundColor Cyan
    $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
    if (-not $azVersion) {
        throw "Azure CLI is not installed or not available in PATH"
    }

    Write-Host "Checking Azure CLI login status..." -ForegroundColor Cyan
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in to Azure CLI. Please run 'az login' first"
    }
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        Write-Host "Checking if Host Pool exists..." -ForegroundColor Cyan
        $existingHostPool = az desktopvirtualization hostpool show --name $Name --resource-group $ResourceGroup --output json 2>$null
        if (-not $existingHostPool) {
            throw "Host Pool '$Name' not found in resource group '$ResourceGroup'"
        }

        $hostPoolData = $existingHostPool | ConvertFrom-Json
        Write-Host "Found Host Pool: $($hostPoolData.name)" -ForegroundColor Yellow
        Write-Host "  Type: $($hostPoolData.hostPoolType)" -ForegroundColor Yellow
        Write-Host "  Location: $($hostPoolData.location)" -ForegroundColor Yellow

        Write-Host "Retrieving registration token for Host Pool '$Name'..." -ForegroundColor Cyan
        $result = az desktopvirtualization hostpool retrieve-registration-token --name $Name --resource-group $ResourceGroup --output json
    } else {
        Write-Host "Retrieving registration token using resource IDs..." -ForegroundColor Cyan
        $result = az desktopvirtualization hostpool retrieve-registration-token --ids $IDs --output json
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }

    $tokenData = $result | ConvertFrom-Json

    Write-Host "✓ Registration token retrieved successfully!" -ForegroundColor Green
    Write-Host "Registration Token Details:" -ForegroundColor Cyan
    Write-Host "  Token: $($tokenData.token)" -ForegroundColor Green
    Write-Host "  Expiration Time: $($tokenData.expirationTime)" -ForegroundColor White

    # Also display the token prominently for easy copying
    Write-Host "`n" -NoNewline
    Write-Host "REGISTRATION TOKEN (copy this for VM registration):" -ForegroundColor Yellow -BackgroundColor DarkBlue
    Write-Host "$($tokenData.token)" -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host "`n" -NoNewline

    return $tokenData
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
