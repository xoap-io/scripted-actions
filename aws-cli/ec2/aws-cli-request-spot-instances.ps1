<#
.SYNOPSIS
    Request and manage EC2 Spot instances using AWS CLI.

.DESCRIPTION
    This script provides comprehensive management of EC2 Spot instances including
    requesting spot instances, managing spot fleets, and monitoring spot prices.

.PARAMETER Action
    The action to perform: Request, Cancel, Describe, GetPrices, or CreateFleet.

.PARAMETER ImageId
    The AMI ID to use for the spot instance.

.PARAMETER InstanceType
    The EC2 instance type to launch.

.PARAMETER InstanceTypes
    Comma-separated list of instance types for diversified spot requests.

.PARAMETER KeyName
    The name of the key pair to use for SSH access.

.PARAMETER SecurityGroupIds
    Comma-separated list of security group IDs.

.PARAMETER SubnetId
    The subnet ID where the instance should be launched.

.PARAMETER SpotPrice
    The maximum price you are willing to pay for the spot instance (per hour).

.PARAMETER LaunchSpecification
    JSON file path containing detailed launch specification.

.PARAMETER SpotRequestId
    The ID of an existing spot request to operate on.

.PARAMETER SpotFleetRequestId
    The ID of an existing spot fleet request to operate on.

.PARAMETER TargetCapacity
    The target capacity for spot fleet (number of instances).

.PARAMETER UserData
    Base64-encoded user data script.

.PARAMETER UserDataFile
    Path to file containing user data script.

.PARAMETER IamInstanceProfile
    The name or ARN of the IAM instance profile.

.PARAMETER Tags
    JSON string of tags to apply to instances.

.PARAMETER ValidFrom
    The start date and time for the spot request (ISO 8601 format).

.PARAMETER ValidUntil
    The end date and time for the spot request (ISO 8601 format).

.PARAMETER Type
    The type of spot request: one-time or persistent.

.PARAMETER AvailabilityZone
    Specific availability zone for price checking.

.PARAMETER ProductDescription
    Product description for spot price history (Linux/UNIX, Windows, etc.).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-request-spot-instances.ps1 -Action "Request" -ImageId "ami-12345678" -InstanceType "t3.micro" -SpotPrice "0.01"

.EXAMPLE
    .\aws-cli-request-spot-instances.ps1 -Action "GetPrices" -InstanceType "t3.micro" -AvailabilityZone "us-east-1a"

.EXAMPLE
    .\aws-cli-request-spot-instances.ps1 -Action "CreateFleet" -TargetCapacity 5 -InstanceTypes "t3.micro,t3.small" -SpotPrice "0.05"

