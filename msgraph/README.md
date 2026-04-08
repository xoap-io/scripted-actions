# Microsoft Graph Automation Scripts

This directory contains PowerShell scripts that automate Microsoft 365, Entra ID (Azure AD),
and Microsoft Intune operations using the Microsoft Graph API.

All scripts are designed to be used with the **XOAP Scripted Actions** module. Authentication
is handled by XOAP via an App Registration using Application ID, Client Secret, and Tenant ID.
The scripts assume an active Microsoft Graph connection is already established.

## Prerequisites

- **Microsoft Graph PowerShell SDK**: Install with `Install-Module Microsoft.Graph`
- **PowerShell 7.0+**: Recommended for full compatibility
- **App Registration**: Configured in Entra ID with appropriate Graph API permissions (handled by XOAP)

## Authentication

Authentication is handled by XOAP using an App Registration. The following are required in XOAP:

- **Application (Client) ID**
- **Client Secret**
- **Tenant ID**

XOAP calls `Connect-MgGraph` before executing these scripts. No authentication code is included
in the scripts themselves.

## Required API Permissions

Different scripts require different Microsoft Graph API permissions. Refer to each script's
`.NOTES` section for the specific permissions needed.

| Permission | Type | Description |
|---|---|---|
| `User.Read.All` | Application | Read all users |
| `Group.ReadWrite.All` | Application | Read and write all groups |
| `GroupMember.ReadWrite.All` | Application | Read and write group memberships |
| `DeviceManagementManagedDevices.ReadWrite.All` | Application | Read and write Intune devices |
| `DeviceManagementApps.ReadWrite.All` | Application | Read and write Intune apps |
| `DeviceManagementConfiguration.ReadWrite.All` | Application | Read and write Intune config policies |
| `Policy.Read.All` | Application | Read conditional access policies |

## Directory Structure

| Folder | Description | Service Focus |
|---|---|---|
| [`entra/`](./entra/) | Entra ID management | Users, groups, conditional access |
| [`intune/`](./intune/) | Microsoft Intune management | Devices, apps, compliance, policies |

## Common Usage Patterns

### Listing resources

```powershell
.\msgraph-get-entra-users.ps1
.\msgraph-get-intune-managed-devices.ps1
```

### Filtering results

```powershell
.\msgraph-get-entra-users.ps1 -Filter "department eq 'IT'"
.\msgraph-get-intune-managed-devices.ps1 -OperatingSystem "Windows"
```

### Exporting output

```powershell
.\msgraph-get-entra-users.ps1 -OutputFormat JSON
.\msgraph-get-intune-device-compliance.ps1 -OutputFormat CSV
```

## Security Considerations

- Follow the principle of least privilege when assigning API permissions
- Regularly rotate client secrets
- Review audit logs in Entra ID for all Graph API activity
- Use App Registrations rather than delegated permissions for automation

## Troubleshooting

- Ensure the App Registration has the required Graph API permissions
- Verify that admin consent has been granted for Application permissions
- Check the Entra ID audit logs for failed authentication attempts
- Confirm the Tenant ID matches the target tenant

## Contributing

Follow the same conventions used in other script directories in this repository.
Refer to [`/templates/template.ps1`](/templates/template.ps1) for the script template.
