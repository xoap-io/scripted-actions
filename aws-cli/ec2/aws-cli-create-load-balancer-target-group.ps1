<#
.SYNOPSIS
    Create an ELB target group using the AWS CLI.

.DESCRIPTION
    Creates an Elastic Load Balancing v2 target group for use with Application,
    Network, or Gateway Load Balancers. Uses the AWS CLI command:
    aws elbv2 create-target-group.
    Outputs the TargetGroupArn and TargetGroupName on success.

.PARAMETER Region
    The AWS region in which to create the target group.

.PARAMETER TargetGroupName
    The name of the target group.

.PARAMETER Protocol
    The protocol for traffic to the targets. Default is HTTP.

.PARAMETER Port
    The port on which targets receive traffic (1-65535).

.PARAMETER VpcId
    The ID of the VPC in which to create the target group.

.PARAMETER TargetType
    The type of target: instance, ip, lambda, or alb. Default is instance.

.PARAMETER HealthCheckPath
    The health check path (HTTP/HTTPS protocols only). Default is /.

.PARAMETER HealthCheckProtocol
    The protocol for health checks. Defaults to the value of Protocol.

.EXAMPLE
    .\aws-cli-create-load-balancer-target-group.ps1 -Region "us-east-1" -TargetGroupName "web-tg" -Port 80 -VpcId "vpc-0a1b2c3d4e5f67890"

.EXAMPLE
    .\aws-cli-create-load-balancer-target-group.ps1 -Region "eu-west-1" -TargetGroupName "api-tg" -Protocol HTTPS -Port 443 -VpcId "vpc-0fedcba9876543210" -HealthCheckPath "/health"

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
    https://docs.aws.amazon.com/cli/latest/reference/elbv2/create-target-group.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to create the target group.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the target group.")]
    [ValidateNotNullOrEmpty()]
    [string]$TargetGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "The protocol for traffic to the targets. Default is HTTP.")]
    [ValidateSet('HTTP', 'HTTPS', 'TCP', 'TLS', 'UDP', 'TCP_UDP', 'GENEVE')]
    [string]$Protocol = 'HTTP',

    [Parameter(Mandatory = $true, HelpMessage = "The port on which targets receive traffic (1-65535).")]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC in which to create the target group.")]
    [ValidatePattern('^vpc-[a-f0-9]{8,17}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false, HelpMessage = "The type of target: instance, ip, lambda, or alb. Default is instance.")]
    [ValidateSet('instance', 'ip', 'lambda', 'alb')]
    [string]$TargetType = 'instance',

    [Parameter(Mandatory = $false, HelpMessage = "The health check path for HTTP/HTTPS protocols. Default is /.")]
    [string]$HealthCheckPath = '/',

    [Parameter(Mandatory = $false, HelpMessage = "The protocol to use for health checks. Defaults to Protocol.")]
    [ValidateSet('HTTP', 'HTTPS', 'TCP', 'TLS', 'UDP', 'TCP_UDP')]
    [string]$HealthCheckProtocol
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Default health check protocol to match target protocol
if (-not $HealthCheckProtocol) {
    $HealthCheckProtocol = if ($Protocol -in @('HTTP','HTTPS')) { $Protocol } else { 'TCP' }
}

try {
    Write-Host "🚀 Starting ELB Target Group Creation" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    Write-Host "🔧 Creating target group '$TargetGroupName'..." -ForegroundColor Cyan

    $awsArgs = @(
        'elbv2', 'create-target-group',
        '--region', $Region,
        '--name', $TargetGroupName,
        '--protocol', $Protocol,
        '--port', $Port,
        '--vpc-id', $VpcId,
        '--target-type', $TargetType,
        '--health-check-protocol', $HealthCheckProtocol,
        '--output', 'json'
    )

    # Add health check path for HTTP/HTTPS
    if ($Protocol -in @('HTTP', 'HTTPS')) {
        $awsArgs += @('--health-check-path', $HealthCheckPath)
    }

    $result = & aws @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create target group: $result"
    }

    $data = $result | ConvertFrom-Json
    $tg   = $data.TargetGroups[0]

    Write-Host "✅ Target group created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  TargetGroupName:  $($tg.TargetGroupName)" -ForegroundColor Cyan
    Write-Host "  TargetGroupArn:   $($tg.TargetGroupArn)" -ForegroundColor Cyan
    Write-Host "  Protocol:         $($tg.Protocol):$($tg.Port)" -ForegroundColor Cyan
    Write-Host "  Target type:      $($tg.TargetType)" -ForegroundColor Cyan
    Write-Host "  VPC:              $($tg.VpcId)" -ForegroundColor Cyan
    Write-Host "  Health check:     $($tg.HealthCheckProtocol) $($tg.HealthCheckPath)" -ForegroundColor Cyan

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Register targets: aws elbv2 register-targets --target-group-arn $($tg.TargetGroupArn) --targets Id=<instance-id>" -ForegroundColor Yellow
    Write-Host "  - Attach to a load balancer listener using the TargetGroupArn above." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
