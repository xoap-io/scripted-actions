<#
.SYNOPSIS
    Bulk stop all running Nutanix VMs in a cluster using the Nutanix Prism Central v3 REST API.

.DESCRIPTION
    This script discovers all RUNNING virtual machines via the Nutanix Prism Central v3
    REST API (GET /vms), optionally filtered by cluster name. It then gracefully stops
    each VM using a POST /vms/{uuid}/acpi_shutdown request. Falls back to power_off if
    ACPI shutdown is not available.

    A self-signed certificate bypass is applied using PowerShell's -SkipCertificateCheck
    (PowerShell 7+) or an inline X509 callback (Windows PowerShell 5.1). Writes a
    timestamped log file (nutanix-cli-stop-vms-YYYYMMDD-HHmmss.log).

.PARAMETER PrismCentralHost
    The hostname or IP address of the Nutanix Prism Central instance.

.PARAMETER Username
    The Prism Central username to authenticate with.

.PARAMETER Password
    The Prism Central password as a SecureString.

.PARAMETER ClusterName
    Optional cluster name to filter VMs. If omitted, VMs from all clusters are targeted.

.PARAMETER WhatIf
    Show which VMs would be stopped without making any changes.

.PARAMETER Force
    Skip the 'YES' confirmation prompt and stop VMs immediately.

.EXAMPLE
    $pwd = Read-Host "Password" -AsSecureString
    .\nutanix-cli-stop-vms.ps1 -PrismCentralHost prism.example.com -Username admin -Password $pwd -WhatIf
    Shows all running Nutanix VMs that would be stopped without making changes.

.EXAMPLE
    $pwd = ConvertTo-SecureString "MyP@ssw0rd" -AsPlainText -Force
    .\nutanix-cli-stop-vms.ps1 -PrismCentralHost 10.0.0.100 -Username admin -Password $pwd -ClusterName "Cluster01" -Force
    Stops all running VMs on Cluster01 without a confirmation prompt.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell REST API (Nutanix Prism Central v3)

.LINK
    https://www.nutanix.dev/api_references/prism-central-v3/

.COMPONENT
    Nutanix Prism Central REST API
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The hostname or IP address of the Nutanix Prism Central instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentralHost,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central username to authenticate with.")]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central password as a SecureString.")]
    [System.Security.SecureString]$Password,

    [Parameter(HelpMessage = "Optional cluster name to filter VMs. If omitted, VMs from all clusters are targeted.")]
    [string]$ClusterName,

    [Parameter(HelpMessage = "Show which VMs would be stopped without making any changes.")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip the 'YES' confirmation prompt and stop VMs immediately.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LogFile = "nutanix-cli-stop-vms-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
}

function Enable-SelfSignedCerts {
    # For Windows PowerShell 5.1: bypass SSL certificate validation
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
            Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) { return true; }
}
"@
        }
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol  = [System.Net.SecurityProtocolType]::Tls12
    }
}

function Invoke-PrismRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [string]$BasicAuth,
        [hashtable]$Body
    )
    $headers = @{
        'Authorization' = "Basic $BasicAuth"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
    }
    $invokeParams = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
    }
    if ($Body) {
        $invokeParams['Body'] = ($Body | ConvertTo-Json -Depth 10)
    }

    # PowerShell 7+ supports -SkipCertificateCheck natively
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $invokeParams['SkipCertificateCheck'] = $true
    }

    return Invoke-RestMethod @invokeParams
}

