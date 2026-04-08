<#
.SYNOPSIS
    Manage EC2 instance tags using AWS CLI.

.DESCRIPTION
    This script provides comprehensive tag management for EC2 instances including
    adding, modifying, removing tags, and bulk operations across multiple instances.

.PARAMETER Action
    The action to perform: Add, Remove, List, or Replace.

.PARAMETER InstanceId
    The ID of the EC2 instance (for single instance operations).

.PARAMETER InstanceIds
    Comma-separated list of instance IDs (for bulk operations).

.PARAMETER TagKey
    The tag key (required for Add and Remove actions).

.PARAMETER TagValue
    The tag value (required for Add action).

.PARAMETER Tags
    JSON string of multiple tags to add/replace (alternative to TagKey/TagValue).

.PARAMETER TagsFromFile
    Path to JSON file containing tags to apply.

.PARAMETER Filter
    Filter to select instances by existing tags (for bulk operations).

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-manage-instance-tags.ps1 -Action Add -InstanceId "i-1234567890abcdef0" -TagKey "Environment" -TagValue "Production"

.EXAMPLE
    .\aws-cli-manage-instance-tags.ps1 -Action Add -InstanceId "i-1234567890abcdef0" -Tags '[{"Key":"Environment","Value":"Prod"},{"Key":"Owner","Value":"TeamA"}]'

.EXAMPLE
    .\aws-cli-manage-instance-tags.ps1 -Action Remove -InstanceId "i-1234567890abcdef0" -TagKey "Environment"

.EXAMPLE
    .\aws-cli-manage-instance-tags.ps1 -Action List -InstanceIds "i-123,i-456,i-789"

