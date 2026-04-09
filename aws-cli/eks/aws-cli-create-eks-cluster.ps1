<#
.SYNOPSIS
    Create an Amazon EKS cluster using AWS CLI.

.DESCRIPTION
    This script creates an Amazon Elastic Kubernetes Service (EKS) cluster using
    the AWS CLI. EKS cluster creation is asynchronous — the cluster is returned
    in CREATING status and transitions to ACTIVE once provisioning completes
    (typically 10-15 minutes).
    The script uses the following AWS CLI command:
    aws eks create-cluster --name $ClusterName --role-arn $RoleArn

.PARAMETER ClusterName
    Defines the name of the EKS cluster to create.

.PARAMETER RoleArn
    Defines the IAM role ARN that the Kubernetes control plane uses to manage
    AWS resources on your behalf (e.g. 'arn:aws:iam::123456789012:role/eks-cluster-role').

.PARAMETER SubnetIds
    Defines the comma-separated list of VPC subnet IDs for the cluster's VPC configuration
    (e.g. 'subnet-abc12345,subnet-def67890').

.PARAMETER SecurityGroupIds
    Defines the comma-separated list of security group IDs for the cluster's VPC configuration.
    If omitted, the default security group for the VPC is used.

.PARAMETER KubernetesVersion
    Defines the Kubernetes version to use for the cluster (e.g. '1.29'). Default: '1.29'.

.PARAMETER Region
    Defines the AWS region where the EKS cluster will be created (e.g. 'us-east-1').
    If omitted, the default region from the AWS CLI configuration is used.

.EXAMPLE
    .\aws-cli-create-eks-cluster.ps1 -ClusterName "eks-prod-01" -RoleArn "arn:aws:iam::123456789012:role/eks-cluster-role" -SubnetIds "subnet-abc12345,subnet-def67890"

.EXAMPLE
    .\aws-cli-create-eks-cluster.ps1 -ClusterName "eks-prod-01" -RoleArn "arn:aws:iam::123456789012:role/eks-cluster-role" -SubnetIds "subnet-abc12345,subnet-def67890" -SecurityGroupIds "sg-0123456789abcdef0" -KubernetesVersion "1.29" -Region "us-east-1"

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
    https://docs.aws.amazon.com/cli/latest/reference/eks/create-cluster.html

.COMPONENT
    AWS CLI Elastic Kubernetes Service
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the EKS cluster to create")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [Parameter(Mandatory = $true, HelpMessage = "The IAM role ARN that the Kubernetes control plane uses to manage AWS resources (e.g. 'arn:aws:iam::123456789012:role/eks-cluster-role')")]
    [ValidatePattern('^arn:aws:iam::\d{12}:role/.+$')]
    [string]$RoleArn,

    [Parameter(Mandatory = $true, HelpMessage = "Comma-separated VPC subnet IDs for the cluster (e.g. 'subnet-abc12345,subnet-def67890')")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetIds,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated security group IDs for the cluster VPC configuration")]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityGroupIds,

    [Parameter(Mandatory = $false, HelpMessage = "The Kubernetes version to use (e.g. '1.29')")]
    [ValidateNotNullOrEmpty()]
    [string]$KubernetesVersion = '1.29',

    [Parameter(Mandatory = $false, HelpMessage = "The AWS region where the EKS cluster will be created (e.g. 'us-east-1')")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating EKS cluster '$ClusterName'..." -ForegroundColor Green

    # Verify AWS CLI is available
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        throw "AWS CLI is not installed or not in PATH. Please install it from https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    }

    # VPC config is built inline in --resources-vpc-config below

    # Build the create-cluster command arguments
    $createArgs = @(
        'eks', 'create-cluster',
        '--name', $ClusterName,
        '--role-arn', $RoleArn,
        '--resources-vpc-config', "subnetIds=$SubnetIds$(if ($SecurityGroupIds) { ",securityGroupIds=$SecurityGroupIds" })",
        '--kubernetes-version', $KubernetesVersion,
        '--output', 'json'
    )

    if ($Region) {
        $createArgs += '--region'
        $createArgs += $Region
        Write-Host "ℹ️  Using region: $Region" -ForegroundColor Yellow
    }

    # Create the EKS cluster
    Write-Host "🔧 Running aws eks create-cluster for '$ClusterName'..." -ForegroundColor Cyan
    $clusterJson = aws @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI eks create-cluster command failed with exit code $LASTEXITCODE"
    }

    $clusterData = $clusterJson | ConvertFrom-Json
    $cluster = $clusterData.cluster

    Write-Host "`n✅ EKS cluster '$ClusterName' creation initiated successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Cluster Name:       $($cluster.name)" -ForegroundColor White
    Write-Host "   ARN:                $($cluster.arn)" -ForegroundColor White
    Write-Host "   Status:             $($cluster.status)" -ForegroundColor White
    Write-Host "   Kubernetes Version: $($cluster.version)" -ForegroundColor White
    Write-Host "   Role ARN:           $($cluster.roleArn)" -ForegroundColor White

    Write-Host "`n⚠️  Cluster creation is asynchronous. The cluster is currently in '$($cluster.status)' status." -ForegroundColor Yellow
    Write-Host "💡 Next Steps:" -ForegroundColor Yellow

    if ($Region) {
        Write-Host "   Wait for ACTIVE status: aws eks wait cluster-active --name $ClusterName --region $Region" -ForegroundColor White
        Write-Host "   Check status:           aws eks describe-cluster --name $ClusterName --region $Region --query 'cluster.status'" -ForegroundColor White
        Write-Host "   Get kubeconfig:         aws eks update-kubeconfig --name $ClusterName --region $Region" -ForegroundColor White
    }
    else {
        Write-Host "   Wait for ACTIVE status: aws eks wait cluster-active --name $ClusterName" -ForegroundColor White
        Write-Host "   Check status:           aws eks describe-cluster --name $ClusterName --query 'cluster.status'" -ForegroundColor White
        Write-Host "   Get kubeconfig:         aws eks update-kubeconfig --name $ClusterName" -ForegroundColor White
    }
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
