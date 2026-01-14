# PowerShell Script Templates

This directory contains starter templates and examples for creating new
automation scripts in this repository. Templates follow established patterns
for parameter validation, error handling, and documentation.

## Available Templates

| Template                           | Description                      | Purpose                              |
| ---------------------------------- | -------------------------------- | ------------------------------------ |
| [`template.ps1`](./template.ps1)   | Basic PowerShell script template | Standard automation script structure |
| [`splatting.ps1`](./splatting.ps1) | Parameter splatting examples     | Complex parameter handling patterns  |

## Template Features

### Standard Structure

All templates include:

- Comprehensive parameter blocks with validation
- Error handling with `$ErrorActionPreference = 'Stop'`
- PowerShell help documentation blocks
- Consistent output and logging patterns
- Progress reporting for long operations

### Parameter Validation Patterns

Templates demonstrate common validation patterns used across the repository:

```powershell
# AWS Resource ID validation
[ValidatePattern('^i-[a-f0-9]{8,17}$')]
[string]$InstanceId

# Azure Resource Group validation
[ValidatePattern('^[a-zA-Z0-9_\-\.\(\)]{1,90}$')]
[string]$ResourceGroupName

# GCP Project ID validation
[ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
[string]$ProjectId

# Region validation with ValidateSet
[ValidateSet("us-east-1", "us-west-2", "eu-west-1")]
[string]$Region
```

## Using Templates

### Creating a New Script

1. Copy the appropriate template file
1. Rename to follow naming convention: `platform-tool-action-resource.ps1`
1. Update the help documentation block
1. Modify parameters for your specific use case
1. Implement the main script logic
1. Test thoroughly before committing

### Naming Conventions

Follow these patterns for new scripts:

- **AWS CLI**: `aws-cli-action-resource.ps1`
- **AWS PowerShell**: `aws-ps-action-resource.ps1`
- **Azure CLI**: `azure-cli-action-resource.ps1`
- **Azure PowerShell**: `az-ps-action-resource.ps1`
- **GCP CLI**: `gce-cli-action-resource.ps1`
- **GCP PowerShell**: `gce-ps-action-resource.ps1`

### Documentation Standards

All scripts must include PowerShell help blocks:

```powershell
<#
.SYNOPSIS
    Brief description of script functionality

.DESCRIPTION
    Detailed description of what the script does, including any
    prerequisites, assumptions, or important considerations.

.PARAMETER ParameterName
    Description of each parameter, including valid values and examples

.EXAMPLE
    PS> .\script-name.ps1 -Parameter "value"
    Description of what this example does

.EXAMPLE
    PS> .\script-name.ps1 -Parameter1 "value1" -Parameter2 "value2"
    Description of a more complex example

.NOTES
    Additional information about the script, including version history,
    author information, or special requirements
#>
```

## Parameter Splatting

The `splatting.ps1` template demonstrates advanced parameter handling:

### Basic Splatting

```powershell
$params = @{
    InstanceType = $InstanceType
    KeyName      = $KeyName
    SecurityGroups = $SecurityGroups
}

if ($SubnetId) {
    $params.SubnetId = $SubnetId
}

$result = aws ec2 run-instances @params
```

### Conditional Parameters

```powershell
$createParams = @{
    ImageId = $ImageId
    MinCount = 1
    MaxCount = 1
}

# Add optional parameters only if provided
if ($PSBoundParameters.ContainsKey('InstanceType')) {
    $createParams.InstanceType = $InstanceType
}

if ($PSBoundParameters.ContainsKey('KeyName')) {
    $createParams.KeyName = $KeyName
}
```

## Error Handling Patterns

### Standard Error Handling

```powershell
$ErrorActionPreference = 'Stop'

try {
    # Main script logic here
    Write-Host "Operation completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    exit 1
}
```

### CLI Tool Error Handling

```powershell
# For AWS CLI
$result = aws ec2 describe-instances --instance-ids $InstanceId 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI command failed: $result"
}

# For Azure CLI
$result = az vm show --resource-group $ResourceGroupName --name $VmName 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI command failed: $result"
}

# For gcloud CLI
$result = gcloud compute instances describe $InstanceName --zone=$Zone 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "gcloud CLI command failed: $result"
}
```

## Validation Patterns

### Common Resource Validations

```powershell
# AWS Instance ID
[ValidatePattern('^i-[a-f0-9]{8,17}$')]

# AWS VPC ID
[ValidatePattern('^vpc-[a-f0-9]{8,17}$')]

# AWS Security Group ID
[ValidatePattern('^sg-[a-f0-9]{8,17}$')]

# Azure Resource Group
[ValidatePattern('^[a-zA-Z0-9_\-\.\(\)]{1,90}$')]

# Azure VM Name
[ValidatePattern('^[a-zA-Z0-9\-]{1,64}$')]

# GCP Instance Name
[ValidatePattern('^[a-z][-a-z0-9]{0,61}[a-z0-9]$')]

# GCP Project ID
[ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
```

