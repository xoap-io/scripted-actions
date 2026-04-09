<#
.SYNOPSIS
    Create a Nutanix volume group using the Prism Central REST API v3.

.DESCRIPTION
    This script creates a new volume group in a Nutanix cluster using the Prism Central
    REST API v3. It calls POST /volume_groups with the specified configuration options
    including shared access and flash mode settings.
    Authentication uses HTTP Basic auth with -SkipCertificateCheck for self-signed certs (PowerShell 7+).

.PARAMETER PrismCentralHost
    The FQDN or IP address of the Prism Central instance.

.PARAMETER Username
    The Prism Central username for authentication.

.PARAMETER Password
    The Prism Central password as a SecureString.

.PARAMETER VolumeGroupName
    The name for the new volume group.

.PARAMETER Description
    An optional description for the volume group.

.PARAMETER SharedAccess
    Enable shared access mode for the volume group (allows multiple attachments).

.PARAMETER FlashMode
    Enable flash mode on the volume group for performance optimization.

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-create-volume-group.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -VolumeGroupName "ProdVG01"

    Create a basic volume group.

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-create-volume-group.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -VolumeGroupName "SharedVG" -Description "Shared storage for app cluster" -SharedAccess -FlashMode

    Create a shared, flash-mode volume group with a description.

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

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new volume group.")]
    [ValidateNotNullOrEmpty()]
    [string]$VolumeGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the volume group.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Enable shared access mode for the volume group.")]
    [switch]$SharedAccess,

    [Parameter(Mandatory = $false, HelpMessage = "Enable flash mode on the volume group for performance optimization.")]
    [switch]$FlashMode
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

try {
    Write-Host "🚀 Starting Nutanix volume group creation..." -ForegroundColor Green
    Write-Host "ℹ️  Prism Central  : $PrismCentralHost" -ForegroundColor Yellow
    Write-Host "ℹ️  Volume Group   : $VolumeGroupName" -ForegroundColor Yellow
    Write-Host "ℹ️  Shared Access  : $($SharedAccess.IsPresent)" -ForegroundColor Yellow
    Write-Host "ℹ️  Flash Mode     : $($FlashMode.IsPresent)" -ForegroundColor Yellow

    # Build the request body
    $resources = @{
        is_shared    = $SharedAccess.IsPresent
        flash_mode   = $FlashMode.IsPresent
    }

    $spec = @{
        name      = $VolumeGroupName
        resources = $resources
    }
    if ($Description) {
        $spec.description = $Description
    }

    $body = @{
        spec     = $spec
        metadata = @{ kind = 'volume_group' }
    }

    Write-Host "🔧 Creating volume group '$VolumeGroupName'..." -ForegroundColor Cyan

    $invokeParams = @{
        Method               = 'POST'
        Uri                  = "$baseUrl/volume_groups"
        Headers              = $headers
        Body                 = ($body | ConvertTo-Json -Depth 10)
        SkipCertificateCheck = $true
    }
    $response = Invoke-RestMethod @invokeParams

    $vgUuid = $response.metadata.uuid
    $taskUuid = $response.status.execution_context.task_uuid

    Write-Host "✅ Volume group '$VolumeGroupName' created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Name         : $VolumeGroupName" -ForegroundColor White
    Write-Host "  UUID         : $vgUuid" -ForegroundColor White
    Write-Host "  Shared Access: $($SharedAccess.IsPresent)" -ForegroundColor White
    Write-Host "  Flash Mode   : $($FlashMode.IsPresent)" -ForegroundColor White
    if ($taskUuid) { Write-Host "  Task UUID    : $taskUuid" -ForegroundColor White }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($plainPassword) { $plainPassword = $null }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
