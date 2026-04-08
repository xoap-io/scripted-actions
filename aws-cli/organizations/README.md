# Organizations Scripts

PowerShell scripts for managing AWS Organizations using the AWS CLI.
Covers account lifecycle, organizational unit (OU) management, and
service control policy (SCP) operations. Scripts must be run from
the organization's management account.

## Prerequisites

- AWS CLI v2
- Appropriate AWS credentials configured
- Must be executed from the organization's management account

## Available Scripts

| Script | Description |
| --- | --- |
| `aws-cli-attach-policy.ps1` | Attaches a service control policy to an account, OU, or root |
| `aws-cli-create-account.ps1` | Creates a new AWS account within the organization |
| `aws-cli-create-organizational-unit.ps1` | Creates an organizational unit under a parent root or OU |
| `aws-cli-delete-organizational-unit.ps1` | Deletes an empty organizational unit |
| `aws-cli-describe-account.ps1` | Retrieves details about a specific AWS account |
| `aws-cli-detach-policy.ps1` | Detaches a service control policy from an account, OU, or root |
| `aws-cli-invite-account.ps1` | Invites an existing AWS account to join the organization |
| `aws-cli-list-accounts.ps1` | Lists all accounts in the organization |
| `aws-cli-list-organizational-units.ps1` | Lists organizational units under a specified parent |
| `aws-cli-list-policies.ps1` | Lists service control policies in the organization |
| `aws-cli-move-account.ps1` | Moves an account from one parent (root or OU) to another |
| `aws-cli-remove-account.ps1` | Removes an account from the organization |

## Usage Examples

### Create a New Account

```powershell
.\aws-cli-create-account.ps1 `
    -AwsAccountEmail "dev-team@example.com" `
    -AwsAccountName "Development"
```

### Create an Organizational Unit

```powershell
.\aws-cli-create-organizational-unit.ps1 `
    -Name "Production" `
    -ParentId "r-ab12"
```

### Move an Account to a Different OU

```powershell
.\aws-cli-move-account.ps1 `
    -AccountId "123456789012" `
    -SourceParentId "r-ab12" `
    -DestinationParentId "ou-ab12-12345678"
```

### Attach a Policy

```powershell
.\aws-cli-attach-policy.ps1 `
    -PolicyId "p-12345678" `
    -TargetId "ou-ab12-12345678"
```

### List All Accounts

```powershell
.\aws-cli-list-accounts.ps1
```

## Notes

- Account creation is asynchronous; the script initiates the request
  and returns a status. Check progress with `describe-account`.
- Organizational units must be empty before they can be deleted.
- Service control policies apply to all accounts and OUs below the
  target in the hierarchy.
