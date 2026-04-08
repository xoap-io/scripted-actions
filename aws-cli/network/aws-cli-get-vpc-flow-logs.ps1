<#
.SYNOPSIS
    Describes AWS VPC Flow Logs.

.DESCRIPTION
    This script retrieves detailed information about VPC Flow Logs in your AWS account.
    Flow logs capture information about IP traffic going to and from network interfaces in your VPC.
    Uses aws ec2 describe-flow-logs to perform the operation.

.PARAMETER FlowLogIds
    Comma-separated list of specific Flow Log IDs to describe. Must be in the format 'fl-xxxxxxxxx'.

.PARAMETER ResourceId
    Filter flow logs by the resource ID (VPC ID, subnet ID, or network interface ID).

.PARAMETER ResourceType
    Filter by resource type: VPC, Subnet, or NetworkInterface.

.PARAMETER FlowLogStatus
    Filter by flow log status: ACTIVE or INACTIVE.

.PARAMETER TrafficType
    Filter by traffic type: ACCEPT, REJECT, or ALL.

.PARAMETER Profile
    The AWS CLI profile to use for the operation.

.PARAMETER Region
    The AWS region to query for VPC Flow Logs.

.PARAMETER OutputFormat
    The output format for the results (json, table, text, yaml).

.PARAMETER ShowRecommendations
    Show configuration recommendations for flow log optimization.

.EXAMPLE
    .\aws-cli-get-vpc-flow-logs.ps1

.EXAMPLE
    .\aws-cli-get-vpc-flow-logs.ps1 -ResourceId vpc-12345678

.EXAMPLE
    .\aws-cli-get-vpc-flow-logs.ps1 -ResourceType Subnet -TrafficType REJECT

.EXAMPLE
    .\aws-cli-get-vpc-flow-logs.ps1 -FlowLogStatus ACTIVE -ShowRecommendations

