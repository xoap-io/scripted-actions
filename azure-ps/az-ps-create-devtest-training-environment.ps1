<#
.SYNOPSIS
    Creates a complete Azure DevTest Labs training environment with multiple VMs and user access.

.DESCRIPTION
    Automates a comprehensive training environment using Azure DevTest Labs.
    Includes lab+VNet+NAT, subnet enablement for VM creation, policies, jumphost-first pattern,
    and validation/diagnostics for the external VNet default subnet and DTL lab VNets.

    Key points:
    - Removes $schema fields from ARM TemplateObjects to avoid “Variable reference is not valid … ':' … ${}” preprocessing errors
    - Precomputed resource IDs (no ARM [resourceId()] with $variables)
    - Subnet/NAT checks & DTL subnetOverrides(useInVmCreation) validation
    - Start/Stop actions via Invoke-AzResourceAction
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9-]{3,50}$')][string]$LabName,
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9-_.()]{1,90}$')][string]$ResourceGroupName,
    [Parameter(Mandatory)]
    [ValidateSet('East US','East US 2','West US','West US 2','Central US','North Central US','South Central US','West Central US','Canada Central','Canada East','North Europe','West Europe','UK South','UK West','Germany West Central','Switzerland North','France Central','Australia East','Australia Southeast','Japan East','Japan West','Korea Central','South India','Central India','East Asia','Southeast Asia')]
    [string]$Location = 'Germany West Central',

    [string[]]$TrainingUserEmails = @(),
    [string[]]$InstructorEmails   = @(),

    [ValidateRange(1,20)][int]$StudentCount = 5,
    [bool]$IncludeTrainer = $true,
    [bool]$UseJumphost    = $true,
    [ValidateSet('Standard_B2s','Standard_B2ms','Standard_D2s_v3','Standard_D4s_v3')][string]$JumphostSize = 'Standard_B2ms',

    [ValidateRange(0,50)][int]$WindowsVMCount = 0,

    [ValidateSet('Standard_B1s','Standard_B2s','Standard_B2ms','Standard_D2s_v3','Standard_D4s_v3','Standard_E2s_v3')][string]$VMSize = 'Standard_B2s',
    [bool]$AllowPublicIP = $true,

    [ValidatePattern('^([01]?[0-9]|2[0-3])[0-5][0-9]$')][string]$AutoShutdownTime = '1800',
    [ValidatePattern('^([01]?[0-9]|2[0-3])[0-5][0-9]$')][string]$AutoStartupTime  = '0800',
    [ValidateRange(1,20)][int]$MaxVMsPerUser = 3,
    [ValidateRange(5,100)][int]$MaxVMsPerLab = 50,
    [ValidateRange(50,10000)][int]$CostThreshold = 500,
    [string]$TimeZoneId = 'UTC',
    [ValidateRange(1,90)][int]$TrainingDuration = 7,
    [bool]$InstallCommonTools = $true,
    [bool]$EnableVPNGateway = $false,
    [ValidateSet('Create','Delete','Start','Stop','Status')][string]$Action = 'Create',

    [switch]$EnableDebugOutput
)

$ErrorActionPreference = 'Stop'

Write-Host "[STARTUP] Script initialization started..." -ForegroundColor Magenta
Write-Host "[STARTUP] PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

# Modules
Write-Host "[Information] Importing required Azure modules..." -ForegroundColor Cyan
try {
    Import-Module Az.Accounts    -Force; Write-Host "[Information] Loaded 'Az.Accounts'"    -ForegroundColor Green
    Import-Module Az.Resources   -Force; Write-Host "[Information] Loaded 'Az.Resources'"   -ForegroundColor Green
    Import-Module Az.DevTestLabs -Force; Write-Host "[Information] Loaded 'Az.DevTestLabs'" -ForegroundColor Green
    Import-Module Az.Network     -Force; Write-Host "[Information] Loaded 'Az.Network'"     -ForegroundColor Green
    Import-Module Az.Compute     -Force; Write-Host "[Information] Loaded 'Az.Compute'"     -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to import Az modules: $($_.Exception.Message)" -ForegroundColor Red
    throw "Install-Module Az -AllowClobber -Force"
}

# Auth
Write-Host "[Information] Checking Azure authentication..." -ForegroundColor Cyan
$azContext = Get-AzContext
if (-not $azContext) {
    Write-Host "[STARTUP] No Azure context found. Please authenticate..." -ForegroundColor Yellow
    Connect-AzAccount | Out-Null
    $azContext = Get-AzContext
}
Write-Host "[Information] Using subscription: $($azContext.Subscription.Name) ($($azContext.Subscription.Id))" -ForegroundColor Green

# === Precomputed resource IDs (avoid ARM [resourceId()] with $variables) ===
$SubscriptionId = (Get-AzContext).Subscription.Id
$RgProviderPath = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers"

$Ids = @{
  NatPip          = "$RgProviderPath/Microsoft.Network/publicIPAddresses/$LabName-nat-pip"
  NatGw           = "$RgProviderPath/Microsoft.Network/natGateways/$LabName-nat-gateway"
  VNet            = "$RgProviderPath/Microsoft.Network/virtualNetworks/$LabName-vnet"
  SubnetDefault   = "$RgProviderPath/Microsoft.Network/virtualnetworks/$LabName-vnet/subnets/default"
  Lab             = "$RgProviderPath/Microsoft.DevTestLab/labs/$LabName"
  LabVNetCanon    = "$RgProviderPath/Microsoft.DevTestLab/labs/$LabName/virtualnetworks/$LabName"
  LabVNetExternal = "$RgProviderPath/Microsoft.DevTestLab/labs/$LabName/virtualnetworks/external-$LabName-vnet"
}

