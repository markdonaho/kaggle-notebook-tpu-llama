#!/bin/bash
# This script is executed on the remote GCE VM.
# It sets up the environment, patches the conversion script, and runs it.

# Exit script if any command fails
set -e

# --- 0. Accept Arguments ---
HF_TOKEN=$1
if [ -z "$HF_TOKEN" ]; then
    echo "❌ ERROR: Hugging Face token was not provided as the first argument."
    exit 1
fi

echo '--- 1. Setting up environment (Python 3.11 via conda) ---'
# Ensure apt isn't locked by unattended-upgrades
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
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
else
  # This case should not be hit on the Deep Learning VM images
  echo "Conda not found in expected locations."
  exit 1
fi

# Create and activate Python 3.11 env
conda create -y -n maxtext311 python=3.11
conda activate maxtext311
python -m pip install --upgrade pip --quiet
pip install torch --quiet
pip install 'huggingface_hub[cli]' --quiet

echo '--- 2. Logging into Hugging Face Hub ---'
huggingface-cli login --token "$HF_TOKEN"

echo '--- 2b. Downloading HF model snapshot locally ---'
HF_LOCAL_DIR="$HOME/hf_models/llama-3.1-8b"
mkdir -p "$HF_LOCAL_DIR"
huggingface-cli download meta-llama/Meta-Llama-3.1-8B-Instruct \
  --include "*.safetensors" \
  --local-dir "$HF_LOCAL_DIR" \
  --local-dir-use-symlinks False
echo '--- Verifying safetensors files ---'
ls -1 "$HF_LOCAL_DIR"/*.safetensors | wc -l || true
ls -1 "$HF_LOCAL_DIR"/*.safetensors | head -n 3 || true

echo '--- 3. Cloning MaxText repository and installing dependencies ---'
rm -rf maxtext
git clone https://github.com/google/maxtext.git
cd maxtext
pip install -r requirements.txt
echo '--- Installing MaxText in editable mode ---'
pip install -e .

echo '--- 4. Applying patches and debug code ---'
# Patch 1: Fix weight names
sed -i 's/"norm.weight"/"model.norm.weight"/g' src/MaxText/llama_or_mistral_ckpt.py
echo "✅ Weight name patch applied."
grep "model.norm.weight" src/MaxText/llama_or_mistral_ckpt.py

# Patch 2: Inject debug code using awk for robustness
DEBUG_CODE=$(cat <<'EOF'
  # --- BEGIN DEBUG ---
  print(f"DEBUG: Type of chkpt_vars is {type(chkpt_vars)}")
  if isinstance(chkpt_vars, dict):
    print(f"DEBUG: Top-level keys in chkpt_vars: {list(chkpt_vars.keys())}")
  elif isinstance(chkpt_vars, list) and len(chkpt_vars) > 0:
    print(f"DEBUG: chkpt_vars is a list with length {len(chkpt_vars)}.")
    if isinstance(chkpt_vars[0], dict):
      print(f"DEBUG: Keys in chkpt_vars[0]: {list(chkpt_vars[0].keys())}")
  # --- END DEBUG ---
EOF
)
awk -v var="$DEBUG_CODE" '/decoder_norm_scale/{print var}1' src/MaxText/llama_or_mistral_ckpt.py > tmp.py && mv tmp.py src/MaxText/llama_or_mistral_ckpt.py
echo "✅ Debug code injected."
grep "DEBUG: Type of chkpt_vars" src/MaxText/llama_or_mistral_ckpt.py

echo '--- 5. Clearing Python cache ---'
find . -type d -name "__pycache__" -exec rm -r {} +

echo '--- 6. Running MaxText conversion script ---'
OUT_DIR="$HOME/maxtext/llama-3.1-8b-maxtext-checkpoint"
mkdir -p "$OUT_DIR"
python -m MaxText.llama_or_mistral_ckpt \
  --base-model-path "$HF_LOCAL_DIR" \
  --model-size llama3.1-8b \
  --huggingface-checkpoint True \
  --maxtext-model-path "$OUT_DIR"

echo '🎉✅ SUCCESS! The MaxText conversion is complete on the VM.'
