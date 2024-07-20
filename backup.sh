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
S3_BUCKET_NAME="ziti-bucket17"
TIMESTAMP=$(date +%F-%H%M%S)

# Run the ziti agent controller snapshot-db command inside the pod
log "Running snapshot-db command inside the pod..."
kubectl exec -n ziti $POD_NAME -- ziti agent controller snapshot-db

if [ $? -ne 0 ]; then
    log "Error: Failed to execute snapshot-db command."
    exit 1
fi

# Identify the new snapshot file in the /persistent directory, ignoring ctrl.db
log "Identifying the new snapshot file..."
NEW_SNAPSHOT_FILE=$(kubectl exec -n ziti $POD_NAME -- bash -c 'ls -t /persistent | grep -v "^ctrl.db$" | head -n 1')

if [ -z "$NEW_SNAPSHOT_FILE" ]; then
    log "Error: No new snapshot file found."
    exit 1
fi

log "New snapshot file identified: $NEW_SNAPSHOT_FILE"

# Copy the snapshot file from the pod to the local file system
LOCAL_SNAPSHOT_PATH="/tmp/$NEW_SNAPSHOT_FILE"
log "Copying the snapshot file from the pod to the local file system..."
kubectl cp ziti/$POD_NAME:/persistent/$NEW_SNAPSHOT_FILE $LOCAL_SNAPSHOT_PATH

if [ $? -ne 0 ]; then
    log "Error: Failed to copy snapshot file from pod to local file system."
    exit 1
fi

log "Snapshot file copied to $LOCAL_SNAPSHOT_PATH"

# Upload the .db file to S3
S3_OBJECT_NAME="snapshot-$TIMESTAMP.db"
log "Uploading the snapshot file to S3..."
aws s3 cp $LOCAL_SNAPSHOT_PATH s3://$S3_BUCKET_NAME/$S3_OBJECT_NAME

if [ $? -ne 0 ]; then
    log "Error: Failed to upload snapshot file to S3."
    exit 1
fi

log "Snapshot file uploaded to S3 bucket: $S3_BUCKET_NAME with object name: $S3_OBJECT_NAME"

# Optional: Clean up old snapshot files if needed
log "Cleaning up local snapshot file..."
rm $LOCAL_SNAPSHOT_PATH

log "Script completed successfully."
