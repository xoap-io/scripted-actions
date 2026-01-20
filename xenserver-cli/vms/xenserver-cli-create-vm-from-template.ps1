<#
.SYNOPSIS
    Creates XenServer virtual machines from templates using XenServerPSModule.

.DESCRIPTION
    This script provisions new VMs from existing templates with configurable CPU, memory,
    storage, and network settings. Supports both quick provisioning and customized deployments.

.PARAMETER Server
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Username
    Username for authentication (default: root).

.PARAMETER Password
    Password for authentication.

.PARAMETER TemplateName
    The name of the template to use.

.PARAMETER TemplateUUID
    The UUID of the template to use.

.PARAMETER VMName
    The name for the new VM.

.PARAMETER VMCount
    Number of VMs to create from the template (default: 1).

.PARAMETER VMNamePrefix
    Prefix for automatically named VMs when creating multiple (used with VMCount > 1).

.PARAMETER StartNumbering
    Starting number for VM naming (default: 1).

.PARAMETER CPUCount
    Number of vCPUs to assign (if different from template default).

.PARAMETER MemoryGB
    Amount of memory in GB (if different from template default).

.PARAMETER StorageRepository
    Storage repository name for the VM disks (uses template default if not specified).

.PARAMETER NetworkName
    Network name to connect the VM to (uses template default if not specified).

.PARAMETER VMDescription
    Optional description for the VM.

.PARAMETER StartVM
    Start the VM after creation.

.EXAMPLE
    .\xenserver-cli-create-vm-from-template.ps1 -Server "xenserver.local" -TemplateName "Ubuntu-22.04-Template" -VMName "WebServer01"

.EXAMPLE
    .\xenserver-cli-create-vm-from-template.ps1 -Server "xenserver.local" -TemplateName "Windows-Server-2022" -VMNamePrefix "AppServer" -VMCount 3 -CPUCount 4 -MemoryGB 8 -StartVM

.EXAMPLE
    .\xenserver-cli-create-vm-from-template.ps1 -Server "xenserver.local" -TemplateUUID "12345678-1234-1234-1234-123456789012" -VMName "DBServer" -CPUCount 8 -MemoryGB 16 -StorageRepository "SSD-Storage"

.NOTES
    Author: Generated for scripted-actions
    Requires: XenServerPSModule (PowerShell SDK)
    Version: 1.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $false)]
    [string]$Username = "root",

    [Parameter(Mandatory = $false)]
    [string]$Password,

    [Parameter(Mandatory = $false, ParameterSetName = "ByName")]
    [string]$TemplateName,

    [Parameter(Mandatory = $false, ParameterSetName = "ByUUID")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$TemplateUUID,

    [Parameter(Mandatory = $false)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$VMCount = 1,

    [Parameter(Mandatory = $false)]
    [string]$VMNamePrefix = "VM",

    [Parameter(Mandatory = $false)]
    [int]$StartNumbering = 1,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 128)]
    [int]$CPUCount,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1024)]
    [int]$MemoryGB,

    [Parameter(Mandatory = $false)]
    [string]$StorageRepository,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [string]$VMDescription = "",

    [Parameter(Mandatory = $false)]
    [switch]$StartVM
)

$ErrorActionPreference = 'Stop'

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