.EXAMPLE
    .\aws-cli-manage-instance-tags.ps1 -Action Add -Filter "tag:Environment=Dev" -TagKey "Owner" -TagValue "DevTeam"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-tags.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The action to perform: Add, Remove, List, or Replace.")]
    [ValidateSet('Add', 'Remove', 'List', 'Replace')]
    [string]$Action,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the EC2 instance (for single instance operations).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of instance IDs (for bulk operations).")]
    [string]$InstanceIds,

    [Parameter(Mandatory = $false, HelpMessage = "The tag key (required for Add and Remove actions).")]
    [ValidateLength(1, 128)]
    [string]$TagKey,

    [Parameter(Mandatory = $false, HelpMessage = "The tag value (required for Add action).")]
    [ValidateLength(0, 256)]
    [string]$TagValue,

    [Parameter(Mandatory = $false, HelpMessage = "JSON string of multiple tags to add/replace (alternative to TagKey/TagValue).")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Path to JSON file containing tags to apply.")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$TagsFromFile,

    [Parameter(Mandatory = $false, HelpMessage = "Filter to select instances by existing tags (for bulk operations).")]
    [string]$Filter,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region to use (optional, uses default if not specified).")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS CLI profile to use (optional).")]
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

    # Determine target instances
    $targetInstances = @()

    if ($InstanceId) {
        $targetInstances += $InstanceId
    }

    if ($InstanceIds) {
        $targetInstances += $InstanceIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($Filter) {
        Write-Output "Finding instances matching filter: $Filter"
        $filterArgs = @('ec2', 'describe-instances', '--filters', $Filter, '--query', 'Reservations[*].Instances[*].InstanceId', '--output', 'text')
        $filterArgs += $awsArgs

        $filterResult = & aws @filterArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            $filteredInstances = $filterResult -split '\s+' | Where-Object { $_ -match '^i-' }
            $targetInstances += $filteredInstances
            Write-Output "Found $($filteredInstances.Count) instances matching filter"
        } else {
            throw "Failed to filter instances: $filterResult"
        }
    }

    if ($targetInstances.Count -eq 0) {
        throw "No instances specified. Use InstanceId, InstanceIds, or Filter parameter."
    }

    # Remove duplicates
    $targetInstances = $targetInstances | Sort-Object -Unique

    Write-Output "Target instances ($($targetInstances.Count)): $($targetInstances -join ', ')"

    # Handle tags from file
    $tagsToApply = $Tags
    if ($TagsFromFile) {
        if (Test-Path $TagsFromFile) {
            $tagsToApply = Get-Content $TagsFromFile -Raw
        } else {
            throw "Tags file not found: $TagsFromFile"
        }
    }

    switch ($Action) {
        'List' {
            Write-Output "`n📋 Listing tags for instances..."

            foreach ($instance in $targetInstances) {
                Write-Output "`nInstance: $instance"
                Write-Output "-" * 40

                $tagResult = aws ec2 describe-tags --filters "Name=resource-id,Values=$instance" @awsArgs --output json 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $tagData = $tagResult | ConvertFrom-Json

                    if ($tagData.Tags.Count -gt 0) {
                        foreach ($tag in $tagData.Tags) {
                            Write-Output "  $($tag.Key): $($tag.Value)"
                        }
                    } else {
                        Write-Output "  No tags found"
                    }
                } else {
                    Write-Warning "Failed to retrieve tags for $instance : $tagResult"
                }
            }
        }

        'Add' {
            if (-not $TagKey -and -not $tagsToApply) {
                throw "Either TagKey/TagValue or Tags/TagsFromFile must be specified for Add action."
            }

            Write-Output "`n🏷️  Adding tags to instances..."

            foreach ($instance in $targetInstances) {
                Write-Output "Processing instance: $instance"

                # Verify instance exists
                $instanceCheck = aws ec2 describe-instances --instance-ids $instance @awsArgs --output json 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Instance $instance not found or not accessible: $instanceCheck"
                    continue
                }

                if ($TagKey) {
                    # Single tag
                    $tagArgs = @('ec2', 'create-tags', '--resources', $instance, '--tags', "Key=$TagKey,Value=$TagValue")
                    $tagArgs += $awsArgs

                    $result = & aws @tagArgs 2>&1

                    if ($LASTEXITCODE -eq 0) {
                        Write-Output "  ✅ Added tag: $TagKey = $TagValue"
                    } else {
                        Write-Warning "  Failed to add tag to $instance : $result"
                    }
                } elseif ($tagsToApply) {
                    # Multiple tags from JSON
                    try {
                        $null = $tagsToApply | ConvertFrom-Json

                        $tagArgs = @('ec2', 'create-tags', '--resources', $instance, '--tags', $tagsToApply)
                        $tagArgs += $awsArgs

                        $result = & aws @tagArgs 2>&1

                        if ($LASTEXITCODE -eq 0) {
                            Write-Output "  ✅ Added multiple tags successfully"
                        } else {
                            Write-Warning "  Failed to add tags to $instance : $result"
                        }
                    } catch {
                        Write-Warning "  Invalid JSON format for tags: $($_.Exception.Message)"
                    }
                }
            }
        }

        'Remove' {
            if (-not $TagKey) {
                throw "TagKey must be specified for Remove action."
            }

            Write-Output "`n🗑️  Removing tag '$TagKey' from instances..."

            foreach ($instance in $targetInstances) {
                Write-Output "Processing instance: $instance"

                $tagArgs = @('ec2', 'delete-tags', '--resources', $instance, '--tags', "Key=$TagKey")
                $tagArgs += $awsArgs

                $result = & aws @tagArgs 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Output "  ✅ Removed tag: $TagKey"
                } else {
                    Write-Warning "  Failed to remove tag from $instance : $result"
                }
            }
        }

        'Replace' {
            if (-not $tagsToApply) {
                throw "Tags or TagsFromFile must be specified for Replace action."
            }

            Write-Output "`n🔄 Replacing all tags on instances..."
            Write-Warning "This will remove ALL existing tags and replace with new ones!"

            foreach ($instance in $targetInstances) {
                Write-Output "Processing instance: $instance"

                # Get existing tags
                $existingTagsResult = aws ec2 describe-tags --filters "Name=resource-id,Values=$instance" @awsArgs --output json 2>&1

                if ($LASTEXITCODE -eq 0) {
                    $existingTagsData = $existingTagsResult | ConvertFrom-Json

                    # Remove existing tags
                    if ($existingTagsData.Tags.Count -gt 0) {
                        Write-Output "  Removing $($existingTagsData.Tags.Count) existing tags..."

                        foreach ($tag in $existingTagsData.Tags) {
                            $removeArgs = @('ec2', 'delete-tags', '--resources', $instance, '--tags', "Key=$($tag.Key)")
                            $removeArgs += $awsArgs

                            $removeResult = & aws @removeArgs 2>&1
                            if ($LASTEXITCODE -ne 0) {
                                Write-Warning "    Failed to remove tag $($tag.Key): $removeResult"
                            }
                        }
                    }

                    # Add new tags
                    try {
                        $null = $tagsToApply | ConvertFrom-Json

                        $addArgs = @('ec2', 'create-tags', '--resources', $instance, '--tags', $tagsToApply)
                        $addArgs += $awsArgs

                        $addResult = & aws @addArgs 2>&1

                        if ($LASTEXITCODE -eq 0) {
                            Write-Output "  ✅ Replaced tags successfully"
                        } else {
                            Write-Warning "  Failed to add new tags: $addResult"
                        }
                    } catch {
                        Write-Warning "  Invalid JSON format for tags: $($_.Exception.Message)"
                    }
                } else {
                    Write-Warning "Failed to get existing tags for $instance : $existingTagsResult"
                }
            }
        }
    }

    # Summary
    Write-Output "`n📊 Operation Summary:"
    Write-Output "Action: $Action"
    Write-Output "Instances processed: $($targetInstances.Count)"
    Write-Output "Instance IDs: $($targetInstances -join ', ')"

    if ($Action -eq 'List') {
        Write-Output "`n💡 Tip: Use filters for bulk operations:"
        Write-Output "Example: -Filter 'tag:Environment=Production' -Action Add -TagKey 'Backup' -TagValue 'Daily'"
    }

    Write-Output "`n✅ Tag management operation completed."

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
