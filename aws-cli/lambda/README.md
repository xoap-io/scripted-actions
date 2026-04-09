# Lambda Scripts

PowerShell scripts for managing AWS Lambda functions using AWS CLI.

## Prerequisites

- AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- Active AWS credentials configured (`aws configure` or environment variables)

## Available Scripts

| Script                               | Description                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------- |
| `aws-cli-create-lambda-function.ps1` | Create an AWS Lambda function from a local ZIP file or an S3 deployment package |
| `aws-cli-invoke-lambda-function.ps1` | Invoke an AWS Lambda function synchronously and print the response payload      |
