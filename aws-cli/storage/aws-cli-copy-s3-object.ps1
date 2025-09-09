<#
.SYNOPSIS
    Copy objects between S3 buckets or within the same bucket using AWS CLI.

.DESCRIPTION
    This script copies S3 objects using the latest AWS CLI (v2.16+).
    Supports copying individual objects or entire prefixes with various options.

.PARAMETER SourceS3Path
    Source S3 path (s3://bucket-name/object-key or s3://bucket-name/prefix/).

.PARAMETER DestinationS3Path
    Destination S3 path (s3://bucket-name/object-key or s3://bucket-name/prefix/).

.PARAMETER Recursive
    Copy all objects under the specified prefix recursively.

.PARAMETER StorageClass
    Storage class for the copied objects.

.PARAMETER ServerSideEncryption
    Server-side encryption method (AES256, aws:kms).

.PARAMETER KmsKeyId
    KMS key ID for encryption (when using aws:kms).

.PARAMETER MetadataDirective
    How to handle metadata (COPY or REPLACE).

.PARAMETER CacheControl
    Cache-Control header for copied objects.

.PARAMETER ContentType
    Content-Type header for copied objects.

.PARAMETER ExcludePatterns
    Comma-separated list of patterns to exclude.

.PARAMETER IncludePatterns
    Comma-separated list of patterns to include.

.PARAMETER DryRun
    Show what would be copied without actually performing the operation.

.PARAMETER Region
    The AWS region to use (optional, uses default if not specified).

.PARAMETER AwsProfile
    The AWS CLI profile to use (optional).

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\aws-cli-copy-s3-object.ps1 -SourceS3Path "s3://source-bucket/file.txt" -DestinationS3Path "s3://dest-bucket/file.txt"

.EXAMPLE
    .\aws-cli-copy-s3-object.ps1 -SourceS3Path "s3://source-bucket/folder/" -DestinationS3Path "s3://dest-bucket/backup/" -Recursive

.EXAMPLE
    .\aws-cli-copy-s3-object.ps1 -SourceS3Path "s3://bucket/data/" -DestinationS3Path "s3://bucket/archive/" -Recursive -StorageClass "GLACIER"

.NOTES
    Requires AWS CLI v2.16+ and appropriate IAM permissions for S3 operations.

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^s3://[a-z0-9][a-z0-9\-]*[a-z0-9]/.*$')]
    [string]$SourceS3Path,

    [Parameter(Mandatory)]
    [ValidatePattern('^s3://[a-z0-9][a-z0-9\-]*[a-z0-9]/.*$')]
    [string]$DestinationS3Path,

    [Parameter()]
    [switch]$Recursive,

    [Parameter()]
    [ValidateSet("STANDARD", "REDUCED_REDUNDANCY", "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING", "GLACIER", "DEEP_ARCHIVE", "GLACIER_IR")]
    [string]$StorageClass,

    [Parameter()]
    [ValidateSet("AES256", "aws:kms")]
    [string]$ServerSideEncryption,

    [Parameter()]
    [string]$KmsKeyId,

    [Parameter()]
    [ValidateSet("COPY", "REPLACE")]
    [string]$MetadataDirective,

    [Parameter()]
    [string]$CacheControl,

    [Parameter()]
    [string]$ContentType,

    [Parameter()]
    [string]$ExcludePatterns,

    [Parameter()]
    [string]$IncludePatterns,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d{1}$')]
    [string]$Region,

    [Parameter()]
    [string]$AwsProfile,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Check AWS CLI availability
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    Write-Host "Starting S3 copy operation..." -ForegroundColor Green

    # Build AWS CLI arguments
    $awsArgs = @()
    if ($Region) {
        $awsArgs += '--region', $Region
    }
    if ($AwsProfile) {
        $awsArgs += '--profile', $AwsProfile
    }

    # Extract bucket names for validation
    $sourceBucket = ($SourceS3Path -replace '^s3://', '') -split '/' | Select-Object -First 1
    $destBucket = ($DestinationS3Path -replace '^s3://', '') -split '/' | Select-Object -First 1

    # Validate source bucket access
    Write-Host "Validating source bucket access..." -ForegroundColor Cyan
    $sourceBucketResult = aws s3api head-bucket --bucket $sourceBucket @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot access source bucket '$sourceBucket': $sourceBucketResult"
    }

    # Validate destination bucket access
    Write-Host "Validating destination bucket access..." -ForegroundColor Cyan
    $destBucketResult = aws s3api head-bucket --bucket $destBucket @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot access destination bucket '$destBucket': $destBucketResult"
    }

    # Check if source exists
    Write-Host "Checking source object(s)..." -ForegroundColor Cyan
    if ($Recursive) {
        $sourceCheckResult = aws s3 ls $SourceS3Path @awsArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Source path does not exist or is not accessible: $SourceS3Path"
        }
        $sourceObjects = $sourceCheckResult -split "`n" | Where-Object { $_.Trim() -ne "" }
        Write-Host "Found $($sourceObjects.Count) object(s) in source" -ForegroundColor Yellow
    } else {
        # For single object, use head-object
        $sourceKey = $SourceS3Path -replace "^s3://$sourceBucket/", ""
        $objectCheckResult = aws s3api head-object --bucket $sourceBucket --key $sourceKey @awsArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Source object does not exist: $SourceS3Path"
        }
        Write-Host "Source object exists" -ForegroundColor Yellow
    }

    # Display copy configuration
    Write-Host "Copy Configuration:" -ForegroundColor Cyan
    Write-Host "  Source: $SourceS3Path" -ForegroundColor White
    Write-Host "  Destination: $DestinationS3Path" -ForegroundColor White
    Write-Host "  Recursive: $Recursive" -ForegroundColor White
    Write-Host "  Dry Run: $DryRun" -ForegroundColor White

    if ($StorageClass) {
        Write-Host "  Storage Class: $StorageClass" -ForegroundColor White
    }
    if ($ServerSideEncryption) {
        Write-Host "  Encryption: $ServerSideEncryption" -ForegroundColor White
    }
    if ($MetadataDirective) {
        Write-Host "  Metadata Directive: $MetadataDirective" -ForegroundColor White
    }
    if ($ExcludePatterns) {
        Write-Host "  Exclude Patterns: $ExcludePatterns" -ForegroundColor White
    }
    if ($IncludePatterns) {
        Write-Host "  Include Patterns: $IncludePatterns" -ForegroundColor White
    }

    # Build copy command
    if ($Recursive) {
        $copyArgs = @('s3', 'cp', $SourceS3Path, $DestinationS3Path, '--recursive')
    } else {
        $copyArgs = @('s3', 'cp', $SourceS3Path, $DestinationS3Path)
    }
    
    $copyArgs += $awsArgs

    if ($DryRun) {
        $copyArgs += '--dryrun'
    }

    if ($ExcludePatterns) {
        $patterns = $ExcludePatterns -split ','
        foreach ($pattern in $patterns) {
            $copyArgs += '--exclude', $pattern.Trim()
        }
    }

    if ($IncludePatterns) {
        $patterns = $IncludePatterns -split ','
        foreach ($pattern in $patterns) {
            $copyArgs += '--include', $pattern.Trim()
        }
    }

    if ($StorageClass) {
        $copyArgs += '--storage-class', $StorageClass
    }

    if ($ServerSideEncryption) {
        $copyArgs += '--sse', $ServerSideEncryption
        if ($KmsKeyId -and $ServerSideEncryption -eq 'aws:kms') {
            $copyArgs += '--sse-kms-key-id', $KmsKeyId
        }
    }

    if ($MetadataDirective) {
        $copyArgs += '--metadata-directive', $MetadataDirective
    }

    if ($CacheControl) {
        $copyArgs += '--cache-control', $CacheControl
    }

    if ($ContentType) {
        $copyArgs += '--content-type', $ContentType
    }

    # Confirmation unless Force or DryRun
    if (-not $Force -and -not $DryRun) {
        Write-Host "`n⚠️  This operation will copy objects to the destination" -ForegroundColor Yellow
        if ($StorageClass -in @('GLACIER', 'DEEP_ARCHIVE')) {
            Write-Host "⚠️  Objects will be stored in $StorageClass (retrieval costs apply)" -ForegroundColor Red
        }
        $confirm = Read-Host "Proceed with copy operation? (y/N)"
        if ($confirm -notmatch '^[Yy]') {
            Write-Host "Operation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Execute copy
    Write-Host "`nExecuting copy operation..." -ForegroundColor Cyan
    Write-Host "Command: aws $($copyArgs -join ' ')" -ForegroundColor Gray
    
    $result = aws @copyArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Copy operation failed: $result"
    }

    Write-Host "✓ Copy operation completed successfully" -ForegroundColor Green
    
    # Display results
    if ($result) {
        Write-Host "`nCopy Results:" -ForegroundColor Cyan
        Write-Output $result
    }

    # Get summary information if not dry run
    if (-not $DryRun) {
        Write-Host "`nVerifying copied objects..." -ForegroundColor Cyan
        
        if ($Recursive) {
            $verifyResult = aws s3 ls $DestinationS3Path --recursive --summarize @awsArgs 2>&1
            if ($LASTEXITCODE -eq 0) {
                $lines = $verifyResult -split "`n"
                $totalObjects = ($lines | Where-Object { $_ -match "Total Objects:" }) -replace ".*Total Objects: ", ""
                $totalSize = ($lines | Where-Object { $_ -match "Total Size:" }) -replace ".*Total Size: ", ""
                
                if ($totalObjects -and $totalSize) {
                    Write-Host "Destination Summary:" -ForegroundColor Cyan
                    Write-Host "  Total Objects: $totalObjects" -ForegroundColor White
                    Write-Host "  Total Size: $totalSize" -ForegroundColor White
                }
            }
        } else {
            # Verify single object
            $destKey = $DestinationS3Path -replace "^s3://$destBucket/", ""
            $verifyResult = aws s3api head-object --bucket $destBucket --key $destKey @awsArgs --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                $objectData = $verifyResult | ConvertFrom-Json
                Write-Host "Copied Object Details:" -ForegroundColor Cyan
                Write-Host "  Size: $($objectData.ContentLength) bytes" -ForegroundColor White
                Write-Host "  Last Modified: $($objectData.LastModified)" -ForegroundColor White
                Write-Host "  ETag: $($objectData.ETag)" -ForegroundColor White
                if ($objectData.ServerSideEncryption) {
                    Write-Host "  Encryption: $($objectData.ServerSideEncryption)" -ForegroundColor White
                }
                if ($objectData.StorageClass) {
                    Write-Host "  Storage Class: $($objectData.StorageClass)" -ForegroundColor White
                }
            }
        }
    }

    Write-Host "`n📝 Important Notes:" -ForegroundColor Cyan
    Write-Host "1. Copied objects inherit the destination bucket's default settings" -ForegroundColor White
    Write-Host "2. Cross-region copies may incur data transfer charges" -ForegroundColor White
    Write-Host "3. Consider lifecycle policies for automatic storage class transitions" -ForegroundColor White
    Write-Host "4. Monitor S3 costs, especially for Glacier storage classes" -ForegroundColor White

    if ($DryRun) {
        Write-Host "`n💡 This was a dry run. No objects were actually copied." -ForegroundColor Yellow
        Write-Host "Remove the -DryRun parameter to perform the actual copy." -ForegroundColor Yellow
    }

    Write-Host "`n✅ S3 copy operation completed!" -ForegroundColor Green

} catch {
    Write-Error "Failed to copy S3 objects: $($_.Exception.Message)"
    exit 1
}
