# Azure PowerShell - Security Scripts

This directory contains PowerShell scripts for managing Azure security services using Azure PowerShell modules.

## Prerequisites

- Azure PowerShell modules installed:
  - `Install-Module -Name Az.KeyVault`
  - `Install-Module -Name Az.Security`
  - `Install-Module -Name Az.Resources`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Security Administrator or equivalent role

## Available Scripts

PowerShell cmdlets for Azure security management:

### Key Vault

- `New-AzKeyVault` - Create Key Vaults
- `Set-AzKeyVaultSecret` - Create/update secrets
- `Get-AzKeyVaultSecret` - Retrieve secrets
- `New-AzKeyVaultKey` - Create encryption keys

### Security Center / Defender

- `Get-AzSecurityAlert` - Retrieve security alerts
- `Set-AzSecurityPricing` - Configure Defender plans
- `Get-AzSecurityAssessment` - Get security recommendations

### Azure AD

- `New-AzADServicePrincipal` - Create service principals
- `New-AzRoleAssignment` - Assign RBAC roles

## Usage Examples

### Key Vault Management

```powershell
# Connect to Azure
Connect-AzAccount

# Create Key Vault
New-AzKeyVault `
    -ResourceGroupName "SecurityRG" `
    -VaultName "MyKeyVault" `
    -Location "EastUS" `
    -EnabledForDiskEncryption `
    -EnableRbacAuthorization

# Create secret
$secretValue = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
Set-AzKeyVaultSecret `
    -VaultName "MyKeyVault" `
    -Name "DatabasePassword" `
    -SecretValue $secretValue

# Retrieve secret
$secret = Get-AzKeyVaultSecret `
    -VaultName "MyKeyVault" `
    -Name "DatabasePassword"
```

### Service Principal and RBAC

```powershell
# Create service principal
$sp = New-AzADServicePrincipal `
    -DisplayName "MyApp" `
    -Role "Contributor" `
    -Scope "/subscriptions/{subscription-id}/resourceGroups/MyRG"

# Assign role
New-AzRoleAssignment `
    -ObjectId $sp.Id `
    -RoleDefinitionName "Reader" `
    -Scope "/subscriptions/{subscription-id}/resourceGroups/MyRG"
```

## Object-Oriented Benefits

```powershell
# Rich object pipeline
Get-AzKeyVault |
    Where-Object {$_.Location -eq 'EastUS'} |
    Select-Object VaultName, ResourceGroupName, Location
```

## Related Documentation

- [Az.KeyVault Module](https://docs.microsoft.com/powershell/module/az.keyvault/)
- [Az.Security Module](https://docs.microsoft.com/powershell/module/az.security/)
- [Azure Security Documentation](https://docs.microsoft.com/azure/security/)

## Support

For issues or questions, please refer to the main repository documentation.
