
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('eu-central-1','us-east-1','us-west-2','eu-west-1')]
    [string]$Region,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$VpcCidr,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Subnet1Cidr,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Subnet2Cidr,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9.-]+$')]
    [string]$DirectoryName,
    [Parameter(Mandatory)]
    [System.Security.SecureString]$AdminPassword,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9]+$')]
    [string]$DirectoryShortName,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$WorkspaceUser,
    [Parameter(Mandatory)]
    [System.Security.SecureString]$WorkspacePassword,
    [Parameter(Mandatory)]
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
    $subnet1 = New-EC2Subnet -VpcId $VpcId -CidrBlock $Subnet1Cidr -AvailabilityZone "$Region"a"
    $subnet2 = New-EC2Subnet -VpcId $VpcId -CidrBlock $Subnet2Cidr -AvailabilityZone "$Region"b"

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
} catch {
    Write-Error "Workspace quickstart failed: $_"
    exit 1
}

# Create VPC
$vpc = New-EC2Vpc -CidrBlock $vpcCidr -AmazonProvidedIpv6CidrBlock $false
$VpcId = $vpc.VpcId
Write-Host "Created VPC: $VpcId"

# Tag the VPC
New-EC2Tag -Resources $VpcId -Tags @{Key="Name";Value="WorkSpacesVPC"}

# Create Subnets
$subnet1 = New-EC2Subnet -VpcId $VpcId -CidrBlock $subnet1Cidr -AvailabilityZone "$region"a""
$subnet2 = New-EC2Subnet -VpcId $VpcId -CidrBlock $subnet2Cidr -AvailabilityZone "$region"b""

# Create Internet Gateway and attach to VPC
$igw = New-EC2InternetGateway
Attach-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -VpcId $VpcId

# Create Security Group
$sg = New-EC2SecurityGroup -GroupName "WorkSpacesSG" -Description "Security group for WorkSpaces" -VpcId $VpcId
$sgId = $sg.GroupId

# Allow RDP and Directory traffic
Grant-EC2SecurityGroupIngress -GroupId $sgId -IpProtocol "tcp" -FromPort 3389 -ToPort 3389 -Cidr "0.0.0.0/0"
Grant-EC2SecurityGroupIngress -GroupId $sgId -IpProtocol "tcp" -FromPort 389 -ToPort 389 -Cidr "0.0.0.0/0"

# Create Simple AD Directory
$directory = Register-SWDDirectory -DirectoryName $directoryName `
    -Password $adminPassword `
    -Size Small `
    -VpcSettings_SubnetIds @($subnet1.SubnetId, $subnet2.SubnetId) `
    -VpcSettings_VpcId $VpcId `
    -DirectoryShortName $directoryShortName `
    -Region $region
$directoryId = $directory.DirectoryId
Write-Host "Created Directory: $directoryId"

# Wait until directory is active
do {
    Start-Sleep -Seconds 30
    $dirStatus = (Get-SWDDirectory -DirectoryId $directoryId).State
    Write-Host "Directory Status: $dirStatus"
} while ($dirStatus -ne "Registered")

# Create WorkSpaces user
New-WKSUser -DirectoryId $directoryId -UserName $workspaceUser -Password $workspacePassword

# Launch WorkSpace
$workspace = New-WKSWorkspace -DirectoryId $directoryId `
    -UserName $workspaceUser `
    -BundleId "wsb-bh8rsxt14" `  # Replace with desired bundle ID
    -WorkspaceProperties_ComputeTypeName VALUE `
    -WorkspaceProperties_RootVolumeSizeGib 80 `
    -WorkspaceProperties_UserVolumeSizeGib 10

Write-Host "Workspace launched: $($workspace.WorkspaceId)"
