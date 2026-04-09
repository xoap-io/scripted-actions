<#
.SYNOPSIS
    Deploy a Google Cloud Function (2nd gen) using gcloud CLI.

.DESCRIPTION
    This script deploys a Google Cloud Function (2nd generation) using the gcloud CLI.
    It supports HTTP triggers and event-driven triggers (Pub/Sub, Cloud Storage).
    The function source code is read from a local directory and deployed to the
    specified region with the chosen runtime.
    The script uses the following gcloud command:
    gcloud functions deploy $FunctionName --gen2 --runtime $Runtime --region $Region

.PARAMETER FunctionName
    The name of the Cloud Function to deploy. Must match GCP naming conventions:
    lowercase letters, digits, and hyphens, starting with a letter.

.PARAMETER Region
    The GCP region where the Cloud Function will be deployed.
    Must match the pattern '^[a-z]+-[a-z]+\d+$' (e.g. us-central1, europe-west1).

.PARAMETER Runtime
    The runtime for the Cloud Function. Accepted values: nodejs20, nodejs18,
    python312, python311, python310, go122, go121, java21, dotnet8.

.PARAMETER EntryPoint
    The name of the function entry point in the source code that will be executed
    when the Cloud Function is triggered.

.PARAMETER SourceDir
    Path to the local directory containing the function source code.
    Defaults to the current directory '.'.

.PARAMETER Trigger
    The trigger type for the Cloud Function. Accepted values: 'http', 'pubsub',
    'storage'. Defaults to 'http'.

.PARAMETER AllowUnauthenticated
    If specified, allows unauthenticated HTTP invocations of the function.
    Only applicable when Trigger is 'http'.

.PARAMETER Memory
    The amount of memory to allocate to the function. Examples: '256Mi', '512Mi',
    '1Gi'. Defaults to '256Mi'.

.PARAMETER ProjectId
    The GCP project ID in which the function will be deployed.
    Must match the pattern '^[a-z][a-z0-9-]{4,28}[a-z0-9]$'.

.EXAMPLE
    .\gce-cli-deploy-cloud-function.ps1 -FunctionName "my-http-function" -Region "us-central1" -Runtime "python312" -EntryPoint "handle_request"

