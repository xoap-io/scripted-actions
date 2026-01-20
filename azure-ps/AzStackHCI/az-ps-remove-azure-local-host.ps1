<#
.SYNOPSIS
    Remove Azure VM and all related resources created for Azure Stack HCI testing.

.DESCRIPTION
    This script removes a Windows Server virtual machine and all related Azure resources
    that were created for Azure Stack HCI nested virtualization testing. This includes
    the VM, network interface, public IP, network security group, virtual network, and
    optionally the resource group.

    The script supports both DryRun mode for testing and actual resource deletion. In DryRun mode,
    all operations are simulated without deleting actual Azure resources.

    Resources removed (in order):
    1. Virtual Machine
    2. Network Interface
    3. Public IP Address
    4. Network Security Group
    5. Virtual Network
    6. Resource Group (if -RemoveResourceGroup is specified)

.PARAMETER ResourceGroup
    Name of the Azure resource group containing the resources to remove.

.PARAMETER VmName
    Name of the virtual machine to remove. Used to derive other resource names.

.PARAMETER RemoveResourceGroup
    If specified, removes the entire resource group after removing individual resources.
    Use with caution as this will remove ALL resources in the resource group.

.PARAMETER Force
    If specified, skips confirmation prompts for resource deletion.

.PARAMETER VNetName
    Name of the virtual network to remove. If not specified, defaults to "vnet-{VmName}".

.PARAMETER SubnetName
    Name of the subnet within the VNet. If not specified, defaults to "subnet-default".

.PARAMETER NSGName
    Name of the network security group to remove. If not specified, defaults to "nsg-{VmName}-rdp".

.PARAMETER PublicIPName
    Name of the public IP address to remove. If not specified, defaults to "pip-{VmName}".

.PARAMETER NICName
    Name of the network interface to remove. If not specified, defaults to "nic-{VmName}".

.PARAMETER DryRun
    If specified, performs a dry run without deleting actual resources.

.EXAMPLE
    .\az-ps-remove-azure-local-host.ps1 -ResourceGroup "rg-azstackhci-test" -VmName "vm-azstackhci-host"

.EXAMPLE
    .\az-ps-remove-azure-local-host.ps1 -ResourceGroup "rg-test" -VmName "vm-test" -RemoveResourceGroup -Force

.EXAMPLE
    .\az-ps-remove-azure-local-host.ps1 -ResourceGroup "rg-test" -VmName "vm-test" -DryRun

.NOTES
    Requires Azure PowerShell module (Az) to be installed and authenticated.

    WARNING: This script will permanently delete Azure resources. Ensure you have backups
    of any important data before running this script.

    The script will attempt to remove resources in the correct order to avoid dependency
    conflicts. Some resources may take time to delete completely.

    Author: XOAP.io

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

    [Parameter(Mandatory = $false)]
    [switch]$RemoveResourceGroup,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

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

# Function to check if resource exists
function Test-ResourceExists {
    param(
        [string]$ResourceType,
        [string]$ResourceName,
        [string]$ResourceGroupName
    )

    try {
        switch ($ResourceType) {
            "VM" {
                $resource = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
            }
            "NetworkInterface" {
                $resource = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
            }
            "PublicIP" {
                $resource = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
            }
            "NetworkSecurityGroup" {
                $resource = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
            }
            "VirtualNetwork" {
                $resource = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $ResourceName -ErrorAction SilentlyContinue
            }
            "ResourceGroup" {
                $resource = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
            }
        }
        return $null -ne $resource
    }
    catch {
        return $false
    }
}

# Function to confirm deletion
function Confirm-Deletion {
    param(
        [string]$ResourceType,
        [string]$ResourceName
    )

    if ($Force -or $DryRun) {
        return $true
    }

    $confirmation = Read-Host "Are you sure you want to delete $ResourceType '$ResourceName'? (y/N)"
    return $confirmation -eq 'y' -or $confirmation -eq 'Y'
}

