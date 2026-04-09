<#
.SYNOPSIS
    Deploy an Azure Virtual Desktop host pool, workspace, and app group via Bicep.

.DESCRIPTION
    This script writes an inline Bicep template to a temporary file and deploys
    an Azure Virtual Desktop (AVD) environment via
    `az deployment group create --template-file`. The template provisions:
    - A host pool (Pooled or Personal, with configurable load balancing)
    - A workspace
    - A desktop application group
    - An association between the workspace and the app group

    The temporary .bicep file is removed in the finally block regardless of
    success or failure.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to deploy into.

.PARAMETER Location
    The Azure region where resources will be deployed (e.g. eastus).

.PARAMETER HostPoolName
    The name of the AVD host pool to create.

.PARAMETER WorkspaceName
    The name of the AVD workspace to create.

.PARAMETER AppGroupName
    The name of the desktop application group. Defaults to "<HostPoolName>-dag".

.PARAMETER HostPoolType
    The type of host pool: Pooled or Personal. Defaults to Pooled.

.PARAMETER LoadBalancerType
    The load balancing algorithm: BreadthFirst, DepthFirst, or Persistent.
    Defaults to BreadthFirst. Use Persistent for Personal host pools.

.PARAMETER MaxSessionLimit
    The maximum number of sessions per session host. Accepts 1-999999.
    Defaults to 10.

.PARAMETER DeploymentName
    The ARM deployment name. Defaults to "<HostPoolName>-deployment-<timestamp>".

.EXAMPLE
    .\bicep-deploy-avd-hostpool.ps1 `
        -ResourceGroupName "rg-avd-prod" `
        -Location "eastus" `
        -HostPoolName "hp-prod-pooled" `
        -WorkspaceName "ws-prod" `
        -HostPoolType "Pooled" `
        -LoadBalancerType "BreadthFirst" `
        -MaxSessionLimit 20

.EXAMPLE
    .\bicep-deploy-avd-hostpool.ps1 `
        -ResourceGroupName "rg-avd-dev" `
        -Location "westeurope" `
        -HostPoolName "hp-dev-personal" `
        -WorkspaceName "ws-dev" `
        -AppGroupName "hp-dev-personal-dag" `
        -HostPoolType "Personal" `
        -LoadBalancerType "Persistent" `
        -MaxSessionLimit 1

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI with Bicep extension (run `az bicep install` to install)

.LINK
    https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/

.COMPONENT
    Azure Bicep

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group to deploy into")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where resources will be deployed (e.g. eastus)")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the AVD host pool to create")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the AVD workspace to create")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the desktop application group (default: <HostPoolName>-dag)")]
    [ValidateNotNullOrEmpty()]
    [string]$AppGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Host pool type: Pooled or Personal (default: Pooled)")]
    [ValidateSet('Pooled', 'Personal')]
    [string]$HostPoolType = 'Pooled',

    [Parameter(Mandatory = $false, HelpMessage = "Load balancing algorithm: BreadthFirst, DepthFirst, or Persistent (default: BreadthFirst)")]
    [ValidateSet('BreadthFirst', 'DepthFirst', 'Persistent')]
    [string]$LoadBalancerType = 'BreadthFirst',

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of sessions per session host (1-999999, default: 10)")]
    [ValidateRange(1, 999999)]
    [int]$MaxSessionLimit = 10,

    [Parameter(Mandatory = $false, HelpMessage = "The ARM deployment name (default: auto-generated with timestamp)")]
    [ValidateNotNullOrEmpty()]
    [string]$DeploymentName
)

$ErrorActionPreference = 'Stop'

if (-not $AppGroupName) { $AppGroupName = "$HostPoolName-dag" }
if (-not $DeploymentName) {
    $DeploymentName = "$HostPoolName-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"
}

$tempBicepFile = $null

try {
    Write-Host "🚀 Starting AVD Host Pool deployment via Bicep" -ForegroundColor Green
    Write-Host "   Host Pool      : $HostPoolName" -ForegroundColor Cyan
    Write-Host "   Workspace      : $WorkspaceName" -ForegroundColor Cyan
    Write-Host "   App Group      : $AppGroupName" -ForegroundColor Cyan
    Write-Host "   Resource Group : $ResourceGroupName" -ForegroundColor Cyan
    Write-Host "   Location       : $Location" -ForegroundColor Cyan
    Write-Host "   Type           : $HostPoolType / $LoadBalancerType" -ForegroundColor Cyan
    Write-Host "   Max Sessions   : $MaxSessionLimit" -ForegroundColor Cyan

    # Validate prerequisites
    Write-Host "`n🔍 Validating prerequisites..." -ForegroundColor Cyan

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI (az) is not installed or not in PATH. Install from https://aka.ms/installazurecliwindows"
    }

    $bicepVersion = az bicep version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Bicep not found — running 'az bicep install'..." -ForegroundColor Yellow
        az bicep install
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Bicep. Run 'az bicep install' manually."
        }
    }
    else {
        Write-Host "✅ Bicep version: $bicepVersion" -ForegroundColor Green
    }

    # Write inline Bicep template to a temp file
    Write-Host "`n🔧 Writing Bicep template to temp file..." -ForegroundColor Cyan

    $bicepTemplate = @"