# ---------- Diagnostics helpers ----------
function Test-GalleryImageAvailability {
    param(
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$Publisher,
        [Parameter(Mandatory)][string]$Offer,
        [Parameter(Mandatory)][string]$Sku
    )
    try {
        $pub = Get-AzVMImagePublisher -Location $Location -ErrorAction Stop | Where-Object { $_.PublisherName -eq $Publisher }
        if (-not $pub) { return "Publisher '$Publisher' not found in $Location." }

        $offers = Get-AzVMImageOffer -Location $Location -PublisherName $Publisher -ErrorAction Stop | Select-Object -ExpandProperty Offer
        if ($Offer -notin $offers) { return "Offer '$Offer' not available in $Location for publisher '$Publisher'." }

        $skus = Get-AzVMImageSku -Location $Location -PublisherName $Publisher -Offer $Offer -ErrorAction Stop | Select-Object -ExpandProperty Skus
        if ($Sku -notin $skus)     { return "SKU '$Sku' not available in $Location for $Publisher/$Offer." }

        return $null
    } catch {
        return "Image availability check error for $Publisher/$Offer/$Sku in $Location: $($_.Exception.Message)"
    }
}

function Test-NetworkAndLabReadiness {
    param(
        [Parameter(Mandatory)][string]$LabName,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$Location
    )
    $problems = New-Object System.Collections.ArrayList

    Write-Host "[HEALTH] Validating external VNet + default subnet + NAT association..." -ForegroundColor Cyan
    $extVnetName = "$LabName-vnet"
    $vnet = Get-AzVirtualNetwork -Name $extVnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vnet) { [void]$problems.Add("External VNet '$extVnetName' not found.") }
    else {
        $defaultSubnet = $vnet.Subnets | Where-Object { $_.Name -eq 'default' }
        if (-not $defaultSubnet) { [void]$problems.Add("Default subnet missing on VNet '$extVnetName'.") }
        else {
            if (-not $defaultSubnet.NatGateway) {
                [void]$problems.Add("Default subnet 'default' on '$extVnetName' has NO NAT Gateway associated (Default Outbound Access is retired).")
            }
        }
    }

    Write-Host "[HEALTH] Validating DevTest Lab VNet subnetOverrides/useInVmCreation..." -ForegroundColor Cyan
    $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName -ErrorAction SilentlyContinue
    if ($lab) {
        $labVnets = Get-AzResource -ResourceId "$($lab.ResourceId)/virtualnetworks" -ErrorAction SilentlyContinue
        if (-not $labVnets) {
            [void]$problems.Add("No DevTest Lab virtual networks found under lab '$LabName'.")
        } else {
            foreach ($lv in $labVnets) {
                $props = (Get-AzResource -ResourceId $lv.ResourceId -ExpandProperties -ErrorAction SilentlyContinue).Properties
                $extId = if ($props) { $props.externalProviderResourceId } else { $null }
                $over  = if ($props) { $props.subnetOverrides } else { $null }

                if (-not $extId) { [void]$problems.Add("Lab VNet '$($lv.Name)' has no externalProviderResourceId (not linked).") }

                if (-not $over -or @($over).Count -eq 0) {
                    [void]$problems.Add("Lab VNet '$($lv.Name)' has no subnetOverrides. Default subnet must be enabled for VM creation.")
                } else {
                    $def = $over | Where-Object { $_.resourceId -match "/subnets/default($|[/?])" }
                    if (-not $def) { [void]$problems.Add("Lab VNet '$($lv.Name)' has overrides, but none for 'default' subnet.") }
                    else {
                        $enabled = $false
                        foreach ($d in $def) {
                            if (($d.useInVmCreation -eq $true) -or (("$($d.useInVmCreation)") -imatch '^true$')) { $enabled = $true }
                        }
                        if (-not $enabled) { [void]$problems.Add("Lab VNet '$($lv.Name)' default subnet override exists but useInVmCreation is not TRUE.") }
                    }
                }
            }
        }
    } else {
        [void]$problems.Add("Lab '$LabName' not found to verify lab VNets.")
    }

    Write-Host "[HEALTH] Checking sample image availability (informational)..." -ForegroundColor Cyan
    $checks = @(
        @{Publisher='MicrosoftWindowsServer';  Offer='WindowsServer'; Sku='2022-Datacenter'},
        @{Publisher='MicrosoftWindowsServer';  Offer='WindowsServer'; Sku='2019-Datacenter'},
        @{Publisher='MicrosoftWindowsDesktop'; Offer='Windows-10';    Sku='win10-22h2-pro'},
        @{Publisher='MicrosoftWindowsDesktop'; Offer='Windows-11';    Sku='win11-22h2-pro'}
    )
    foreach ($c in $checks) {
        $msg = Test-GalleryImageAvailability -Location $Location -Publisher $c.Publisher -Offer $c.Offer -Sku $c.Sku
        if ($msg) { [void]$problems.Add("Image check: $msg") }
    }

    if ($problems.Count -gt 0) {
        Write-Warning "[HEALTH] Issues detected:"
        $idx = 0
        foreach ($p in $problems) { $idx++; Write-Host ("  {0}. {1}" -f $idx, $p) -ForegroundColor Yellow }
    } else {
        Write-Host "[HEALTH] No blocking issues detected. Network and Lab VNets look good." -ForegroundColor Green
    }
    return ,$problems
}

