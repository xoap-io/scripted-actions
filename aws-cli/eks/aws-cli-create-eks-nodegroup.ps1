<#
.SYNOPSIS
    Create a managed node group in an existing EKS cluster using AWS CLI.

.DESCRIPTION
    This script creates a managed node group in an existing Amazon Elastic Kubernetes
    Service (EKS) cluster using the AWS CLI. Node group creation is asynchronous —
    the node group is returned in CREATING status and transitions to ACTIVE once
    EC2 instances are provisioned and joined to the cluster.
    The script uses the following AWS CLI command:
    aws eks create-nodegroup --cluster-name $ClusterName --nodegroup-name $NodegroupName

.PARAMETER ClusterName
    Defines the name of the existing EKS cluster to add the node group to.

.PARAMETER NodegroupName
    Defines the name of the managed node group to create.

.PARAMETER NodeRole
    Defines the IAM role ARN that the EC2 nodes use to make AWS API calls
    (e.g. 'arn:aws:iam::123456789012:role/eks-node-role').

.PARAMETER Subnets
    Defines the comma-separated list of VPC subnet IDs where the node group nodes
    will be launched (e.g. 'subnet-abc12345,subnet-def67890').

.PARAMETER InstanceTypes
    Defines the EC2 instance type for the nodes (e.g. 't3.medium', 'm5.large').
    Default: 't3.medium'.

.PARAMETER DesiredSize
    Defines the desired number of nodes in the node group. Default: 2.

.PARAMETER MinSize
    Defines the minimum number of nodes in the node group. Default: 1.

.PARAMETER MaxSize
    Defines the maximum number of nodes in the node group. Default: 4.

.PARAMETER Region
    Defines the AWS region of the EKS cluster (e.g. 'us-east-1').
    If omitted, the default region from the AWS CLI configuration is used.

.EXAMPLE
    .\aws-cli-create-eks-nodegroup.ps1 -ClusterName "eks-prod-01" -NodegroupName "ng-general" -NodeRole "arn:aws:iam::123456789012:role/eks-node-role" -Subnets "subnet-abc12345,subnet-def67890"

.EXAMPLE
    .\aws-cli-create-eks-nodegroup.ps1 -ClusterName "eks-prod-01" -NodegroupName "ng-general" -NodeRole "arn:aws:iam::123456789012:role/eks-node-role" -Subnets "subnet-abc12345,subnet-def67890" -InstanceTypes "m5.large" -DesiredSize 4 -MinSize 2 -MaxSize 8 -Region "us-east-1"

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
    https://docs.aws.amazon.com/cli/latest/reference/eks/create-nodegroup.html

