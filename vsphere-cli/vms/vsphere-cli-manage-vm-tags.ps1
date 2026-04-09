<#
.SYNOPSIS
    Assign, remove, or list tags on vSphere VMs using VMware PowerCLI.

.DESCRIPTION
    This script manages vSphere tag assignments on virtual machines using the
    New-TagAssignment, Remove-TagAssignment, and Get-TagAssignment PowerCLI cmdlets.
    Three actions are supported:
      List   - Display all tag assignments on the specified VM
      Assign - Assign a tag (by name and optionally category) to the VM
      Remove - Remove a tag assignment from the VM

.PARAMETER Server
    The vCenter Server FQDN or IP address.

.PARAMETER Credential
    PSCredential object for authenticating to vCenter.

.PARAMETER VmName
    The name of the virtual machine to manage tags on.

.PARAMETER Action
    The tag operation to perform. Valid values: Assign, Remove, List.
    Default: List

.PARAMETER TagName
    The name of the tag to assign or remove. Required for Assign and Remove actions.

.PARAMETER CategoryName
    The tag category name used to disambiguate tags with the same name in different categories.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-manage-vm-tags.ps1 -Server "vcenter.domain.com" -Credential $cred -VmName "WebServer01" -Action List

    List all tags assigned to WebServer01.

.EXAMPLE
    $cred = Get-Credential
    .\vsphere-cli-manage-vm-tags.ps1 -Server "vcenter.domain.com" -Credential $cred -VmName "WebServer01" -Action Assign -TagName "Production" -CategoryName "Environment"

    Assign the Production tag to WebServer01.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: VMware.PowerCLI (Install-Module -Name VMware.PowerCLI)

.LINK
    https://developer.vmware.com/docs/powercli/

.COMPONENT
    VMware vSphere PowerCLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The vCenter Server FQDN or IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$Server,

    [Parameter(Mandatory = $true, HelpMessage = "PSCredential object for authenticating to vCenter.")]
    [ValidateNotNull()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the virtual machine to manage tags on.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "The tag operation to perform. Valid values: Assign, Remove, List.")]
    [ValidateSet('Assign', 'Remove', 'List')]
    [string]$Action = 'List',

    [Parameter(Mandatory = $false, HelpMessage = "The name of the tag to assign or remove. Required for Assign and Remove actions.")]
    [string]$TagName,

    [Parameter(Mandatory = $false, HelpMessage = "The tag category name to disambiguate tags with the same name.")]
    [string]$CategoryName
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting vSphere VM tag management..." -ForegroundColor Green

    # Import PowerCLI module
    Write-Host "🔍 Loading VMware.PowerCLI module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name VMware.PowerCLI -ListAvailable)) {
        throw "VMware.PowerCLI module is not installed. Install it with: Install-Module -Name VMware.PowerCLI"
    }
    Import-Module VMware.PowerCLI -ErrorAction Stop
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope User | Out-Null
    Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope User | Out-Null

    # Connect to vCenter
    Write-Host "🔍 Connecting to vCenter Server '$Server'..." -ForegroundColor Cyan
    $connection = Connect-VIServer -Server $Server -Credential $Credential -Force
    Write-Host "✅ Connected to: $($connection.Name)" -ForegroundColor Green

    # Get VM
    Write-Host "🔍 Locating VM '$VmName'..." -ForegroundColor Cyan
    $vm = Get-VM -Name $VmName -ErrorAction Stop
    if (-not $vm) { throw "VM '$VmName' not found." }
    Write-Host "✅ VM found: $($vm.Name) (Power state: $($vm.PowerState))" -ForegroundColor Green

    # Validate TagName for Assign/Remove
    if ($Action -in 'Assign', 'Remove' -and -not $TagName) {
        throw "TagName is required when Action is '$Action'."
    }

    switch ($Action) {
        'List' {
            Write-Host "🔍 Retrieving tag assignments for '$VmName'..." -ForegroundColor Cyan
            $assignments = Get-TagAssignment -Entity $vm

            if ($assignments.Count -eq 0) {
                Write-Host "ℹ️  No tags assigned to '$VmName'." -ForegroundColor Yellow
            }
            else {
                Write-Host "✅ Found $($assignments.Count) tag assignment(s):" -ForegroundColor Green
                $assignments | Select-Object @{N='Tag'; E={$_.Tag.Name}}, @{N='Category'; E={$_.Tag.Category.Name}} | Format-Table -AutoSize
            }
        }

        'Assign' {
            Write-Host "🔧 Assigning tag '$TagName' to VM '$VmName'..." -ForegroundColor Cyan
            $tagParams = @{ Name = $TagName }
            if ($CategoryName) { $tagParams.Category = $CategoryName }
            $tag = Get-Tag @tagParams -ErrorAction Stop
            if (-not $tag) { throw "Tag '$TagName' not found." }

            New-TagAssignment -Entity $vm -Tag $tag -ErrorAction Stop | Out-Null
            Write-Host "✅ Tag '$TagName' assigned to '$VmName' successfully." -ForegroundColor Green
        }

        'Remove' {
            Write-Host "🔧 Removing tag '$TagName' from VM '$VmName'..." -ForegroundColor Cyan
            $assignments = Get-TagAssignment -Entity $vm | Where-Object { $_.Tag.Name -eq $TagName }
            if ($CategoryName) {
                $assignments = $assignments | Where-Object { $_.Tag.Category.Name -eq $CategoryName }
            }

            if (-not $assignments) {
                Write-Host "⚠️  Tag '$TagName' is not assigned to '$VmName'. No action taken." -ForegroundColor Yellow
            }
            else {
                $assignments | Remove-TagAssignment -Confirm:$false
                Write-Host "✅ Tag '$TagName' removed from '$VmName' successfully." -ForegroundColor Green
            }
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($global:DefaultVIServers) {
        Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction SilentlyContinue
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