# ---------- VNet/Lab utilities ----------
function Get-LabVirtualNetwork {
    param([Parameter(Mandatory)][string]$LabName,[Parameter(Mandatory)][string]$ResourceGroupName)
    try {
        $desiredName = "external-$LabName-vnet"
        $labVnets = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualnetworks' -ExpandProperties -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "$LabName/$desiredName" }
        $allLabVnetsForLab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualnetworks' -ExpandProperties -ErrorAction SilentlyContinue
        if ($allLabVnetsForLab) {
            $extVnetName = "$LabName-vnet"
            $extVnetId   = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$extVnetName"
            $additionalLabVnets = $allLabVnetsForLab | Where-Object {
                $_.Name -eq "$LabName/$desiredName" -and $_.Properties -and $_.Properties.externalProviderResourceId -and (
                    $_.Properties.externalProviderResourceId -ieq $extVnetId -or
                    $_.Properties.externalProviderResourceId -like "*/$extVnetName" -or
                    $_.Properties.externalProviderResourceId -like "*/$extVnetName/*" -or
                    $_.Properties.externalProviderResourceId.ToLower().Contains($extVnetName.ToLower())
                )
            }
            if ($additionalLabVnets) { $labVnets = @($labVnets) + @($additionalLabVnets) }
        }
        if ($labVnets -and $labVnets.Count -ge 1) {
            $preferred = $labVnets | Where-Object { $_.Name -eq "$LabName/$desiredName" } | Select-Object -First 1
            if ($preferred) { return [pscustomobject]@{ Name="external-$LabName-vnet"; SubnetName='default' } }
            $enabled = $labVnets | Where-Object { $_.Properties -and $_.Properties.subnetOverrides -and ($_.Properties.subnetOverrides | Where-Object { $_.useInVmCreation -eq $true }).Count -gt 0 } | Select-Object -First 1
            if ($enabled) {
                $parts2 = $enabled.Name -split '/'
                if ($parts2.Length -eq 2 -and $parts2[0] -eq $LabName) { return [pscustomobject]@{ Name=$parts2[1]; SubnetName='default' } }
            }
            $first = $labVnets | Select-Object -First 1
            $parts = $first.Name -split '/'
            if ($parts.Length -eq 2 -and $parts[0] -eq $LabName) { return [pscustomobject]@{ Name=$parts[1]; SubnetName='default' } }
        }
    } catch { }
    return [pscustomobject]@{ Name=$LabName; SubnetName='default' }
}

function Enable-LabVNetSubnet {
    param(
        [Parameter(Mandatory)][string]$LabName,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$LabVNetName,
        [string]$SubnetName='default'
    )
    try {
        Write-Host "[Enable-Subnet] Enabling '$SubnetName' on Lab VNet '$LabVNetName'..." -ForegroundColor Yellow
        $labVnetResource = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualnetworks' -Name "$LabName/$LabVNetName" -ExpandProperties -ErrorAction Stop
        if (-not $labVnetResource.Properties.externalProviderResourceId) {
            Write-Warning "[Enable-Subnet] No externalProviderResourceId on lab VNet '$LabVNetName'."
            return $false
        }
        $subnetResourceId = "$($labVnetResource.Properties.externalProviderResourceId)/subnets/$SubnetName"

        $newSubnetOverrides = @()
        if ($labVnetResource.Properties.subnetOverrides) {
            foreach ($o in $labVnetResource.Properties.subnetOverrides) {
                if ($o.resourceId -notmatch "/subnets/$SubnetName($|[/?])") { $newSubnetOverrides += $o }
            }
        }
        $newSubnetOverrides += @{
            resourceId = $subnetResourceId
            useInVmCreation = 'Allow'
            sharedPublicIpAddressConfiguration = @{
                allowedPorts = @(@{ transportProtocol='Tcp'; backendPort=3389 })
            }
        }

        $updateBody = @{
            properties = @{
                description = $labVnetResource.Properties.description
                externalProviderResourceId = $labVnetResource.Properties.externalProviderResourceId
                subnetOverrides = $newSubnetOverrides
            }
        }
        Set-AzResource -ResourceId $labVnetResource.ResourceId -Properties $updateBody.properties -Force -ErrorAction Stop | Out-Null
        Start-Sleep -Seconds 3
        $verify = Get-AzResource -ResourceId $labVnetResource.ResourceId -ExpandProperties -ErrorAction SilentlyContinue
        $ok = $verify.Properties.subnetOverrides | Where-Object { $_.resourceId -eq $subnetResourceId -and $_.useInVmCreation -eq $true }
        if ($ok) { Write-Host "[Enable-Subnet] Subnet '$SubnetName' enabled." -ForegroundColor Green; return $true }
        Write-Warning "[Enable-Subnet] Verification failed for '$SubnetName'."
        return $false
    } catch {
        Write-Warning "[Enable-Subnet] Error: $($_.Exception.Message)"
        return $false
    }
}

