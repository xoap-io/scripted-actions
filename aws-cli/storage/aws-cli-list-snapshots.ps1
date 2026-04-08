<#
.SYNOPSIS
    List EBS snapshots with filtering options using AWS CLI.

.DESCRIPTION
    This script lists EBS snapshots using the latest AWS CLI (v2.16+) with various
    filtering and output options for comprehensive snapshot management.

.PARAMETER SnapshotIds
    Comma-separated list of specific snapshot IDs to describe.

.PARAMETER OwnerIds
    Comma-separated list of owner IDs (self, amazon, or account IDs).

.PARAMETER State
    Filter snapshots by state (pending, completed, error).

.PARAMETER VolumeId
    Filter snapshots created from a specific volume.

.PARAMETER VolumeSize
    Filter snapshots by original volume size in GiB.

.PARAMETER Description
    Filter snapshots by description (partial match).

.PARAMETER TagKey
    Filter snapshots that have a specific tag key.

.PARAMETER TagValue
    Filter snapshots by tag key=value pair (use with TagKey).

.PARAMETER StartTimeAfter
    Filter snapshots started after this date (YYYY-MM-DD format).

.PARAMETER StartTimeBefore
    Filter snapshots started before this date (YYYY-MM-DD format).

.PARAMETER Encrypted
    Filter by encryption status (true/false).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER OutputFormat
    Output format: table, json, csv (default: table).

.PARAMETER ShowTags
    Include tags in the output.

.PARAMETER SortBy
    Sort results by: StartTime, VolumeSize, Progress (default: StartTime).

.PARAMETER SortOrder
    Sort order: asc, desc (default: desc).

.EXAMPLE
    .\aws-cli-list-snapshots.ps1

.EXAMPLE
    .\aws-cli-list-snapshots.ps1 -OwnerIds "self" -State "completed"

.EXAMPLE
    .\aws-cli-list-snapshots.ps1 -VolumeId "vol-1234567890abcdef0" -ShowTags

