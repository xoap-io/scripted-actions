<#
.SYNOPSIS
    Create a logical network on an Azure Local (Azure Stack HCI) cluster.

.DESCRIPTION
    This script creates a new logical network on an Azure Local cluster via the Arc resource
    bridge, so that Azure Local VMs can attach network interfaces to it. It supports both
    static IP pools and DHCP allocation. For static networks a default route (0.0.0.0/0) to
    the given gateway and the DNS servers are configured on the subnet.

    The script is idempotent: if a logical network with the same name already exists in the
    resource group, it is reused and the script exits successfully.

    The default values match the XOAP Jumpstart LocalBox environment (cluster
    'localboxcluster' in resource group 'AzureLocal'): a new workload network 'lnet-vms' on
    the 192.168.1.0/24 subnet with an IP pool of 192.168.1.200-192.168.1.240 that does not
    overlap the pool of the existing 'localboxcluster-InfraLNET' network (192.168.1.101-103).

    Uses Get-AzStackHCIVMLogicalNetwork and New-AzStackHCIVMLogicalNetwork.

    This script can run anywhere with an Azure context; it does not need to run on a cluster
    node. Verify the Hyper-V switch name on a cluster node with Get-VMSwitch if the creation
    fails - the name must match exactly.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources. Defaults to "westeurope".

.PARAMETER LogicalNetworkName
    Name of the logical network to create. Defaults to "lnet-vms".

.PARAMETER VmSwitchName
    Name of the external Hyper-V switch on the cluster the logical network binds to.
    Defaults to "ConvergedSwitch(compute_management)" (LocalBox default switch).

.PARAMETER SubnetName
    Name of the subnet within the logical network. Defaults to "default".

.PARAMETER IpAllocationMethod
    IP allocation method for the subnet: "Static" (IP pool, gateway and DNS configured) or
    "Dynamic" (DHCP). Defaults to "Static".

.PARAMETER AddressPrefix
    Subnet address prefix in CIDR notation. Defaults to "192.168.1.0/24".

.PARAMETER IpPoolStart
    First IP address of the static IP pool. Defaults to "192.168.1.200". Static allocation only.

.PARAMETER IpPoolEnd
    Last IP address of the static IP pool. Defaults to "192.168.1.240". Static allocation only.

.PARAMETER Gateway
    Default gateway for the subnet (configured as a 0.0.0.0/0 route). Defaults to
    "192.168.1.1". Static allocation only.

.PARAMETER DnsServers
    DNS servers for the subnet. Defaults to @("192.168.1.254") (LocalBox DNS). Static
    allocation only.

.PARAMETER Vlan
    Optional VLAN ID for the subnet. Defaults to 0 (no VLAN tagging).

.EXAMPLE
    .\az-ps-create-azure-local-logical-network.ps1

    Creates the "lnet-vms" workload network with all LocalBox defaults.

