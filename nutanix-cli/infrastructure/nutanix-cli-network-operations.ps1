<#
.SYNOPSIS
    Manages Nutanix network operations using Nutanix PowerShell SDK.

.DESCRIPTION
    This script provides comprehensive network management including network creation,
    configuration, VLAN management, and IP pool configuration.
    Supports network monitoring and troubleshooting operations.
    Requires Nutanix PowerShell SDK and connection to Prism Central/Element.

.PARAMETER PrismCentral
    The Prism Central FQDN or IP address to connect to.

.PARAMETER PrismElement
    The Prism Element FQDN or IP address to connect to (alternative to Prism Central).

.PARAMETER ClusterName
    Name of the cluster to target for network operations.

.PARAMETER ClusterUUID
    UUID of a specific cluster to target for network operations.

.PARAMETER Operation
    The operation to perform on the network(s).

.PARAMETER NetworkName
    Name of the network to manage.

.PARAMETER NetworkNames
    Array of network names for batch operations.

.PARAMETER NetworkUUID
    UUID of a specific network to manage.

.PARAMETER VlanId
    VLAN ID for network creation or modification.

.PARAMETER NetworkDescription
    Description for the network.

.PARAMETER IPPoolStart
    Starting IP address for the IP pool.

.PARAMETER IPPoolEnd
    Ending IP address for the IP pool.

.PARAMETER Gateway
    Gateway IP address for the network.

.PARAMETER SubnetMask
    Subnet mask for the network.

.PARAMETER DNSServers
    Array of DNS server IP addresses.

.PARAMETER DHCPEnabled
    Enable or disable DHCP for the network.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file.

.PARAMETER Force
    Force operations without confirmation prompts.

.EXAMPLE
    .\nutanix-cli-network-operations.ps1 -PrismCentral "pc.domain.com" -Operation "List" -ClusterName "Prod-Cluster"

.EXAMPLE
    .\nutanix-cli-network-operations.ps1 -PrismCentral "pc.domain.com" -Operation "Create" -NetworkName "VLAN100" -VlanId 100 -NetworkDescription "Production Network"

.EXAMPLE
    .\nutanix-cli-network-operations.ps1 -PrismCentral "pc.domain.com" -Operation "CreateWithPool" -NetworkName "VLAN200" -VlanId 200 -IPPoolStart "192.168.200.10" -IPPoolEnd "192.168.200.100" -Gateway "192.168.200.1" -SubnetMask "255.255.255.0"

.NOTES
    Author: XOAP.io
    Requires: Nutanix PowerShell SDK, AOS 6.0+

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, ParameterSetName = "PrismCentral")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentral,

    [Parameter(Mandatory = $false, ParameterSetName = "PrismElement")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismElement,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$ClusterUUID,

    [Parameter(Mandatory = $true)]
    [ValidateSet("List", "Create", "CreateWithPool", "Delete", "Update", "Status", "Report", "Monitor")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [string[]]$NetworkNames,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$NetworkUUID,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 4094)]
    [int]$VlanId,

    [Parameter(Mandatory = $false)]
    [string]$NetworkDescription,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$IPPoolStart,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$IPPoolEnd,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$Gateway,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
    [string]$SubnetMask,

    [Parameter(Mandatory = $false)]
    [ValidateScript({
        foreach ($dns in $_) {
            if ($dns -notmatch '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
                throw "Invalid DNS server IP address: $dns"
            }
        }
        return $true
    })]
    [string[]]$DNSServers,

    [Parameter(Mandatory = $false)]
    [bool]$DHCPEnabled = $false,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON", "HTML")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to check and install Nutanix PowerShell SDK if needed
