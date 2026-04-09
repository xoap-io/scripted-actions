<#
.SYNOPSIS
    Deploys a Session-based RDS environment across five servers.

.DESCRIPTION
    Installs required Windows Features, creates SMB shares with proper permissions, sets up RDS deployment, adds RD Licensing and Gateway, creates a session collection, and enables User Profile Disks (UPD).
    Follows strict parameter validation, error handling, and output conventions per repo standards.

.PARAMETER DomainFqdn
    FQDN of the Active Directory domain.

.PARAMETER FileServer
    Hostname of the File Server.

.PARAMETER LicensingServer
    Hostname of the RD Licensing Server.

.PARAMETER BrokerAndWeb
    Hostname of the RD Connection Broker + Web Access (run script here).

.PARAMETER GatewayServer
    Hostname of the RD Gateway Server.

.PARAMETER SessionHost
    Hostname of the RD Session Host.

.PARAMETER CollectionName
    Name of the RDS session collection.

.PARAMETER CollectionDesc
    Description of the session collection.

.PARAMETER UPDShareName
    Name of the UPD SMB share.

.PARAMETER ProfilesShareName
    Name of the roaming profiles SMB share.

.PARAMETER UPDLocalPath
    Local path for UPD share on File Server.

.PARAMETER ProfilesLocalPath
    Local path for profiles share on File Server.

.PARAMETER UPDMaxSizeGB
    Max size (GB) for User Profile Disks.

.PARAMETER RdsLicenseMode
    Licensing mode: 'PerUser' or 'PerDevice'.

.PARAMETER CollectionUserGroup
    Domain group allowed to log on to the collection.

.PARAMETER GatewayExternalFqdn
    Optional external FQDN for RD Gateway.

.PARAMETER SkipGateway
    Skip RD Gateway server deployment and configuration.

.PARAMETER SkipLicensing
    Skip RD Licensing server deployment and configuration.

.EXAMPLE
    # Deploy full RDS environment with all components
    .\pass-rds-deployment.ps1

.EXAMPLE
    # Deploy RDS environment without Gateway and Licensing servers
    .\pass-rds-deployment.ps1 -SkipGateway -SkipLicensing

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 5.1 or later

    Use -SkipGateway and/or -SkipLicensing for environments that don't need all RDS components.
    When skipping components, their corresponding server parameters will be ignored.

.LINK
    https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-deploy-infrastructure

