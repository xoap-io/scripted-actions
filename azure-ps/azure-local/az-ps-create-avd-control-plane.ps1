<#
.SYNOPSIS
    Create the complete AVD control plane (host pool, desktop application group,
    workspace) for session hosts running on Azure Local.

.DESCRIPTION
    This script creates all Azure Virtual Desktop control plane objects needed before
    session hosts on an Azure Local (Azure Stack HCI) cluster can be added:

    1. Host pool (standard management; pooled or personal). Host pools for Azure Local
       session hosts use the same ARM resources as cloud AVD - there is no special
       resource type - but a host pool must not mix Azure and Azure Local session hosts.
    2. Desktop application group bound to the host pool.
    3. Workspace, with the application group registered to it.
    4. Optionally assigns users or groups the "Desktop Virtualization User" role on the
       application group so they can launch the desktop.

    All steps are idempotent: existing objects with the same name are reused.

    Designed for the XOAP Scripted Actions module: no interactive prompts, and the
    Azure context is expected to be pre-established by the scripted action's service
    principal (Connect-AzAccount -ServicePrincipal). The service principal needs the
    Desktop Virtualization Contributor role (and User Access Administrator or
    equivalent if -AssignUserUpns / -AssignGroupObjectIds is used).

    Session hosts are added afterwards with az-ps-deploy-avd-session-hosts.ps1, which
    generates its own registration token.

    Uses Get/New-AzWvdHostPool, Get/New-AzWvdApplicationGroup, Get/New-AzWvdWorkspace,
    Register-AzWvdApplicationGroup and New-AzRoleAssignment.

.PARAMETER ResourceGroupName
    Azure resource group for the AVD control plane objects. Defaults to "AzureLocal"
    (same resource group as the Azure Local instance, matching the LocalBox setup).

.PARAMETER Location
    Azure region for the AVD objects (must be a region where Azure Virtual Desktop
    metadata is available). Defaults to "westeurope".

.PARAMETER HostPoolName
    Name of the AVD host pool to create.

.PARAMETER HostPoolFriendlyName
    Friendly name of the host pool shown to admins. Defaults to the host pool name.

.PARAMETER HostPoolType
    Host pool type: "Pooled" or "Personal". Defaults to "Pooled".

.PARAMETER LoadBalancerType
    Session load balancing for pooled host pools: "BreadthFirst" or "DepthFirst".
    Defaults to "BreadthFirst". For personal host pools "Persistent" is used
    automatically.

.PARAMETER MaxSessionLimit
    Maximum number of concurrent user sessions per session host (pooled host pools).
    Defaults to 10.

.PARAMETER CustomRdpProperty
    Optional custom RDP properties string for the host pool, e.g.
    "audiocapturemode:i:1;camerastoredirect:s:*;". Leave empty to keep service defaults.

.PARAMETER AppGroupName
    Name of the desktop application group. Defaults to "<HostPoolName>-dag".

.PARAMETER WorkspaceName
    Name of the workspace. Defaults to "<HostPoolName>-ws".

.PARAMETER WorkspaceFriendlyName
    Friendly name of the workspace shown to users in their client. Defaults to the
    workspace name.

.PARAMETER AssignUserUpns
    Optional list of user principal names that are granted the "Desktop Virtualization
    User" role on the application group. Failures per user are reported as warnings.

.PARAMETER AssignGroupObjectIds
    Optional list of Entra ID group object IDs (GUIDs) that are granted the "Desktop
    Virtualization User" role on the application group.

.EXAMPLE
    .\az-ps-create-avd-control-plane.ps1 -HostPoolName "hp-azlocal-01"

    Creates the pooled host pool "hp-azlocal-01" with the application group
    "hp-azlocal-01-dag" and workspace "hp-azlocal-01-ws" in resource group "AzureLocal".

.EXAMPLE
    .\az-ps-create-avd-control-plane.ps1 `
        -HostPoolName "hp-azlocal-01" `
        -HostPoolType "Pooled" `
        -MaxSessionLimit 8 `
        -AssignGroupObjectIds @("11111111-2222-3333-4444-555555555555")

    Creates the control plane and lets an Entra ID group launch the desktop.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.DesktopVirtualization, Az.Resources (for role assignments); a connected Azure context (service principal)

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-desktop/azure-local-overview

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/

