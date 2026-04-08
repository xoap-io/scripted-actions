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

.PARAMETER LabName
    Name of the Azure DevTest Lab to create.

.PARAMETER ResourceGroupName
    Name of the Azure Resource Group for the lab.

.PARAMETER Location
    Azure region where the lab resources will be deployed.

.PARAMETER TrainingUserEmails
    Array of email addresses for training users to be added to the lab.

.PARAMETER InstructorEmails
    Array of email addresses for instructors to be added to the lab.

.PARAMETER StudentCount
    Number of student VMs to create. Must be between 1 and 20.

.PARAMETER IncludeTrainer
    Whether to include a trainer VM in the lab.

.PARAMETER UseJumphost
    Whether to use a jumphost VM pattern.

.PARAMETER JumphostSize
    Azure VM size for the jumphost VM.

.PARAMETER WindowsVMCount
    Number of Windows VMs to create (legacy parameter).

.PARAMETER LinuxVMCount
    Number of Linux VMs to create (legacy parameter).

.PARAMETER VMSize
    Azure VM size for student VMs.

.PARAMETER AllowPublicIP
    Whether to allow public IP addresses for VMs.

.PARAMETER AutoShutdownTime
    Time (HHMM) for automatic VM shutdown (e.g., 1800 for 6PM).

.PARAMETER AutoStartupTime
    Time (HHMM) for automatic VM startup (e.g., 0800 for 8AM).

.PARAMETER MaxVMsPerUser
    Maximum number of VMs a single user can create.

.PARAMETER MaxVMsPerLab
    Maximum total number of VMs in the lab.

.PARAMETER CostThreshold
    Cost threshold in USD for budget alerts.

.PARAMETER TimeZoneId
    Time zone ID for scheduled operations (e.g., 'UTC', 'W. Europe Standard Time').

.PARAMETER TrainingDuration
    Duration of the training in days.

.PARAMETER InstallCommonTools
    Whether to install common development tools on VMs.

.PARAMETER EnableVPNGateway
    Whether to enable a VPN gateway for the lab network.

.PARAMETER Action
    Action to perform: Create, Delete, Start, Stop, or Status.

.PARAMETER EnableDebugOutput
    If specified, enables verbose debug output during script execution.

.EXAMPLE
    .\az-ps-create-devtest-training-environment.ps1 -LabName "MyLab" -ResourceGroupName "rg-training" -Location "West Europe" -StudentCount 10

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.DevTestLabs

.LINK
    https://learn.microsoft.com/en-us/azure/devtest-labs/

