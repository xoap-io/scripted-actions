<#
.SYNOPSIS
    Create an Amazon RDS database instance using AWS CLI.

.DESCRIPTION
    This script provisions a new Amazon RDS database instance with configurable
    engine, instance class, storage, networking, and security options.
    The creation operation is asynchronous — the instance enters a 'creating'
    state and becomes available after several minutes. Uses
    aws rds create-db-instance to provision the instance.

.PARAMETER DBInstanceIdentifier
    A unique identifier for the DB instance. Must start with a letter, contain
    only alphanumeric characters and hyphens, and be 1-63 characters long.

.PARAMETER DBInstanceClass
    The compute and memory capacity of the DB instance.
    Example: db.t3.micro, db.m5.large, db.r5.xlarge

.PARAMETER Engine
    The database engine to use. Supported values: mysql, postgres, mariadb,
    oracle-ee, oracle-se2, sqlserver-ee, sqlserver-se, sqlserver-ex, sqlserver-web.

.PARAMETER MasterUsername
    The master username for the DB instance.

.PARAMETER MasterUserPassword
    The password for the master user. Must meet the engine-specific password
    requirements. Handled as a plain string for XOAP compatibility.

.PARAMETER AllocatedStorage
    The amount of storage (in GB) to allocate for the DB instance.
    Minimum 20 GB, maximum 65536 GB. Defaults to 20.

.PARAMETER DBName
    The name of the initial database to create on the instance.
    Not supported for all engines (e.g. SQL Server).

.PARAMETER VpcSecurityGroupIds
    Comma-separated list of VPC security group IDs to associate with the instance.
    Example: sg-0a1b2c3d4e5f67890,sg-0f1e2d3c4b5a67890

.PARAMETER DBSubnetGroupName
    The name of the DB subnet group for the instance. Required for VPC deployments.

.PARAMETER MultiAZ
    Enable Multi-AZ deployment for high availability.

.PARAMETER StorageEncrypted
    Enable encryption for the DB instance storage.

.PARAMETER Region
    The AWS region in which to create the DB instance.
    Example: us-east-1, eu-west-1

.EXAMPLE
    .\aws-cli-create-rds-instance.ps1 `
        -DBInstanceIdentifier "my-db-01" `
        -DBInstanceClass "db.t3.micro" `
        -Engine "mysql" `
        -MasterUsername "admin" `
        -MasterUserPassword "MySecurePass123!" `
        -AllocatedStorage 20

.EXAMPLE
    .\aws-cli-create-rds-instance.ps1 `
        -DBInstanceIdentifier "prod-postgres-01" `
        -DBInstanceClass "db.m5.large" `
        -Engine "postgres" `
        -MasterUsername "dbadmin" `
        -MasterUserPassword "MySecurePass123!" `
        -DBName "appdb" `
        -AllocatedStorage 100 `
        -VpcSecurityGroupIds "sg-0a1b2c3d4e5f67890" `
        -DBSubnetGroupName "my-db-subnet-group" `
        -MultiAZ `
        -StorageEncrypted `
        -Region "us-east-1"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/rds/create-db-instance.html

