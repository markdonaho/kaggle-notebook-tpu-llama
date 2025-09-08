#!/bin/bash
set -e # Exit on error

# --- Instructions for Setup ---
# 1. Make sure you have the gcloud CLI installed and authenticated.
# 2. Create a file named .env in the same directory as this script.
# 3. Add your Hugging Face User Access Token to the .env file like this:
#    HF_TOKEN="hf_your_token_here"
# 4. Run this script from your terminal: ./run_conversion.sh

# --- Source environment variables for HF_TOKEN ---
if [ -f .env ]; then
  # Use sed to handle potential Windows carriage returns and ignore comments
  export $(cat .env | sed 's/\r$//' | sed 's/#.*//g' | xargs)
fi

if [ -z "$HF_TOKEN" ]; then
    echo "❌ ERROR: HF_TOKEN is not set."
    echo "Please create a .env file and add your Hugging Face token to it."
    exit 1
fi

# --- Configuration ---
export PROJECT_ID="llama-flax-conversion"
export VM_NAME="llama-flax-converter-v2"
export VM_ZONE="us-central1-a"

# --- Step 1: Create an "Overkill" GCE VM (idempotent) ---
# Machine: n2-highmem-16 (16 vCPU, 128GB RAM)
# Disk: 200GB Persistent SSD for fast I/O
if gcloud compute instances describe $VM_NAME --project=$PROJECT_ID --zone=$VM_ZONE >/dev/null 2>&1; then
    echo "ℹ️ VM already exists: $VM_NAME. Skipping creation."
else
    echo "🚀 Creating a powerful n2-highmem-16 VM with an SSD..."
    gcloud compute instances create $VM_NAME \
        --project=$PROJECT_ID \
        --zone=$VM_ZONE \
        --machine-type="n2-highmem-16" \
        --image="c2-deeplearning-pytorch-2-4-cu124-v20250325-debian-11" \
        --image-project="ml-images" \
        --boot-disk-type="pd-ssd" \
        --boot-disk-size="200GB" \
        --quiet
fi

# --- Step 1b: Wait for SSH readiness ---
echo "⏳ Waiting for SSH to become ready on $VM_NAME ..."
for attempt in {1..30}; do
    if gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="echo ready" >/dev/null 2>&1; then
        echo "✅ SSH is ready."
        break
    else
        echo "Retry $attempt/30 ..."
        sleep 10
    fi
done

# --- Step 1c: Copy helper scripts to VM ---
echo "📤 Copying execution and inspection scripts to the VM..."
gcloud compute scp inspect_module_path.py remote_executor.sh $VM_NAME:~/ --zone=$VM_ZONE --project=$PROJECT_ID --quiet

# --- Step 2: SSH and Run the Executor Script ---
echo "💻 Connecting to VM to run the full, automated process..."
# Pass the HF_TOKEN to the remote script as the first argument.
# The remote script is responsible for making itself executable.
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="
  chmod +x ./remote_executor.sh
  ./remote_executor.sh '$HF_TOKEN'
"

# --- Step 3: Provide Instructions for Next Steps ---
echo "
------------------------------------------------------------------
✅ The automated MaxText conversion script has finished on the VM.

NEXT STEPS:

1. Set up a GCS bucket and upload the converted checkpoint:
   gcloud compute ssh \${VM_NAME} --zone=\${VM_ZONE} --project=\${PROJECT_ID} --command="
     gsutil mb gs://\${PROJECT_ID}-llama-checkpoints
     gsutil cp -r ~/maxtext/llama-3.1-8b-maxtext-checkpoint gs://\${PROJECT_ID}-llama-checkpoints/
   "

2. After uploading to GCS, DELETE THE VM to avoid costs:
   gcloud compute instances delete \${VM_NAME} --zone=\${VM_ZONE} --project=\${PROJECT_ID} --quiet

3. Use the GCS checkpoint path in your Kaggle TPU notebook for fine-tuning
------------------------------------------------------------------
"
