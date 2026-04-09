# PowerShell - Windows Server Management Scripts

This directory contains PowerShell scripts for managing and hardening Windows Server
instances, including local user accounts, Windows Update, WinRM remoting, and CIS
security baseline hardening.

## Prerequisites

- Windows Server 2016 or later (2019/2022 recommended)
- PowerShell 5.1 or later
- Administrator privileges
- PSWindowsUpdate module (optional, for `ps-configure-windows-update.ps1`)

## Available Scripts

| Script                            | Description                                                                                                                    |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `ps-configure-windows-update.ps1` | Configures Windows Update settings and optionally points the machine at a WSUS server; can trigger an immediate update install |
| `ps-manage-local-users.ps1`       | Creates, removes, enables, disables, and manages local user accounts and group memberships                                     |
| `ps-configure-winrm.ps1`          | Enables, disables, configures, and tests Windows Remote Management (WinRM) for PowerShell remoting                             |
| `ps-harden-windows-server.ps1`    | Applies CIS Windows Server 2019/2022 benchmark hardening controls at Level 1 or Level 2                                        |

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

## Notes

- All scripts require Administrator privileges.
- `ps-harden-windows-server.ps1` should be tested in a non-production environment
  before applying to production servers; use `-WhatIf` for a dry-run preview.
- `ps-configure-windows-update.ps1` uses PSWindowsUpdate when available, falling
  back to the built-in WUA COM interface.

## Related Documentation

- [Windows Update Overview](https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-overview)
- [LocalAccounts Module](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/)
- [WinRM Configuration](https://docs.microsoft.com/en-us/windows/win32/winrm/installation-and-configuration-for-windows-remote-management)
- [CIS Benchmarks](https://www.cisecurity.org/benchmark/microsoft_windows_server)
