# Project Plan: Fine-Tuning a Llama 3.1 Summarizer for Knowledge Management
Version: 8.0
Date: 2025-09-05
Status: Phase 2 Revised

## Legend
✅: Complete

🔄: In Progress / Revised

⏹️: Blocked

[ ]: Not Started

## 1.0 Introduction & Vision
This document outlines the complete, end-to-end plan to fine-tune a meta-llama/Meta-Llama-3.1-8B-Instruct model to serve as a specialized "Summarizer AI." The vision is to create a model that can automatically process raw meeting, podcast, and video transcripts and generate structured, interconnected, and human-readable knowledge summaries in Obsidian-flavored Markdown.

This Summarizer AI is the foundational component of a larger automated knowledge management pipeline. The subsequent phases of that pipeline are considered separate projects that will build upon the successful completion of this plan.

## Phase 1: Training Data Development ✅
Goal: To produce a high-quality dataset of 500-2000 examples that teach the model to generate structured summary chunks associated with specific document sections.

### Session 1.1: Raw Data Acquisition & "Golden Record" Creation ✅

### Session 1.2: Dataset Chunking and Formatting (Tag and Assemble Method) ✅

## Phase 2: Environment & Model Preparation 🔄
Goal: To prepare a JAX-native version of the Llama 3.1 model using the MaxText framework and establish a stable fine-tuning environment on Kaggle TPUs.

### Session 2.1: Kaggle Environment Setup ✅

[x] Create a new Notebook on Kaggle and select the "TPU v3-8" accelerator. ✅

### Session 2.2: JAX and Library Installation ✅

Objective: To establish a stable and up-to-date library configuration in the main Kaggle training notebook.

Actionable Steps:

[x] In the first cell, run the JAX installation command. MaxText's own requirements will be installed later.

#### STEP 1: INSTALL JAX FOR TPU
!pip install "jax[tpu]" -f [https://storage.googleapis.com/jax-releases/libtpu_releases.html](https://storage.googleapis.com/jax-releases/libtpu_releases.html)

[x] Verify the connection to all 8 TPU cores. ✅

### Session 2.3: Model Conversion with MaxText (GCP Method) [🔄]

Objective: To bypass Kaggle's limitations by using a Google Cloud VM to run MaxText's conversion script, converting the PyTorch weights into a MaxText-compatible JAX checkpoint stored in Google Cloud Storage.

Status: In Progress. We have diagnosed a series of complex, interacting bugs in the conversion process, including incorrect weight names, Python module resolution failures, and Python bytecode caching issues. A final, robust version of the `run_conversion.sh` script has been prepared. The new approach patches the conversion script in-memory and pipes it directly to the Python interpreter, which should resolve all previously encountered issues. This script is ready to be run at the start of the next session.

Actionable Steps:

[ ] **Run the Final Conversion Script**: Execute the fully debugged `run_conversion.sh` script to perform the automated conversion on the GCP VM.
[x] Create GCP VM: Spin up a temporary, powerful Google Compute Engine VM (e.g., n2-standard-8 with 32GB RAM and 100GB disk).
[x] Setup MaxText on VM: SSH into the VM, clone the MaxText repository, and install its dependencies.
[x] Fix Weight Names in Conversion Script**: Modify `llama_or_mistral_ckpt.py` on the VM to use the correct weight names for Llama 3.1 (e.g., `model.norm.weight` instead of `norm.weight`).
[ ] Run MaxText Conversion: Use MaxText's built-in conversion script. You'll need to accept the Llama 3.1 terms and get a Hugging Face token first. The script handles downloading the sharded safetensors and converting them into a single JAX checkpoint.

# First, log in to Hugging Face
huggingface-cli login

# Run the conversion script, pointing output to your GCS bucket
python MaxText/llama_or_mistral_ckpt.py \
  --base-model-path meta-llama/Meta-Llama-3.1-8B-Instruct \
  --model-size 8b \
  --maxtext-model-path gs://your-gcs-bucket-name/llama-3.1-8b-maxtext-checkpoint

[ ] Verify Output: Confirm that the converted JAX checkpoint files have been saved to your Google Cloud Storage (GCS) bucket.

[ ] Teardown VM: Shut down or delete the GCP VM to avoid incurring further costs.

### Session 2.4: Configure Kaggle for MaxText Training [ ]

Objective: To set up the Kaggle TPU notebook to run a MaxText fine-tuning job using the GCS checkpoint.

Actionable Steps:

[ ] Configure GCS Access: Create a GCP Service Account with "Storage Object Viewer" permissions, generate a JSON key, and add it to Kaggle secrets.

[ ] Clone MaxText in Kaggle: In your notebook, clone the MaxText repository and install its requirements.

!git clone [https://github.com/google/maxtext.git](https://github.com/google/maxtext.git)
!pip install -r maxtext/requirements.txt

[ ] Prepare Training Config: Create a MaxText configuration file (.yml) for your fine-tuning job. This file will define the model paths, dataset, and training parameters. You will point the load_parameters_path to your GCS checkpoint.

[ ] Initial Verification: Run a small MaxText command (e.g., an evaluation step with steps=1) to ensure it can access the GCS checkpoint and initialize the model on the TPU correctly before starting the full training job.

## Phase 3: Fine-Tuning the Summarizer Model [ ]
Goal: To efficiently fine-tune the Llama 3.1 model on the prepared dataset using the MaxText framework on Kaggle TPUs.

[ ] Upload and Prepare Dataset for MaxText

[ ] Create Custom Fine-Tuning Configuration (.yml)

[ ] Execute MaxText Training Script

[ ] Monitor Training and Log Metrics

[ ] Save Final Checkpoint to GCS

## Phase 4: Inference, Validation, and Assembly [ ]
Goal: To test the fine-tuned model and build the final "Tag and Assemble" pipeline that generates complete summary documents.

[ ] Load Fine-Tuned Checkpoint in an Inference Environment

[ ] Perform Qualitative Validation on Test Data

[ ] Develop the Full Summarization Pipeline ("Tag and Assemble")

## Phase 5: Saving & Deploying the Model [ ]
Goal: To save the final model artifacts for persistent use and create a clean inference environment.

[ ] Document Final Model and Save Artifacts

[ ] Create a Standalone Inference Notebook


