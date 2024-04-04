# Introduction

This repository hosts scripts for the Scripted Actions area, which is part of the [XOAP platform](https://xoap.io). They are provided as-is and are not officially supported by XOAP. Use them at your own risk. Always test them in a non-production environment before using them in production.

## Code of Conduct

This project has adopted this [Code of Conduct](CODE_OF_CONDUCT.md).

## Change log

A full list of changes in each version can be found in the  [Releases](https://github.com/xoap-io/scripted-actions/releases).

## Documentation

### Azure CLI & Bicep

Most of the available scripts are built to use a local Azure CLI configuration file. Find more information here: [Azure CLI Configuration](https://docs.microsoft.com/en-us/cli/azure/azure-cli-configuration).

### Azure PowerShell

For Azure PowerShell-related scripts we suggest to use the noninteractive authentication with a service principal: [Sign in to Azure PowerShell with a service principal](https://learn.microsoft.com/en-us/powershell/azure/authenticate-noninteractive?view=azps-11.4.0).

### AWS CLI

For AWS CLI-related scripts we suggest using the AWS CLI configuration file: [Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

## Prerequisites

Depending on which scripts you want to use, you need to have the following prerequisites installed:

### Azure CLI

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

### Azure PowerShell

- [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)

### AWS CLI

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

### Bicep

- [Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-cli)

### ARM Templates

See Azure CLI & Azure PowerShell.

## Templates

You can use the provided templates to create your scripts. The templates are located in the `templates` folder.

