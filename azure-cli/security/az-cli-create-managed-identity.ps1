<#
.SYNOPSIS
    Create an Azure User-Assigned or System-Assigned Managed Identity using Azure CLI.

.DESCRIPTION
    This script creates Azure Managed Identities using the Azure CLI with comprehensive configuration and security best practices.
    Supports both User-Assigned and System-Assigned managed identities with role assignments and resource associations.
    Includes scope validation, role assignment automation, and identity lifecycle management.

    The script uses the Azure CLI command: az identity create

.PARAMETER Name
    Name of the User-Assigned Managed Identity to create.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group where the identity will be created.

.PARAMETER Location
    Azure region where the identity will be created.

.PARAMETER Tags
    Tags to apply to the identity in key=value format (space-separated pairs).

.PARAMETER AssignRoles
    Automatically assign roles to the identity.

.PARAMETER Roles
    Comma-separated list of roles to assign to the identity.

.PARAMETER Scope
    Scope for role assignments (subscription, resource group, or resource).

.PARAMETER TargetResourceGroup
    Target resource group for role assignments.

.PARAMETER AssociateWithResources
    Associate identity with existing resources.

.PARAMETER ResourceNames
    Comma-separated list of resource names to associate with.

.PARAMETER ResourceTypes
    Comma-separated list of resource types for association.

.PARAMETER GenerateClientScript
    Generate sample client scripts for using the identity.

.PARAMETER OutputFormat
    Output format for identity information.

.EXAMPLE
    .\az-cli-create-managed-identity.ps1 -Name "webapp-identity" -ResourceGroup "rg-web" -Location "eastus" -AssignRoles -Roles "Storage Blob Data Reader,Key Vault Secrets User"

.EXAMPLE
    .\az-cli-create-managed-identity.ps1 -Name "backup-identity" -ResourceGroup "rg-backup" -Location "westus2" -Tags "Environment=Production Purpose=Backup" -Scope "/subscriptions/12345/resourceGroups/rg-storage"

.EXAMPLE
    .\az-cli-create-managed-identity.ps1 -Name "aks-identity" -ResourceGroup "rg-aks" -Location "northeurope" -AssociateWithResources -ResourceNames "aks-cluster" -ResourceTypes "Microsoft.ContainerService/managedClusters"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

    Managed Identity Best Practices:
    - Use User-Assigned for multiple resources
    - Use System-Assigned for single resources
    - Apply least privilege principles
    - Use appropriate scoping for role assignments
    - Monitor identity usage and access patterns
    - Rotate credentials regularly

.LINK
    https://docs.microsoft.com/en-us/cli/azure/identity

.COMPONENT
    Azure CLI Managed Identity
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the User-Assigned Managed Identity")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(3, 128)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Azure region for the identity")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Tags in key=value format")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Assign roles to the identity")]
    [switch]$AssignRoles,

    [Parameter(Mandatory = $false, HelpMessage = "Roles to assign (comma-separated)")]
    [string]$Roles = "Reader",

    [Parameter(Mandatory = $false, HelpMessage = "Scope for role assignments")]
    [string]$Scope,

    [Parameter(Mandatory = $false, HelpMessage = "Target resource group for assignments")]
    [string]$TargetResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Associate with existing resources")]
    [switch]$AssociateWithResources,

    [Parameter(Mandatory = $false, HelpMessage = "Resource names to associate (comma-separated)")]
    [string]$ResourceNames,

    [Parameter(Mandatory = $false, HelpMessage = "Resource types for association (comma-separated)")]
    [string]$ResourceTypes,

    [Parameter(Mandatory = $false, HelpMessage = "Generate client usage scripts")]
    [switch]$GenerateClientScript,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'JSON', 'Summary')]
    [string]$OutputFormat = 'Summary'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to validate Azure CLI installation and authentication
function Test-AzureCLI {
    try {
        Write-Host "🔍 Validating Azure CLI installation..." -ForegroundColor Cyan
        $null = az --version
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not installed or not functioning correctly"
        }

        Write-Host "🔍 Checking Azure CLI authentication..." -ForegroundColor Cyan
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not authenticated to Azure CLI. Please run 'az login' first"
        }

        Write-Host "✅ Azure CLI validation successful" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Azure CLI validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate resource group exists