function Resolve-LabVirtualNetwork {
    param(
        [Parameter(Mandatory)][string]$LabName,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [ValidateRange(10,600)][int]$TimeoutSeconds = 180,
        [ValidateRange(2,60)][int]$PollSeconds = 10
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $desired = "external-$LabName-vnet"
    do {
        $labVnets = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualnetworks' -ExpandProperties -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$LabName/*" }
        if ($labVnets) {
            $attached = $labVnets | Where-Object { $_.Name -eq "$LabName/$desired" } | Select-Object -First 1
            $candidates = if ($attached) { @($attached) + @($labVnets) } else { $labVnets }
            foreach ($lv in $candidates) {
                $overs = $lv.Properties.subnetOverrides
                if (-not $overs) { continue }
                $def = $overs | Where-Object { $_.resourceId -match "/subnets/default($|[/?])" }
                $enabled = $false
                foreach ($d in $def) {
                    if (($d.useInVmCreation -eq $true) -or (("$($d.useInVmCreation)") -imatch '^true$')) { $enabled = $true }
                }
                if ($enabled) {
                    $parts = $lv.Name -split '/'
                    return [pscustomobject]@{ Name=$parts[1]; SubnetName='default' }
                }
            }
        }
        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    Write-Warning "[Resolver] Timeout waiting for lab VNet with default subnet enabled. Attempting manual enablement..."
    try {
        $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName -ErrorAction SilentlyContinue
        if ($lab) {
            $labVnets = Get-AzResource -ResourceId "$($lab.ResourceId)/virtualnetworks" -ErrorAction SilentlyContinue
            if ($labVnets -and $labVnets.Count -gt 0) {
                $first = $labVnets | Select-Object -First 1
                $ok = Enable-LabVNetSubnet -LabName $LabName -ResourceGroupName $ResourceGroupName -LabVNetName $first.Name -SubnetName 'default'
                if ($ok) { return [pscustomobject]@{ Name=$first.Name; SubnetName='default' } }
            }
        }
    } catch { }
    return Get-LabVirtualNetwork -LabName $LabName -ResourceGroupName $ResourceGroupName
}

# ---------- VM ARM template for DTL (no $schema field) ----------
function New-DevTestLabVMTemplate {
    param(
        [string]$VMName,
        [hashtable]$VMConfig,
        [bool]$IsJumphost,
        [string]$VNetName='default',
        [string]$SubnetName='default'
    )
    $labVnetId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$($VMConfig.ResourceGroupName)/providers/Microsoft.DevTestLab/labs/$($VMConfig.LabName)/virtualnetworks/external-$($VMConfig.LabName)-vnet"

    $vmProperties = @{
        size = $VMConfig.Size
        userName = $VMConfig.UserName
        password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VMConfig.Password))
        isAuthenticationWithSshKey = $false
        labSubnetName = $SubnetName
        labVirtualNetworkId = $labVnetId
        notes = $VMConfig.Notes
        allowClaim = $VMConfig.AllowClaim
        storageType = $VMConfig.StorageType
        galleryImageReference = @{
            offer     = $VMConfig.GalleryImageReferenceOffer
            publisher = $VMConfig.GalleryImageReferencePublisher
            sku       = $VMConfig.GalleryImageReferenceSku
            osType    = 'Windows'
            version   = $VMConfig.GalleryImageReferenceVersion
        }
        disallowPublicIpAddress = $VMConfig.DisallowPublicIpAddress
    }
    if (-not $VMConfig.DisallowPublicIpAddress) {
        $vmProperties['networkInterface'] = @{
            publicIpAddress = 'New'
            publicIpAddressInboundDnatRules = @(
                @{ transportProtocol='tcp'; backendPort=3389 }
            )
        }
    }
    return @{
        contentVersion = '1.0.0.0'
        resources = @(
            @{
                type = 'Microsoft.DevTestLab/labs/virtualmachines'
                apiVersion = '2018-09-15'
                name = "$($VMConfig.LabName)/$VMName"
                location = $VMConfig.Location
                properties = $vmProperties
            }
        )
    }
}

# ---------- RG/Lab creation (no $schema in TemplateObject) ----------
function New-TrainingResourceGroup { param($Name,$Location)
    $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "Creating resource group '$Name' in '$Location'..." -ForegroundColor Yellow
        $rg = New-AzResourceGroup -Name $Name -Location $Location
        Write-Host "Resource group created." -ForegroundColor Green
    } else { Write-Host "Resource group '$Name' already exists." -ForegroundColor Green }
    return $rg
}

