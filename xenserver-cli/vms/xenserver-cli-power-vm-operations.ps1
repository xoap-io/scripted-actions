<#
.SYNOPSIS
    Performs power operations on XenServer virtual machines using XenServerPSModule.

.DESCRIPTION
    This script performs various power operations on VMs including start, stop, restart, suspend, and reset.
    Supports single VMs, multiple VMs by name pattern, or VMs in a specific pool.
    Uses the XenServer PowerShell SDK module for all operations.

.PARAMETER Server
    The XenServer pool coordinator hostname or IP address.

.PARAMETER Username
    Username for authentication (default: root).

.PARAMETER Password
    Password for authentication.

.PARAMETER VMName
    The name of the virtual machine(s). Supports exact match.

.PARAMETER VMUUID
    The UUID of the virtual machine to operate on.

.PARAMETER VMNames
    An array of specific VM names for batch operations.

.PARAMETER Operation
    The power operation to perform: Start, Stop, Shutdown, Reboot, Suspend, Resume, Pause, Unpause.

.PARAMETER Force
    Force the operation without confirmation prompts (hard power operations).

.PARAMETER Async
    Run operations asynchronously and return task objects.

.PARAMETER TimeoutSeconds
    Timeout in seconds for operation completion (default: 300).

.EXAMPLE
    .\xenserver-cli-power-vm-operations.ps1 -Server "xenserver.domain.com" -VMName "WebServer01" -Operation "Start"

.EXAMPLE
    .\xenserver-cli-power-vm-operations.ps1 -Server "xenserver.domain.com" -VMUUID "12345678-abcd-1234-abcd-123456789012" -Operation "Shutdown"

.EXAMPLE
    .\xenserver-cli-power-vm-operations.ps1 -Server "xenserver.domain.com" -VMNames @("VM01","VM02","VM03") -Operation "Start" -Async

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: XenServerPSModule (Citrix XenServer SDK)

.LINK
    https://docs.xenserver.com/en-us/xenserver/current-release/vms/manage.html

