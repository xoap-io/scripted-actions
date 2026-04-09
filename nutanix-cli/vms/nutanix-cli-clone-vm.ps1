<#
.SYNOPSIS
    Clone an existing Nutanix VM using the Prism Central REST API v3.

.DESCRIPTION
    This script clones an existing Nutanix AHV virtual machine using the Prism Central REST API v3.
    It first queries GET /vms to find the source VM by name, retrieves its UUID, then calls
    POST /vms/{uuid}/clone to create one or more clones. Authentication uses HTTP Basic auth.
    Self-signed certificates are accepted via -SkipCertificateCheck (PowerShell 7+).

.PARAMETER PrismCentralHost
    The FQDN or IP address of the Prism Central instance.

.PARAMETER Username
    The Prism Central username for authentication.

.PARAMETER Password
    The Prism Central password as a SecureString.

.PARAMETER SourceVmName
    The name of the source VM to clone.

.PARAMETER CloneName
    The base name for the cloned VM(s). When NumClones > 1, a numeric suffix is appended.

.PARAMETER NumClones
    The number of clones to create (1-10). Default: 1

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-clone-vm.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -SourceVmName "TemplateVM" -CloneName "AppServer"

    Clone TemplateVM once, creating AppServer.

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-clone-vm.ps1 -PrismCentralHost "10.0.0.10" -Username "admin" -Password $pass -SourceVmName "BaseVM" -CloneName "WebNode" -NumClones 3

    Clone BaseVM three times, creating WebNode-1, WebNode-2, WebNode-3.

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the source VM to clone.")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceVmName,

    [Parameter(Mandatory = $true, HelpMessage = "The base name for the cloned VM(s). A numeric suffix is appended when NumClones > 1.")]
    [ValidateNotNullOrEmpty()]
    [string]$CloneName,

    [Parameter(Mandatory = $false, HelpMessage = "The number of clones to create (1-10).")]
    [ValidateRange(1, 10)]
    [int]$NumClones = 1
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
        Method                  = $Method
        Uri                     = $uri
        Headers                 = $headers
        SkipCertificateCheck    = $true
    }
    if ($Body) {
        $invokeParams.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    return Invoke-RestMethod @invokeParams
}

try {
    Write-Host "🚀 Starting Nutanix VM clone operation..." -ForegroundColor Green
    Write-Host "ℹ️  Prism Central: $PrismCentralHost" -ForegroundColor Yellow
    Write-Host "ℹ️  Source VM: $SourceVmName" -ForegroundColor Yellow
    Write-Host "ℹ️  Clone name base: $CloneName" -ForegroundColor Yellow
    Write-Host "ℹ️  Number of clones: $NumClones" -ForegroundColor Yellow

    # Find source VM UUID
    Write-Host "🔍 Searching for source VM '$SourceVmName'..." -ForegroundColor Cyan
    $listBody = @{
        kind   = 'vm'
        length = 500
        filter = "vm_name==$SourceVmName"
    }
    $listResponse = Invoke-NutanixApi -Method POST -Endpoint '/vms/list' -Body $listBody
    $sourceVm = $listResponse.entities | Where-Object { $_.status.name -eq $SourceVmName } | Select-Object -First 1

    if (-not $sourceVm) {
        throw "Source VM '$SourceVmName' not found in Prism Central."
    }

    $sourceUuid = $sourceVm.metadata.uuid
    Write-Host "✅ Found source VM '$SourceVmName' with UUID: $sourceUuid" -ForegroundColor Green

    # Create clones
    $results = @()
    for ($i = 1; $i -le $NumClones; $i++) {
        $targetName = if ($NumClones -eq 1) { $CloneName } else { "$CloneName-$i" }
        Write-Host "🔧 Creating clone '$targetName' ($i/$NumClones)..." -ForegroundColor Cyan

        $cloneBody = @{
            spec_list = @(
                @{ name = $targetName }
            )
        }

        $cloneResponse = Invoke-NutanixApi -Method POST -Endpoint "/vms/$sourceUuid/clone" -Body $cloneBody
        $taskUuid = $cloneResponse.task_uuid

        Write-Host "✅ Clone task submitted for '$targetName'. Task UUID: $taskUuid" -ForegroundColor Green
        $results += [PSCustomObject]@{
            CloneName = $targetName
            TaskUuid  = $taskUuid
        }
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    $results | Format-Table -AutoSize
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Clear plain text password from memory
    if ($plainPassword) { $plainPassword = $null }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