.EXAMPLE
    .\aws-cli-list-snapshots.ps1 -TagKey "Environment" -TagValue "Production" -OutputFormat "json"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-snapshots.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of specific snapshot IDs to describe")]
    [string]$SnapshotIds,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of owner IDs (self, amazon, or account IDs)")]
    [string]$OwnerIds = "self",

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots by state (pending, completed, error)")]
    [ValidateSet("pending", "completed", "error")]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots created from a specific volume")]
    [ValidatePattern('^vol-[a-f0-9]{8,17}$')]
    [string]$VolumeId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots by original volume size in GiB")]
    [ValidateRange(1, 65536)]
    [int]$VolumeSize,

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots by description (partial match)")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots that have a specific tag key")]
    [string]$TagKey,

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots by tag key=value pair (use with TagKey)")]
    [string]$TagValue,

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots started after this date (YYYY-MM-DD format)")]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$StartTimeAfter,

    [Parameter(Mandatory = $false, HelpMessage = "Filter snapshots started before this date (YYYY-MM-DD format)")]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$StartTimeBefore,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by encryption status (true/false)")]
    [bool]$Encrypted,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use")]
    [string]$AwsProfile,

    [Parameter(Mandatory = $false, HelpMessage = "Output format: table, json, csv (default: table)")]
    [ValidateSet("table", "json", "csv")]
    [string]$OutputFormat = "table",

    [Parameter(Mandatory = $false, HelpMessage = "Include tags in the output")]
    [switch]$ShowTags,

    [Parameter(Mandatory = $false, HelpMessage = "Sort results by: StartTime, VolumeSize, Progress (default: StartTime)")]
    [ValidateSet("StartTime", "VolumeSize", "Progress")]
    [string]$SortBy = "StartTime",

    [Parameter(Mandatory = $false, HelpMessage = "Sort order: asc, desc (default: desc)")]
    [ValidateSet("asc", "desc")]
    [string]$SortOrder = "desc"
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Listing EBS snapshots..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Build describe-snapshots command
    $describeArgs = @('ec2', 'describe-snapshots')
    $describeArgs += $awsArgs
    $describeArgs += '--output', 'json'

    # Add snapshot IDs if specified
    if ($SnapshotIds) {
        $snapshotIdList = $SnapshotIds -split ','
        $describeArgs += '--snapshot-ids'
        $describeArgs += $snapshotIdList
    } else {
        # Add owner IDs if no specific snapshot IDs
        $ownerIdList = $OwnerIds -split ','
        $describeArgs += '--owner-ids'
        $describeArgs += $ownerIdList
    }

    # Build filters
    $filters = @()

    if ($State) {
        $filters += "Name=state,Values=$State"
    }

    if ($VolumeId) {
        $filters += "Name=volume-id,Values=$VolumeId"
    }

    if ($VolumeSize) {
        $filters += "Name=volume-size,Values=$VolumeSize"
    }

    if ($Description) {
        $filters += "Name=description,Values=*$Description*"
    }

    if ($StartTimeAfter) {
        $filters += "Name=start-time,Values=$StartTimeAfter*"
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
        throw "Failed to list snapshots: $result"
    }

    $snapshotData = $result | ConvertFrom-Json
    $snapshots = $snapshotData.Snapshots

    if ($snapshots.Count -eq 0) {
        Write-Host "No snapshots found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    # Apply additional filtering for date ranges
    if ($StartTimeAfter -or $StartTimeBefore) {
        $filteredSnapshots = @()
        foreach ($snapshot in $snapshots) {
            $startTime = [DateTime]::Parse($snapshot.StartTime)
            $include = $true

            if ($StartTimeAfter) {
                $afterDate = [DateTime]::Parse($StartTimeAfter)
                if ($startTime -lt $afterDate) {
                    $include = $false
                }
            }

            if ($StartTimeBefore) {
                $beforeDate = [DateTime]::Parse($StartTimeBefore).AddDays(1)
                if ($startTime -ge $beforeDate) {
                    $include = $false
                }
            }

            if ($include) {
                $filteredSnapshots += $snapshot
            }
        }
        $snapshots = $filteredSnapshots
    }

    # Sort snapshots
    switch ($SortBy) {
        "StartTime" {
            if ($SortOrder -eq "desc") {
                $snapshots = $snapshots | Sort-Object { [DateTime]::Parse($_.StartTime) } -Descending
            } else {
                $snapshots = $snapshots | Sort-Object { [DateTime]::Parse($_.StartTime) }
            }
        }
        "VolumeSize" {
            if ($SortOrder -eq "desc") {
                $snapshots = $snapshots | Sort-Object VolumeSize -Descending
            } else {
                $snapshots = $snapshots | Sort-Object VolumeSize
            }
        }
        "Progress" {
            if ($SortOrder -eq "desc") {
                $snapshots = $snapshots | Sort-Object Progress -Descending
            } else {
                $snapshots = $snapshots | Sort-Object Progress
            }
        }
    }

    Write-Host "Found $($snapshots.Count) snapshot(s)" -ForegroundColor Cyan

    # Process and display results based on output format
    switch ($OutputFormat) {
        "json" {
            Write-Host "`nJSON Output:" -ForegroundColor Cyan
            $snapshots | ConvertTo-Json -Depth 10
        }
        "csv" {
            Write-Host "`nCSV Output:" -ForegroundColor Cyan
            $csvData = @()
            foreach ($snapshot in $snapshots) {
                $tags = ""
                if ($snapshot.Tags) {
                    $tagStrings = $snapshot.Tags | ForEach-Object { "$($_.Key)=$($_.Value)" }
                    $tags = $tagStrings -join ";"
                }

                $csvData += [PSCustomObject]@{
                    SnapshotId = $snapshot.SnapshotId
                    VolumeId = $snapshot.VolumeId
                    VolumeSize = $snapshot.VolumeSize
                    State = $snapshot.State
                    Progress = $snapshot.Progress
                    StartTime = $snapshot.StartTime
                    Description = $snapshot.Description
                    Encrypted = $snapshot.Encrypted
                    OwnerId = $snapshot.OwnerId
                    Tags = $tags
                }
            }
            $csvData | ConvertTo-Csv -NoTypeInformation
        }
        "table" {
            Write-Host "`nSnapshot Summary:" -ForegroundColor Cyan
            Write-Host "=" * 120 -ForegroundColor Gray

            foreach ($snapshot in $snapshots) {
                Write-Host "`nSnapshot ID: " -NoNewline -ForegroundColor White
                Write-Host $snapshot.SnapshotId -ForegroundColor Cyan

                Write-Host "  Volume ID: " -NoNewline -ForegroundColor White
                Write-Host $snapshot.VolumeId -ForegroundColor Yellow

                Write-Host "  Volume Size: " -NoNewline -ForegroundColor White
                Write-Host "$($snapshot.VolumeSize) GiB" -ForegroundColor Yellow

                Write-Host "  State: " -NoNewline -ForegroundColor White
                $stateColor = switch ($snapshot.State) {
                    "completed" { "Green" }
                    "pending" { "Yellow" }
                    "error" { "Red" }
                    default { "White" }
                }
                Write-Host $snapshot.State -ForegroundColor $stateColor

                Write-Host "  Progress: " -NoNewline -ForegroundColor White
                Write-Host "$($snapshot.Progress)%" -ForegroundColor Cyan

                Write-Host "  Start Time: " -NoNewline -ForegroundColor White
                Write-Host $snapshot.StartTime -ForegroundColor Gray

                Write-Host "  Description: " -NoNewline -ForegroundColor White
                Write-Host $snapshot.Description -ForegroundColor Gray

                Write-Host "  Encrypted: " -NoNewline -ForegroundColor White
                $encColor = if ($snapshot.Encrypted) { "Green" } else { "Red" }
                Write-Host $snapshot.Encrypted -ForegroundColor $encColor

                Write-Host "  Owner ID: " -NoNewline -ForegroundColor White
                Write-Host $snapshot.OwnerId -ForegroundColor Gray

                if ($snapshot.KmsKeyId) {
                    Write-Host "  KMS Key: " -NoNewline -ForegroundColor White
                    Write-Host $snapshot.KmsKeyId -ForegroundColor Gray
                }

                if ($ShowTags -and $snapshot.Tags) {
                    Write-Host "  Tags:" -ForegroundColor White
                    foreach ($tag in $snapshot.Tags) {
                        Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
                    }
                }
            }

            # Summary statistics
            Write-Host "`n" + "=" * 120 -ForegroundColor Gray
            Write-Host "Summary Statistics:" -ForegroundColor Cyan

            $totalSize = ($snapshots | Measure-Object -Property VolumeSize -Sum).Sum
            Write-Host "  Total Snapshots: $($snapshots.Count)" -ForegroundColor White
            Write-Host "  Total Volume Size: $totalSize GiB" -ForegroundColor White

            $stateGroups = $snapshots | Group-Object State
            Write-Host "  States:" -ForegroundColor White
            foreach ($group in $stateGroups) {
                Write-Host "    $($group.Name): $($group.Count)" -ForegroundColor Gray
            }

            $encryptedCount = ($snapshots | Where-Object { $_.Encrypted }).Count
            $unencryptedCount = $snapshots.Count - $encryptedCount
            Write-Host "  Encryption:" -ForegroundColor White
            Write-Host "    Encrypted: $encryptedCount" -ForegroundColor Green
            Write-Host "    Unencrypted: $unencryptedCount" -ForegroundColor Red

            # Age analysis
            $now = Get-Date
            $recentCount = ($snapshots | Where-Object {
                ([DateTime]::Parse($_.StartTime)) -gt $now.AddDays(-7)
            }).Count
            $oldCount = ($snapshots | Where-Object {
                ([DateTime]::Parse($_.StartTime)) -lt $now.AddDays(-30)
            }).Count

            Write-Host "  Age Analysis:" -ForegroundColor White
            Write-Host "    Last 7 days: $recentCount" -ForegroundColor Gray
            Write-Host "    Older than 30 days: $oldCount" -ForegroundColor Gray
        }
    }

    Write-Host "`n✅ Snapshot listing completed successfully!" -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