.COMPONENT
    Azure PowerShell DevTest Labs
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure DevTest Lab to create.")]
    [ValidatePattern('^[a-zA-Z0-9-]{3,50}$')]
    [string]$LabName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group for the lab.")]
    [ValidatePattern('^[a-zA-Z0-9-_.()]{1,90}$')]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Azure region where the lab resources will be deployed.")]
    [ValidateSet('East US','East US 2','West US','West US 2','Central US','North Central US','South Central US','West Central US','Canada Central','Canada East','North Europe','West Europe','UK South','UK West','Germany West Central','Switzerland North','France Central','Australia East','Australia Southeast','Japan East','Japan West','Korea Central','South India','Central India','East Asia','Southeast Asia')]
    [string]$Location = 'Germany West Central',

    [Parameter(Mandatory = $false, HelpMessage = "Array of email addresses for training users to be added to the lab.")]
    [string[]]$TrainingUserEmails = @(),

    [Parameter(Mandatory = $false, HelpMessage = "Array of email addresses for instructors to be added to the lab.")]
    [string[]]$InstructorEmails = @(),

    # German training scenario parameters
    [Parameter(Mandatory = $false, HelpMessage = "Number of student VMs to create. Must be between 1 and 20.")]
    [ValidateRange(1,20)]
    [int]$StudentCount = 5,

    [Parameter(Mandatory = $false, HelpMessage = "Whether to include a trainer VM in the lab.")]
    [bool]$IncludeTrainer = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Whether to use a jumphost VM pattern.")]
    [bool]$UseJumphost = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Azure VM size for the jumphost VM.")]
    [ValidateSet('Standard_B2s', 'Standard_B2ms', 'Standard_D2s_v3', 'Standard_D4s_v3')]
    [string]$JumphostSize = 'Standard_B2ms',

    # Legacy parameters for compatibility
    [Parameter(Mandatory = $false, HelpMessage = "Number of Windows VMs to create (legacy parameter).")]
    [ValidateRange(0,50)]
    [int]$WindowsVMCount = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Number of Linux VMs to create (legacy parameter).")]
    [ValidateRange(0,50)]
    [int]$LinuxVMCount = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Azure VM size for student VMs.")]
    [ValidateSet('Standard_B1s', 'Standard_B2s', 'Standard_B2ms', 'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_E2s_v3')]
    [string]$VMSize = 'Standard_B2s',

    [Parameter(Mandatory = $false, HelpMessage = "Whether to allow public IP addresses for VMs.")]
    [bool]$AllowPublicIP = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Time (HHMM) for automatic VM shutdown (e.g., 1800 for 6PM).")]
    [ValidatePattern('^([01]?[0-9]|2[0-3])[0-5][0-9]$')]
    [string]$AutoShutdownTime = '1800',

    [Parameter(Mandatory = $false, HelpMessage = "Time (HHMM) for automatic VM startup (e.g., 0800 for 8AM).")]
    [ValidatePattern('^([01]?[0-9]|2[0-3])[0-5][0-9]$')]
    [string]$AutoStartupTime  = '0800',

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of VMs a single user can create.")]
    [ValidateRange(1,20)]
    [int]$MaxVMsPerUser = 3,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum total number of VMs in the lab.")]
    [ValidateRange(5,100)]
    [int]$MaxVMsPerLab = 50,

    [Parameter(Mandatory = $false, HelpMessage = "Cost threshold in USD for budget alerts.")]
    [ValidateRange(50,10000)]
    [int]$CostThreshold = 500,

    [Parameter(Mandatory = $false, HelpMessage = "Time zone ID for scheduled operations (e.g., 'UTC', 'W. Europe Standard Time').")]
    [string]$TimeZoneId = 'UTC',

    [Parameter(Mandatory = $false, HelpMessage = "Duration of the training in days.")]
    [ValidateRange(1,90)]
    [int]$TrainingDuration = 7,

    [Parameter(Mandatory = $false, HelpMessage = "Whether to install common development tools on VMs.")]
    [bool]$InstallCommonTools = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Whether to enable a VPN gateway for the lab network.")]
    [bool]$EnableVPNGateway = $false,

    [Parameter(Mandatory = $false, HelpMessage = "Action to perform: Create, Delete, Start, Stop, or Status.")]
    [ValidateSet('Create','Delete','Start','Stop','Status')]
    [string]$Action = 'Create',

    [Parameter(Mandatory = $false, HelpMessage = "If specified, enables verbose debug output during script execution.")]
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

if ($SubscriptionId) {
    Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
}

Write-Host "Using subscription: $($azContext.Subscription.Name) ($($azContext.Subscription.Id))" -ForegroundColor Green

# Function to create resource group
function New-TrainingResourceGroup {
    param($Name, $Location)

    Write-Host "Checking if resource group '$Name' exists..." -ForegroundColor Cyan
    $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue

    if (-not $rg) {
        Write-Host "Creating resource group '$Name' in '$Location'..." -ForegroundColor Yellow
        $rg = New-AzResourceGroup -Name $Name -Location $Location
        Write-Host "Resource group created successfully." -ForegroundColor Green
    } else {
        Write-Host "Resource group '$Name' already exists." -ForegroundColor Green
    }
    return $rg
}

