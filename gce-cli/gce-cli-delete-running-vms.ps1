$deletedVMs = @()

# Get list of VM names
$instances = gcloud compute instances list --project $project --zone $zone --format="value(name)"

foreach ($vmName in $instances) {
    Write-Output "Deleting GCP VM: $vmName..."

    # Get disk names attached to VM
    $disks = gcloud compute instances describe $vmName `
        --project $project --zone $zone `
        --format="value(disks.deviceName)"

    # Delete instance
    gcloud compute instances delete $vmName --project $project --zone $zone --quiet

    # Delete attached disks
    foreach ($disk in $disks) {
        Write-Output "Deleting disk: $disk..."
        gcloud compute disks delete $disk --project $project --zone $zone --quiet
    }

    # Delete static IPs (if any reserved for the instance)
    $addresses = gcloud compute addresses list --project $project --filter="name~$vmName" --format="value(name,region)"
    foreach ($entry in $addresses) {
        $parts = $entry.Split(" ")
        $ipName = $parts[0]
        $region = $parts[1]
        Write-Output "Releasing static IP: $ipName in region $region"
        gcloud compute addresses delete $ipName --region $region --project $project --quiet
    }

    # Delete related snapshots (assumes snapshots named or tagged after VM)
    $snapshots = gcloud compute snapshots list --project $project --filter="name~$vmName" --format="value(name)"
    foreach ($snap in $snapshots) {
        Write-Output "Deleting snapshot: $snap"
        gcloud compute snapshots delete $snap --project $project --quiet
    }

    $deletedVMs += $vmName
}

Write-Output "`nDeleted GCP Instances:"
$deletedVMs | ForEach-Object { Write-Output "- $_" }
