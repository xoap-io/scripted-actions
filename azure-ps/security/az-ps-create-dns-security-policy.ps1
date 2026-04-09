<#
.SYNOPSIS
  Deploy Azure DNS Security Policy (dnsResolverPolicies) with domain lists, rules, VNet links, and diagnostics.

.DESCRIPTION
  This script creates and manages Azure DNS Security Policies with comprehensive domain filtering,
  security rules, virtual network links, and diagnostic logging. It provides idempotent operations
  to ensure consistent deployments.

.PARAMETER Name
  The name of the DNS Security Policy. Must be 2-64 characters, alphanumeric with hyphens.

.PARAMETER Location
  The Azure region where resources will be deployed.

.PARAMETER ResourceGroupName
  The resource group name. Defaults to the policy name if not specified.

.PARAMETER Tags
  Hashtable of tags to apply to all created resources.

.PARAMETER LogAnalyticsWorkspaceResourceId
  Full ARM resource ID of an existing Log Analytics workspace for diagnostic logs.

.PARAMETER DomainLists
  Hashtable defining domain lists. Each key maps to @{ name = "string"; domains = @("domain1.", "domain2.") }

.PARAMETER Rules
  Hashtable defining security rules. Each key maps to rule configuration with action_type, priority, etc.

.PARAMETER VnetLinks
  Array of virtual networks to link. Each entry: @{ name = "vnet-name"; resource_group_name = "vnet-rg" }

.NOTES
  This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
  The use of the scripts does not require XOAP, but it will make your life easier.
  You are allowed to pull the script from the repository and use it with XOAP or other solutions.
  The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
  liability for the function, the use and the consequences of the use of this freely available script.
  PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

  Author: XOAP.IO
  Requires: Az PowerShell module (Install-Module Az), Az.DnsResolver, Az.Monitor

.EXAMPLE
  .\az-ps-create-dns-security-policy.ps1 `
    -Name "dns-security-demo" `
    -Location "northeurope" `
    -ResourceGroupName "dns-security-demo" `
    -Tags @{ environment="demo"; project="dns-security" } `
    -LogAnalyticsWorkspaceResourceId "/subscriptions/<SUBID>/resourceGroups/operations-management/providers/Microsoft.OperationalInsights/workspaces/azurekubernetesservice" `
    -DomainLists @{
        domain_list_1 = @{
          name    = "dns-security-demo"
          domains = @("example.com.", "malicious.com.")
        }
      } `
    -Rules @{
        rule_1 = @{
          name                    = "dns-security-demo"
          action_type             = "Block"
          domain_list_keys        = @("domain_list_1")
          dns_security_rule_state = "Enabled"
          priority                = 100
        }
      } `
    -VnetLinks @(
        @{ name = "vnet-prod-1"; resource_group_name = "rg-network-prod" }
      )

.LINK
  https://learn.microsoft.com/en-us/azure/dns/dns-resolver-overview

.COMPONENT
  Azure PowerShell DNS Security
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory, HelpMessage="Name of the DNS Security Policy (2-64 chars, alphanumeric with hyphens)")]
  [ValidatePattern('^[a-zA-Z0-9\-]{2,64}$')]
  [string]$Name,

  [Parameter(Mandatory, HelpMessage="Azure region for resource deployment")]
  [ValidateNotNullOrEmpty()]
  [string]$Location,

  [Parameter(HelpMessage="Resource group name (defaults to policy name)")]
  [ValidatePattern('^[a-zA-Z0-9\-\._\(\)]+$')]
  [string]$ResourceGroupName = $Name,

  [Parameter(HelpMessage="Tags to apply to all resources")]
  [hashtable]$Tags = @{},

  [Parameter(Mandatory, HelpMessage="Full ARM resource ID of Log Analytics workspace")]
  [ValidatePattern('^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.OperationalInsights/workspaces/[^/]+$')]
  [string]$LogAnalyticsWorkspaceResourceId,

  [Parameter(Mandatory, HelpMessage="Domain lists configuration")]
  [ValidateNotNull()]
  [hashtable]$DomainLists,

  [Parameter(Mandatory, HelpMessage="Security rules configuration")]
  [ValidateNotNull()]
  [hashtable]$Rules,

  [Parameter(Mandatory, HelpMessage="Virtual network links configuration")]
  [ValidateNotNull()]
  [array]$VnetLinks
)