.COMPONENT
    Citrix XenServer PowerShell
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The XenServer pool coordinator hostname or IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$Server,

    [Parameter(Mandatory = $false, HelpMessage = "Username for authentication (default: root).")]
    [string]$Username = "root",

    [Parameter(Mandatory = $false, HelpMessage = "Password for authentication.")]
    [string]$Password,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVM", HelpMessage = "The name of the virtual machine. Supports exact match.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [Parameter(Mandatory = $false, ParameterSetName = "SingleVMUUID", HelpMessage = "The UUID of the virtual machine to operate on.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$VMUUID,

    [Parameter(Mandatory = $false, ParameterSetName = "MultipleVMs", HelpMessage = "An array of specific VM names for batch operations.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VMNames,

    [Parameter(Mandatory = $true, HelpMessage = "The power operation to perform: Start, Stop, Shutdown, Reboot, Suspend, Resume, Pause, Unpause.")]
    [ValidateSet("Start", "Stop", "Shutdown", "Reboot", "Suspend", "Resume", "Pause", "Unpause")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "Force the operation without confirmation prompts (hard power operations).")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Run operations asynchronously and return task objects.")]
    [switch]$Async,

    [Parameter(Mandatory = $false, HelpMessage = "Timeout in seconds for operation completion (default: 300).")]
    [ValidateRange(30, 3600)]
    [int]$TimeoutSeconds = 300
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to check and install XenServerPSModule if needed
function Test-XenServerModuleInstallation {
    Write-Verbose "Checking for XenServerPSModule..."

    if (-not (Get-Module -ListAvailable -Name XenServerPSModule)) {
        Write-Warning "XenServerPSModule not found."
        Write-Host "Please install the XenServer PowerShell SDK from: https://www.xenserver.com/downloads"
        Write-Host "After installation, import the module with: Import-Module XenServerPSModule"
        throw "XenServerPSModule is required but not installed"
    }

    try {
        Import-Module XenServerPSModule -ErrorAction Stop
        Write-Verbose "✓ XenServerPSModule loaded successfully"
    }
    catch {
        throw "Failed to import XenServerPSModule: $_"
    }
}

# Function to connect to XenServer
function Connect-XenServerSession {
    param(
        [string]$ServerUrl,
        [string]$User,
        [string]$Pass
    )

    Write-Verbose "Connecting to XenServer: $ServerUrl"

    try {
        $url = if ($ServerUrl -match '^https?://') { $ServerUrl } else { "https://$ServerUrl" }
        $session = Connect-XenServer -Url $url -UserName $User -Password $Pass -SetDefaultSession -PassThru
        Write-Host "✓ Connected to XenServer: $ServerUrl" -ForegroundColor Green
        return $session
    }
    catch {
        Write-Error "Failed to connect to XenServer: $_"
        throw
    }
}

# Function to perform VM power operation
function Invoke-VMPowerOperation {
    param(
        [object]$VM,
        [string]$Op,
        [bool]$IsAsync
    )

    Write-Host "Performing $Op operation on VM: $($VM.name_label) ($($VM.uuid))..."

    $actionParams = @{
        VM = $VM
        XenAction = switch ($Op) {
            "Start" { [XenAPI.vm_operations]::start }
            "Stop" { [XenAPI.vm_operations]::hard_shutdown }
            "Shutdown" { [XenAPI.vm_operations]::clean_shutdown }
            "Reboot" { [XenAPI.vm_operations]::clean_reboot }
            "Suspend" { [XenAPI.vm_operations]::suspend }
            "Resume" { [XenAPI.vm_operations]::resume }
            "Pause" { [XenAPI.vm_operations]::pause }
            "Unpause" { [XenAPI.vm_operations]::unpause }
            default { throw "Unknown operation: $Op" }
        }
    }

    if ($IsAsync) {
        $actionParams['Async'] = $true
        $actionParams['PassThru'] = $true
    }

    try {
        $result = Invoke-XenVM @actionParams

        if ($IsAsync) {
            Write-Host "✓ $Op operation initiated (Task: $($result.uuid))" -ForegroundColor Green
            return $result
        }
        else {
            Write-Host "✓ $Op operation completed successfully" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Error "Failed to perform $Op operation: $_"
        return $false
    }
}

# Main script execution
try {
    Write-Host "XenServer VM Power Operations Script" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan

    # Check and load XenServer module
    Test-XenServerModuleInstallation

    # Connect to XenServer
    $session = Connect-XenServerSession -ServerUrl $Server -User $Username -Pass $Password

    # Get target VMs
    $targetVMs = @()

    try {
        if ($VMUUID) {
            $targetVMs += Get-XenVM -Uuid $VMUUID
        }
        elseif ($VMName) {
            $targetVMs += Get-XenVM -Name $VMName
        }
        elseif ($VMNames) {
            foreach ($name in $VMNames) {
                $vm = Get-XenVM -Name $name
                if ($vm) { $targetVMs += $vm }
            }
        }
        else {
            throw "No VM specified. Use -VMName, -VMUUID, or -VMNames parameter."
        }
    }
    catch {
        Write-Error "Failed to retrieve VMs: $_"
        throw
    }

    if ($targetVMs.Count -eq 0) {
        throw "No VMs found matching the specified criteria"
    }

    Write-Host "`nTarget VMs: $($targetVMs.Count)" -ForegroundColor Yellow
    foreach ($vm in $targetVMs) {
        Write-Host "  - $($vm.name_label) ($($vm.power_state))" -ForegroundColor Gray
    }

    # Process each VM
    $successCount = 0
    $failureCount = 0
    $tasks = @()

    foreach ($vm in $targetVMs) {
        Write-Host "`nProcessing VM: $($vm.name_label)" -ForegroundColor Cyan
        Write-Host "Current power state: $($vm.power_state)"

        # Perform operation
        $result = Invoke-VMPowerOperation -VM $vm -Op $Operation -IsAsync $Async.IsPresent

        if ($Async.IsPresent) {
            if ($result) {
                $tasks += $result
                $successCount++
            }
            else {
                $failureCount++
            }
        }
        else {
            if ($result) {
                $successCount++
            }
            else {
                $failureCount++
            }
        }
    }

    # Wait for async tasks if requested
    if ($Async.IsPresent -and $tasks.Count -gt 0) {
        Write-Host "`nWaiting for async operations to complete..." -ForegroundColor Yellow
        foreach ($task in $tasks) {
            $task | Wait-XenTask -ShowProgress -PassThru | Out-Null
        }
        Write-Host "✓ All async operations completed" -ForegroundColor Green
    }

    # Summary
    Write-Host "`n======================================" -ForegroundColor Cyan
    Write-Host "Operation Summary:" -ForegroundColor Cyan
    Write-Host "  Total VMs: $($targetVMs.Count)"
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })

    if ($failureCount -gt 0) {
        exit 1
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Disconnect from XenServer
    if ($session) {
        try {
            Get-XenSession | Disconnect-XenServer
            Write-Verbose "Disconnected from XenServer"
        }
        catch {
            Write-Warning "Failed to disconnect from XenServer: $_"
        }
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