### Region and Zone Validations

```powershell
# AWS Regions
[ValidateSet("us-east-1", "us-east-2", "us-west-1", "us-west-2",
            "eu-west-1", "eu-west-2", "eu-central-1", "ap-southeast-1")]

# Azure Regions
[ValidateSet("eastus", "westus", "centralus", "northeurope",
            "westeurope", "southeastasia", "eastasia")]

# GCP Zones
[ValidateSet("us-central1-a", "us-central1-b", "us-west1-a",
            "europe-west1-b", "asia-southeast1-a")]
```

## Output Patterns

### Success Messages

```powershell
Write-Host "✓ Resource created successfully" -ForegroundColor Green
Write-Host "Resource ID: $resourceId" -ForegroundColor Cyan
```

### Progress Reporting

```powershell
Write-Progress -Activity "Creating resources" -Status "Creating VPC..." -PercentComplete 25
Write-Progress -Activity "Creating resources" -Status "Creating subnets..." -PercentComplete 50
Write-Progress -Activity "Creating resources" -Status "Creating instances..." -PercentComplete 75
Write-Progress -Activity "Creating resources" -Status "Complete" -PercentComplete 100
```

### Verbose Output

```powershell
Write-Verbose "Validating parameters..."
Write-Verbose "Connecting to AWS..."
Write-Verbose "Creating instance with parameters: $($params | ConvertTo-Json)"
```

## Testing Guidelines

### Manual Testing Checklist

Before committing new scripts:

1. **Parameter Validation**: Test with invalid parameters
1. **Error Handling**: Test with non-existent resources
1. **Authentication**: Test with invalid credentials
1. **Edge Cases**: Test with boundary values
1. **Cleanup**: Verify resources are properly cleaned up

### Test Scenarios

```powershell
# Test parameter validation
.\script.ps1 -InvalidParameter "value"  # Should fail validation

# Test error handling
.\script.ps1 -ResourceId "non-existent"  # Should handle gracefully

# Test success path
.\script.ps1 -ValidParameter "value"     # Should complete successfully
```

## Best Practices

### Script Organization

1. Place parameters at the top of the script
1. Include validation for all required parameters
1. Group related functionality into functions
1. Use meaningful variable names
1. Include comments for complex logic

### Security Considerations

1. Never hardcode credentials in scripts
1. Use parameter validation to prevent injection
1. Implement proper error handling to avoid information disclosure
1. Use secure methods for credential handling
1. Follow principle of least privilege

### Performance Optimization

1. Use parameter splatting for complex commands
1. Implement parallel processing for bulk operations
1. Cache results when appropriate
1. Use efficient data structures
1. Minimize API calls

## Contributing New Templates

When adding new templates:

1. Follow existing naming conventions
1. Include comprehensive documentation
1. Demonstrate common patterns used in the repository
1. Add validation examples relevant to the platform
1. Include error handling patterns
1. Update this README with template descriptions

## Platform-Specific Considerations

### AWS Scripts

- Use AWS CLI or AWS PowerShell modules
- Implement proper credential handling
- Include region-specific validations
- Handle AWS service limits and quotas

### Azure Scripts

- Use Azure CLI or Az PowerShell modules
- Implement proper subscription context
- Include resource group management
- Handle Azure resource naming restrictions

### GCP Scripts

- Use gcloud CLI or Google Cloud PowerShell modules
- Implement proper project context
- Include zone and region considerations
- Handle GCP quota and billing implications

## Template Customization

### Adding Custom Validations

```powershell
# Custom validation function
function ValidateAwsResourceId {
    param([string]$ResourceId, [string]$ResourceType)

    $patterns = @{
        'instance' = '^i-[a-f0-9]{8,17}$'
        'vpc'      = '^vpc-[a-f0-9]{8,17}$'
        'subnet'   = '^subnet-[a-f0-9]{8,17}$'
    }

    if (-not ($ResourceId -match $patterns[$ResourceType])) {
        throw "Invalid $ResourceType ID format: $ResourceId"
    }
}
```

### Adding Custom Parameters

```powershell
# Optional parameters with defaults
[Parameter()]
[int]$Timeout = 300

# Mandatory parameters with validation
[Parameter(Mandatory)]
[ValidateNotNullOrEmpty()]
[string]$ResourceName

# Switch parameters
[Parameter()]
[switch]$Force
```

## Support

For questions about templates or creating new scripts:

1. Review existing scripts for patterns
1. Check template documentation
1. Follow repository coding standards
1. Test thoroughly before submitting
1. Include comprehensive documentation
