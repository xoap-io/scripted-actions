<#
.SYNOPSIS
    Attach or detach IAM instance profiles to/from EC2 instances using AWS CLI.

.DESCRIPTION
    This script provides comprehensive management of IAM instance profiles for EC2 instances,
    including attaching, detaching, replacing profiles, and validating permissions.

.PARAMETER InstanceId
    The ID of the EC2 instance to modify.

.PARAMETER InstanceIds
    Comma-separated list of instance IDs for bulk operations.

.PARAMETER IamInstanceProfile
    The name or ARN of the IAM instance profile to attach.

.PARAMETER Action
    The action to perform: Attach, Detach, Replace, or Describe.

.PARAMETER Force
    Force the operation without confirmation prompts.

.PARAMETER ValidatePermissions
    Validate that the instance profile has basic EC2 permissions.

.PARAMETER WaitForAssociation
    Wait for the association to complete before returning.

.PARAMETER MaxWaitTime
    Maximum time to wait for association in seconds (default: 120).

.PARAMETER DryRun
    Perform a dry run to validate parameters without making changes.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-attach-instance-profile.ps1 -InstanceId "i-1234567890abcdef0" -IamInstanceProfile "EC2-SSM-Role" -Action "Attach"

.EXAMPLE
    .\aws-cli-attach-instance-profile.ps1 -InstanceIds "i-123,i-456" -IamInstanceProfile "EC2-Default-Role" -Action "Attach" -Force

.EXAMPLE
    .\aws-cli-attach-instance-profile.ps1 -InstanceId "i-1234567890abcdef0" -Action "Detach"

.EXAMPLE
    .\aws-cli-attach-instance-profile.ps1 -InstanceId "i-1234567890abcdef0" -IamInstanceProfile "NewRole" -Action "Replace" -WaitForAssociation