.COMPONENT
    AWS CLI Elastic Kubernetes Service
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing EKS cluster to add the node group to")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the managed node group to create")]
    [ValidateNotNullOrEmpty()]
    [string]$NodegroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The IAM role ARN that EC2 nodes use to make AWS API calls (e.g. 'arn:aws:iam::123456789012:role/eks-node-role')")]
    [ValidatePattern('^arn:aws:iam::\d{12}:role/.+$')]
    [string]$NodeRole,

    [Parameter(Mandatory = $true, HelpMessage = "Comma-separated VPC subnet IDs where nodes will be launched (e.g. 'subnet-abc12345,subnet-def67890')")]
    [ValidateNotNullOrEmpty()]
    [string]$Subnets,

    [Parameter(Mandatory = $false, HelpMessage = "The EC2 instance type for nodes (e.g. 't3.medium', 'm5.large')")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceTypes = 't3.medium',

    [Parameter(Mandatory = $false, HelpMessage = "The desired number of nodes in the node group (1-5000)")]
    [ValidateRange(1, 5000)]
    [int]$DesiredSize = 2,

    [Parameter(Mandatory = $false, HelpMessage = "The minimum number of nodes in the node group (0-5000)")]
    [ValidateRange(0, 5000)]
    [int]$MinSize = 1,

    [Parameter(Mandatory = $false, HelpMessage = "The maximum number of nodes in the node group (1-5000)")]
    [ValidateRange(1, 5000)]
    [int]$MaxSize = 4,

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region of the EKS cluster (e.g. 'us-east-1')")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating managed node group '$NodegroupName' in EKS cluster '$ClusterName'..." -ForegroundColor Green

    # Verify AWS CLI is available
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI is not installed or not in PATH. Please install it from https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    }

    # Validate scaling bounds
    if ($MinSize -gt $DesiredSize) {
        throw "MinSize ($MinSize) must be less than or equal to DesiredSize ($DesiredSize)."
    }

    if ($DesiredSize -gt $MaxSize) {
        throw "DesiredSize ($DesiredSize) must be less than or equal to MaxSize ($($MaxSize))."
    }

    Write-Host "ℹ️  Scaling config: min=$MinSize, desired=$DesiredSize, max=$MaxSize" -ForegroundColor Yellow
    Write-Host "ℹ️  Instance type: $InstanceTypes" -ForegroundColor Yellow

    # Build the create-nodegroup command arguments
    $createArgs = @(
        'eks', 'create-nodegroup',
        '--cluster-name', $ClusterName,
        '--nodegroup-name', $NodegroupName,
        '--node-role', $NodeRole,
        '--subnets', ($Subnets -split ',' | ForEach-Object { $_.Trim() }),
        '--instance-types', $InstanceTypes,
        '--scaling-config', "minSize=$MinSize,maxSize=$MaxSize,desiredSize=$DesiredSize",
        '--output', 'json'
    )

    if ($Region) {
        $createArgs += '--region'
        $createArgs += $Region
        Write-Host "ℹ️  Using region: $Region" -ForegroundColor Yellow
    }

    # Create the node group
    Write-Host "🔧 Running aws eks create-nodegroup for '$NodegroupName'..." -ForegroundColor Cyan
    $nodegroupJson = aws @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI eks create-nodegroup command failed with exit code $LASTEXITCODE"
    }

    $nodegroupData = $nodegroupJson | ConvertFrom-Json
    $nodegroup = $nodegroupData.nodegroup

    Write-Host "`n✅ Node group '$NodegroupName' creation initiated successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Node Group Name: $($nodegroup.nodegroupName)" -ForegroundColor White
    Write-Host "   Status:          $($nodegroup.status)" -ForegroundColor White
    Write-Host "   ARN:             $($nodegroup.nodegroupArn)" -ForegroundColor White
    Write-Host "   Cluster:         $($nodegroup.clusterName)" -ForegroundColor White
    Write-Host "   Instance Types:  $($nodegroup.instanceTypes -join ', ')" -ForegroundColor White
    Write-Host "   Desired Size:    $($nodegroup.scalingConfig.desiredSize)" -ForegroundColor White
    Write-Host "   Min Size:        $($nodegroup.scalingConfig.minSize)" -ForegroundColor White
    Write-Host "   Max Size:        $($nodegroup.scalingConfig.maxSize)" -ForegroundColor White

    Write-Host "`n⚠️  Node group creation is asynchronous. The node group is currently in '$($nodegroup.status)' status." -ForegroundColor Yellow
    Write-Host "💡 Next Steps:" -ForegroundColor Yellow

    if ($Region) {
        Write-Host "   Wait for ACTIVE: aws eks wait nodegroup-active --cluster-name $ClusterName --nodegroup-name $NodegroupName --region $Region" -ForegroundColor White
        Write-Host "   Check status:    aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodegroupName --region $Region --query 'nodegroup.status'" -ForegroundColor White
    }
    else {
        Write-Host "   Wait for ACTIVE: aws eks wait nodegroup-active --cluster-name $ClusterName --nodegroup-name $NodegroupName" -ForegroundColor White
        Write-Host "   Check status:    aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $NodegroupName --query 'nodegroup.status'" -ForegroundColor White
    }

    Write-Host "   Verify nodes:    kubectl get nodes" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
