<#
.SYNOPSIS
    Create EC2 Launch Template using AWS CLI.

.DESCRIPTION
    This script creates EC2 Launch Templates for consistent instance deployment with
    support for latest AMI selection, user data, security groups, and instance profiles.

.PARAMETER LaunchTemplateName
    The name for the launch template.

.PARAMETER VersionDescription
    Description for this version of the launch template.

.PARAMETER AmiId
    The AMI ID to use (can use 'latest' for latest Amazon Linux 2).

.PARAMETER InstanceType
    The instance type for the launch template.

.PARAMETER KeyName
    The key pair name for SSH access.

.PARAMETER SecurityGroupIds
    Comma-separated list of security group IDs.

.PARAMETER SubnetId
    The subnet ID (optional - can be specified at launch time).

.PARAMETER IamInstanceProfile
    The IAM instance profile name or ARN.

.PARAMETER UserDataFile
    Path to file containing user data script.

.PARAMETER UserDataBase64
    Base64-encoded user data string.

.PARAMETER EbsOptimized
    Enable EBS optimization.

.PARAMETER Monitoring
    Enable detailed CloudWatch monitoring.

.PARAMETER DisableApiTermination
    Enable termination protection.

.PARAMETER InstanceInitiatedShutdownBehavior
    Shutdown behavior (stop or terminate).

.PARAMETER Tags
    JSON string of tags to apply to instances launched from this template.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-create-launch-template.ps1 -LaunchTemplateName "WebServer-Template" -AmiId "ami-12345678" -InstanceType "t3.micro" -KeyName "my-key"

.EXAMPLE
    .\aws-cli-create-launch-template.ps1 -LaunchTemplateName "App-Template" -AmiId "latest" -InstanceType "t3.small" -SecurityGroupIds "sg-123,sg-456" -UserDataFile "C:\scripts\userdata.sh"