.EXAMPLE
    .\aws-cli-get-vpc-flow-logs.ps1 -FlowLogIds fl-12345678,fl-87654321

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

    IMPORTANT NOTES:
    - Flow logs can be configured at VPC, subnet, or network interface level
    - Logs are delivered to CloudWatch Logs, S3, or Kinesis Data Firehose
    - Flow logs do not capture all traffic (e.g., DHCP, DNS to Amazon DNS resolver)
    - There are charges for flow log data ingestion and storage

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-flow-logs.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Specific Flow Log IDs to describe")]
    [ValidatePattern('^fl-[a-zA-Z0-9]+(,fl-[a-zA-Z0-9]+)*$')]
    [string]$FlowLogIds,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by resource ID (VPC, subnet, or network interface)")]
    [string]$ResourceId,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by resource type")]
    [ValidateSet('VPC', 'Subnet', 'NetworkInterface')]
    [string]$ResourceType,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by flow log status")]
    [ValidateSet('ACTIVE', 'INACTIVE')]
    [string]$FlowLogStatus,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by traffic type")]
    [ValidateSet('ACCEPT', 'REJECT', 'ALL')]
    [string]$TrafficType,

    [Parameter(Mandatory = $false, HelpMessage = "AWS CLI profile to use")]
    [string]$Profile,

    [Parameter(Mandatory = $false, HelpMessage = "AWS region")]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('json', 'table', 'text', 'yaml')]
    [string]$OutputFormat = 'table',

    [Parameter(Mandatory = $false, HelpMessage = "Show configuration recommendations")]
    [switch]$ShowRecommendations
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving VPC Flow Log information..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @('ec2', 'describe-flow-logs')

    if ($FlowLogIds) {
        $logArray = $FlowLogIds -split ','
        $awsArgs += @('--flow-log-ids')
        $awsArgs += $logArray
    }

    # Build filters array
    $filters = @()

    if ($ResourceId) {
        $filters += "Name=resource-id,Values=$ResourceId"
    }

    if ($ResourceType) {
        $filters += "Name=resource-type,Values=$ResourceType"
    }

    if ($FlowLogStatus) {
        $filters += "Name=flow-log-status,Values=$FlowLogStatus"
    }

    if ($TrafficType) {
        $filters += "Name=traffic-type,Values=$TrafficType"
    }

    if ($filters.Count -gt 0) {
        $awsArgs += @('--filters')
        $awsArgs += $filters
    }

    if ($Profile) {
        $awsArgs += @('--profile', $Profile)
    }

    if ($Region) {
        $awsArgs += @('--region', $Region)
    }

    # Execute the AWS CLI command
    $result = & aws @awsArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe VPC Flow Logs: $result"
    }

    $flowLogInfo = $result | ConvertFrom-Json

    if ($OutputFormat -eq 'json') {
        # Output raw JSON
        $result
        return
    }

    if ($flowLogInfo.FlowLogs.Count -eq 0) {
        Write-Host "No VPC Flow Logs found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    # Display summary
    Write-Host "`nVPC Flow Logs Summary:" -ForegroundColor Cyan
    Write-Host "Total flow logs found: $($flowLogInfo.FlowLogs.Count)" -ForegroundColor White

    # Categorize flow logs
    $activeFlowLogs = $flowLogInfo.FlowLogs | Where-Object { $_.FlowLogStatus -eq 'ACTIVE' }
    $inactiveFlowLogs = $flowLogInfo.FlowLogs | Where-Object { $_.FlowLogStatus -eq 'INACTIVE' }

    Write-Host "  Active: $($activeFlowLogs.Count)" -ForegroundColor Green
    Write-Host "  Inactive: $($inactiveFlowLogs.Count)" -ForegroundColor Yellow

    # Group by resource type
    $byResourceType = $flowLogInfo.FlowLogs | Group-Object ResourceType
    foreach ($group in $byResourceType) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Group by traffic type
    $byTrafficType = $flowLogInfo.FlowLogs | Group-Object TrafficType
    Write-Host "`nBy Traffic Type:" -ForegroundColor Cyan
    foreach ($group in $byTrafficType) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor White
    }

    # Display detailed information for each flow log
    foreach ($flowLog in $flowLogInfo.FlowLogs) {
        Write-Host "`n" + "="*60 -ForegroundColor Gray
        Write-Host "Flow Log: $($flowLog.FlowLogId)" -ForegroundColor Cyan

        # Status
        $statusColor = if ($flowLog.FlowLogStatus -eq 'ACTIVE') { 'Green' } else { 'Yellow' }
        Write-Host "  Status: $($flowLog.FlowLogStatus)" -ForegroundColor $statusColor

        # Resource information
        Write-Host "  Resource ID: $($flowLog.ResourceId)" -ForegroundColor White
        Write-Host "  Resource Type: $($flowLog.ResourceType)" -ForegroundColor White
        Write-Host "  Traffic Type: $($flowLog.TrafficType)" -ForegroundColor White

        # Destination information
        Write-Host "`n  Destination Configuration:" -ForegroundColor Yellow
        Write-Host "    Log Destination Type: $($flowLog.LogDestinationType)" -ForegroundColor White

        if ($flowLog.LogDestination) {
            Write-Host "    Log Destination: $($flowLog.LogDestination)" -ForegroundColor White
        }

        if ($flowLog.LogGroupName) {
            Write-Host "    CloudWatch Log Group: $($flowLog.LogGroupName)" -ForegroundColor White
        }

        if ($flowLog.DeliverLogsPermissionArn) {
            Write-Host "    IAM Role ARN: $($flowLog.DeliverLogsPermissionArn)" -ForegroundColor White
        }

        # Format information
        if ($flowLog.LogFormat) {
            Write-Host "`n  Log Format:" -ForegroundColor Yellow
            Write-Host "    $($flowLog.LogFormat)" -ForegroundColor Gray
        }

        # Timestamps
        Write-Host "`n  Timeline:" -ForegroundColor Yellow
        Write-Host "    Creation Time: $($flowLog.CreationTime)" -ForegroundColor White

        if ($flowLog.FlowLogStatus -eq 'INACTIVE' -and $flowLog.DeliverLogsErrorMessage) {
            Write-Host "    Error Message: $($flowLog.DeliverLogsErrorMessage)" -ForegroundColor Red
        }

        # Display tags if present
        if ($flowLog.Tags -and $flowLog.Tags.Count -gt 0) {
            Write-Host "`n  Tags:" -ForegroundColor Yellow
            foreach ($tag in $flowLog.Tags) {
                Write-Host "    $($tag.Key): $($tag.Value)" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n" + "="*60 -ForegroundColor Gray

    # Show recommendations if requested
    if ($ShowRecommendations) {
        Write-Host "`nConfiguration Recommendations:" -ForegroundColor Cyan

        # Check for missing flow logs
        Write-Host "`n1. Coverage Analysis:" -ForegroundColor Yellow
        Write-Host "   - Consider enabling flow logs at VPC level for comprehensive coverage" -ForegroundColor White
        Write-Host "   - Subnet-level logs for granular analysis of specific network segments" -ForegroundColor White
        Write-Host "   - Network interface-level logs for detailed instance traffic analysis" -ForegroundColor White

        # Traffic type recommendations
        Write-Host "`n2. Traffic Type Configuration:" -ForegroundColor Yellow
        $allTrafficLogs = $flowLogInfo.FlowLogs | Where-Object { $_.TrafficType -eq 'ALL' }
        $rejectOnlyLogs = $flowLogInfo.FlowLogs | Where-Object { $_.TrafficType -eq 'REJECT' }

        if ($rejectOnlyLogs.Count -gt 0 -and $allTrafficLogs.Count -eq 0) {
            Write-Host "   - Consider enabling 'ALL' traffic logging for complete visibility" -ForegroundColor Yellow
        }

        Write-Host "   - 'ALL': Complete traffic visibility (higher cost)" -ForegroundColor White
        Write-Host "   - 'REJECT': Security-focused logging (lower cost)" -ForegroundColor White
        Write-Host "   - 'ACCEPT': Successful connections only" -ForegroundColor White

        # Destination recommendations
        Write-Host "`n3. Destination Optimization:" -ForegroundColor Yellow
        $s3Logs = $flowLogInfo.FlowLogs | Where-Object { $_.LogDestinationType -eq 's3' }
        $cloudWatchLogs = $flowLogInfo.FlowLogs | Where-Object { $_.LogDestinationType -eq 'cloud-watch-logs' }

        Write-Host "   - S3: Cost-effective for long-term storage and analysis ($($s3Logs.Count) configured)" -ForegroundColor White
        Write-Host "   - CloudWatch Logs: Real-time monitoring and alerting ($($cloudWatchLogs.Count) configured)" -ForegroundColor White
        Write-Host "   - Kinesis Data Firehose: Stream processing and transformation" -ForegroundColor White

        # Cost optimization
        Write-Host "`n4. Cost Optimization:" -ForegroundColor Yellow
        Write-Host "   - Use custom log formats to reduce data volume and costs" -ForegroundColor White
        Write-Host "   - Implement log retention policies to manage storage costs" -ForegroundColor White
        Write-Host "   - Consider sampling for high-volume environments" -ForegroundColor White

        # Security recommendations
        Write-Host "`n5. Security Best Practices:" -ForegroundColor Yellow
        Write-Host "   - Enable flow logs for all VPCs to detect anomalous traffic" -ForegroundColor White
        Write-Host "   - Use 'REJECT' logs to identify potential security threats" -ForegroundColor White
        Write-Host "   - Set up CloudWatch alarms for suspicious traffic patterns" -ForegroundColor White
    }

    # Show inactive flow logs
    if ($inactiveFlowLogs.Count -gt 0) {
        Write-Host "`nInactive Flow Logs (require attention):" -ForegroundColor Red
        foreach ($inactive in $inactiveFlowLogs) {
            Write-Host "  $($inactive.FlowLogId) - Resource: $($inactive.ResourceId)" -ForegroundColor Yellow
            if ($inactive.DeliverLogsErrorMessage) {
                Write-Host "    Error: $($inactive.DeliverLogsErrorMessage)" -ForegroundColor Red
            }
        }
    }

    # Common management commands
    Write-Host "`nManagement Commands:" -ForegroundColor Cyan
    Write-Host "Create flow log: aws ec2 create-flow-logs --resource-type <type> --resource-ids <id> --traffic-type ALL --log-destination-type s3 --log-destination <s3-arn>" -ForegroundColor Gray
    Write-Host "Delete flow log: aws ec2 delete-flow-logs --flow-log-ids <flow-log-id>" -ForegroundColor Gray
    Write-Host "Query CloudWatch Logs: aws logs filter-log-events --log-group-name <group-name> --start-time <timestamp>" -ForegroundColor Gray

    if (-not $ShowRecommendations) {
        Write-Host "`nTip: Use -ShowRecommendations switch for configuration optimization guidance." -ForegroundColor Cyan
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