begin {
  $ErrorActionPreference = 'Stop'
  Write-Verbose "Starting DNS Security Policy deployment: $Name"

  # --- Helper: Ensure modules ---
  $required = @('Az.Accounts','Az.Resources','Az.Monitor','Az.Network','Az.DnsResolver')
  foreach ($m in $required) {
    try {
      Import-Module $m -Force -ErrorAction Stop
      Write-Verbose "Loaded module: $m"
    } catch {
      throw "Required module '$m' is not available. Run: Install-Module $m -Scope CurrentUser"
    }
  }

  # --- Helper: Idempotent creators ---
  function Get-OrCreateResourceGroup {
    param($Name,$Location,$Tags)
    try {
      $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
      if ($null -eq $rg) {
        Write-Verbose "Creating Resource Group '$Name' in '$Location'..."
        return New-AzResourceGroup -Name $Name -Location $Location -Tag $Tags -Force
      } else {
        if ($Tags.Count -gt 0) {
          Set-AzResourceGroup -Name $Name -Tag $Tags | Out-Null
        }
        return $rg
      }
    } catch {
      throw "Failed to create/update Resource Group '$Name': $($_.Exception.Message)"
    }
  }

  function Get-OrCreateDnsResolverPolicy {
    param($PolicyName,$RgName,$Location,$Tags)
    try {
      $existing = Get-AzDnsResolverPolicy -Name $PolicyName -ResourceGroupName $RgName -ErrorAction SilentlyContinue
      if ($null -eq $existing) {
        Write-Verbose "Creating DNS Resolver Policy '$PolicyName'..."
        return New-AzDnsResolverPolicy -Name $PolicyName -ResourceGroupName $RgName -Location $Location -Tag $Tags
      } else {
        if ($Tags.Count -gt 0) {
          Update-AzDnsResolverPolicy -Name $PolicyName -ResourceGroupName $RgName -Tag $Tags | Out-Null
        }
        return $existing
      }
    } catch {
      throw "Failed to create/update DNS Resolver Policy '$PolicyName': $($_.Exception.Message)"
    }
  }

  function Get-OrCreateDomainList {
    param($DlName,$RgName,$Location,$Domains,[hashtable]$Tags)
    try {
      $existing = Get-AzDnsResolverDomainList -Name $DlName -ResourceGroupName $RgName -ErrorAction SilentlyContinue
      if ($null -eq $existing) {
        Write-Verbose "Creating Domain List '$DlName'..."
        return New-AzDnsResolverDomainList -Name $DlName -ResourceGroupName $RgName -Location $Location -Domain $Domains -Tag $Tags
      } else {
        # Update domains if changed
        $needUpdate = @($existing.Domain) -join ',' -ne @($Domains) -join ','
        if ($needUpdate -or $Tags.Count -gt 0) {
          Write-Verbose "Updating Domain List '$DlName'..."
          return Update-AzDnsResolverDomainList -Name $DlName -ResourceGroupName $RgName -Domain $Domains -Tag $Tags
        }
        return $existing
      }
    } catch {
      throw "Failed to create/update Domain List '$DlName': $($_.Exception.Message)"
    }
  }

  function Get-OrCreateDnsSecurityRule {
    param(
      $RuleName,$RgName,$PolicyName,$Location,
      [int]$Priority,[ValidateSet('Enabled','Disabled')]$State,
      [ValidateSet('Block','Allow','Monitor')]$ActionType,
      [array]$DomainListIds,[hashtable]$Tags
    )
    try {
      $existing = Get-AzDnsResolverPolicyDnsSecurityRule `
                    -Name $RuleName -ResourceGroupName $RgName -DnsResolverPolicyName $PolicyName -ErrorAction SilentlyContinue
      $dlObj = $DomainListIds | ForEach-Object { @{ id = $_ } }

      if ($null -eq $existing) {
        Write-Verbose "Creating DNS Security Rule '$RuleName'..."
        return New-AzDnsResolverPolicyDnsSecurityRule `
          -Name $RuleName `
          -ResourceGroupName $RgName `
          -DnsResolverPolicyName $PolicyName `
          -Location $Location `
          -Priority $Priority `
          -DnsSecurityRuleState $State `
          -ActionType $ActionType `
          -DnsResolverDomainList $dlObj `
          -Tag $Tags
      } else {
        Write-Verbose "Updating DNS Security Rule '$RuleName' if needed..."
        return Update-AzDnsResolverPolicyDnsSecurityRule `
          -Name $RuleName `
          -ResourceGroupName $RgName `
          -DnsResolverPolicyName $PolicyName `
          -Priority $Priority `
          -DnsSecurityRuleState $State `
          -ActionType $ActionType `
          -DnsResolverDomainList $dlObj `
          -Tag $Tags
      }
    } catch {
      throw "Failed to create/update DNS Security Rule '$RuleName': $($_.Exception.Message)"
    }
  }

  function Get-OrCreatePolicyVnetLink {
    param($LinkName,$RgName,$PolicyName,$VnetId,$Location,[hashtable]$Tags)
    try {
      $existing = Get-AzDnsResolverPolicyVirtualNetworkLink `
                    -Name $LinkName -ResourceGroupName $RgName -DnsResolverPolicyName $PolicyName -ErrorAction SilentlyContinue
      if ($null -eq $existing) {
        Write-Verbose "Creating VNet Link '$LinkName' -> $VnetId"
        return New-AzDnsResolverPolicyVirtualNetworkLink `
          -Name $LinkName `
          -ResourceGroupName $RgName `
          -DnsResolverPolicyName $PolicyName `
          -VirtualNetworkId $VnetId `
          -Location $Location `
          -Tag $Tags
      } else {
        # Update tags only (link target cannot change without recreate)
        if ($Tags.Count -gt 0) {
          Update-AzDnsResolverPolicyVirtualNetworkLink `
            -Name $LinkName `
            -ResourceGroupName $RgName `
            -DnsResolverPolicyName $PolicyName `
            -Tag $Tags | Out-Null
        }
        return $existing
      }
    } catch {
      throw "Failed to create/update VNet Link '$LinkName': $($_.Exception.Message)"
    }
  }

  function Set-DiagnosticSettings {
    param($TargetResourceId,$LogAnalyticsWorkspaceResourceId,$NamePrefix)
    try {
      $diagName = "$NamePrefix-diagnostics"
      $existing = Get-AzDiagnosticSetting -ResourceId $TargetResourceId -ErrorAction SilentlyContinue
      if ($existing) {
        # Replace/ensure DnsResponse category is enabled to the LA workspace
        Remove-AzDiagnosticSetting -Name $existing.Name -ResourceId $TargetResourceId -ErrorAction SilentlyContinue
      }
      New-AzDiagnosticSetting `
        -Name $diagName `
        -ResourceId $TargetResourceId `
        -WorkspaceResourceId $LogAnalyticsWorkspaceResourceId `
        -Category "DnsResponse" `
        -Enabled:$true | Out-Null
      Write-Verbose "Configured diagnostic settings for $TargetResourceId"
    } catch {
      Write-Warning "Failed to configure diagnostic settings: $($_.Exception.Message)"
    }
  }
}

