# Google Cloud CLI - VM Management Scripts

This directory contains PowerShell scripts for managing Google Compute Engine (GCE) virtual machines using gcloud CLI.

## Prerequisites

- Google Cloud SDK installed (includes gcloud CLI)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- GCP project with Compute Engine API enabled
- Authenticated to GCP (`gcloud auth login`)
- Project set (`gcloud config set project PROJECT_ID`)
- Compute Engine permissions

## Available Scripts

### VM Lifecycle Management

Scripts for creating, managing, and terminating GCE instances:

- **gce-cli-create-vm.ps1** - Create new VM instances
- **gce-cli-start-vm.ps1** - Start stopped instances
- **gce-cli-stop-vm.ps1** - Stop running instances
- **gce-cli-restart-vm.ps1** - Restart instances
- **gce-cli-delete-vm.ps1** - Delete instances
- **gce-cli-delete-running-vms.ps1** - Bulk delete running VMs

### Instance Operations

- List instances
- Update instance metadata
- Attach/detach disks
- Manage instance groups

## Usage Examples

### Create a VM Instance

```powershell
# Create basic VM
gcloud compute instances create my-instance `
    --zone=us-central1-a `
    --machine-type=e2-medium `
    --image-family=ubuntu-2004-lts `
    --image-project=ubuntu-os-cloud

# Create with custom configuration
gcloud compute instances create my-custom-vm `
    --zone=us-central1-a `
    --machine-type=n1-standard-4 `
    --boot-disk-size=100GB `
    --boot-disk-type=pd-ssd `
    --image-family=debian-11 `
    --image-project=debian-cloud `
    --tags=http-server,https-server `
    --metadata=startup-script='#!/bin/bash
        apt-get update
        apt-get install -y nginx'
```

### Start/Stop VMs

```powershell
# Start instance
gcloud compute instances start my-instance --zone=us-central1-a

# Stop instance
gcloud compute instances stop my-instance --zone=us-central1-a

# Restart instance
gcloud compute instances reset my-instance --zone=us-central1-a
```

### Delete VMs

```powershell
# Delete single instance
gcloud compute instances delete my-instance `
    --zone=us-central1-a `
    --quiet

# Delete multiple instances
gcloud compute instances delete instance1 instance2 instance3 `
    --zone=us-central1-a `
    --quiet
```

## GCE VM Best Practices

- **Cost Optimization**:

  - Use preemptible VMs for fault-tolerant workloads (up to 80% savings)
  - Leverage committed use discounts
  - Stop VMs when not needed
  - Use appropriate machine types
  - Enable sustained use discounts automatically

- **Security**:

  - Use service accounts with minimal permissions
  - Enable OS Login for SSH access
  - Use VPC firewall rules
  - Enable Shielded VM features
  - Keep OS and packages updated

- **High Availability**:

  - Deploy across multiple zones
  - Use managed instance groups
  - Implement health checks
  - Use persistent disks for data
  - Configure automatic restart

- **Performance**:
  - Use SSD persistent disks for better performance
  - Enable live migration
  - Choose appropriate machine types
  - Use local SSDs for temporary high-performance storage
  - Monitor with Cloud Monitoring

## Machine Type Families

### General Purpose

- **E2**: Cost-optimized, shared-core instances
- **N1**: First generation, balanced CPU/memory
- **N2/N2D**: Second generation, balanced workloads

### Compute Optimized

- **C2/C2D**: High compute performance
- **H3**: High-performance computing

### Memory Optimized

- **M1/M2/M3**: High memory-to-CPU ratio
- In-memory databases, analytics

### Accelerator Optimized

- **A2**: NVIDIA A100 GPUs
- **G2**: NVIDIA L4 GPUs for AI/ML workloads

## Disk Types

- **Standard Persistent Disk**: Cost-effective, standard HDD
- **SSD Persistent Disk**: Fast, reliable SSD
- **Balanced Persistent Disk**: Cost/performance balance
- **Local SSD**: Highest performance, ephemeral
- **Extreme Persistent Disk**: Highest IOPS and throughput

## Error Handling

Scripts include:

- Project and zone validation
- Instance name validation
- Quota checks
- Resource availability verification
- Comprehensive error messages

## Related Documentation

- [GCE Documentation](https://cloud.google.com/compute/docs)
- [gcloud compute instances](https://cloud.google.com/sdk/gcloud/reference/compute/instances)
- [Machine Types](https://cloud.google.com/compute/docs/machine-types)
- [Disk Types](https://cloud.google.com/compute/docs/disks)

## Support

For issues or questions, please refer to the main repository documentation.