.COMPONENT
    Windows PowerShell Server Management
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "FQDN of the Active Directory domain.")][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$DomainFqdn          = 'domainname.local',
    [Parameter(HelpMessage = "Hostname of the File Server.")][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$FileServer          = 'fileserver.domainname.local',
    [Parameter(HelpMessage = "Hostname of the RD Licensing Server.")][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$LicensingServer     = 'licensingserver.domainname.local',
    [Parameter(HelpMessage = "Hostname of the RD Connection Broker + Web Access (run script here).")][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$BrokerAndWeb        = 'brokerandweb.domainname.local',
    [Parameter(HelpMessage = "Hostname of the RD Gateway Server.")][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$GatewayServer       = 'gatewayserver.domainname.local',
    [Parameter(HelpMessage = "Hostname of the RD Session Host.")][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$SessionHost         = 'sessionhost.domainname.local',
    [Parameter(HelpMessage = "Name of the RDS session collection.")][ValidatePattern('^[\w-]+$')][string]$CollectionName              = 'MainCollection',
    [Parameter(HelpMessage = "Description of the session collection.")][string]$CollectionDesc                                           = 'Primary RDSH collection',
    [Parameter(HelpMessage = "Name of the UPD SMB share.")][ValidatePattern('^[\w\$-]+$')][string]$UPDShareName              = 'RDS-ProfileDisks$',
    [Parameter(HelpMessage = "Name of the roaming profiles SMB share.")][ValidatePattern('^[\w\$-]+$')][string]$ProfilesShareName         = 'RDS-Profiles$',
    [Parameter(HelpMessage = "Local path for UPD share on File Server.")][ValidatePattern('^[A-Z]:\\[\\\w\s-]+$')][string]$UPDLocalPath    = "\\terminaltest1.passnet.local\ProfileDisks",
    [Parameter(HelpMessage = "Local path for profiles share on File Server.")][ValidatePattern('^[A-Z]:\\[\\\w\s-]+$')][string]$ProfilesLocalPath = "C:\UserProfiles",
    [Parameter(HelpMessage = "Max size (GB) for User Profile Disks.")][ValidateRange(1,100)][int]$UPDMaxSizeGB                         = 30,
    [Parameter(HelpMessage = "Licensing mode: 'PerUser' or 'PerDevice'.")][ValidateSet('PerUser','PerDevice')][string]$RdsLicenseMode      = 'PerUser',
    [Parameter(HelpMessage = "Domain group allowed to log on to the collection.")][string]$CollectionUserGroup                                     = "$($DomainFqdn.Split('.')[0].ToUpper())\Domain Users",
    [Parameter(HelpMessage = "Optional external FQDN for RD Gateway.")][string]$GatewayExternalFqdn                                     = '',
    [Parameter(HelpMessage = "Certificate thumbprint for the RD Connection Broker.")][string]$BrokerCertThumbprint                                    = "<BROKER_CERT_THUMBPRINT>",
    [Parameter(HelpMessage = "Certificate thumbprint for the RD Gateway.")][string]$GatewayCertThumbprint                                   = "<GATEWAY_CERT_THUMBPRINT>",
    [Parameter(HelpMessage = "Skip RD Gateway server deployment and configuration.")][switch]$SkipGateway,
    [Parameter(HelpMessage = "Skip RD Licensing server deployment and configuration.")][switch]$SkipLicensing
)

$ErrorActionPreference = 'Stop'

try {

# -------------------------
# PRECHECKS
# -------------------------
Write-Host "Validating execution context..." -ForegroundColor Cyan
$envComputer = "$env:COMPUTERNAME.$DomainFqdn".ToLower()
if ($envComputer -ne $BrokerAndWeb.ToLower()) {
    Write-Warning "This script should be run on $BrokerAndWeb. Current: $envComputer"
}

Import-Module ServerManager -ErrorAction Stop
Import-Module RemoteDesktop -ErrorAction SilentlyContinue

$sessionOptions = New-PSSessionOption -OperationTimeout (30 * 60 * 1000)

# Build server list based on selected components
$Servers = @($FileServer, $BrokerAndWeb, $SessionHost)
if (-not $SkipLicensing) {
    $Servers += $LicensingServer
}
if (-not $SkipGateway) {
    $Servers += $GatewayServer
}
$Servers = $Servers | Select-Object -Unique

Write-Host "Testing PowerShell Remoting to all servers..." -ForegroundColor Cyan
foreach ($srv in $Servers) {
    try {
        Test-WsMan -ComputerName $srv -ErrorAction Stop | Out-Null
        Write-Host "  OK: $srv" -ForegroundColor Green
    } catch {
        throw "Cannot connect to $srv via PowerShell Remoting. Ensure WinRM is enabled and reachable."
    }
}

# -------------------------
# INSTALL WINDOWS FEATURES
# -------------------------
Write-Host "Installing Windows Features..." -ForegroundColor Cyan

# Build feature installation plan based on selected components
$featurePlan = @(
    @{ Server=$FileServer;     Features=@('FS-FileServer','FS-Resource-Manager') },
    @{ Server=$BrokerAndWeb;   Features=@('RDS-Connection-Broker','RDS-Web-Access') },
    @{ Server=$SessionHost;    Features=@('RDS-RD-Server') }
)

# Add optional components
if (-not $SkipLicensing) {
    $featurePlan += @{ Server=$LicensingServer; Features=@('RDS-Licensing','RDS-Licensing-UI') }
}
if (-not $SkipGateway) {
    $featurePlan += @{ Server=$GatewayServer; Features=@('RDS-Gateway') }
}

foreach ($item in $featurePlan) {
    Invoke-Command -ComputerName $item.Server -ArgumentList (,$item.Features) -ScriptBlock {
        param($Features)
        Import-Module ServerManager
        foreach ($f in $Features) {
            $res = Get-WindowsFeature -Name $f
            if (-not $res.Installed) {
                Write-Host "Installing $f..." -ForegroundColor Yellow
                Install-WindowsFeature -Name $f -IncludeManagementTools -Restart:$false | Out-Null
            } else {
                Write-Host "$f already installed." -ForegroundColor DarkGreen
            }
        }
    } -ArgumentList ($item.Features) -ErrorAction Stop -SessionOption $sessionOptions
}

# -------------------------
# CREATE SHARES ON FILE SERVER
# -------------------------
Write-Host "Creating profile and UPD shares on $FileServer ..." -ForegroundColor Cyan

$createShares = {
    param(
        [Parameter(Mandatory)][string]$UPDPath,
        [Parameter(Mandatory)][string]$ProfilesPath,
        [Parameter(Mandatory)][string]$UPDShare,
        [Parameter(Mandatory)][string]$ProfilesShare,
        [Parameter(Mandatory)][string]$DomainFqdn
    )

    # Ensure paths exist
    foreach ($p in @($UPDPath, $ProfilesPath)) {
        if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Path $p | Out-Null
        }
    }

    # ---- Resolve language-agnostic identities (SIDs) ----
    # BUILTIN\Administrators (S-1-5-32-544)
    $sidAdmins  = New-Object System.Security.Principal.SecurityIdentifier `
        ([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
    $ntAdmins   = $sidAdmins.Translate([System.Security.Principal.NTAccount]).Value  # e.g. "BUILTIN\Administrators" / "BUILTIN\Administratoren"

    # NT AUTHORITY\SYSTEM (S-1-5-18)
    $sidSystem  = New-Object System.Security.Principal.SecurityIdentifier `
        ([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
    $ntSystem   = $sidSystem.Translate([System.Security.Principal.NTAccount]).Value  # e.g. "NT AUTHORITY\SYSTEM" / "NT-AUTORITÄT\SYSTEM"

    # DOMAIN\Domain Users (S-1-5-21-<domain>-513) – derived from current domain SID
    $domainUsersSid = $null
    $ntDomainUsers  = $null
    try {
        $adDomain    = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $domainSid   = New-Object System.Security.Principal.SecurityIdentifier($adDomain.GetDirectoryEntry().objectSid.Value, 0)
        $domainUsersSid = New-Object System.Security.Principal.SecurityIdentifier(
            [System.Security.Principal.WellKnownSidType]::AccountDomainUsersSid, $domainSid
        )
        $ntDomainUsers  = $domainUsersSid.Translate([System.Security.Principal.NTAccount]).Value  # e.g. "CONTOSO\Domain Users" / "CONTOSO\Domänen-Benutzer"
    } catch {
        Write-Warning "Could not resolve Domain Users. Is the server domain-joined? Skipping Domain Users grants."
    }

    function Set-Share {
        param([string]$Name, [string]$Path)

        if (-not (Get-SmbShare -Name $Name -ErrorAction SilentlyContinue)) {
            # Use translated, locale-correct account names for share permissions
            $fullAccessAccounts = @($ntAdmins, $ntSystem) | Where-Object { $_ }
            New-SmbShare -Name $Name -Path $Path -CachingMode None -FullAccess $fullAccessAccounts -ErrorAction Stop | Out-Null
        }
    }

    # Create shares if missing
    Set-Share -Name $UPDShare      -Path $UPDPath
    Set-Share -Name $ProfilesShare -Path $ProfilesPath

    # Grant CHANGE on the shares to Domain Users (if resolvable)
    if ($ntDomainUsers) {
        foreach ($share in @($UPDShare, $ProfilesShare)) {
            Grant-SmbShareAccess -Name $share -AccountName $ntDomainUsers -AccessRight Change -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # ---- Secure NTFS with language-neutral SIDs via icacls ----
    foreach ($folder in @($UPDPath, $ProfilesPath)) {
        # Stop inheriting, keep existing ACEs converted to explicit
        icacls $folder /inheritance:d | Out-Null

        # Full Control for BUILTIN\Administrators and SYSTEM via SIDs (language-agnostic)
        icacls $folder /grant "*$($sidAdmins.Value):(OI)(CI)(F)" | Out-Null
        icacls $folder /grant "*$($sidSystem.Value):(OI)(CI)(F)" | Out-Null

        # Modify for Domain Users (if resolvable)
        if ($domainUsersSid) {
            icacls $folder /grant "*$($domainUsersSid.Value):(OI)(CI)(M)" | Out-Null
        } else {
            Write-Verbose "Skipping Domain Users NTFS grant on $folder because Domain Users SID was not resolved."
        }
    }
}
Invoke-Command -ComputerName $FileServer -ScriptBlock $createShares -ArgumentList $UPDLocalPath,$ProfilesLocalPath,$UPDShareName,$ProfilesShareName,$DomainFqdn -SessionOption $sessionOptions

$UPDSharePath      = "\\$($FileServer.Split('.')[0])\$UPDShareName"
$ProfilesSharePath = "\\$($FileServer.Split('.')[0])\$ProfilesShareName"
Write-Host "UPD Share  : $UPDSharePath" -ForegroundColor Green
Write-Host "Profiles   : $ProfilesSharePath" -ForegroundColor Green

# -------------------------
# ADD ALL SERVERS TO COMPUTER POOL (German OS compatible)
# -------------------------
Write-Host "Adding all RDS infrastructure servers to the computer pool..." -ForegroundColor Cyan

# Build computer pool server list based on selected components
$computerPoolServers = @($SessionHost, $BrokerAndWeb, $FileServer)
if (-not $SkipLicensing) {
    $computerPoolServers += $LicensingServer
}
if (-not $SkipGateway) {
    $computerPoolServers += $GatewayServer
}
foreach ($srv in $computerPoolServers) {
    try {
        Add-ServerManagerServer -ComputerName $srv -ErrorAction SilentlyContinue
        Write-Host "Successfully added $srv to Server Manager." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to add $srv to Server Manager: $_"
    }
}

# -------------------------
# CREATE/EXTEND RDS DEPLOYMENT
# -------------------------
Write-Host "Setting up RDS deployment..." -ForegroundColor Cyan
Import-Module RemoteDesktop -ErrorAction SilentlyContinue

$deploymentExists = $false
try {
    $deployment = Get-RDServer -ConnectionBroker $BrokerAndWeb -ErrorAction Stop
    if ($deployment) { $deploymentExists = $true }
} catch { Write-Verbose "Deployment not yet initialized." }

if (-not $deploymentExists) {
    Write-Host "Creating new RD Session deployment..." -ForegroundColor Yellow
    New-RDSessionDeployment `
        -ConnectionBroker $BrokerAndWeb `
        -WebAccessServer  $BrokerAndWeb `
        -SessionHost      $SessionHost `
        -ErrorAction Stop
} else {
    Write-Host "Deployment already exists. Ensuring RDSH is present..." -ForegroundColor DarkGreen
    $existingRDSH = (Get-RDServer -ConnectionBroker $BrokerAndWeb | Where-Object {$_.Server -ieq $SessionHost -and $_.Roles -match 'RDS-RD-SERVER'})
    if (-not $existingRDSH) {
        Add-RDServer -Server $SessionHost -Role "RDS-RD-SERVER" -ConnectionBroker $BrokerAndWeb -ErrorAction Stop
    }
}

# Configure RD Licensing if not skipped
if (-not $SkipLicensing) {
    Write-Host "Adding RD Licensing server and setting license mode..." -ForegroundColor Cyan
    $existingLic = (Get-RDServer -ConnectionBroker $BrokerAndWeb | Where-Object { $_.Server -ieq $LicensingServer -and $_.Roles -match 'RDS-LICENSING' })
    if (-not $existingLic) {
        Add-RDServer -Server $LicensingServer -Role "RDS-LICENSING" -ConnectionBroker $BrokerAndWeb -ErrorAction Stop
    }
    Set-RDLicenseConfiguration -ConnectionBroker $BrokerAndWeb -LicenseServer $LicensingServer -Mode $RdsLicenseMode -ErrorAction Stop
} else {
    Write-Host "Skipping RD Licensing configuration as requested." -ForegroundColor Yellow
}

# Configure RD Gateway if not skipped
if (-not $SkipGateway) {
    Write-Host "Adding RD Gateway server..." -ForegroundColor Cyan
    $existingGw = (Get-RDServer -ConnectionBroker $BrokerAndWeb | Where-Object { $_.Server -ieq $GatewayServer -and $_.Roles -match 'RDS-GATEWAY' })
    if (-not $existingGw) {
        Add-RDServer -Server $GatewayServer -Role "RDS-GATEWAY" -ConnectionBroker $BrokerAndWeb -ErrorAction Stop
    }

    if ($GatewayExternalFqdn) {
        Write-Host "Configuring RD Gateway external FQDN: $GatewayExternalFqdn" -ForegroundColor Yellow
        Set-RDDeploymentGatewayConfiguration `
            -ConnectionBroker $BrokerAndWeb `
            -GatewayMode Custom `
            -LogonMethod Password `
            -UseCachedCredentials $true `
            -BypassLocal $true `
            -GatewayExternalFqdn $GatewayExternalFqdn `
            -ErrorAction SilentlyContinue
    } else {
        Set-RDDeploymentGatewayConfiguration `
            -ConnectionBroker $BrokerAndWeb `
            -GatewayMode Automatic `
            -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "Skipping RD Gateway configuration as requested." -ForegroundColor Yellow
}

Write-Host "Creating collection and enabling UPD..." -ForegroundColor Cyan
$collectionExists = $false
try {
    $col = Get-RDSessionCollection -ConnectionBroker $BrokerAndWeb -CollectionName $CollectionName -ErrorAction Stop
    if ($col) { $collectionExists = $true }
} catch { Write-Verbose "Collection does not exist yet." }

if (-not $collectionExists) {
    New-RDSessionCollection `
        -CollectionName   $CollectionName `
        -CollectionDescription $CollectionDesc `
        -SessionHost      $SessionHost `
        -ConnectionBroker $BrokerAndWeb `
        -ErrorAction Stop

    if ($CollectionUserGroup) {
        Set-RDSessionCollectionConfiguration `
            -CollectionName   $CollectionName `
            -ConnectionBroker $BrokerAndWeb `
            -UserGroup        $CollectionUserGroup `
            -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "Collection '$CollectionName' already exists." -ForegroundColor DarkGreen
    try {
        Add-RDSessionHost -CollectionName $CollectionName -SessionHost $SessionHost -ConnectionBroker $BrokerAndWeb -ErrorAction SilentlyContinue
    } catch { Write-Verbose "Session host already in collection or could not be added." }
}

# -------------------------
# INTEGRATE CERTIFICATES FOR BROKER/WEB AND RD GATEWAY
# -------------------------
function Set-RDCertificate {
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Role, # "Broker" or "Gateway"
        [Parameter(Mandatory)][string]$CertThumbprint,
        [string]$CertStore = "My"
    )
    Write-Host "Configuring certificate for $Role on $Server..." -ForegroundColor Cyan
    try {
        if ($Role -eq "Broker") {
            # Set certificate for RD Connection Broker and Web Access
            Set-RDCertificate -Role RDConnectionBroker -Thumbprint $CertThumbprint -CertStore $CertStore -ConnectionBroker $Server -Force -ErrorAction Stop
            Set-RDCertificate -Role RDWebAccess -Thumbprint $CertThumbprint -CertStore $CertStore -ConnectionBroker $Server -Force -ErrorAction Stop
            Write-Host "Broker/Web certificate applied on $Server." -ForegroundColor Green
        } elseif ($Role -eq "Gateway") {
            # Set certificate for RD Gateway
            Set-RDCertificate -Role RDGateway -Thumbprint $CertThumbprint -CertStore $CertStore -ConnectionBroker $Server -Force -ErrorAction Stop
            Write-Host "Gateway certificate applied on $Server." -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to apply certificate for $Role on {$Server}: $_"
    }
}

Set-RDCertificate -Server $BrokerAndWeb -Role "Broker"  -CertThumbprint $BrokerCertThumbprint
Set-RDCertificate -Server $GatewayServer -Role "Gateway" -CertThumbprint $GatewayCertThumbprint


Set-RDSessionCollectionConfiguration `
    -CollectionName   $CollectionName `
    -ConnectionBroker $BrokerAndWeb `
    -EnableUserProfileDisk `
    -DiskPath $UPDSharePath `
    -MaxUserProfileDiskSizeGB $UPDMaxSizeGB `
    -ErrorAction Stop

Write-Host ""
Write-Host "---------------- DEPLOYMENT COMPLETE ----------------" -ForegroundColor Green
Write-Host "Broker/Web   : $BrokerAndWeb"
Write-Host "Gateway      : $GatewayServer"
Write-Host "Licensing    : $LicensingServer ($RdsLicenseMode)"
Write-Host "RDSH         : $SessionHost"
Write-Host "Collection   : $CollectionName"
Write-Host "UPD Share    : $UPDSharePath (Max $UPDMaxSizeGB GB)"
Write-Host "Profiles     : $ProfilesSharePath"
Write-Host "-----------------------------------------------------" -ForegroundColor Green

Write-Host "`nNEXT STEPS:" -ForegroundColor Cyan
Write-Host "1) Activate the RD Licensing server on $LicensingServer and install your CALs."
Write-Host "2) (Optional) Configure RD Gateway CAP/RAP policies and SSL certificate on $GatewayServer."
Write-Host "3) (Optional) Redirect user profiles to $ProfilesSharePath or move to FSLogix if preferred."

}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