process {
  try {
    # Basic context sanity check
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx) {
      throw "No Azure context found. Run Connect-AzAccount first."
    }
    Write-Verbose "Using Azure subscription: $($ctx.Subscription.Name)"

    Write-Host "Starting DNS Security Policy deployment..." -ForegroundColor Cyan

    # 1) Resource Group
    Write-Verbose "Creating/updating Resource Group: $ResourceGroupName"
    $rg = Get-OrCreateResourceGroup -Name $ResourceGroupName -Location $Location -Tags $Tags
    Write-Host "✓ Resource Group: $($rg.ResourceGroupName)" -ForegroundColor Green

    # 2) DNS Resolver Policy (this is the 'DNS Security Policy' container)
    Write-Verbose "Creating/updating DNS Resolver Policy: $Name"
    $policy = Get-OrCreateDnsResolverPolicy -PolicyName $Name -RgName $rg.ResourceGroupName -Location $Location -Tags $Tags
    Write-Host "✓ DNS Resolver Policy: $($policy.Name)" -ForegroundColor Green

    # 3) Domain Lists
    Write-Host "Processing domain lists..." -ForegroundColor Cyan
    $domainListMap = @{}
    foreach ($key in $DomainLists.Keys) {
      $entry = $DomainLists[$key]
      if (-not $entry.name) {
        throw "DomainLists['$key'] must contain 'name'."
      }
      if (-not $entry.domains) {
        throw "DomainLists['$key'] must contain 'domains' (@('example.com.'))."
      }

      Write-Verbose "Processing domain list: $($entry.name)"
      $dl = Get-OrCreateDomainList -DlName $entry.name -RgName $rg.ResourceGroupName -Location $Location -Domains $entry.domains -Tags $Tags
      $domainListMap[$key] = $dl
      Write-Host "  ✓ Domain List: $($entry.name) ($($entry.domains.Count) domains)" -ForegroundColor Green
    }

    # 4) Rules
    Write-Host "Processing security rules..." -ForegroundColor Cyan
    foreach ($key in $Rules.Keys) {
      $r = $Rules[$key]
      foreach ($required in @('name','action_type','domain_list_keys','dns_security_rule_state','priority')) {
        if (-not $r.ContainsKey($required)) {
          throw "Rules['$key'] missing required property '$required'."
        }
      }

      $domainListIds = @()
      foreach ($dlKey in $r.domain_list_keys) {
        if (-not $domainListMap.ContainsKey($dlKey)) {
          throw "Rule '$($r.name)' references unknown domain_list_key '$dlKey'."
        }
        $domainListIds += $domainListMap[$dlKey].Id
      }

      Write-Verbose "Processing security rule: $($r.name)"
      $null = Get-OrCreateDnsSecurityRule `
        -RuleName $r.name `
        -RgName $rg.ResourceGroupName `
        -PolicyName $policy.Name `
        -Location $Location `
        -Priority ([int]$r.priority) `
        -State $r.dns_security_rule_state `
        -ActionType $r.action_type `
        -DomainListIds $domainListIds `
        -Tags $Tags
      Write-Host "  ✓ Security Rule: $($r.name) ($($r.action_type), Priority: $($r.priority))" -ForegroundColor Green
    }

    # 5) VNet Links
    Write-Host "Processing VNet links..." -ForegroundColor Cyan
    foreach ($link in $VnetLinks) {
      foreach ($required in @('name','resource_group_name')) {
        if (-not $link.ContainsKey($required)) {
          throw "Each VnetLinks entry needs '$required'."
        }
      }

      Write-Verbose "Processing VNet link: $($link.name) in RG: $($link.resource_group_name)"
      $vnet = Get-AzVirtualNetwork -Name $link.name -ResourceGroupName $link.resource_group_name -ErrorAction Stop

      # Same-region guard (policy and VNet must be in same region)
      if ($vnet.Location -ne $Location) {
        throw "VNet '$($link.name)' is in region '$($vnet.Location)' but policy is in '$Location'. They must match."
      }

      $linkName = if ($link.ContainsKey('link_name') -and $link.link_name) {
        $link.link_name
      } else {
        "$Name-$($link.name)-link"
      }

      $null = Get-OrCreatePolicyVnetLink -LinkName $linkName -RgName $rg.ResourceGroupName -PolicyName $policy.Name -VnetId $vnet.Id -Location $Location -Tags $Tags
      Write-Host "  ✓ VNet Link: $linkName -> $($vnet.Name)" -ForegroundColor Green
    }

    # 6) Diagnostics
    Write-Host "Configuring diagnostic settings..." -ForegroundColor Cyan
    Set-DiagnosticSettings -TargetResourceId $policy.Id -LogAnalyticsWorkspaceResourceId $LogAnalyticsWorkspaceResourceId -NamePrefix $Name
    Write-Host "  ✓ Diagnostic settings configured" -ForegroundColor Green

    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
    Write-Host "DNS Security Policy ID: $($policy.Id)" -ForegroundColor Yellow

  } catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    Write-Error $_.ScriptStackTrace
    throw
  }
}
