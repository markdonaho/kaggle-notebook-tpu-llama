#!/bin/bash
set -e # Exit on error

# --- Configuration (matching run_conversion.sh) ---
export PROJECT_ID="llama-flax-conversion"
export VM_NAME="llama-flax-converter-v2"
export VM_ZONE="us-central1-a"
export BUCKET_NAME="${PROJECT_ID}-llama-checkpoints"
export CHECKPOINT_PATH="llama-3.1-8b-maxtext-checkpoint"

echo "🚀 Starting GCS upload process..."
echo "Project ID: $PROJECT_ID"
echo "Bucket Name: $BUCKET_NAME"
echo "Checkpoint Path: $CHECKPOINT_PATH"

# --- Step 1: Check if VM exists and is running ---
echo "🔍 Checking if VM exists and is accessible..."
if ! gcloud compute instances describe $VM_NAME --project=$PROJECT_ID --zone=$VM_ZONE >/dev/null 2>&1; then
    echo "❌ ERROR: VM $VM_NAME not found in project $PROJECT_ID"
    echo "Please ensure the conversion VM is still running or check the VM name/project."
    exit 1
fi

# Check if VM is running
VM_STATUS=$(gcloud compute instances describe $VM_NAME --project=$PROJECT_ID --zone=$VM_ZONE --format="value(status)")
if [ "$VM_STATUS" != "RUNNING" ]; then
    echo "❌ ERROR: VM $VM_NAME is not running (status: $VM_STATUS)"
    echo "Please start the VM or check its status."
    exit 1
fi

echo "✅ VM is running and accessible"

# --- Step 2: Check if checkpoint exists on VM ---
echo "🔍 Verifying checkpoint exists on VM..."
if ! gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="test -d ~/maxtext/$CHECKPOINT_PATH"; then
    echo "❌ ERROR: Checkpoint directory ~/maxtext/$CHECKPOINT_PATH not found on VM"
    echo "Please ensure the conversion completed successfully."
    exit 1
fi

echo "✅ Checkpoint directory found on VM"

# --- Step 3: Create GCS bucket if it doesn't exist ---
echo "🪣 Checking if GCS bucket exists..."
if gsutil ls -b gs://$BUCKET_NAME >/dev/null 2>&1; then
    echo "✅ Bucket $BUCKET_NAME already exists"
else
    echo "🆕 Creating GCS bucket: $BUCKET_NAME"
    gsutil mb gs://$BUCKET_NAME
    echo "✅ Bucket created successfully"
fi

# --- Step 4: Upload checkpoint from VM to GCS ---
echo "📤 Uploading checkpoint from VM to GCS..."
echo "This may take several minutes due to the large file size..."

# Use gsutil cp to avoid needing objects.list on destination during upload
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="
    echo 'Starting upload from VM (cp -r)...'
    gsutil -m cp -r ~/maxtext/$CHECKPOINT_PATH/* gs://$BUCKET_NAME/$CHECKPOINT_PATH/
    echo 'Upload completed from VM side'
"

echo "✅ Upload completed successfully!"

# --- Step 5: Verify upload ---
echo "🔍 Verifying upload..."
UPLOADED_FILES=$(gsutil ls gs://$BUCKET_NAME/$CHECKPOINT_PATH | wc -l)
echo "Files uploaded: $UPLOADED_FILES"

if [ $UPLOADED_FILES -gt 0 ]; then
    echo "✅ Upload verification successful!"
    echo ""
    echo "📋 Summary:"
    echo "  - Bucket: gs://$BUCKET_NAME"
    echo "  - Checkpoint: gs://$BUCKET_NAME/$CHECKPOINT_PATH"
    echo "  - Files uploaded: $UPLOADED_FILES"
    echo ""
    echo "🎯 Next steps:"
    echo "  1. Use this path in your Kaggle notebook: gs://$BUCKET_NAME/$CHECKPOINT_PATH"
    echo "  2. Consider deleting the VM to avoid costs:"
    echo "     gcloud compute instances delete $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet"
else
    echo "❌ ERROR: Upload verification failed - no files found in bucket"
    exit 1
fi
