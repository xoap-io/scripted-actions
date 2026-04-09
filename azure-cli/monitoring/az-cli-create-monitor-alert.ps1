<#
.SYNOPSIS
    Create an Azure Monitor metric alert rule using the Azure CLI.

.DESCRIPTION
    This script creates an Azure Monitor metric alert rule that triggers when a resource
    metric crosses a specified threshold, using the Azure CLI.
    Optionally links an action group for email or webhook notifications.
    The script uses the following Azure CLI command:
    az monitor metrics alert create --resource-group $ResourceGroupName --name $AlertName

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group where the alert rule will be created.

.PARAMETER AlertName
    Defines the name of the metric alert rule.

.PARAMETER TargetResourceId
    Defines the full resource ID of the Azure resource to monitor.

.PARAMETER MetricName
    Defines the name of the metric to monitor (e.g. "Percentage CPU", "Network In Total").

.PARAMETER Operator
    Defines the comparison operator for the alert condition.
    Valid values: GreaterThan, LessThan, GreaterThanOrEqual, LessThanOrEqual. Default: GreaterThan.

.PARAMETER Threshold
    Defines the threshold value that triggers the alert.

.PARAMETER WindowSize
    Defines the period of time used to monitor alert activity (ISO 8601 duration). Default: PT5M (5 minutes).

.PARAMETER Evaluation
    Defines the number of evaluation periods required before the alert fires (1-6). Default: 1.

.PARAMETER Severity
    Defines the severity of the alert (0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose). Default: 2.

.PARAMETER ActionGroupId
    Defines the resource ID of an action group to associate with the alert for notifications.

.EXAMPLE
    .\az-cli-create-monitor-alert.ps1 -ResourceGroupName "rg-monitoring" -AlertName "high-cpu-alert" -TargetResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vms/providers/Microsoft.Compute/virtualMachines/vm-prod-01" -MetricName "Percentage CPU" -Threshold 90

.EXAMPLE
    .\az-cli-create-monitor-alert.ps1 -ResourceGroupName "rg-monitoring" -AlertName "high-cpu-alert" -TargetResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vms/providers/Microsoft.Compute/virtualMachines/vm-prod-01" -MetricName "Percentage CPU" -Operator "GreaterThan" -Threshold 80 -WindowSize "PT15M" -Evaluation 3 -Severity 1 -ActionGroupId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/microsoft.insights/actionGroups/ops-team"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/monitor/metrics/alert

.COMPONENT
    Azure CLI Monitor
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the alert rule will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the metric alert rule")]
    [ValidateNotNullOrEmpty()]
    [string]$AlertName,

    [Parameter(Mandatory = $true, HelpMessage = "The full resource ID of the Azure resource to monitor")]
    [ValidateNotNullOrEmpty()]
    [string]$TargetResourceId,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the metric to monitor (e.g. 'Percentage CPU')")]
    [ValidateNotNullOrEmpty()]
    [string]$MetricName,

    [Parameter(Mandatory = $false, HelpMessage = "The comparison operator for the alert condition")]
    [ValidateSet('GreaterThan', 'LessThan', 'GreaterThanOrEqual', 'LessThanOrEqual')]
    [string]$Operator = 'GreaterThan',

    [Parameter(Mandatory = $true, HelpMessage = "The threshold value that triggers the alert")]
    [ValidateNotNullOrEmpty()]
    [double]$Threshold,

    [Parameter(Mandatory = $false, HelpMessage = "The time window for alert evaluation (ISO 8601 duration, e.g. PT5M, PT15M, PT1H)")]
    [ValidateNotNullOrEmpty()]
    [string]$WindowSize = 'PT5M',

    [Parameter(Mandatory = $false, HelpMessage = "The number of evaluation periods required before the alert fires (1-6)")]
    [ValidateRange(1, 6)]
    [int]$Evaluation = 1,

    [Parameter(Mandatory = $false, HelpMessage = "The severity of the alert (0=Critical, 1=Error, 2=Warning, 3=Informational, 4=Verbose)")]
    [ValidateRange(0, 4)]
    [int]$Severity = 2,

    [Parameter(Mandatory = $false, HelpMessage = "The resource ID of an action group to associate with the alert")]
    [ValidateNotNullOrEmpty()]
    [string]$ActionGroupId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Azure Monitor metric alert '$AlertName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    Write-Host "ℹ️  Alert configuration:" -ForegroundColor Yellow
    Write-Host "   Metric:     $MetricName" -ForegroundColor White
    Write-Host "   Condition:  $Operator $Threshold" -ForegroundColor White
    Write-Host "   Window:     $WindowSize" -ForegroundColor White
    Write-Host "   Evaluation: $Evaluation period(s)" -ForegroundColor White
    Write-Host "   Severity:   $Severity" -ForegroundColor White

    # Build the condition string — include min failing periods when Evaluation > 1
    $conditionBase = "avg `"$MetricName`" $Operator $Threshold"
    $condition = if ($Evaluation -gt 1) {
        "$conditionBase where $Evaluation violations in $Evaluation evaluations"
    }
    else {
        $conditionBase
    }

    # Build the alert create arguments
    $alertArgs = @(
        'monitor', 'metrics', 'alert', 'create',
        '--resource-group', $ResourceGroupName,
        '--name', $AlertName,
        '--scopes', $TargetResourceId,
        '--condition', $condition,
        '--window-size', $WindowSize,
        '--evaluation-frequency', $WindowSize,
        '--severity', $Severity,
        '--output', 'json'
    )

    if ($ActionGroupId) {
        $alertArgs += '--action'
        $alertArgs += $ActionGroupId
        Write-Host "   ActionGroup: $ActionGroupId" -ForegroundColor White
    }

    # Create the alert rule
    Write-Host "🔧 Creating metric alert rule '$AlertName'..." -ForegroundColor Cyan
    $alertJson = az @alertArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI metrics alert create command failed with exit code $LASTEXITCODE"
    }

    $alert = $alertJson | ConvertFrom-Json

    Write-Host "`n✅ Metric alert rule '$AlertName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   AlertName:    $($alert.name)" -ForegroundColor White
    Write-Host "   AlertId:      $($alert.id)" -ForegroundColor White
    Write-Host "   Severity:     $($alert.severity)" -ForegroundColor White
    Write-Host "   Enabled:      $($alert.enabled)" -ForegroundColor White
    Write-Host "   WindowSize:   $($alert.windowSize)" -ForegroundColor White
    Write-Host "   ProvisioningState: $($alert.provisioningState)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
