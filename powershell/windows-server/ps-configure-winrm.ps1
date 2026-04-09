<#
.SYNOPSIS
    Configure Windows Remote Management (WinRM) for PowerShell remoting.

.DESCRIPTION
    Enables, disables, configures, or tests Windows Remote Management (WinRM) and
    PowerShell remoting on the local machine. Uses Enable-PSRemoting, Set-WSManInstance,
    and related cmdlets. Supports configuring HTTP and HTTPS listeners, restricting
    allowed hosts, and tuning envelope size and concurrent user limits.

.PARAMETER Action
    Operation to perform: Enable, Disable, Configure, or Test.

.PARAMETER AllowedHosts
    Comma-separated list of hosts permitted to connect. Use "*" to allow all. Default is "*".

.PARAMETER UseHTTPS
    Configure a HTTPS listener instead of (or in addition to) HTTP.

.PARAMETER CertificateThumbprint
    Certificate thumbprint for the HTTPS listener. Required when UseHTTPS is specified.

.PARAMETER MaxEnvelopeSizekb
    Maximum SOAP envelope size in kilobytes. Default is 512.

.PARAMETER MaxConcurrentUsers
    Maximum number of concurrent remote management users. Default is 10.

.EXAMPLE
    .\ps-configure-winrm.ps1 -Action Enable

.EXAMPLE
    .\ps-configure-winrm.ps1 -Action Configure -AllowedHosts "10.0.0.*,192.168.1.*" -MaxEnvelopeSizekb 1024 -MaxConcurrentUsers 25

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 5.1+; must be run as Administrator

.LINK
    https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management

.COMPONENT
    Windows PowerShell Server Management
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Operation to perform: Enable, Disable, Configure, or Test.")]
    [ValidateSet('Enable', 'Disable', 'Configure', 'Test')]
    [string]$Action = 'Configure',

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of allowed hosts. Default is '*' (all).")]
    [string]$AllowedHosts = '*',

    [Parameter(Mandatory = $false, HelpMessage = "Configure a HTTPS listener.")]
    [switch]$UseHTTPS,

    [Parameter(Mandatory = $false, HelpMessage = "Certificate thumbprint for HTTPS listener. Required when UseHTTPS is set.")]
    [string]$CertificateThumbprint,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum SOAP envelope size in kilobytes (32-8192). Default is 512.")]
    [ValidateRange(32, 8192)]
    [int]$MaxEnvelopeSizekb = 512,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of concurrent remote management users (1-100). Default is 10.")]
    [ValidateRange(1, 100)]
    [int]$MaxConcurrentUsers = 10
)

$ErrorActionPreference = 'Stop'

# Must run as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

# Validate HTTPS params
if ($UseHTTPS -and -not $CertificateThumbprint) {
    throw "CertificateThumbprint is required when UseHTTPS is specified."
}

try {
    Write-Host "🚀 Starting WinRM Configuration" -ForegroundColor Green
    Write-Host "🔧 Action: $Action" -ForegroundColor Cyan

    switch ($Action) {
        'Enable' {
            Write-Host "🔧 Enabling PowerShell remoting..." -ForegroundColor Cyan
            Enable-PSRemoting -Force -SkipNetworkProfileCheck
            Set-Service -Name WinRM -StartupType Automatic
            Start-Service -Name WinRM -ErrorAction SilentlyContinue
            Write-Host "✅ WinRM enabled and set to start automatically." -ForegroundColor Green
        }
        'Disable' {
            Write-Host "🔧 Disabling PowerShell remoting..." -ForegroundColor Cyan
            Disable-PSRemoting -Force
            Set-Service -Name WinRM -StartupType Disabled
            Stop-Service -Name WinRM -Force -ErrorAction SilentlyContinue
            Write-Host "✅ WinRM disabled." -ForegroundColor Green
        }
        'Configure' {
            Write-Host "🔧 Ensuring WinRM service is running..." -ForegroundColor Cyan
            Enable-PSRemoting -Force -SkipNetworkProfileCheck
            Set-Service -Name WinRM -StartupType Automatic

            Write-Host "🔧 Setting trusted hosts: $AllowedHosts" -ForegroundColor Cyan
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value $AllowedHosts -Force

            Write-Host "🔧 Setting MaxEnvelopeSizekb to $MaxEnvelopeSizekb..." -ForegroundColor Cyan
            Set-WSManInstance -ResourceURI winrm/config -ValueSet @{ MaxEnvelopeSizekb = $MaxEnvelopeSizekb } | Out-Null

            Write-Host "🔧 Setting MaxConcurrentUsers to $MaxConcurrentUsers..." -ForegroundColor Cyan
            Set-WSManInstance -ResourceURI winrm/config/service -ValueSet @{ MaxConcurrentOperationsPerUser = $MaxConcurrentUsers } | Out-Null

            if ($UseHTTPS) {
                Write-Host "🔧 Creating HTTPS listener with thumbprint $CertificateThumbprint..." -ForegroundColor Cyan
                $httpsListener = Get-ChildItem WSMan:\localhost\Listener | Where-Object { $_.Keys -contains 'Transport=HTTPS' }
                if ($httpsListener) {
                    Write-Host "ℹ️  HTTPS listener already exists. Updating certificate..." -ForegroundColor Yellow
                    Set-Item -Path ($httpsListener.PSPath + '\CertificateThumbprint') -Value $CertificateThumbprint
                } else {
                    New-WSManInstance winrm/config/Listener -SelectorSet @{ Address = '*'; Transport = 'HTTPS' } `
                        -ValueSet @{ CertificateThumbprint = $CertificateThumbprint } | Out-Null
                }
                Write-Host "✅ HTTPS listener configured." -ForegroundColor Green
            }

            Write-Host "✅ WinRM configured successfully." -ForegroundColor Green
        }
        'Test' {
            Write-Host "🔍 Testing WinRM connectivity to localhost..." -ForegroundColor Cyan
            try {
                Test-WSMan -ComputerName localhost -ErrorAction Stop | Out-Null
                Write-Host "✅ WinRM is responding on localhost." -ForegroundColor Green
            } catch {
                Write-Host "❌ WinRM is NOT responding on localhost: $($_.Exception.Message)" -ForegroundColor Red
            }

            Write-Host "`n📊 Summary:" -ForegroundColor Blue
            $config = Get-WSManInstance winrm/config -ErrorAction SilentlyContinue
            Write-Host "  MaxEnvelopeSizekb:   $($config.MaxEnvelopeSizekb)" -ForegroundColor Cyan
            $svcConfig = Get-WSManInstance winrm/config/service -ErrorAction SilentlyContinue
            Write-Host "  AllowUnencrypted:    $($svcConfig.AllowUnencrypted)" -ForegroundColor Cyan
            $listeners = Get-ChildItem WSMan:\localhost\Listener
            Write-Host "  Listeners ($($listeners.Count)):" -ForegroundColor Cyan
            foreach ($l in $listeners) {
                $transport = ($l.Keys | Where-Object { $_ -like 'Transport=*' }) -replace 'Transport=', ''
                Write-Host "    Transport: $transport" -ForegroundColor Cyan
            }
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
