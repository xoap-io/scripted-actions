<#
.SYNOPSIS
  Stage unattend.xml for Push-Button Reset and trigger a Windows Reset via the Intune CSP (RemoteWipe) using the MDM Bridge.

.DESCRIPTION
  Stages the provided unattend.xml into the C:\Recovery\OEM folder alongside a ResetConfig.xml and
  CommonCustomizations.cmd so that the file survives a Push-Button Reset. Then schedules a SYSTEM-context
  task that calls the MDM_RemoteWipe CIM method (MDM Bridge WMI provider) to initiate a device wipe.
  Uses reagentc.exe to ensure Windows Recovery Environment (WinRE) is enabled before triggering the wipe.

.PARAMETER UnattendXmlPath
  Full path to your unattend.xml to apply after Reset.

.PARAMETER Mode
  Wipe mode: Standard, Protected, KeepUserData, KeepProvisioningData

.PARAMETER Force
  Skip safety countdown.

.EXAMPLE
  .\reset-os.ps1 -UnattendXmlPath "C:\Setup\unattend.xml"

.EXAMPLE
  .\reset-os.ps1 -UnattendXmlPath "C:\Setup\unattend.xml" -Mode KeepUserData -Force

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 5.1 or later

.LINK
    https://learn.microsoft.com/en-us/windows/deployment/push-button-reset/push-button-reset-overview

.COMPONENT
    Windows PowerShell Server Management
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory, HelpMessage = "Full path to your unattend.xml to apply after Reset.")]
  [ValidateScript({Test-Path $_ -PathType Leaf})]
  [string]$UnattendXmlPath,

  [Parameter(HelpMessage = "Wipe mode: Standard, Protected, KeepUserData, KeepProvisioningData.")]
  [ValidateSet('Standard','Protected','KeepUserData','KeepProvisioningData')]
  [string]$Mode = 'Standard',

  [Parameter(HelpMessage = "Skip safety countdown.")]
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

#--- Helpers ---------------------------------------------------------------

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Run this script from an elevated PowerShell."
  }
}

function Ensure-WinRE {
  Write-Host "Checking Windows RE status..."
  $info = (reagentc.exe /info) 2>&1 | Out-String
  if ($info -notmatch 'Windows RE status:\s+Enabled') {
    Write-Host "Enabling Windows RE..."
    $out = (reagentc.exe /enable) 2>&1
    Start-Sleep -Seconds 2
    $info = (reagentc.exe /info) 2>&1 | Out-String
    if ($info -notmatch 'Windows RE status:\s+Enabled') {
      throw "Windows RE could not be enabled. RemoteWipe requires WinRE."
    }
  }
}

function Stage-ResetArtifacts {
  param(
    [Parameter(Mandatory)][string]$UnattendPath
  )
  $oem = 'C:\Recovery\OEM'
  if (-not (Test-Path $oem)) { New-Item -ItemType Directory -Path $oem -Force | Out-Null }

  # 1) Copy unattend.xml to the OEM recovery folder
  Copy-Item -Path $UnattendPath -Destination (Join-Path $oem 'Unattend.xml') -Force

  # 2) ResetConfig.xml pointing to our script in both reset paths
  $resetXml = @'
<?xml version="1.0" encoding="utf-8"?>
<Reset>
  <Run Phase="BasicReset_AfterImageApply">
    <Path>CommonCustomizations.cmd</Path>
    <Duration>2</Duration>
  </Run>
  <Run Phase="FactoryReset_AfterImageApply">
    <Path>CommonCustomizations.cmd</Path>
    <Duration>2</Duration>
  </Run>
</Reset>
'@
  Set-Content -Path (Join-Path $oem 'ResetConfig.xml') -Value $resetXml -Encoding utf8

  # 3) CommonCustomizations.cmd – copy unattend into the new OS right after image apply
  $cmd = @'
@echo off
REM Define %TARGETOS% (e.g. C:\Windows) and %TARGETOSDRIVE% (e.g. C:)
for /F "tokens=1,2,3 delims= " %%A in ('reg query "HKLM\SOFTWARE\Microsoft\RecoveryEnvironment" /v TargetOS') DO SET TARGETOS=%%C
for /F "tokens=1 delims=\" %%A in ('Echo %TARGETOS%') DO SET TARGETOSDRIVE=%%A

REM Put unattend.xml into the new OS so OOBE consumes it
copy "%TARGETOSDRIVE%\Recovery\OEM\Unattend.xml" "%TARGETOS%\Panther\Unattend.xml" /y

EXIT 0
'@
  Set-Content -Path (Join-Path $oem 'CommonCustomizations.cmd') -Value $cmd -Encoding ascii

  Write-Host "Staged: $oem (Unattend.xml, ResetConfig.xml, CommonCustomizations.cmd)"
}

function Get-WipeMethodName {
  switch ($Mode) {
    'Standard'              { 'doWipeMethod' }                       # Reset (Remove everything)
    'Protected'             { 'doWipeProtectedMethod' }              # Reset + fully clean drive
    'KeepUserData'          { 'doWipePersistUserDataMethod' }        # Keep my files
    'KeepProvisioningData'  { 'doWipePersistProvisionedDataMethod' } # Keep provisioning packages
  }
}

function Invoke-RemoteWipe-AsSystem {
  param([Parameter(Mandatory)][string]$MethodName)

  # Build an inline script that runs under SYSTEM and calls the MDM Bridge method
  $inline = @"
`$ns = 'root\cimv2\mdm\dmmap'
`$class = 'MDM_RemoteWipe'
`$method = '$MethodName'
`$session = New-CimSession
`$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
`$param  = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create('param','', 'String', 'In')
`$params.Add(`$param) | Out-Null
`$instance = Get-CimInstance -Namespace `$ns -ClassName `$class -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
`$null = `$session.InvokeMethod(`$ns, `$instance, `$method, `$params)
"@

  $b64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inline))
  $taskName = "Invoke-RemoteWipe-" + [Guid]::NewGuid().ToString()
  $action   = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $b64"
  $trigger  = New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddSeconds(10))
  $principal= New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal | Out-Null
  Start-ScheduledTask -TaskName $taskName | Out-Null
  Write-Host "Wipe scheduled via SYSTEM task '$taskName'... device will reset shortly."
}

#--- Flow ------------------------------------------------------------------

try {
    Assert-Admin
    Ensure-WinRE
    Stage-ResetArtifacts -UnattendPath $UnattendXmlPath

    Write-Warning "About to RESET this device via Intune CSP (mode: $Mode). THIS IS DESTRUCTIVE."
    if (-not $Force) {
        for ($i=10; $i -ge 1; $i--) {
            Write-Host ("Starting in {0} seconds... Press Ctrl+C to abort" -f $i)
            Start-Sleep -Seconds 1
        }
    }

    $method = Get-WipeMethodName
    Invoke-RemoteWipe-AsSystem -MethodName $method
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