.EXAMPLE
    .\aws-cli-attach-instance-profile.ps1 -InstanceId "i-1234567890abcdef0" -Action "Describe"

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
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $false)]
    [string]$InstanceIds,

    [Parameter(Mandatory = $false)]
    [string]$IamInstanceProfile,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Attach', 'Detach', 'Replace', 'Describe')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$ValidatePermissions,

    [Parameter(Mandatory = $false)]
    [switch]$WaitForAssociation,

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 600)]
    [int]$MaxWaitTime = 120,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

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
    if ($DryRun) { $awsArgs += @('--dry-run') }

    Write-Output "🔐 Managing IAM Instance Profiles for EC2"
    Write-Output "Action: $Action"
    if ($Region) { Write-Output "Region: $Region" }
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Determine target instances
    $targetInstances = @()
    if ($InstanceId) {
        $targetInstances += $InstanceId
    }
    if ($InstanceIds) {
        $targetInstances += $InstanceIds -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($targetInstances.Count -eq 0 -and $Action -ne 'Describe') {
        throw "Either InstanceId or InstanceIds must be specified for $Action action."
    }

    # Function to validate instance profile
    function Test-InstanceProfile {
        param([string]$ProfileName)
        
        Write-Output "🔍 Validating instance profile: $ProfileName"
        
        # Check if instance profile exists
        $profileResult = aws iam get-instance-profile --instance-profile-name $ProfileName @awsArgs --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Instance profile '$ProfileName' not found or not accessible"
            return $false
        }

        $profileData = $profileResult | ConvertFrom-Json
        $instanceProfile = $profileData.InstanceProfile
        
        Write-Output "✅ Instance profile found:"
        Write-Output "  Name: $($instanceProfile.InstanceProfileName)"
        Write-Output "  ARN: $($instanceProfile.Arn)"
        Write-Output "  Created: $($instanceProfile.CreateDate)"
        
        if ($instanceProfile.Roles -and $instanceProfile.Roles.Count -gt 0) {
            Write-Output "  Attached Roles: $($instanceProfile.Roles.Count)"
            foreach ($role in $instanceProfile.Roles) {
                Write-Output "    • $($role.RoleName)"
            }
        } else {
            Write-Warning "  ⚠️  No roles attached to this instance profile"
        }

        # Validate permissions if requested
        if ($ValidatePermissions -and $instanceProfile.Roles.Count -gt 0) {
            Write-Output "`n🔍 Validating role permissions..."
            
            foreach ($role in $instanceProfile.Roles) {
                $policiesResult = aws iam list-attached-role-policies --role-name $role.RoleName @awsArgs --output json 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $policiesData = $policiesResult | ConvertFrom-Json
                    
                    Write-Output "  Role: $($role.RoleName)"
                    Write-Output "    Attached Policies: $($policiesData.AttachedPolicies.Count)"
                    
                    foreach ($policy in $policiesData.AttachedPolicies) {
                        Write-Output "      • $($policy.PolicyName)"
                    }
                    
                    # Check for common EC2 policies
                    $commonPolicies = @('AmazonSSMManagedInstanceCore', 'CloudWatchAgentServerPolicy', 'AmazonEC2ReadOnlyAccess')
                    $foundPolicies = $policiesData.AttachedPolicies | Where-Object { $_.PolicyName -in $commonPolicies }
                    
                    if ($foundPolicies.Count -gt 0) {
                        Write-Output "    ✅ Common EC2 policies found: $($foundPolicies.Count)"
                    } else {
                        Write-Output "    ⚠️  No common EC2 policies detected"
                    }
                }
            }
        }

        return $true
    }

    # Function to get current instance profile association
    function Get-InstanceProfileAssociation {
        param([string]$InstanceId)
        
        $associationResult = aws ec2 describe-iam-instance-profile-associations --filters "Name=instance-id,Values=$InstanceId" @awsArgs --output json 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $associationData = $associationResult | ConvertFrom-Json
            if ($associationData.IamInstanceProfileAssociations.Count -gt 0) {
                return $associationData.IamInstanceProfileAssociations[0]
            }
        }
        
        return $null
    }

    # Function to wait for association completion
    function Wait-ForAssociation {
        param([string]$AssociationId, [string]$InstanceId)
        
        Write-Output "⏳ Waiting for association to complete..."
        $waitTime = 0
        $checkInterval = 10
        
        do {
            Start-Sleep -Seconds $checkInterval
            $waitTime += $checkInterval
            
            $statusResult = aws ec2 describe-iam-instance-profile-associations --association-ids $AssociationId @awsArgs --query 'IamInstanceProfileAssociations[0].State' --output text 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                $state = $statusResult.Trim()
                Write-Output "[$([math]::Round($waitTime/60, 1)) min] Association state: $state"
                
                if ($state -eq 'associated') {
                    Write-Output "✅ Association completed successfully"
                    return $true
                } elseif ($state -eq 'association-failed') {
                    Write-Warning "❌ Association failed"
                    return $false
                }
            }
            
        } while ($waitTime -lt $MaxWaitTime)
        
        Write-Warning "⏰ Association monitoring timed out after $($MaxWaitTime/60) minutes"
        return $false
    }

    switch ($Action) {
        'Attach' {
            if (-not $IamInstanceProfile) {
                throw "IamInstanceProfile is required for Attach action."
            }

            # Validate the instance profile first
            if (-not (Test-InstanceProfile -ProfileName $IamInstanceProfile)) {
                exit 1
            }

            Write-Output "`n🔗 Attaching instance profile to instances..."

            foreach ($instanceId in $targetInstances) {
                Write-Output "`n" + "=" * 50
                Write-Output "Processing instance: $instanceId"

                # Check if instance exists and get current state
                $instanceResult = aws ec2 describe-instances --instance-ids $instanceId @awsArgs --query 'Reservations[0].Instances[0].[State.Name,InstanceType]' --output text 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Instance $instanceId not found or not accessible"
                    continue
                }

                $instanceInfo = $instanceResult.Trim() -split "`t"
                Write-Output "Instance state: $($instanceInfo[0])"
                Write-Output "Instance type: $($instanceInfo[1])"

                # Check for existing association
                $existingAssociation = Get-InstanceProfileAssociation -InstanceId $instanceId
                
                if ($existingAssociation) {
                    Write-Warning "⚠️  Instance already has an instance profile attached:"
                    Write-Output "  Profile: $($existingAssociation.IamInstanceProfile.Arn)"
                    Write-Output "  State: $($existingAssociation.State)"
                    
                    if (-not $Force) {
                        $confirmation = Read-Host "Replace existing profile? (y/N)"
                        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                            Write-Output "Skipping instance $instanceId"
                            continue
                        }
                    }
                    
                    # Detach existing profile first
                    Write-Output "🔄 Replacing existing instance profile..."
                    $replaceResult = aws ec2 replace-iam-instance-profile-association --association-id $existingAssociation.AssociationId --iam-instance-profile Name=$IamInstanceProfile @awsArgs --output json 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $replaceData = $replaceResult | ConvertFrom-Json
                        Write-Output "✅ Instance profile replacement initiated"
                        Write-Output "Association ID: $($replaceData.IamInstanceProfileAssociation.AssociationId)"
                        
                        if ($WaitForAssociation) {
                            Wait-ForAssociation -AssociationId $replaceData.IamInstanceProfileAssociation.AssociationId -InstanceId $instanceId
                        }
                    } else {
                        Write-Warning "Failed to replace instance profile: $replaceResult"
                    }
                } else {
                    # Attach new profile
                    Write-Output "🔗 Attaching instance profile..."
                    $attachResult = aws ec2 associate-iam-instance-profile --instance-id $instanceId --iam-instance-profile Name=$IamInstanceProfile @awsArgs --output json 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $attachData = $attachResult | ConvertFrom-Json
                        Write-Output "✅ Instance profile attachment initiated"
                        Write-Output "Association ID: $($attachData.IamInstanceProfileAssociation.AssociationId)"
                        Write-Output "State: $($attachData.IamInstanceProfileAssociation.State)"
                        
                        if ($WaitForAssociation) {
                            Wait-ForAssociation -AssociationId $attachData.IamInstanceProfileAssociation.AssociationId -InstanceId $instanceId
                        }
                    } else {
                        Write-Warning "Failed to attach instance profile to $instanceId : $attachResult"
                    }
                }
            }
        }

        'Detach' {
            Write-Output "`n🔓 Detaching instance profiles from instances..."

            foreach ($instanceId in $targetInstances) {
                Write-Output "`n" + "=" * 50
                Write-Output "Processing instance: $instanceId"

                # Get current association
                $association = Get-InstanceProfileAssociation -InstanceId $instanceId
                
                if (-not $association) {
                    Write-Output "ℹ️  No instance profile attached to instance $instanceId"
                    continue
                }

                Write-Output "Current profile: $($association.IamInstanceProfile.Arn)"
                Write-Output "Association state: $($association.State)"

                # Confirmation prompt
                if (-not $Force) {
                    Write-Output "⚠️  You are about to detach the instance profile from instance: $instanceId"
                    $confirmation = Read-Host "Are you sure you want to continue? (y/N)"
                    
                    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                        Write-Output "Skipping instance $instanceId"
                        continue
                    }
                }

                # Detach the profile
                $detachResult = aws ec2 disassociate-iam-instance-profile --association-id $association.AssociationId @awsArgs --output json 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Output "✅ Instance profile detachment initiated"
                    Write-Output "Association ID: $($association.AssociationId)"
                } else {
                    Write-Warning "Failed to detach instance profile from $instanceId : $detachResult"
                }
            }
        }

        'Replace' {
            if (-not $IamInstanceProfile) {
                throw "IamInstanceProfile is required for Replace action."
            }

            # Validate the new instance profile
            if (-not (Test-InstanceProfile -ProfileName $IamInstanceProfile)) {
                exit 1
            }

            Write-Output "`n🔄 Replacing instance profiles..."

            foreach ($instanceId in $targetInstances) {
                Write-Output "`n" + "=" * 50
                Write-Output "Processing instance: $instanceId"

                # Get current association
                $association = Get-InstanceProfileAssociation -InstanceId $instanceId
                
                if (-not $association) {
                    Write-Output "ℹ️  No instance profile currently attached. Attaching new profile..."
                    
                    $attachResult = aws ec2 associate-iam-instance-profile --instance-id $instanceId --iam-instance-profile Name=$IamInstanceProfile @awsArgs --output json 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $attachData = $attachResult | ConvertFrom-Json
                        Write-Output "✅ Instance profile attached"
                        Write-Output "Association ID: $($attachData.IamInstanceProfileAssociation.AssociationId)"
                        
                        if ($WaitForAssociation) {
                            Wait-ForAssociation -AssociationId $attachData.IamInstanceProfileAssociation.AssociationId -InstanceId $instanceId
                        }
                    } else {
                        Write-Warning "Failed to attach instance profile: $attachResult"
                    }
                } else {
                    Write-Output "Current profile: $($association.IamInstanceProfile.Arn)"
                    Write-Output "Replacing with: $IamInstanceProfile"

                    # Replace the profile
                    $replaceResult = aws ec2 replace-iam-instance-profile-association --association-id $association.AssociationId --iam-instance-profile Name=$IamInstanceProfile @awsArgs --output json 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $replaceData = $replaceResult | ConvertFrom-Json
                        Write-Output "✅ Instance profile replacement initiated"
                        Write-Output "New Association ID: $($replaceData.IamInstanceProfileAssociation.AssociationId)"
                        
                        if ($WaitForAssociation) {
                            Wait-ForAssociation -AssociationId $replaceData.IamInstanceProfileAssociation.AssociationId -InstanceId $instanceId
                        }
                    } else {
                        Write-Warning "Failed to replace instance profile: $replaceResult"
                    }
                }
            }
        }

        'Describe' {
            if ($targetInstances.Count -eq 0) {
                # Describe all associations in the region
                Write-Output "`n📋 Describing all IAM instance profile associations..."
                
                $allAssociationsResult = aws ec2 describe-iam-instance-profile-associations @awsArgs --output json 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $allAssociationsData = $allAssociationsResult | ConvertFrom-Json
                    
                    if ($allAssociationsData.IamInstanceProfileAssociations.Count -eq 0) {
                        Write-Output "No IAM instance profile associations found in this region"
                        exit 0
                    }

                    Write-Output "`n📊 All IAM Instance Profile Associations ($($allAssociationsData.IamInstanceProfileAssociations.Count)):"
                    Write-Output "=" * 100
                    Write-Output "Instance ID`t`tProfile Name`t`t`tState`t`tAssociation ID"
                    Write-Output "-" * 100

                    foreach ($assoc in $allAssociationsData.IamInstanceProfileAssociations) {
                        $profileName = $assoc.IamInstanceProfile.Arn -replace '.*/([^/]+)$', '$1'
                        Write-Output "$($assoc.InstanceId)`t$($profileName.PadRight(25))`t$($assoc.State.PadRight(15))`t$($assoc.AssociationId)"
                    }

                    # Summary by state
                    $stateGroups = $allAssociationsData.IamInstanceProfileAssociations | Group-Object State
                    Write-Output "`n📈 Summary by State:"
                    foreach ($group in $stateGroups) {
                        Write-Output "  • $($group.Name): $($group.Count) associations"
                    }
                }
            } else {
                # Describe specific instances
                Write-Output "`n📋 Describing instance profile associations for specified instances..."

                foreach ($instanceId in $targetInstances) {
                    Write-Output "`n" + "=" * 60
                    Write-Output "Instance: $instanceId"

                    # Get instance details
                    $instanceResult = aws ec2 describe-instances --instance-ids $instanceId @awsArgs --query 'Reservations[0].Instances[0].[State.Name,InstanceType,LaunchTime]' --output text 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $instanceInfo = $instanceResult.Trim() -split "`t"
                        Write-Output "State: $($instanceInfo[0])"
                        Write-Output "Type: $($instanceInfo[1])"
                        Write-Output "Launch Time: $($instanceInfo[2])"
                    }

                    # Get association details
                    $association = Get-InstanceProfileAssociation -InstanceId $instanceId
                    
                    if ($association) {
                        Write-Output "`n🔐 IAM Instance Profile Association:"
                        Write-Output "Profile ARN: $($association.IamInstanceProfile.Arn)"
                        Write-Output "Association ID: $($association.AssociationId)"
                        Write-Output "State: $($association.State)"
                        Write-Output "Associated Time: $($association.Timestamp)"

                        # Get profile details
                        $profileName = $association.IamInstanceProfile.Arn -replace '.*/([^/]+)$', '$1'
                        Test-InstanceProfile -ProfileName $profileName
                    } else {
                        Write-Output "`n🔓 No IAM instance profile associated with this instance"
                        Write-Output "💡 Consider attaching an instance profile for:"
                        Write-Output "  • Systems Manager access"
                        Write-Output "  • CloudWatch monitoring"
                        Write-Output "  • S3 access"
                        Write-Output "  • Other AWS service integrations"
                    }
                }
            }
        }
    }

    Write-Output "`n✅ IAM instance profile operation completed successfully."

} catch {
    Write-Error "Failed to manage IAM instance profile: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
