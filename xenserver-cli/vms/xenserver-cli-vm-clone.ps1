<#
.SYNOPSIS
    Clones XenServer virtual machines using XenServerPSModule.

.DESCRIPTION
    This script clones VMs using storage-level fast disk clone operations where available.
    Supports both single VM cloning and batch cloning with automatic naming.

.PARAMETER Server
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Username
    Username for authentication (default: root).

.PARAMETER Password
    Password for authentication.

.PARAMETER VMName
    The source VM name to clone from.

.PARAMETER VMUUID
    The source VM UUID to clone from.

.PARAMETER NewVMName
    The name for the cloned VM.

.PARAMETER NewVMDescription
    Optional description for the cloned VM.

.PARAMETER Count
    Number of clones to create (for batch operations).

.PARAMETER NamePrefix
    Prefix for automatically named clones (used with Count > 1).

.PARAMETER StartNumbering
    Starting number for clone naming (default: 1).

.EXAMPLE
    .\xenserver-cli-vm-clone.ps1 -Server "xenserver.local" -VMName "Template-Ubuntu" -NewVMName "WebServer01"

.EXAMPLE
    .\xenserver-cli-vm-clone.ps1 -Server "xenserver.local" -VMName "Template-Win" -NamePrefix "TestVM" -Count 5

.NOTES
    Author: Generated for scripted-actions
    Requires: XenServerPSModule (PowerShell SDK)
    Version: 2.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $false)]
    [string]$Username = "root",

    [Parameter(Mandatory = $false)]
    [string]$Password,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM")]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVMUUID")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$VMUUID,

    [Parameter(Mandatory = $false)]
    [string]$NewVMName,

    [Parameter(Mandatory = $false)]
    [string]$NewVMDescription = "",

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$Count = 1,

    [Parameter(Mandatory = $false)]
    [string]$NamePrefix = "Clone",

    [Parameter(Mandatory = $false)]
    [int]$StartNumbering = 1
)

$ErrorActionPreference = 'Stop'

# Check and load XenServer module
if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
    throw "XenServerPSModule not found. Please install the XenServer PowerShell SDK."
}
Import-Module XenServerPSModule -ErrorAction Stop

# Main execution
try {
    Write-Host "XenServer VM Clone Script" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan

    # Connect to XenServer
    $url = if ($Server -match '^https?://') { $Server } else { "https://$Server" }
    $session = Connect-XenServer -Url $url -UserName $Username -Password $Password -SetDefaultSession -PassThru
    Write-Host "✓ Connected to XenServer: $Server" -ForegroundColor Green

    # Get source VM
    $sourceVM = if ($VMUUID) {
        Get-XenVM -Uuid $VMUUID
    }
    elseif ($VMName) {
        Get-XenVM -Name $VMName
    }
    else {
        throw "Specify -VMName or -VMUUID"
    }

    if (-not $sourceVM) {
        throw "Source VM not found"
    }

    Write-Host "`nSource VM: $($sourceVM.name_label) ($($sourceVM.uuid))" -ForegroundColor Yellow

    # Clone VMs
    $successCount = 0
    $clonedVMs = @()

    for ($i = 0; $i -lt $Count; $i++) {
        $cloneName = if ($Count -eq 1 -and $NewVMName) {
            $NewVMName
        } else {
            "$NamePrefix$($StartNumbering + $i)"
        }

        Write-Host "`nCloning VM to: $cloneName..." -ForegroundColor Cyan

        try {
            # Use Invoke-XenVM with Clone action
            $cloneRef = Invoke-XenVM -VM $sourceVM -XenAction Clone -NewNameLabel $cloneName -PassThru

            # Get the cloned VM object
            $clonedVM = Get-XenVM -Ref $cloneRef

            # Set description if provided
            if ($NewVMDescription) {
                Set-XenVM -VM $clonedVM -NameDescription $NewVMDescription
            }

            Write-Host "✓ Clone created: $cloneName (UUID: $($clonedVM.uuid))" -ForegroundColor Green
            $clonedVMs += $clonedVM
            $successCount++
        }
        catch {
            Write-Error "Failed to clone VM: $_"
        }
    }

    Write-Host "`n=========================" -ForegroundColor Cyan
    Write-Host "Cloning Summary:" -ForegroundColor Cyan
    Write-Host "  Total: $Count"
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $($Count - $successCount)" -ForegroundColor $(if (($Count - $successCount) -gt 0) { "Red" } else { "Gray" })
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