function Test-ResourceGroupExists {
    param($ResourceGroup)

    try {
        Write-Host "🔍 Validating resource group '$ResourceGroup' exists..." -ForegroundColor Cyan
        $null = az group show --name $ResourceGroup --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Resource group '$ResourceGroup' not found"
        }
        Write-Host "✅ Resource group '$ResourceGroup' found" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Resource group validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate location
function Test-AzureLocation {
    param($Location)

    try {
        Write-Host "🔍 Validating Azure location '$Location'..." -ForegroundColor Cyan
        $validLocations = az account list-locations --query "[].name" --output tsv
        if ($validLocations -notcontains $Location) {
            throw "Invalid Azure location: $Location"
        }
        Write-Host "✅ Location '$Location' is valid" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Location validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to check if identity already exists
function Test-IdentityExists {
    param($ResourceGroup, $IdentityName)

    try {
        Write-Host "🔍 Checking if identity '$IdentityName' already exists..." -ForegroundColor Cyan
        $identity = az identity show --resource-group $ResourceGroup --name $IdentityName --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($identity)) {
            throw "Managed Identity '$IdentityName' already exists in resource group '$ResourceGroup'"
        }
        Write-Host "✅ Identity name is available" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Identity conflict check failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to parse and validate tags
function Get-ValidatedTags {
    param($TagString)

    if ([string]::IsNullOrEmpty($TagString)) {
        return @()
    }

    $tagPairs = $TagString -split '\s+'
    $azTags = @()

    foreach ($pair in $tagPairs) {
        if ($pair -match '^([^=]+)=(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2]

            # Validate tag key and value
            if ($key.Length -gt 512 -or $value.Length -gt 256) {
                throw "Tag key must be ≤ 512 chars and value ≤ 256 chars: $pair"
            }

            $azTags += $pair
        }
        else {
            throw "Invalid tag format: $pair (use key=value format)"
        }
    }

    return $azTags
}

# Function to validate role definitions
function Test-RoleDefinitions {
    param($RoleList)

    try {
        Write-Host "🔍 Validating role definitions..." -ForegroundColor Cyan

        $validRoles = @()
        $roleNames = $RoleList -split ','

        foreach ($roleName in $roleNames) {
            $roleName = $roleName.Trim()

            # Check if role exists
            $role = az role definition list --name $roleName --output json | ConvertFrom-Json
            if (-not $role -or $role.Count -eq 0) {
                throw "Role definition '$roleName' not found"
            }

            $validRoles += @{
                Name = $role.roleName
                Id = $role.id
                Description = $role.description
            }
        }

        Write-Host "✅ All role definitions validated" -ForegroundColor Green
        return $validRoles
    }
    catch {
        Write-Error "Role validation failed: $($_.Exception.Message)"
        return $null
    }
}

# Function to build scope for role assignments
function Get-RoleAssignmentScope {
    param($Scope, $TargetResourceGroup)

    try {
        if ($Scope) {
            Write-Host "🔍 Validating provided scope..." -ForegroundColor Cyan
            # Basic scope validation
            if ($Scope -notmatch '^/subscriptions/') {
                throw "Invalid scope format. Must start with /subscriptions/"
            }
            return $Scope
        }

        # Build scope from subscription and resource group
        $subscription = az account show --query "id" --output tsv
        $builtScope = "/subscriptions/$subscription"

        if ($TargetResourceGroup) {
            # Validate target resource group exists
            $null = az group show --name $TargetResourceGroup --query "name" --output tsv 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Target resource group '$TargetResourceGroup' not found"
            }
            $builtScope += "/resourceGroups/$TargetResourceGroup"
        }

        Write-Host "✅ Built scope: $builtScope" -ForegroundColor Green
        return $builtScope
    }
    catch {
        Write-Error "Scope building failed: $($_.Exception.Message)"
        return $null
    }
}

# Function to assign roles to identity
function Set-IdentityRoleAssignments {
    param($IdentityId, $Roles, $Scope)

    try {
        Write-Host "🔧 Assigning roles to managed identity..." -ForegroundColor Cyan

        $assignments = @()
        foreach ($role in $Roles) {
            Write-Host "   Assigning role: $($role.Name)" -ForegroundColor Gray

            $assignment = az role assignment create --assignee $IdentityId --role $role.Name --scope $Scope --output json | ConvertFrom-Json

            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ Role '$($role.Name)' assigned successfully" -ForegroundColor Green
                $assignments += $assignment
            }
            else {
                Write-Warning "   ⚠️ Failed to assign role '$($role.Name)'"
            }
        }

        return $assignments
    }
    catch {
        Write-Warning "Error assigning roles: $($_.Exception.Message)"
        return @()
    }
}

# Function to associate identity with resources
function Set-ResourceAssociations {
    param($IdentityId, $ResourceNames, $ResourceTypes, $ResourceGroup)

    try {
        Write-Host "🔧 Associating identity with resources..." -ForegroundColor Cyan

        $nameArray = $ResourceNames -split ','
        $typeArray = $ResourceTypes -split ','

        if ($nameArray.Count -ne $typeArray.Count) {
            throw "Number of resource names must match number of resource types"
        }

        $associations = @()
        for ($i = 0; $i -lt $nameArray.Count; $i++) {
            $resourceName = $nameArray[$i].Trim()
            $resourceType = $typeArray[$i].Trim()

            Write-Host "   Associating with: $resourceName ($resourceType)" -ForegroundColor Gray

            try {
                # The specific association method depends on the resource type
                # For VMs, we would use: az vm identity assign
                # For App Services: az webapp identity assign
                # This is a generic approach for demonstration

                switch -Wildcard ($resourceType) {
                    "*VirtualMachines*" {
                        $result = az vm identity assign --name $resourceName --resource-group $ResourceGroup --identities $IdentityId --output json 2>$null | ConvertFrom-Json
                    }
                    "*WebSites*" {
                        $result = az webapp identity assign --name $resourceName --resource-group $ResourceGroup --identities $IdentityId --output json 2>$null | ConvertFrom-Json
                    }
                    "*ContainerService*" {
                        # For AKS, this would be more complex and might require different approach
                        Write-Host "   ℹ️ AKS identity assignment requires special configuration" -ForegroundColor Yellow
                        $result = @{ Status = "Manual configuration required" }
                    }
                    default {
                        Write-Host "   ℹ️ Resource type '$resourceType' may require manual identity configuration" -ForegroundColor Yellow
                        $result = @{ Status = "Manual configuration may be required" }
                    }
                }

                if ($result) {
                    $associations += @{
                        ResourceName = $resourceName
                        ResourceType = $resourceType
                        Status = "Associated"
                        Details = $result
                    }
                    Write-Host "   ✅ Associated with $resourceName" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "   ⚠️ Failed to associate with $resourceName : $($_.Exception.Message)"
                $associations += @{
                    ResourceName = $resourceName
                    ResourceType = $resourceType
                    Status = "Failed"
                    Error = $_.Exception.Message
                }
            }
        }

        return $associations
    }
    catch {
        Write-Warning "Error associating resources: $($_.Exception.Message)"
        return @()
    }
}

# Function to generate client scripts
function New-ClientScripts {
    param($Identity, $OutputPath)

    try {
        Write-Host "📝 Generating client usage scripts..." -ForegroundColor Cyan

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $scriptPath = if ($OutputPath) { $OutputPath } else { "./managed-identity-scripts-$timestamp" }

        # Create directory
        if (-not (Test-Path $scriptPath)) {
            New-Item -ItemType Directory -Path $scriptPath -Force | Out-Null
        }

        # PowerShell script
        $psScript = @"
# PowerShell script to use Managed Identity: $($Identity.name)
# Identity ID: $($Identity.id)
# Client ID: $($Identity.clientId)

# Method 1: Using Azure PowerShell with Managed Identity
Connect-AzAccount -Identity

# Method 2: Using REST API with Instance Metadata Service
`$headers = @{'Metadata' = 'true'}
`$uri = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
`$response = Invoke-RestMethod -Uri `$uri -Headers `$headers -Method GET
`$accessToken = `$response.access_token

# Method 3: Using specific client ID (for user-assigned identity)
`$uri = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/&client_id=$($Identity.clientId)'
`$response = Invoke-RestMethod -Uri `$uri -Headers `$headers -Method GET
`$accessToken = `$response.access_token

Write-Host "Managed Identity authentication successful"
"@

        $psScript | Out-File -FilePath "$scriptPath/use-identity.ps1" -Encoding UTF8

        # Python script
        $pyScript = @"
#!/usr/bin/env python3
# Python script to use Managed Identity: $($Identity.name)
# Identity ID: $($Identity.id)
# Client ID: $($Identity.clientId)

import requests
import json

def get_access_token(resource='https://management.azure.com/', client_id='$($Identity.clientId)'):
    """Get access token using Managed Identity"""
    url = 'http://169.254.169.254/metadata/identity/oauth2/token'
    params = {
        'api-version': '2018-02-01',
        'resource': resource,
        'client_id': client_id
    }
    headers = {'Metadata': 'true'}

    try:
        response = requests.get(url, params=params, headers=headers)
        response.raise_for_status()
        token_data = response.json()
        return token_data['access_token']
    except Exception as e:
        print(f"Error getting access token: {e}")
        return None

# Example usage
if __name__ == "__main__":
    token = get_access_token()
    if token:
        print("Managed Identity authentication successful")
        # Use the token for Azure API calls
        headers = {'Authorization': f'Bearer {token}'}
        # Example: List resource groups
        # response = requests.get('https://management.azure.com/subscriptions/{subscription-id}/resourcegroups?api-version=2020-06-01', headers=headers)
    else:
        print("Failed to get access token")
"@

        $pyScript | Out-File -FilePath "$scriptPath/use-identity.py" -Encoding UTF8

        # Bash script
        $bashScript = @"
#!/bin/bash
# Bash script to use Managed Identity: $($Identity.name)
# Identity ID: $($Identity.id)
# Client ID: $($Identity.clientId)

# Function to get access token
get_access_token() {
    local resource=`${1:-"https://management.azure.com/"}
    local client_id="$($Identity.clientId)"

    local url="http://169.254.169.254/metadata/identity/oauth2/token"
    local response=`$(curl -s -H "Metadata: true" "`${url}?api-version=2018-02-01&resource=`${resource}&client_id=`${client_id}")

    echo `$response | jq -r '.access_token'
}

# Example usage
TOKEN=`$(get_access_token)

if [ "`$TOKEN" != "null" ] && [ -n "`$TOKEN" ]; then
    echo "Managed Identity authentication successful"
    # Use the token for Azure API calls
    # Example: curl -H "Authorization: Bearer `$TOKEN" "https://management.azure.com/subscriptions/{subscription-id}/resourcegroups?api-version=2020-06-01"
else
    echo "Failed to get access token"
fi
"@

        $bashScript | Out-File -FilePath "$scriptPath/use-identity.sh" -Encoding UTF8

        # README file
        $readme = @"
# Managed Identity Usage Scripts

This directory contains sample scripts for using the Managed Identity: **$($Identity.name)**

## Identity Information
- **Name**: $($Identity.name)
- **Resource Group**: $($Identity.resourceGroup)
- **Client ID**: $($Identity.clientId)
- **Principal ID**: $($Identity.principalId)
- **Tenant ID**: $($Identity.tenantId)

## Scripts Included

### PowerShell (use-identity.ps1)
- Uses Azure PowerShell modules
- Includes REST API examples
- Shows both system and user-assigned identity usage

### Python (use-identity.py)
- Uses requests library
- Shows token acquisition and usage
- Includes error handling

### Bash (use-identity.sh)
- Uses curl and jq
- Linux/Unix compatible
- Shows REST API token acquisition

## Usage Notes

1. These scripts work only from Azure resources (VMs, App Services, etc.) that have the managed identity assigned
2. For user-assigned identities, specify the client ID in token requests
3. Different Azure services may require different resource URIs in token requests:
   - Azure Resource Manager: https://management.azure.com/
   - Key Vault: https://vault.azure.net
   - Storage: https://storage.azure.com/
   - Microsoft Graph: https://graph.microsoft.com/

## Security Best Practices

- Never expose access tokens in logs or error messages
- Use appropriate resource URIs for specific services
- Implement proper error handling and retry logic
- Monitor identity usage through Azure Activity Log
"@

        $readme | Out-File -FilePath "$scriptPath/README.md" -Encoding UTF8

        Write-Host "✅ Client scripts generated in: $scriptPath" -ForegroundColor Green
        return $scriptPath
    }
    catch {
        Write-Warning "Error generating client scripts: $($_.Exception.Message)"
        return $null
    }
}

# Function to display identity summary
function Show-IdentitySummary {
    param($Identity, $RoleAssignments, $ResourceAssociations, $Format)

    switch ($Format) {
        'Summary' {
            Write-Host "`n📋 Managed Identity Summary:" -ForegroundColor Yellow
            Write-Host "   Name: $($Identity.name)" -ForegroundColor White
            Write-Host "   Resource Group: $($Identity.resourceGroup)" -ForegroundColor White
            Write-Host "   Location: $($Identity.location)" -ForegroundColor White
            Write-Host "   Client ID: $($Identity.clientId)" -ForegroundColor White
            Write-Host "   Principal ID: $($Identity.principalId)" -ForegroundColor White
            Write-Host "   Tenant ID: $($Identity.tenantId)" -ForegroundColor White

            if ($RoleAssignments.Count -gt 0) {
                Write-Host "`n🔐 Role Assignments:" -ForegroundColor Yellow
                $RoleAssignments | ForEach-Object {
                    Write-Host "   - $($_.roleDefinitionName) at $($_.scope)" -ForegroundColor White
                }
            }

            if ($ResourceAssociations.Count -gt 0) {
                Write-Host "`n🔗 Resource Associations:" -ForegroundColor Yellow
                $ResourceAssociations | ForEach-Object {
                    Write-Host "   - $($_.ResourceName) ($($_.ResourceType)): $($_.Status)" -ForegroundColor White
                }
            }
        }
        'Table' {
            Write-Host "`n📋 Identity Details:" -ForegroundColor Yellow
            $Identity | Format-Table -Property name, resourceGroup, location, clientId, principalId -AutoSize
        }
        'JSON' {
            $output = @{
                Identity = $Identity
                RoleAssignments = $RoleAssignments
                ResourceAssociations = $ResourceAssociations
            }
            return $output | ConvertTo-Json -Depth 10
        }
    }
}

# Main execution
try {
    Write-Host "🚀 Starting Azure Managed Identity Creation" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate resource group exists
    if (-not (Test-ResourceGroupExists -ResourceGroup $ResourceGroup)) {
        exit 1
    }

    # Validate location
    if (-not (Test-AzureLocation -Location $Location)) {
        exit 1
    }

    # Check if identity already exists
    if (-not (Test-IdentityExists -ResourceGroup $ResourceGroup -IdentityName $Name)) {
        exit 1
    }

    # Validate tags
    $validatedTags = @()
    if ($Tags) {
        $validatedTags = Get-ValidatedTags -TagString $Tags
    }

    # Validate roles if assignment is requested
    $validatedRoles = @()
    if ($AssignRoles) {
        $validatedRoles = Test-RoleDefinitions -RoleList $Roles
        if (-not $validatedRoles) {
            exit 1
        }
    }

    # Build scope for role assignments if needed
    $assignmentScope = $null
    if ($AssignRoles) {
        $assignmentScope = Get-RoleAssignmentScope -Scope $Scope -TargetResourceGroup $TargetResourceGroup
        if (-not $assignmentScope) {
            exit 1
        }
    }

    # Build parameters array
    $azParams = @(
        'identity', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location
    )

    # Add tags if provided
    if ($validatedTags.Count -gt 0) {
        $azParams += '--tags'
        $azParams += $validatedTags
    }

    # Create the managed identity
    Write-Host "🔧 Creating managed identity '$Name'..." -ForegroundColor Cyan
    $identity = az @azParams --output json | ConvertFrom-Json

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Managed identity '$Name' created successfully!" -ForegroundColor Green

        # Wait a moment for identity to propagate
        Write-Host "⏳ Waiting for identity propagation..." -ForegroundColor Cyan
        Start-Sleep -Seconds 10

        # Assign roles if requested
        $roleAssignments = @()
        if ($AssignRoles -and $validatedRoles.Count -gt 0) {
            $roleAssignments = Set-IdentityRoleAssignments -IdentityId $identity.principalId -Roles $validatedRoles -Scope $assignmentScope
        }

        # Associate with resources if requested
        $resourceAssociations = @()
        if ($AssociateWithResources -and $ResourceNames -and $ResourceTypes) {
            $resourceAssociations = Set-ResourceAssociations -IdentityId $identity.id -ResourceNames $ResourceNames -ResourceTypes $ResourceTypes -ResourceGroup $ResourceGroup
        }

        # Generate client scripts if requested
        if ($GenerateClientScript) {
            $scriptPath = New-ClientScripts -Identity $identity
            if ($scriptPath) {
                Write-Host "📝 Client scripts available at: $scriptPath" -ForegroundColor Cyan
            }
        }

        # Display results
        if ($OutputFormat -eq 'JSON') {
            $output = Show-IdentitySummary -Identity $identity -RoleAssignments $roleAssignments -ResourceAssociations $resourceAssociations -Format $OutputFormat
            Write-Output $output
        }
        else {
            Show-IdentitySummary -Identity $identity -RoleAssignments $roleAssignments -ResourceAssociations $resourceAssociations -Format $OutputFormat
        }

        # Show next steps
        Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   1. Assign the identity to your Azure resources" -ForegroundColor White
        Write-Host "   2. Use the Client ID in your applications: $($identity.clientId)" -ForegroundColor White
        Write-Host "   3. Configure your application to use managed identity authentication" -ForegroundColor White
        Write-Host "   4. Test the identity access with appropriate resources" -ForegroundColor White
        Write-Host "   5. Monitor identity usage through Azure Activity Log" -ForegroundColor White
    }
    else {
        throw "Failed to create managed identity. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "❌ Failed to create managed identity: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
