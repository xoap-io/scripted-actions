# SQL Database Scripts

PowerShell scripts for managing Azure SQL logical servers and databases using
Azure CLI.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script                           | Description                                                                                                   |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `az-cli-create-sql-server.ps1`   | Create an Azure SQL logical server with configurable TLS version and public network access                    |
| `az-cli-create-sql-database.ps1` | Create an Azure SQL Database on an existing logical server with configurable SKU, size, and backup redundancy |
