<#
.SYNOPSIS
    Manages vSphere virtual networks, port groups, and vSwitches using PowerCLI.

.DESCRIPTION
    This script provides comprehensive network management including virtual switches,
    port groups, VLAN configuration, network adapters, and traffic analysis.
    Supports both standard and distributed virtual switches.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER Operation
    The network operation to perform.

.PARAMETER HostName
    The ESXi host for standard switch operations.

.PARAMETER ClusterName
    The cluster name for distributed switch operations.

.PARAMETER SwitchName
    Name of the virtual switch to manage.

.PARAMETER SwitchType
    Type of virtual switch.

.PARAMETER PortGroupName
    Name of the port group to manage.

.PARAMETER VLANID
    VLAN ID for the port group (0-4094, 0 for no VLAN).

.PARAMETER NumPorts
    Number of ports for the port group.

.PARAMETER PhysicalAdapters
    Array of physical network adapter names to add to the switch.

.PARAMETER MTU
    Maximum Transmission Unit size (1500-9000 bytes).

.PARAMETER SecurityPolicy
    Security policy settings for the port group.

.PARAMETER NetworkPolicy
    Network policy type for advanced configurations.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file (optional).

.PARAMETER Force
    Force operations without confirmation prompts.

.EXAMPLE
    .\vsphere-cli-network-operations.ps1 -VCenterServer "vcenter.domain.com" -Operation "CreatePortGroup" -HostName "esx01.domain.com" -SwitchName "vSwitch0" -PortGroupName "Production_VLAN100" -VLANID 100

.EXAMPLE
    .\vsphere-cli-network-operations.ps1 -VCenterServer "vcenter.domain.com" -Operation "CreateDistributedSwitch" -SwitchName "DSwitch-Production" -ClusterName "Production"

.EXAMPLE
    .\vsphere-cli-network-operations.ps1 -VCenterServer "vcenter.domain.com" -Operation "Report" -OutputFormat "CSV" -OutputPath "network-report.csv"

.EXAMPLE
    .\vsphere-cli-network-operations.ps1 -VCenterServer "vcenter.domain.com" -Operation "ConfigureUplinkTeaming" -HostName "esx01.domain.com" -SwitchName "vSwitch0" -PhysicalAdapters @("vmnic0", "vmnic1")

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: VMware PowerCLI (Install-Module -Name VMware.PowerCLI)

.LINK
    https://developer.vmware.com/docs/powercli/