function New-TrainingDevTestLab {
    param($LabName,$ResourceGroupName,$Location)

    Write-Host "Creating/Updating DevTest Lab '$LabName' and external VNet/NAT..." -ForegroundColor Cyan

    $resources = @()

    # NAT Public IP
    $resources += @{
        type = 'Microsoft.Network/publicIPAddresses'
        apiVersion = '2020-11-01'
        name = "$LabName-nat-pip"
        location = $Location
        sku = @{ name='Standard' }
        properties = @{ publicIPAllocationMethod='Static'; publicIPAddressVersion='IPv4' }
    }

    # NAT Gateway
    $resources += @{
        type = 'Microsoft.Network/natGateways'
        apiVersion = '2020-11-01'
        name = "$LabName-nat-gateway"
        location = $Location
        sku = @{ name='Standard' }
        properties = @{
            idleTimeoutInMinutes = 4
            publicIpAddresses = @( @{ id = $Ids.NatPip } )
        }
        dependsOn = @($Ids.NatPip)
    }

    # External VNet + default subnet associated with NAT
    $resources += @{
        type = 'Microsoft.Network/virtualNetworks'
        apiVersion = '2020-11-01'
        name = "$LabName-vnet"
        location = $Location
        properties = @{
            addressSpace = @{ addressPrefixes = @('10.10.0.0/16') }
            subnets = @(
                @{
                    name = 'default'
                    properties = @{
                        addressPrefix = '10.10.0.0/24'
                        natGateway = @{ id = $Ids.NatGw }
                    }
                }
            )
        }
        dependsOn = @($Ids.NatGw)
    }

    # DevTest Lab
    $resources += @{
        type = 'Microsoft.DevTestLab/labs'
        apiVersion = '2018-09-15'
        name = $LabName
        location = $Location
        properties = @{
            labStorageType = 'Standard'
            mandatoryArtifactsResourceIdsWindows = @()
            premiumDataDisks = 'Enabled'
            environmentPermission = 'Reader'
            announcement = @{
                title = 'Welcome to Training Lab'
                markdown = "Welcome to the **$LabName** training environment. Please follow the instructor's guidance for accessing your assigned VMs."
                enabled = 'Enabled'
                expirationDate = (Get-Date).AddDays($TrainingDuration).ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            support = @{ enabled = 'Enabled'; markdown = 'For technical support, contact your instructor or IT administrator.' }
        }
    }

    # Attach canonical Lab VNet (labName/labName) only on first deploy
    $existingLab   = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName -ErrorAction SilentlyContinue
    $existingLabVN = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualnetworks' -ExpandProperties -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$LabName/*" }

    if (-not $existingLab -and (-not $existingLabVN -or $existingLabVN.Count -eq 0)) {
        $resources += @{
            type = 'Microsoft.DevTestLab/labs/virtualnetworks'
            apiVersion = '2018-09-15'
            name = "$LabName/$LabName"
            location = $Location
            dependsOn = @($Ids.Lab, $Ids.VNet)
            properties = @{
                description = 'Training lab virtual network'
                externalProviderResourceId = $Ids.VNet
                subnetOverrides = @(
                    @{
                        resourceId = $Ids.SubnetDefault
                        useInVmCreation = 'Allow'
                        sharedPublicIpAddressConfiguration = @{
                            allowedPorts = @(@{ transportProtocol='Tcp'; backendPort=3389 })
                        }
                    }
                )
            }
        }
    } else {
        $desired = "external-$LabName-vnet"
        $present = $false
        if ($existingLabVN) { $present = ($existingLabVN | Where-Object { $_.Name -eq "$LabName/$desired" }).Count -gt 0 }
        if (-not $present) {
            $resources += @{
                type = 'Microsoft.DevTestLab/labs/virtualnetworks'
                apiVersion = '2018-09-15'
                name = "$LabName/$desired"
                location = $Location
                dependsOn = @($Ids.Lab, $Ids.VNet, $Ids.NatGw)
                properties = @{
                    description = 'External VNet for training lab'
                    externalProviderResourceId = $Ids.VNet
                    subnetOverrides = @(
                        @{
                            resourceId = $Ids.SubnetDefault
                            useInVmCreation = 'Allow'
                            sharedPublicIpAddressConfiguration = @{
                                allowedPorts = @(@{ transportProtocol='Tcp'; backendPort=3389 })
                            }
                        }
                    )
                }
            }
        }
    }

    $template = @{
        contentVersion = '1.0.0.0'
        resources = $resources
    }

    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateObject $template -Name "DevTestLab-$LabName-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
    Write-Host "DevTest Lab + external VNet/NAT ensured." -ForegroundColor Green
}

# ---------- Policies ----------
function Set-TrainingLabPolicies {
    param($LabName,$ResourceGroupName)

    Write-Host "Configuring lab policies..." -ForegroundColor Cyan

    try {
        $cmd = Get-Command Set-AzDtlAllowedVMSizesPolicy -ErrorAction SilentlyContinue
        if ($cmd) {
            $tried = $false
            foreach ($paramName in @('AllowedVMSizes','AllowedVirtualMachineSizes','VMSizes','VirtualMachineSizes','Sizes','AllowedSizes')) {
                if ($cmd.Parameters.ContainsKey($paramName)) {
                    $args = @{ LabName=$LabName; ResourceGroupName=$ResourceGroupName; Enable=$true }
                    $args[$paramName] = @($VMSize)
                    try { Set-AzDtlAllowedVMSizesPolicy @args; $tried=$true; Write-Host "Allowed VM sizes policy set." -ForegroundColor Green; break } catch { }
                }
            }
            if (-not $tried) { Write-Warning "Could not set Allowed VM sizes policy (cmdlet parameters mismatch)." }
        } else { Write-Warning "Set-AzDtlAllowedVMSizesPolicy not found." }
    } catch { Write-Warning "VM sizes policy error: $_" }

    try { Set-AzDtlVMsPerUserPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -MaxVMs $MaxVMsPerUser -Enable } catch { Write-Warning "VMs per user policy error: $_" }
    try { Set-AzDtlVMsPerLabPolicy  -LabName $LabName -ResourceGroupName $ResourceGroupName -MaxVMs $MaxVMsPerLab  -Enable } catch { Write-Warning "VMs per lab policy error: $_" }

    try {
        $h=[int]$AutoShutdownTime.Substring(0,2); $m=[int]$AutoShutdownTime.Substring(2,2)
        $t= Get-Date -Hour $h -Minute $m -Second 0 -Millisecond 0
        $cmd = Get-Command Set-AzDtlAutoShutdownPolicy -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Parameters.ContainsKey('TimeZoneId')) {
            Set-AzDtlAutoShutdownPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -Time $t -TimeZoneId $TimeZoneId -Enable
        } elseif ($cmd) {
            Set-AzDtlAutoShutdownPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -Time $t -Enable
        } else {
            $policyId= "$($Ids.Lab)/policies/AutoShutdown"
            $body = @{
                properties = @{
                    status = 'Enabled'
                    dailyRecurrence = @{
                        time = ('{0:D2}:{1:D2}' -f $h,$m)
                        timeZoneId = $TimeZoneId
                    }
                }
            }
            Set-AzResource -ResourceId $policyId -Properties $body.properties -Force | Out-Null
        }
        Write-Host "Auto-shutdown policy set." -ForegroundColor Green
    } catch { Write-Warning "Auto-shutdown policy error: $_" }

    try {
        $h=[int]$AutoStartupTime.Substring(0,2); $m=[int]$AutoStartupTime.Substring(2,2)
        $t= Get-Date -Hour $h -Minute $m -Second 0 -Millisecond 0
        $cmd = Get-Command Set-AzDtlAutoStartPolicy -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Parameters.ContainsKey('TimeZoneId')) {
            Set-AzDtlAutoStartPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -Time $t -TimeZoneId $TimeZoneId -Enable
        } elseif ($cmd) {
            Set-AzDtlAutoStartPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -Time $t -Enable
        } else {
            $policyId= "$($Ids.Lab)/policies/AutoStart"
            $body = @{
                properties = @{
                    status = 'Enabled'
                    weeklyRecurrence = @{
                        time = ('{0:D2}:{1:D2}' -f $h,$m)
                        weekdays = @('Monday','Tuesday','Wednesday','Thursday','Friday')
                        timeZoneId = $TimeZoneId
                    }
                }
            }
            Set-AzResource -ResourceId $policyId -Properties $body.properties -Force | Out-Null
        }
        Write-Host "Auto-start policy set." -ForegroundColor Green
    } catch { Write-Warning "Auto-start policy error: $_" }

    Write-Host "Lab policies configured." -ForegroundColor Green
}

