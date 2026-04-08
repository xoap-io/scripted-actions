# Entra ID (Azure AD) Management Scripts

This directory contains PowerShell scripts for managing Entra ID resources via the Microsoft
Graph API, including users, groups, conditional access policies, and directory objects.

## Prerequisites

- Microsoft Graph PowerShell SDK (`Microsoft.Graph` module)
- App Registration with the following permissions (granted by XOAP):
  - `User.Read.All`
  - `User.EnableDisableAccount.All`
  - `Group.ReadWrite.All`
  - `GroupMember.ReadWrite.All`
  - `Policy.Read.All`

## Scripts

| Script | Description |
|---|---|
| [`msgraph-get-entra-users.ps1`](./msgraph-get-entra-users.ps1) | List and filter Entra ID users |
| [`msgraph-disable-entra-user.ps1`](./msgraph-disable-entra-user.ps1) | Enable or disable a user account |
| [`msgraph-get-entra-groups.ps1`](./msgraph-get-entra-groups.ps1) | List and filter Entra ID groups |
| [`msgraph-create-entra-group.ps1`](./msgraph-create-entra-group.ps1) | Create a new security or M365 group |
| [`msgraph-add-entra-group-member.ps1`](./msgraph-add-entra-group-member.ps1) | Add a user or device to a group |
| [`msgraph-get-conditional-access-policies.ps1`](./msgraph-get-conditional-access-policies.ps1) | List conditional access policies |

## Quick Start

```powershell
# List all users
.\msgraph-get-entra-users.ps1

# Get users filtered by department
.\msgraph-get-entra-users.ps1 -Filter "department eq 'Engineering'"

# Disable a user account
.\msgraph-disable-entra-user.ps1 -UserPrincipalName "user@contoso.com" -AccountEnabled $false

# Create a security group
.\msgraph-create-entra-group.ps1 -DisplayName "SG-IT-Admins" -GroupType Security -MailNickname "sg-it-admins"

# Add a user to a group
.\msgraph-add-entra-group-member.ps1 -GroupId "00000000-0000-0000-0000-000000000000" -MemberUserPrincipalName "user@contoso.com"

# List all conditional access policies
.\msgraph-get-conditional-access-policies.ps1
```
