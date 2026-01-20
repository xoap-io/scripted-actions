<#
.SYNOPSIS
    Manages vSphere resource pools and advanced VM resource allocation using PowerCLI.

.DESCRIPTION
    This script provides comprehensive resource pool management including creation, deletion,
    configuration of resource allocation (CPU/Memory), shares, reservations, and limits.
    Also manages VM resource allocation and resource pool hierarchies.
    Requires VMware PowerCLI and connection to vCenter Server.

.PARAMETER VCenterServer
    The vCenter Server FQDN or IP address to connect to.

.PARAMETER Operation
    The resource pool operation to perform.

.PARAMETER ClusterName
    The cluster name where the resource pool operations will be performed.

.PARAMETER ResourcePoolName
    Name of the resource pool to manage.

.PARAMETER ParentResourcePoolName
    Name of the parent resource pool for hierarchical operations.

.PARAMETER VMName
    Name of the VM for resource allocation operations.

.PARAMETER CPUShares
    CPU shares allocation (High/Normal/Low or custom value).

.PARAMETER MemoryShares
    Memory shares allocation (High/Normal/Low or custom value).

.PARAMETER CPUReservationMHz
    CPU reservation in MHz.

.PARAMETER MemoryReservationGB
    Memory reservation in GB.

.PARAMETER CPULimitMHz
    CPU limit in MHz (-1 for unlimited).

.PARAMETER MemoryLimitGB
    Memory limit in GB (-1 for unlimited).

.PARAMETER CPUExpandableReservation
    Whether CPU reservation is expandable.

.PARAMETER MemoryExpandableReservation
    Whether memory reservation is expandable.

.PARAMETER OutputFormat
    Output format for reports.

.PARAMETER OutputPath
    Path to save the report file (optional).

.PARAMETER Force
    Force operations without confirmation prompts.

.EXAMPLE
    .\vsphere-cli-resource-pools.ps1 -VCenterServer "vcenter.domain.com" -Operation "CreateResourcePool" -ClusterName "Production" -ResourcePoolName "WebServers" -CPUShares "High" -MemoryShares "High"

.EXAMPLE
    .\vsphere-cli-resource-pools.ps1 -VCenterServer "vcenter.domain.com" -Operation "ConfigureVMResources" -VMName "web01" -CPUShares "High" -MemoryReservationGB 4

.EXAMPLE
    .\vsphere-cli-resource-pools.ps1 -VCenterServer "vcenter.domain.com" -Operation "Report" -OutputFormat "CSV" -OutputPath "resource-pools-report.csv"

.EXAMPLE
    .\vsphere-cli-resource-pools.ps1 -VCenterServer "vcenter.domain.com" -Operation "CreateChildResourcePool" -ClusterName "Production" -ParentResourcePoolName "WebServers" -ResourcePoolName "Frontend"

.NOTES
    Author: XOAP.io
    Requires: VMware PowerCLI 13.x or later, vSphere 7.0 or later

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VCenterServer,

    [Parameter(Mandatory = $true)]
    [ValidateSet("CreateResourcePool", "DeleteResourcePool", "CreateChildResourcePool",
                 "ConfigureResourcePool", "ConfigureVMResources", "MoveVMToResourcePool",
                 "Report", "ResourcePoolHealth", "ResourceUsage", "RebalanceResources")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName,

    [Parameter(Mandatory = $false)]
    [string]$ResourcePoolName,

    [Parameter(Mandatory = $false)]
    [string]$ParentResourcePoolName,

    [Parameter(Mandatory = $false)]
    [string]$VMName,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(High|Normal|Low|\d+)$')]
    [string]$CPUShares = "Normal",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(High|Normal|Low|\d+)$')]
    [string]$MemoryShares = "Normal",

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 999999)]
    [int]$CPUReservationMHz = 0,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 999999)]
    [int]$MemoryReservationGB = 0,

    [Parameter(Mandatory = $false)]
    [ValidateRange(-1, 999999)]
    [int]$CPULimitMHz = -1,

    [Parameter(Mandatory = $false)]
    [ValidateRange(-1, 999999)]
    [int]$MemoryLimitGB = -1,

    [Parameter(Mandatory = $false)]
    [switch]$CPUExpandableReservation,

    [Parameter(Mandatory = $false)]
    [switch]$MemoryExpandableReservation,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "CSV", "JSON")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
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

