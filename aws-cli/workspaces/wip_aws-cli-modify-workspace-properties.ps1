<#
.SYNOPSIS
    Short description

.DESCRIPTION
    Long description

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT


.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName 
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

# Add your code here...


aws workspaces modify-workspace-properties `
    --workspace-id ws-dk1xzr417 `
    --workspace-properties RunningMode=string,RunningModeAutoStopTimeoutInMinutes=integer,RootVolumeSizeGib=integer,UserVolumeSizeGib=integer,ComputeTypeName=string,Protocols=string,string,OperatingSystemName=string
