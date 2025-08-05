
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('true','false')]
    [string]$CreateAS2Role,
    [Parameter(Mandatory)]
    [ValidateSet('us-east-1','us-west-2','eu-west-1','ap-southeast-1','ap-northeast-2')]
    [string]$Region,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$VpcCidr,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$PublicSubnetCidr,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$PrivateSubnet1Cidr,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$PrivateSubnet2Cidr
)

$ErrorActionPreference = 'Stop'
try {
    # AZ Mapping (minimal subset)
    $RegionMap = @{
        "us-east-1"       = @{ az1 = "use1-az2"; az2 = "use1-az4" }
        "us-west-2"       = @{ az1 = "usw2-az1"; az2 = "usw2-az2" }
        "eu-west-1"       = @{ az1 = "euw1-az1"; az2 = "euw1-az2" }
        "ap-southeast-1"  = @{ az1 = "apse1-az1"; az2 = "apse1-az2" }
        "ap-northeast-2"  = @{ az1 = "apne2-az1"; az2 = "apne2-az3" }
    }

    $AZ1 = $RegionMap[$Region].az1
    $AZ2 = $RegionMap[$Region].az2

    # --- IAM Role for AppStream Service Access ---
    if ($CreateAS2Role -eq "true") {
        $AssumeRolePolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "appstream.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
"@

        New-IAMRole -RoleName "AmazonAppStreamServiceAccess" `
            -AssumeRolePolicyDocument $AssumeRolePolicy `
            -Path "/service-role/" `
            -MaxSessionDuration 3600 | Out-Null

        Register-IAMRolePolicy -RoleName "AmazonAppStreamServiceAccess" `
            -PolicyArn "arn:aws:iam::aws:policy/service-role/AmazonAppStreamServiceAccess"
        Write-Host "Created and registered IAM role for AppStream Service Access."
    }

    # --- Networking ---
    $vpc = New-EC2Vpc -CidrBlock $VpcCidr `
        -TagSpecification @{ ResourceType = 'vpc'; Tags = @{ Key = 'Name'; Value = 'AppStream 2.0 VPC' } }
    Write-Host "Created VPC: $($vpc.VpcId)"

    $igw = New-EC2InternetGateway -TagSpecification @{ ResourceType = "internet-gateway"; Tags = @{ Key = "Name"; Value = "AppStream2 IGW" } }
    Add-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -VpcId $vpc.VpcId
    Write-Host "Created and attached Internet Gateway: $($igw.InternetGatewayId)"

    $publicSubnet = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $PublicSubnetCidr -AvailabilityZoneId $AZ1 `
        -TagSpecification @{ ResourceType = "subnet"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 public subnet" } }
    Write-Host "Created public subnet: $($publicSubnet.SubnetId)"

    $privateSubnet1 = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $PrivateSubnet1Cidr -AvailabilityZoneId $AZ1 `
        -TagSpecification @{ ResourceType = "subnet"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 private subnet 1" } }
    Write-Host "Created private subnet 1: $($privateSubnet1.SubnetId)"

    $privateSubnet2 = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $PrivateSubnet2Cidr -AvailabilityZoneId $AZ2 `
        -TagSpecification @{ ResourceType = "subnet"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 private subnet 2" } }
    Write-Host "Created private subnet 2: $($privateSubnet2.SubnetId)"

    $eip = New-EC2Address -Domain vpc
    $nat = New-EC2NatGateway -SubnetId $publicSubnet.SubnetId -AllocationId $eip.AllocationId `
        -TagSpecification @{ ResourceType = "natgateway"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 NAT gateway" } }
    Write-Host "Created NAT Gateway: $($nat.NatGatewayId)"

    # Route Tables
    $publicRT = New-EC2RouteTable -VpcId $vpc.VpcId -TagSpecification @{ ResourceType = "route-table"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 public route table" } }
    New-EC2Route -RouteTableId $publicRT.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -GatewayId $igw.InternetGatewayId
    Register-EC2RouteTableAssociation -SubnetId $publicSubnet.SubnetId -RouteTableId $publicRT.RouteTableId
    Write-Host "Configured public route table."

    $privateRT = New-EC2RouteTable -VpcId $vpc.VpcId -TagSpecification @{ ResourceType = "route-table"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 private route table" } }
    New-EC2Route -RouteTableId $privateRT.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -NatGatewayId $nat.NatGatewayId
    Register-EC2RouteTableAssociation -SubnetId $privateSubnet1.SubnetId -RouteTableId $privateRT.RouteTableId
    Register-EC2RouteTableAssociation -SubnetId $privateSubnet2.SubnetId -RouteTableId $privateRT.RouteTableId
    Write-Host "Configured private route table."

    # --- Lambda Role for DescribeImages ---
    $lambdaAssume = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
"@
    $lambdaPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "appstream:DescribeImages",
    "Resource": "*"
  }]
}
"@

    New-IAMRole -RoleName "iamLambdaExecutionRoleGetImage" `
      -AssumeRolePolicyDocument $lambdaAssume `
      -Path "/service-role/" -MaxSessionDuration 3600 | Out-Null

    Register-IAMRolePolicy -RoleName "iamLambdaExecutionRoleGetImage" `
      -PolicyArn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

    Register-IAMRolePolicy -RoleName "iamLambdaExecutionRoleGetImage" `
      -PolicyName "describe-as2-images" `
      -PolicyDocument $lambdaPolicy
    Write-Host "Created and registered Lambda execution role for DescribeImages."

    # --- Get Latest Image via Lambda (manual simulation) ---
    $appstreamClient = Initialize-AWSDefaultConfiguration -Region $Region
    $images = Get-APSImage -Type PUBLIC
    $windowsImages = $images.Images | Where-Object { $_.Platform -eq "WINDOWS_SERVER_2022" }
    $generalPurpose = $windowsImages | Where-Object { $_.Description -notmatch 'Graphics|Design' } | Sort-Object -Property CreatedTime -Descending
    $latestImage = $generalPurpose[0].Name
    Write-Host "Latest general purpose Windows Server 2022 image: $latestImage"

    # --- AppStream Image Builder ---
    New-APSImageBuilder -Name "AS2_Lab_ImageBuilder" `
      -ImageName $latestImage `
      -InstanceType "stream.standard.medium" `
      -AppstreamAgentVersion "LATEST" `
      -EnableDefaultInternetAccess $false `
      -DisplayName "Image Builder" `
      -Description "Image builder for AppStream 2.0 hands-on lab" `
      -VpcConfig_SubnetIds $privateSubnet1.SubnetId
    Write-Host "Created AppStream Image Builder."
    Write-Host "AppStream 2.0 quickstart completed successfully."
} catch {
    Write-Error "AppStream 2.0 quickstart failed: $_"
    exit 1
}

# AZ Mapping (minimal subset)
$RegionMap = @{
    "us-east-1"       = @{ az1 = "use1-az2"; az2 = "use1-az4" }
    "us-west-2"       = @{ az1 = "usw2-az1"; az2 = "usw2-az2" }
    "eu-west-1"       = @{ az1 = "euw1-az1"; az2 = "euw1-az2" }
    "ap-southeast-1"  = @{ az1 = "apse1-az1"; az2 = "apse1-az2" }
    "ap-northeast-2"  = @{ az1 = "apne2-az1"; az2 = "apne2-az3" }
}

$AZ1 = $RegionMap[$Region].az1
$AZ2 = $RegionMap[$Region].az2

# --- IAM Role for AppStream Service Access ---
if ($CreateAS2Role -eq "true") {
    $AssumeRolePolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "appstream.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
"@

    New-IAMRole -RoleName "AmazonAppStreamServiceAccess" `
        -AssumeRolePolicyDocument $AssumeRolePolicy `
        -Path "/service-role/" `
        -MaxSessionDuration 3600 | Out-Null

    Register-IAMRolePolicy -RoleName "AmazonAppStreamServiceAccess" `
        -PolicyArn "arn:aws:iam::aws:policy/service-role/AmazonAppStreamServiceAccess"
}

# --- Networking ---

$vpc = New-EC2Vpc -CidrBlock $VpcCidr `
    -TagSpecification @{ ResourceType = 'vpc'; Tags = @{ Key = 'Name'; Value = 'AppStream 2.0 VPC' } }

$igw = New-EC2InternetGateway -TagSpecification @{ ResourceType = "internet-gateway"; Tags = @{ Key = "Name"; Value = "AppStream2 IGW" } }
Add-EC2InternetGateway -InternetGatewayId $igw.InternetGatewayId -VpcId $vpc.VpcId


$publicSubnet = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $PublicSubnetCidr -AvailabilityZoneId $AZ1 `
    -TagSpecification @{ ResourceType = "subnet"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 public subnet" } }

$privateSubnet1 = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $PrivateSubnet1Cidr -AvailabilityZoneId $AZ1 `
    -TagSpecification @{ ResourceType = "subnet"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 private subnet 1" } }

$privateSubnet2 = New-EC2Subnet -VpcId $vpc.VpcId -CidrBlock $PrivateSubnet2Cidr -AvailabilityZoneId $AZ2 `
    -TagSpecification @{ ResourceType = "subnet"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 private subnet 2" } }

$eip = New-EC2Address -Domain vpc
$nat = New-EC2NatGateway -SubnetId $publicSubnet.SubnetId -AllocationId $eip.AllocationId `
    -TagSpecification @{ ResourceType = "natgateway"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 NAT gateway" } }

# Route Tables
$publicRT = New-EC2RouteTable -VpcId $vpc.VpcId -TagSpecification @{ ResourceType = "route-table"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 public route table" } }
New-EC2Route -RouteTableId $publicRT.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -GatewayId $igw.InternetGatewayId
Register-EC2RouteTableAssociation -SubnetId $publicSubnet.SubnetId -RouteTableId $publicRT.RouteTableId

$privateRT = New-EC2RouteTable -VpcId $vpc.VpcId -TagSpecification @{ ResourceType = "route-table"; Tags = @{ Key = "Name"; Value = "AppStream 2.0 private route table" } }
New-EC2Route -RouteTableId $privateRT.RouteTableId -DestinationCidrBlock "0.0.0.0/0" -NatGatewayId $nat.NatGatewayId
Register-EC2RouteTableAssociation -SubnetId $privateSubnet1.SubnetId -RouteTableId $privateRT.RouteTableId
Register-EC2RouteTableAssociation -SubnetId $privateSubnet2.SubnetId -RouteTableId $privateRT.RouteTableId

# --- Lambda Role for DescribeImages ---
$lambdaAssume = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
"@
$lambdaPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "appstream:DescribeImages",
    "Resource": "*"
  }]
}
"@

New-IAMRole -RoleName "iamLambdaExecutionRoleGetImage" `
  -AssumeRolePolicyDocument $lambdaAssume `
  -Path "/service-role/" -MaxSessionDuration 3600 | Out-Null

Register-IAMRolePolicy -RoleName "iamLambdaExecutionRoleGetImage" `
  -PolicyArn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

Register-IAMRolePolicy -RoleName "iamLambdaExecutionRoleGetImage" `
  -PolicyName "describe-as2-images" `
  -PolicyDocument $lambdaPolicy

# You will need to ZIP your inline lambda function as code
# and upload it manually or through `Publish-LMFunction` if needed.
# Here, we assume it has already been created and available.

# --- Get Latest Image via Lambda (manual simulation) ---
$appstreamClient = Initialize-AWSDefaultConfiguration -Region $Region
$images = Get-APSImage -Type PUBLIC
$windowsImages = $images.Images | Where-Object { $_.Platform -eq "WINDOWS_SERVER_2022" }
$generalPurpose = $windowsImages | Where-Object { $_.Description -notmatch 'Graphics|Design' } | Sort-Object -Property CreatedTime -Descending
$latestImage = $generalPurpose[0].Name

# --- AppStream Image Builder ---
New-APSImageBuilder -Name "AS2_Lab_ImageBuilder" `
  -ImageName $latestImage `
  -InstanceType "stream.standard.medium" `
  -AppstreamAgentVersion "LATEST" `
  -EnableDefaultInternetAccess $false `
  -DisplayName "Image Builder" `
  -Description "Image builder for AppStream 2.0 hands-on lab" `
  -VpcConfig_SubnetIds $privateSubnet1.SubnetId
  