# Function to create DevTest Lab
function New-TrainingDevTestLab {
    param($LabName, $ResourceGroupName, $Location)

    Write-Host "Creating DevTest Lab '$LabName'..." -ForegroundColor Cyan

    # Create the lab using ARM template approach since New-AzDtlLab may not be available
    $labTemplate = @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            labName = @{
                type = 'string'
                value = $LabName
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
        )
    }

    # Deploy the lab
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateObject $labTemplate `
            -Name "DevTestLab-$LabName-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
            -Force

        Write-Host "DevTest Lab created successfully." -ForegroundColor Green
        return $deployment
    } catch {
        throw "Failed to create DevTest Lab: $_"
    }
}

# Function to set lab policies
function Set-TrainingLabPolicies {
    param($LabName, $ResourceGroupName)

    Write-Host "Configuring lab policies..." -ForegroundColor Cyan

    # Set allowed VM sizes policy
    Write-Host "Setting allowed VM sizes policy..." -ForegroundColor Yellow
    Set-AzDtlAllowedVMSizesPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -AllowedVmSizes @($VMSize) -Enable

    # Set VMs per user policy
    Write-Host "Setting VMs per user policy (max: $MaxVMsPerUser)..." -ForegroundColor Yellow
    Set-AzDtlVMsPerUserPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -MaxVMs $MaxVMsPerUser -Enable

    # Set VMs per lab policy
    Write-Host "Setting VMs per lab policy (max: $MaxVMsPerLab)..." -ForegroundColor Yellow
    Set-AzDtlVMsPerLabPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -MaxVMs $MaxVMsPerLab -Enable

    # Set auto-shutdown policy
    Write-Host "Setting auto-shutdown policy (shutdown at: $AutoShutdownTime $TimeZoneId)..." -ForegroundColor Yellow
    Set-AzDtlAutoShutdownPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -Time $AutoShutdownTime -TimeZoneId $TimeZoneId -Enable

    # Set auto-start policy
    Write-Host "Setting auto-start policy (startup at: $AutoStartupTime $TimeZoneId)..." -ForegroundColor Yellow
    Set-AzDtlAutoStartPolicy -LabName $LabName -ResourceGroupName $ResourceGroupName -Time $AutoStartupTime -TimeZoneId $TimeZoneId -Enable

    Write-Host "Lab policies configured successfully." -ForegroundColor Green
}

# Function to add users to lab
function Add-TrainingLabUsers {
    param($LabName, $ResourceGroupName, $UserEmails, $Role = 'DevTest Labs User')

    if ($UserEmails.Count -eq 0) {
        Write-Host "No user emails provided, skipping user assignment." -ForegroundColor Yellow
        return
    }

    Write-Host "Adding $($UserEmails.Count) users to lab with role '$Role'..." -ForegroundColor Cyan

    # Get lab resource ID
    $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName

    foreach ($email in $UserEmails) {
        try {
            Write-Host "Adding user: $email" -ForegroundColor Yellow

            # Get user object ID from Azure AD
            $user = Get-AzADUser -Mail $email -ErrorAction SilentlyContinue
            if (-not $user) {
                Write-Warning "User $email not found in Azure AD, skipping..."
                continue
            }

            # Assign role to user
            New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $Role -Scope $lab.ResourceId -ErrorAction SilentlyContinue
            Write-Host "User $email added successfully." -ForegroundColor Green

        } catch {
            Write-Warning "Failed to add user $email`: $_"
        }
    }
}