try {
    Write-Log '===== Nutanix Prism Central Bulk VM Stop Script Started =====' -Color Blue
    Write-Log "Log file:          $LogFile" -Color Cyan
    Write-Log "Prism Central:     $PrismCentralHost" -Color Cyan

    # Enable self-signed cert bypass for Windows PowerShell 5.1
    Enable-SelfSignedCerts

    # Build base64 basic auth credential
    $bstr     = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $plainPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $credentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("${Username}:${plainPwd}"))
    $plainPwd    = $null

    $baseUri = "https://${PrismCentralHost}:9440/api/nutanix/v3"

    # Discover VMs using paginated API
    Write-Log '🔍 Discovering VMs via Prism Central v3 API...' -Color Cyan
    $allVms  = [System.Collections.Generic.List[object]]::new()
    $offset  = 0
    $length  = 500

    do {
        $listBody = @{
            kind   = 'vm'
            offset = $offset
            length = $length
        }
        $response   = Invoke-PrismRequest -Method POST -Uri "$baseUri/vms/list" -BasicAuth $credentials -Body $listBody
        $entities   = $response.entities
        $totalMatch = $response.metadata.total_matches

        if ($entities) {
            foreach ($vm in $entities) {
                $allVms.Add($vm) | Out-Null
            }
        }
        $offset += $length
    } while ($offset -lt $totalMatch)

    Write-Log "Total VMs found: $($allVms.Count)" -Color Cyan

    # Filter to RUNNING VMs only
    $runningVms = @($allVms | Where-Object { $_.status.resources.power_state -eq 'ON' })

    # Optional cluster name filter
    if ($ClusterName) {
        Write-Log "Cluster filter: $ClusterName" -Color Cyan
        $runningVms = @($runningVms | Where-Object {
            $_.status.cluster_reference.name -eq $ClusterName
        })
    }

    if ($runningVms.Count -eq 0) {
        Write-Log 'ℹ️  No RUNNING VMs found matching the criteria.' -Color Yellow
        exit 0
    }

    Write-Log "Found $($runningVms.Count) RUNNING VM(s):" -Color Cyan
    foreach ($vm in $runningVms) {
        $clName = $vm.status.cluster_reference.name
        Write-Log "   • $($vm.status.name) | UUID: $($vm.metadata.uuid) | Cluster: $clName" -Color White
    }

    if ($WhatIf) {
        Write-Log '🔍 WhatIf mode — no VMs will be stopped.' -Color Cyan
        exit 0
    }

    # Confirmation prompt
    if (-not $Force) {
        Write-Log '' -Color White
        Write-Log "⚠️  About to stop $($runningVms.Count) RUNNING VM(s) on Prism Central '$PrismCentralHost'." -Color Yellow
        $confirmation = Read-Host "Type 'YES' to confirm"
        if ($confirmation -ne 'YES') {
            Write-Log 'Operation cancelled by user.' -Color Yellow
            exit 0
        }
    }

    # Stop each VM via ACPI shutdown
    Write-Log '🛑 Stopping VMs via ACPI shutdown...' -Color Cyan
    $stoppedUuids = [System.Collections.Generic.List[string]]::new()

    foreach ($vm in $runningVms) {
        $uuid   = $vm.metadata.uuid
        $vmName = $vm.status.name
        Write-Log "   Stopping: $vmName ($uuid)..." -Color Cyan
        try {
            $actionBody = @{ action = 'ACPI_SHUTDOWN' }
            Invoke-PrismRequest -Method POST -Uri "$baseUri/vms/$uuid/acpi_shutdown" -BasicAuth $credentials -Body $actionBody | Out-Null
            Write-Log "   ✅ ACPI shutdown initiated: $vmName" -Color Green
            $stoppedUuids.Add($uuid) | Out-Null
        }
        catch {
            Write-Log "   ⚠️  ACPI shutdown failed for $vmName, attempting power_off: $($_.Exception.Message)" -Color Yellow
            try {
                $powerOffBody = @{
                    spec = @{
                        resources = @{ power_state = 'OFF' }
                        name      = $vmName
                    }
                    metadata = @{ kind = 'vm'; uuid = $uuid }
                }
                Invoke-PrismRequest -Method PUT -Uri "$baseUri/vms/$uuid" -BasicAuth $credentials -Body $powerOffBody | Out-Null
                Write-Log "   ✅ Power off initiated: $vmName" -Color Green
                $stoppedUuids.Add($uuid) | Out-Null
            }
            catch {
                Write-Log "   ❌ Failed to stop $vmName ($uuid): $($_.Exception.Message)" -Color Red
            }
        }
    }

    # Post-verification: re-query and confirm VMs are no longer RUNNING
    Write-Log '' -Color White
    Write-Log '🔎 Verifying VMs have stopped (waiting up to 5 minutes)...' -Color Cyan
    $maxWait  = 300
    $waited   = 0
    $interval = 20

    do {
        Start-Sleep -Seconds $interval
        $waited += $interval

        $verifyBody = @{ kind = 'vm'; offset = 0; length = 500 }
        $verifyResp = Invoke-PrismRequest -Method POST -Uri "$baseUri/vms/list" -BasicAuth $credentials -Body $verifyBody
        $stillOn    = @($verifyResp.entities | Where-Object {
            $_.metadata.uuid -in $stoppedUuids -and
            $_.status.resources.power_state -eq 'ON'
        })
        Write-Log "   Waiting... $($stillOn.Count) VM(s) still RUNNING ($waited/$maxWait s)" -Color Gray
    } while ($stillOn.Count -gt 0 -and $waited -lt $maxWait)

    if ($stillOn.Count -gt 0) {
        Write-Log "   ⚠️  $($stillOn.Count) VM(s) are still RUNNING after $maxWait seconds:" -Color Yellow
        foreach ($v in $stillOn) {
            Write-Log "      • $($v.status.name) ($($v.metadata.uuid))" -Color Yellow
        }
    }
    else {
        Write-Log '   ✅ Verified: no targeted VMs are still RUNNING.' -Color Green
    }

    Write-Log '' -Color White
    Write-Log '===== Operation Complete =====' -Color White
    Write-Log "Prism Central: $PrismCentralHost" -Color White
    Write-Log "VMs stopped:   $($stoppedUuids.Count)" -Color White
    Write-Log "Log file:      $LogFile" -Color Gray
    Write-Log '==============================' -Color White
}
catch {
    Write-Log "❌ Script failed: $($_.Exception.Message)" -Color Red
    exit 1
}
finally {
    Write-Log '' -Color White
    Write-Log '🏁 Script execution completed' -Color Green
}
