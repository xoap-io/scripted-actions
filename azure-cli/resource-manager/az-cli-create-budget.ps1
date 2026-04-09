<#
.SYNOPSIS
    Create an Azure Cost Management budget with email alerts using the Azure CLI.

.DESCRIPTION
    This script creates an Azure Cost Management budget at subscription or resource group scope
    with configurable monthly spend amount and percentage-based email alert notifications,
    using the Azure CLI.
    The script uses the following Azure CLI command:
    az consumption budget create --budget-name $BudgetName --amount $Amount

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group to scope the budget to.
    If omitted, the budget is created at subscription level.

.PARAMETER BudgetName
    Defines the name of the budget.

.PARAMETER Amount
    Defines the monthly budget amount in the account currency.

.PARAMETER StartDate
    Defines the start date of the budget (first day of the month, format: YYYY-MM-DD).
    Defaults to the first day of the current month.

.PARAMETER EndDate
    Defines the end date of the budget (format: YYYY-MM-DD).
    Defaults to one year from the start date.

.PARAMETER AlertThresholdPercent
    Defines the percentage of budget consumption that triggers an alert notification (1-1000). Default: 80.

.PARAMETER NotificationEmail
    Defines an email address to notify when the alert threshold is reached.

.EXAMPLE
    .\az-cli-create-budget.ps1 -BudgetName "monthly-budget" -Amount 1000 -NotificationEmail "admin@example.com"

.EXAMPLE
    .\az-cli-create-budget.ps1 -ResourceGroupName "rg-production" -BudgetName "rg-prod-budget" -Amount 500 -AlertThresholdPercent 90 -NotificationEmail "billing@example.com" -StartDate "2026-04-01" -EndDate "2027-04-01"

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
    https://learn.microsoft.com/en-us/cli/azure/consumption/budget

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The name of the Resource Group to scope the budget to (omit for subscription-level budget)")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the budget")]
    [ValidateNotNullOrEmpty()]
    [string]$BudgetName,

    [Parameter(Mandatory = $true, HelpMessage = "The monthly budget amount in the account currency")]
    [ValidateNotNullOrEmpty()]
    [double]$Amount,

    [Parameter(Mandatory = $false, HelpMessage = "The start date of the budget (YYYY-MM-DD, first day of a month). Defaults to first day of current month.")]
    [ValidateNotNullOrEmpty()]
    [string]$StartDate,

    [Parameter(Mandatory = $false, HelpMessage = "The end date of the budget (YYYY-MM-DD). Defaults to one year from start date.")]
    [ValidateNotNullOrEmpty()]
    [string]$EndDate,

    [Parameter(Mandatory = $false, HelpMessage = "The percentage of budget consumption that triggers an alert (1-1000)")]
    [ValidateRange(1, 1000)]
    [int]$AlertThresholdPercent = 80,

    [Parameter(Mandatory = $false, HelpMessage = "An email address to notify when the alert threshold is reached")]
    [ValidateNotNullOrEmpty()]
    [string]$NotificationEmail
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Azure Cost Management budget '$BudgetName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Default StartDate to the first day of the current month
    if (-not $StartDate) {
        $today = Get-Date
        $StartDate = (Get-Date -Year $today.Year -Month $today.Month -Day 1).ToString('yyyy-MM-dd')
        Write-Host "ℹ️  StartDate not specified. Using: $StartDate" -ForegroundColor Yellow
    }

    # Default EndDate to one year from StartDate
    if (-not $EndDate) {
        $EndDate = ([datetime]::ParseExact($StartDate, 'yyyy-MM-dd', $null)).AddYears(1).ToString('yyyy-MM-dd')
        Write-Host "ℹ️  EndDate not specified. Using: $EndDate" -ForegroundColor Yellow
    }

    # Build the budget create arguments
    $budgetArgs = @(
        'consumption', 'budget', 'create',
        '--budget-name', $BudgetName,
        '--amount', $Amount,
        '--time-grain', 'Monthly',
        '--start-date', $StartDate,
        '--end-date', $EndDate,
        '--output', 'json'
    )

    if ($ResourceGroupName) {
        $budgetArgs += '--resource-group'
        $budgetArgs += $ResourceGroupName
        Write-Host "ℹ️  Creating resource group-scoped budget for: $ResourceGroupName" -ForegroundColor Yellow
    }
    else {
        Write-Host "ℹ️  Creating subscription-level budget." -ForegroundColor Yellow
    }

    if ($NotificationEmail) {
        $budgetArgs += '--threshold'
        $budgetArgs += $AlertThresholdPercent
        $budgetArgs += '--contact-emails'
        $budgetArgs += $NotificationEmail
    }

    # Create the budget
    Write-Host "🔧 Creating budget '$BudgetName' with amount $Amount and $AlertThresholdPercent% alert threshold..." -ForegroundColor Cyan
    $budgetJson = az @budgetArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI consumption budget create command failed with exit code $LASTEXITCODE"
    }

    $budget = $budgetJson | ConvertFrom-Json

    Write-Host "`n✅ Budget '$BudgetName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   BudgetName:           $($budget.name)" -ForegroundColor White
    Write-Host "   Amount:               $($budget.amount) $($budget.timeGrain)" -ForegroundColor White
    Write-Host "   TimeGrain:            $($budget.timeGrain)" -ForegroundColor White
    Write-Host "   StartDate:            $StartDate" -ForegroundColor White
    Write-Host "   EndDate:              $EndDate" -ForegroundColor White
    Write-Host "   AlertThresholdPercent: $AlertThresholdPercent%" -ForegroundColor White

    if ($NotificationEmail) {
        Write-Host "   NotificationEmail:    $NotificationEmail" -ForegroundColor White
    }

    if ($ResourceGroupName) {
        Write-Host "   Scope:                Resource Group: $ResourceGroupName" -ForegroundColor White
    }
    else {
        Write-Host "   Scope:                Subscription" -ForegroundColor White
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
