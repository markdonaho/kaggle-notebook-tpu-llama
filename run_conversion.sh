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

# --- Step 1c: Copy inspection script to VM ---
echo "📤 Copying inspect_module_path.py to the VM..."
gcloud compute scp inspect_module_path.py $VM_NAME:~/ --zone=$VM_ZONE --project=$PROJECT_ID --quiet

# --- Step 2: SSH and Run the Entire Process Non-Interactively ---
echo "💻 Connecting to VM to run the full, automated process..."
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="
# Exit script if any command fails
set -e

echo '--- 1. Setting up environment (Python 3.10 via conda) ---'
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
   echo 'Waiting for unattended-upgrades to finish...'
   sleep 5
done

# Clean up any stale backports entries that cause 404s
sudo rm -f /etc/apt/sources.list.d/backports.list || true
sudo sed -i '/backports/d' /etc/apt/sources.list || true

sudo apt-get update -y
sudo apt-get install -y git curl

# Initialize or install conda
if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
  source /opt/conda/etc/profile.d/conda.sh
elif [ -f "\$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
  source "\$HOME/miniconda3/etc/profile.d/conda.sh"
else
  curl -sLo miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
  bash miniconda.sh -b -p "\$HOME/miniconda3"
  source "\$HOME/miniconda3/etc/profile.d/conda.sh"
fi

# Accept conda Terms of Service for non-interactive use
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# Create and activate Python 3.11 env (needed for flax>=0.11.0)
conda create -y -n maxtext311 python=3.11
conda activate maxtext311
python -m pip install --upgrade pip --quiet
pip install torch --quiet
pip install 'huggingface_hub[cli]' --quiet

echo '--- 2. Logging into Hugging Face Hub ---'
huggingface-cli login --token '$HF_TOKEN'

echo '--- 3. Cloning MaxText repository and installing dependencies ---'
rm -rf maxtext
git clone https://github.com/google/maxtext.git
cd maxtext
pip install -r requirements.txt
echo '--- Installing MaxText in editable mode ---'
pip install -e .

echo '--- Applying patch for Llama 3.1 weight names ---'
# Use single quotes and escaped inner quotes for robustness
sed -i 's/"norm.weight"/"model.norm.weight"/g' src/MaxText/llama_or_mistral_ckpt.py

echo '--- Verifying patch ---'
grep "model.norm.weight" src/MaxText/llama_or_mistral_ckpt.py

echo '--- Clearing Python cache ---'
find . -type d -name "__pycache__" -exec rm -r {} +

echo '--- DEBUG: Finding the exact module path ---'
python ~/inspect_module_path.py

echo '--- Running MaxText conversion script ---'
python -m MaxText.llama_or_mistral_ckpt \
  --base-model-path meta-llama/Meta-Llama-3.1-8B-Instruct \
  --model-size llama3.1-8b \
  --huggingface-checkpoint True \
  --maxtext-model-path ./llama-3.1-8b-maxtext-checkpoint

echo '--- Uploading to GCS bucket ---'
# Note: You'll need to set up GCS bucket and authentication
# gsutil cp -r ./llama-3.1-8b-maxtext-checkpoint gs://your-bucket-name/

echo '🎉✅ SUCCESS! The MaxText conversion is complete on the VM.'
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