.COMPONENT
    Azure PowerShell Desktop Virtualization
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group for the AVD control plane objects.")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region for the AVD objects (must support Azure Virtual Desktop metadata).")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    [Parameter(Mandatory = $true, HelpMessage = "Name of the AVD host pool to create.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory = $false, HelpMessage = "Friendly name of the host pool shown to admins. Defaults to the host pool name.")]
    [string]$HostPoolFriendlyName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Host pool type: Pooled or Personal.")]
    [ValidateSet("Pooled", "Personal")]
    [string]$HostPoolType = "Pooled",

    [Parameter(Mandatory = $false, HelpMessage = "Session load balancing for pooled host pools: BreadthFirst or DepthFirst.")]
    [ValidateSet("BreadthFirst", "DepthFirst")]
    [string]$LoadBalancerType = "BreadthFirst",

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of concurrent user sessions per session host (pooled host pools).")]
    [ValidateRange(1, 999)]
    [int]$MaxSessionLimit = 10,

    [Parameter(Mandatory = $false, HelpMessage = "Optional custom RDP properties string for the host pool.")]
    [string]$CustomRdpProperty = "",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the desktop application group. Defaults to '<HostPoolName>-dag'.")]
    [string]$AppGroupName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the workspace. Defaults to '<HostPoolName>-ws'.")]
    [string]$WorkspaceName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Friendly name of the workspace shown to users. Defaults to the workspace name.")]
    [string]$WorkspaceFriendlyName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Optional list of user principal names granted the 'Desktop Virtualization User' role on the application group.")]
    [string[]]$AssignUserUpns = @(),

    [Parameter(Mandatory = $false, HelpMessage = "Optional list of Entra ID group object IDs (GUIDs) granted the 'Desktop Virtualization User' role on the application group.")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string[]]$AssignGroupObjectIds = @()
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Preflight: modules + Azure context
    Write-Host "🚀 Creating AVD control plane for host pool '$HostPoolName'" -ForegroundColor Green

    foreach ($module in @('Az.Accounts', 'Az.DesktopVirtualization')) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            throw "The $module module is not installed. Run: Install-Module $module -Scope CurrentUser"
        }
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. The XOAP Scripted Actions service principal must be connected (Connect-AzAccount -ServicePrincipal) before this script runs."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    if (-not $HostPoolFriendlyName)  { $HostPoolFriendlyName  = $HostPoolName }
    if (-not $AppGroupName)          { $AppGroupName          = "$($HostPoolName)-dag" }
    if (-not $WorkspaceName)         { $WorkspaceName         = "$($HostPoolName)-ws" }
    if (-not $WorkspaceFriendlyName) { $WorkspaceFriendlyName = $WorkspaceName }

    # 1) Host pool
    $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName -ErrorAction SilentlyContinue
    if ($hostPool) {
        Write-Host "ℹ️  Host pool '$HostPoolName' already exists (type: $($hostPool.HostPoolType)) - reusing" -ForegroundColor Yellow
    }
    else {
        Write-Host "🔧 Creating $HostPoolType host pool '$HostPoolName'..." -ForegroundColor Cyan
        $hostPoolParams = @{
            ResourceGroupName     = $ResourceGroupName
            Name                  = $HostPoolName
            Location              = $Location
            HostPoolType          = $HostPoolType
            PreferredAppGroupType = 'Desktop'
            FriendlyName          = $HostPoolFriendlyName
        }
        if ($HostPoolType -eq 'Pooled') {
            $hostPoolParams['LoadBalancerType'] = $LoadBalancerType
            $hostPoolParams['MaxSessionLimit']  = $MaxSessionLimit
        }
        else {
            $hostPoolParams['LoadBalancerType']              = 'Persistent'
            $hostPoolParams['PersonalDesktopAssignmentType'] = 'Automatic'
        }
        if ($CustomRdpProperty) { $hostPoolParams['CustomRdpProperty'] = $CustomRdpProperty }

        $hostPool = New-AzWvdHostPool @hostPoolParams
        Write-Host "✅ Host pool '$HostPoolName' created" -ForegroundColor Green
    }

    # 2) Desktop application group
    $appGroup = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName -Name $AppGroupName -ErrorAction SilentlyContinue
    if ($appGroup) {
        Write-Host "ℹ️  Application group '$AppGroupName' already exists - reusing" -ForegroundColor Yellow
    }
    else {
        Write-Host "🔧 Creating desktop application group '$AppGroupName'..." -ForegroundColor Cyan
        $appGroupParams = @{
            ResourceGroupName    = $ResourceGroupName
            Name                 = $AppGroupName
            Location             = $Location
            HostPoolArmPath      = $hostPool.Id
            ApplicationGroupType = 'Desktop'
            FriendlyName         = "$HostPoolFriendlyName Desktop"
        }
        $appGroup = New-AzWvdApplicationGroup @appGroupParams
        Write-Host "✅ Application group '$AppGroupName' created" -ForegroundColor Green
    }

    # 3) Workspace + application group registration
    $workspace = Get-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName -ErrorAction SilentlyContinue
    if ($workspace) {
        Write-Host "ℹ️  Workspace '$WorkspaceName' already exists - reusing" -ForegroundColor Yellow
    }
    else {
        Write-Host "🔧 Creating workspace '$WorkspaceName'..." -ForegroundColor Cyan
        $workspace = New-AzWvdWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName `
            -Location $Location -FriendlyName $WorkspaceFriendlyName
        Write-Host "✅ Workspace '$WorkspaceName' created" -ForegroundColor Green
    }

    if ($workspace.ApplicationGroupReference -contains $appGroup.Id) {
        Write-Host "ℹ️  Application group already registered to workspace '$WorkspaceName'" -ForegroundColor Yellow
    }
    else {
        Write-Host "🔧 Registering application group to workspace '$WorkspaceName'..." -ForegroundColor Cyan
        $null = Register-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName `
            -WorkspaceName $WorkspaceName -ApplicationGroupPath $appGroup.Id
        Write-Host "✅ Application group registered" -ForegroundColor Green
    }

    # 4) Optional user/group assignments on the application group
    if ($AssignUserUpns.Count -gt 0 -or $AssignGroupObjectIds.Count -gt 0) {
        if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
            throw "The Az.Resources module is required for role assignments. Run: Install-Module Az.Resources -Scope CurrentUser"
        }
        foreach ($upn in $AssignUserUpns) {
            try {
                $null = New-AzRoleAssignment -SignInName $upn -RoleDefinitionName 'Desktop Virtualization User' `
                    -Scope $appGroup.Id -ErrorAction Stop
                Write-Host "✅ Assigned 'Desktop Virtualization User' to user '$upn'" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -match 'already exists') {
                    Write-Host "ℹ️  User '$upn' already assigned" -ForegroundColor Yellow
                }
                else {
                    Write-Host "⚠️  Could not assign user '$($upn)': $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
        foreach ($groupId in $AssignGroupObjectIds) {
            try {
                $null = New-AzRoleAssignment -ObjectId $groupId -RoleDefinitionName 'Desktop Virtualization User' `
                    -Scope $appGroup.Id -ErrorAction Stop
                Write-Host "✅ Assigned 'Desktop Virtualization User' to group '$groupId'" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -match 'already exists') {
                    Write-Host "ℹ️  Group '$groupId' already assigned" -ForegroundColor Yellow
                }
                else {
                    Write-Host "⚠️  Could not assign group '$($groupId)': $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "   Host pool:   $HostPoolName ($HostPoolType)" -ForegroundColor Blue
    Write-Host "   App group:   $AppGroupName" -ForegroundColor Blue
    Write-Host "   Workspace:   $WorkspaceName" -ForegroundColor Blue
    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Add session hosts on Azure Local:" -ForegroundColor Yellow
    Write-Host "   .\az-ps-deploy-avd-session-hosts.ps1 -HostPoolName '$HostPoolName' -NamePrefix '<prefix>' -VmImageName '<image>' ..." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
