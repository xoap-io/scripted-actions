<#
.SYNOPSIS
    Create a VM snapshot in Nutanix using the Prism Central REST API v3.

.DESCRIPTION
    This script creates a snapshot for an existing Nutanix AHV virtual machine using the
    Prism Central REST API v3. It queries GET /vms to find the VM by name, then calls
    POST /vm_snapshots to create the snapshot. Authentication uses HTTP Basic auth.
    Self-signed certificates are accepted via -SkipCertificateCheck (PowerShell 7+).
    If SnapshotName is not provided, a timestamped name is auto-generated.

.PARAMETER PrismCentralHost
    The FQDN or IP address of the Prism Central instance.

.PARAMETER Username
    The Prism Central username for authentication.

.PARAMETER Password
    The Prism Central password as a SecureString.

.PARAMETER VmName
    The name of the VM to snapshot.

.PARAMETER SnapshotName
    The name to assign to the snapshot. If omitted, a timestamped name is auto-generated.

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-snapshot-vm.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -VmName "WebServer01"

    Create a snapshot of WebServer01 with an auto-generated name.

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-snapshot-vm.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -VmName "AppServer" -SnapshotName "AppServer-PrePatch-20260408"

    Create a named snapshot before applying patches.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 7+ (for -SkipCertificateCheck support)

.LINK
    https://www.nutanix.dev/reference/prism_central/v3/

.COMPONENT
    Nutanix REST API PowerShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The FQDN or IP address of the Prism Central instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentralHost,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central username for authentication.")]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central password as a SecureString.")]
    [ValidateNotNull()]
    [SecureString]$Password,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM to snapshot.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "The name to assign to the snapshot. Auto-generated if omitted.")]
    [string]$SnapshotName
)

$ErrorActionPreference = 'Stop'

# Build base URL and auth header
$baseUrl = "https://$PrismCentralHost`:9440/api/nutanix/v3"
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
$encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${plainPassword}"))
$headers = @{
    Authorization  = "Basic $encodedAuth"
    'Content-Type' = 'application/json'
}

function Invoke-NutanixApi {
    param(
        [string]$Method,
        [string]$Endpoint,
        [hashtable]$Body
    )
    $uri = "$baseUrl$Endpoint"
    $invokeParams = @{
        Method               = $Method
        Uri                  = $uri
        Headers              = $headers
        SkipCertificateCheck = $true
    }
    if ($Body) {
        $invokeParams.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    return Invoke-RestMethod @invokeParams
}

try {
    Write-Host "🚀 Starting Nutanix VM snapshot operation..." -ForegroundColor Green
    Write-Host "ℹ️  Prism Central: $PrismCentralHost" -ForegroundColor Yellow
    Write-Host "ℹ️  VM: $VmName" -ForegroundColor Yellow

    # Auto-generate snapshot name if not provided
    if (-not $SnapshotName) {
        $SnapshotName = "$VmName-snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Write-Host "ℹ️  Auto-generated snapshot name: $SnapshotName" -ForegroundColor Yellow
    }
    else {
        Write-Host "ℹ️  Snapshot name: $SnapshotName" -ForegroundColor Yellow
    }

    # Find VM UUID
    Write-Host "🔍 Searching for VM '$VmName'..." -ForegroundColor Cyan
    $listBody = @{
        kind   = 'vm'
        length = 500
        filter = "vm_name==$VmName"
    }
    $listResponse = Invoke-NutanixApi -Method POST -Endpoint '/vms/list' -Body $listBody
    $vm = $listResponse.entities | Where-Object { $_.status.name -eq $VmName } | Select-Object -First 1

    if (-not $vm) {
        throw "VM '$VmName' not found in Prism Central."
    }

    $vmUuid = $vm.metadata.uuid
    Write-Host "✅ Found VM '$VmName' with UUID: $vmUuid" -ForegroundColor Green

    # Create snapshot
    Write-Host "🔧 Creating snapshot '$SnapshotName'..." -ForegroundColor Cyan
    $snapshotBody = @{
        spec = @{
            name      = $SnapshotName
            resources = @{
                entity_uuid = $vmUuid
            }
        }
        metadata = @{
            kind = 'vm_snapshot'
        }
    }

    $response = Invoke-NutanixApi -Method POST -Endpoint '/vm_snapshots' -Body $snapshotBody

    $taskUuid = $response.status.execution_context.task_uuid
    Write-Host "✅ Snapshot '$SnapshotName' creation submitted successfully." -ForegroundColor Green
    if ($taskUuid) {
        Write-Host "ℹ️  Task UUID: $taskUuid" -ForegroundColor Yellow
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  VM Name       : $VmName" -ForegroundColor White
    Write-Host "  VM UUID       : $vmUuid" -ForegroundColor White
    Write-Host "  Snapshot Name : $SnapshotName" -ForegroundColor White
    Write-Host "  Task UUID     : $taskUuid" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($plainPassword) { $plainPassword = $null }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
