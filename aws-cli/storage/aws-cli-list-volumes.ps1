<#
.SYNOPSIS
    List EBS volumes with filtering options using AWS CLI.

.DESCRIPTION
    This script lists EBS volumes using the latest AWS CLI (v2.16+) with various filtering
    and output options for comprehensive volume management.

.PARAMETER VolumeIds
    Comma-separated list of specific volume IDs to describe.

.PARAMETER State
    Filter volumes by state (creating, available, in-use, deleting, deleted, error).

.PARAMETER VolumeType
    Filter volumes by type (gp2, gp3, io1, io2, st1, sc1, standard).

.PARAMETER Size
    Filter volumes by size in GiB.

.PARAMETER AvailabilityZone
    Filter volumes by availability zone.

.PARAMETER InstanceId
    Filter volumes attached to a specific instance.

.PARAMETER Encrypted
    Filter by encryption status (true/false).

.PARAMETER TagKey
    Filter volumes that have a specific tag key.

.PARAMETER TagValue
    Filter volumes by tag key=value pair (use with TagKey).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER OutputFormat
    Output format: table, json, csv (default: table).

.PARAMETER ShowTags
    Include tags in the output.

.PARAMETER ShowAttachments
    Include attachment information in the output.

.EXAMPLE
    .\aws-cli-list-volumes.ps1

.EXAMPLE
    .\aws-cli-list-volumes.ps1 -State "available" -VolumeType "gp3"

.EXAMPLE
    .\aws-cli-list-volumes.ps1 -InstanceId "i-1234567890abcdef0" -ShowAttachments

.EXAMPLE
    .\aws-cli-list-volumes.ps1 -Encrypted $true -OutputFormat "json"

.EXAMPLE
    .\aws-cli-list-volumes.ps1 -TagKey "Environment" -TagValue "Production" -ShowTags

