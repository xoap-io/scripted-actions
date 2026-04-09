# Cloud Functions Scripts

PowerShell scripts for managing Google Cloud Functions (2nd gen) using
gcloud CLI.

## Prerequisites

- Google Cloud SDK (https://cloud.google.com/sdk/docs/install)
- Active GCP credentials (`gcloud auth login` or a service account key)
- Cloud Functions API and Cloud Run API enabled in the target project

## Available Scripts

| Script                              | Description                                                                           |
| ----------------------------------- | ------------------------------------------------------------------------------------- |
| `gce-cli-deploy-cloud-function.ps1` | Deploy a Google Cloud Function (2nd gen) with HTTP, Pub/Sub, or Cloud Storage trigger |