.EXAMPLE
    .\gce-cli-deploy-cloud-function.ps1 -FunctionName "my-http-function" -Region "europe-west1" -Runtime "nodejs20" -EntryPoint "handleRequest" -SourceDir "./src" -AllowUnauthenticated -Memory "512Mi" -ProjectId "my-gcp-project"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Google Cloud SDK (https://cloud.google.com/sdk/docs/install)

.LINK
    https://cloud.google.com/sdk/gcloud/reference/functions/deploy

.COMPONENT
    Google Cloud CLI Cloud Functions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Cloud Function to deploy (lowercase letters, digits, hyphens; must start with a letter).")]
    [ValidatePattern('^[a-z][a-z0-9-]{0,61}[a-z0-9]$')]
    [string]$FunctionName,

    [Parameter(Mandatory = $true, HelpMessage = "The GCP region where the Cloud Function will be deployed (e.g. us-central1, europe-west1).")]
    [ValidatePattern('^[a-z]+-[a-z]+\d+$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The runtime for the Cloud Function (e.g. nodejs20, python312, go122, java21, dotnet8).")]
    [ValidateSet('nodejs20', 'nodejs18', 'python312', 'python311', 'python310', 'go122', 'go121', 'java21', 'dotnet8')]
    [string]$Runtime,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the function entry point in the source code to execute when triggered.")]
    [ValidateNotNullOrEmpty()]
    [string]$EntryPoint,

    [Parameter(Mandatory = $false, HelpMessage = "Path to the local directory containing the function source code. Defaults to current directory '.'.")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDir = '.',

    [Parameter(Mandatory = $false, HelpMessage = "The trigger type for the Cloud Function: 'http', 'pubsub', or 'storage'. Defaults to 'http'.")]
    [ValidateSet('http', 'pubsub', 'storage')]
    [string]$Trigger = 'http',

    [Parameter(Mandatory = $false, HelpMessage = "Allow unauthenticated HTTP invocations of the function. Only applicable for HTTP-triggered functions.")]
    [switch]$AllowUnauthenticated,

    [Parameter(Mandatory = $false, HelpMessage = "The amount of memory to allocate to the function (e.g. '256Mi', '512Mi', '1Gi'). Defaults to '256Mi'.")]
    [ValidateNotNullOrEmpty()]
    [string]$Memory = '256Mi',

    [Parameter(Mandatory = $false, HelpMessage = "The GCP project ID in which the function will be deployed.")]
    [ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]
    [string]$ProjectId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Deploying Google Cloud Function '$FunctionName' (2nd gen) to region '$Region'..." -ForegroundColor Green

    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
        throw "Google Cloud SDK (gcloud) is not installed or not in PATH. Please install it from https://cloud.google.com/sdk/docs/install"
    }

    # Validate source directory
    $resolvedSource = [System.IO.Path]::GetFullPath($SourceDir)
    if (-not (Test-Path $resolvedSource -PathType Container)) {
        throw "Source directory not found: $resolvedSource"
    }

    if ($ProjectId) {
        Write-Host "🔍 Setting active project to '$ProjectId'..." -ForegroundColor Cyan
        gcloud config set project $ProjectId --quiet 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set active GCP project to '$ProjectId'."
        }
    }

    Write-Host "🔧 Running gcloud functions deploy --gen2..." -ForegroundColor Cyan

    $deployArgs = @(
        'functions', 'deploy', $FunctionName,
        '--gen2',
        '--runtime', $Runtime,
        '--region', $Region,
        '--entry-point', $EntryPoint,
        '--source', $resolvedSource,
        '--memory', $Memory,
        '--format', 'json'
    )

    switch ($Trigger) {
        'http' {
            $deployArgs += '--trigger-http'
            if ($AllowUnauthenticated) {
                $deployArgs += '--allow-unauthenticated'
            }
            else {
                $deployArgs += '--no-allow-unauthenticated'
            }
        }
        'pubsub' {
            Write-Host "ℹ️  Pub/Sub trigger selected. Ensure the topic name is configured post-deployment." -ForegroundColor Yellow
            $deployArgs += '--trigger-topic'
            $deployArgs += 'default'
        }
        'storage' {
            Write-Host "ℹ️  Cloud Storage trigger selected. Ensure the bucket name is configured post-deployment." -ForegroundColor Yellow
            $deployArgs += '--trigger-bucket'
            $deployArgs += 'default'
        }
    }

    if ($ProjectId) {
        $deployArgs += '--project'
        $deployArgs += $ProjectId
    }

    $deployJson = gcloud @deployArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "gcloud functions deploy command failed with exit code $($LASTEXITCODE). Output: $deployJson"
    }

    # gcloud --format json may output a single object or array; normalize
    $deployOutput = $deployJson | Out-String | ConvertFrom-Json -ErrorAction SilentlyContinue

    Write-Host "`n✅ Cloud Function '$FunctionName' deployed successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Function Name: $FunctionName" -ForegroundColor White
    Write-Host "   Region:        $Region" -ForegroundColor White
    Write-Host "   Runtime:       $Runtime" -ForegroundColor White
    Write-Host "   Entry Point:   $EntryPoint" -ForegroundColor White
    Write-Host "   Memory:        $Memory" -ForegroundColor White
    Write-Host "   Trigger:       $Trigger" -ForegroundColor White

    if ($deployOutput -and $deployOutput.serviceConfig -and $deployOutput.serviceConfig.uri) {
        Write-Host "   URI:           $($deployOutput.serviceConfig.uri)" -ForegroundColor White
    }

    if ($deployOutput -and $deployOutput.state) {
        Write-Host "   State:         $($deployOutput.state)" -ForegroundColor White
    }

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Describe function: gcloud functions describe $FunctionName --region $Region --gen2" -ForegroundColor White
    if ($Trigger -eq 'http') {
        Write-Host "   - Get URL: gcloud functions describe $FunctionName --region $Region --gen2 --format='value(serviceConfig.uri)'" -ForegroundColor White
    }
    Write-Host "   - View logs: gcloud functions logs read $FunctionName --region $Region --gen2" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