.EXAMPLE
    .\aws-cli-request-spot-instances.ps1 -Action "Cancel" -SpotRequestId "sir-12345678"

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
    [ValidateSet('Request', 'Cancel', 'Describe', 'GetPrices', 'CreateFleet', 'CancelFleet')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^ami-[a-zA-Z0-9]{8,}$')]
    [string]$ImageId,

    [Parameter(Mandatory = $false)]
    [string]$InstanceType,

    [Parameter(Mandatory = $false)]
    [string]$InstanceTypes,

    [Parameter(Mandatory = $false)]
    [string]$KeyName,

    [Parameter(Mandatory = $false)]
    [string]$SecurityGroupIds,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0.001, 10.0)]
    [decimal]$SpotPrice,

    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$LaunchSpecification,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^sir-[a-zA-Z0-9]{8,}$')]
    [string]$SpotRequestId,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^sfr-[a-zA-Z0-9]{8,}$')]
    [string]$SpotFleetRequestId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10000)]
    [int]$TargetCapacity,

    [Parameter(Mandatory = $false)]
    [string]$UserData,

    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$UserDataFile,

    [Parameter(Mandatory = $false)]
    [string]$IamInstanceProfile,

    [Parameter(Mandatory = $false)]
    [string]$Tags,

    [Parameter(Mandatory = $false)]
    [string]$ValidFrom,

    [Parameter(Mandatory = $false)]
    [string]$ValidUntil,

    [Parameter(Mandatory = $false)]
    [ValidateSet('one-time', 'persistent')]
    [string]$Type = 'one-time',

    [Parameter(Mandatory = $false)]
    [string]$AvailabilityZone,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Linux/UNIX', 'Windows', 'SUSE Linux', 'Red Hat Enterprise Linux')]
    [string]$ProductDescription = 'Linux/UNIX',

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

    Write-Output "💰 Managing EC2 Spot Instances"
    Write-Output "Action: $Action"
    if ($Region) { Write-Output "Region: $Region" }

    switch ($Action) {
        'Request' {
            if (-not $ImageId) {
                throw "ImageId is required for Request action."
            }
            if (-not $InstanceType) {
                throw "InstanceType is required for Request action."
            }

            Write-Output "`n🚀 Requesting spot instance..."
            Write-Output "AMI ID: $ImageId"
            Write-Output "Instance Type: $InstanceType"
            if ($SpotPrice) { Write-Output "Max Spot Price: $SpotPrice per hour" }

            # Prepare user data
            $userData = $null
            if ($UserDataFile) {
                Write-Output "Loading user data from file: $UserDataFile"
                $userDataContent = Get-Content -Path $UserDataFile -Raw
                $userData = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userDataContent))
            } elseif ($UserData) {
                $userData = $UserData
            }

            # Build launch specification
            $launchSpec = @{
                ImageId = $ImageId
                InstanceType = $InstanceType
            }

            if ($KeyName) { $launchSpec.KeyName = $KeyName }
            if ($SecurityGroupIds) { 
                $launchSpec.SecurityGroupIds = $SecurityGroupIds -split ',' | ForEach-Object { $_.Trim() }
            }
            if ($SubnetId) { $launchSpec.SubnetId = $SubnetId }
            if ($userData) { $launchSpec.UserData = $userData }
            if ($IamInstanceProfile) { 
                $launchSpec.IamInstanceProfile = @{ Name = $IamInstanceProfile }
            }

            # Convert to JSON and create temp file
            $launchSpecJson = $launchSpec | ConvertTo-Json -Depth 3
            $tempFile = [System.IO.Path]::GetTempFileName()
            $launchSpecJson | Out-File -FilePath $tempFile -Encoding UTF8

            try {
                # Build spot request command
                $spotArgs = @(
                    'ec2', 'request-spot-instances',
                    '--launch-specification', "file://$tempFile",
                    '--type', $Type
                ) + $awsArgs

                if ($SpotPrice) {
                    $spotArgs += @('--spot-price', $SpotPrice.ToString())
                }
                if ($ValidFrom) {
                    $spotArgs += @('--valid-from', $ValidFrom)
                }
                if ($ValidUntil) {
                    $spotArgs += @('--valid-until', $ValidUntil)
                }

                # Request the spot instance
                $requestResult = aws @spotArgs --output json 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $spotData = $requestResult | ConvertFrom-Json
                    
                    Write-Output "`n✅ Spot instance request submitted successfully:"
                    foreach ($request in $spotData.SpotInstanceRequests) {
                        Write-Output "  • Request ID: $($request.SpotInstanceRequestId)"
                        Write-Output "    State: $($request.State)"
                        Write-Output "    Status: $($request.Status.Code) - $($request.Status.Message)"
                        if ($request.SpotPrice) {
                            Write-Output "    Spot Price: $($request.SpotPrice)"
                        }
                        
                        # Apply tags if provided
                        if ($Tags) {
                            Write-Output "    Applying tags..."
                            try {
                                $tagsArray = $Tags | ConvertFrom-Json
                                $tagsJson = $tagsArray | ConvertTo-Json -Depth 3 -Compress
                                
                                $tagResult = aws ec2 create-tags --resources $request.SpotInstanceRequestId --tags $tagsJson @awsArgs 2>&1
                                
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Output "    ✅ Tags applied"
                                } else {
                                    Write-Warning "    Failed to apply tags: $tagResult"
                                }
                            } catch {
                                Write-Warning "    Invalid JSON format for tags: $($_.Exception.Message)"
                            }
                        }
                    }

                    Write-Output "`n💡 Monitor your spot request with:"
                    Write-Output "aws ec2 describe-spot-instance-requests --spot-instance-request-ids $($spotData.SpotInstanceRequests[0].SpotInstanceRequestId)"

                } else {
                    Write-Error "Failed to request spot instance: $requestResult"
                }

            } finally {
                # Clean up temp file
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force
                }
            }
        }

        'Cancel' {
            if (-not $SpotRequestId) {
                throw "SpotRequestId is required for Cancel action."
            }

            Write-Output "`n❌ Cancelling spot request: $SpotRequestId"
            
            # Get current request details
            $describeResult = aws ec2 describe-spot-instance-requests --spot-instance-request-ids $SpotRequestId @awsArgs --output json 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $requestData = $describeResult | ConvertFrom-Json
                $request = $requestData.SpotInstanceRequests[0]
                
                Write-Output "Current state: $($request.State)"
                Write-Output "Current status: $($request.Status.Code)"
                
                if ($request.InstanceId) {
                    Write-Output "⚠️  Instance launched: $($request.InstanceId)"
                    Write-Output "Note: Cancelling the spot request will not terminate the running instance."
                }
            }

            # Cancel the spot request
            $cancelResult = aws ec2 cancel-spot-instance-requests --spot-instance-request-ids $SpotRequestId @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $cancelData = $cancelResult | ConvertFrom-Json
                Write-Output "✅ Spot request cancelled successfully"
                
                foreach ($cancelled in $cancelData.CancelledSpotInstanceRequests) {
                    Write-Output "  • Request ID: $($cancelled.SpotInstanceRequestId)"
                    Write-Output "    State: $($cancelled.State)"
                }
            } else {
                Write-Error "Failed to cancel spot request: $cancelResult"
            }
        }

        'Describe' {
            Write-Output "`n📋 Describing spot instance requests..."
            
            $describeArgs = @('ec2', 'describe-spot-instance-requests') + $awsArgs
            
            if ($SpotRequestId) {
                $describeArgs += @('--spot-instance-request-ids', $SpotRequestId)
                Write-Output "Specific request: $SpotRequestId"
            }

            $describeResult = aws @describeArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $requestData = $describeResult | ConvertFrom-Json
                
                if ($requestData.SpotInstanceRequests.Count -eq 0) {
                    Write-Output "No spot instance requests found"
                    exit 0
                }

                Write-Output "`n📊 Spot Instance Requests ($($requestData.SpotInstanceRequests.Count)):"
                Write-Output "=" * 80

                foreach ($request in $requestData.SpotInstanceRequests) {
                    Write-Output "`nRequest ID: $($request.SpotInstanceRequestId)"
                    Write-Output "State: $($request.State)"
                    Write-Output "Status: $($request.Status.Code) - $($request.Status.Message)"
                    Write-Output "Type: $($request.Type)"
                    Write-Output "Spot Price: $($request.SpotPrice)"
                    Write-Output "Instance Type: $($request.LaunchSpecification.InstanceType)"
                    Write-Output "AMI ID: $($request.LaunchSpecification.ImageId)"
                    
                    if ($request.InstanceId) {
                        Write-Output "Instance ID: $($request.InstanceId)"
                        
                        # Get instance details
                        $instanceResult = aws ec2 describe-instances --instance-ids $request.InstanceId @awsArgs --query 'Reservations[0].Instances[0].[State.Name,PublicIpAddress,PrivateIpAddress]' --output text 2>&1
                        
                        if ($LASTEXITCODE -eq 0) {
                            $instanceInfo = $instanceResult.Trim() -split "`t"
                            Write-Output "Instance State: $($instanceInfo[0])"
                            if ($instanceInfo[1] -and $instanceInfo[1] -ne "None") {
                                Write-Output "Public IP: $($instanceInfo[1])"
                            }
                            if ($instanceInfo[2] -and $instanceInfo[2] -ne "None") {
                                Write-Output "Private IP: $($instanceInfo[2])"
                            }
                        }
                    }
                    
                    if ($request.ValidFrom) {
                        Write-Output "Valid From: $($request.ValidFrom)"
                    }
                    if ($request.ValidUntil) {
                        Write-Output "Valid Until: $($request.ValidUntil)"
                    }
                    
                    if ($request.Tags -and $request.Tags.Count -gt 0) {
                        Write-Output "Tags:"
                        foreach ($tag in $request.Tags) {
                            Write-Output "  • $($tag.Key): $($tag.Value)"
                        }
                    }
                }

                # Summary
                $stateGroups = $requestData.SpotInstanceRequests | Group-Object State
                Write-Output "`n📈 Summary by State:"
                foreach ($group in $stateGroups) {
                    Write-Output "  • $($group.Name): $($group.Count) requests"
                }

            } else {
                Write-Error "Failed to describe spot requests: $describeResult"
            }
        }

        'GetPrices' {
            Write-Output "`n💰 Getting spot price history..."
            
            $priceArgs = @(
                'ec2', 'describe-spot-price-history',
                '--start-time', (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
                '--product-descriptions', $ProductDescription
            ) + $awsArgs

            if ($InstanceType) {
                $priceArgs += @('--instance-types', $InstanceType)
                Write-Output "Instance Type: $InstanceType"
            }
            if ($AvailabilityZone) {
                $priceArgs += @('--availability-zone', $AvailabilityZone)
                Write-Output "Availability Zone: $AvailabilityZone"
            }
            
            Write-Output "Product Description: $ProductDescription"
            Write-Output "Time Range: Last 24 hours"

            $priceResult = aws @priceArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $priceData = $priceResult | ConvertFrom-Json
                
                if ($priceData.SpotPriceHistory.Count -eq 0) {
                    Write-Output "No spot price history found for the specified criteria"
                    exit 0
                }

                Write-Output "`n📊 Current Spot Prices:"
                Write-Output "=" * 80
                Write-Output "Instance Type`t`tAZ`t`tPrice`t`tTimestamp"
                Write-Output "-" * 80

                # Group by instance type and AZ to get latest prices
                $latestPrices = $priceData.SpotPriceHistory | 
                    Group-Object {$_.InstanceType + ":" + $_.AvailabilityZone} |
                    ForEach-Object {
                        $_.Group | Sort-Object Timestamp -Descending | Select-Object -First 1
                    } |
                    Sort-Object InstanceType, AvailabilityZone

                foreach ($price in $latestPrices) {
                    $timestamp = [DateTime]::Parse($price.Timestamp).ToString("MM/dd HH:mm")
                    Write-Output "$($price.InstanceType.PadRight(15))`t$($price.AvailabilityZone.PadRight(15))`t$($price.SpotPrice)`t`t$timestamp"
                }

                # Price analysis
                if ($InstanceType) {
                    $instancePrices = $latestPrices | Where-Object { $_.InstanceType -eq $InstanceType }
                    if ($instancePrices.Count -gt 1) {
                        $minPrice = ($instancePrices | Measure-Object -Property SpotPrice -Minimum).Minimum
                        $maxPrice = ($instancePrices | Measure-Object -Property SpotPrice -Maximum).Maximum
                        $avgPrice = ($instancePrices | Measure-Object -Property SpotPrice -Average).Average
                        
                        Write-Output "`n📈 Price Analysis for $InstanceType :"
                        Write-Output "Minimum Price: $minPrice"
                        Write-Output "Maximum Price: $maxPrice"
                        Write-Output "Average Price: $([math]::Round($avgPrice, 4))"
                        
                        $cheapestAZ = $instancePrices | Sort-Object SpotPrice | Select-Object -First 1
                        Write-Output "Cheapest AZ: $($cheapestAZ.AvailabilityZone) at $($cheapestAZ.SpotPrice)"
                    }
                }

                Write-Output "`n💡 Tip: Consider setting your maximum spot price 10-20% above current prices for better success rates."

            } else {
                Write-Error "Failed to get spot prices: $priceResult"
            }
        }

        'CreateFleet' {
            if (-not $TargetCapacity) {
                throw "TargetCapacity is required for CreateFleet action."
            }

            Write-Output "`n🚢 Creating spot fleet request..."
            Write-Output "Target Capacity: $TargetCapacity instances"

            # Determine instance types
            $instanceTypeList = @()
            if ($InstanceTypes) {
                $instanceTypeList = $InstanceTypes -split ',' | ForEach-Object { $_.Trim() }
            } elseif ($InstanceType) {
                $instanceTypeList = @($InstanceType)
            } else {
                throw "Either InstanceType or InstanceTypes must be specified for fleet requests."
            }

            Write-Output "Instance Types: $($instanceTypeList -join ', ')"

            # Build launch template specifications
            $launchTemplateConfigs = @()
            foreach ($iType in $instanceTypeList) {
                $config = @{
                    LaunchTemplateSpecification = @{
                        LaunchTemplateName = "spot-fleet-template-$(Get-Date -Format 'yyyyMMdd-HHmm')"
                        Version = '$Latest'
                    }
                    Overrides = @(
                        @{
                            InstanceType = $iType
                            WeightedCapacity = 1
                        }
                    )
                }
                $launchTemplateConfigs += $config
            }

            # Build spot fleet configuration
            $spotFleetConfig = @{
                SpotFleetRequestConfig = @{
                    TargetCapacity = $TargetCapacity
                    AllocationStrategy = "diversified"
                    IamFleetRole = "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/aws-ec2-spot-fleet-tagging-role"
                    LaunchTemplateConfigs = $launchTemplateConfigs
                    ReplaceUnhealthyInstances = $true
                    Type = "maintain"
                }
            }

            if ($SpotPrice) {
                $spotFleetConfig.SpotFleetRequestConfig.SpotPrice = $SpotPrice.ToString()
                Write-Output "Max Spot Price: $SpotPrice per hour"
            }

            # Convert to JSON and create temp file
            $fleetConfigJson = $spotFleetConfig | ConvertTo-Json -Depth 5
            $tempFile = [System.IO.Path]::GetTempFileName()
            $fleetConfigJson | Out-File -FilePath $tempFile -Encoding UTF8

            try {
                Write-Output "`n⚠️  Note: This is a simplified fleet configuration."
                Write-Output "For production use, create a proper launch template first."
                Write-Output "Fleet configuration saved to temp file for review."

                # Display the configuration
                Write-Output "`n📋 Fleet Configuration:"
                Write-Output $fleetConfigJson

                Write-Output "`n💡 To create the fleet, run:"
                Write-Output "aws ec2 request-spot-fleet --spot-fleet-request-config file://$tempFile"

            } finally {
                # Don't auto-delete temp file so user can review
                Write-Output "`nTemp config file: $tempFile"
            }
        }

        'CancelFleet' {
            if (-not $SpotFleetRequestId) {
                throw "SpotFleetRequestId is required for CancelFleet action."
            }

            Write-Output "`n❌ Cancelling spot fleet: $SpotFleetRequestId"
            
            $cancelResult = aws ec2 cancel-spot-fleet-requests --spot-fleet-request-ids $SpotFleetRequestId --terminate-instances @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Output "✅ Spot fleet cancellation initiated"
                Write-Output "All instances in the fleet will be terminated."
            } else {
                Write-Error "Failed to cancel spot fleet: $cancelResult"
            }
        }
    }

    Write-Output "`n✅ Spot instance operation completed successfully."

} catch {
    Write-Error "Failed to manage spot instances: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
