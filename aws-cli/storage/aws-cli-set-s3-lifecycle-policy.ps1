<#
.SYNOPSIS
    Set an S3 lifecycle policy on an existing bucket using the AWS CLI.

.DESCRIPTION
    Configures an Amazon S3 lifecycle policy that transitions objects through
    Standard-IA and Glacier storage classes before expiring them. Uses the
    AWS CLI command: aws s3api put-bucket-lifecycle-configuration.
    An optional prefix restricts the policy to matching object keys only.

.PARAMETER Region
    The AWS region where the bucket resides.

.PARAMETER BucketName
    The name of the S3 bucket to apply the lifecycle policy to.

.PARAMETER TransitionToIaDays
    Number of days after creation to transition objects to Standard-IA (30-365). Default is 30.

.PARAMETER TransitionToGlacierDays
    Number of days after creation to transition objects to Glacier (60-730). Default is 90.

.PARAMETER ExpirationDays
    Number of days after creation to permanently delete objects (90-3650). Default is 365.

.PARAMETER Prefix
    Apply the lifecycle rule only to objects whose key begins with this prefix.
    If omitted, the rule applies to all objects in the bucket.

.EXAMPLE
    .\aws-cli-set-s3-lifecycle-policy.ps1 -Region "us-east-1" -BucketName "my-archive-bucket"

.EXAMPLE
    .\aws-cli-set-s3-lifecycle-policy.ps1 -Region "eu-west-1" -BucketName "my-logs-bucket" -Prefix "logs/" -TransitionToIaDays 60 -TransitionToGlacierDays 180 -ExpirationDays 730

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
    https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-lifecycle-configuration.html

.COMPONENT
    AWS CLI S3
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region where the bucket resides.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the S3 bucket.")]
    [ValidateNotNullOrEmpty()]
    [string]$BucketName,

    [Parameter(Mandatory = $false, HelpMessage = "Days before transitioning to Standard-IA (30-365). Default is 30.")]
    [ValidateRange(30, 365)]
    [int]$TransitionToIaDays = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Days before transitioning to Glacier (60-730). Default is 90.")]
    [ValidateRange(60, 730)]
    [int]$TransitionToGlacierDays = 90,

    [Parameter(Mandatory = $false, HelpMessage = "Days before expiring (deleting) objects (90-3650). Default is 365.")]
    [ValidateRange(90, 3650)]
    [int]$ExpirationDays = 365,

    [Parameter(Mandatory = $false, HelpMessage = "Apply lifecycle rule only to objects with this key prefix.")]
    [string]$Prefix
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Validate day ordering
if ($TransitionToGlacierDays -le $TransitionToIaDays) {
    Write-Host "❌ TransitionToGlacierDays ($TransitionToGlacierDays) must be greater than TransitionToIaDays ($TransitionToIaDays)." -ForegroundColor Red
    exit 1
}
if ($ExpirationDays -le $TransitionToGlacierDays) {
    Write-Host "❌ ExpirationDays ($ExpirationDays) must be greater than TransitionToGlacierDays ($TransitionToGlacierDays)." -ForegroundColor Red
    exit 1
}

try {
    Write-Host "🚀 Starting S3 Lifecycle Policy Configuration" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    Write-Host "🔍 Verifying bucket '$BucketName' exists..." -ForegroundColor Cyan
    aws s3api head-bucket --bucket $BucketName --region $Region 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Bucket '$BucketName' does not exist or is not accessible." }
    Write-Host "✅ Bucket verified." -ForegroundColor Green

    # Build lifecycle configuration JSON
    $rulePrefix = if ($Prefix) { $Prefix } else { '' }
    $lifecycleConfig = @{
        Rules = @(
            @{
                ID     = "XOAP-LifecycleRule-$(Get-Date -Format 'yyyyMMdd')"
                Status = 'Enabled'
                Filter = @{ Prefix = $rulePrefix }
                Transitions = @(
                    @{ Days = $TransitionToIaDays;     StorageClass = 'STANDARD_IA' }
                    @{ Days = $TransitionToGlacierDays; StorageClass = 'GLACIER' }
                )
                Expiration = @{ Days = $ExpirationDays }
            }
        )
    }

    $lifecycleJson = $lifecycleConfig | ConvertTo-Json -Depth 6 -Compress

    Write-Host "🔧 Applying lifecycle policy to bucket '$BucketName'..." -ForegroundColor Cyan
    $result = aws s3api put-bucket-lifecycle-configuration `
        --region $Region `
        --bucket $BucketName `
        --lifecycle-configuration $lifecycleJson 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set lifecycle policy: $result"
    }

    Write-Host "✅ Lifecycle policy applied successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Bucket:             $BucketName" -ForegroundColor Cyan
    Write-Host "  Prefix filter:      $(if ($Prefix) { $Prefix } else { '(all objects)' })" -ForegroundColor Cyan
    Write-Host "  → Standard-IA:      after $TransitionToIaDays days" -ForegroundColor Cyan
    Write-Host "  → Glacier:          after $TransitionToGlacierDays days" -ForegroundColor Cyan
    Write-Host "  → Expire/Delete:    after $ExpirationDays days" -ForegroundColor Cyan
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
