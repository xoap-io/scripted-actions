<#
.SYNOPSIS
    Deploy Azure Arc Jumpstart LocalBox (formerly HCIBox) for Azure Stack HCI testing and evaluation.

.DESCRIPTION
    This script deploys the Azure Arc Jumpstart LocalBox environment in Azure using the official Bicep template.
    LocalBox provides a complete Azure Stack HCI testing environment with nested virtualization, Arc-enabled
    servers, and various Azure hybrid services pre-configured for evaluation and learning.

    The script supports both DryRun mode for testing and actual deployment. In DryRun mode,
    all operations are simulated without creating actual Azure resources.

    Features included in LocalBox:
    - Windows Server client VM with nested virtualization
    - Azure Stack HCI cluster simulation
    - Arc-enabled servers and Kubernetes
    - Azure hybrid services integration
    - Optional Azure Bastion for secure access

.PARAMETER Location
    Azure region where LocalBox resources will be deployed.

.PARAMETER ResourceGroup
    Name of the Azure resource group to create or use for the LocalBox deployment.

.PARAMETER NamingPrefix
    Prefix used by the Bicep template to name all created resources.

.PARAMETER VmSize
    Azure VM size for the LocalBox client VM. Must support nested virtualization.

.PARAMETER WinAdminUser
    Administrator username for the LocalBox client VM.

.PARAMETER WinAdminPassword
    Administrator password for the LocalBox client VM (as SecureString).

.PARAMETER DeployBastion
    Whether to deploy Azure Bastion for browser-based RDP access.

.PARAMETER RdpPort
    RDP port for direct access to the client VM (when not using Bastion).

.PARAMETER VmAutologon
    Whether to enable automatic sign-in on the client VM.

.PARAMETER SubscriptionId
    Azure subscription ID to use for the deployment.

.PARAMETER DryRun
    If specified, performs a dry run without creating actual resources.

.EXAMPLE
    .\az-ps-deploy-jumpstart-localbox.ps1 -Location "West Europe" -ResourceGroup "rg-localbox" -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\az-ps-deploy-jumpstart-localbox.ps1 -Location "East US" -ResourceGroup "rg-test" -NamingPrefix "hcitest" -VmSize "Standard_D16s_v5" -DeployBastion $false -DryRun

.NOTES
    Requires Azure PowerShell module (Az) to be installed and authenticated.
    
    VM sizes that support nested virtualization: Standard_D8s_v5, Standard_D16s_v5, Standard_D32s_v5,
    Standard_E8s_v5, Standard_E16s_v5, Standard_E32s_v5, etc.

    The deployment can take 60-90 minutes to complete as it includes extensive configuration
    and software installation within the nested environment.

    IMPORTANT: This deployment can be expensive. Monitor costs and clean up when not needed.

    Template source: https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_hcibox

    Author: XOAP.io
    Version: 1.0
    Last Updated: September 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('East US', 'East US 2', 'West US', 'West US 2', 'West US 3', 'Central US', 'North Central US', 'South Central US', 'West Central US', 'Canada Central', 'Canada East', 'Brazil South', 'North Europe', 'West Europe', 'UK South', 'UK West', 'France Central', 'Germany West Central', 'Switzerland North', 'Norway East', 'Sweden Central', 'Australia East', 'Australia Southeast', 'East Asia', 'Southeast Asia', 'Japan East', 'Japan West', 'Korea Central', 'Korea South', 'Central India', 'South India', 'West India', 'UAE North', 'South Africa North')]
    [string]$Location = "West Europe",

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9\-_\.]{1,90}$')]
    [string]$ResourceGroup = "rg-localbox",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9\-_]{1,20}$')]
    [string]$NamingPrefix = "localbox",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Standard_D8s_v5', 'Standard_D16s_v5', 'Standard_D32s_v5', 'Standard_E8s_v5', 'Standard_E16s_v5', 'Standard_E32s_v5', 'Standard_D8s_v6', 'Standard_D16s_v6', 'Standard_D32s_v6')]
    [string]$VmSize = "Standard_D8s_v6",

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9\-_]{1,20}$')]
    [string]$WinAdminUser = "arcdemo",

    [Parameter(Mandatory = $false)]
    [SecureString]$WinAdminPassword,

    [Parameter(Mandatory = $false)]
    [bool]$DeployBastion = $true,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1024, 65535)]
    [int]$RdpPort = 3389,

    [Parameter(Mandatory = $false)]
    [bool]$VmAutologon = $false,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# IMPORTANT: Template URI
