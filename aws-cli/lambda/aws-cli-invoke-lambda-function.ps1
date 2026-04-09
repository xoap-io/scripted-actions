<#
.SYNOPSIS
    Invoke an AWS Lambda function synchronously using AWS CLI.

.DESCRIPTION
    This script invokes an existing AWS Lambda function synchronously using the AWS CLI.
    The response payload is written to a file and its contents are printed to the console.
    The HTTP status code returned by the invocation is also displayed.
    The script uses the following AWS CLI command:
    aws lambda invoke --function-name $FunctionName $OutputFile

.PARAMETER FunctionName
    The name of the Lambda function to invoke. Must be 1-64 characters: letters,
    numbers, hyphens, and underscores only.

.PARAMETER Payload
    Optional JSON payload string to pass to the Lambda function.
    Example: '{"key":"value"}'.

.PARAMETER OutputFile
    The file path where the Lambda response payload will be written.
    Defaults to 'lambda-response.json'.

.PARAMETER Region
    The AWS region where the Lambda function resides.
    Must match the pattern '^[a-z]{2}-[a-z]+-\d$'.

.EXAMPLE
    .\aws-cli-invoke-lambda-function.ps1 -FunctionName "my-function"

.EXAMPLE
    .\aws-cli-invoke-lambda-function.ps1 -FunctionName "my-function" -Payload '{"key":"value","action":"process"}' -OutputFile "my-response.json" -Region "us-east-1"

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
    https://docs.aws.amazon.com/cli/latest/reference/lambda/invoke.html

.COMPONENT
    AWS CLI Lambda
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Lambda function to invoke (1-64 chars: letters, numbers, hyphens, underscores).")]
    [ValidatePattern('^[a-zA-Z0-9_-]{1,64}$')]
    [string]$FunctionName,

    [Parameter(Mandatory = $false, HelpMessage = "Optional JSON payload string to pass to the function. Example: '{key:value}'.")]
    [ValidateNotNullOrEmpty()]
    [string]$Payload,

    [Parameter(Mandatory = $false, HelpMessage = "File path where the Lambda response payload will be written. Defaults to 'lambda-response.json'.")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFile = 'lambda-response.json',

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region where the Lambda function resides (e.g. us-east-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Invoking AWS Lambda function '$FunctionName'..." -ForegroundColor Green

    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI is not installed or not in PATH. Please install it from https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    }

    Write-Host "🔧 Running aws lambda invoke..." -ForegroundColor Cyan

    $invokeArgs = @(
        'lambda', 'invoke',
        '--function-name', $FunctionName,
        '--output', 'json'
    )

    if ($Payload) {
        $invokeArgs += '--payload'
        $invokeArgs += $Payload
    }

    if ($Region) {
        $invokeArgs += '--region'
        $invokeArgs += $Region
    }

    # OutputFile must be the last positional argument for aws lambda invoke
    $invokeArgs += $OutputFile

    $invokeMetaJson = aws @invokeArgs

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI lambda invoke command failed with exit code $LASTEXITCODE"
    }

    $invokeMeta = $invokeMetaJson | ConvertFrom-Json

    Write-Host "`n✅ Lambda function '$FunctionName' invoked successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Status Code:     $($invokeMeta.StatusCode)" -ForegroundColor White
    Write-Host "   Response File:   $OutputFile" -ForegroundColor White

    if ($invokeMeta.FunctionError) {
        Write-Host "   Function Error:  $($invokeMeta.FunctionError)" -ForegroundColor Yellow
        Write-Host "⚠️  The function returned a function-level error. Check the response payload for details." -ForegroundColor Yellow
    }

    if (Test-Path $OutputFile) {
        $responseContent = Get-Content -Path $OutputFile -Raw
        Write-Host "`n📄 Response Payload:" -ForegroundColor Cyan
        Write-Host $responseContent -ForegroundColor White
    }
    else {
        Write-Host "ℹ️  Response file '$OutputFile' was not created by the CLI." -ForegroundColor Yellow
    }

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - View logs: aws logs tail /aws/lambda/$FunctionName --follow" -ForegroundColor White
    Write-Host "   - Check function configuration: aws lambda get-function --function-name $FunctionName" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
