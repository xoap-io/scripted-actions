<#
.SYNOPSIS
    Add a rule to a Network ACL using the AWS CLI.

.DESCRIPTION
    Creates an inbound or outbound rule in an Amazon VPC Network ACL using the
    AWS CLI command: aws ec2 create-network-acl-entry. Supports TCP, UDP, ICMP,
    and all-traffic rules with allow or deny actions.

.PARAMETER Region
    The AWS region where the Network ACL resides.

.PARAMETER NetworkAclId
    The ID of the Network ACL to add the rule to.

.PARAMETER RuleNumber
    The rule priority number (1-32766). Lower numbers are evaluated first.

.PARAMETER Protocol
    The IP protocol: tcp, udp, icmp, or all. Default is tcp.

.PARAMETER RuleAction
    Whether to allow or deny matching traffic. Default is allow.

.PARAMETER Egress
    When specified, creates an egress (outbound) rule. Default is ingress.

.PARAMETER CidrBlock
    The IPv4 CIDR block for the rule (e.g. 10.0.0.0/8).

.PARAMETER FromPort
    The first port in the port range (TCP/UDP rules only).

.PARAMETER ToPort
    The last port in the port range (TCP/UDP rules only).

.EXAMPLE
    .\aws-cli-create-network-acl-entry.ps1 -Region "us-east-1" -NetworkAclId "acl-0a1b2c3d4e5f67890" -RuleNumber 100 -CidrBlock "10.0.0.0/8" -FromPort 443 -ToPort 443

.EXAMPLE
    .\aws-cli-create-network-acl-entry.ps1 -Region "eu-west-1" -NetworkAclId "acl-0fedcba9876543210" -RuleNumber 200 -Protocol tcp -RuleAction deny -CidrBlock "192.168.100.0/24" -FromPort 0 -ToPort 65535 -Egress

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-network-acl-entry.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region where the Network ACL resides.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the Network ACL.")]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkAclId,

    [Parameter(Mandatory = $true, HelpMessage = "Rule priority number (1-32766). Lower numbers are evaluated first.")]
    [ValidateRange(1, 32766)]
    [int]$RuleNumber,

    [Parameter(Mandatory = $false, HelpMessage = "IP protocol: tcp, udp, icmp, or all. Default is tcp.")]
    [ValidateSet('tcp', 'udp', 'icmp', 'all')]
    [string]$Protocol = 'tcp',

    [Parameter(Mandatory = $false, HelpMessage = "Rule action: allow or deny. Default is allow.")]
    [ValidateSet('allow', 'deny')]
    [string]$RuleAction = 'allow',

    [Parameter(Mandatory = $false, HelpMessage = "Create an egress (outbound) rule. Default creates an ingress rule.")]
    [switch]$Egress,

    [Parameter(Mandatory = $true, HelpMessage = "The IPv4 CIDR block for the rule (e.g. 10.0.0.0/8).")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$CidrBlock,

    [Parameter(Mandatory = $false, HelpMessage = "First port in range (TCP/UDP only, 0-65535).")]
    [ValidateRange(0, 65535)]
    [int]$FromPort,

    [Parameter(Mandatory = $false, HelpMessage = "Last port in range (TCP/UDP only, 0-65535).")]
    [ValidateRange(0, 65535)]
    [int]$ToPort
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Map protocol to number for NACL entry
$protocolNumber = switch ($Protocol) {
    'tcp'  { '6' }
    'udp'  { '17' }
    'icmp' { '1' }
    'all'  { '-1' }
}

try {
    Write-Host "🚀 Starting Network ACL Entry Creation" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    $direction = if ($Egress) { 'egress' } else { 'ingress' }
    Write-Host "🔧 Adding $direction rule #$RuleNumber to NACL '$NetworkAclId'..." -ForegroundColor Cyan

    $awsArgs = @(
        'ec2', 'create-network-acl-entry',
        '--region', $Region,
        '--network-acl-id', $NetworkAclId,
        '--rule-number', $RuleNumber,
        '--protocol', $protocolNumber,
        '--rule-action', $RuleAction,
        '--cidr-block', $CidrBlock
    )

    # Add direction flag
    if ($Egress) {
        $awsArgs += '--egress'
    } else {
        $awsArgs += '--ingress'
    }

    # Add port range for TCP/UDP
    if ($Protocol -in @('tcp', 'udp') -and ($PSBoundParameters.ContainsKey('FromPort') -or $PSBoundParameters.ContainsKey('ToPort'))) {
        $portFrom = if ($PSBoundParameters.ContainsKey('FromPort')) { $FromPort } else { 0 }
        $portTo   = if ($PSBoundParameters.ContainsKey('ToPort'))   { $ToPort }   else { 65535 }
        $awsArgs += @('--port-range', "From=$portFrom,To=$portTo")
    }

    # Add ICMP type/code for ICMP rules (allow all by default)
    if ($Protocol -eq 'icmp') {
        $awsArgs += @('--icmp-type-code', 'Code=-1,Type=-1')
    }

    $result = & aws @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create NACL entry: $result"
    }

    Write-Host "✅ Network ACL entry created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Network ACL:    $NetworkAclId" -ForegroundColor Cyan
    Write-Host "  Rule number:    $RuleNumber" -ForegroundColor Cyan
    Write-Host "  Direction:      $direction" -ForegroundColor Cyan
    Write-Host "  Protocol:       $Protocol ($protocolNumber)" -ForegroundColor Cyan
    Write-Host "  Action:         $RuleAction" -ForegroundColor Cyan
    Write-Host "  CIDR:           $CidrBlock" -ForegroundColor Cyan
    if ($Protocol -in @('tcp', 'udp')) {
        $pFrom = if ($PSBoundParameters.ContainsKey('FromPort')) { $FromPort } else { 0 }
        $pTo   = if ($PSBoundParameters.ContainsKey('ToPort'))   { $ToPort }   else { 65535 }
        Write-Host "  Port range:     $pFrom - $pTo" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
