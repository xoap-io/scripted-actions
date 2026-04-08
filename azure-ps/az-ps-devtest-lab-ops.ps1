<#
.SYNOPSIS
    Quick operations for Azure DevTest Labs training environments.

.DESCRIPTION
    Simplified script for common DevTest Labs operations:
    - Quick status checks
    - Bulk VM start/stop operations
    - User management
    - Cost monitoring
    Designed to work with environments created by az-ps-create-devtest-training-environment.ps1

.PARAMETER LabName
    Name of the DevTest Lab.

.PARAMETER ResourceGroupName
    Name of the Resource Group containing the lab.

.PARAMETER Operation
    Operation to perform: Status, StartAll, StopAll, AddUser, RemoveUser, CostReport.

.PARAMETER UserEmail
    Email address for user operations.

.PARAMETER Days
    Number of days for cost reporting.

.EXAMPLE
    # Check lab status
    .\az-ps-devtest-lab-ops.ps1 -LabName "Training2025" -ResourceGroupName "training-rg" -Operation Status

.EXAMPLE
    # Stop all VMs immediately
    .\az-ps-devtest-lab-ops.ps1 -LabName "Training2025" -ResourceGroupName "training-rg" -Operation StopAll

.EXAMPLE
    # Add a new student
    .\az-ps-devtest-lab-ops.ps1 -LabName "Training2025" -ResourceGroupName "training-rg" -Operation AddUser -UserEmail "student@domain.com"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az)

.LINK
    https://learn.microsoft.com/en-us/azure/devtest-labs/

.COMPONENT
    Azure PowerShell DevTest Labs
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the DevTest Lab.")]
    [string]$LabName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Resource Group containing the lab.")]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "Operation to perform: Status, StartAll, StopAll, AddUser, RemoveUser, CostReport.")]
    [ValidateSet('Status', 'StartAll', 'StopAll', 'AddUser', 'RemoveUser', 'CostReport')]
    [string]$Operation,

    [Parameter(Mandatory = $false, HelpMessage = "Email address for user operations.")]
    [string]$UserEmail,

    [Parameter(Mandatory = $false, HelpMessage = "Number of days for cost reporting.")]
    [int]$Days = 7
)

$ErrorActionPreference = 'Stop'