# ---------- Users ----------
function Add-TrainingLabUsers {
    param($LabName,$ResourceGroupName,$UserEmails,$Role='DevTest Labs User')
    if (-not $UserEmails -or $UserEmails.Count -eq 0) { Write-Host "No user emails provided." -ForegroundColor Yellow; return }
    $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName
    foreach ($email in $UserEmails) {
        try {
            $user = Get-AzADUser -Mail $email -ErrorAction SilentlyContinue
            if (-not $user) { Write-Warning "AAD user not found: $email"; continue }
            New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope $lab.ResourceId -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Assigned '$Role' to $email" -ForegroundColor Green
        } catch { Write-Warning "Failed to add $email: $_" }
    }
}

# ---------- Formulas (optional) ----------
function New-TrainingVMFormulas {
    param($LabName,$ResourceGroupName)
    $labVnet = Resolve-LabVirtualNetwork -LabName $LabName -ResourceGroupName $ResourceGroupName -TimeoutSeconds 180 -PollSeconds 10
    $formulaVnetName = $labVnet.Name
    $formulaSubnetName = $labVnet.SubnetName

    if ($InstallCommonTools -and $WindowsVMCount -gt 0) {
        Write-Host "Preparing a Windows formula with common tools..." -ForegroundColor Yellow
        $formulaVmProps = @{
            size = $VMSize
            userName = 'trainee'
            password = 'Training123!'
            isAuthenticationWithSshKey = $false
            labSubnetName = $formulaSubnetName
            labVirtualNetworkId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/virtualnetworks/$formulaVnetName"
            notes = 'Windows training virtual machine'
            artifacts = @(
                @{ artifactId = '/resourceGroups/{resource-group}/providers/Microsoft.DevTestLab/labs/{lab-name}/artifactSources/public repo/artifacts/windows-chrome' },
                @{ artifactId = '/resourceGroups/{resource-group}/providers/Microsoft.DevTestLab/labs/{lab-name}/artifactSources/public repo/artifacts/windows-notepadplusplus' },
                @{ artifactId = '/resourceGroups/{resource-group}/providers/Microsoft.DevTestLab/labs/{lab-name}/artifactSources/public repo/artifacts/windows-vscode' }
            )
            galleryImageReference = @{
                offer='WindowsServer'; publisher='MicrosoftWindowsServer'; sku='2019-Datacenter'; osType='Windows'; version='latest'
            }
            disallowPublicIpAddress = -not $AllowPublicIP
        }
        Write-Host "Formula definition prepared (ensure public artifact source exists in the lab)." -ForegroundColor Green
    }
}