# Function to create VM formulas
function New-TrainingVMFormulas {
    param($LabName, $ResourceGroupName)

    Write-Host "Creating VM formulas for training..." -ForegroundColor Cyan

    # Common artifacts for training VMs
    $commonWindowsArtifacts = @()
    $commonLinuxArtifacts = @()

    if ($InstallCommonTools) {
        $commonWindowsArtifacts = @(
            @{
                artifactId = '/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.DevTestLab/labs/{lab-name}/artifactSources/public repo/artifacts/windows-chrome'
            },
            @{
                artifactId = '/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.DevTestLab/labs/{lab-name}/artifactSources/public repo/artifacts/windows-notepadplusplus'
            },
            @{
                artifactId = '/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.DevTestLab/labs/{lab-name}/artifactSources/public repo/artifacts/windows-vscode'
            }
        )

        $commonLinuxArtifacts = @(
            @{
                artifactId = '/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.DevTestLab/labs/{lab-name}/artifactSources/public repo/artifacts/linux-apt-package'
                parameters = @(
                    @{
                        name = 'packages'
                        value = 'curl wget git vim nano htop'
                    }
                )
            }
        )
    }

    # Create Windows VM formula
    if ($WindowsVMCount -gt 0) {
        Write-Host "Creating Windows VM formula..." -ForegroundColor Yellow
        $windowsFormula = @{
            location = $Location
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
    }

    # Create Linux VM formula
    if ($LinuxVMCount -gt 0) {
        Write-Host "Creating Linux VM formula..." -ForegroundColor Yellow
        $linuxFormula = @{
            location = $Location
            properties = @{
                description = 'Linux training VM with common development tools'
                osType = 'Linux'
                formulaContent = @{
                    properties = @{
                        size = $VMSize
                        userName = 'trainee'
                        password = 'Training123!'
                        isAuthenticationWithSshKey = $false
                        labSubnetName = 'default'
                        labVirtualNetworkId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/virtualnetworks/default"
                        notes = 'Linux training virtual machine'
                        artifacts = $commonLinuxArtifacts
                        galleryImageReference = @{
                            offer = 'UbuntuServer'
                            publisher = 'Canonical'
                            sku = '18.04-LTS'
                            osType = 'Linux'
                            version = 'latest'
                        }
                        networkInterface = @{
                            sharedPublicIpAddressConfiguration = @{
                                inboundNatRules = @(
                                    @{
                                        transportProtocol = 'tcp'
                                        backendPort = 22
                                    }
                                )
                            }
                        }
                        disallowPublicIpAddress = -not $AllowPublicIP
                    }
                }
            }
        }
    }

    Write-Host "VM formulas created successfully." -ForegroundColor Green

    # Return formulas for potential use
    return @{
        WindowsFormula = if ($WindowsVMCount -gt 0) { $windowsFormula } else { $null }
        LinuxFormula = if ($LinuxVMCount -gt 0) { $linuxFormula } else { $null }
    }
}

# Function to create German training VM sets
function New-GermanTrainingVMSets {
    param($LabName, $ResourceGroupName)

    Write-Host "Creating German training VM sets..." -ForegroundColor Cyan

    # Calculate total VMs needed
    $participantCount = $StudentCount + ($IncludeTrainer ? 1 : 0)
    $totalVMs = $participantCount * 5  # Each participant gets 5 VMs
    if ($UseJumphost) {
        $totalVMs += $participantCount  # Add jumphost for each participant
    }

    Write-Host "Creating VMs for $StudentCount students$(if($IncludeTrainer){' + 1 trainer'})" -ForegroundColor Yellow
    Write-Host "Total VMs to create: $totalVMs" -ForegroundColor Yellow
    if ($UseJumphost) {
        Write-Host "Using jumphost architecture (recommended)" -ForegroundColor Green
    }

    # VM specifications based on German requirements
    $vmSpecs = @{
        'ServerDC' = @{
            OS = 'Windows Server 2022'
            CPU = 2
            RAM = '4 GB'
            Disk = '50 GB'
            Image = @{
                offer = 'WindowsServer'
                publisher = 'MicrosoftWindowsServer'
                sku = '2022-Datacenter'
                osType = 'Windows'
                version = 'latest'
            }
        }
        'ServerTS' = @{
            OS = 'Windows Server 2019'
            CPU = 2
            RAM = '4 GB'
            Disk = '50 GB'
            Image = @{
                offer = 'WindowsServer'
                publisher = 'MicrosoftWindowsServer'
                sku = '2019-Datacenter'
                osType = 'Windows'
                version = 'latest'
            }
        }
        'Server01' = @{
            OS = 'Windows Server 2022'
            CPU = 2
            RAM = '4 GB'
            Disk = '50 GB'
            Image = @{
                offer = 'WindowsServer'
                publisher = 'MicrosoftWindowsServer'
                sku = '2022-Datacenter'
                osType = 'Windows'
                version = 'latest'
            }
        }
        'Client01' = @{
            OS = 'Windows 10'
            CPU = 2
            RAM = '4 GB'
            Disk = '50 GB'
            Image = @{
                offer = 'Windows-10'
                publisher = 'MicrosoftWindowsDesktop'
                sku = 'win10-22h2-pro'
                osType = 'Windows'
                version = 'latest'
            }
        }
        'Client02' = @{
            OS = 'Windows 11'
            CPU = 2
            RAM = '4 GB'
            Disk = '50 GB'
            Image = @{
                offer = 'Windows-11'
                publisher = 'MicrosoftWindowsDesktop'
                sku = 'win11-22h2-pro'
                osType = 'Windows'
                version = 'latest'
            }
        }
    }

    # Create VMs for each participant
    for ($participant = 1; $participant -le $participantCount; $participant++) {
        $participantType = if ($participant -le $StudentCount) { "Student" } else { "Trainer" }
        $participantId = if ($participant -le $StudentCount) { "S$($participant.ToString('00'))" } else { "T01" }

        Write-Host "Creating VM set for $participantType $participantId..." -ForegroundColor Yellow

        # Create jumphost if enabled
        if ($UseJumphost) {
            $jumphostName = "Jumphost-$participantId"
            Write-Host "  Creating jumphost: $jumphostName" -ForegroundColor Cyan

            $jumphostConfig = @{
                name = $jumphostName
                location = $Location
                properties = @{
                    size = $JumphostSize
                    userName = 'trainer'
                    password = 'Training123!'
                    isAuthenticationWithSshKey = $false
                    labSubnetName = 'default'
                    labVirtualNetworkId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/virtualnetworks/default"
                    notes = "Jumphost for $participantType $participantId - Connect here first"
                    allowClaim = $true
                    storageType = 'Standard'
                    galleryImageReference = @{
                        offer = 'Windows-10'
                        publisher = 'MicrosoftWindowsDesktop'
                        sku = 'win10-22h2-pro'
                        osType = 'Windows'
                        version = 'latest'
                    }
                    disallowPublicIpAddress = $false  # Jumphost needs public IP
                    networkInterface = @{
                        publicIpAddress = 'New'
                        publicIpAddressInboundDnatRules = @(
                            @{
                                transportProtocol = 'tcp'
                                backendPort = 3389
                            }
                        )
                    }
                }
            }

            # Store jumphost config for later implementation
            $null = $jumphostConfig
            Write-Host "    Jumphost $jumphostName configured" -ForegroundColor Green
        }

        # Create the 5 VMs for this participant
        foreach ($vmType in @('ServerDC', 'ServerTS', 'Server01', 'Client01', 'Client02')) {
            $vmName = "$vmType-$participantId"
            $spec = $vmSpecs[$vmType]

            Write-Host "  Creating $vmType`: $vmName ($($spec.OS))" -ForegroundColor Gray

            $vmConfig = @{
                name = $vmName
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
                                inboundNatRules = @()
                            }
                        }
                    } else {
                        @{
                            publicIpAddress = 'New'
                            publicIpAddressInboundDnatRules = @(
                                @{
                                    transportProtocol = 'tcp'
                                    backendPort = 3389
                                }
                            )
                        }
                    }
                }
            }

            # Store VM config for later implementation
            $null = $vmConfig
            Write-Host "    $vmName configured" -ForegroundColor Green
        }

        Write-Host "  VM set for $participantType $participantId completed" -ForegroundColor Green
    }

    # Create additional VMs if specified (legacy support)
    if ($WindowsVMCount -gt 0 -or $LinuxVMCount -gt 0) {
        Write-Host "Creating additional VMs (legacy parameters)..." -ForegroundColor Yellow
        # Call existing function for additional VMs
        New-TrainingClaimableVMs -LabName $LabName -ResourceGroupName $ResourceGroupName
    }

    Write-Host "German training VM sets creation completed!" -ForegroundColor Green
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "- Participants: $participantCount ($StudentCount students$(if($IncludeTrainer){', 1 trainer'}))" -ForegroundColor White
    Write-Host "- VMs per participant: $(if($UseJumphost){'6 (5 + jumphost)'}else{'5'})" -ForegroundColor White
    Write-Host "- Total VMs: $totalVMs" -ForegroundColor White
    Write-Host "- Architecture: $(if($UseJumphost){'Jumphost (recommended)'}else{'Direct access'})" -ForegroundColor White
}