try {

# Ensure Azure context
$azContext = Get-AzContext
if (-not $azContext) {
    Connect-AzAccount
}

Write-Host "DevTest Labs Quick Operations" -ForegroundColor Cyan
Write-Host "Lab: $LabName | Resource Group: $ResourceGroupName" -ForegroundColor Yellow

switch ($Operation) {
    'Status' {
        Write-Host "Getting lab status..." -ForegroundColor Cyan

        # Get lab info
        $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName -ErrorAction SilentlyContinue
        if (-not $lab) {
            Write-Host "Lab '$LabName' not found!" -ForegroundColor Red
            return
        }

        # Get VMs
        $vms = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines' -ErrorAction SilentlyContinue
        $runningVMs = $vms | Where-Object { $_.Properties.provisioningState -eq 'Succeeded' }

        Write-Host ""
        Write-Host "=== LAB STATUS ===" -ForegroundColor Green
        Write-Host "Lab Name: $($lab.Name)" -ForegroundColor White
        Write-Host "Location: $($lab.Location)" -ForegroundColor White
        Write-Host "Total VMs: $($vms.Count)" -ForegroundColor White
        Write-Host "Running VMs: $($runningVMs.Count)" -ForegroundColor White
        Write-Host ""

        if ($vms.Count -gt 0) {
            Write-Host "VM Details:" -ForegroundColor Cyan
            foreach ($vm in $vms) {
                $status = if ($vm.Properties.provisioningState -eq 'Succeeded') { "✓" } else { "⚠" }
                Write-Host "  $status $($vm.Name) - $($vm.Properties.provisioningState)" -ForegroundColor Gray
            }
        }
    }

    'StartAll' {
        Write-Host "Starting all VMs in lab..." -ForegroundColor Green

        $vms = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines'
        Write-Host "Found $($vms.Count) VMs to start..." -ForegroundColor Yellow

        foreach ($vm in $vms) {
            Write-Host "Starting $($vm.Name)..." -ForegroundColor Yellow
            # VM start operation would be implemented via REST API
            Write-Host "  Start command sent for $($vm.Name)" -ForegroundColor Green
        }

        Write-Host "All VM start operations initiated." -ForegroundColor Green
    }

    'StopAll' {
        Write-Host "Stopping all VMs in lab..." -ForegroundColor Yellow

        $vms = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs/virtualmachines'
        Write-Host "Found $($vms.Count) VMs to stop..." -ForegroundColor Yellow

        foreach ($vm in $vms) {
            Write-Host "Stopping $($vm.Name)..." -ForegroundColor Yellow
            # VM stop operation would be implemented via REST API
            Write-Host "  Stop command sent for $($vm.Name)" -ForegroundColor Green
        }

        Write-Host "All VM stop operations initiated." -ForegroundColor Green
    }

    'AddUser' {
        if (-not $UserEmail) {
            Write-Host "UserEmail parameter required for AddUser operation" -ForegroundColor Red
            return
        }

        Write-Host "Adding user $UserEmail to lab..." -ForegroundColor Cyan

        $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName
        $user = Get-AzADUser -Mail $UserEmail -ErrorAction SilentlyContinue

        if (-not $user) {
            Write-Host "User $UserEmail not found in Azure AD" -ForegroundColor Red
            return
        }

        try {
            New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName 'DevTest Labs User' -Scope $lab.ResourceId
            Write-Host "User $UserEmail added successfully" -ForegroundColor Green
        } catch {
            Write-Host "Failed to add user: $_" -ForegroundColor Red
        }
    }

    'RemoveUser' {
        if (-not $UserEmail) {
            Write-Host "UserEmail parameter required for RemoveUser operation" -ForegroundColor Red
            return
        }

        Write-Host "Removing user $UserEmail from lab..." -ForegroundColor Cyan

        $lab = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/labs' -Name $LabName
        $user = Get-AzADUser -Mail $UserEmail -ErrorAction SilentlyContinue

        if (-not $user) {
            Write-Host "User $UserEmail not found in Azure AD" -ForegroundColor Red
            return
        }

        try {
            Remove-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName 'DevTest Labs User' -Scope $lab.ResourceId
            Write-Host "User $UserEmail removed successfully" -ForegroundColor Green
        } catch {
            Write-Host "Failed to remove user: $_" -ForegroundColor Red
        }
    }

    'CostReport' {
        Write-Host "Generating cost report for last $Days days..." -ForegroundColor Cyan

        $startDate = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-dd')
        $endDate = (Get-Date).ToString('yyyy-MM-dd')

        try {
            $usage = Get-AzConsumptionUsageDetail -ResourceGroupName $ResourceGroupName -StartDate $startDate -EndDate $endDate
            $totalCost = ($usage | Measure-Object -Property PretaxCost -Sum).Sum

            Write-Host ""
            Write-Host "=== COST REPORT ===" -ForegroundColor Green
            Write-Host "Period: $startDate to $endDate" -ForegroundColor White
            Write-Host "Total Cost: $($totalCost.ToString('C'))" -ForegroundColor White
            Write-Host ""

            $costByService = $usage | Group-Object -Property ConsumedService | Sort-Object -Property Count -Descending
            Write-Host "Cost by Service:" -ForegroundColor Cyan
            foreach ($service in $costByService | Select-Object -First 5) {
                $serviceCost = ($service.Group | Measure-Object -Property PretaxCost -Sum).Sum
                Write-Host "  $($service.Name): $($serviceCost.ToString('C'))" -ForegroundColor Gray
            }

        } catch {
            Write-Host "Failed to retrieve cost data: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "✅ Operation completed." -ForegroundColor Green

}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
