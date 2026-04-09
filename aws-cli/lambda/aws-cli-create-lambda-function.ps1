<#
.SYNOPSIS
    Create an AWS Lambda function from a ZIP deployment package using AWS CLI.

.DESCRIPTION
    This script creates an AWS Lambda function using the AWS CLI. The deployment
    package can be supplied either as a local ZIP file (using the fileb:// prefix)
    or from an S3 bucket. Either ZipFile or both S3Bucket and S3Key must be provided.
    The script uses the following AWS CLI command:
    aws lambda create-function --function-name $FunctionName --runtime $Runtime --role $RoleArn

.PARAMETER FunctionName
    The name of the Lambda function. Must be 1-64 characters: letters, numbers,
    hyphens, and underscores only.

.PARAMETER Runtime
    The Lambda runtime identifier. Accepted values: python3.12, python3.11,
    python3.10, nodejs20.x, nodejs18.x, java21, java17, dotnet8, provided.al2023.

.PARAMETER RoleArn
    The Amazon Resource Name (ARN) of the IAM execution role for the function.
    Must match the pattern '^arn:aws:iam::\d{12}:role/.+$'.

.PARAMETER Handler
    The function handler entry point. Examples: 'index.handler',
    'lambda_function.lambda_handler'.

.PARAMETER ZipFile
    Path to a local ZIP deployment package. Must use the fileb:// prefix
    (e.g. 'fileb://function.zip').

.PARAMETER S3Bucket
    The name of the S3 bucket containing the deployment package.

.PARAMETER S3Key
    The S3 object key of the deployment package ZIP file.

.PARAMETER Description
    A description of the Lambda function.

.PARAMETER MemorySize
    The amount of memory available to the function at runtime in MB.
    Valid range: 128-10240. Defaults to 128.

.PARAMETER Timeout
    The function timeout in seconds. Valid range: 1-900. Defaults to 3.

.PARAMETER Environment
    Environment variables as a JSON string.
    Example: '{"Variables":{"KEY":"VALUE","DB_HOST":"localhost"}}'.

.PARAMETER Region
    The AWS region where the Lambda function will be created.
    Must match the pattern '^[a-z]{2}-[a-z]+-\d$'.

.EXAMPLE
    .\aws-cli-create-lambda-function.ps1 -FunctionName "my-function" -Runtime "python3.12" -RoleArn "arn:aws:iam::123456789012:role/lambda-role" -Handler "lambda_function.lambda_handler" -ZipFile "fileb://function.zip"

.EXAMPLE
    .\aws-cli-create-lambda-function.ps1 -FunctionName "my-function" -Runtime "nodejs20.x" -RoleArn "arn:aws:iam::123456789012:role/lambda-role" -Handler "index.handler" -S3Bucket "my-deploy-bucket" -S3Key "functions/my-function.zip" -MemorySize 256 -Timeout 30 -Description "My Node.js Lambda function" -Region "us-east-1"

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
    https://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html

.COMPONENT
    AWS CLI Lambda
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Lambda function (1-64 chars: letters, numbers, hyphens, underscores).")]
    [ValidatePattern('^[a-zA-Z0-9_-]{1,64}$')]
    [string]$FunctionName,

    [Parameter(Mandatory = $true, HelpMessage = "The Lambda runtime identifier (e.g. python3.12, nodejs20.x, java21, dotnet8).")]
    [ValidateSet('python3.12', 'python3.11', 'python3.10', 'nodejs20.x', 'nodejs18.x', 'java21', 'java17', 'dotnet8', 'provided.al2023')]
    [string]$Runtime,

    [Parameter(Mandatory = $true, HelpMessage = "The ARN of the IAM execution role (arn:aws:iam::123456789012:role/my-role).")]
    [ValidatePattern('^arn:aws:iam::\d{12}:role/.+$')]
    [string]$RoleArn,

    [Parameter(Mandatory = $true, HelpMessage = "The function handler entry point (e.g. 'index.handler' or 'lambda_function.lambda_handler').")]
    [ValidateNotNullOrEmpty()]
    [string]$Handler,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the local ZIP deployment package using the fileb:// prefix (e.g. fileb://function.zip).")]
    [ValidateNotNullOrEmpty()]
    [string]$ZipFile,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the S3 bucket containing the deployment package.")]
    [ValidateNotNullOrEmpty()]
    [string]$S3Bucket,

    [Parameter(Mandatory = $false, HelpMessage = "The S3 object key of the deployment package ZIP file.")]
    [ValidateNotNullOrEmpty()]
    [string]$S3Key,

    [Parameter(Mandatory = $false, HelpMessage = "A description of the Lambda function.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Memory available to the function at runtime in MB (128-10240). Defaults to 128.")]
    [ValidateRange(128, 10240)]
    [int]$MemorySize = 128,

    [Parameter(Mandatory = $false, HelpMessage = "Function timeout in seconds (1-900). Defaults to 3.")]
    [ValidateRange(1, 900)]
    [int]$Timeout = 3,

    [Parameter(Mandatory = $false, HelpMessage = "Environment variables as JSON string. Example: '{\"Variables\":{\"KEY\":\"VALUE\"}}'.")]
    [ValidateNotNullOrEmpty()]
    [string]$Environment,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region where the Lambda function will be created (e.g. us-east-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating AWS Lambda function '$FunctionName'..." -ForegroundColor Green

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI is not installed or not in PATH. Please install it from https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    }

    # Validate that at least one deployment source is provided
    if (-not $ZipFile -and -not ($S3Bucket -and $S3Key)) {
        throw "You must provide either -ZipFile or both -S3Bucket and -S3Key as the deployment package source."
    }

    if ($ZipFile -and ($S3Bucket -or $S3Key)) {
        throw "Specify either -ZipFile or -S3Bucket/-S3Key, not both."
    }

    if ($S3Bucket -and -not $S3Key) {
        throw "-S3Key is required when -S3Bucket is specified."
    }

    if ($S3Key -and -not $S3Bucket) {
        throw "-S3Bucket is required when -S3Key is specified."
    }

    Write-Host "🔧 Running aws lambda create-function..." -ForegroundColor Cyan

    $createArgs = @(
        'lambda', 'create-function',
        '--function-name', $FunctionName,
        '--runtime', $Runtime,
        '--role', $RoleArn,
        '--handler', $Handler,
        '--memory-size', $MemorySize,
        '--timeout', $Timeout,
        '--output', 'json'
    )

    if ($ZipFile) {
        $createArgs += '--zip-file'
        $createArgs += $ZipFile
    }
    else {
        $createArgs += '--code'
        $createArgs += "S3Bucket=$($S3Bucket),S3Key=$($S3Key)"
    }

    if ($Description) {
        $createArgs += '--description'
        $createArgs += $Description
    }

    if ($Environment) {
        $createArgs += '--environment'
        $createArgs += $Environment
    }

    if ($Region) {
        $createArgs += '--region'
        $createArgs += $Region
    }

    $functionJson = aws @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI lambda create-function command failed with exit code $LASTEXITCODE"
    }

    $function = $functionJson | ConvertFrom-Json

    Write-Host "`n✅ Lambda function '$FunctionName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Function Name: $($function.FunctionName)" -ForegroundColor White
    Write-Host "   ARN:           $($function.FunctionArn)" -ForegroundColor White
    Write-Host "   Runtime:       $($function.Runtime)" -ForegroundColor White
    Write-Host "   Handler:       $($function.Handler)" -ForegroundColor White
    Write-Host "   Memory (MB):   $($function.MemorySize)" -ForegroundColor White
    Write-Host "   Timeout (s):   $($function.Timeout)" -ForegroundColor White
    Write-Host "   State:         $($function.State)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Invoke the function: aws lambda invoke --function-name $FunctionName response.json" -ForegroundColor White
    Write-Host "   - View logs: aws logs tail /aws/lambda/$FunctionName --follow" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