function Test-NutanixSDKInstallation {
    Write-Host "Checking Nutanix PowerShell SDK installation..." -ForegroundColor Yellow

    try {
        $nutanixModule = Get-Module -Name Nutanix.PowerShell.SDK -ListAvailable
        if (-not $nutanixModule) {
            Write-Warning "Nutanix PowerShell SDK not found. Installing..."
            Install-Module -Name Nutanix.PowerShell.SDK -Force -AllowClobber -Scope CurrentUser
            Write-Host "Nutanix PowerShell SDK installed successfully." -ForegroundColor Green
        } else {
            $version = $nutanixModule | Sort-Object Version -Descending | Select-Object -First 1
            Write-Host "Nutanix PowerShell SDK version $($version.Version) found." -ForegroundColor Green
        }

        # Import the module
        Import-Module Nutanix.PowerShell.SDK -Force

        return $true
    }
    catch {
        Write-Error "Failed to install or import Nutanix PowerShell SDK: $($_.Exception.Message)"
        return $false
    }
}

# Function to connect to Prism Central or Element
function Connect-ToNutanix {
    param($Server, $ServerType)

    try {
        Write-Host "Connecting to $ServerType`: $Server" -ForegroundColor Yellow

        # Check if already connected
        if ($global:DefaultNTNXConnection -and $global:DefaultNTNXConnection.Server -eq $Server) {
            Write-Host "Already connected to $Server" -ForegroundColor Green
            return $global:DefaultNTNXConnection
        }

        # Connect to Nutanix
        $connection = Connect-NTNXCluster -Server $Server -AcceptInvalidSSLCerts
        Write-Host "Successfully connected to $ServerType`: $($connection.Server)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to $ServerType $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to get target networks
function Get-TargetNetworks {
    param(
        $ClusterName,
        $ClusterUUID,
        $NetworkName,
        $NetworkNames,
        $NetworkUUID
    )

    try {
        $networks = @()
        $allNetworks = Get-NTNXNetwork

        # Filter by cluster if specified
        if ($ClusterName) {
            $cluster = Get-NTNXCluster | Where-Object { $_.name -eq $ClusterName }
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            # Note: Networks may not have cluster association in all Nutanix versions
            # This filter may need adjustment based on your environment
        }
        elseif ($ClusterUUID) {
            # Note: Networks may not have cluster association in all Nutanix versions
            # This filter may need adjustment based on your environment
        }

        # Filter by specific network criteria
        if ($NetworkUUID) {
            $networks = $allNetworks | Where-Object { $_.uuid -eq $NetworkUUID }
        }
        elseif ($NetworkName) {
            $networks = $allNetworks | Where-Object { $_.name -eq $NetworkName }
        }
        elseif ($NetworkNames) {
            $networks = $allNetworks | Where-Object { $_.name -in $NetworkNames }
        }
        else {
            # Return all networks
            $networks = $allNetworks
        }

        if ($Operation -ne "Create" -and $Operation -ne "CreateWithPool" -and -not $networks) {
            throw "No networks found matching the specified criteria"
        }

        if ($networks) {
            Write-Host "Found $($networks.Count) network(s) for processing:" -ForegroundColor Green
            foreach ($network in $networks) {
                $vlanInfo = if ($network.vlanId) { " (VLAN $($network.vlanId))" } else { " (No VLAN)" }
                Write-Host "  - $($network.name)$vlanInfo [$($network.uuid)]" -ForegroundColor White
            }
        }

        return $networks
    }
    catch {
        Write-Error "Failed to get target networks: $($_.Exception.Message)"
        throw
    }
}

# Function to list networks
function Get-NetworkList {
    param($Networks)

    try {
        Write-Host "  Listing networks..." -ForegroundColor Cyan

        $networkList = @()

        foreach ($network in $Networks) {
            $networkInfo = @{
                NetworkName = $network.name
                NetworkUUID = $network.uuid
                VlanId = if ($network.vlanId) { $network.vlanId } else { "None" }
                Type = if ($network.vlanId) { "VLAN" } else { "Unmanaged" }
                Description = if ($network.description) { $network.description } else { "No description" }
                IPConfig = if ($network.ipConfig) {
                    @{
                        Gateway = $network.ipConfig.defaultGateway
                        SubnetMask = $network.ipConfig.subnetMask
                        DHCPEnabled = $network.ipConfig.dhcpServerAddress -ne $null
                        DNSServers = $network.ipConfig.dnsServerIpList -join ", "
                        Pool = if ($network.ipConfig.pool) {
                            "$($network.ipConfig.pool.startIpAddress) - $($network.ipConfig.pool.endIpAddress)"
                        } else { "None" }
                    }
                } else { "Not configured" }
                LastUpdated = Get-Date
            }

            $networkList += $networkInfo
        }

        Write-Host "    ✓ Network list compiled - $($networkList.Count) networks" -ForegroundColor Green

        return $networkList
    }
    catch {
        Write-Warning "    Failed to list networks: $($_.Exception.Message)"
        return @()
    }
}

# Function to create a network
function New-NutanixNetwork {
    param($NetworkName, $VlanId, $NetworkDescription)

    try {
        Write-Host "  Creating network: $NetworkName" -ForegroundColor Cyan

        # Check if network already exists
        $existingNetwork = Get-NTNXNetwork | Where-Object { $_.name -eq $NetworkName }
        if ($existingNetwork) {
            throw "Network '$NetworkName' already exists"
        }

        # Prepare network specification
        $networkSpec = @{
            name = $NetworkName
        }

        if ($VlanId) {
            $networkSpec.vlanId = $VlanId
            Write-Host "    Adding VLAN ID: $VlanId" -ForegroundColor White
        }

        if ($NetworkDescription) {
            $networkSpec.description = $NetworkDescription
            Write-Host "    Adding description: $NetworkDescription" -ForegroundColor White
        }

        # Create the network
        Write-Host "    Creating network..." -ForegroundColor Yellow
        $result = New-NTNXNetwork @networkSpec

        Write-Host "    ✓ Network '$NetworkName' created successfully" -ForegroundColor Green

        return @{
            NetworkName = $NetworkName
            NetworkUUID = $result.uuid
            VlanId = $VlanId
            Description = $NetworkDescription
            Operation = "Create"
            Status = "Success"
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to create network: $($_.Exception.Message)"
        return @{
            NetworkName = $NetworkName
            Operation = "Create"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to create a network with IP pool
function New-NutanixNetworkWithPool {
    param($NetworkName, $VlanId, $NetworkDescription, $IPPoolStart, $IPPoolEnd, $Gateway, $SubnetMask, $DNSServers, $DHCPEnabled)

    try {
        Write-Host "  Creating network with IP pool: $NetworkName" -ForegroundColor Cyan

        # Check if network already exists
        $existingNetwork = Get-NTNXNetwork | Where-Object { $_.name -eq $NetworkName }
        if ($existingNetwork) {
            throw "Network '$NetworkName' already exists"
        }

        # Validate required parameters for IP pool
        if (-not $IPPoolStart -or -not $IPPoolEnd -or -not $Gateway -or -not $SubnetMask) {
            throw "IPPoolStart, IPPoolEnd, Gateway, and SubnetMask are required for CreateWithPool operation"
        }

        # Prepare network specification
        $networkSpec = @{
            name = $NetworkName
        }

        if ($VlanId) {
            $networkSpec.vlanId = $VlanId
            Write-Host "    Adding VLAN ID: $VlanId" -ForegroundColor White
        }

        if ($NetworkDescription) {
            $networkSpec.description = $NetworkDescription
            Write-Host "    Adding description: $NetworkDescription" -ForegroundColor White
        }

        # Add IP configuration
        $ipConfig = @{
            defaultGateway = $Gateway
            subnetMask = $SubnetMask
            pool = @{
                startIpAddress = $IPPoolStart
                endIpAddress = $IPPoolEnd
            }
        }

        if ($DNSServers) {
            $ipConfig.dnsServerIpList = $DNSServers
            Write-Host "    Adding DNS servers: $($DNSServers -join ', ')" -ForegroundColor White
        }

        if ($DHCPEnabled) {
            # Note: DHCP configuration may require additional parameters
            # This is a basic implementation
            Write-Host "    Enabling DHCP (basic configuration)" -ForegroundColor White
        }

        $networkSpec.ipConfig = $ipConfig

        Write-Host "    IP Pool: $IPPoolStart - $IPPoolEnd" -ForegroundColor White
        Write-Host "    Gateway: $Gateway" -ForegroundColor White
        Write-Host "    Subnet Mask: $SubnetMask" -ForegroundColor White

        # Create the network
        Write-Host "    Creating network with IP configuration..." -ForegroundColor Yellow
        $result = New-NTNXNetwork @networkSpec

        Write-Host "    ✓ Network '$NetworkName' with IP pool created successfully" -ForegroundColor Green

        return @{
            NetworkName = $NetworkName
            NetworkUUID = $result.uuid
            VlanId = $VlanId
            Description = $NetworkDescription
            IPPoolStart = $IPPoolStart
            IPPoolEnd = $IPPoolEnd
            Gateway = $Gateway
            SubnetMask = $SubnetMask
            DNSServers = $DNSServers -join ", "
            DHCPEnabled = $DHCPEnabled
            Operation = "CreateWithPool"
            Status = "Success"
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to create network with IP pool: $($_.Exception.Message)"
        return @{
            NetworkName = $NetworkName
            Operation = "CreateWithPool"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to delete a network
function Remove-NutanixNetwork {
    param($Network, $Force)

    try {
        Write-Host "  Deleting network: $($Network.name)" -ForegroundColor Cyan

        # Check if VMs are using this network
        $vmsUsingNetwork = Get-NTNXVM | Where-Object {
            $_.nics | Where-Object { $_.networkUuid -eq $Network.uuid }
        }

        if ($vmsUsingNetwork.Count -gt 0 -and -not $Force) {
            Write-Warning "    Network is in use by $($vmsUsingNetwork.Count) VM(s). Use -Force to delete anyway."
            Write-Host "    VMs using this network:" -ForegroundColor Yellow
            foreach ($vm in $vmsUsingNetwork) {
                Write-Host "      - $($vm.vmName)" -ForegroundColor Yellow
            }
            return @{
                NetworkName = $Network.name
                NetworkUUID = $Network.uuid
                Operation = "Delete"
                Status = "Blocked"
                Reason = "Network is in use by VMs"
                VMsUsing = $vmsUsingNetwork.Count
                LastUpdated = Get-Date
            }
        }

        # Confirm deletion
        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to delete network '$($Network.name)'? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Host "    Deletion cancelled by user" -ForegroundColor Yellow
                return @{
                    NetworkName = $Network.name
                    NetworkUUID = $Network.uuid
                    Operation = "Delete"
                    Status = "Cancelled"
                    LastUpdated = Get-Date
                }
            }
        }

        # Delete the network
        Write-Host "    Deleting network..." -ForegroundColor Yellow
        Remove-NTNXNetwork -NetworkUuid $Network.uuid

        Write-Host "    ✓ Network '$($Network.name)' deleted successfully" -ForegroundColor Green

        return @{
            NetworkName = $Network.name
            NetworkUUID = $Network.uuid
            Operation = "Delete"
            Status = "Success"
            LastUpdated = Get-Date
        }
    }
    catch {
        Write-Error "    Failed to delete network: $($_.Exception.Message)"
        return @{
            NetworkName = $Network.name
            NetworkUUID = $Network.uuid
            Operation = "Delete"
            Status = "Failed"
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to get network status
function Get-NetworkStatus {
    param($Network)

    try {
        Write-Host "  Getting network status: $($Network.name)" -ForegroundColor Cyan

        # Get VMs using this network
        $vmsUsingNetwork = Get-NTNXVM | Where-Object {
            $_.nics | Where-Object { $_.networkUuid -eq $Network.uuid }
        }

        $status = @{
            NetworkName = $Network.name
            NetworkUUID = $Network.uuid
            VlanId = if ($Network.vlanId) { $Network.vlanId } else { "None" }
            Type = if ($Network.vlanId) { "VLAN" } else { "Unmanaged" }
            Description = if ($Network.description) { $Network.description } else { "No description" }
            VMsConnected = $vmsUsingNetwork.Count
            VMNames = ($vmsUsingNetwork | Select-Object -ExpandProperty vmName) -join ", "
            IPConfiguration = @{
                HasIPConfig = $Network.ipConfig -ne $null
                Gateway = if ($Network.ipConfig) { $Network.ipConfig.defaultGateway } else { "Not configured" }
                SubnetMask = if ($Network.ipConfig) { $Network.ipConfig.subnetMask } else { "Not configured" }
                DHCPEnabled = if ($Network.ipConfig) { $Network.ipConfig.dhcpServerAddress -ne $null } else { $false }
                DNSServers = if ($Network.ipConfig -and $Network.ipConfig.dnsServerIpList) {
                    $Network.ipConfig.dnsServerIpList -join ", "
                } else { "Not configured" }
                IPPool = if ($Network.ipConfig -and $Network.ipConfig.pool) {
                    "$($Network.ipConfig.pool.startIpAddress) - $($Network.ipConfig.pool.endIpAddress)"
                } else { "Not configured" }
            }
            LastUpdated = Get-Date
        }

        Write-Host "    ✓ Status collected - $($status.VMsConnected) VMs connected" -ForegroundColor Green

        return $status
    }
    catch {
        Write-Warning "    Failed to get network status: $($_.Exception.Message)"
        return @{
            NetworkName = $Network.name
            NetworkUUID = $Network.uuid
            Error = $_.Exception.Message
            LastUpdated = Get-Date
        }
    }
}

# Function to monitor network usage
function Monitor-NetworkUsage {
    param($Networks)

    try {
        Write-Host "  Monitoring network usage..." -ForegroundColor Cyan

        $monitoringResults = @()

        foreach ($network in $Networks) {
            # Get VMs using this network
            $vmsUsingNetwork = Get-NTNXVM | Where-Object {
                $_.nics | Where-Object { $_.networkUuid -eq $network.uuid }
            }

            $poweredOnVMs = $vmsUsingNetwork | Where-Object { $_.powerState -eq "ON" }

            $networkMonitoring = @{
                NetworkName = $network.name
                NetworkUUID = $network.uuid
                VlanId = if ($network.vlanId) { $network.vlanId } else { "None" }
                TotalVMs = $vmsUsingNetwork.Count
                ActiveVMs = $poweredOnVMs.Count
                InactiveVMs = $vmsUsingNetwork.Count - $poweredOnVMs.Count
                UtilizationStatus = if ($vmsUsingNetwork.Count -eq 0) { "Unused" }
                                  elseif ($poweredOnVMs.Count -eq 0) { "Inactive" }
                                  else { "Active" }
                IPPoolUtilization = if ($network.ipConfig -and $network.ipConfig.pool) {
                    # Basic IP pool usage calculation
                    # Note: Actual IP utilization would require more detailed API calls
                    $poolSize = [System.Net.IPAddress]::Parse($network.ipConfig.pool.endIpAddress).Address - [System.Net.IPAddress]::Parse($network.ipConfig.pool.startIpAddress).Address + 1
                    $utilizationPercent = if ($poolSize -gt 0) {
                        [math]::Round(($poweredOnVMs.Count / $poolSize) * 100, 2)
                    } else { 0 }
                    @{
                        PoolSize = $poolSize
                        EstimatedUsed = $poweredOnVMs.Count
                        EstimatedUtilizationPercent = $utilizationPercent
                    }
                } else { "No IP pool configured" }
                Timestamp = Get-Date
            }

            $monitoringResults += $networkMonitoring
        }

        Write-Host "    ✓ Network monitoring completed - $($monitoringResults.Count) networks analyzed" -ForegroundColor Green

        return $monitoringResults
    }
    catch {
        Write-Warning "    Failed to monitor network usage: $($_.Exception.Message)"
        return @()
    }
}

# Function to display results
function Show-NetworkResults {
    param($Results, $Operation, $OutputFormat, $OutputPath)

    Write-Host "`n=== Network $Operation Results ===" -ForegroundColor Cyan

    switch ($Operation) {
        "List" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nNetwork List:" -ForegroundColor Green
                foreach ($result in $Results) {
                    Write-Host "$($result.NetworkName) ($($result.Type))" -ForegroundColor White
                    if ($result.VlanId -ne "None") {
                        Write-Host "  VLAN ID: $($result.VlanId)" -ForegroundColor Gray
                    }
                    if ($result.IPConfig -ne "Not configured") {
                        Write-Host "  Gateway: $($result.IPConfig.Gateway)" -ForegroundColor Gray
                        if ($result.IPConfig.Pool -ne "None") {
                            Write-Host "  IP Pool: $($result.IPConfig.Pool)" -ForegroundColor Gray
                        }
                    }
                }
            }
        }
        "Monitor" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nNetwork Usage Monitoring:" -ForegroundColor Green
                $Results | Format-Table NetworkName, VlanId, TotalVMs, ActiveVMs, UtilizationStatus -AutoSize

                # Show detailed IP pool utilization
                $poolResults = $Results | Where-Object { $_.IPPoolUtilization -ne "No IP pool configured" }
                if ($poolResults) {
                    Write-Host "`nIP Pool Utilization:" -ForegroundColor Green
                    foreach ($result in $poolResults) {
                        Write-Host "$($result.NetworkName):" -ForegroundColor White
                        Write-Host "  Pool Size: $($result.IPPoolUtilization.PoolSize)" -ForegroundColor White
                        Write-Host "  Estimated Used: $($result.IPPoolUtilization.EstimatedUsed)" -ForegroundColor White
                        Write-Host "  Estimated Utilization: $($result.IPPoolUtilization.EstimatedUtilizationPercent)%" -ForegroundColor White
                    }
                }
            }
        }
        "Status" {
            if ($OutputFormat -eq "Console") {
                Write-Host "`nNetwork Status:" -ForegroundColor Green
                foreach ($result in $Results) {
                    Write-Host "`nNetwork: $($result.NetworkName)" -ForegroundColor White
                    Write-Host "  Type: $($result.Type)" -ForegroundColor White
                    if ($result.VlanId -ne "None") {
                        Write-Host "  VLAN ID: $($result.VlanId)" -ForegroundColor White
                    }
                    Write-Host "  Connected VMs: $($result.VMsConnected)" -ForegroundColor White
                    Write-Host "  IP Configuration:" -ForegroundColor White
                    Write-Host "    Gateway: $($result.IPConfiguration.Gateway)" -ForegroundColor Gray
                    Write-Host "    Subnet Mask: $($result.IPConfiguration.SubnetMask)" -ForegroundColor Gray
                    Write-Host "    DHCP Enabled: $($result.IPConfiguration.DHCPEnabled)" -ForegroundColor Gray
                    Write-Host "    IP Pool: $($result.IPConfiguration.IPPool)" -ForegroundColor Gray
                }
            }
        }
        default {
            if ($OutputFormat -eq "Console") {
                $Results | Format-Table -AutoSize
            }
        }
    }

    # Export results if requested
    if ($OutputFormat -ne "Console") {
        switch ($OutputFormat) {
            "CSV" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Network_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $Results | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Network_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nResults exported to: $OutputPath" -ForegroundColor Green
            }
            "HTML" {
                if (-not $OutputPath) {
                    $OutputPath = "Nutanix_Network_$Operation`_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
                }
                $htmlContent = $Results | ConvertTo-Html -Title "Nutanix Network $Operation Report" -Head "<style>table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background-color:#f2f2f2;}</style>"
                $htmlContent | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nHTML report generated: $OutputPath" -ForegroundColor Green
            }
        }
    }
}

# Main execution
try {
    Write-Host "=== Nutanix Network Operations ===" -ForegroundColor Cyan

    # Determine target server
    $targetServer = if ($PrismCentral) { $PrismCentral } else { $PrismElement }
    $serverType = if ($PrismCentral) { "Prism Central" } else { "Prism Element" }

    if (-not $targetServer) {
        throw "Either PrismCentral or PrismElement parameter must be specified"
    }

    Write-Host "Target $serverType`: $targetServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White
    Write-Host ""

    # Check and install Nutanix PowerShell SDK
    if (-not (Test-NutanixSDKInstallation)) {
        throw "Nutanix PowerShell SDK installation failed"
    }

    # Connect to Nutanix
    $connection = Connect-ToNutanix -Server $targetServer -ServerType $serverType

    # Get target networks (not needed for create operations)
    $targetNetworks = @()
    if ($Operation -notin @("Create", "CreateWithPool")) {
        $targetNetworks = Get-TargetNetworks -ClusterName $ClusterName -ClusterUUID $ClusterUUID -NetworkName $NetworkName -NetworkNames $NetworkNames -NetworkUUID $NetworkUUID
    }

    # Perform operations
    $results = @()

    switch ($Operation) {
        "List" {
            $results = Get-NetworkList -Networks $targetNetworks
        }
        "Create" {
            if (-not $NetworkName) {
                throw "NetworkName parameter is required for Create operation"
            }
            $result = New-NutanixNetwork -NetworkName $NetworkName -VlanId $VlanId -NetworkDescription $NetworkDescription
            $results += $result
        }
        "CreateWithPool" {
            if (-not $NetworkName) {
                throw "NetworkName parameter is required for CreateWithPool operation"
            }
            $result = New-NutanixNetworkWithPool -NetworkName $NetworkName -VlanId $VlanId -NetworkDescription $NetworkDescription -IPPoolStart $IPPoolStart -IPPoolEnd $IPPoolEnd -Gateway $Gateway -SubnetMask $SubnetMask -DNSServers $DNSServers -DHCPEnabled $DHCPEnabled
            $results += $result
        }
        "Delete" {
            foreach ($network in $targetNetworks) {
                $result = Remove-NutanixNetwork -Network $network -Force:$Force
                $results += $result
            }
        }
        "Status" {
            foreach ($network in $targetNetworks) {
                $result = Get-NetworkStatus -Network $network
                $results += $result
            }
        }
        "Report" {
            foreach ($network in $targetNetworks) {
                $result = Get-NetworkStatus -Network $network
                $results += $result
            }
        }
        "Monitor" {
            $results = Monitor-NetworkUsage -Networks $targetNetworks
        }
        "Update" {
            Write-Host "Update operation not yet implemented" -ForegroundColor Yellow
            $results += @{
                Operation = "Update"
                Status = "Not Implemented"
                Message = "Network update operations require specific implementation"
            }
        }
    }

    # Display results
    Show-NetworkResults -Results $results -Operation $Operation -OutputFormat $OutputFormat -OutputPath $OutputPath

    Write-Host "`n=== Network Operations Completed ===" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from Nutanix if connected
    if ($global:DefaultNTNXConnection) {
        Write-Host "`nDisconnecting from Nutanix..." -ForegroundColor Yellow
        Disconnect-NTNXCluster
    }
}
