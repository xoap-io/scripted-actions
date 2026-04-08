<#
.SYNOPSIS
    Create a custom AWS WorkSpace bundle.

.DESCRIPTION
    This script creates a custom WorkSpace bundle (image + compute type) using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces create-workspace-bundle

.PARAMETER AwsImageId
    The ID of the WorkSpace image to use.

.PARAMETER AwsComputeTypeName
    The compute type for the bundle (e.g., VALUE, STANDARD, PERFORMANCE, POWER, GRAPHICS).

.PARAMETER AwsBundleName
    The name for the new bundle.

.EXAMPLE
    .\aws-cli-create-workspace-bundle.ps1 -AwsImageId "wsi-12345678" -AwsComputeTypeName "STANDARD" -AwsBundleName "MyBundle"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/create-workspace-bundle.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace image to use")]
    [ValidatePattern('^wsi-[a-zA-Z0-9]{8,}$')]
    [string]$AwsImageId,

    [Parameter(Mandatory = $true, HelpMessage = "The compute type for the bundle (e.g., VALUE, STANDARD, PERFORMANCE, POWER, GRAPHICS)")]
    [ValidateSet('VALUE', 'STANDARD', 'PERFORMANCE', 'POWER', 'GRAPHICS')]
    [string]$AwsComputeTypeName,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new bundle")]
    [ValidatePattern('^[a-zA-Z0-9._@\- ]{1,64}$')]
    [string]$AwsBundleName
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    aws workspaces create-workspace-bundle `
        --image-id $AwsImageId `
        --compute-type-name $AwsComputeTypeName `
        --bundle-name "$AwsBundleName"
    Write-Host "Successfully created WorkSpace bundle $AwsBundleName." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
