<#
.SYNOPSIS
    Creates an AWS Budget with a cost alert using the AWS CLI.

.DESCRIPTION
    This script creates a monthly AWS Budget for the specified account and
    configures an alert notification when spend reaches the defined percentage
    of the budget limit. Optionally an email address can be provided to receive
    alert notifications via SNS. Both COST and USAGE budget types are supported.
    Uses the following AWS CLI command:
    aws budgets create-budget

.PARAMETER AccountId
    The 12-digit AWS account ID that owns the budget.

.PARAMETER BudgetName
    The name of the budget.

.PARAMETER BudgetAmount
    The monthly budget limit in USD.

.PARAMETER AlertThresholdPercent
    The percentage of the budget at which an alert is triggered (1-200).
    Defaults to 80.

.PARAMETER NotificationEmail
    Optional email address for budget alert notifications.

.PARAMETER BudgetType
    The type of budget.
    Valid values: COST, USAGE. Defaults to COST.

.EXAMPLE
    .\aws-cli-create-budget.ps1 `
        -AccountId "123456789012" `
        -BudgetName "MonthlyOpsBudget" `
        -BudgetAmount 500 `
        -AlertThresholdPercent 80 `
        -NotificationEmail "ops-team@example.com"

.EXAMPLE
    .\aws-cli-create-budget.ps1 `
        -AccountId "123456789012" `
        -BudgetName "DevTeamBudget" `
        -BudgetAmount 200 `
        -AlertThresholdPercent 100 `
        -BudgetType "COST"

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
    https://docs.aws.amazon.com/cli/latest/reference/budgets/create-budget.html

.COMPONENT
    AWS CLI Monitoring
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The 12-digit AWS account ID that owns the budget.")]
    [ValidatePattern('^\d{12}$')]
    [string]$AccountId,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the budget.")]
    [ValidateNotNullOrEmpty()]
    [string]$BudgetName,

    [Parameter(Mandatory = $true, HelpMessage = "The monthly budget limit in USD.")]
    [double]$BudgetAmount,

    [Parameter(Mandatory = $false, HelpMessage = "The percentage of the budget at which to send an alert (1-200). Defaults to 80.")]
    [ValidateRange(1, 200)]
    [int]$AlertThresholdPercent = 80,

    [Parameter(Mandatory = $false, HelpMessage = "Email address for budget alert notifications.")]
    [string]$NotificationEmail,

    [Parameter(Mandatory = $false, HelpMessage = "The type of budget: COST or USAGE. Defaults to COST.")]
    [ValidateSet('COST', 'USAGE')]
    [string]$BudgetType = 'COST'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Creating AWS Budget: $BudgetName (account: $AccountId)" -ForegroundColor Green

    # Build the budget JSON
    $budgetJson = @{
        BudgetName  = $BudgetName
        BudgetLimit = @{
            Amount = "$BudgetAmount"
            Unit   = 'USD'
        }
        TimeUnit    = 'MONTHLY'
        BudgetType  = $BudgetType
    } | ConvertTo-Json -Compress

    # Build the notifications-with-subscribers JSON
    $subscriber = if ($NotificationEmail) {
        @{
            SubscriptionType = 'EMAIL'
            Address          = $NotificationEmail
        }
    } else {
        @{
            SubscriptionType = 'EMAIL'
            Address          = 'no-reply@example.com'
        }
    }

    $notificationsJson = @(
        @{
            Notification = @{
                NotificationType          = 'ACTUAL'
                ComparisonOperator        = 'GREATER_THAN'
                Threshold                 = $AlertThresholdPercent
                ThresholdType             = 'PERCENTAGE'
                NotificationState         = 'ALARM'
            }
            Subscribers = @($subscriber)
        }
    ) | ConvertTo-Json -Depth 5 -Compress

    Write-Host "🔧 Creating budget..." -ForegroundColor Cyan

    $result = aws budgets create-budget `
        --account-id $AccountId `
        --budget $budgetJson `
        --notifications-with-subscribers $notificationsJson `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create budget: $result"
    }

    Write-Host "✅ AWS Budget created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   BudgetName           : $BudgetName"
    Write-Host "   BudgetType           : $BudgetType"
    Write-Host "   MonthlyLimit         : `$$BudgetAmount USD"
    Write-Host "   AlertThreshold       : $AlertThresholdPercent%"
    if ($NotificationEmail) {
        Write-Host "   NotificationEmail    : $NotificationEmail"
    }

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   View your budgets at: https://console.aws.amazon.com/billing/home#/budgets"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
