<#
.SYNOPSIS
    Update an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script updates an Azure Virtual Desktop Host Pool using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER Name
    The name of the Azure Virtual Desktop Host Pool to update.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Add
    Add an object to a list of objects by specifying a path and key value pairs.

.PARAMETER CustomRdpProperty
    Custom RDP property for the host pool.

.PARAMETER Description
    Optional new description for the host pool.

.PARAMETER ForceString
    Replace a string value with another string value. Valid values: '0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes'

.PARAMETER FriendlyName
    Optional new friendly name for the host pool.

.PARAMETER IDs
    One or more resource IDs (space-delimited). When provided, other parameters like Name and ResourceGroup are ignored.

.PARAMETER LoadBalancerType
    Load balancer type for the host pool. Valid values: 'BreadthFirst', 'DepthFirst', 'Persistent'

.PARAMETER MaxSessionLimit
    Maximum session limit for pooled host pools (1-999999).

.PARAMETER PersonalDesktopAssignmentType
    Assignment type for personal host pools. Valid values: 'Automatic', 'Direct'

.PARAMETER PreferredAppGroupType
    Preferred application group type. Valid values: 'Desktop', 'None', 'RailApplications'

.PARAMETER RegistrationInfo
    Registration information for the host pool.

.PARAMETER Remove
    Remove a property or an element from a list.

.PARAMETER Ring
    Ring for the host pool.

.PARAMETER Set
    Update an object by specifying a property path and value to set.

.PARAMETER SsoClientId
    SSO client ID for the host pool.

.PARAMETER SsoClientSecretKeyVaultPath
    SSO client secret key vault path for the host pool.

.PARAMETER SsoSecretType
    SSO secret type for the host pool. Valid values: 'Certificate', 'CertificateInKeyVault', 'SharedKey', 'SharedKeyInKeyVault'

.PARAMETER SsoAdfsAuthority
    SSO ADFS authority for the host pool.

.PARAMETER StartVmOnConnect
    Enable start VM on connect for the host pool.

.PARAMETER ValidationEnvironment
    Mark as validation environment for the host pool.

.PARAMETER VmTemplate
    VM template for the host pool.

.PARAMETER Tags
    Optional tags in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-avd-hostpool-update.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup" -Description "Updated description"

.EXAMPLE
    .\az-cli-avd-hostpool-update.ps1 -Name "MyHostPool" -ResourceGroup "MyRG" -MaxSessionLimit 10 -LoadBalancerType "BreadthFirst"

.EXAMPLE
    .\az-cli-avd-hostpool-update.ps1 -Name "PersonalPool" -ResourceGroup "MyRG" -PersonalDesktopAssignmentType "Automatic" -StartVmOnConnect

