[CmdletBinding()]
param(
    [Parameter()]
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
} catch {
    Write-Error "Failed to list directories: $_"
    exit 1
}