.COMPONENT
    AWS CLI Relational Database Service
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "A unique identifier for the DB instance (letters, digits, hyphens; 1-63 chars; must start with a letter).")]
    [ValidatePattern('^[a-zA-Z][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]$')]
    [string]$DBInstanceIdentifier,

    [Parameter(Mandatory = $true, HelpMessage = "The compute and memory class of the DB instance. Example: db.t3.micro, db.m5.large.")]
    [ValidateNotNullOrEmpty()]
    [string]$DBInstanceClass,

    [Parameter(Mandatory = $true, HelpMessage = "The database engine: mysql, postgres, mariadb, oracle-ee, oracle-se2, sqlserver-ee, sqlserver-se, sqlserver-ex, sqlserver-web.")]
    [ValidateSet(
        'mysql',
        'postgres',
        'mariadb',
        'oracle-ee',
        'oracle-se2',
        'sqlserver-ee',
        'sqlserver-se',
        'sqlserver-ex',
        'sqlserver-web'
    )]
    [string]$Engine,

    [Parameter(Mandatory = $true, HelpMessage = "The master username for the DB instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$MasterUsername,

    [Parameter(Mandatory = $true, HelpMessage = "The password for the master user. Must meet engine-specific password requirements.")]
    [ValidateNotNullOrEmpty()]
    [string]$MasterUserPassword,

    [Parameter(Mandatory = $false, HelpMessage = "The amount of storage in GB to allocate (20-65536). Defaults to 20.")]
    [ValidateRange(20, 65536)]
    [int]$AllocatedStorage = 20,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the initial database to create on the instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$DBName,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated VPC security group IDs. Example: sg-0a1b2c3d,sg-0f1e2d3c.")]
    [ValidateNotNullOrEmpty()]
    [string]$VpcSecurityGroupIds,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the DB subnet group for the instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$DBSubnetGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Enable Multi-AZ deployment for high availability.")]
    [switch]$MultiAZ,

    [Parameter(Mandatory = $false, HelpMessage = "Enable encryption for the DB instance storage.")]
    [switch]$StorageEncrypted,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region in which to create the DB instance. Example: us-east-1.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "`n🚀 Starting RDS instance creation..." -ForegroundColor Green

    # Check AWS CLI availability
    Write-Host "🔍 Checking AWS CLI availability..." -ForegroundColor Cyan
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI is not installed or not in PATH. Install from https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    }

    Write-Host "ℹ️  Instance ID : $($DBInstanceIdentifier)" -ForegroundColor Yellow
    Write-Host "ℹ️  Engine      : $($Engine)" -ForegroundColor Yellow
    Write-Host "ℹ️  Class       : $($DBInstanceClass)" -ForegroundColor Yellow
    Write-Host "ℹ️  Storage     : $($AllocatedStorage) GB" -ForegroundColor Yellow

    # Build AWS CLI arguments
    $awsArgs = @(
        'rds', 'create-db-instance',
        '--db-instance-identifier', $DBInstanceIdentifier,
        '--db-instance-class', $DBInstanceClass,
        '--engine', $Engine,
        '--master-username', $MasterUsername,
        '--master-user-password', $MasterUserPassword,
        '--allocated-storage', $AllocatedStorage,
        '--output', 'json'
    )

    if ($DBName) {
        $awsArgs += '--db-name', $DBName
    }

    if ($VpcSecurityGroupIds) {
        $sgList = $VpcSecurityGroupIds -split ',' | ForEach-Object { $_.Trim() }
        $awsArgs += '--vpc-security-group-ids'
        $awsArgs += $sgList
    }

    if ($DBSubnetGroupName) {
        $awsArgs += '--db-subnet-group-name', $DBSubnetGroupName
    }

    if ($MultiAZ) {
        $awsArgs += '--multi-az'
    }
    else {
        $awsArgs += '--no-multi-az'
    }

    if ($StorageEncrypted) {
        $awsArgs += '--storage-encrypted'
    }

    if ($Region) {
        $awsArgs += '--region', $Region
    }

    Write-Host "🔧 Submitting RDS instance creation request..." -ForegroundColor Cyan

    $result = & aws @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "aws rds create-db-instance failed: $result"
    }

    $instanceInfo = $result | ConvertFrom-Json
    $instance = $instanceInfo.DBInstance

    Write-Host "`n✅ RDS instance creation initiated successfully!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Instance ID  : $($instance.DBInstanceIdentifier)" -ForegroundColor Green
    Write-Host "   Status       : $($instance.DBInstanceStatus)" -ForegroundColor Green
    Write-Host "   Engine       : $($instance.Engine) $($instance.EngineVersion)" -ForegroundColor Green
    Write-Host "   Class        : $($instance.DBInstanceClass)" -ForegroundColor Green
    Write-Host "   Storage      : $($instance.AllocatedStorage) GB" -ForegroundColor Green
    Write-Host "   Multi-AZ     : $($instance.MultiAZ)" -ForegroundColor Green
    Write-Host "   Encrypted    : $($instance.StorageEncrypted)" -ForegroundColor Green

    Write-Host "`n⚠️  Note: Instance creation is asynchronous. The instance will be available in several minutes." -ForegroundColor Yellow
    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   Monitor status with:" -ForegroundColor Yellow

    $describeCmd = "   aws rds describe-db-instances --db-instance-identifier $($DBInstanceIdentifier)"
    if ($Region) {
        $describeCmd += " --region $($Region)"
    }
    Write-Host $describeCmd -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
