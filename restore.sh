#!/bin/bash

# Function to print logs
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Define the correct label key and value
LABEL_KEY="app.kubernetes.io/name"
LABEL_VALUE="ziti-controller"

# Get the name of the ziti-controller pod
log "Fetching the name of the ziti-controller pod..."
POD_NAME=$(kubectl get pods -n ziti -l $LABEL_KEY=$LABEL_VALUE -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
    log "Error: No ziti-controller pod found with label $LABEL_KEY=$LABEL_VALUE."
    exit 1
fi

log "Found ziti-controller pod: $POD_NAME"

# Set variables
S3_BUCKET_NAME="ziti-backup17"
LOCAL_RESTORE_PATH="/tmp/latest_snapshot.db"

# Fetch the latest .db file from S3 bucket
log "Fetching the latest snapshot from S3..."
LATEST_SNAPSHOT=$(aws s3 ls s3://$S3_BUCKET_NAME/ --recursive | sort | tail -n 1 | awk '{print $4}')

if [ -z "$LATEST_SNAPSHOT" ]; then
    log "Error: No snapshot found in the S3 bucket."
    exit 1
fi

log "Latest snapshot identified: $LATEST_SNAPSHOT"

# Download the latest snapshot from S3 to the local file system
log "Downloading the latest snapshot to $LOCAL_RESTORE_PATH..."
aws s3 cp s3://$S3_BUCKET_NAME/$LATEST_SNAPSHOT $LOCAL_RESTORE_PATH

if [ $? -ne 0 ]; then
    log "Error: Failed to download snapshot from S3."
    exit 1
fi

log "Snapshot downloaded to $LOCAL_RESTORE_PATH"

# Copy the snapshot file from the local file system to the pod's /persistent directory
log "Copying the snapshot file to the pod..."
kubectl cp $LOCAL_RESTORE_PATH ziti/$POD_NAME:/persistent/latest_snapshot.db

if [ $? -ne 0 ]; then
    log "Error: Failed to copy snapshot file to the pod."
    exit 1
fi

log "Snapshot file copied to the pod's /persistent directory"

# Clean up local snapshot file if needed
log "Cleaning up local snapshot file..."
rm $LOCAL_RESTORE_PATH

log "Script completed successfully."