# ---------- German training VM sets ----------
function New-GermanTrainingVMSets {
    param($LabName,$ResourceGroupName)

    $labVnet = Resolve-LabVirtualNetwork -LabName $LabName -ResourceGroupName $ResourceGroupName -TimeoutSeconds 300 -PollSeconds 10
    $vnetName = $labVnet.Name; $subnetName = $labVnet.SubnetName
    Write-Host "Using lab VNet: $vnetName / Subnet: $subnetName" -ForegroundColor Green

    $participantCount = $StudentCount + ($IncludeTrainer ? 1 : 0)
    $totalVMs = $participantCount * 5 + ($UseJumphost ? $participantCount : 0)
    Write-Host "Total VMs to create: $totalVMs ($participantCount participant sets)" -ForegroundColor Yellow

    $vmSpecs = @{
        'ServerDC' = @{
            Image=@{offer='WindowsServer'; publisher='MicrosoftWindowsServer'; sku='2022-Datacenter'; version='latest'}
            User='administrator'
        }
        'ServerTS' = @{
            Image=@{offer='WindowsServer'; publisher='MicrosoftWindowsServer'; sku='2019-Datacenter'; version='latest'}
            User='administrator'
        }
        'Server01' = @{
            Image=@{offer='WindowsServer'; publisher='MicrosoftWindowsServer'; sku='2022-Datacenter'; version='latest'}
            User='administrator'
        }
        'Client01' = @{
            Image=@{offer='Windows-10'; publisher='MicrosoftWindowsDesktop'; sku='win10-22h2-pro'; version='latest'}
            User='administrator'
        }
        'Client02' = @{
            Image=@{offer='Windows-11'; publisher='MicrosoftWindowsDesktop'; sku='win11-22h2-pro'; version='latest'}
            User='administrator'
        }
    }

    for ($participant=1; $participant -le $participantCount; $participant++) {
        $participantType = if ($participant -le $StudentCount) { "Student" } else { "Trainer" }
        $participantId   = if ($participant -le $StudentCount) { "S$($participant.ToString('00'))" } else { "T01" }

        if ($UseJumphost) {
            $jumphostName = "Jumphost-$participantId"
            Write-Host "Creating jumphost: $jumphostName" -ForegroundColor Cyan
            try {
                $params = @{
                    LabName=$LabName; ResourceGroupName=$ResourceGroupName; Location=$Location; Name=$jumphostName; Size=$JumphostSize
                    UserName='trainer'; Password=(ConvertTo-SecureString 'Training123!' -AsPlainText -Force)
                    GalleryImageReferenceOffer='Windows-10'; GalleryImageReferencePublisher='MicrosoftWindowsDesktop'
                    GalleryImageReferenceSku='win10-22h2-pro'; GalleryImageReferenceVersion='latest'
                    AllowClaim=$true; StorageType='Standard'; Notes="Jumphost for $participantType $participantId"
                    DisallowPublicIpAddress=$false
                }
                $cmd = Get-Command New-AzDtlVirtualMachine -ErrorAction SilentlyContinue
                if ($cmd) {
                    New-AzDtlVirtualMachine @params | Out-Null
                } else {
                    $vmTemplate = New-DevTestLabVMTemplate -VMName $jumphostName -VMConfig $params -IsJumphost $true -VNetName $vnetName -SubnetName $subnetName
                    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateObject $vmTemplate -Name "DTL-VM-$jumphostName-$(Get-Date -Format 'yyyyMMddHHmmss')" -Force | Out-Null
                }
                Write-Host "  -> Jumphost created" -ForegroundColor Green
            } catch { Write-Warning "Jumphost creation failed: $_" }
        }

        foreach ($vmType in @('ServerDC','ServerTS','Server01','Client01','Client02')) {
            $vmName = "$vmType-$participantId"
            $img = $vmSpecs[$vmType].Image
            try {
                $params = @{
                    LabName=$LabName; ResourceGroupName=$ResourceGroupName; Location=$Location; Name=$vmName; Size=$VMSize
                    UserName=$vmSpecs[$vmType].User; Password=(ConvertTo-SecureString 'Training123!' -AsPlainText -Force)
                    GalleryImageReferenceOffer=$img.offer; GalleryImageReferencePublisher=$img.publisher
                    GalleryImageReferenceSku=$img.sku; GalleryImageReferenceVersion=$img.version
                    AllowClaim=$true; StorageType='Standard'; Notes="$vmType for $participantType $participantId"
                    DisallowPublicIpAddress=$UseJumphost
                }
                $cmd = Get-Command New-AzDtlVirtualMachine -ErrorAction SilentlyContinue
                if ($cmd) {
                    New-AzDtlVirtualMachine @params | Out-Null
                } else {
                    $vmTemplate = New-DevTestLabVMTemplate -VMName $vmName -VMConfig $params -IsJumphost $false -VNetName $vnetName -SubnetName $subnetName
                    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateObject $vmTemplate -Name "DTL-VM-$vmName-$(Get-Date -Format 'yyyyMMddHHmmss')" -Force | Out-Null
                }
                Write-Host "  -> $vmName created" -ForegroundColor Green
            } catch { Write-Warning "VM $vmName failed: $_" }
        }
    }
    Write-Host "German training VM sets creation completed." -ForegroundColor Green
}

# ---------- Claimable legacy VMs ----------
function New-TrainingClaimableVMs {
    param($LabName,$ResourceGroupName)
    $labVnet = Resolve-LabVirtualNetwork -LabName $LabName -ResourceGroupName $ResourceGroupName -TimeoutSeconds 180 -PollSeconds 10
    $vnetName=$labVnet.Name; $subnetName=$labVnet.SubnetName
    for ($i=1; $i -le $WindowsVMCount; $i++) {
        $vmName = "TrainingWin$($i.ToString('00'))"
        try {
            $params = @{
                LabName=$LabName; ResourceGroupName=$ResourceGroupName; Location=$Location; Name=$vmName; Size=$VMSize
                UserName='trainee'; Password=(ConvertTo-SecureString 'Training123!' -AsPlainText -Force)
                GalleryImageReferenceOffer='WindowsServer'; GalleryImageReferencePublisher='MicrosoftWindowsServer'
                GalleryImageReferenceSku='2019-Datacenter'; GalleryImageReferenceVersion='latest'
                AllowClaim=$true; StorageType='Standard'; Notes="Windows training VM #$i"
                DisallowPublicIpAddress= -not $AllowPublicIP
            }
            $cmd = Get-Command New-AzDtlVirtualMachine -ErrorAction SilentlyContinue
            if ($cmd) {
                New-AzDtlVirtualMachine @params | Out-Null
            } else {
                $vmTemplate = New-DevTestLabVMTemplate -VMName $vmName -VMConfig $params -IsJumphost $false -VNetName $vnetName -SubnetName $subnetName
                New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateObject $vmTemplate -Name "DTL-VM-$vmName-$(Get-Date -Format 'yyyyMMddHHmmss')" -Force | Out-Null
            }
            Write-Host "  -> $vmName created" -ForegroundColor Green
        } catch { Write-Warning "VM $vmName failed: $_" }
    }
}

