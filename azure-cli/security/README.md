# Azure CLI - Security Scripts

This directory contains PowerShell scripts for managing Azure security services using Azure CLI.

## Prerequisites

- Azure CLI 2.50+ installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Azure CLI logged in (`az login`)
- Security Administrator or equivalent role

## Available Scripts

### Azure Key Vault

- Create and manage Key Vaults
- Secret management (create, retrieve, update, delete)
- Key management (encryption keys)
- Certificate management
- Access policies configuration

### Azure Active Directory (Azure AD)

- User and group management
- Application registrations
- Service principal creation
- Role assignments

### Security Center / Microsoft Defender

- Security posture assessment
- Security recommendations
- Threat protection configuration
- Compliance monitoring

### Azure Firewall

- Firewall deployment and configuration
- Application rules
- Network rules
- NAT rules

### Network Security

- Network Security Group (NSG) management
- Application Security Group (ASG) creation
- DDoS Protection configuration

## Usage Examples

### Key Vault Operations

```powershell
# Create Key Vault
az keyvault create `
    --name myKeyVault `
    --resource-group myResourceGroup `
    --location eastus `
    --enabled-for-deployment `
    --enabled-for-disk-encryption

# Create secret
az keyvault secret set `
    --vault-name myKeyVault `
    --name DatabasePassword `
    --value "P@ssw0rd123!"

# Retrieve secret
az keyvault secret show `
    --vault-name myKeyVault `
    --name DatabasePassword `
    --query value -o tsv

# Grant access to service principal
az keyvault set-policy `
    --name myKeyVault `
    --spn <app-id> `
    --secret-permissions get list
```

### Create Service Principal

```powershell
# Create service principal with certificate authentication
az ad sp create-for-rbac `
    --name myApp `
    --role Contributor `
    --scopes /subscriptions/{subscription-id}/resourceGroups/myResourceGroup `
    --create-cert
```

### Configure Azure Firewall

```powershell
# Create Azure Firewall
az network firewall create `
    --name myFirewall `
    --resource-group myResourceGroup `
    --location eastus

# Create application rule
az network firewall application-rule create `
    --collection-name AppRules `
    --firewall-name myFirewall `
    --name AllowGitHub `
    --protocols Https=443 `
    --source-addresses * `
    --target-fqdns github.com *.github.com `
    --resource-group myResourceGroup `
    --priority 100 `
    --action Allow
```

## Azure Security Best Practices

- **Key Vault**:

  - Enable soft delete and purge protection
  - Use RBAC for access control (recommended over access policies)
  - Enable Azure Private Link
  - Implement key rotation
  - Monitor access with diagnostic logs

- **Identity and Access**:

  - Enable MFA for all users
  - Use Conditional Access policies
  - Implement Privileged Identity Management (PIM)
  - Regular access reviews
  - Use managed identities instead of service principals

- **Network Security**:

  - Implement defense in depth
  - Use Azure Firewall or NVAs for centralized control
  - Enable network flow logs
  - Use Just-In-Time VM access
  - Segment networks with NSGs

- **Monitoring and Compliance**:
  - Enable Microsoft Defender for Cloud
  - Configure Security Center alerts
  - Implement Azure Policy
  - Enable diagnostic logging
  - Regular security assessments

## Common Security Scenarios

### Managed Identity Authentication

```powershell
# Assign managed identity to VM
az vm identity assign `
    --name myVM `
    --resource-group myResourceGroup

# Grant Key Vault access to managed identity
az keyvault set-policy `
    --name myKeyVault `
    --object-id <managed-identity-object-id> `
    --secret-permissions get list
```

### Implement Zero Trust

1. Verify explicitly (MFA, Conditional Access)
2. Use least privilege access (RBAC, PIM)
3. Assume breach (network segmentation, monitoring)

## Encryption at Rest and in Transit

- **At Rest**: Enable Azure Disk Encryption, Key Vault, SQL TDE
- **In Transit**: Use TLS 1.2+, HTTPS, VPN/ExpressRoute

## Error Handling

Scripts include:

- Key Vault name validation (globally unique)
- Permission checks
- Secret format validation
- Comprehensive error messages
- Audit logging recommendations

## Related Documentation

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure Active Directory Documentation](https://docs.microsoft.com/azure/active-directory/)
- [Microsoft Defender for Cloud](https://docs.microsoft.com/azure/defender-for-cloud/)
- [Azure Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
- [Azure CLI Security Commands](https://docs.microsoft.com/cli/azure/keyvault)

## Support

For issues or questions, please refer to the main repository documentation.
