#!/bin/bash
set -e # Exit on error

# --- Configuration (matching run_conversion.sh) ---
export PROJECT_ID="llama-flax-conversion"
export VM_NAME="llama-flax-converter-v2"
export VM_ZONE="us-central1-a"
export CHECKPOINT_DIR_NAME="llama-3.1-8b-maxtext-checkpoint"
export REMOTE_CHECKPOINT_PATH="~/maxtext/$CHECKPOINT_DIR_NAME"
export COMPRESSED_FILE_NAME="llama-3.1-8b-maxtext-checkpoint.tar.gz"
export LOCAL_DOWNLOAD_DIR="./checkpoint_download" # Using a dedicated directory

echo "🚀 Starting local download process from VM..."
echo "Project ID: $PROJECT_ID"
echo "VM Name: $VM_NAME"
echo "Checkpoint Path on VM: $REMOTE_CHECKPOINT_PATH"

# --- Step 1: Ensure local download directory exists ---
mkdir -p $LOCAL_DOWNLOAD_DIR

# --- Step 2: Compress the checkpoint directory on the VM ---
echo "⚙️ Compressing checkpoint directory on the VM... (This may take a few minutes)"
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="
  echo 'Starting compression on VM...'
  tar -czf $COMPRESSED_FILE_NAME -C ~/maxtext/ $CHECKPOINT_DIR_NAME
  echo 'Compression complete.'
"

# --- Step 3: Download the compressed file ---
echo "📥 Downloading compressed file ($COMPRESSED_FILE_NAME) from VM..."
gcloud compute scp "$VM_NAME:~/$COMPRESSED_FILE_NAME" "$LOCAL_DOWNLOAD_DIR/" --zone=$VM_ZONE --project=$PROJECT_ID --quiet

echo "✅ Download complete."

# --- Step 4: Extract the file locally ---
echo "📦 Extracting checkpoint locally..."
tar -xzf "$LOCAL_DOWNLOAD_DIR/$COMPRESSED_FILE_NAME" -C "$LOCAL_DOWNLOAD_DIR/"

echo "✅ Extraction complete."

# --- Step 5: Clean up ---
echo "🧹 Cleaning up..."
# Remove the compressed tarball from the VM to save space
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="rm ~/$COMPRESSED_FILE_NAME"
# Remove the local tarball
rm "$LOCAL_DOWNLOAD_DIR/$COMPRESSED_FILE_NAME"
echo "✅ Cleanup complete."

echo ""
echo "🎉 SUCCESS! The MaxText checkpoint is now available locally at:"
echo "$(pwd)/$LOCAL_DOWNLOAD_DIR/$CHECKPOINT_DIR_NAME"
echo ""
echo "🎯 Next steps:"
echo "  1. Navigate to the Kaggle website or use the Kaggle CLI."
echo "  2. Create a new dataset."
echo "  3. Upload the contents of the '$(pwd)/$LOCAL_DOWNLOAD_DIR/$CHECKPOINT_DIR_NAME' directory."
