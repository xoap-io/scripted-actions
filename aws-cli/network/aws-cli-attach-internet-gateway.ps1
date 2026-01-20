<#
.SYNOPSIS
    Attaches an Internet Gateway to a VPC using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script attaches an existing Internet Gateway to a VPC, enabling internet connectivity
    for the VPC. Includes validation and comprehensive error handling.

.PARAMETER InternetGatewayId
    The ID of the Internet Gateway to attach.

.PARAMETER VpcId
    The ID of the VPC to attach the Internet Gateway to.

.PARAMETER DryRun
    Perform a dry run to validate parameters without making changes.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER Profile
    The AWS CLI profile to use (optional).

.EXAMPLE
    .\aws-cli-attach-internet-gateway.ps1 -InternetGatewayId "igw-12345678" -VpcId "vpc-12345678"

.EXAMPLE
    .\aws-cli-attach-internet-gateway.ps1 -InternetGatewayId "igw-12345678" -VpcId "vpc-12345678" -DryRun

.NOTES
    Author: XOAP
    Date: 2025-08-06

    Requires: AWS CLI v2.16+

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^igw-[a-zA-Z0-9]{8,}$')]
    [string]$InternetGatewayId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

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

    Write-Output "🌐 Attaching Internet Gateway to VPC"
    Write-Output "Internet Gateway: $InternetGatewayId"
    Write-Output "VPC: $VpcId"
    if ($DryRun) { Write-Output "Mode: DRY RUN - No changes will be made" }

    # Verify Internet Gateway exists and get current state
    Write-Output "`n🔍 Verifying Internet Gateway..."
    $igwResult = aws ec2 describe-internet-gateways --internet-gateway-ids $InternetGatewayId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Internet Gateway $InternetGatewayId not found or not accessible: $igwResult"
    }

    $igwData = $igwResult | ConvertFrom-Json
    $internetGateway = $igwData.InternetGateways[0]

    Write-Output "✅ Internet Gateway verified:"
    Write-Output "  State: $($internetGateway.State)"
    Write-Output "  Owner ID: $($internetGateway.OwnerId)"

    # Check current attachments
    if ($internetGateway.Attachments -and $internetGateway.Attachments.Count -gt 0) {
        Write-Output "  Current attachments: $($internetGateway.Attachments.Count)"
        foreach ($attachment in $internetGateway.Attachments) {
            Write-Output "    • VPC: $($attachment.VpcId) (State: $($attachment.State))"

            if ($attachment.VpcId -eq $VpcId) {
                if ($attachment.State -eq 'attached') {
                    Write-Output "⚠️  Internet Gateway is already attached to this VPC"
                    if (-not $DryRun) {
                        Write-Output "✅ No action needed - attachment already exists"
                        exit 0
                    } else {
                        Write-Output "ℹ️  DRY RUN: Would skip - already attached"
                        exit 0
                    }
                } elseif ($attachment.State -eq 'attaching') {
                    Write-Output "⏳ Internet Gateway is currently being attached to this VPC"
                    exit 0
                }
            }
        }

        # Check if IGW is attached to a different VPC
        $otherAttachments = $internetGateway.Attachments | Where-Object { $_.VpcId -ne $VpcId -and $_.State -eq 'attached' }
        if ($otherAttachments.Count -gt 0) {
            Write-Warning "⚠️  Internet Gateway is attached to other VPCs:"
            foreach ($attachment in $otherAttachments) {
                Write-Output "    • VPC: $($attachment.VpcId)"
            }
            throw "An Internet Gateway can only be attached to one VPC at a time. Detach from other VPCs first."
        }
    } else {
        Write-Output "  Current attachments: None"
    }

    # Verify VPC exists
    Write-Output "`n🔍 Verifying VPC..."
    $vpcResult = aws ec2 describe-vpcs --vpc-ids $VpcId @awsArgs --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "VPC $VpcId not found or not accessible: $vpcResult"
    }

    $vpcData = $vpcResult | ConvertFrom-Json
    $vpc = $vpcData.Vpcs[0]

    Write-Output "✅ VPC verified:"
    Write-Output "  State: $($vpc.State)"
    Write-Output "  CIDR Block: $($vpc.CidrBlock)"
    Write-Output "  Default: $($vpc.IsDefault)"

    # Check if VPC already has an Internet Gateway attached
    $vpcIgwResult = aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VpcId" @awsArgs --output json 2>&1

    if ($LASTEXITCODE -eq 0) {
        $vpcIgwData = $vpcIgwResult | ConvertFrom-Json

        if ($vpcIgwData.InternetGateways.Count -gt 0) {
            $existingIgw = $vpcIgwData.InternetGateways[0]
            if ($existingIgw.InternetGatewayId -ne $InternetGatewayId) {
                Write-Warning "⚠️  VPC already has a different Internet Gateway attached:"
                Write-Output "    Existing IGW: $($existingIgw.InternetGatewayId)"
                throw "VPC can only have one Internet Gateway attached. Detach the existing one first."
            }
        }
    }

    # Attach the Internet Gateway
    if (-not $DryRun) {
        Write-Output "`n🔗 Attaching Internet Gateway to VPC..."
        $attachResult = aws ec2 attach-internet-gateway --internet-gateway-id $InternetGatewayId --vpc-id $VpcId @awsArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Output "✅ Internet Gateway attachment initiated successfully!"

            # Verify the attachment
            Write-Output "`n🔍 Verifying attachment..."
            Start-Sleep -Seconds 2

            $verifyResult = aws ec2 describe-internet-gateways --internet-gateway-ids $InternetGatewayId @awsArgs --output json 2>&1

            if ($LASTEXITCODE -eq 0) {
                $verifyData = $verifyResult | ConvertFrom-Json
                $verifiedIgw = $verifyData.InternetGateways[0]

                $attachment = $verifiedIgw.Attachments | Where-Object { $_.VpcId -eq $VpcId }

                if ($attachment) {
                    Write-Output "✅ Attachment verified:"
                    Write-Output "  VPC ID: $($attachment.VpcId)"
                    Write-Output "  State: $($attachment.State)"

                    if ($attachment.State -eq 'attached') {
                        Write-Output "🎉 Internet Gateway successfully attached!"
                    } elseif ($attachment.State -eq 'attaching') {
                        Write-Output "⏳ Attachment in progress..."
                    }
                } else {
                    Write-Warning "⚠️  Attachment not found in verification"
                }
            }

            Write-Output "`n💡 Next Steps:"
            Write-Output "• Update route tables to route traffic (0.0.0.0/0) to the Internet Gateway"
            Write-Output "• Ensure subnets have 'Auto-assign public IP' enabled for internet access"
            Write-Output "• Configure security groups to allow appropriate inbound/outbound traffic"
            Write-Output "• Consider creating NAT Gateways for private subnet internet access"

            Write-Output "`n📋 Useful Commands:"
            Write-Output "# Add route to route table:"
            Write-Output "aws ec2 create-route --route-table-id rtb-xxxxxxxx --destination-cidr-block 0.0.0.0/0 --gateway-id $InternetGatewayId"
            Write-Output ""
            Write-Output "# Enable auto-assign public IP for subnet:"
            Write-Output "aws ec2 modify-subnet-attribute --subnet-id subnet-xxxxxxxx --map-public-ip-on-launch"

        } else {
            Write-Error "Failed to attach Internet Gateway: $attachResult"
        }
    } else {
        Write-Output "`n✅ DRY RUN: Internet Gateway attachment command validated successfully"
        Write-Output "Command that would be executed:"
        Write-Output "aws ec2 attach-internet-gateway --internet-gateway-id $InternetGatewayId --vpc-id $VpcId"
    }

} catch {
    Write-Error "Failed to attach Internet Gateway: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Output "Script execution completed."
}
