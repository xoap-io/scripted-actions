# WorkSpaces Scripts

PowerShell scripts for creating, managing, and monitoring Amazon
WorkSpaces using AWS Tools for PowerShell.

## Prerequisites

- AWS Tools for PowerShell:
  - `Install-Module -Name AWS.Tools.WorkSpaces`
  - `Install-Module -Name AWS.Tools.EC2` (required by
    `workspace-quickstart1.ps1`)
  - `Install-Module -Name AWS.Tools.SimpleAD` (required by
    `workspace-quickstart1.ps1`)
- Appropriate AWS credentials configured
- An existing WorkSpaces directory (except when using
  `workspace-quickstart1.ps1`, which creates one)

## Available Scripts

| Script                                                  | Description                                                                                       |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `aws-ps-create-workspace.ps1`                           | Creates a WorkSpace for a user given a bundle ID and directory ID                                 |
| `aws-ps-reboot-workspace.ps1`                           | Reboots a single WorkSpace by ID                                                                  |
| `aws-ps-workspaces-bulk-create.ps1`                     | Creates multiple WorkSpaces from a CSV file or array of hashtables                                |
| `aws-ps-workspaces-bulk-delete.ps1`                     | Terminates multiple WorkSpaces from a CSV file, ID list, or filter criteria                       |
| `aws-ps-workspaces-create-user.ps1`                     | Creates a user in a WorkSpaces directory                                                          |
| `aws-ps-workspaces-create-workspace.ps1`                | Creates a WorkSpace with detailed configuration (compute type, storage, running mode, tags)       |
| `aws-ps-workspaces-delete-user.ps1`                     | Deletes a user from a WorkSpaces directory, checking for active WorkSpaces first                  |
| `aws-ps-workspaces-delete-workspace.ps1`                | Terminates one or more WorkSpaces, skipping already-terminated instances                          |
| `aws-ps-workspaces-describe-bundle.ps1`                 | Retrieves and displays details of a specific WorkSpaces bundle                                    |
| `aws-ps-workspaces-describe-workspace.ps1`              | Retrieves and displays detailed information about a specific WorkSpace                            |
| `aws-ps-workspaces-get-workspace-connection-status.ps1` | Retrieves connection status for one or more WorkSpaces                                            |
| `aws-ps-workspaces-list-bundles.ps1`                    | Lists available WorkSpaces bundles, with optional filtering by owner or bundle ID                 |
| `aws-ps-workspaces-list-directories.ps1`                | Lists registered WorkSpaces directories, with optional filtering by directory ID                  |
| `aws-ps-workspaces-list-tags.ps1`                       | Lists all tags associated with a WorkSpace                                                        |
| `aws-ps-workspaces-list-users.ps1`                      | Lists users in a WorkSpaces directory                                                             |
| `aws-ps-workspaces-list-workspace-usage.ps1`            | Retrieves usage information for WorkSpaces with optional date and user filters                    |
| `aws-ps-workspaces-list-workspaces.ps1`                 | Lists WorkSpaces with optional filtering by directory, user, state, or bundle                     |
| `aws-ps-workspaces-migrate-workspace.ps1`               | Migrates a WorkSpace to a different bundle                                                        |
| `aws-ps-workspaces-modify-workspace-properties.ps1`     | Modifies compute type, volume sizes, or running mode for a WorkSpace                              |
| `aws-ps-workspaces-reboot-workspace.ps1`                | Reboots one or more WorkSpaces, skipping those not in a rebootable state                          |
| `aws-ps-workspaces-reset-user-password.ps1`             | Resets the password for a user in a WorkSpaces directory                                          |
| `aws-ps-workspaces-start-workspace.ps1`                 | Starts one or more stopped WorkSpaces                                                             |
| `aws-ps-workspaces-stop-workspace.ps1`                  | Stops one or more running WorkSpaces                                                              |
| `aws-ps-workspaces-tag-workspace.ps1`                   | Adds key-value tags to one or more WorkSpaces                                                     |
| `aws-ps-workspaces-untag-workspace.ps1`                 | Removes tags from one or more WorkSpaces by tag key                                               |
| `workspace-quickstart1.ps1`                             | Deploys a complete WorkSpaces environment including VPC, Simple AD directory, user, and WorkSpace |

## Usage Examples

### WorkSpaces Quickstart (full environment)

```powershell
.\workspace-quickstart1.ps1 `
    -Region eu-central-1 `
    -VpcCidr 10.0.0.0/16 `
    -Subnet1Cidr 10.0.1.0/24 `
    -Subnet2Cidr 10.0.2.0/24 `
    -DirectoryName corp.example.com `
    -AdminPassword (Read-Host -AsSecureString) `
    -DirectoryShortName CORP `
    -WorkspaceUser jdoe `
    -WorkspacePassword (Read-Host -AsSecureString) `
    -BundleId wsb-bh8rsxt14
```

### Create a Single WorkSpace

```powershell
.\aws-ps-workspaces-create-workspace.ps1 `
    -DirectoryId d-1234567890ab `
    -UserName jdoe `
    -BundleId wsb-abc12345 `
    -RunningMode AUTO_STOP `
    -ComputeTypeName VALUE
```

### Bulk Create WorkSpaces from CSV

```powershell
.\aws-ps-workspaces-bulk-create.ps1 -CsvFilePath .\workspaces.csv
```

CSV format: `DirectoryId,UserName,BundleId,ComputeTypeName,RunningMode`

### List WorkSpaces by State

```powershell
.\aws-ps-workspaces-list-workspaces.ps1 `
    -State AVAILABLE `
    -DirectoryId d-1234567890ab
```

### Migrate a WorkSpace to a New Bundle

```powershell
.\aws-ps-workspaces-migrate-workspace.ps1 `
    -WorkspaceId ws-abc12345 `
    -TargetBundleId wsb-xyz98765
```

### Add Tags to a WorkSpace

```powershell
.\aws-ps-workspaces-tag-workspace.ps1 `
    -WorkspaceId ws-abc12345 `
    -Tags @{Environment='Production'; Owner='TeamA'}
```

### Reset a User Password

```powershell
.\aws-ps-workspaces-reset-user-password.ps1 `
    -DirectoryId d-1234567890ab `
    -UserName jdoe `
    -NewPassword (Read-Host -AsSecureString)
```

## Notes

- Use `AUTO_STOP` running mode for users who connect intermittently
  to reduce costs. Use `ALWAYS_ON` for users who connect more than
  roughly 80 hours per month.
- Scripts that accept an array of WorkSpace IDs (start, stop, reboot,
  delete, tag) skip entries that are already in the target state or
  in a state that does not permit the operation.
- The `-WhatIf` switch on bulk create and bulk delete previews which
  WorkSpaces would be affected without making changes.