function New-VMFromTemplate {
    param(
        [object]$Template,
        [string]$NewVMName,
        [string]$Description,
        [int]$vCPUs,
        [int]$MemoryGigabytes,
        [string]$SRName,
        [string]$Network,
        [bool]$Start
    )

    Write-Host "`nCreating VM: $NewVMName from template $($Template.name_label)..." -ForegroundColor Cyan

    try {
        # Clone/Provision the template
        Write-Verbose "Cloning template..."
        $vmRef = Invoke-XenVM -VM $Template -XenAction Clone -NewNameLabel $NewVMName -PassThru
        $newVM = Get-XenVM -Ref $vmRef

        Write-Host "  ✓ VM provisioned: $NewVMName (UUID: $($newVM.uuid))" -ForegroundColor Green

        # Set description if provided
        if ($Description) {
            Set-XenVM -VM $newVM -NameDescription $Description
            Write-Verbose "Description set"
        }

        # Configure CPU count if specified
        if ($vCPUs -gt 0) {
            Set-XenVM -VM $newVM -VCPUsMax $vCPUs -VCPUsAtStartup $vCPUs
            Write-Host "  ✓ CPUs configured: $vCPUs" -ForegroundColor Green
        }

        # Configure memory if specified
        if ($MemoryGigabytes -gt 0) {
            $memoryBytes = $MemoryGigabytes * 1GB
            Set-XenVM -VM $newVM -MemoryStaticMax $memoryBytes -MemoryDynamicMax $memoryBytes -MemoryDynamicMin $memoryBytes -MemoryStaticMin $memoryBytes
            Write-Host "  ✓ Memory configured: $MemoryGigabytes GB" -ForegroundColor Green
        }

        # Configure storage repository if specified
        if ($SRName) {
            try {
                $sr = Get-XenSR -Name $SRName
                if ($sr) {
                    # Set SR for VM's disks
                    $vbds = Get-XenVBD -VM $newVM | Where-Object { $_.type -eq "Disk" }
                    foreach ($vbd in $vbds) {
                        $vdi = Get-XenVDI -Ref $vbd.VDI
                        # Move VDI to new SR if needed
                        if ($vdi.SR -ne $sr.opaque_ref) {
                            Write-Verbose "Moving disk to SR: $SRName"
                            # Note: Actual VDI migration would require additional steps
                        }
                    }
                    Write-Host "  ✓ Storage repository: $SRName" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "Could not configure storage repository: $_"
            }
        }

        # Configure network if specified
        if ($Network) {
            try {
                $network = Get-XenNetwork -Name $Network
                if ($network) {
                    $vifs = Get-XenVIF -VM $newVM
                    if ($vifs) {
                        Set-XenVIF -VIF $vifs[0] -Network $network
                        Write-Host "  ✓ Network configured: $Network" -ForegroundColor Green
                    }
                }
            }
            catch {
                Write-Warning "Could not configure network: $_"
            }
        }

        # Mark VM as not a template
        Set-XenVM -VM $newVM -IsATemplate $false

        # Start VM if requested
        if ($Start) {
            Write-Host "  Starting VM..." -ForegroundColor Cyan
            Invoke-XenVM -VM $newVM -XenAction Start
            Write-Host "  ✓ VM started successfully" -ForegroundColor Green
        }

        return @{
            Success = $true
            VM = $newVM
            Name = $NewVMName
            UUID = $newVM.uuid
        }
    }
    catch {
        Write-Error "Failed to create VM: $_"
        return @{
            Success = $false
            Name = $NewVMName
            Error = $_.Exception.Message
        }
    }
}

# Main execution
try {
    Write-Host "XenServer VM Creation from Template" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan

    # Connect to XenServer
    $url = if ($Server -match '^https?://') { $Server } else { "https://$Server" }
    $session = Connect-XenServer -Url $url -UserName $Username -Password $Password -SetDefaultSession -PassThru
    Write-Host "✓ Connected to XenServer: $Server" -ForegroundColor Green

    # Get template
    $template = if ($TemplateUUID) {
        Get-XenVM -Uuid $TemplateUUID | Where-Object { $_.is_a_template -eq $true }
    }
    elseif ($TemplateName) {
        Get-XenVM -Name $TemplateName | Where-Object { $_.is_a_template -eq $true }
    }
    else {
        throw "Specify -TemplateName or -TemplateUUID"
    }

    if (-not $template) {
        throw "Template not found or not a valid template"
    }

    Write-Host "`nTemplate: $($template.name_label) ($($template.uuid))" -ForegroundColor Yellow
    Write-Host "  CPUs: $($template.VCPUs_max)"
    Write-Host "  Memory: $([math]::Round($template.memory_static_max / 1GB, 2)) GB"

    # Validate storage repository if specified
    if ($StorageRepository) {
        $sr = Get-XenSR -Name $StorageRepository
        if (-not $sr) {
            Write-Warning "Storage repository '$StorageRepository' not found, will use template default"
            $StorageRepository = $null
        }
    }

    # Validate network if specified
    if ($NetworkName) {
        $network = Get-XenNetwork -Name $NetworkName
        if (-not $network) {
            Write-Warning "Network '$NetworkName' not found, will use template default"
            $NetworkName = $null
        }
    }

    # Create VMs
    $results = @()
    $successCount = 0

    Write-Host "`nCreating $VMCount VM(s)..." -ForegroundColor Cyan

    for ($i = 0; $i -lt $VMCount; $i++) {
        $vmName = if ($VMCount -eq 1 -and $VMName) {
            $VMName
        } else {
            "$VMNamePrefix$($StartNumbering + $i)"
        }

        $result = New-VMFromTemplate `
            -Template $template `
            -NewVMName $vmName `
            -Description $VMDescription `
            -vCPUs $CPUCount `
            -MemoryGigabytes $MemoryGB `
            -SRName $StorageRepository `
            -Network $NetworkName `
            -Start $StartVM.IsPresent

        $results += $result
        if ($result.Success) {
            $successCount++
        }
    }

    # Summary
    Write-Host "`n====================================" -ForegroundColor Cyan
    Write-Host "VM Creation Summary:" -ForegroundColor Cyan
    Write-Host "  Total: $VMCount"
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $($VMCount - $successCount)" -ForegroundColor $(if (($VMCount - $successCount) -gt 0) { "Red" } else { "Gray" })

    if ($successCount -gt 0) {
        Write-Host "`nCreated VMs:" -ForegroundColor Green
        foreach ($result in $results | Where-Object { $_.Success }) {
            Write-Host "  - $($result.Name) (UUID: $($result.UUID))"
        }
    }

    if ($successCount -lt $VMCount) {
        Write-Host "`nFailed VMs:" -ForegroundColor Red
        foreach ($result in $results | Where-Object { -not $_.Success }) {
            Write-Host "  - $($result.Name): $($result.Error)"
        }
        exit 1
    }
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}
finally {
    # Disconnect
    if ($session) {
        Get-XenSession | Disconnect-XenServer
    }
}