.EXAMPLE
    .\az-ps-create-azure-local-logical-network.ps1 `
        -LogicalNetworkName "lnet-dhcp" `
        -IpAllocationMethod "Dynamic"

    Creates a DHCP-based logical network on the default switch.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM)

    The IP pool of a new static network must not overlap the pools of existing logical
    networks on the same subnet.

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/create-logical-networks

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    # Azure Local resource scoping
    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId = "/subscriptions/e5373ae1-c1cf-418e-8044-a2851af745b6/resourceGroups/AzureLocal/providers/Microsoft.ExtendedLocation/customLocations/jumpstart",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region of the Arc resources.")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    # Logical network definition
    [Parameter(Mandatory = $false, HelpMessage = "Name of the logical network to create.")]
    [ValidateNotNullOrEmpty()]
    [string]$LogicalNetworkName = "lnet-vms",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the external Hyper-V switch on the cluster.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmSwitchName = "ConvergedSwitch(compute_management)",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the subnet within the logical network.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName = "default",

    [Parameter(Mandatory = $false, HelpMessage = "IP allocation method: Static (IP pool) or Dynamic (DHCP).")]
    [ValidateSet("Static", "Dynamic")]
    [string]$IpAllocationMethod = "Static",

    [Parameter(Mandatory = $false, HelpMessage = "Subnet address prefix in CIDR notation.")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$AddressPrefix = "192.168.1.0/24",

    [Parameter(Mandatory = $false, HelpMessage = "First IP address of the static IP pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$IpPoolStart = "192.168.1.200",

    [Parameter(Mandatory = $false, HelpMessage = "Last IP address of the static IP pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$IpPoolEnd = "192.168.1.240",

    [Parameter(Mandatory = $false, HelpMessage = "Default gateway for the subnet (0.0.0.0/0 route).")]
    [ValidateNotNullOrEmpty()]
    [string]$Gateway = "192.168.1.1",

    [Parameter(Mandatory = $false, HelpMessage = "DNS servers for the subnet.")]
    [string[]]$DnsServers = @("192.168.1.254"),

    [Parameter(Mandatory = $false, HelpMessage = "Optional VLAN ID for the subnet. 0 = no VLAN tagging.")]
    [ValidateRange(0, 4094)]
    [int]$Vlan = 0
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Preflight: module + Azure context
    if (-not (Get-Module -ListAvailable -Name Az.StackHCIVM)) {
        throw "The Az.StackHCIVM module is not installed. Run: Install-Module Az.StackHCIVM -Scope CurrentUser"
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. Run Connect-AzAccount (or sign in with your service principal) first."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    # 1) Idempotency: reuse an existing logical network with the same name
    $lnet = Get-AzStackHCIVMLogicalNetwork -ResourceGroupName $ResourceGroupName -Name $LogicalNetworkName -ErrorAction SilentlyContinue
    if ($lnet) {
        Write-Host "ℹ️  Logical network '$LogicalNetworkName' already exists on switch '$($lnet.VMSwitchName)' - nothing to do" -ForegroundColor Yellow
        return
    }

    # 2) Create the logical network
    Write-Host "🚀 Creating logical network '$LogicalNetworkName' on switch '$VmSwitchName' ($IpAllocationMethod)..." -ForegroundColor Green

    $lnetParams = @{
        Name               = $LogicalNetworkName
        ResourceGroupName  = $ResourceGroupName
        CustomLocationId   = $CustomLocationId
        Location           = $Location
        VMSwitchName       = $VmSwitchName
        SubnetName         = $SubnetName
        AddressPrefix      = @($AddressPrefix)
        IpAllocationMethod = $IpAllocationMethod
    }

    if ($IpAllocationMethod -eq 'Static') {
        $lnetParams['IpPoolStart'] = $IpPoolStart
        $lnetParams['IpPoolEnd']   = $IpPoolEnd
        $lnetParams['Route']       = @(
            @{
                Name             = "default"
                AddressPrefix    = "0.0.0.0/0"
                NextHopIpAddress = $Gateway
            }
        )
        if ($DnsServers.Count -gt 0) {
            $lnetParams['DnsServer'] = $DnsServers
        }
        Write-Host "🔧 Subnet: $AddressPrefix | IP pool: $IpPoolStart - $IpPoolEnd | Gateway: $Gateway | DNS: $($DnsServers -join ', ')" -ForegroundColor Cyan
    }

    if ($Vlan -gt 0) {
        $lnetParams['Vlan'] = $Vlan
        Write-Host "🔧 VLAN ID: $Vlan" -ForegroundColor Cyan
    }

    $lnet = New-AzStackHCIVMLogicalNetwork @lnetParams

    Write-Host "✅ Logical network '$LogicalNetworkName' created (provisioning state: $($lnet.ProvisioningState))" -ForegroundColor Green
    Write-Host "💡 Next Steps: attach VM network interfaces with New-AzStackHCIVMNetworkInterface or deploy a VM with az-ps-deploy-azure-local-vm-from-image.ps1 -LogicalNetworkName '$LogicalNetworkName'" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