# Main execution
try {
    Write-ColorOutput "Starting Azure Stack HCI cleanup script" -Color Cyan
    Write-ColorOutput "Target Resource Group: $ResourceGroup" -Color White
    Write-ColorOutput "Target VM: $VmName" -Color White

    if ($DryRun) {
        Write-ColorOutput "DRY RUN MODE - No actual resources will be deleted" -Color Yellow
    } elseif (-not $Force) {
        Write-ColorOutput "Running in interactive mode - you will be prompted for confirmations" -Color Yellow
    }

    # Validate Azure login
    if (-not (Test-AzureLogin)) {
        exit 1
    }

    # Check if resource group exists
    Write-ColorOutput "Checking if resource group '$ResourceGroup' exists..." -Color Yellow

    if (-not (Test-ResourceExists -ResourceType "ResourceGroup" -ResourceName $ResourceGroup -ResourceGroupName $ResourceGroup)) {
        Write-ColorOutput "Resource group '$ResourceGroup' does not exist. Nothing to clean up." -Color Green
        exit 0
    }

    Write-ColorOutput "Resource group found. Proceeding with cleanup..." -Color Green

    # 1. Remove Virtual Machine
    Write-ColorOutput "`n=== Removing Virtual Machine ===" -Color Cyan

    if (Test-ResourceExists -ResourceType "VM" -ResourceName $VmName -ResourceGroupName $ResourceGroup) {
        if ($DryRun) {
            Write-ColorOutput "Would delete VM '$VmName'" -Color Cyan
        } elseif (Confirm-Deletion -ResourceType "Virtual Machine" -ResourceName $VmName) {
            try {
                Write-ColorOutput "Deleting VM '$VmName'..." -Color Yellow
                Remove-AzVM -ResourceGroupName $ResourceGroup -Name $VmName -Force
                Write-ColorOutput "VM deleted successfully" -Color Green
            }
            catch {
                Write-Warning "Failed to delete VM: $($_.Exception.Message)"
            }
        } else {
            Write-ColorOutput "Skipping VM deletion" -Color Yellow
        }
    } else {
        Write-ColorOutput "VM '$VmName' not found or already deleted" -Color Green
    }

    # 2. Remove Network Interface
    Write-ColorOutput "`n=== Removing Network Interface ===" -Color Cyan

    if (Test-ResourceExists -ResourceType "NetworkInterface" -ResourceName $NICName -ResourceGroupName $ResourceGroup) {
        if ($DryRun) {
            Write-ColorOutput "Would delete Network Interface '$NICName'" -Color Cyan
        } elseif (Confirm-Deletion -ResourceType "Network Interface" -ResourceName $NICName) {
            try {
                Write-ColorOutput "Deleting Network Interface '$NICName'..." -Color Yellow
                Remove-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $NICName -Force
                Write-ColorOutput "Network Interface deleted successfully" -Color Green
            }
            catch {
                Write-Warning "Failed to delete Network Interface: $($_.Exception.Message)"
            }
        } else {
            Write-ColorOutput "Skipping Network Interface deletion" -Color Yellow
        }
    } else {
        Write-ColorOutput "Network Interface '$NICName' not found or already deleted" -Color Green
    }

    # 3. Remove Public IP
    Write-ColorOutput "`n=== Removing Public IP Address ===" -Color Cyan

    if (Test-ResourceExists -ResourceType "PublicIP" -ResourceName $PublicIPName -ResourceGroupName $ResourceGroup) {
        if ($DryRun) {
            Write-ColorOutput "Would delete Public IP '$PublicIPName'" -Color Cyan
        } elseif (Confirm-Deletion -ResourceType "Public IP Address" -ResourceName $PublicIPName) {
            try {
                Write-ColorOutput "Deleting Public IP '$PublicIPName'..." -Color Yellow
                Remove-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $PublicIPName -Force
                Write-ColorOutput "Public IP deleted successfully" -Color Green
            }
            catch {
                Write-Warning "Failed to delete Public IP: $($_.Exception.Message)"
            }
        } else {
            Write-ColorOutput "Skipping Public IP deletion" -Color Yellow
        }
    } else {
        Write-ColorOutput "Public IP '$PublicIPName' not found or already deleted" -Color Green
    }

    # 4. Remove Network Security Group
    Write-ColorOutput "`n=== Removing Network Security Group ===" -Color Cyan

    if (Test-ResourceExists -ResourceType "NetworkSecurityGroup" -ResourceName $NSGName -ResourceGroupName $ResourceGroup) {
        if ($DryRun) {
            Write-ColorOutput "Would delete Network Security Group '$NSGName'" -Color Cyan
        } elseif (Confirm-Deletion -ResourceType "Network Security Group" -ResourceName $NSGName) {
            try {
                Write-ColorOutput "Deleting Network Security Group '$NSGName'..." -Color Yellow
                Remove-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroup -Name $NSGName -Force
                Write-ColorOutput "Network Security Group deleted successfully" -Color Green
            }
            catch {
                Write-Warning "Failed to delete Network Security Group: $($_.Exception.Message)"
            }
        } else {
            Write-ColorOutput "Skipping Network Security Group deletion" -Color Yellow
        }
    } else {
        Write-ColorOutput "Network Security Group '$NSGName' not found or already deleted" -Color Green
    }

    # 5. Remove Virtual Network
    Write-ColorOutput "`n=== Removing Virtual Network ===" -Color Cyan

    if (Test-ResourceExists -ResourceType "VirtualNetwork" -ResourceName $VNetName -ResourceGroupName $ResourceGroup) {
        if ($DryRun) {
            Write-ColorOutput "Would delete Virtual Network '$VNetName'" -Color Cyan
        } elseif (Confirm-Deletion -ResourceType "Virtual Network" -ResourceName $VNetName) {
            try {
                Write-ColorOutput "Deleting Virtual Network '$VNetName'..." -Color Yellow
                Remove-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNetName -Force
                Write-ColorOutput "Virtual Network deleted successfully" -Color Green
            }
            catch {
                Write-Warning "Failed to delete Virtual Network: $($_.Exception.Message)"
            }
        } else {
            Write-ColorOutput "Skipping Virtual Network deletion" -Color Yellow
        }
    } else {
        Write-ColorOutput "Virtual Network '$VNetName' not found or already deleted" -Color Green
    }

    # 6. Remove Resource Group (if requested)
    if ($RemoveResourceGroup) {
        Write-ColorOutput "`n=== Removing Resource Group ===" -Color Cyan

        if ($DryRun) {
            Write-ColorOutput "Would delete Resource Group '$ResourceGroup' and ALL its contents" -Color Cyan
            Write-ColorOutput "WARNING: This would remove ALL resources in the resource group!" -Color Red
        } elseif (Confirm-Deletion -ResourceType "Resource Group (and ALL its contents)" -ResourceName $ResourceGroup) {
            try {
                Write-ColorOutput "Deleting Resource Group '$ResourceGroup'..." -Color Yellow
                Write-ColorOutput "WARNING: This will delete ALL resources in the resource group!" -Color Red
                Remove-AzResourceGroup -Name $ResourceGroup -Force
                Write-ColorOutput "Resource Group deleted successfully" -Color Green
            }
            catch {
                Write-Warning "Failed to delete Resource Group: $($_.Exception.Message)"
            }
        } else {
            Write-ColorOutput "Skipping Resource Group deletion" -Color Yellow
        }
    }

    # Display cleanup summary
    Write-ColorOutput "`n=== Cleanup Summary ===" -Color Cyan

    if ($DryRun) {
        Write-ColorOutput "DRY RUN COMPLETED - Resources that would be deleted:" -Color Yellow
        Write-ColorOutput "- Virtual Machine: $VmName" -Color White
        Write-ColorOutput "- Network Interface: $NICName" -Color White
        Write-ColorOutput "- Public IP: $PublicIPName" -Color White
        Write-ColorOutput "- Network Security Group: $NSGName" -Color White
        Write-ColorOutput "- Virtual Network: $VNetName" -Color White
        if ($RemoveResourceGroup) {
            Write-ColorOutput "- Resource Group: $ResourceGroup (and ALL its contents)" -Color Red
        }
        Write-ColorOutput "`nTo perform actual deletion, run the script again without the -DryRun parameter" -Color Yellow
    } else {
        Write-ColorOutput "CLEANUP COMPLETED!" -Color Green
        Write-ColorOutput "Processed resources:" -Color White
        Write-ColorOutput "- Virtual Machine: $VmName" -Color White
        Write-ColorOutput "- Network Interface: $NICName" -Color White
        Write-ColorOutput "- Public IP: $PublicIPName" -Color White
        Write-ColorOutput "- Network Security Group: $NSGName" -Color White
        Write-ColorOutput "- Virtual Network: $VNetName" -Color White
        if ($RemoveResourceGroup) {
            Write-ColorOutput "- Resource Group: $ResourceGroup" -Color White
        }

        Write-ColorOutput "`nNote: Some resources may take additional time to be fully removed from Azure." -Color Yellow
        Write-ColorOutput "You can verify deletion status in the Azure portal." -Color Yellow
    }
}
catch {
    Write-Error "Cleanup failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