# ---------- Status / Delete / StartStop ----------
function Get-TrainingLabStatus {
    param($LabName,$ResourceGroupName)
    try {
        $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName -ErrorAction Stop
        Write-Host "Lab: $($lab.Name) | RG: $($lab.ResourceGroupName) | Loc: $($lab.Location) | Status: Active" -ForegroundColor Green
        try {
            $vms = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines'
            Write-Host "Total VMs: $($vms.Count)" -ForegroundColor White
            foreach ($vm in $vms) { Write-Host "  - $($vm.Name)" -ForegroundColor Gray }
        } catch { Write-Host "VMs: Unable to retrieve list" -ForegroundColor Yellow }
        return $lab
    } catch {
        Write-Host "Lab '$LabName' not found in RG '$ResourceGroupName'." -ForegroundColor Red
        return $null
    }
}

function Remove-TrainingEnvironment {
    param($LabName,$ResourceGroupName)
    Write-Host "WARNING: This deletes the entire RG '$ResourceGroupName'!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'DELETE' to confirm"
    if ($confirmation -ne 'DELETE') { Write-Host "Deletion cancelled." -ForegroundColor Yellow; return }
    Remove-AzResourceGroup -Name $ResourceGroupName -Force -AsJob
    Write-Host "Deletion initiated." -ForegroundColor Green
}

function Set-TrainingVMsState {
    param(
        [Parameter(Mandatory)][string]$LabName,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [ValidateSet('Start','Stop')][string]$State
    )
    Write-Host "$($State)ing all VMs in lab '$LabName'..." -ForegroundColor Cyan
    try {
        $labVMs = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' -ErrorAction Stop
        foreach ($vm in $labVMs) {
            $action = if ($State -eq 'Start') { 'start' } else { 'stop' }
            Write-Host "  -> $State $($vm.Name)" -ForegroundColor Yellow
            Invoke-AzResourceAction -ResourceId $vm.ResourceId -Action $action -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "All VM $($State.ToLower()) actions initiated." -ForegroundColor Green
    } catch { Write-Error "Failed to $($State.ToLower()) VMs: $_" }
}

# ---------- Main ----------
Write-Host "[Information] Azure DevTest Labs Training Environment Manager" -ForegroundColor Cyan
Write-Host "[STARTUP] Action: $Action" -ForegroundColor Gray

switch ($Action) {
    'Create' {
        New-TrainingResourceGroup -Name $ResourceGroupName -Location $Location
        New-TrainingDevTestLab   -LabName $LabName -ResourceGroupName $ResourceGroupName -Location $Location

        $issues = Test-NetworkAndLabReadiness -LabName $LabName -ResourceGroupName $ResourceGroupName -Location $Location
        if ($issues.Count -gt 0) {
            Write-Warning "Pre-create diagnostics found $($issues.Count) issue(s). Proceeding; fix critical items if VM creation fails."
        }

        Start-Sleep -Seconds 30

        Set-TrainingLabPolicies -LabName $LabName -ResourceGroupName $ResourceGroupName

        if ($TrainingUserEmails.Count -gt 0) { Add-TrainingLabUsers -LabName $LabName -ResourceGroupName $ResourceGroupName -UserEmails $TrainingUserEmails -Role 'DevTest Labs User' }
        if ($InstructorEmails.Count   -gt 0) { Add-TrainingLabUsers -LabName $LabName -ResourceGroupName $ResourceGroupName -UserEmails $InstructorEmails   -Role 'Owner' }

        New-TrainingVMFormulas -LabName $LabName -ResourceGroupName $ResourceGroupName

        if ($StudentCount -gt 0 -or $IncludeTrainer) {
            New-GermanTrainingVMSets -LabName $LabName -ResourceGroupName $ResourceGroupName
        } elseif ($WindowsVMCount -gt 0) {
            New-TrainingClaimableVMs -LabName $LabName -ResourceGroupName $ResourceGroupName
        } else {
            Write-Host "No VMs requested." -ForegroundColor Yellow
        }

        Write-Host "[POST] Re-running health checks after creation..." -ForegroundColor Cyan
        $postIssues = Test-NetworkAndLabReadiness -LabName $LabName -ResourceGroupName $ResourceGroupName -Location $Location
        if ($postIssues.Count -gt 0) {
            Write-Warning "Post-create diagnostics still show $($postIssues.Count) issue(s). Review warnings above."
        } else {
            Write-Host "[POST] Environment looks healthy." -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "Training environment created successfully." -ForegroundColor Green
        Write-Host "Lab URL:" -ForegroundColor Yellow
        Write-Host ("https://portal.azure.com/#resource/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.DevTestLab/labs/{2}" -f (Get-AzContext).Subscription.Id,$ResourceGroupName,$LabName)
    }
    'Delete' { Remove-TrainingEnvironment -LabName $LabName -ResourceGroupName $ResourceGroupName }
    'Status' { Get-TrainingLabStatus    -LabName $LabName -ResourceGroupName $ResourceGroupName | Out-Null }
    'Start'  { Set-TrainingVMsState     -LabName $LabName -ResourceGroupName $ResourceGroupName -State 'Start' }
    'Stop'   { Set-TrainingVMsState     -LabName $LabName -ResourceGroupName $ResourceGroupName -State 'Stop' }
}

Write-Host "Operation completed." -ForegroundColor Green
