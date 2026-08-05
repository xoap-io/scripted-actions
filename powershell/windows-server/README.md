# PowerShell - Windows Server Management Scripts

This directory contains PowerShell scripts for managing and hardening Windows Server
instances, including local user accounts, Windows Update, WinRM remoting, CIS
security baseline hardening, and Hyper-V golden image builds.

## Prerequisites

- Windows Server 2016 or later (2019/2022 recommended)
- PowerShell 5.1 or later
- Administrator privileges
- PSWindowsUpdate module (optional, for `ps-configure-windows-update.ps1`)
- Hyper-V role with PowerShell module (for `ps-build-hyperv-golden-image.ps1`)

## Available Scripts

| Script                              | Description                                                                                                                                                   |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ps-configure-windows-update.ps1`   | Configures Windows Update settings and optionally points the machine at a WSUS server; can trigger an immediate update install                                |
| `ps-manage-local-users.ps1`         | Creates, removes, enables, disables, and manages local user accounts and group memberships                                                                    |
| `ps-configure-winrm.ps1`            | Enables, disables, configures, and tests Windows Remote Management (WinRM) for PowerShell remoting                                                            |
| `ps-harden-windows-server.ps1`      | Applies CIS Windows Server 2019/2022 benchmark hardening controls at Level 1 or Level 2                                                                       |
| `ps-build-hyperv-golden-image.ps1`  | Builds a generalized (sysprepped) golden image VHDX on a Hyper-V host fully unattended from a Windows ISO; optionally registers it as an Azure Local VM image |
| `ps-configure-avd-session-host.ps1` | Configures an AVD session host guest: FSLogix profile containers, RDP Shortpath for managed networks and time zone redirection                                |

## Usage Examples

### Configure Windows Update with WSUS

```powershell
.\ps-configure-windows-update.ps1 `
    -WsusServer "http://wsus.corp.local" `
    -WsusPort 8530 `
    -EnableAutomaticUpdate `
    -InstallUpdatesNow `
    -AcceptEula
```

### Create a Local Service Account

```powershell
$pwd = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
.\ps-manage-local-users.ps1 `
    -Action Create `
    -Username "svc-backup" `
    -Password $pwd `
    -FullName "Backup Service Account" `
    -PasswordNeverExpires
```

### Add User to Remote Desktop Users Group

```powershell
.\ps-manage-local-users.ps1 `
    -Action AddToGroup `
    -Username "svc-backup" `
    -GroupName "Remote Desktop Users"
```

### Enable and Configure WinRM

```powershell
.\ps-configure-winrm.ps1 -Action Enable

.\ps-configure-winrm.ps1 `
    -Action Configure `
    -AllowedHosts "10.0.0.*,192.168.1.*" `
    -MaxEnvelopeSizekb 1024 `
    -MaxConcurrentUsers 25
```

### Apply CIS Level 1 Hardening

```powershell
# Preview changes first
.\ps-harden-windows-server.ps1 -Profile Level1 -WhatIf

# Apply with backup of current settings
.\ps-harden-windows-server.ps1 -Profile Level1 -BackupCurrentSettings -Force
```

### Apply CIS Level 2 Hardening

```powershell
.\ps-harden-windows-server.ps1 -Profile Level2 -BackupCurrentSettings -Force
```

### Build a Golden Image VHDX on an Azure Local Host (XOAP Scripted Actions)

```powershell
.\ps-build-hyperv-golden-image.ps1 `
    -IsoPath "C:\ClusterStorage\UserStorage_2\ISOs\WindowsServer2025.iso" `
    -EditionName "Windows Server 2025 Datacenter (Desktop Experience)" `
    -AdminPassword "P@ssw0rd-only-for-build" `
    -ImageName "ws2025-golden" `
    -CustomizeScriptPath ".\install-apps.ps1"
```

Runs fully unattended: applies the OS from the ISO to a new Gen 2 VHDX with
DISM, boots a temporary VM once to run the customization script and
`sysprep /generalize /oobe /shutdown`, removes the VM, and (with `-ImageName`)
registers the VHDX as an Azure Local VM image using the Azure context
pre-established by the XOAP Scripted Actions service principal. Omit
`-ImageName` (and pass `-VhdxPath`) for a build-only run without any Azure
connection; register later with
`azure-ps/azure-local/az-ps-create-azure-local-image.ps1`.

### Configure an AVD Session Host (FSLogix + RDP Shortpath)

```powershell
.\ps-configure-avd-session-host.ps1 `
    -ProfileSharePath "\\fs01.corp.contoso.com\avd-profiles" `
    -EnableRdpShortpath `
    -EnableTimeZoneRedirection `
    -Restart
```

Runs inside the session host (e.g. as a XOAP Scripted Action targeting the
VM). On Azure Local, RDP Shortpath keeps session traffic on the local network
instead of routing it through the AVD gateway. Deploy the session hosts first
with `azure-ps/azure-local/az-ps-deploy-avd-session-hosts.ps1`.

## Notes

- All scripts require Administrator privileges.
- `ps-harden-windows-server.ps1` should be tested in a non-production environment
  before applying to production servers; use `-WhatIf` for a dry-run preview.
- `ps-configure-windows-update.ps1` uses PSWindowsUpdate when available, falling
  back to the built-in WUA COM interface.
- `ps-build-hyperv-golden-image.ps1` must run directly on the Hyper-V host and
  needs no network unless the customization script requires one (`-SwitchName`).
  With `-ImageName` it additionally requires Az.Accounts + Az.StackHCIVM and a
  connected service principal Azure context (established by XOAP Scripted
  Actions before the script runs).

## Related Documentation

- [Windows Update Overview](https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-overview)
- [LocalAccounts Module](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/)
- [WinRM Configuration](https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management)
- [CIS Benchmarks](https://www.cisecurity.org/benchmark/microsoft_windows_server)
