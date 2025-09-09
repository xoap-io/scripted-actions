<#
.SYNOPSIS
    Deploy Azure VM for Azure Stack HCI nested virtualization testing.

.DESCRIPTION
    This script deploys a Windows Server 2022 virtual machine in Azure with nested virtualization 
    capabilities for testing Azure Stack HCI. The VM includes Hyper-V role installation and 
    configuration for running nested virtual machines.

    The script supports both DryRun mode for testing and actual deployment. In DryRun mode,
    all operations are simulated without creating actual Azure resources.

.PARAMETER ResourceGroup
    Name of the Azure resource group to create or use.

.PARAMETER VmName
    Name of the virtual machine to create.

.PARAMETER Location
    Azure region where resources will be created.

.PARAMETER VmSize
    Azure VM size that supports nested virtualization.

.PARAMETER AdminUser
    Administrator username for the VM.

.PARAMETER AdminPassword
    Administrator password for the VM (as SecureString).

.PARAMETER WindowsSku
    Windows Server SKU to use for the VM.

.PARAMETER VNetAddressPrefix
    Address prefix for the virtual network (CIDR notation).

.PARAMETER SubnetAddressPrefix
    Address prefix for the subnet (CIDR notation).

.PARAMETER VNetName
    Name of the virtual network to create.

.PARAMETER SubnetName
    Name of the subnet to create within the VNet.

.PARAMETER NSGName
    Name of the network security group to create.

.PARAMETER PublicIPName
    Name of the public IP address to create.

.PARAMETER NICName
    Name of the network interface to create.

.PARAMETER DryRun
    If specified, performs a dry run without creating actual resources.

.EXAMPLE
    .\az-ps-deploy-azure-local-host.ps1 -ResourceGroup "rg-azstackhci-test" -VmName "vm-azstackhci-host" -Location "East US" -AdminUser "azureadmin"

.EXAMPLE
    .\az-ps-deploy-azure-local-host.ps1 -ResourceGroup "rg-test" -VmName "vm-test" -Location "West US 2" -AdminUser "admin" -DryRun

.NOTES
    Requires Azure PowerShell module (Az) to be installed and authenticated.
    VM sizes that support nested virtualization: Standard_D2s_v3, Standard_D4s_v3, Standard_D8s_v3, 
    Standard_D16s_v3, Standard_D32s_v3, Standard_E2s_v3, Standard_E4s_v3, Standard_E8s_v3, 
    Standard_E16s_v3, Standard_E32s_v3, Standard_F2s_v2, Standard_F4s_v2, Standard_F8s_v2, 
    Standard_F16s_v2, Standard_F32s_v2

    Author: Azure Infrastructure Team
    Version: 1.0
    Last Updated: September 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9\-_\.]{1,90}$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9\-_]{1,15}$')]
    [string]$VmName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('East US', 'East US 2', 'West US', 'West US 2', 'West US 3', 'Central US', 'North Central US', 'South Central US', 'West Central US', 'Canada Central', 'Canada East', 'Brazil South', 'North Europe', 'West Europe', 'UK South', 'UK West', 'France Central', 'Germany West Central', 'Switzerland North', 'Norway East', 'Sweden Central', 'Australia East', 'Australia Southeast', 'East Asia', 'Southeast Asia', 'Japan East', 'Japan West', 'Korea Central', 'Korea South', 'Central India', 'South India', 'West India', 'UAE North', 'South Africa North')]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3', 'Standard_D16s_v3', 'Standard_D32s_v3', 'Standard_E2s_v3', 'Standard_E4s_v3', 'Standard_E8s_v3', 'Standard_E16s_v3', 'Standard_E32s_v3', 'Standard_F2s_v2', 'Standard_F4s_v2', 'Standard_F8s_v2', 'Standard_F16s_v2', 'Standard_F32s_v2', 'Standard_D8s_v5', 'Standard_D16s_v5', 'Standard_D32s_v5')]
    [string]$VmSize = 'Standard_D4s_v3',

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9\-_]{1,20}$')]
    [string]$AdminUser,

    [Parameter(Mandatory = $false)]
    [SecureString]$AdminPassword,

    [Parameter(Mandatory = $false)]
    [ValidateSet('2019-datacenter', '2019-datacenter-core', '2022-datacenter', '2022-datacenter-core', '2022-datacenter-azure-edition', '2022-datacenter-azure-edition-core')]
    [string]$WindowsSku = '2022-datacenter-azure-edition',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$')]
    [string]$VNetAddressPrefix = '10.10.0.0/16',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$')]
    [string]$SubnetAddressPrefix = '10.10.1.0/24',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9\-_]{2,64}$')]
    [string]$VNetName = "vnet-$VmName",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9\-_]{2,80}$')]
    [string]$SubnetName = "subnet-default",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9\-_\.]{1,80}$')]
    [string]$NSGName = "nsg-$VmName-rdp",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9\-_\.]{1,80}$')]
    [string]$PublicIPName = "pip-$VmName",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9\-_]{1,80}$')]
    [string]$NICName = "nic-$VmName",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    
    if ($DryRun) {
        Write-Host "[DRY RUN] $Message" -ForegroundColor Cyan
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Function to validate Azure login
function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "Not logged in to Azure"
        }
        Write-ColorOutput "Azure context validated: $($context.Account.Id)" -Color Green
        return $true
    }
    catch {
        Write-Error "Azure login required. Please run 'Connect-AzAccount' first."
        return $false
    }
}