.EXAMPLE
    .\az-cli-avd-hostpool-update.ps1 -IDs "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.DesktopVirtualization/hostPools/mypool" -FriendlyName "Updated Pool"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Add,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CustomRdpProperty,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$ForceString,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('BreadthFirst', 'DepthFirst', 'Persistent')]
    [string]$LoadBalancerType,

    [Parameter()]
    [ValidateRange(1, 999999)]
    [int]$MaxSessionLimit,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Automatic', 'Direct')]
    [string]$PersonalDesktopAssignmentType,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Desktop', 'None', 'RailApplications')]
    [string]$PreferredAppGroupType,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationInfo,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Remove,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Ring,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Set,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientSecretKeyVaultPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Certificate', 'CertificateInKeyVault', 'SharedKey', 'SharedKeyInKeyVault')]
    [string]$SsoSecretType,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SsoAdfsAuthority,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$StartVmOnConnect,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$ValidationEnvironment,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$VmTemplate
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
    
    Write-Host "Checking if Host Pool exists..." -ForegroundColor Cyan
    $existingHostPool = az desktopvirtualization hostpool show --name $Name --resource-group $ResourceGroup --output json 2>$null
    if (-not $existingHostPool) {
        throw "Host Pool '$Name' not found in resource group '$ResourceGroup'"
    }
    
    $currentHostPool = $existingHostPool | ConvertFrom-Json
    Write-Host "Found Host Pool: $($currentHostPool.name)" -ForegroundColor Yellow
    Write-Host "  Current Type: $($currentHostPool.hostPoolType)" -ForegroundColor Yellow
    Write-Host "  Current Load Balancer Type: $($currentHostPool.loadBalancerType)" -ForegroundColor Yellow
    Write-Host "  Current Max Session Limit: $($currentHostPool.maxSessionLimit)" -ForegroundColor Yellow
    Write-Host "  Current Description: $($currentHostPool.description)" -ForegroundColor Yellow
    Write-Host "  Current Friendly Name: $($currentHostPool.friendlyName)" -ForegroundColor Yellow
    
    # Check if there are any updates to make
    $hasUpdates = $false
    
    Write-Host "Updating Azure Virtual Desktop Host Pool..." -ForegroundColor Cyan
    
    # Build base command
    $updateParams = @(
        'desktopvirtualization', 'hostpool', 'update',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--output', 'json'
    )
    
    # Add optional parameters if provided
    if ($Add) {
        $updateParams += '--add', $Add
        $hasUpdates = $true
        Write-Host "  Will add: $Add" -ForegroundColor Green
    }
    
    if ($CustomRdpProperty -and $CustomRdpProperty -ne $currentHostPool.customRdpProperty) {
        $updateParams += '--custom-rdp-property', $CustomRdpProperty
        $hasUpdates = $true
        Write-Host "  Will update custom RDP property to: $CustomRdpProperty" -ForegroundColor Green
    }
    
    if ($Description -and $Description -ne $currentHostPool.description) {
        $updateParams += '--description', $Description
        $hasUpdates = $true
        Write-Host "  Will update description to: $Description" -ForegroundColor Green
    }
    
    if ($ForceString) {
        $updateParams += '--force-string', $ForceString
        $hasUpdates = $true
        Write-Host "  Will apply force-string: $ForceString" -ForegroundColor Green
    }
    
    if ($FriendlyName -and $FriendlyName -ne $currentHostPool.friendlyName) {
        $updateParams += '--friendly-name', $FriendlyName
        $hasUpdates = $true
        Write-Host "  Will update friendly name to: $FriendlyName" -ForegroundColor Green
    }
    
    if ($IDs) {
        $updateParams += '--ids', $IDs
        $hasUpdates = $true
        Write-Host "  Will use resource IDs: $IDs" -ForegroundColor Green
    }
    
    if ($LoadBalancerType -and $LoadBalancerType -ne $currentHostPool.loadBalancerType) {
        $updateParams += '--load-balancer-type', $LoadBalancerType
        $hasUpdates = $true
        Write-Host "  Will update load balancer type to: $LoadBalancerType" -ForegroundColor Green
    }
    
    if ($MaxSessionLimit -and $MaxSessionLimit -ne $currentHostPool.maxSessionLimit) {
        $updateParams += '--max-session-limit', $MaxSessionLimit
        $hasUpdates = $true
        Write-Host "  Will update max session limit to: $MaxSessionLimit" -ForegroundColor Green
    }
    
    if ($PersonalDesktopAssignmentType -and $PersonalDesktopAssignmentType -ne $currentHostPool.personalDesktopAssignmentType) {
        $updateParams += '--personal-desktop-assignment-type', $PersonalDesktopAssignmentType
        $hasUpdates = $true
        Write-Host "  Will update personal desktop assignment type to: $PersonalDesktopAssignmentType" -ForegroundColor Green
    }
    
    if ($PreferredAppGroupType -and $PreferredAppGroupType -ne $currentHostPool.preferredAppGroupType) {
        $updateParams += '--preferred-app-group-type', $PreferredAppGroupType
        $hasUpdates = $true
        Write-Host "  Will update preferred app group type to: $PreferredAppGroupType" -ForegroundColor Green
    }
    
    if ($RegistrationInfo) {
        $updateParams += '--registration-info', $RegistrationInfo
        $hasUpdates = $true
        Write-Host "  Will update registration info: $RegistrationInfo" -ForegroundColor Green
    }
    
    if ($Remove) {
        $updateParams += '--remove', $Remove
        $hasUpdates = $true
        Write-Host "  Will remove: $Remove" -ForegroundColor Green
    }
    
    if ($Ring) {
        $updateParams += '--ring', $Ring
        $hasUpdates = $true
        Write-Host "  Will update ring to: $Ring" -ForegroundColor Green
    }
    
    if ($Set) {
        $updateParams += '--set', $Set
        $hasUpdates = $true
        Write-Host "  Will set: $Set" -ForegroundColor Green
    }
    
    if ($SsoClientId) {
        $updateParams += '--sso-client-id', $SsoClientId
        $hasUpdates = $true
        Write-Host "  Will update SSO client ID to: $SsoClientId" -ForegroundColor Green
    }
    
    if ($SsoClientSecretKeyVaultPath) {
        $updateParams += '--sso-client-secret-key-vault-path', $SsoClientSecretKeyVaultPath
        $hasUpdates = $true
        Write-Host "  Will update SSO client secret key vault path to: $SsoClientSecretKeyVaultPath" -ForegroundColor Green
    }
    
    if ($SsoSecretType) {
        $updateParams += '--sso-secret-type', $SsoSecretType
        $hasUpdates = $true
        Write-Host "  Will update SSO secret type to: $SsoSecretType" -ForegroundColor Green
    }
    
    if ($SsoAdfsAuthority) {
        $updateParams += '--ssoadfs-authority', $SsoAdfsAuthority
        $hasUpdates = $true
        Write-Host "  Will update SSO ADFS authority to: $SsoAdfsAuthority" -ForegroundColor Green
    }
    
    if ($StartVmOnConnect) {
        $updateParams += '--start-vm-on-connect', $StartVmOnConnect
        $hasUpdates = $true
        Write-Host "  Will update start VM on connect to: $StartVmOnConnect" -ForegroundColor Green
    }
    
    if ($Tags) {
        $updateParams += '--tags', $Tags
        $hasUpdates = $true
        Write-Host "  Will update tags to: $Tags" -ForegroundColor Green
    }
    
    if ($ValidationEnvironment) {
        $updateParams += '--validation-environment', $ValidationEnvironment
        $hasUpdates = $true
        Write-Host "  Will update validation environment to: $ValidationEnvironment" -ForegroundColor Green
    }
    
    if ($VmTemplate) {
        $updateParams += '--vm-template', $VmTemplate
        $hasUpdates = $true
        Write-Host "  Will update VM template to: $VmTemplate" -ForegroundColor Green
    }
    
    if (-not $hasUpdates) {
        Write-Host "No updates specified or no changes detected" -ForegroundColor Yellow
        exit 0
    }
    
    $result = & az @updateParams
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code: $LASTEXITCODE"
    }
    
    $updatedHostPool = $result | ConvertFrom-Json
    
    Write-Host "Azure Virtual Desktop Host Pool updated successfully:" -ForegroundColor Green
    Write-Host "  Name: $($updatedHostPool.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($updatedHostPool.resourceGroup)" -ForegroundColor White
    Write-Host "  Type: $($updatedHostPool.hostPoolType)" -ForegroundColor White
    Write-Host "  Load Balancer Type: $($updatedHostPool.loadBalancerType)" -ForegroundColor White
    Write-Host "  Max Session Limit: $($updatedHostPool.maxSessionLimit)" -ForegroundColor White
    Write-Host "  Description: $($updatedHostPool.description)" -ForegroundColor White
    Write-Host "  Friendly Name: $($updatedHostPool.friendlyName)" -ForegroundColor White
    Write-Host "  Location: $($updatedHostPool.location)" -ForegroundColor White
    Write-Host "  ID: $($updatedHostPool.id)" -ForegroundColor White
    
    return $updatedHostPool
} catch {
    Write-Error "Failed to update Azure Virtual Desktop Host Pool: $_"
    exit 1
}