.NOTES
    Author: XOAP
    Date: 2025-08-06
    Version: 1.0
    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateLength(3, 128)]
    [string]$LaunchTemplateName,

    [Parameter(Mandatory = $false)]
    [string]$VersionDescription,

    [Parameter(Mandatory = $true)]
    [string]$AmiId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('t2.nano','t2.micro','t2.small','t2.medium','t2.large','t2.xlarge','t2.2xlarge',
                't3.nano','t3.micro','t3.small','t3.medium','t3.large','t3.xlarge','t3.2xlarge',
                't3a.nano','t3a.micro','t3a.small','t3a.medium','t3a.large','t3a.xlarge','t3a.2xlarge',
                'm5.large','m5.xlarge','m5.2xlarge','m5.4xlarge','m5.8xlarge','m5.12xlarge','m5.16xlarge','m5.24xlarge',
                'm5a.large','m5a.xlarge','m5a.2xlarge','m5a.4xlarge','m5a.8xlarge','m5a.12xlarge','m5a.16xlarge','m5a.24xlarge',
                'c5.large','c5.xlarge','c5.2xlarge','c5.4xlarge','c5.9xlarge','c5.12xlarge','c5.18xlarge','c5.24xlarge',
                'r5.large','r5.xlarge','r5.2xlarge','r5.4xlarge','r5.8xlarge','r5.12xlarge','r5.16xlarge','r5.24xlarge')]
    [string]$InstanceType,

    [Parameter(Mandatory = $false)]
    [string]$KeyName,

    [Parameter(Mandatory = $false)]
    [string]$SecurityGroupIds,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false)]
    [string]$IamInstanceProfile,

    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$UserDataFile,

    [Parameter(Mandatory = $false)]
    [string]$UserDataBase64,

    [Parameter(Mandatory = $false)]
    [switch]$EbsOptimized,

    [Parameter(Mandatory = $false)]
    [switch]$Monitoring,

    [Parameter(Mandatory = $false)]
    [switch]$DisableApiTermination,

    [Parameter(Mandatory = $false)]
    [ValidateSet('stop', 'terminate')]
    [string]$InstanceInitiatedShutdownBehavior = 'stop',

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    # Build base AWS CLI arguments
    $awsArgs = @()
    if ($Region) { $awsArgs += @('--region', $Region) }
    if ($Profile) { $awsArgs += @('--profile', $Profile) }

    Write-Output "Creating Launch Template: $LaunchTemplateName"

    # Resolve AMI ID if 'latest' is specified
    $resolvedAmiId = $AmiId
    if ($AmiId -eq 'latest') {
        Write-Output "Resolving latest Amazon Linux 2 AMI..."
        
        $amiArgs = @('ec2', 'describe-images', 
                    '--owners', 'amazon',
                    '--filters', 'Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2',
                              'Name=state,Values=available',
                    '--query', 'Images | sort_by(@, &CreationDate) | [-1].ImageId',
                    '--output', 'text')
        $amiArgs += $awsArgs
        
        $latestAmi = & aws @amiArgs 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $latestAmi -match '^ami-') {
            $resolvedAmiId = $latestAmi.Trim()
            Write-Output "Latest AMI resolved to: $resolvedAmiId"
        } else {
            throw "Failed to resolve latest AMI: $latestAmi"
        }
    }

    # Verify AMI exists
    Write-Output "Verifying AMI: $resolvedAmiId"
    $amiCheckResult = aws ec2 describe-images --image-ids $resolvedAmiId @awsArgs --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "AMI not found or not accessible: $amiCheckResult"
    }

    $amiData = $amiCheckResult | ConvertFrom-Json
    $ami = $amiData.Images[0]
    Write-Output "AMI Details:"
    Write-Output "  Name: $($ami.Name)"
    Write-Output "  Architecture: $($ami.Architecture)"
    Write-Output "  Root Device Type: $($ami.RootDeviceType)"

    # Process user data
    $userDataEncoded = $UserDataBase64
    if ($UserDataFile) {
        $userData = Get-Content $UserDataFile -Raw -Encoding UTF8
        $userDataEncoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userData))
        Write-Output "User data loaded from file: $UserDataFile"
    }

    # Build launch template data
    $launchTemplateData = @{
        ImageId = $resolvedAmiId
        InstanceType = $InstanceType
    }

    if ($KeyName) {
        $launchTemplateData.KeyName = $KeyName
    }

    if ($SecurityGroupIds) {
        $sgArray = $SecurityGroupIds -split ',' | ForEach-Object { $_.Trim() }
        $launchTemplateData.SecurityGroupIds = $sgArray
    }

    if ($SubnetId) {
        $launchTemplateData.SubnetId = $SubnetId
    }

    if ($IamInstanceProfile) {
        if ($IamInstanceProfile -match '^arn:') {
            $launchTemplateData.IamInstanceProfile = @{ Arn = $IamInstanceProfile }
        } else {
            $launchTemplateData.IamInstanceProfile = @{ Name = $IamInstanceProfile }
        }
    }

    if ($userDataEncoded) {
        $launchTemplateData.UserData = $userDataEncoded
    }

    if ($EbsOptimized) {
        $launchTemplateData.EbsOptimized = $true
    }

    if ($Monitoring) {
        $launchTemplateData.Monitoring = @{ Enabled = $true }
    }

    if ($DisableApiTermination) {
        $launchTemplateData.DisableApiTermination = $true
    }

    $launchTemplateData.InstanceInitiatedShutdownBehavior = $InstanceInitiatedShutdownBehavior

    # Add tag specifications if provided
    if ($Tags) {
        try {
            $tagArray = $Tags | ConvertFrom-Json
            $launchTemplateData.TagSpecifications = @(
                @{
                    ResourceType = 'instance'
                    Tags = $tagArray
                },
                @{
                    ResourceType = 'volume'
                    Tags = $tagArray
                }
            )
        } catch {
            Write-Warning "Invalid JSON format for tags, skipping tag specifications: $($_.Exception.Message)"
        }
    }

    # Convert to JSON
    $launchTemplateJson = $launchTemplateData | ConvertTo-Json -Depth 10 -Compress

    # Create the launch template
    $createArgs = @('ec2', 'create-launch-template', '--launch-template-name', $LaunchTemplateName)
    $createArgs += $awsArgs

    if ($VersionDescription) {
        $createArgs += @('--version-description', $VersionDescription)
    }

    $createArgs += @('--launch-template-data', $launchTemplateJson, '--output', 'json')

    Write-Output "`nCreating launch template with configuration:"
    Write-Output "  Name: $LaunchTemplateName"
    Write-Output "  AMI ID: $resolvedAmiId"
    Write-Output "  Instance Type: $InstanceType"
    if ($KeyName) { Write-Output "  Key Name: $KeyName" }
    if ($SecurityGroupIds) { Write-Output "  Security Groups: $SecurityGroupIds" }
    if ($SubnetId) { Write-Output "  Subnet: $SubnetId" }
    if ($IamInstanceProfile) { Write-Output "  IAM Instance Profile: $IamInstanceProfile" }
    if ($UserDataFile) { Write-Output "  User Data: From file $UserDataFile" }
    if ($EbsOptimized) { Write-Output "  EBS Optimized: Enabled" }
    if ($Monitoring) { Write-Output "  Detailed Monitoring: Enabled" }

    $result = & aws @createArgs 2>&1

    if ($LASTEXITCODE -eq 0) {
        $templateData = $result | ConvertFrom-Json
        $template = $templateData.LaunchTemplate

        Write-Output "`n✅ Launch Template created successfully!"
        Write-Output "📋 Template Details:"
        Write-Output "  Launch Template ID: $($template.LaunchTemplateId)"
        Write-Output "  Launch Template Name: $($template.LaunchTemplateName)"
        Write-Output "  Latest Version: $($template.LatestVersionNumber)"
        Write-Output "  Default Version: $($template.DefaultVersionNumber)"
        Write-Output "  Created: $($template.CreateTime)"

        # Show usage examples
        Write-Output "`n💡 Usage Examples:"
        Write-Output "Launch instance from template:"
        Write-Output "  aws ec2 run-instances --launch-template LaunchTemplateId=$($template.LaunchTemplateId)"
        Write-Output ""
        Write-Output "Launch with specific version:"
        Write-Output "  aws ec2 run-instances --launch-template LaunchTemplateId=$($template.LaunchTemplateId),Version=1"
        Write-Output ""
        Write-Output "Launch with override (different instance type):"
        Write-Output "  aws ec2 run-instances --launch-template LaunchTemplateId=$($template.LaunchTemplateId) --instance-type t3.small"

        if (-not $SubnetId) {
            Write-Output ""
            Write-Output "⚠️  Note: No subnet specified in template. You'll need to specify --subnet-id when launching instances."
        }

    } else {
        throw "Failed to create launch template: $result"
    }

} catch {
    Write-Error "Failed to create launch template: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