# Function to get or prompt for admin password
function Get-AdminPassword {
    if (-not $AdminPassword) {
        Write-Host "Enter administrator password for VM '$VmName':" -ForegroundColor Yellow
        $AdminPassword = Read-Host -AsSecureString
    }
    return $AdminPassword
}

# Main execution
try {
    Write-ColorOutput "Starting Azure Stack HCI deployment script" -Color Cyan
    Write-ColorOutput "Target Resource Group: $ResourceGroup" -Color White
    Write-ColorOutput "Target VM: $VmName" -Color White
    Write-ColorOutput "Target Location: $Location" -Color White
    Write-ColorOutput "VM Size: $VmSize" -Color White
    Write-ColorOutput "Windows SKU: $WindowsSku" -Color White
    
    if ($DryRun) {
        Write-ColorOutput "DRY RUN MODE - No actual resources will be created" -Color Yellow
    }

    # Validate Azure login
    if (-not (Test-AzureLogin)) {
        exit 1
    }

    # Get admin password
    $AdminPassword = Get-AdminPassword

    # Create or verify resource group
    Write-ColorOutput "Checking resource group '$ResourceGroup'..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would check/create resource group '$ResourceGroup' in '$Location'" -Color Cyan
    } else {
        try {
            $rg = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) {
                Write-ColorOutput "Creating resource group '$ResourceGroup'..." -Color Yellow
                $rg = New-AzResourceGroup -Name $ResourceGroup -Location $Location
                Write-ColorOutput "Resource group created successfully" -Color Green
            } else {
                Write-ColorOutput "Resource group already exists" -Color Green
            }
        }
        catch {
            Write-Error "Failed to create/verify resource group: $($_.Exception.Message)"
            exit 1
        }
    }

    # Create virtual network
    Write-ColorOutput "Creating virtual network '$VNetName'..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would create VNet '$VNetName' with address space $VNetAddressPrefix" -Color Cyan
        Write-ColorOutput "Would create subnet '$SubnetName' with address space $SubnetAddressPrefix" -Color Cyan
    } else {
        try {
            $subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
            $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Location $Location -Name $VNetName -AddressPrefix $VNetAddressPrefix -Subnet $subnet
            Write-ColorOutput "Virtual network created successfully" -Color Green
        }
        catch {
            Write-Error "Failed to create virtual network: $($_.Exception.Message)"
            exit 1
        }
    }

    # Create network security group
    Write-ColorOutput "Creating network security group '$NSGName'..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would create NSG '$NSGName' with RDP rule (port 3389)" -Color Cyan
    } else {
        try {
            $rdpRule = New-AzNetworkSecurityRuleConfig -Name "Allow-RDP" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
            $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Location $Location -Name $NSGName -SecurityRules $rdpRule
            Write-ColorOutput "Network security group created successfully" -Color Green
        }
        catch {
            Write-Error "Failed to create network security group: $($_.Exception.Message)"
            exit 1
        }
    }

    # Create public IP
    Write-ColorOutput "Creating public IP '$PublicIPName'..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would create public IP '$PublicIPName' with static allocation" -Color Cyan
    } else {
        try {
            $pip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Location $Location -Name $PublicIPName -AllocationMethod Static -Sku Standard
            Write-ColorOutput "Public IP created successfully" -Color Green
        }
        catch {
            Write-Error "Failed to create public IP: $($_.Exception.Message)"
            exit 1
        }
    }

    # Create network interface
    Write-ColorOutput "Creating network interface '$NICName'..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would create NIC '$NICName' and associate with subnet, NSG, and public IP" -Color Cyan
    } else {
        try {
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetName
            $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $SubnetName
            $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Name $NSGName
            $pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $PublicIPName
            
            $nic = New-AzNetworkInterface -ResourceGroupName $ResourceGroup -Location $Location -Name $NICName -SubnetId $subnet.Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id
            Write-ColorOutput "Network interface created successfully" -Color Green
        }
        catch {
            Write-Error "Failed to create network interface: $($_.Exception.Message)"
            exit 1
        }
    }

    # Create virtual machine
    Write-ColorOutput "Creating virtual machine '$VmName'..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would create VM '$VmName' with Windows Server $WindowsSku" -Color Cyan
        Write-ColorOutput "Would configure VM with size '$VmSize' and enable nested virtualization" -Color Cyan
    } else {
        try {
            # Create credential object
            $credential = New-Object System.Management.Automation.PSCredential ($AdminUser, $AdminPassword)
            
            # Create VM configuration
            $vmConfig = New-AzVMConfig -VMName $VmName -VMSize $VmSize
            $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $VmName -Credential $credential -ProvisionVMAgent -EnableAutoUpdate
            $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus $WindowsSku -Version "latest"
            
            # Get network interface
            $nic = Get-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $NICName
            $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
            
            # Set OS disk
            $vmConfig = Set-AzVMOSDisk -VM $vmConfig -CreateOption FromImage -StorageAccountType Premium_LRS
            
            # Create the VM
            $vm = New-AzVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vmConfig
            Write-ColorOutput "Virtual machine created successfully" -Color Green
        }
        catch {
            Write-Error "Failed to create virtual machine: $($_.Exception.Message)"
            exit 1
        }
    }

    # Configure nested virtualization and install Hyper-V
    Write-ColorOutput "Configuring nested virtualization and installing Hyper-V..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would stop VM to enable nested virtualization" -Color Cyan
        Write-ColorOutput "Would install Hyper-V role and management tools" -Color Cyan
        Write-ColorOutput "Would restart VM to complete configuration" -Color Cyan
    } else {
        try {
            # Stop VM to enable nested virtualization
            Write-ColorOutput "Stopping VM to enable nested virtualization..." -Color Yellow
            Stop-AzVM -ResourceGroupName $ResourceGroup -Name $VmName -Force
            
            # Enable nested virtualization
            Write-ColorOutput "Enabling nested virtualization..." -Color Yellow
            $vm = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VmName
            $vm.HardwareProfile.VmSize = $VmSize
            Update-AzVM -ResourceGroupName $ResourceGroup -VM $vm
            
            # Start VM
            Write-ColorOutput "Starting VM..." -Color Yellow
            Start-AzVM -ResourceGroupName $ResourceGroup -Name $VmName
            
            # Wait for VM to be ready
            Write-ColorOutput "Waiting for VM to be ready..." -Color Yellow
            Start-Sleep -Seconds 120
            
            # Install Hyper-V role using Custom Script Extension
            Write-ColorOutput "Installing Hyper-V role..." -Color Yellow
            
            $scriptContent = @"
# Install Hyper-V role and management tools
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
Add-WindowsCapability -Online -Name 'Rsat.Hyper-V.Tools~~~~0.0.1.0' -ErrorAction SilentlyContinue
Restart-Computer -Force
"@
            
            $scriptBytes = [System.Text.Encoding]::UTF8.GetBytes($scriptContent)
            $scriptBase64 = [System.Convert]::ToBase64String($scriptBytes)
            
            Set-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroup -VMName $VmName -Name "InstallHyperV" -FileUri @() -Run "powershell.exe" -Argument "-encodedCommand $scriptBase64" -Location $Location
            
            Write-ColorOutput "Hyper-V installation initiated. VM will restart automatically." -Color Green
        }
        catch {
            Write-Error "Failed to configure nested virtualization: $($_.Exception.Message)"
            exit 1
        }
    }

    # Display deployment summary
    Write-ColorOutput "`n=== Deployment Summary ===" -Color Cyan
    
    if ($DryRun) {
        Write-ColorOutput "DRY RUN COMPLETED - Resources that would be created:" -Color Yellow
        Write-ColorOutput "- Resource Group: $ResourceGroup" -Color White
        Write-ColorOutput "- Virtual Network: $VNetName ($VNetAddressPrefix)" -Color White
        Write-ColorOutput "- Subnet: $SubnetName ($SubnetAddressPrefix)" -Color White
        Write-ColorOutput "- Network Security Group: $NSGName" -Color White
        Write-ColorOutput "- Public IP: $PublicIPName" -Color White
        Write-ColorOutput "- Network Interface: $NICName" -Color White
        Write-ColorOutput "- Virtual Machine: $VmName ($VmSize)" -Color White
        Write-ColorOutput "- OS: Windows Server $WindowsSku" -Color White
        Write-ColorOutput "- Features: Nested Virtualization, Hyper-V Role" -Color White
        Write-ColorOutput "`nEstimated monthly cost (approx): $200-400 USD depending on usage" -Color Yellow
        Write-ColorOutput "To deploy for real, run the script again without the -DryRun parameter" -Color Yellow
    } else {
        Write-ColorOutput "DEPLOYMENT COMPLETED SUCCESSFULLY!" -Color Green
        Write-ColorOutput "Resources created:" -Color White
        Write-ColorOutput "- Resource Group: $ResourceGroup" -Color White
        Write-ColorOutput "- Virtual Network: $VNetName" -Color White
        Write-ColorOutput "- Subnet: $SubnetName" -Color White
        Write-ColorOutput "- Network Security Group: $NSGName" -Color White
        Write-ColorOutput "- Public IP: $PublicIPName" -Color White
        Write-ColorOutput "- Network Interface: $NICName" -Color White
        Write-ColorOutput "- Virtual Machine: $VmName" -Color White
        
        # Get public IP address - only if not in DryRun mode
        try {
            $publicIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $PublicIPName
            Write-ColorOutput "`nConnection Information:" -Color Cyan
            Write-ColorOutput "- Public IP Address: $($publicIP.IpAddress)" -Color White
            Write-ColorOutput "- RDP Port: 3389" -Color White
            Write-ColorOutput "- Username: $AdminUser" -Color White
            Write-ColorOutput "`nTo connect via RDP:" -Color Yellow
            Write-ColorOutput "mstsc /v:$($publicIP.IpAddress)" -Color White
        }
        catch {
            Write-Warning "Could not retrieve public IP address information"
        }
        
        Write-ColorOutput "`nNote: Hyper-V installation is in progress. The VM will restart automatically to complete the installation." -Color Yellow
        Write-ColorOutput "After the restart, you can connect to the VM and start creating nested VMs for Azure Stack HCI testing." -Color Yellow
    }
}
catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}