.COMPONENT
    VMware vSphere PowerCLI
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "The vCenter Server FQDN or IP address to connect to.")]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $true, HelpMessage = "The network operation to perform (e.g. CreatePortGroup, CreateStandardSwitch, Report, NetworkHealth).")]
    [ValidateSet("CreatePortGroup", "DeletePortGroup", "CreateStandardSwitch", "DeleteStandardSwitch",
                 "CreateDistributedSwitch", "DeleteDistributedSwitch", "ConfigureUplinkTeaming",
                 "ConfigureSecurity", "ConfigureTrafficShaping", "Report", "NetworkHealth", "VMNetworkInfo")]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "The ESXi host for standard switch operations.")]
    [string]$HostName,

    [Parameter(Mandatory = $false, HelpMessage = "The cluster name for distributed switch operations.")]
    [string]$ClusterName,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the virtual switch to manage.")]
    [string]$SwitchName,

    [Parameter(Mandatory = $false, HelpMessage = "Type of virtual switch (Standard or Distributed).")]
    [ValidateSet("Standard", "Distributed")]
    [string]$SwitchType = "Standard",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the port group to manage.")]
    [string]$PortGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "VLAN ID for the port group (0-4094, 0 for no VLAN).")]
    [ValidateRange(0, 4094)]
    [int]$VLANID = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Number of ports for the port group (8-4096).")]
    [ValidateRange(8, 4096)]
    [int]$NumPorts = 128,

    [Parameter(Mandatory = $false, HelpMessage = "Array of physical network adapter names to add to the switch.")]
    [string[]]$PhysicalAdapters,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum Transmission Unit size in bytes (1500-9000).")]
    [ValidateRange(1500, 9000)]
    [int]$MTU = 1500,

    [Parameter(Mandatory = $false, HelpMessage = "Security policy settings for the port group (e.g. AllowPromiscuous, DenyMacChanges).")]
    [ValidateSet("AllowPromiscuous", "DenyPromiscuous", "AllowMacChanges", "DenyMacChanges", "AllowForgedTransmits", "DenyForgedTransmits")]
    [string[]]$SecurityPolicy,

    [Parameter(Mandatory = $false, HelpMessage = "Network policy type for load balancing (e.g. LoadBalanceSourceVirtualPort, ExplicitFailover).")]
    [ValidateSet("LoadBalanceSourceVirtualPort", "LoadBalanceSourceMAC", "LoadBalanceIP", "ExplicitFailover")]
    [string]$NetworkPolicy = "LoadBalanceSourceVirtualPort",

    [Parameter(Mandatory = $false, HelpMessage = "Output format for reports (Console, CSV, or JSON).")]
    [ValidateSet("Console", "CSV", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false, HelpMessage = "Path to save the report file.")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = "Force operations without confirmation prompts.")]
    [switch]$Force
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to check and install PowerCLI if needed
function Test-PowerCLIInstallation {
    Write-Host "Checking PowerCLI installation..." -ForegroundColor Yellow

    try {
        $powerCLIModule = Get-Module -Name VMware.PowerCLI -ListAvailable
        if (-not $powerCLIModule) {
            Write-Warning "VMware PowerCLI not found. Installing..."
            Install-Module -Name VMware.PowerCLI -Force -AllowClobber -Scope CurrentUser
            Write-Host "PowerCLI installed successfully." -ForegroundColor Green
        } else {
            $version = $powerCLIModule | Sort-Object Version -Descending | Select-Object -First 1
            Write-Host "PowerCLI version $($version.Version) found." -ForegroundColor Green
        }

        # Import the module
        Import-Module VMware.PowerCLI -Force

        # Disable certificate warnings for lab environments
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope User | Out-Null
        Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope User | Out-Null

        return $true
    }
    catch {
        Write-Error "Failed to install or import PowerCLI: $($_.Exception.Message)"
        return $false
    }
}

# Function to connect to vCenter
function Connect-ToVCenter {
    param($Server)

    try {
        Write-Host "Connecting to vCenter Server: $Server" -ForegroundColor Yellow

        # Check if already connected
        $connection = $global:DefaultVIServers | Where-Object { $_.Name -eq $Server -and $_.IsConnected }
        if ($connection) {
            Write-Host "Already connected to $Server" -ForegroundColor Green
            return $connection
        }

        # Connect to vCenter (will prompt for credentials if not cached)
        $connection = Connect-VIServer -Server $Server -Force
        Write-Host "Successfully connected to vCenter: $($connection.Name)" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Error "Failed to connect to vCenter Server $Server`: $($_.Exception.Message)"
        throw
    }
}