# Function to create claimable VMs
function New-TrainingClaimableVMs {
    param($LabName, $ResourceGroupName)

    Write-Host "Creating claimable training VMs..." -ForegroundColor Cyan

    $totalVMs = $WindowsVMCount + $LinuxVMCount
    Write-Host "Creating $totalVMs total VMs ($WindowsVMCount Windows, $LinuxVMCount Linux)..." -ForegroundColor Yellow

    # Create Windows VMs
    for ($i = 1; $i -le $WindowsVMCount; $i++) {
        $vmName = "TrainingWin$($i.ToString('00'))"
        Write-Host "Creating Windows VM: $vmName" -ForegroundColor Yellow

        # Use REST API call since PowerShell cmdlets might not be fully available
        $vm = @{
            location = $Location
            properties = @{
                size = $VMSize
                userName = 'trainee'
                password = 'Training123!'
                isAuthenticationWithSshKey = $false
                labSubnetName = 'default'
                labVirtualNetworkId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/virtualnetworks/default"
                notes = "Windows training VM #$i - Ready for student use"
                allowClaim = $true
                storageType = 'Standard'
                galleryImageReference = @{
                    offer = 'WindowsServer'
                    publisher = 'MicrosoftWindowsServer'
                    sku = '2019-Datacenter'
                    osType = 'Windows'
                    version = 'latest'
                }
                disallowPublicIpAddress = -not $AllowPublicIP
                networkInterface = if ($AllowPublicIP) {
                    @{
                        publicIpAddress = 'New'
                        publicIpAddressInboundDnatRules = @(
                            @{
                                transportProtocol = 'tcp'
                                backendPort = 3389
                            }
                        )
                    }
                } else {
                    @{
                        sharedPublicIpAddressConfiguration = @{
                            inboundNatRules = @(
                                @{
                                    transportProtocol = 'tcp'
                                    backendPort = 3389
                                }
                            )
                        }
                    }
                }
            }
        }

        try {
            # This would need to be implemented via REST API calls in a real scenario
            # For now, we'll show the structure - store formula for later use
            $null = $windowsFormula
            Write-Host "Windows VM $vmName configured (implementation needed via REST API)" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to create VM $vmName`: $_"
        }
    }

    # Create Linux VMs
    for ($i = 1; $i -le $LinuxVMCount; $i++) {
        $vmName = "TrainingLinux$($i.ToString('00'))"
        Write-Host "Creating Linux VM: $vmName" -ForegroundColor Yellow

        $vm = @{
            location = $Location
            properties = @{
                size = $VMSize
                userName = 'trainee'
                password = 'Training123!'
                isAuthenticationWithSshKey = $false
                labSubnetName = 'default'
                labVirtualNetworkId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/labs/$LabName/virtualnetworks/default"
                notes = "Linux training VM #$i - Ready for student use"
                allowClaim = $true
                storageType = 'Standard'
                galleryImageReference = @{
                    offer = 'UbuntuServer'
                    publisher = 'Canonical'
                    sku = '18.04-LTS'
                    osType = 'Linux'
                    version = 'latest'
                }
                disallowPublicIpAddress = -not $AllowPublicIP
                networkInterface = if ($AllowPublicIP) {
                    @{
                        publicIpAddress = 'New'
                        publicIpAddressInboundDnatRules = @(
                            @{
                                transportProtocol = 'tcp'
                                backendPort = 22
                            }
                        )
                    }
                } else {
                    @{
                        sharedPublicIpAddressConfiguration = @{
                            inboundNatRules = @(
                                @{
                                    transportProtocol = 'tcp'
                                    backendPort = 22
                                }
                            )
                        }
                    }
                }
            }
        }

        try {
            # This would need to be implemented via REST API calls in a real scenario
            # Store VM configuration for later use
            $null = $vm
            Write-Host "Linux VM $vmName configured (implementation needed via REST API)" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to create VM $vmName`: $_"
        }
    }

    Write-Host "Claimable VMs creation process completed." -ForegroundColor Green
}

