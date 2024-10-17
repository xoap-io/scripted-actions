<#
.SYNOPSIS
    Assigns a Virtual Machine (VM) to an Azure Virtual Desktop (AVD) Host Pool using a Service Principal Object (SPO).

.DESCRIPTION
    This script assigns a specified VM to a specified AVD Host Pool using Azure PowerShell cmdlets.
    It connects to Azure using a Service Principal Object (SPO) for authentication.

.PARAMETER HostPoolName
    The name of the AVD Host Pool to which the VM will be assigned.

.PARAMETER VmName
    The name of the Virtual Machine to assign.

.PARAMETER Location
    The Azure region where the VM and Host Pool are located. Default is 'West Europe'.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true)]
    [string]$VmName,

    [Parameter(Mandatory=$true)]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'bril',
        'canada', 'europe', 'france', 'germany',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brilsoutheast'
    )]
    [string]$Location = "westeurope",
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [securestring]$Password
)
# Retrieve the Host Pool
$HostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroupName -Name $HostPoolName
if (-not $HostPool) {
    Write-Error "Host Pool '$HostPoolName' not found in Resource Group '$ResourceGroupName' at location '$Location'."
    exit
}

# Create a new registration token for the Host Pool
New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -ExpirationTime (Get-Date).AddDays(1).ToString("yyyy-MM-dd 12:00")

$parameters = @{
    HostPoolName = $HostPoolName
    ResourceGroupName = $ResourceGroupName
}

$registrationkeytoken = (Get-AzWvdHostPoolRegistrationToken @parameters).Token

$ScriptBlock = {
    param(
        [string] $RegistrationKeyToken,
        [string] $VmName,
        [securestring] $Password
    )
    # Define constants for URLs and file paths
    $agentUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
    $bootLoaderUrl = 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
    $tempDirectory = "C:\Temp"
    $agentInstallerPath = Join-Path -Path $tempDirectory -ChildPath "Microsoft.RDInfra.RDAgent.Installer-x64.msi"
    $bootLoaderInstallerPath = Join-Path -Path $tempDirectory -ChildPath "Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi"
    $domainUser = "s.sokolic@ris.ag"
    $domain = $domainUser.Split("@")[-1]
    $ouPath = "OU=Computers,OU=AVD,DC=domain,DC=local"
    $VmName = $VmName

    # Existing product names to check for
    $agentProductName = 'Remote Desktop Services Infrastructure Agent'
    $bootLoaderProductName = 'Remote Desktop Agent Boot Loader'

    # Create a Temp directory if it doesn't exist
    if (-Not (Test-Path -Path $tempDirectory)) {
        New-Item -ItemType Directory -Path $tempDirectory | Out-Null
    }

    # Uninstall existing packages if they are installed
    function Uninstall-Package($productName) {
        try {
            $product = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name = '$productName'"
            if ($null -ne $product) {
                Write-Host "Uninstalling $productName..."
                $product.Uninstall() | Out-Null
                Write-Host "$productName uninstalled successfully."
            } else {
                Write-Host "$productName is not installed."
            }
        } catch {
            Write-Host "Error uninstalling $productName $_" -ForegroundColor Red
            throw
        }
    }

    # Download and install VDA Agent and Boot Loader
    function Get-File($url, $outputPath) {
        try {
            Write-Host "Downloading from $url..."
            Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
            Unblock-File -Path $outputPath
            Write-Host "Downloaded $outputPath successfully."
        } catch {
            Write-Host "Error downloading file from $url $_" -ForegroundColor Red
            throw
        }
    }

    function Install-Package($installerPath, $arguments) {
        try {
            Write-Host "Installing package from $installerPath..."
            Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -Verbose
            Write-Host "Installation completed for $installerPath."
        } catch {
            Write-Host "Error installing package from $installerPath $_" -ForegroundColor Red
            throw
        }
    }

    try {
        # Uninstall existing installations if needed
        Uninstall-Package -ProductName $agentProductName
        Uninstall-Package -ProductName $bootLoaderProductName

        # Download installers
        Get-File -Url $agentUrl -OutputPath $agentInstallerPath
        Get-File -Url $bootLoaderUrl -OutputPath $bootLoaderInstallerPath

        # Install VDA Agent
        $vdaAgentArgs = "/i `"$agentInstallerPath`" /quiet /norestart REGISTRATIONTOKEN=$RegistrationKeyToken"
        Install-Package -InstallerPath $agentInstallerPath -Arguments $vdaAgentArgs

        # Install Boot Loader
        $bootLoaderArgs = "/i `"$bootLoaderInstallerPath`" /quiet /norestart"
        Install-Package -InstallerPath $bootLoaderInstallerPath -Arguments $bootLoaderArgs

        $domainJoinSettings = @{
            Name                   = "joindomain"
            Type                   = "JsonADDomainExtension" 
            Publisher              = "Microsoft.Compute"
            typeHandlerVersion     = "1.3"
            SettingString          = '{
                "name": "'+ $($domain) + '",
                "ouPath": "'+ $($ouPath) + '",
                "user": "'+ $($domainUser) + '",
                "restart": "'+ $true + '",
                "options": 3
            }'
            ProtectedSettingString = '{
            "password":"' + $(Get-AzKeyVaultSecret -VaultName "keyvault-test4353768787" -Name "VMjoin" -AsPlainText) + '"}'
            
            VMName                 = $VMName
            ResourceGroupName      = $resourceGroupName
            location               = $Location
        }
        Set-AzVMExtension @domainJoinSettings
    
        $avdDscSettings = @{
            Name               = "Microsoft.PowerShell.DSC"
            Type               = "DSC" 
            Publisher          = "Microsoft.Powershell"
            typeHandlerVersion = "2.73"
            SettingString      = "{
                ""modulesUrl"":'$avdModuleLocation',
                ""ConfigurationFunction"":""Configuration.ps1\\AddSessionHost"",
                ""Properties"": {
                    ""hostPoolName"": ""$($fileParameters.avdSettings.avdHostpool.Name)"",
                    ""registrationInfoToken"": ""$($registrationToken.token)"",
                    ""aadJoin"": true
                }
            }"
            VMName             = $VMName
            ResourceGroupName  = $resourceGroupName
            location           = $Location
        }
        Set-AzVMExtension @avdDscSettings  

        Write-Host "All installations complete."
    }

    catch {
        Write-Host "An error occurred during the installation process: $_" -ForegroundColor Red
        throw
    }
}

try {
    # Run script on the VM
    Write-Host "Running script on $VmName..."
    $Script = [scriptblock]::create($ScriptBlock)
    $cmdRes = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName $VmName -CommandId 'RunPowerShellScript' -ScriptString $Script -Parameter @{'RegistrationKeyToken' = $registrationkeytoken;}
    $cmdRes.Value | ForEach-Object { Write-Host $_.Message }
    Write-Host "Script execution completed on $VmName."
} 
catch {
    Write-Host "An error occurred while running the script on $VmName $_" -ForegroundColor Red
    throw
}
