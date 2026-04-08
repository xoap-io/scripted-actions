<#
.SYNOPSIS
    Quickstart for deploying an AWS WorkSpace with VPC, directory, and user setup.

.DESCRIPTION
    This script creates a complete AWS WorkSpaces environment including VPC, subnets, internet gateway, security group,
    Simple AD directory, a WorkSpaces user, and a WorkSpace. Uses New-EC2Vpc, New-EC2Subnet, New-EC2InternetGateway,
    New-EC2SecurityGroup, Grant-EC2SecurityGroupIngress, Register-SWDDirectory, New-WKSUser, and New-WKSWorkspace
    from AWS.Tools.EC2, AWS.Tools.SimpleAD, and AWS.Tools.WorkSpaces.

.PARAMETER Region
    The AWS region to deploy resources in.

.PARAMETER VpcCidr
    The CIDR block for the VPC (e.g. 10.0.0.0/16).

.PARAMETER Subnet1Cidr
    The CIDR block for the first subnet (e.g. 10.0.1.0/24).

.PARAMETER Subnet2Cidr
    The CIDR block for the second subnet (e.g. 10.0.2.0/24).

.PARAMETER DirectoryName
    The fully qualified domain name for the Simple AD directory (e.g. corp.example.com).

.PARAMETER AdminPassword
    The administrator password for the Simple AD directory as a SecureString.

.PARAMETER DirectoryShortName
    The NetBIOS short name for the directory (e.g. CORP).

.PARAMETER WorkspaceUser
    The user name for the WorkSpace user.

.PARAMETER WorkspacePassword
    The password for the WorkSpace user as a SecureString.

.PARAMETER BundleId
    The bundle ID to use for the WorkSpace (e.g. wsb-bh8rsxt14).

.EXAMPLE
    .\workspace-quickstart1.ps1 -Region eu-central-1 -VpcCidr 10.0.0.0/16 -Subnet1Cidr 10.0.1.0/24 -Subnet2Cidr 10.0.2.0/24 -DirectoryName corp.example.com -AdminPassword (Read-Host -AsSecureString) -DirectoryShortName CORP -WorkspaceUser jdoe -WorkspacePassword (Read-Host -AsSecureString) -BundleId wsb-bh8rsxt14

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.EC2, AWS.Tools.SimpleAD, AWS.Tools.WorkSpaces

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region to deploy resources in (e.g. eu-central-1).")]
    [ValidateSet('eu-central-1','us-east-1','us-west-2','eu-west-1')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The CIDR block for the VPC (e.g. 10.0.0.0/16).")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$VpcCidr,

    [Parameter(Mandatory = $true, HelpMessage = "The CIDR block for the first subnet (e.g. 10.0.1.0/24).")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Subnet1Cidr,

    [Parameter(Mandatory = $true, HelpMessage = "The CIDR block for the second subnet (e.g. 10.0.2.0/24).")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Subnet2Cidr,

    [Parameter(Mandatory = $true, HelpMessage = "The fully qualified domain name for the Simple AD directory (e.g. corp.example.com).")]
    [ValidatePattern('^[a-zA-Z0-9.-]+$')]
    [string]$DirectoryName,

    [Parameter(Mandatory = $true, HelpMessage = "The administrator password for the Simple AD directory as a SecureString.")]
    [System.Security.SecureString]$AdminPassword,

    [Parameter(Mandatory = $true, HelpMessage = "The NetBIOS short name for the directory (e.g. CORP).")]
    [ValidatePattern('^[a-zA-Z0-9]+$')]
    [string]$DirectoryShortName,

    [Parameter(Mandatory = $true, HelpMessage = "The user name for the WorkSpace user (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$WorkspaceUser,

    [Parameter(Mandatory = $true, HelpMessage = "The password for the WorkSpace user as a SecureString.")]
    [System.Security.SecureString]$WorkspacePassword,

    [Parameter(Mandatory = $true, HelpMessage = "The bundle ID to use for the WorkSpace (e.g. wsb-bh8rsxt14).")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating VPC..." -ForegroundColor Cyan
    $vpc = New-EC2Vpc -CidrBlock $VpcCidr -AmazonProvidedIpv6CidrBlock $false
    $VpcId = $vpc.VpcId
    Write-Host "Created VPC: $VpcId" -ForegroundColor Green

    New-EC2Tag -Resources $VpcId -Tags @{Key="Name";Value="WorkSpacesVPC"}

    Write-Host "Creating subnets..." -ForegroundColor Cyan
    $subnet1 = New-EC2Subnet -VpcId $VpcId -CidrBlock $Subnet1Cidr -AvailabilityZone "${Region}a"
    $subnet2 = New-EC2Subnet -VpcId $VpcId -CidrBlock $Subnet2Cidr -AvailabilityZone "${Region}b"

    Write-Host "Creating and attaching Internet Gateway..." -ForegroundColor Cyan
    $igw = New-EC2InternetGateway
    Attach-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -VpcId $VpcId

    Write-Host "Creating Security Group..." -ForegroundColor Cyan
    $sg = New-EC2SecurityGroup -GroupName "WorkSpacesSG" -Description "Security group for WorkSpaces" -VpcId $VpcId
    $sgId = $sg.GroupId

    Grant-EC2SecurityGroupIngress -GroupId $sgId -IpProtocol "tcp" -FromPort 3389 -ToPort 3389 -Cidr "0.0.0.0/0"
    Grant-EC2SecurityGroupIngress -GroupId $sgId -IpProtocol "tcp" -FromPort 389 -ToPort 389 -Cidr "0.0.0.0/0"

    Write-Host "Registering Simple AD Directory..." -ForegroundColor Cyan
    $plainAdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword))
    $directory = Register-SWDDirectory -DirectoryName $DirectoryName `
        -Password $plainAdminPassword `
        -Size Small `
        -VpcSettings_SubnetIds @($subnet1.SubnetId, $subnet2.SubnetId) `
        -VpcSettings_VpcId $VpcId `
        -DirectoryShortName $DirectoryShortName `
        -Region $Region
    $directoryId = $directory.DirectoryId
    Write-Host "Created Directory: $directoryId" -ForegroundColor Green

    Write-Host "Waiting for directory to become active..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 30
        $dirStatus = (Get-SWDDirectory -DirectoryId $directoryId).State
        Write-Host "Directory Status: $dirStatus"
    } while ($dirStatus -ne "Registered")

    Write-Host "Creating WorkSpaces user..." -ForegroundColor Cyan
    $plainWorkspacePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($WorkspacePassword))
    New-WKSUser -DirectoryId $directoryId -UserName $WorkspaceUser -Password $plainWorkspacePassword

    Write-Host "Launching WorkSpace..." -ForegroundColor Cyan
    $workspace = New-WKSWorkspace -DirectoryId $directoryId `
        -UserName $WorkspaceUser `
        -BundleId $BundleId `
        -WorkspaceProperties_ComputeTypeName VALUE `
        -WorkspaceProperties_RootVolumeSizeGib 80 `
        -WorkspaceProperties_UserVolumeSizeGib 10

    Write-Host "Workspace launched: $($workspace.WorkspaceId)" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