# LocalBox supersedes HCIBox. The Bicep lives in the Arc Jumpstart repo.
# If the LocalBox path changes, update the URL below to the current main.bicep.
$TemplateUri = "https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_hcibox/bicep/main.bicep"

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
    if (-not $WinAdminPassword) {
        Write-Host "Enter a strong password for the LocalBox client VM '$WinAdminUser':" -ForegroundColor Yellow
        $WinAdminPassword = Read-Host -AsSecureString
    }
    return $WinAdminPassword
}

# Main execution
try {
    Write-ColorOutput "Starting Azure Arc Jumpstart LocalBox deployment script" -Color Cyan
    Write-ColorOutput "Target Subscription: $SubscriptionId" -Color White
    Write-ColorOutput "Target Resource Group: $ResourceGroup" -Color White
    Write-ColorOutput "Target Location: $Location" -Color White
    Write-ColorOutput "Naming Prefix: $NamingPrefix" -Color White
    Write-ColorOutput "VM Size: $VmSize" -Color White
    Write-ColorOutput "Deploy Bastion: $DeployBastion" -Color White
    
    if ($DryRun) {
        Write-ColorOutput "DRY RUN MODE - No actual resources will be created" -Color Yellow
    } else {
        Write-ColorOutput "WARNING: This deployment can be expensive and take 60-90 minutes to complete" -Color Red
    }

    # Validate Azure login
    if (-not (Test-AzureLogin)) {
        exit 1
    }

    # Get admin password
    $WinAdminPassword = Get-AdminPassword

    # Select subscription
    if ($DryRun) {
        Write-ColorOutput "Would select Azure subscription: $SubscriptionId" -Color Cyan
    } else {
        try {
            $selectedSub = Select-AzSubscription -SubscriptionId $SubscriptionId
            Write-ColorOutput "Selected subscription: $($selectedSub.Subscription.Name)" -Color Green
        }
        catch {
            Write-Error "Failed to select subscription '$SubscriptionId': $($_.Exception.Message)"
            exit 1
        }
    }

    # Provider registrations (best effort)
    Write-ColorOutput "Checking Azure resource provider registrations..." -Color Yellow
    
    $providers = @(
        "Microsoft.Compute", "Microsoft.Network", "Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.ManagedIdentity",
        "Microsoft.Automation", "Microsoft.OperationalInsights", "Microsoft.Monitor",
        "Microsoft.HybridCompute", "Microsoft.Kubernetes", "Microsoft.KubernetesConfiguration", "Microsoft.ExtendedLocation"
    )

    if ($DryRun) {
        Write-ColorOutput "Would check and register the following providers if needed:" -Color Cyan
        foreach ($provider in $providers) {
            Write-ColorOutput "  - $provider" -Color White
        }
    } else {
        foreach ($provider in $providers) {
            try {
                $rp = Get-AzResourceProvider -ProviderNamespace $provider
                if ($rp.RegistrationState -ne "Registered") {
                    Write-ColorOutput "Registering provider: $provider" -Color Yellow
                    Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
                } else {
                    Write-ColorOutput "Provider already registered: $provider" -Color Green
                }
            }
            catch {
                Write-Warning "Failed to register provider $provider : $($_.Exception.Message)"
            }
        }
    }

    # Resource group
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

    # Parameters for Bicep template
    Write-ColorOutput "Preparing deployment parameters..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would use the following deployment parameters:" -Color Cyan
        Write-ColorOutput "  - Location: $Location" -Color White
        Write-ColorOutput "  - Naming Prefix: $NamingPrefix" -Color White
        Write-ColorOutput "  - VM Size: $VmSize" -Color White
        Write-ColorOutput "  - Admin Username: $WinAdminUser" -Color White
        Write-ColorOutput "  - Deploy Bastion: $DeployBastion" -Color White
        Write-ColorOutput "  - RDP Port: $RdpPort" -Color White
        Write-ColorOutput "  - VM Autologon: $VmAutologon" -Color White
        Write-ColorOutput "  - Template URI: $TemplateUri" -Color White
    } else {
        # Convert SecureString to plain text for template parameter
        $PlainPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($WinAdminPassword))
        
        $Params = @{
            location              = $Location
            namingPrefix          = $NamingPrefix
            vmSize                = $VmSize
            windowsAdminUsername  = $WinAdminUser
            windowsAdminPassword  = $PlainPwd
            deployBastion         = $DeployBastion
            rdpPort               = $RdpPort
            vmAutologon           = $VmAutologon
        }
    }

    # Deployment
    Write-ColorOutput "Starting LocalBox Bicep deployment..." -Color Yellow
    
    if ($DryRun) {
        Write-ColorOutput "Would deploy LocalBox using Bicep template" -Color Cyan
        Write-ColorOutput "Template: $TemplateUri" -Color Cyan
        Write-ColorOutput "Deployment would be named: localbox-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Color Cyan
        Write-ColorOutput "Estimated deployment time: 60-90 minutes" -Color Yellow
    } else {
        try {
            $deploymentName = "localbox-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Write-ColorOutput "Deployment name: $deploymentName" -Color White
            Write-ColorOutput "This may take 60-90 minutes to complete..." -Color Yellow
            
            $deployment = New-AzResourceGroupDeployment `
                -ResourceGroupName $ResourceGroup `
                -TemplateUri $TemplateUri `
                -TemplateParameterObject $Params `
                -Name $deploymentName `
                -Mode Incremental `
                -Verbose

            if ($deployment.ProvisioningState -eq "Succeeded") {
                Write-ColorOutput "Deployment completed successfully!" -Color Green
            } elseif ($deployment.ProvisioningState -eq "Accepted") {
                Write-ColorOutput "Deployment accepted and is running in the background" -Color Green
            } else {
                Write-Warning "Deployment returned state: $($deployment.ProvisioningState). Check errors above or in portal."
            }
        }
        catch {
            Write-Error "Deployment failed: $($_.Exception.Message)"
            exit 1
        }
    }

    # Display deployment summary
    Write-ColorOutput "`n=== Deployment Summary ===" -Color Cyan
    
    if ($DryRun) {
        Write-ColorOutput "DRY RUN COMPLETED - LocalBox deployment that would be created:" -Color Yellow
        Write-ColorOutput "- Resource Group: $ResourceGroup" -Color White
        Write-ColorOutput "- Location: $Location" -Color White
        Write-ColorOutput "- Naming Prefix: $NamingPrefix" -Color White
        Write-ColorOutput "- VM Size: $VmSize" -Color White
        Write-ColorOutput "- Admin User: $WinAdminUser" -Color White
        Write-ColorOutput "- Bastion Enabled: $DeployBastion" -Color White
        Write-ColorOutput "- Template: $TemplateUri" -Color White
        Write-ColorOutput "`nEstimated monthly cost: $800-1500 USD (depending on usage and region)" -Color Yellow
        Write-ColorOutput "To deploy for real, run the script again without the -DryRun parameter" -Color Yellow
    } else {
        Write-ColorOutput "LOCALBOX DEPLOYMENT INITIATED!" -Color Green
        
        # Portal links
        $rg = Get-AzResourceGroup -Name $ResourceGroup
        $portalRgUrl = "https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups/resourceType/Microsoft.Resources%2FResourceGroups"
        $portalDeploymentsUrl = "https://portal.azure.com/#view/HubsExtension/DeploymentDetailsBlade/~/overview"

        Write-ColorOutput "`nResource Group: $($rg.ResourceGroupName) | Location: $Location" -Color White
        Write-ColorOutput "Portal - Resource Groups: $portalRgUrl" -Color White
        Write-ColorOutput "Portal - Deployments (open from the RG): $portalDeploymentsUrl" -Color White
        
        Write-ColorOutput "`nIMPORTANT NEXT STEPS:" -Color Yellow
        Write-ColorOutput "1. Monitor the deployment in the Azure portal (60-90 minutes expected)" -Color White
        Write-ColorOutput "2. Once Bicep deployment completes, RDP/Bastion to the LocalBox client VM" -Color White
        Write-ColorOutput "3. Allow the managed identity and automated scripts to finish configuration" -Color White
        Write-ColorOutput "4. The LocalBox environment will be ready for Azure Stack HCI testing" -Color White
        
        Write-ColorOutput "`nCOST WARNING: Remember to clean up resources when done testing!" -Color Red
    }
}
catch {
    Write-Error "LocalBox deployment failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