param hostPoolName string
param workspaceName string
param appGroupName string
param location string
param hostPoolType string
param loadBalancerType string
param maxSessionLimit int

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostPoolName
  location: location
  properties: {
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancerType
    maxSessionLimit: maxSessionLimit
    preferredAppGroupType: 'Desktop'
    startVMOnConnect: false
    validationEnvironment: false
  }
}

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: appGroupName
  location: location
  properties: {
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostPool.id
    friendlyName: '\${appGroupName} Desktop'
    description: 'Desktop application group for \${hostPoolName}'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  properties: {
    applicationGroupReferences: [
      appGroup.id
    ]
    friendlyName: workspaceName
    description: 'AVD Workspace associated with \${hostPoolName}'
  }
}

output hostPoolId string = hostPool.id
output workspaceId string = workspace.id
output appGroupId string = appGroup.id
output registrationInfoExpirationTime string = hostPool.properties.registrationInfo == null ? 'Not configured' : 'See portal'
"@

    $tempBicepFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.bicep'
    Set-Content -Path $tempBicepFile -Value $bicepTemplate -Encoding UTF8
    Write-Host "✅ Bicep template written to: $tempBicepFile" -ForegroundColor Green

    # Deploy via Azure CLI
    Write-Host "`n🔧 Deploying Bicep template..." -ForegroundColor Cyan

    $deployArgs = @(
        'deployment', 'group', 'create',
        '--resource-group', $ResourceGroupName,
        '--name', $DeploymentName,
        '--template-file', $tempBicepFile,
        '--parameters',
        "hostPoolName=$HostPoolName",
        "workspaceName=$WorkspaceName",
        "appGroupName=$AppGroupName",
        "location=$Location",
        "hostPoolType=$HostPoolType",
        "loadBalancerType=$LoadBalancerType",
        "maxSessionLimit=$MaxSessionLimit",
        '--output', 'json'
    )

    $result = az @deployArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed: $result"
    }

    $deploymentOutput = $result | ConvertFrom-Json

    Write-Host "`n✅ Deployment succeeded!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Deployment Name  : $DeploymentName" -ForegroundColor White
    Write-Host "   Provisioning     : $($deploymentOutput.properties.provisioningState)" -ForegroundColor White

    $outputs = $deploymentOutput.properties.outputs
    if ($outputs.hostPoolId) {
        Write-Host "   Host Pool ID     : $($outputs.hostPoolId.value)" -ForegroundColor White
    }
    if ($outputs.workspaceId) {
        Write-Host "   Workspace ID     : $($outputs.workspaceId.value)" -ForegroundColor White
    }
    if ($outputs.appGroupId) {
        Write-Host "   App Group ID     : $($outputs.appGroupId.value)" -ForegroundColor White
    }

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. Add session hosts to the host pool using a VM deployment script" -ForegroundColor White
    Write-Host "   2. Assign users or groups to the app group in Azure AD / Entra ID" -ForegroundColor White
    Write-Host "   3. Generate a registration token: az desktopvirtualization hostpool update ..." -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($tempBicepFile -and (Test-Path $tempBicepFile)) {
        Remove-Item -Path $tempBicepFile -Force
        Write-Host "`n🔧 Cleaned up temp Bicep file" -ForegroundColor Cyan
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