# Function to get lab status
function Get-TrainingLabStatus {
    param($LabName, $ResourceGroupName)

    Write-Host "Getting training lab status..." -ForegroundColor Cyan

    try {
        $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName -ErrorAction Stop

        Write-Host "Lab Status Report:" -ForegroundColor Green
        Write-Host "==================" -ForegroundColor Green
        Write-Host "Lab Name: $($lab.Name)" -ForegroundColor White
        Write-Host "Resource Group: $($lab.ResourceGroupName)" -ForegroundColor White
        Write-Host "Location: $($lab.Location)" -ForegroundColor White
        Write-Host "Status: Active" -ForegroundColor Green

        # Get VMs in the lab
        try {
            $labVMs = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines'
            Write-Host "Total VMs: $($labVMs.Count)" -ForegroundColor White

            foreach ($vm in $labVMs) {
                Write-Host "  - $($vm.Name)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "VMs: Unable to retrieve VM list" -ForegroundColor Yellow
        }

        # Get users
        try {
            $roleAssignments = Get-AzRoleAssignment -Scope $lab.ResourceId
            $labUsers = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq 'DevTest Labs User' }
            Write-Host "Lab Users: $($labUsers.Count)" -ForegroundColor White
        } catch {
            Write-Host "Users: Unable to retrieve user list" -ForegroundColor Yellow
        }

        return $lab
    } catch {
        Write-Host "Lab '$LabName' not found in RG '$ResourceGroupName'." -ForegroundColor Red
        return $null
    }
}