.NOTES
    Requires AWS CLI v2.16+ and appropriate IAM permissions for EC2 operations.

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$VolumeIds,

    [Parameter()]
    [ValidateSet("creating", "available", "in-use", "deleting", "deleted", "error")]
    [string]$State,

    [Parameter()]
    [ValidateSet("gp2", "gp3", "io1", "io2", "st1", "sc1", "standard")]
    [string]$VolumeType,

    [Parameter()]
    [ValidateRange(1, 65536)]
    [int]$Size,

    [Parameter()]
    [string]$AvailabilityZone,

    [Parameter()]
    [ValidatePattern('^i-[a-f0-9]{8,17}$')]
    [string]$InstanceId,

    [Parameter()]
    [bool]$Encrypted,

    [Parameter()]
    [string]$TagKey,

    [Parameter()]
    [string]$TagValue,

    [Parameter()]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter()]
    [string]$AwsProfile,

    [Parameter()]
    [ValidateSet("table", "json", "csv")]
    [string]$OutputFormat = "table",

    [Parameter()]
    [switch]$ShowTags,

    [Parameter()]
    [switch]$ShowAttachments
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Listing EBS volumes..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Build describe-volumes command
    $describeArgs = @('ec2', 'describe-volumes')
    $describeArgs += $awsArgs
    $describeArgs += '--output', 'json'

    # Add volume IDs if specified
    if ($VolumeIds) {
        $volumeIdList = $VolumeIds -split ','
        $describeArgs += '--volume-ids'
        $describeArgs += $volumeIdList
    }

    # Build filters
    $filters = @()

    if ($State) {
        $filters += "Name=state,Values=$State"
    }

    if ($VolumeType) {
        $filters += "Name=volume-type,Values=$VolumeType"
    }

    if ($Size) {
        $filters += "Name=size,Values=$Size"
    }

    if ($AvailabilityZone) {
        $filters += "Name=availability-zone,Values=$AvailabilityZone"
    }

    if ($InstanceId) {
        $filters += "Name=attachment.instance-id,Values=$InstanceId"
    }

    if ($PSBoundParameters.ContainsKey('Encrypted')) {
        $encryptedValue = $Encrypted.ToString().ToLower()
        $filters += "Name=encrypted,Values=$encryptedValue"
    }

    if ($TagKey -and $TagValue) {
        $filters += "Name=tag:$TagKey,Values=$TagValue"
    } elseif ($TagKey) {
        $filters += "Name=tag-key,Values=$TagKey"
    }

    # Add filters to command if any exist
    if ($filters.Count -gt 0) {
        $describeArgs += '--filters'
        $describeArgs += $filters
    }

    # Execute the command
    Write-Host "Executing: aws $($describeArgs -join ' ')" -ForegroundColor Gray
    $result = aws @describeArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list volumes: $result"
    }

    $volumeData = $result | ConvertFrom-Json
    $volumes = $volumeData.Volumes

    if ($volumes.Count -eq 0) {
        Write-Host "No volumes found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Found $($volumes.Count) volume(s)" -ForegroundColor Cyan

    # Process and display results based on output format
    switch ($OutputFormat) {
        "json" {
            Write-Host "`nJSON Output:" -ForegroundColor Cyan
            $volumes | ConvertTo-Json -Depth 10
        }
        "csv" {
            Write-Host "`nCSV Output:" -ForegroundColor Cyan
            $csvData = @()
            foreach ($volume in $volumes) {
                $attachmentInfo = ""
                if ($volume.Attachments.Count -gt 0) {
                    $attachment = $volume.Attachments[0]
                    $attachmentInfo = "$($attachment.InstanceId):$($attachment.Device)"
                }

                $tags = ""
                if ($volume.Tags) {
                    $tagStrings = $volume.Tags | ForEach-Object { "$($_.Key)=$($_.Value)" }
                    $tags = $tagStrings -join ";"
                }

                $csvData += [PSCustomObject]@{
                    VolumeId = $volume.VolumeId
                    Size = $volume.Size
                    Type = $volume.VolumeType
                    State = $volume.State
                    AvailabilityZone = $volume.AvailabilityZone
                    Encrypted = $volume.Encrypted
                    CreateTime = $volume.CreateTime
                    Attachment = $attachmentInfo
                    Tags = $tags
                }
            }
            $csvData | ConvertTo-Csv -NoTypeInformation
        }
        "table" {
            Write-Host "`nVolume Summary:" -ForegroundColor Cyan
            Write-Host "=" * 120 -ForegroundColor Gray

            foreach ($volume in $volumes) {
                Write-Host "`nVolume ID: " -NoNewline -ForegroundColor White
                Write-Host $volume.VolumeId -ForegroundColor Cyan

                Write-Host "  Size: " -NoNewline -ForegroundColor White
                Write-Host "$($volume.Size) GiB" -ForegroundColor Yellow

                Write-Host "  Type: " -NoNewline -ForegroundColor White
                Write-Host $volume.VolumeType -ForegroundColor Yellow

                Write-Host "  State: " -NoNewline -ForegroundColor White
                $stateColor = switch ($volume.State) {
                    "available" { "Green" }
                    "in-use" { "Cyan" }
                    "creating" { "Yellow" }
                    "deleting" { "Red" }
                    "error" { "Red" }
                    default { "White" }
                }
                Write-Host $volume.State -ForegroundColor $stateColor

                Write-Host "  AZ: " -NoNewline -ForegroundColor White
                Write-Host $volume.AvailabilityZone -ForegroundColor Yellow

                Write-Host "  Encrypted: " -NoNewline -ForegroundColor White
                $encColor = if ($volume.Encrypted) { "Green" } else { "Red" }
                Write-Host $volume.Encrypted -ForegroundColor $encColor

                Write-Host "  Created: " -NoNewline -ForegroundColor White
                Write-Host $volume.CreateTime -ForegroundColor Gray

                if ($volume.VolumeType -in @("gp3", "io1", "io2")) {
                    if ($volume.Iops) {
                        Write-Host "  IOPS: " -NoNewline -ForegroundColor White
                        Write-Host $volume.Iops -ForegroundColor Yellow
                    }
                }

                if ($volume.VolumeType -eq "gp3" -and $volume.Throughput) {
                    Write-Host "  Throughput: " -NoNewline -ForegroundColor White
                    Write-Host "$($volume.Throughput) MB/s" -ForegroundColor Yellow
                }

                if ($volume.KmsKeyId) {
                    Write-Host "  KMS Key: " -NoNewline -ForegroundColor White
                    Write-Host $volume.KmsKeyId -ForegroundColor Gray
                }

                if ($ShowAttachments -and $volume.Attachments.Count -gt 0) {
                    Write-Host "  Attachments:" -ForegroundColor White
                    foreach ($attachment in $volume.Attachments) {
                        Write-Host "    Instance: $($attachment.InstanceId)" -ForegroundColor Cyan
                        Write-Host "    Device: $($attachment.Device)" -ForegroundColor Cyan
                        Write-Host "    State: $($attachment.State)" -ForegroundColor Cyan
                        Write-Host "    Attach Time: $($attachment.AttachTime)" -ForegroundColor Gray
                        Write-Host "    Delete on Termination: $($attachment.DeleteOnTermination)" -ForegroundColor Gray
                    }
                }

                if ($ShowTags -and $volume.Tags) {
                    Write-Host "  Tags:" -ForegroundColor White
                    foreach ($tag in $volume.Tags) {
                        Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
                    }
                }
            }

            # Summary statistics
            Write-Host "`n" + "=" * 120 -ForegroundColor Gray
            Write-Host "Summary Statistics:" -ForegroundColor Cyan

            $totalSize = ($volumes | Measure-Object -Property Size -Sum).Sum
            Write-Host "  Total Volumes: $($volumes.Count)" -ForegroundColor White
            Write-Host "  Total Size: $totalSize GiB" -ForegroundColor White

            $stateGroups = $volumes | Group-Object State
            Write-Host "  States:" -ForegroundColor White
            foreach ($group in $stateGroups) {
                Write-Host "    $($group.Name): $($group.Count)" -ForegroundColor Gray
            }

            $typeGroups = $volumes | Group-Object VolumeType
            Write-Host "  Types:" -ForegroundColor White
            foreach ($group in $typeGroups) {
                Write-Host "    $($group.Name): $($group.Count)" -ForegroundColor Gray
            }

            $encryptedCount = ($volumes | Where-Object { $_.Encrypted }).Count
            $unencryptedCount = $volumes.Count - $encryptedCount
            Write-Host "  Encryption:" -ForegroundColor White
            Write-Host "    Encrypted: $encryptedCount" -ForegroundColor Green
            Write-Host "    Unencrypted: $unencryptedCount" -ForegroundColor Red
        }
    }

    Write-Host "`n✅ Volume listing completed successfully!" -ForegroundColor Green

} catch {
    Write-Error "Failed to list volumes: $($_.Exception.Message)"
    exit 1
}
