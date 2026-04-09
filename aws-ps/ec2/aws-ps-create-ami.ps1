<#
.SYNOPSIS
    Creates an Amazon Machine Image (AMI) from a running or stopped EC2 instance.

.DESCRIPTION
    This script creates an AMI from an existing EC2 instance using the New-EC2Image
    cmdlet from AWS.Tools.EC2. It supports optional reboot suppression and can poll
    until the image reaches the 'available' state before returning.

.PARAMETER Region
    The AWS region where the source EC2 instance is located (e.g. eu-central-1).

.PARAMETER InstanceId
    The ID of the EC2 instance to create the AMI from (e.g. i-1234567890abcdef0).

.PARAMETER ImageName
    The name for the new AMI. Must be unique within the region.

.PARAMETER Description
    Optional description for the AMI.

.PARAMETER NoReboot
    If specified, the instance will not be rebooted before creating the image.
    This may result in an inconsistent filesystem state on the AMI.

.PARAMETER WaitForAvailable
    If specified, the script will poll until the AMI state reaches 'available',
    waiting up to 30 minutes. If omitted, the script returns immediately after
    initiating the image creation.

.EXAMPLE
    .\aws-ps-create-ami.ps1 -Region eu-central-1 -InstanceId i-1234567890abcdef0 -ImageName "MyAppAMI-v1"
    Creates an AMI from the specified instance, rebooting it first, and returns immediately.

.EXAMPLE
    .\aws-ps-create-ami.ps1 -Region us-east-1 -InstanceId i-0abcdef1234567890 -ImageName "ProdBackup-20260101" -Description "Production snapshot before patch" -NoReboot -WaitForAvailable
    Creates an AMI without rebooting the instance and waits until the image is available.

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
    https://docs.aws.amazon.com/powershell/latest/reference/items/New-EC2Image.html

.COMPONENT
    AWS PowerShell EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region where the source EC2 instance is located (e.g. eu-central-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EC2 instance to create the AMI from (e.g. i-1234567890abcdef0).")]
    [ValidatePattern('^i-[a-f0-9]{8,17}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new AMI. Must be unique within the region.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageName,

    [Parameter(HelpMessage = "Optional description for the AMI.")]
    [string]$Description,

    [Parameter(HelpMessage = "If specified, the instance will not be rebooted before creating the image. May result in inconsistent filesystem state.")]
    [switch]$NoReboot,

    [Parameter(HelpMessage = "If specified, the script polls until the AMI reaches 'available' state (up to 30 minutes).")]
    [switch]$WaitForAvailable
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting AMI creation" -ForegroundColor Green
    Write-Host "🔍 Importing AWS.Tools.EC2 module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.EC2 -ErrorAction Stop

    Write-Host "🔍 Verifying source instance: $InstanceId in $Region..." -ForegroundColor Cyan
    $reservations = Get-EC2Instance -InstanceId $InstanceId -Region $Region
    $instance = $reservations.Instances | Select-Object -First 1
    if (-not $instance) {
        throw "Instance '$InstanceId' not found in region '$Region'."
    }
    $nameTag = ($instance.Tags | Where-Object { $_.Key -eq 'Name' }).Value
    if (-not $nameTag) { $nameTag = '(no Name tag)' }
    Write-Host "   Instance: $($instance.InstanceId) | $($instance.State.Name) | $($instance.InstanceType) | $nameTag" -ForegroundColor White

    # Build parameters for New-EC2Image
    $createParams = @{
        InstanceId = $InstanceId
        Name       = $ImageName
        Region     = $Region
    }
    if ($Description) {
        $createParams['Description'] = $Description
    }
    if ($NoReboot) {
        $createParams['NoReboot'] = $true
        Write-Host "⚠️  NoReboot specified — image may have inconsistent filesystem state." -ForegroundColor Yellow
    }

    Write-Host "🔧 Creating AMI '$ImageName' from instance $InstanceId..." -ForegroundColor Cyan
    $imageId = New-EC2Image @createParams
    Write-Host "✅ AMI creation initiated. ImageId: $imageId" -ForegroundColor Green

    if ($WaitForAvailable) {
        Write-Host "⏳ Waiting for AMI to reach 'available' state (up to 30 minutes)..." -ForegroundColor Cyan
        $maxWaitSeconds = 1800
        $waited         = 0
        $interval       = 30

        do {
            Start-Sleep -Seconds $interval
            $waited += $interval
            $image = Get-EC2Image -ImageId $imageId -Region $Region
            $state = $image.State.Value
            Write-Host "   State: $state ($waited/$maxWaitSeconds s)" -ForegroundColor Gray
        } while ($state -ne 'available' -and $waited -lt $maxWaitSeconds)

        if ($state -ne 'available') {
            Write-Host "⚠️  AMI did not reach 'available' state within $maxWaitSeconds seconds. Current state: $state" -ForegroundColor Yellow
        }
        else {
            Write-Host "✅ AMI is now available." -ForegroundColor Green
        }
    }
    else {
        $image = Get-EC2Image -ImageId $imageId -Region $Region
        $state = $image.State.Value
    }

    Write-Host "" -ForegroundColor White
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   ImageId:   $imageId" -ForegroundColor White
    Write-Host "   ImageName: $ImageName" -ForegroundColor White
    Write-Host "   State:     $state" -ForegroundColor White
    Write-Host "   Region:    $Region" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