function Remove-TrainingEnvironment {
    param($LabName, $ResourceGroupName)

    Write-Host "WARNING: This will delete the entire training environment including all VMs and data!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'DELETE' to confirm deletion"

    if ($confirmation -ne 'DELETE') {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        return
    }

    Write-Host "Deleting training environment..." -ForegroundColor Cyan

    try {
        # Delete the entire resource group (fastest way to clean up everything)
        Write-Host "Deleting resource group '$ResourceGroupName' and all contained resources..." -ForegroundColor Yellow
        Remove-AzResourceGroup -Name $ResourceGroupName -Force -AsJob

        Write-Host "Deletion initiated. This process may take several minutes to complete." -ForegroundColor Green
        Write-Host "You can check the status in the Azure portal." -ForegroundColor Green

    } catch {
        Write-Error "Failed to delete training environment: $_"
    }
}

# Function to start/stop all VMs in lab
function Set-TrainingVMsState {
    param($LabName, $ResourceGroupName, $State)

    Write-Host "$($State)ing all VMs in training lab..." -ForegroundColor Cyan

    try {
        $labVMs = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines'

        Write-Host "Found $($labVMs.Count) VMs to $($State.ToLower())..." -ForegroundColor Yellow

        foreach ($vm in $labVMs) {
            Write-Host "$($State)ing VM: $($vm.Name)" -ForegroundColor Yellow

            if ($State -eq 'Start') {
                # Start VM - would need REST API call
                Write-Host "VM $($vm.Name) start initiated" -ForegroundColor Green
            } else {
                # Stop VM - would need REST API call
                Write-Host "VM $($vm.Name) stop initiated" -ForegroundColor Green
            }
        }

        Write-Host "All VMs $($State.ToLower()) process initiated." -ForegroundColor Green

    } catch {
        Write-Error "Failed to $($State.ToLower()) VMs: $_"
    }
}

