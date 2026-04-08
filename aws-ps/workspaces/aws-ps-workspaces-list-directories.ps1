<#
.SYNOPSIS
    List AWS WorkSpaces directories.

.DESCRIPTION
    This script retrieves and lists AWS WorkSpaces directories using the Get-WKSDirectory cmdlet from AWS.Tools.WorkSpaces.
    Optionally filters by directory ID.

.PARAMETER DirectoryId
    (Optional) Filter by a specific directory ID.

.EXAMPLE
    .\aws-ps-workspaces-list-directories.ps1

.EXAMPLE
    .\aws-ps-workspaces-list-directories.ps1 -DirectoryId d-1234567890

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.WorkSpaces

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Optional directory ID to filter results.")]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving WorkSpaces directories..." -ForegroundColor Cyan

    if ($DirectoryId) {
        $directories = Get-WKSDirectory -DirectoryId $DirectoryId
    } else {
        $directories = Get-WKSDirectory
    }

    if ($directories) {
        Write-Host "Found $($directories.Count) directory(ies):" -ForegroundColor Green

        foreach ($dir in $directories) {
            Write-Host ""
            Write-Host "Directory ID: $($dir.DirectoryId)" -ForegroundColor White
            Write-Host "  Name: $($dir.DirectoryName)" -ForegroundColor White
            Write-Host "  Type: $($dir.DirectoryType)" -ForegroundColor White
            Write-Host "  State: $($dir.State)" -ForegroundColor White
            Write-Host "  Alias: $($dir.Alias)" -ForegroundColor White
            Write-Host "  Customer Username: $($dir.CustomerUserName)" -ForegroundColor White
            Write-Host "  Registration Code: $($dir.RegistrationCode)" -ForegroundColor White

            if ($dir.SubnetIds) {
                Write-Host "  Subnet IDs: $($dir.SubnetIds -join ', ')" -ForegroundColor White
            }

            if ($dir.DnsIpAddresses) {
                Write-Host "  DNS IP Addresses: $($dir.DnsIpAddresses -join ', ')" -ForegroundColor White
            }

            if ($dir.WorkspaceCreationProperties) {
                Write-Host "  Creation Properties:" -ForegroundColor White
                Write-Host "    Enable Internet Access: $($dir.WorkspaceCreationProperties.EnableInternetAccess)" -ForegroundColor Gray
                Write-Host "    Enable Maintenance Mode: $($dir.WorkspaceCreationProperties.EnableMaintenanceMode)" -ForegroundColor Gray
                Write-Host "    User Enabled As Local Admin: $($dir.WorkspaceCreationProperties.UserEnabledAsLocalAdministrator)" -ForegroundColor Gray
                Write-Host "    Default OU: $($dir.WorkspaceCreationProperties.DefaultOu)" -ForegroundColor Gray
                Write-Host "    Custom Security Group: $($dir.WorkspaceCreationProperties.CustomSecurityGroupId)" -ForegroundColor Gray
            }
        }

        return $directories
    } else {
        Write-Host "No directories found" -ForegroundColor Yellow
        return @()
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
