#!/bin/bash
set -e # Exit on error

# Source environment variables
if [ -f .env ]; then
  export $(cat .env | sed 's/#.*//g' | xargs)
fi

# --- Configuration ---
export PROJECT_ID="llama-flax-conversion"
export VM_NAME="llama-flax-converter-v2"
export VM_ZONE="us-central1-a"

# --- Step 2: SSH and Run the Entire Process Non-Interactively ---
echo "💻 Connecting to VM to run the full, automated process..."
gcloud compute ssh $VM_NAME --zone=$VM_ZONE --project=$PROJECT_ID --quiet --command="
# Exit script if any command fails
set -e

echo '--- 1. Setting up environment ---'
# --- FIX: Wait for any automatic system updates to finish before we run apt ---
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
   echo 'Waiting for unattended-upgrades to finish...'
   sleep 5
done

sudo sed -i -e '/backports/s/^#*/#/' /etc/apt/sources.list
sudo apt-get update -y
sudo apt-get install -y python3-pip git
pip install --upgrade pip --quiet
pip install 'huggingface_hub[cli]' flax sentencepiece protobuf torch jax[cpu] --quiet

# Add the local bin directory to the PATH - THIS DID NOT WORK
# export PATH=$HOME/.local/bin:$PATH

echo '--- 2. Logging into Hugging Face Hub ---'
$HOME/.local/bin/huggingface-cli login --token '$HF_TOKEN'

echo '--- 3. Downloading PyTorch model using huggingface-cli ---'
$HOME/.local/bin/huggingface-cli download meta-llama/Meta-Llama-3.1-8B-Instruct \
    --local-dir ./Meta-Llama-3.1-8B-Instruct-PyTorch \
    --repo-type model

echo '--- 4. Cloning and checking out a stable Transformers version ---'
rm -rf transformers
git clone https://github.com/huggingface/transformers.git
cd transformers
git checkout v4.36.2

echo '--- 5. Running diagnostics before conversion ---'
echo \"Current directory: \$(pwd)\"
echo \"--- Listing contents of scripts/conversion directory ---\"
ls -l ./scripts/conversion/
echo \"--- Searching for the conversion script ---\"
find . -name 'convert_pytorch_checkpoint_to_flax.py'

echo '--- 6. Running the PyTorch-to-Flax conversion from within transformers dir ---'
python3 ./scripts/conversion/convert_pytorch_checkpoint_to_flax.py \
    --pytorch_checkpoint_path ../Meta-Llama-3.1-8B-Instruct-PyTorch \
    --flax_dump_path ../Meta-Llama-3.1-8B-Instruct-Flax

echo '🎉✅ SUCCESS! The conversion is complete on the VM.'
"

# --- Step 3: Provide Instructions for Next Steps ---
echo "
------------------------------------------------------------------
✅ The automated script has finished on the VM.

NEXT STEPS:

1. Download the converted files to Cloud Shell with this command:
gcloud compute scp --recurse \${VM_NAME}:~/Meta-Llama-3.1-8B-Instruct-Flax . --zone=\${VM_ZONE} --project=\${PROJECT_ID}

2. After you have the files, DELETE THE VM to avoid costs with this command:
gcloud compute instances delete \${VM_NAME} --zone=\${VM_ZONE} --project=\${PROJECT_ID} --quiet
------------------------------------------------------------------
"
