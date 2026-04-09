# WorkSpaces Scripts

PowerShell scripts for managing Amazon WorkSpaces using the AWS CLI.
Covers workspace provisioning, lifecycle management, bundle and image
management, directory registration, tagging, and user operations.

## Prerequisites

- AWS CLI v2
- Appropriate AWS credentials configured

## Available Scripts

| Script                                             | Description                                                             |
| -------------------------------------------------- | ----------------------------------------------------------------------- |
| `aws-cli-create-tag.ps1`                           | Adds a single tag to a WorkSpace using a key-value specification string |
| `aws-cli-create-tags.ps1`                          | Adds multiple tags to a WorkSpace using an array of key-value pairs     |
| `aws-cli-create-workspace-bundle.ps1`              | Creates a custom WorkSpace bundle                                       |
| `aws-cli-create-workspace-image.ps1`               | Creates a custom WorkSpace image from an existing WorkSpace             |
| `aws-cli-create-workspace.ps1`                     | Provisions a new WorkSpace for a user in a registered directory         |
| `aws-cli-delete-tag.ps1`                           | Removes a tag from a WorkSpace                                          |
| `aws-cli-delete-workspace-image.ps1`               | Deletes a custom WorkSpace image                                        |
| `aws-cli-deregister-workspace-directory.ps1`       | Deregisters a directory from WorkSpaces                                 |
| `aws-cli-describe-workspace-bundles.ps1`           | Lists available WorkSpace bundles                                       |
| `aws-cli-describe-workspace-directories.ps1`       | Lists registered WorkSpace directories                                  |
| `aws-cli-describe-workspace-snapshots.ps1`         | Lists snapshots for a WorkSpace                                         |
| `aws-cli-describe-workspaces.ps1`                  | Lists and describes WorkSpaces                                          |
| `aws-cli-list-available-workspace-images.ps1`      | Lists available WorkSpace images                                        |
| `aws-cli-list-workspace-directories.ps1`           | Lists WorkSpace directory identifiers                                   |
| `aws-cli-list-workspace-users.ps1`                 | Lists users in a WorkSpaces directory                                   |
| `aws-cli-migrate-workspace.ps1`                    | Migrates a WorkSpace to a different bundle                              |
| `aws-cli-modify-workspace-creation-properties.ps1` | Modifies default creation properties for a WorkSpaces directory         |
| `aws-cli-modify-workspace-properties.ps1`          | Modifies compute type, volume size, or running mode of a WorkSpace      |
| `aws-cli-modify-workspace-state.ps1`               | Changes the state of a WorkSpace (e.g., AVAILABLE or ADMIN_MAINTENANCE) |
| `aws-cli-reboot-workspace.ps1`                     | Reboots a running WorkSpace                                             |
| `aws-cli-rebuild-workspace.ps1`                    | Rebuilds a WorkSpace to its original state                              |
| `aws-cli-recover-workspace.ps1`                    | Recovers a WorkSpace that is in an unhealthy state                      |
| `aws-cli-register-workspace-directory.ps1`         | Registers a directory with Amazon WorkSpaces                            |
| `aws-cli-restore-workspace.ps1`                    | Restores a WorkSpace from a snapshot                                    |
| `aws-cli-start-workspace.ps1`                      | Starts a stopped WorkSpace                                              |
| `aws-cli-stop-worksapce.ps1`                       | Stops a running WorkSpace                                               |
| `aws-cli-terminate-workspace.ps1`                  | Permanently terminates a WorkSpace and deletes its data                 |

## Usage Examples

### Create a WorkSpace

```powershell
.\aws-cli-create-workspace.ps1 `
    -AwsDirectoryId "d-1234567890" `
    -AwsWorkspaceBundleId "wsb-12345678" `
    -AwsUserName "johndoe" `
    -AwsRunningMode "AUTO_STOP"
```

### Stop a WorkSpace

```powershell
.\aws-cli-stop-worksapce.ps1 -AwsWorkspaceId "ws-12345678"
```

### Modify WorkSpace Properties

```powershell
.\aws-cli-modify-workspace-properties.ps1 `
    -AwsWorkspaceId "ws-12345678" `
    -AwsRunningMode "ALWAYS_ON" `
    -AwsRootVolumeSizeGib 80
```

### Migrate a WorkSpace to a Different Bundle

```powershell
.\aws-cli-migrate-workspace.ps1 `
    -AwsSourceWorkspaceId "ws-12345678" `
    -AwsWorkspaceBundleId "wsb-87654321"
```

### Tag a WorkSpace (Multiple Tags)

```powershell
.\aws-cli-create-tags.ps1 `
    -AwsWorkspaceId "ws-12345678" `
    -AwsTags @{Key="Environment";Value="Production"},@{Key="Owner";Value="Alice"}
```

### Register a Directory

```powershell
.\aws-cli-register-workspace-directory.ps1 -AwsDirectoryId "d-1234567890"
```

## Notes

- `aws-cli-stop-worksapce.ps1` contains a typo in the filename
  ("worksapce"); use the exact filename when calling the script.
- `AUTO_STOP` running mode stops the WorkSpace after a configurable
  idle period and is recommended for users who do not work full-time.
- `ALWAYS_ON` keeps the WorkSpace running continuously and is billed
  at a fixed monthly rate.
- Terminating a WorkSpace permanently deletes all user data stored on
  the WorkSpace volumes.
