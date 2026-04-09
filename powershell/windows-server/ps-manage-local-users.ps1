<#
.SYNOPSIS
    Manage local Windows user accounts and group memberships.

.DESCRIPTION
    Creates, removes, enables, disables, and manages group memberships for local
    Windows user accounts using the built-in LocalAccounts module cmdlets:
    New-LocalUser, Remove-LocalUser, Enable-LocalUser, Disable-LocalUser,
    Add-LocalGroupMember, Remove-LocalGroupMember, and Get-LocalUser.

.PARAMETER Action
    The action to perform: Create, Remove, Enable, Disable, AddToGroup,
    RemoveFromGroup, or List.

.PARAMETER Username
    The local username to operate on. Required for all actions except List.

.PARAMETER Password
    SecureString password for the new user account. Required for Create.

.PARAMETER FullName
    Full display name for the user account (Create action).

.PARAMETER Description
    Description for the user account (Create action).

.PARAMETER GroupName
    Local group name for AddToGroup/RemoveFromGroup actions. Default is Administrators.

.PARAMETER PasswordNeverExpires
    Set the user's password to never expire (Create action).

.PARAMETER UserMustChangePassword
    Require the user to change their password at next logon (Create action).

.EXAMPLE
    .\ps-manage-local-users.ps1 -Action Create -Username "svc-backup" -Password (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -FullName "Backup Service" -PasswordNeverExpires

.EXAMPLE
    .\ps-manage-local-users.ps1 -Action AddToGroup -Username "svc-backup" -GroupName "Remote Desktop Users"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 5.1+ (built-in LocalAccounts module)

.LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.localaccounts/

.COMPONENT
    Windows PowerShell Server Management
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Action to perform: Create, Remove, Enable, Disable, AddToGroup, RemoveFromGroup, or List.")]
    [ValidateSet('Create', 'Remove', 'Enable', 'Disable', 'AddToGroup', 'RemoveFromGroup', 'List')]
    [string]$Action,

    [Parameter(Mandatory = $false, HelpMessage = "Local username to operate on. Required for all actions except List.")]
    [string]$Username,

    [Parameter(Mandatory = $false, HelpMessage = "SecureString password for new user account. Required for Create.")]
    [System.Security.SecureString]$Password,

    [Parameter(Mandatory = $false, HelpMessage = "Full display name for the user account.")]
    [string]$FullName,

    [Parameter(Mandatory = $false, HelpMessage = "Description for the user account.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Local group name for AddToGroup/RemoveFromGroup. Default is Administrators.")]
    [string]$GroupName = 'Administrators',

    [Parameter(Mandatory = $false, HelpMessage = "Set the user's password to never expire.")]
    [switch]$PasswordNeverExpires,

    [Parameter(Mandatory = $false, HelpMessage = "Require the user to change password at next logon.")]
    [switch]$UserMustChangePassword
)

$ErrorActionPreference = 'Stop'

# Validate Username presence for actions that require it
if ($Action -ne 'List' -and -not $Username) {
    throw "Username is required for Action '$Action'."
}
if ($Action -eq 'Create' -and -not $Password) {
    throw "Password is required for Action 'Create'."
}

# Check module availability
if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.LocalAccounts)) {
    throw "Microsoft.PowerShell.LocalAccounts module not found. Requires PowerShell 5.1+ on Windows."
}

try {
    Write-Host "🚀 Starting Local User Management" -ForegroundColor Green
    Write-Host "🔧 Action: $Action" -ForegroundColor Cyan

    switch ($Action) {
        'Create' {
            Write-Host "🔧 Creating local user '$Username'..." -ForegroundColor Cyan
            $newUserParams = @{
                Name                     = $Username
                Password                 = $Password
                PasswordNeverExpires     = $PasswordNeverExpires.IsPresent
                UserMayNotChangePassword = $false
            }
            if ($FullName)    { $newUserParams['FullName']    = $FullName }
            if ($Description) { $newUserParams['Description'] = $Description }
            if ($UserMustChangePassword) {
                $newUserParams['UserMayNotChangePassword'] = $false
            }
            New-LocalUser @newUserParams | Out-Null
            Write-Host "✅ User '$Username' created." -ForegroundColor Green

            if ($UserMustChangePassword) {
                # Force password change at next logon by disabling PasswordNeverExpires and expiring immediately
                Set-LocalUser -Name $Username -PasswordNeverExpires:$false
                Write-Host "ℹ️  User must change password at next logon." -ForegroundColor Yellow
            }
        }
        'Remove' {
            Write-Host "🔧 Removing local user '$Username'..." -ForegroundColor Cyan
            Remove-LocalUser -Name $Username
            Write-Host "✅ User '$Username' removed." -ForegroundColor Green
        }
        'Enable' {
            Write-Host "🔧 Enabling local user '$Username'..." -ForegroundColor Cyan
            Enable-LocalUser -Name $Username
            Write-Host "✅ User '$Username' enabled." -ForegroundColor Green
        }
        'Disable' {
            Write-Host "🔧 Disabling local user '$Username'..." -ForegroundColor Cyan
            Disable-LocalUser -Name $Username
            Write-Host "✅ User '$Username' disabled." -ForegroundColor Green
        }
        'AddToGroup' {
            Write-Host "🔧 Adding '$Username' to group '$GroupName'..." -ForegroundColor Cyan
            Add-LocalGroupMember -Group $GroupName -Member $Username
            Write-Host "✅ '$Username' added to '$GroupName'." -ForegroundColor Green
        }
        'RemoveFromGroup' {
            Write-Host "🔧 Removing '$Username' from group '$GroupName'..." -ForegroundColor Cyan
            Remove-LocalGroupMember -Group $GroupName -Member $Username
            Write-Host "✅ '$Username' removed from '$GroupName'." -ForegroundColor Green
        }
        'List' {
            Write-Host "🔍 Listing all local user accounts..." -ForegroundColor Cyan
            $users = Get-LocalUser
            Write-Host "`n📊 Summary: $($users.Count) user(s) found" -ForegroundColor Blue
            Write-Host ("  {0,-25} {1,-10} {2,-20} {3}" -f "Username", "Enabled", "Last Logon", "Description") -ForegroundColor Cyan
            Write-Host ("  {0,-25} {1,-10} {2,-20} {3}" -f "--------", "-------", "----------", "-----------") -ForegroundColor Cyan
            foreach ($u in $users) {
                $lastLogon = if ($u.LastLogon) { $u.LastLogon.ToString('yyyy-MM-dd HH:mm') } else { 'Never' }
                Write-Host ("  {0,-25} {1,-10} {2,-20} {3}" -f $u.Name, $u.Enabled, $lastLogon, $u.Description)
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