# Function to convert shares value
function Convert-SharesValue {
    param(
        $SharesInput,
        $ResourceType
    )

    # Define standard shares values
    $standardShares = @{
        "High" = @{ "CPU" = 2000; "Memory" = 20 }
        "Normal" = @{ "CPU" = 1000; "Memory" = 10 }
        "Low" = @{ "CPU" = 500; "Memory" = 5 }
    }

    if ($SharesInput -match '^\d+$') {
        # Custom numeric value
        return [int]$SharesInput
    } elseif ($standardShares.ContainsKey($SharesInput)) {
        # Standard value
        return $standardShares[$SharesInput][$ResourceType]
    } else {
        # Default to Normal
        return $standardShares["Normal"][$ResourceType]
    }
}

# Function to create a resource pool
function New-ResourcePool {
    param(
        $ClusterName,
        $ResourcePoolName,
        $ParentResourcePoolName,
        $CPUShares,
        $MemoryShares,
        $CPUReservationMHz,
        $MemoryReservationGB,
        $CPULimitMHz,
        $MemoryLimitGB,
        $CPUExpandableReservation,
        $MemoryExpandableReservation
    )

    try {
        Write-Host "  Creating resource pool '$ResourcePoolName'..." -ForegroundColor Yellow

        # Get the parent location (cluster or parent resource pool)
        if ($ParentResourcePoolName) {
            $parentResourcePool = Get-ResourcePool -Name $ParentResourcePoolName -ErrorAction SilentlyContinue
            if (-not $parentResourcePool) {
                throw "Parent resource pool '$ParentResourcePoolName' not found"
            }
            $parentLocation = $parentResourcePool
            Write-Host "    Parent: Resource Pool '$ParentResourcePoolName'" -ForegroundColor Gray
        } else {
            $cluster = Get-Cluster -Name $ClusterName -ErrorAction SilentlyContinue
            if (-not $cluster) {
                throw "Cluster '$ClusterName' not found"
            }
            $parentLocation = $cluster
            Write-Host "    Parent: Cluster '$ClusterName'" -ForegroundColor Gray
        }

        # Check if resource pool already exists
        $existingRP = Get-ResourcePool -Location $parentLocation -Name $ResourcePoolName -ErrorAction SilentlyContinue
        if ($existingRP) {
            Write-Host "    Resource pool already exists" -ForegroundColor Yellow
            return @{
                ResourcePool = $ResourcePoolName
                Parent = if ($ParentResourcePoolName) { $ParentResourcePoolName } else { $ClusterName }
                Status = "AlreadyExists"
                Message = "Resource pool already exists"
            }
        }

        # Convert shares values
        $cpuSharesValue = Convert-SharesValue -SharesInput $CPUShares -ResourceType "CPU"
        $memorySharesValue = Convert-SharesValue -SharesInput $MemoryShares -ResourceType "Memory"

        # Set unlimited values
        $cpuLimitActual = if ($CPULimitMHz -eq -1) { -1 } else { $CPULimitMHz }
        $memoryLimitActual = if ($MemoryLimitGB -eq -1) { -1 } else { $MemoryLimitGB * 1024 } # Convert to MB

        # Create resource pool specification
        $rpSpec = New-Object VMware.Vim.ResourceConfigSpec

        # CPU configuration
        $rpSpec.CpuAllocation = New-Object VMware.Vim.ResourceAllocationInfo
        $rpSpec.CpuAllocation.Shares = New-Object VMware.Vim.SharesInfo
        $rpSpec.CpuAllocation.Shares.Level = "custom"
        $rpSpec.CpuAllocation.Shares.Shares = $cpuSharesValue
        $rpSpec.CpuAllocation.Reservation = $CPUReservationMHz
        $rpSpec.CpuAllocation.Limit = $cpuLimitActual
        $rpSpec.CpuAllocation.ExpandableReservation = $CPUExpandableReservation

        # Memory configuration
        $rpSpec.MemoryAllocation = New-Object VMware.Vim.ResourceAllocationInfo
        $rpSpec.MemoryAllocation.Shares = New-Object VMware.Vim.SharesInfo
        $rpSpec.MemoryAllocation.Shares.Level = "custom"
        $rpSpec.MemoryAllocation.Shares.Shares = $memorySharesValue
        $rpSpec.MemoryAllocation.Reservation = $MemoryReservationGB * 1024 # Convert to MB
        $rpSpec.MemoryAllocation.Limit = $memoryLimitActual
        $rpSpec.MemoryAllocation.ExpandableReservation = $MemoryExpandableReservation

        # Create the resource pool
        $resourcePool = New-ResourcePool -Location $parentLocation -Name $ResourcePoolName -CpuSharesLevel Custom -CpuShares $cpuSharesValue -MemSharesLevel Custom -MemShares $memorySharesValue

        # Apply additional configuration
        $resourcePool | Set-ResourcePool -CpuReservationMhz $CPUReservationMHz -MemReservationGB $MemoryReservationGB -CpuLimitMhz $cpuLimitActual -MemLimitGB ($memoryLimitActual / 1024) -CpuExpandableReservation:$CPUExpandableReservation -MemExpandableReservation:$MemoryExpandableReservation

        Write-Host "    ✓ Resource pool created successfully" -ForegroundColor Green
        Write-Host "      CPU: $cpuSharesValue shares, $CPUReservationMHz MHz reservation, $CPULimitMHz MHz limit" -ForegroundColor Gray
        Write-Host "      Memory: $memorySharesValue shares, $MemoryReservationGB GB reservation, $MemoryLimitGB GB limit" -ForegroundColor Gray

        return @{
            ResourcePool = $ResourcePoolName
            Parent = if ($ParentResourcePoolName) { $ParentResourcePoolName } else { $ClusterName }
            CPUShares = $cpuSharesValue
            MemoryShares = $memorySharesValue
            CPUReservation = $CPUReservationMHz
            MemoryReservation = $MemoryReservationGB
            CPULimit = $CPULimitMHz
            MemoryLimit = $MemoryLimitGB
            Status = "Success"
            Message = "Resource pool created successfully"
        }
    }
    catch {
        return @{
            ResourcePool = $ResourcePoolName
            Parent = if ($ParentResourcePoolName) { $ParentResourcePoolName } else { $ClusterName }
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to delete a resource pool
function Remove-ResourcePool {
    param(
        $ResourcePoolName,
        $Force
    )

    try {
        Write-Host "  Deleting resource pool '$ResourcePoolName'..." -ForegroundColor Yellow

        # Get the resource pool
        $resourcePool = Get-ResourcePool -Name $ResourcePoolName -ErrorAction SilentlyContinue
        if (-not $resourcePool) {
            Write-Host "    Resource pool not found" -ForegroundColor Yellow
            return @{
                ResourcePool = $ResourcePoolName
                Status = "NotFound"
                Message = "Resource pool not found"
            }
        }

        # Check for VMs in the resource pool
        $vmsInPool = Get-VM -Location $resourcePool -ErrorAction SilentlyContinue
        if ($vmsInPool -and -not $Force) {
            throw "Resource pool contains VMs. Use -Force to override: $($vmsInPool.Name -join ', ')"
        }

        # Check for child resource pools
        $childPools = Get-ResourcePool -Location $resourcePool -ErrorAction SilentlyContinue
        if ($childPools -and -not $Force) {
            throw "Resource pool contains child resource pools. Use -Force to override: $($childPools.Name -join ', ')"
        }

        # Move VMs to parent if Force is used
        if ($vmsInPool -and $Force) {
            Write-Host "    Moving VMs to parent resource pool..." -ForegroundColor Gray
            $parentPool = $resourcePool.Parent
            foreach ($vm in $vmsInPool) {
                Move-VM -VM $vm -Destination $parentPool
                Write-Host "      Moved VM '$($vm.Name)'" -ForegroundColor Gray
            }
        }

        # Delete child resource pools if Force is used
        if ($childPools -and $Force) {
            Write-Host "    Deleting child resource pools..." -ForegroundColor Gray
            foreach ($childPool in $childPools) {
                Remove-ResourcePool -ResourcePool $childPool -Confirm:$false
                Write-Host "      Deleted child resource pool '$($childPool.Name)'" -ForegroundColor Gray
            }
        }

        # Remove the resource pool
        Remove-ResourcePool -ResourcePool $resourcePool -Confirm:$false

        Write-Host "    ✓ Resource pool deleted successfully" -ForegroundColor Green
        return @{
            ResourcePool = $ResourcePoolName
            Status = "Success"
            Message = "Resource pool deleted successfully"
            VMsMoved = if ($vmsInPool) { $vmsInPool.Count } else { 0 }
            ChildPoolsDeleted = if ($childPools) { $childPools.Count } else { 0 }
        }
    }
    catch {
        return @{
            ResourcePool = $ResourcePoolName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to configure VM resources
function Set-VMResourceAllocation {
    param(
        $VMName,
        $CPUShares,
        $MemoryShares,
        $CPUReservationMHz,
        $MemoryReservationGB,
        $CPULimitMHz,
        $MemoryLimitGB
    )

    try {
        Write-Host "  Configuring resources for VM '$VMName'..." -ForegroundColor Yellow

        # Get the VM
        $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if (-not $vm) {
            throw "VM '$VMName' not found"
        }

        # Convert shares values
        $cpuSharesValue = Convert-SharesValue -SharesInput $CPUShares -ResourceType "CPU"
        $memorySharesValue = Convert-SharesValue -SharesInput $MemoryShares -ResourceType "Memory"

        # Set unlimited values
        $cpuLimitActual = if ($CPULimitMHz -eq -1) { -1 } else { $CPULimitMHz }
        $memoryLimitActual = if ($MemoryLimitGB -eq -1) { -1 } else { $MemoryLimitGB }

        # Configure VM resource allocation
        $vm | Set-VM -CpuSharesLevel Custom -NumCpuShares $cpuSharesValue -MemSharesLevel Custom -NumMemShares $memorySharesValue -Confirm:$false

        # Set CPU configuration
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $vmConfigSpec.CpuAllocation = New-Object VMware.Vim.ResourceAllocationInfo
        $vmConfigSpec.CpuAllocation.Reservation = $CPUReservationMHz
        $vmConfigSpec.CpuAllocation.Limit = $cpuLimitActual
        $vmConfigSpec.CpuAllocation.Shares = New-Object VMware.Vim.SharesInfo
        $vmConfigSpec.CpuAllocation.Shares.Level = "custom"
        $vmConfigSpec.CpuAllocation.Shares.Shares = $cpuSharesValue

        # Set Memory configuration
        $vmConfigSpec.MemoryAllocation = New-Object VMware.Vim.ResourceAllocationInfo
        $vmConfigSpec.MemoryAllocation.Reservation = $MemoryReservationGB * 1024 # Convert to MB
        $vmConfigSpec.MemoryAllocation.Limit = if ($memoryLimitActual -eq -1) { -1 } else { $memoryLimitActual * 1024 }
        $vmConfigSpec.MemoryAllocation.Shares = New-Object VMware.Vim.SharesInfo
        $vmConfigSpec.MemoryAllocation.Shares.Level = "custom"
        $vmConfigSpec.MemoryAllocation.Shares.Shares = $memorySharesValue

        # Apply configuration
        $vm.ExtensionData.ReconfigVM($vmConfigSpec)

        Write-Host "    ✓ VM resources configured successfully" -ForegroundColor Green
        Write-Host "      CPU: $cpuSharesValue shares, $CPUReservationMHz MHz reservation, $CPULimitMHz MHz limit" -ForegroundColor Gray
        Write-Host "      Memory: $memorySharesValue shares, $MemoryReservationGB GB reservation, $MemoryLimitGB GB limit" -ForegroundColor Gray

        return @{
            VM = $VMName
            CPUShares = $cpuSharesValue
            MemoryShares = $memorySharesValue
            CPUReservation = $CPUReservationMHz
            MemoryReservation = $MemoryReservationGB
            CPULimit = $CPULimitMHz
            MemoryLimit = $MemoryLimitGB
            Status = "Success"
            Message = "VM resources configured successfully"
        }
    }
    catch {
        return @{
            VM = $VMName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to move VM to resource pool
function Move-VMToResourcePool {
    param(
        $VMName,
        $ResourcePoolName
    )

    try {
        Write-Host "  Moving VM '$VMName' to resource pool '$ResourcePoolName'..." -ForegroundColor Yellow

        # Get the VM
        $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if (-not $vm) {
            throw "VM '$VMName' not found"
        }

        # Get the resource pool
        $resourcePool = Get-ResourcePool -Name $ResourcePoolName -ErrorAction SilentlyContinue
        if (-not $resourcePool) {
            throw "Resource pool '$ResourcePoolName' not found"
        }

        # Check if VM is already in the resource pool
        if ($vm.ResourcePool.Name -eq $ResourcePoolName) {
            Write-Host "    VM is already in the target resource pool" -ForegroundColor Yellow
            return @{
                VM = $VMName
                ResourcePool = $ResourcePoolName
                Status = "AlreadyInPool"
                Message = "VM is already in the target resource pool"
            }
        }

        # Move the VM
        Move-VM -VM $vm -Destination $resourcePool

        Write-Host "    ✓ VM moved successfully" -ForegroundColor Green
        return @{
            VM = $VMName
            ResourcePool = $ResourcePoolName
            PreviousResourcePool = $vm.ResourcePool.Name
            Status = "Success"
            Message = "VM moved to resource pool successfully"
        }
    }
    catch {
        return @{
            VM = $VMName
            ResourcePool = $ResourcePoolName
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to get resource pool health check
function Get-ResourcePoolHealthCheck {
    param($ResourcePool)

    try {
        Write-Host "  Performing health check for resource pool '$($ResourcePool.Name)'..." -ForegroundColor Yellow

        $healthIssues = @()
        $healthStatus = "Healthy"

        # Get VMs in the resource pool
        $vmsInPool = Get-VM -Location $ResourcePool

        # Check CPU over-commitment
        $totalCPUReservation = 0
        $totalMemoryReservation = 0

        foreach ($vm in $vmsInPool) {
            if ($vm.PowerState -eq "PoweredOn") {
                $totalCPUReservation += $vm.CpuReservationMhz
                $totalMemoryReservation += $vm.MemoryReservationMB
            }
        }

        # Check CPU limits and reservations
        if ($ResourcePool.CpuLimitMhz -ne -1 -and $totalCPUReservation -gt $ResourcePool.CpuLimitMhz) {
            $healthIssues += "CPU reservations ($totalCPUReservation MHz) exceed pool limit ($($ResourcePool.CpuLimitMhz) MHz)"
            $healthStatus = "Critical"
        }

        if ($ResourcePool.MemLimitMB -ne -1 -and $totalMemoryReservation -gt $ResourcePool.MemLimitMB) {
            $healthIssues += "Memory reservations ($([math]::Round($totalMemoryReservation/1024, 1)) GB) exceed pool limit ($([math]::Round($ResourcePool.MemLimitMB/1024, 1)) GB)"
            $healthStatus = "Critical"
        }

        # Check for high resource contention
        if ($ResourcePool.CpuReservationUsedMhz / $ResourcePool.CpuReservationMhz -gt 0.9) {
            $healthIssues += "High CPU reservation usage: $([math]::Round($ResourcePool.CpuReservationUsedMhz / $ResourcePool.CpuReservationMhz * 100, 1))%"
            if ($healthStatus -eq "Healthy") {
                $healthStatus = "Warning"
            }
        }

        if ($ResourcePool.MemReservationUsedMB / $ResourcePool.MemReservationMB -gt 0.9) {
            $healthIssues += "High memory reservation usage: $([math]::Round($ResourcePool.MemReservationUsedMB / $ResourcePool.MemReservationMB * 100, 1))%"
            if ($healthStatus -eq "Healthy") {
                $healthStatus = "Warning"
            }
        }

        # Check for idle VMs with high reservations
        $idleVMs = $vmsInPool | Where-Object {
            $_.PowerState -eq "PoweredOff" -and
            ($_.CpuReservationMhz -gt 0 -or $_.MemoryReservationMB -gt 0)
        }

        if ($idleVMs.Count -gt 0) {
            $healthIssues += "Powered-off VMs with reservations: $($idleVMs.Count)"
            if ($healthStatus -eq "Healthy") {
                $healthStatus = "Warning"
            }
        }

        $result = @{
            ResourcePool = $ResourcePool.Name
            Status = $healthStatus
            Issues = $healthIssues
            VMCount = $vmsInPool.Count
            PoweredOnVMs = ($vmsInPool | Where-Object { $_.PowerState -eq "PoweredOn" }).Count
            CPUReservationUsedPercent = [math]::Round($ResourcePool.CpuReservationUsedMhz / $ResourcePool.CpuReservationMhz * 100, 1)
            MemoryReservationUsedPercent = [math]::Round($ResourcePool.MemReservationUsedMB / $ResourcePool.MemReservationMB * 100, 1)
            CPUShares = $ResourcePool.CpuShares
            MemoryShares = $ResourcePool.MemShares
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
            ResourcePool = $ResourcePool.Name
            Status = "Failed"
            Message = $_.Exception.Message
        }
    }
}

# Function to generate resource pool report
function Get-ResourcePoolReport {
    param(
        $OutputFormat,
        $OutputPath
    )

    Write-Host "Generating resource pool report..." -ForegroundColor Yellow

    $reportData = @()

    try {
        # Get all resource pools
        $resourcePools = Get-ResourcePool

        foreach ($rp in $resourcePools) {
            $vmsInPool = Get-VM -Location $rp
            $poweredOnVMs = $vmsInPool | Where-Object { $_.PowerState -eq "PoweredOn" }

            $reportItem = [PSCustomObject]@{
                Name = $rp.Name
                Parent = $rp.Parent.Name
                ParentType = $rp.Parent.GetType().Name
                CPUShares = $rp.CpuShares
                MemoryShares = $rp.MemShares
                CPUReservationMHz = $rp.CpuReservationMhz
                CPUReservationUsedMHz = $rp.CpuReservationUsedMhz
                CPUReservationUsedPercent = if ($rp.CpuReservationMhz -gt 0) { [math]::Round($rp.CpuReservationUsedMhz / $rp.CpuReservationMhz * 100, 1) } else { 0 }
                CPULimitMHz = $rp.CpuLimitMhz
                CPUExpandableReservation = $rp.CpuExpandableReservation
                MemoryReservationMB = $rp.MemReservationMB
                MemoryReservationUsedMB = $rp.MemReservationUsedMB
                MemoryReservationUsedPercent = if ($rp.MemReservationMB -gt 0) { [math]::Round($rp.MemReservationUsedMB / $rp.MemReservationMB * 100, 1) } else { 0 }
                MemoryLimitMB = $rp.MemLimitMB
                MemoryExpandableReservation = $rp.MemExpandableReservation
                VMCount = $vmsInPool.Count
                PoweredOnVMs = $poweredOnVMs.Count
                PoweredOffVMs = ($vmsInPool | Where-Object { $_.PowerState -eq "PoweredOff" }).Count
                VMList = ($vmsInPool.Name -join ";")
                Timestamp = Get-Date
            }

            $reportData += $reportItem
        }

        # Export report
        switch ($OutputFormat) {
            "Console" {
                Write-Host "`n=== Resource Pool Report ===" -ForegroundColor Cyan
                $reportData | Format-Table Name, CPUShares, MemoryShares, VMCount, PoweredOnVMs, CPUReservationUsedPercent, MemoryReservationUsedPercent -AutoSize
            }
            "CSV" {
                if (-not $OutputPath) {
                    $OutputPath = "ResourcePool_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                }
                $reportData | Export-Csv -Path $OutputPath -NoTypeInformation
                Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
            }
            "JSON" {
                if (-not $OutputPath) {
                    $OutputPath = "ResourcePool_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                }
                $reportData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "Report exported to: $OutputPath" -ForegroundColor Green
            }
        }

        return $reportData
    }
    catch {
        Write-Warning "Failed to generate resource pool report: $($_.Exception.Message)"
        return @()
    }
}

# Function to display operation summary
function Show-ResourcePoolOperationSummary {
    param(
        $Results,
        $Operation
    )

    Write-Host "`n=== Resource Pool $Operation Summary ===" -ForegroundColor Cyan

    $successful = $Results | Where-Object { $_.Status -eq "Success" }
    $failed = $Results | Where-Object { $_.Status -eq "Failed" }
    $warnings = $Results | Where-Object { $_.Status -in @("AlreadyExists", "NotFound", "AlreadyInPool") }

    Write-Host "Total Operations: $($Results.Count)" -ForegroundColor White
    Write-Host "Successful: $($successful.Count)" -ForegroundColor Green
    Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
    Write-Host "Warnings: $($warnings.Count)" -ForegroundColor Yellow

    if ($failed.Count -gt 0) {
        Write-Host "`nFailed Operations:" -ForegroundColor Red
        foreach ($result in $failed) {
            Write-Host "  - $($result.ResourcePool ?? $result.VM): $($result.Message)" -ForegroundColor White
        }
    }
}

# Main execution
try {
    Write-Host "=== vSphere Resource Pool Operations ===" -ForegroundColor Cyan
    Write-Host "Target vCenter: $VCenterServer" -ForegroundColor White
    Write-Host "Operation: $Operation" -ForegroundColor White

    if ($ClusterName) { Write-Host "Target Cluster: $ClusterName" -ForegroundColor White }
    if ($ResourcePoolName) { Write-Host "Resource Pool: $ResourcePoolName" -ForegroundColor White }
    if ($VMName) { Write-Host "Target VM: $VMName" -ForegroundColor White }
    Write-Host ""

    # Check and install PowerCLI
    if (-not (Test-PowerCLIInstallation)) {
        throw "PowerCLI installation failed"
    }

    # Connect to vCenter
    $connection = Connect-ToVCenter -Server $VCenterServer

    # Perform the requested operation
    $results = @()

    switch ($Operation) {
        "CreateResourcePool" {
            if (-not $ClusterName -or -not $ResourcePoolName) {
                throw "ClusterName and ResourcePoolName are required for CreateResourcePool operation"
            }

            $result = New-ResourcePool -ClusterName $ClusterName -ResourcePoolName $ResourcePoolName -ParentResourcePoolName $ParentResourcePoolName -CPUShares $CPUShares -MemoryShares $MemoryShares -CPUReservationMHz $CPUReservationMHz -MemoryReservationGB $MemoryReservationGB -CPULimitMHz $CPULimitMHz -MemoryLimitGB $MemoryLimitGB -CPUExpandableReservation:$CPUExpandableReservation -MemoryExpandableReservation:$MemoryExpandableReservation
            $results += $result
        }

        "CreateChildResourcePool" {
            if (-not $ParentResourcePoolName -or -not $ResourcePoolName) {
                throw "ParentResourcePoolName and ResourcePoolName are required for CreateChildResourcePool operation"
            }

            $result = New-ResourcePool -ClusterName $ClusterName -ResourcePoolName $ResourcePoolName -ParentResourcePoolName $ParentResourcePoolName -CPUShares $CPUShares -MemoryShares $MemoryShares -CPUReservationMHz $CPUReservationMHz -MemoryReservationGB $MemoryReservationGB -CPULimitMHz $CPULimitMHz -MemoryLimitGB $MemoryLimitGB -CPUExpandableReservation:$CPUExpandableReservation -MemoryExpandableReservation:$MemoryExpandableReservation
            $results += $result
        }

        "DeleteResourcePool" {
            if (-not $ResourcePoolName) {
                throw "ResourcePoolName is required for DeleteResourcePool operation"
            }

            $result = Remove-ResourcePool -ResourcePoolName $ResourcePoolName -Force:$Force
            $results += $result
        }

        "ConfigureVMResources" {
            if (-not $VMName) {
                throw "VMName is required for ConfigureVMResources operation"
            }

            $result = Set-VMResourceAllocation -VMName $VMName -CPUShares $CPUShares -MemoryShares $MemoryShares -CPUReservationMHz $CPUReservationMHz -MemoryReservationGB $MemoryReservationGB -CPULimitMHz $CPULimitMHz -MemoryLimitGB $MemoryLimitGB
            $results += $result
        }

        "MoveVMToResourcePool" {
            if (-not $VMName -or -not $ResourcePoolName) {
                throw "VMName and ResourcePoolName are required for MoveVMToResourcePool operation"
            }

            $result = Move-VMToResourcePool -VMName $VMName -ResourcePoolName $ResourcePoolName
            $results += $result
        }

        "ResourcePoolHealth" {
            $resourcePools = if ($ResourcePoolName) {
                @(Get-ResourcePool -Name $ResourcePoolName)
            } else {
                Get-ResourcePool
            }

            foreach ($rp in $resourcePools) {
                $result = Get-ResourcePoolHealthCheck -ResourcePool $rp
                $results += $result
            }

            # Display health summary
            $healthy = $results | Where-Object { $_.Status -eq "Healthy" }
            $warning = $results | Where-Object { $_.Status -eq "Warning" }
            $critical = $results | Where-Object { $_.Status -eq "Critical" }

            Write-Host "`n=== Resource Pool Health Summary ===" -ForegroundColor Cyan
            Write-Host "Healthy: $($healthy.Count)" -ForegroundColor Green
            Write-Host "Warning: $($warning.Count)" -ForegroundColor Yellow
            Write-Host "Critical: $($critical.Count)" -ForegroundColor Red
        }

        "Report" {
            $results = Get-ResourcePoolReport -OutputFormat $OutputFormat -OutputPath $OutputPath
        }

        "ResourceUsage" {
            $resourcePools = Get-ResourcePool
            Write-Host "`n=== Resource Pool Usage Summary ===" -ForegroundColor Cyan

            foreach ($rp in $resourcePools) {
                $cpuUsagePercent = if ($rp.CpuReservationMhz -gt 0) { [math]::Round($rp.CpuReservationUsedMhz / $rp.CpuReservationMhz * 100, 1) } else { 0 }
                $memUsagePercent = if ($rp.MemReservationMB -gt 0) { [math]::Round($rp.MemReservationUsedMB / $rp.MemReservationMB * 100, 1) } else { 0 }

                Write-Host "`n$($rp.Name):" -ForegroundColor Yellow
                Write-Host "  CPU: $($rp.CpuReservationUsedMhz)/$($rp.CpuReservationMhz) MHz ($cpuUsagePercent%)" -ForegroundColor White
                Write-Host "  Memory: $([math]::Round($rp.MemReservationUsedMB/1024, 1))/$([math]::Round($rp.MemReservationMB/1024, 1)) GB ($memUsagePercent%)" -ForegroundColor White
                Write-Host "  VMs: $(Get-VM -Location $rp | Where-Object { $_.PowerState -eq 'PoweredOn' } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor White
            }
        }
    }

    # Display summary (except for operations that already display results)
    if ($Operation -notin @("Report", "ResourcePoolHealth", "ResourceUsage")) {
        Show-ResourcePoolOperationSummary -Results $results -Operation $Operation
    }

    Write-Host "`n=== Operation Completed ===" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
finally {
    # Disconnect from vCenter if connected
    if ($global:DefaultVIServers) {
        Write-Host "`nDisconnecting from vCenter..." -ForegroundColor Yellow
        Disconnect-VIServer -Server * -Confirm:$false -Force
    }
}