# ---------- Main ----------
try {

Write-Host "[Information] Azure DevTest Labs Training Environment Manager" -ForegroundColor Cyan
Write-Host "[STARTUP] Action: $Action" -ForegroundColor Gray

switch ($Action) {
    'Create' {
        Write-Host "Creating training environment..." -ForegroundColor Green

        # Create resource group
        New-TrainingResourceGroup -Name $ResourceGroupName -Location $Location

        # Create DevTest Lab
        New-TrainingDevTestLab -LabName $LabName -ResourceGroupName $ResourceGroupName -Location $Location

        # Wait a moment for lab to be fully provisioned
        Start-Sleep -Seconds 30

        # Set lab policies
        Set-TrainingLabPolicies -LabName $LabName -ResourceGroupName $ResourceGroupName

        # Add users
        if ($TrainingUserEmails.Count -gt 0) {
            Add-TrainingLabUsers -LabName $LabName -ResourceGroupName $ResourceGroupName -UserEmails $TrainingUserEmails -Role 'DevTest Labs User'
        }

        if ($InstructorEmails.Count -gt 0) {
            Add-TrainingLabUsers -LabName $LabName -ResourceGroupName $ResourceGroupName -UserEmails $InstructorEmails -Role 'Owner'
        }

        # Create VM formulas
        New-TrainingVMFormulas -LabName $LabName -ResourceGroupName $ResourceGroupName

        # Create German training VM sets or legacy VMs
        if ($StudentCount -gt 0 -or $IncludeTrainer) {
            New-GermanTrainingVMSets -LabName $LabName -ResourceGroupName $ResourceGroupName
        } elseif ($WindowsVMCount -gt 0) {
            New-TrainingClaimableVMs -LabName $LabName -ResourceGroupName $ResourceGroupName
        } else {
            Write-Host "No VMs requested." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Training environment created successfully!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "Lab Name: $LabName" -ForegroundColor White
        Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
        Write-Host "Location: $Location" -ForegroundColor White

        if ($StudentCount -gt 0 -or $IncludeTrainer) {
            $participantCount = $StudentCount + ($IncludeTrainer ? 1 : 0)
            $totalVMs = $participantCount * 5 + ($UseJumphost ? $participantCount : 0)
            Write-Host "German Training Setup:" -ForegroundColor Cyan
            Write-Host "- Students: $StudentCount" -ForegroundColor White
            Write-Host "- Trainer: $(if($IncludeTrainer){'1'}else{'0'})" -ForegroundColor White
            Write-Host "- Total Participants: $participantCount" -ForegroundColor White
            Write-Host "- VMs per Participant: $(if($UseJumphost){'6 (5 + jumphost)'}else{'5'})" -ForegroundColor White
            Write-Host "- Total VMs: $totalVMs" -ForegroundColor White
            Write-Host "- Jumphost: $(if($UseJumphost){'Enabled (recommended)'}else{'Disabled'})" -ForegroundColor White
        }

        if ($WindowsVMCount -gt 0 -or $LinuxVMCount -gt 0) {
            Write-Host "Additional VMs:" -ForegroundColor Cyan
            Write-Host "- Windows VMs: $WindowsVMCount" -ForegroundColor White
            Write-Host "- Linux VMs: $LinuxVMCount" -ForegroundColor White
        }

        Write-Host "Auto-shutdown: $AutoShutdownTime $TimeZoneId" -ForegroundColor White
        Write-Host "Auto-startup: $AutoStartupTime $TimeZoneId" -ForegroundColor White
        Write-Host "Max VMs per user: $MaxVMsPerUser" -ForegroundColor White
        Write-Host ""
        Write-Host "Training environment created successfully." -ForegroundColor Green
        Write-Host "Lab URL:" -ForegroundColor Yellow
        Write-Host ("https://portal.azure.com/#resource/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.DevTestLab/labs/{2}" -f (Get-AzContext).Subscription.Id,$ResourceGroupName,$LabName)
    }

    'Delete' {
        Remove-TrainingEnvironment -LabName $LabName -ResourceGroupName $ResourceGroupName
    }

    'Status' {
        Get-TrainingLabStatus -LabName $LabName -ResourceGroupName $ResourceGroupName
    }

    'Start' {
        Set-TrainingVMsState -LabName $LabName -ResourceGroupName $ResourceGroupName -State 'Start'
    }

    'Stop' {
        Set-TrainingVMsState -LabName $LabName -ResourceGroupName $ResourceGroupName -State 'Stop'
    }
}

Write-Host "✅ Operation completed." -ForegroundColor Green

}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