# Function to create a port group
function New-NetworkPortGroup {
    param(
        $VMHost,
        $SwitchName,
        $PortGroupName,
        $VLANID
    )

    try {
        Write-Host "  Creating port group '$PortGroupName' on switch '$SwitchName'..." -ForegroundColor Yellow

        # Check if port group already exists
        $existingPG = Get-VirtualPortGroup -VMHost $VMHost -Name $PortGroupName -ErrorAction SilentlyContinue
        if ($existingPG) {
            Write-Host "    Port group already exists" -ForegroundColor Yellow
            return @{
                Host = $VMHost.Name
                Switch = $SwitchName
                PortGroup = $PortGroupName
                VLANID = $VLANID
                Status = "AlreadyExists"
                Message = "Port group already exists"
            }
        }

        # Get the virtual switch
        $vswitch = Get-VirtualSwitch -VMHost $VMHost -Name $SwitchName -ErrorAction SilentlyContinue
        if (-not $vswitch) {
            throw "Virtual switch '$SwitchName' not found on host '$($VMHost.Name)'"
        }

        # Create the port group
        $null = New-VirtualPortGroup -VirtualSwitch $vswitch -Name $PortGroupName -VLanId $VLANID

        Write-Host "    ✓ Port group created successfully" -ForegroundColor Green
        return @{
            Host = $VMHost.Name
            Switch = $SwitchName
            PortGroup = $PortGroupName
            VLANID = $VLANID
            Status = "Success"
            Message = "Port group created successfully"
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            Switch = $SwitchName
            PortGroup = $PortGroupName
            VLANID = $VLANID
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to delete a port group
function Remove-NetworkPortGroup {
    param(
        $VMHost,
        $PortGroupName,
        $Force
    )

    try {
        Write-Host "  Removing port group '$PortGroupName'..." -ForegroundColor Yellow

        # Get the port group
        $portGroup = Get-VirtualPortGroup -VMHost $VMHost -Name $PortGroupName -ErrorAction SilentlyContinue
        if (-not $portGroup) {
            Write-Host "    Port group not found" -ForegroundColor Yellow
            return @{
                Host = $VMHost.Name
                PortGroup = $PortGroupName
                Status = "NotFound"
                Message = "Port group not found"
            }
        }

        # Check for connected VMs
        $connectedVMs = Get-VM | Get-NetworkAdapter | Where-Object { $_.NetworkName -eq $PortGroupName }
        if ($connectedVMs -and -not $Force) {
            throw "Port group has VMs connected. Use -Force to override: $($connectedVMs.Parent.Name -join ', ')"
        }

        # Remove the port group
        Remove-VirtualPortGroup -VirtualPortGroup $portGroup -Confirm:$false

        Write-Host "    ✓ Port group removed successfully" -ForegroundColor Green
        return @{
            Host = $VMHost.Name
            PortGroup = $PortGroupName
            Status = "Success"
            Message = "Port group removed successfully"
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            PortGroup = $PortGroupName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to create a standard virtual switch
function New-StandardVirtualSwitch {
    param(
        $VMHost,
        $SwitchName,
        $NumPorts,
        $MTU,
        $PhysicalAdapters
    )

    try {
        Write-Host "  Creating standard virtual switch '$SwitchName'..." -ForegroundColor Yellow

        # Check if switch already exists
        $existingSwitch = Get-VirtualSwitch -VMHost $VMHost -Name $SwitchName -ErrorAction SilentlyContinue
        if ($existingSwitch) {
            Write-Host "    Virtual switch already exists" -ForegroundColor Yellow
            return @{
                Host = $VMHost.Name
                Switch = $SwitchName
                Status = "AlreadyExists"
                Message = "Virtual switch already exists"
            }
        }

        # Create the virtual switch
        $switchParams = @{
            VMHost = $VMHost
            Name = $SwitchName
            NumPorts = $NumPorts
            Mtu = $MTU
        }

        # Add physical adapters if specified
        if ($PhysicalAdapters) {
            $nics = @()
            foreach ($nicName in $PhysicalAdapters) {
                $nic = Get-VMHostNetworkAdapter -VMHost $VMHost -Name $nicName -Physical -ErrorAction SilentlyContinue
                if ($nic) {
                    $nics += $nic
                } else {
                    Write-Warning "Physical adapter '$nicName' not found on host '$($VMHost.Name)'"
                }
            }
            if ($nics.Count -gt 0) {
                $switchParams.Nic = $nics
            }
        }

        $null = New-VirtualSwitch @switchParams

        Write-Host "    ✓ Standard virtual switch created successfully" -ForegroundColor Green
        return @{
            Host = $VMHost.Name
            Switch = $SwitchName
            NumPorts = $NumPorts
            MTU = $MTU
            PhysicalAdapters = $PhysicalAdapters
            Status = "Success"
            Message = "Standard virtual switch created successfully"
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            Switch = $SwitchName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to create a distributed virtual switch
function New-DistributedVirtualSwitch {
    param(
        $ClusterName,
        $SwitchName,
        $NumPorts,
        $MTU
    )

    try {
        Write-Host "  Creating distributed virtual switch '$SwitchName'..." -ForegroundColor Yellow

        # Check if switch already exists
        $existingSwitch = Get-VDSwitch -Name $SwitchName -ErrorAction SilentlyContinue
        if ($existingSwitch) {
            Write-Host "    Distributed virtual switch already exists" -ForegroundColor Yellow
            return @{
                Cluster = $ClusterName
                Switch = $SwitchName
                Status = "AlreadyExists"
                Message = "Distributed virtual switch already exists"
            }
        }

        # Get the datacenter (required for distributed switch)
        if ($ClusterName) {
            $cluster = Get-Cluster -Name $ClusterName
            $datacenter = $cluster.Parent
        } else {
            $datacenter = Get-Datacenter | Select-Object -First 1
        }

        # Create the distributed virtual switch
        $vdswitch = New-VDSwitch -Name $SwitchName -Location $datacenter -NumUplinkPorts 4 -Mtu $MTU

        # Add hosts to the distributed switch if cluster specified
        if ($ClusterName) {
            $clusterHosts = Get-VMHost -Location $cluster
            foreach ($vmHost in $clusterHosts) {
                try {
                    Add-VDSwitchVMHost -VDSwitch $vdswitch -VMHost $vmHost
                    Write-Host "      Added host '$($vmHost.Name)' to distributed switch" -ForegroundColor Gray
                }
                catch {
                    Write-Warning "Failed to add host '$($vmHost.Name)' to distributed switch: $($_.Exception.Message)"
                }
            }
        }

        Write-Host "    ✓ Distributed virtual switch created successfully" -ForegroundColor Green
        return @{
            Cluster = $ClusterName
            Switch = $SwitchName
            NumPorts = $NumPorts
            MTU = $MTU
            Status = "Success"
            Message = "Distributed virtual switch created successfully"
        }
    }
    catch {
        return @{
            Cluster = $ClusterName
            Switch = $SwitchName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to configure uplink teaming
function Set-UplinkTeaming {
    param(
        $VMHost,
        $SwitchName,
        $PhysicalAdapters,
        $NetworkPolicy
    )

    try {
        Write-Host "  Configuring uplink teaming for switch '$SwitchName'..." -ForegroundColor Yellow

        # Get the virtual switch
        $vswitch = Get-VirtualSwitch -VMHost $VMHost -Name $SwitchName -ErrorAction SilentlyContinue
        if (-not $vswitch) {
            throw "Virtual switch '$SwitchName' not found on host '$($VMHost.Name)'"
        }

        # Configure NIC teaming policy
        $teamingPolicy = Get-NicTeamingPolicy -VirtualSwitch $vswitch

        # Set load balancing policy
        $teamingPolicy | Set-NicTeamingPolicy -LoadBalancingPolicy $NetworkPolicy

        # Add physical adapters if specified
        if ($PhysicalAdapters) {
            $activeNics = @()
            foreach ($nicName in $PhysicalAdapters) {
                $nic = Get-VMHostNetworkAdapter -VMHost $VMHost -Name $nicName -Physical -ErrorAction SilentlyContinue
                if ($nic) {
                    $activeNics += $nicName
                } else {
                    Write-Warning "Physical adapter '$nicName' not found on host '$($VMHost.Name)'"
                }
            }

            if ($activeNics.Count -gt 0) {
                # Remove existing NICs and add new ones
                $currentNics = $vswitch.Nic
                if ($currentNics) {
                    foreach ($currentNic in $currentNics) {
                        Remove-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $currentNic -VirtualSwitch $vswitch -Confirm:$false
                    }
                }

                # Add new NICs
                foreach ($nicName in $activeNics) {
                    $nic = Get-VMHostNetworkAdapter -VMHost $VMHost -Name $nicName -Physical
                    Add-VirtualSwitchPhysicalNetworkAdapter -VirtualSwitch $vswitch -VMHostPhysicalNic $nic -Confirm:$false
                }

                Write-Host "      Added NICs: $($activeNics -join ', ')" -ForegroundColor Gray
            }
        }

        Write-Host "    ✓ Uplink teaming configured successfully" -ForegroundColor Green
        return @{
            Host = $VMHost.Name
            Switch = $SwitchName
            NetworkPolicy = $NetworkPolicy
            PhysicalAdapters = $PhysicalAdapters
            Status = "Success"
            Message = "Uplink teaming configured successfully"
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            Switch = $SwitchName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to configure security policies
function Set-SecurityPolicy {
    param(
        $VMHost,
        $PortGroupName,
        $SecurityPolicy
    )

    try {
        Write-Host "  Configuring security policy for port group '$PortGroupName'..." -ForegroundColor Yellow

        # Get the port group
        $portGroup = Get-VirtualPortGroup -VMHost $VMHost -Name $PortGroupName -ErrorAction SilentlyContinue
        if (-not $portGroup) {
            throw "Port group '$PortGroupName' not found on host '$($VMHost.Name)'"
        }

        # Get current security policy
        $secPolicy = Get-SecurityPolicy -VirtualPortGroup $portGroup

        # Apply security settings
        $policyParams = @{}

        foreach ($policy in $SecurityPolicy) {
            switch ($policy) {
                "AllowPromiscuous" { $policyParams.AllowPromiscuous = $true }
                "DenyPromiscuous" { $policyParams.AllowPromiscuous = $false }
                "AllowMacChanges" { $policyParams.MacChanges = $true }
                "DenyMacChanges" { $policyParams.MacChanges = $false }
                "AllowForgedTransmits" { $policyParams.ForgedTransmits = $true }
                "DenyForgedTransmits" { $policyParams.ForgedTransmits = $false }
            }
        }

        if ($policyParams.Count -gt 0) {
            $secPolicy | Set-SecurityPolicy @policyParams
            Write-Host "      Applied security policies: $($SecurityPolicy -join ', ')" -ForegroundColor Gray
        }

        Write-Host "    ✓ Security policy configured successfully" -ForegroundColor Green
        return @{
            Host = $VMHost.Name
            PortGroup = $PortGroupName
            SecurityPolicy = $SecurityPolicy
            Status = "Success"
            Message = "Security policy configured successfully"
        }
    }
    catch {
        return @{
            Host = $VMHost.Name
            PortGroup = $PortGroupName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to get network health check
function Get-NetworkHealthCheck {
    param($VMHost)

    try {
        Write-Host "  Performing network health check for host '$($VMHost.Name)'..." -ForegroundColor Yellow

        $healthIssues = @()
        $healthStatus = "Healthy"

        # Get all virtual switches
        $vSwitches = Get-VirtualSwitch -VMHost $VMHost

        # Check each virtual switch
        foreach ($vswitch in $vSwitches) {
            # Check for physical adapters
            if ($vswitch.Nic.Count -eq 0 -and $vswitch.Name -ne "vSwitch0") {
                $healthIssues += "Virtual switch '$($vswitch.Name)' has no physical adapters"
                $healthStatus = "Warning"
            }

            # Check for single point of failure
            if ($vswitch.Nic.Count -eq 1) {
                $healthIssues += "Virtual switch '$($vswitch.Name)' has only one physical adapter (single point of failure)"
                if ($healthStatus -eq "Healthy") {
                    $healthStatus = "Warning"
                }
            }

            # Check for link state
            foreach ($nic in $vswitch.Nic) {
                $nicAdapter = Get-VMHostNetworkAdapter -VMHost $VMHost -Name $nic -Physical
                if (-not $nicAdapter.LinkUp) {
                    $healthIssues += "Physical adapter '$nic' on switch '$($vswitch.Name)' is link down"
                    $healthStatus = "Critical"
                }
            }
        }

        # Check for orphaned port groups
        $portGroups = Get-VirtualPortGroup -VMHost $VMHost
        foreach ($pg in $portGroups) {
            $connectedVMs = Get-VM | Get-NetworkAdapter | Where-Object { $_.NetworkName -eq $pg.Name }
            if (-not $connectedVMs -and $pg.Name -notin @("Management Network", "VM Network")) {
                $healthIssues += "Port group '$($pg.Name)' has no connected VMs"
                if ($healthStatus -eq "Healthy") {
                    $healthStatus = "Warning"
                }
            }
        }

        # Check VMkernel network adapters
        $vmkernelAdapters = Get-VMHostNetworkAdapter -VMHost $VMHost -VMKernel
        foreach ($vmk in $vmkernelAdapters) {
            if (-not $vmk.IP) {
                $healthIssues += "VMkernel adapter '$($vmk.Name)' has no IP address"
                $healthStatus = "Warning"
            }
        }

        $result = @{
            Host = $VMHost.Name
            Status = $healthStatus
            Issues = $healthIssues
            VirtualSwitches = $vSwitches.Count
            PortGroups = $portGroups.Count
            VMKernelAdapters = $vmkernelAdapters.Count
            PhysicalAdapters = (Get-VMHostNetworkAdapter -VMHost $VMHost -Physical).Count
        }

        $statusColor = switch ($healthStatus) {
            "Healthy" { "Green" }
            "Warning" { "Yellow" }
            "Critical" { "Red" }
            default { "White" }
        }

        Write-Host "    Status: $healthStatus" -ForegroundColor $statusColor
        if ($healthIssues.Count -gt 0) {
            foreach ($issue in $healthIssues) {
                Write-Host "      - $issue" -ForegroundColor Gray
            }
        }

        return $result
    }
    catch {
        return @{
            Host = $VMHost.Name
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to get VM network information
function Get-VMNetworkInfo {
    param($VMHost)

    try {
        Write-Host "  Gathering VM network information for host '$($VMHost.Name)'..." -ForegroundColor Yellow

        $vmNetworkInfo = @()
        $vms = Get-VM -Location $VMHost

        foreach ($vm in $vms) {
            $networkAdapters = Get-NetworkAdapter -VM $vm
            foreach ($adapter in $networkAdapters) {
                $portGroup = Get-VirtualPortGroup -VMHost $VMHost -Name $adapter.NetworkName -ErrorAction SilentlyContinue

                $vmNetworkInfo += [PSCustomObject]@{
                    VMName = $vm.Name
                    PowerState = $vm.PowerState
                    AdapterName = $adapter.Name
                    NetworkName = $adapter.NetworkName
                    MacAddress = $adapter.MacAddress
                    ConnectionState = $adapter.ConnectionState.Connected
                    StartConnected = $adapter.ConnectionState.StartConnected
                    VLANID = if ($portGroup) { $portGroup.VLanId } else { "N/A" }
                    AdapterType = $adapter.Type
                }
            }
        }

        return $vmNetworkInfo
    }
    catch {
        Write-Warning "Failed to get VM network information for host '$($VMHost.Name)': $($_.Exception.Message)"
        return @()
    }
}

# Function to generate network report
function Get-NetworkReport {
    param(
        $Hosts,
        $OutputFormat,
        $OutputPath
    )

    Write-Host "Generating network configuration report..." -ForegroundColor Yellow

    $reportData = @()

    foreach ($vmHost in $Hosts) {
        try {
            # Get virtual switches
            $vSwitches = Get-VirtualSwitch -VMHost $vmHost

            foreach ($vswitch in $vSwitches) {
                # Get port groups for this switch
                $portGroups = Get-VirtualPortGroup -VMHost $vmHost -VirtualSwitch $vswitch

                foreach ($pg in $portGroups) {
                    $reportItem = [PSCustomObject]@{
                        Host = $vmHost.Name
                        SwitchName = $vswitch.Name
                        SwitchType = "Standard"
                        NumPorts = $vswitch.NumPorts
                        MTU = $vswitch.Mtu
                        PhysicalAdapters = ($vswitch.Nic -join ";")
                        PortGroupName = $pg.Name
                        VLANID = $pg.VLanId
                        ConnectedVMs = (Get-VM | Get-NetworkAdapter | Where-Object { $_.NetworkName -eq $pg.Name }).Count
                        Timestamp = Get-Date
                    }

                    $reportData += $reportItem
                }

                # If no port groups, still include the switch
                if ($portGroups.Count -eq 0) {
                    $reportItem = [PSCustomObject]@{
                        Host = $vmHost.Name
                        SwitchName = $vswitch.Name
                        SwitchType = "Standard"
                        NumPorts = $vswitch.NumPorts
                        MTU = $vswitch.Mtu
                        PhysicalAdapters = ($vswitch.Nic -join ";")
                        PortGroupName = ""
                        VLANID = ""
                        ConnectedVMs = 0
                        Timestamp = Get-Date
                    }

                    $reportData += $reportItem
                }
            }
        }
        catch {
            Write-Warning "Failed to get network data for host '$($vmHost.Name)': $($_.Exception.Message)"
        }
    }

    # Export report
    switch ($OutputFormat) {
        "Console" {
            Write-Host "`n=== Network Configuration Report ===" -ForegroundColor Cyan
            $reportData | Format-Table Host, SwitchName, PortGroupName, VLANID, ConnectedVMs -AutoSize
        }
        "CSV" {
            if (-not $OutputPath) {
                $OutputPath = "Network_Configuration_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            }
            $reportData | Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
        "JSON" {
            if (-not $OutputPath) {
                $OutputPath = "Network_Configuration_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            }
            $reportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
        }
    }

    return $reportData
}

# Function to display operation summary
function Show-NetworkOperationSummary {
    param(
        $Results,
        $Operation
    )

    Write-Host "`n=== Network $Operation Summary ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Success" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $warnings = $Results | Where-Object { $_.Status -in @("AlreadyExists", "NotFound") }

    Write-Host "Total Operations: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Operations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  - $($result.Host): $($result.Message)" -ForegroundColor White
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere Network Operations ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($HostName) { Write-Host "Target Host: $HostName" -ForegroundColor White }
    if ($ClusterName) { Write-Host "Target Cluster: $ClusterName" -ForegroundColor White }
    if ($SwitchName) { Write-Host "Switch Name: $SwitchName" -ForegroundColor White }
    if ($PortGroupName) { Write-Host "Port Group: $PortGroupName" -ForegroundColor White }
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Get target hosts based on operation
    $targetHosts = @()
    if ($HostName) {
        $targetHosts = @(Get-VMHost -Name $HostName)
    } elseif ($ClusterName -and $Operation -notin @("CreateDistributedSwitch", "DeleteDistributedSwitch")) {
        $cluster = Get-Cluster -Name $ClusterName
        $targetHosts = Get-VMHost -Location $cluster
    } elseif ($Operation -in @("Report", "NetworkHealth", "VMNetworkInfo")) {
        $targetHosts = Get-VMHost
    }

    # Perform the requested operation
    $results = @()

    switch ($Operation) {
        "CreatePortGroup" {
            if (-not $HostName -or -not $SwitchName -or -not $PortGroupName) {
                throw "HostName, SwitchName, and PortGroupName are required for CreatePortGroup operation"
            }

            foreach ($vmHost in $targetHosts) {
                $result = New-NetworkPortGroup -VMHost $vmHost -SwitchName $SwitchName -PortGroupName $PortGroupName -VLANID $VLANID
                $results += $result
            }
        }

        "DeletePortGroup" {
            if (-not $HostName -or -not $PortGroupName) {
                throw "HostName and PortGroupName are required for DeletePortGroup operation"
            }

            foreach ($vmHost in $targetHosts) {
                $result = Remove-NetworkPortGroup -VMHost $vmHost -PortGroupName $PortGroupName -Force:$Force
                $results += $result
            }
        }

        "CreateStandardSwitch" {
            if (-not $HostName -or -not $SwitchName) {
                throw "HostName and SwitchName are required for CreateStandardSwitch operation"
            }

            foreach ($vmHost in $targetHosts) {
                $result = New-StandardVirtualSwitch -VMHost $vmHost -SwitchName $SwitchName -NumPorts $NumPorts -MTU $MTU -PhysicalAdapters $PhysicalAdapters
                $results += $result
            }
        }

        "CreateDistributedSwitch" {
            if (-not $SwitchName) {
                throw "SwitchName is required for CreateDistributedSwitch operation"
            }

            $result = New-DistributedVirtualSwitch -ClusterName $ClusterName -SwitchName $SwitchName -NumPorts $NumPorts -MTU $MTU
            $results += $result
        }

        "ConfigureUplinkTeaming" {
            if (-not $HostName -or -not $SwitchName) {
                throw "HostName and SwitchName are required for ConfigureUplinkTeaming operation"
            }

            foreach ($vmHost in $targetHosts) {
                $result = Set-UplinkTeaming -VMHost $vmHost -SwitchName $SwitchName -PhysicalAdapters $PhysicalAdapters -NetworkPolicy $NetworkPolicy
                $results += $result
            }
        }

        "ConfigureSecurity" {
            if (-not $HostName -or -not $PortGroupName -or -not $SecurityPolicy) {
                throw "HostName, PortGroupName, and SecurityPolicy are required for ConfigureSecurity operation"
            }

            foreach ($vmHost in $targetHosts) {
                $result = Set-SecurityPolicy -VMHost $vmHost -PortGroupName $PortGroupName -SecurityPolicy $SecurityPolicy
                $results += $result
            }
        }

        "NetworkHealth" {
            foreach ($vmHost in $targetHosts) {
                $result = Get-NetworkHealthCheck -VMHost $vmHost
                $results += $result
            }

            # Display health summary
            $healthy = $results | Where-Object { $_.Status -eq "Healthy" }
            $warning = $results | Where-Object { $_.Status -eq "Warning" }
            $critical = $results | Where-Object { $_.Status -eq "Critical" }

            Write-Host "`n=== Network Health Summary ===" -ForegroundColor Cyan
            Write-Host "Healthy: $($healthy.Count)" -ForegroundColor Green
            Write-Host "Warning: $($warning.Count)" -ForegroundColor Yellow
            Write-Host "Critical: $($critical.Count)" -ForegroundColor Red
        }

        "VMNetworkInfo" {
            $allVMNetworkInfo = @()
            foreach ($vmHost in $targetHosts) {
                $vmNetworkInfo = Get-VMNetworkInfo -VMHost $vmHost
                $allVMNetworkInfo += $vmNetworkInfo
            }

            Write-Host "`n=== VM Network Information ===" -ForegroundColor Cyan
            $allVMNetworkInfo | Format-Table VMName, NetworkName, MacAddress, VLANID, ConnectionState -AutoSize

            if ($OutputPath) {
                switch ($OutputFormat) {
                    "CSV" { $allVMNetworkInfo | Export-Csv -Path $OutputPath -NoTypeInformation }
                    "JSON" { $allVMNetworkInfo | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8 }
                }
                Write-Host "VM network information exported to: $OutputPath" -ForegroundColor Green
            }
        }

        "Report" {
            $results = Get-NetworkReport -Hosts $targetHosts -OutputFormat $OutputFormat -OutputPath $OutputPath
        }
    }

    # Display summary (except for operations that already display results)
    if ($Operation -notin @("Report", "NetworkHealth", "VMNetworkInfo")) {
        Show-NetworkOperationSummary -Results $results -Operation $Operation
    }

    Write-Host "`n=== Operation Completed ===" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
    # Disconnect from vCenter if connected
    if ($global:DefaultVIServers) {
        Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
        Disconnect-VIServer -Server * -Confirm:$false -Force
    }
}
