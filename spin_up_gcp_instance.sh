#!/bin/bash

### Variables
VM_NAME="cs-lab2-test-vm"
ZONE="europe-west1-b"

echo "Creating VM instance..."

### Create instance
gcloud compute instances create "$VM_NAME" \
  --zone "europe-west1-b" \
  --machine-type e2-micro \
  --image-family ubuntu-2404-lts-amd64 \
  --image-project ubuntu-os-cloud \
  --tags cloud-systems

echo "VM $VM_NAME created."

echo "Resizing disk to 100GB..."

gcloud compute disks resize "$VM_NAME"  \
  --zone "$ZONE" \
  --size 100GB

echo "Disk resized to 100GB."

echo "Suspending VM $VM_NAME..."

gcloud compute instances suspend "$VM_NAME" \
  --zone "$ZONE"

echo "VM $VM_NAME suspended."
