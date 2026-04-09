<#
.SYNOPSIS
    Creates an EC2 launch template using AWS.Tools.EC2.

.DESCRIPTION
    This script creates an EC2 launch template using the New-EC2LaunchTemplate cmdlet
    from AWS.Tools.EC2. Launch templates enable you to save your instance configuration
    for use with Auto Scaling groups, Spot Fleet requests, and on-demand instances.
    UserData can be provided as a plain-text script or pre-encoded base64 string — the
    script detects and encodes plain text automatically.

.PARAMETER Region
    The AWS region to create the launch template in (e.g. eu-central-1).

.PARAMETER TemplateName
    The name for the new launch template.

.PARAMETER ImageId
    The ID of the AMI to use for instances launched from this template
    (e.g. ami-12345678abcdef01).

.PARAMETER InstanceType
    The EC2 instance type for instances launched from this template (e.g. t3.medium).

.PARAMETER KeyName
    Optional name of the EC2 key pair for SSH/RDP access.

.PARAMETER SecurityGroupIds
    Optional comma-separated list of security group IDs
    (e.g. "sg-12345678,sg-abcdef12").

.PARAMETER SubnetId
    Optional subnet ID to launch instances into
    (e.g. subnet-12345678abcdef01).

.PARAMETER UserData
    Optional user data script to run at instance launch. Accepts plain text or
    base64-encoded content. Plain text is automatically base64-encoded.

.PARAMETER Description
    Optional description for the launch template version.

.EXAMPLE
    .\aws-ps-create-launch-template.ps1 -Region eu-central-1 -TemplateName "WebServer-LT" -ImageId ami-12345678abcdef01 -InstanceType t3.medium
    Creates a minimal launch template with AMI and instance type.

.EXAMPLE
    .\aws-ps-create-launch-template.ps1 -Region us-east-1 -TemplateName "AppServer-LT" -ImageId ami-0abcdef1234567890 -InstanceType m5.large -KeyName mykey -SecurityGroupIds "sg-12345678,sg-abcdef12" -SubnetId subnet-12345678abcdef01 -Description "Application server template"
    Creates a launch template with full network configuration.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.EC2

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/items/New-EC2LaunchTemplate.html

.COMPONENT
    AWS PowerShell EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region to create the launch template in (e.g. eu-central-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new launch template.")]
    [ValidateNotNullOrEmpty()]
    [string]$TemplateName,

    [Parameter(Mandatory = $true, HelpMessage = "The AMI ID to use for instances launched from this template (e.g. ami-12345678abcdef01).")]
    [ValidatePattern('^ami-[a-zA-Z0-9]{8,}$')]
    [string]$ImageId,

    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance type for instances launched from this template (e.g. t3.medium).")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceType,

    [Parameter(HelpMessage = "Optional name of the EC2 key pair for SSH/RDP access.")]
    [string]$KeyName,

    [Parameter(HelpMessage = "Optional comma-separated list of security group IDs (e.g. 'sg-12345678,sg-abcdef12').")]
    [string]$SecurityGroupIds,

    [Parameter(HelpMessage = "Optional subnet ID to launch instances into (e.g. subnet-12345678abcdef01).")]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(HelpMessage = "Optional user data script to run at instance launch. Plain text is auto-encoded to base64.")]
    [string]$UserData,

    [Parameter(HelpMessage = "Optional description for the launch template version.")]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting EC2 launch template creation" -ForegroundColor Green
    Write-Host "🔍 Importing AWS.Tools.EC2 module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.EC2 -ErrorAction Stop

    # Build launch template data object
    Write-Host "🔧 Building launch template data..." -ForegroundColor Cyan
    $ltData = [Amazon.EC2.Model.RequestLaunchTemplateData]::new()
    $ltData.ImageId      = $ImageId
    $ltData.InstanceType = $InstanceType

    if ($KeyName) {
        $ltData.KeyName = $KeyName
        Write-Host "   KeyName: $KeyName" -ForegroundColor Gray
    }

    if ($SecurityGroupIds) {
        $sgList = $SecurityGroupIds -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
        foreach ($sg in $sgList) {
            $ltData.SecurityGroupId.Add($sg) | Out-Null
        }
        Write-Host "   SecurityGroupIds: $($sgList -join ', ')" -ForegroundColor Gray
    }

    if ($SubnetId) {
        $networkInterface = [Amazon.EC2.Model.LaunchTemplateInstanceNetworkInterfaceSpecificationRequest]::new()
        $networkInterface.SubnetId      = $SubnetId
        $networkInterface.DeviceIndex   = 0
        $ltData.NetworkInterface.Add($networkInterface) | Out-Null
        Write-Host "   SubnetId: $SubnetId" -ForegroundColor Gray
    }

    if ($UserData) {
        # Detect if already base64 encoded
        $isBase64 = $false
        try {
            $null = [System.Convert]::FromBase64String($UserData)
            $isBase64 = $true
        }
        catch [System.FormatException] {
            $isBase64 = $false
        }

        if ($isBase64) {
            $ltData.UserData = $UserData
            Write-Host "   UserData: provided as base64 (used as-is)" -ForegroundColor Gray
        }
        else {
            $ltData.UserData = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UserData))
            Write-Host "   UserData: plain text encoded to base64" -ForegroundColor Gray
        }
    }

    # Build creation parameters
    $createParams = @{
        LaunchTemplateName = $TemplateName
        LaunchTemplateData = $ltData
        Region             = $Region
    }
    if ($Description) {
        $createParams['VersionDescription'] = $Description
    }

    Write-Host "🔧 Creating launch template '$TemplateName'..." -ForegroundColor Cyan
    $result = New-EC2LaunchTemplate @createParams

    Write-Host "✅ Launch template created successfully." -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   LaunchTemplateId:   $($result.LaunchTemplateId)" -ForegroundColor White
    Write-Host "   LaunchTemplateName: $($result.LaunchTemplateName)" -ForegroundColor White
    Write-Host "   DefaultVersion:     $($result.DefaultVersionNumber)" -ForegroundColor White
    Write-Host "   Region:             $Region" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
