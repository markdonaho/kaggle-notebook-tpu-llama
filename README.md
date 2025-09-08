# Project Plan: Fine-Tuning a Llama 3.1 Summarizer for Knowledge Management
Version: 8.1
Date: 2025-09-08
Status: Phase 2 - Checkpoint Ready for Kaggle Upload

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

### Session 2.3: Model Conversion with MaxText (GCP Method) [✅]

Objective: To bypass Kaggle's limitations by using a Google Cloud VM to run MaxText's conversion script, converting the PyTorch weights into a MaxText-compatible JAX checkpoint.

Status: Complete. We executed a hardened, automated conversion flow on a GCP VM. The process now downloads a local Hugging Face snapshot of `meta-llama/Meta-Llama-3.1-8B-Instruct`, injects targeted debug code, and writes checkpoints to an absolute path to satisfy Orbax. Conversion succeeded and the base weights were saved on the VM.

Details:
- Used a dedicated `remote_executor.sh` invoked from `run_conversion.sh` to avoid nested shell quoting issues
- Downloaded local HF snapshot via `huggingface-cli download` and pointed MaxText to the local path
- Verified `chkpt_vars` populated; corrected access and confirmed presence of `model.norm.weight`
- Fixed Orbax error by writing to an absolute path: `$HOME/maxtext/llama-3.1-8b-maxtext-checkpoint`

Actionable Steps:

[x] Run the Final Conversion Script: Executed successfully on the GCP VM
[x] Create GCP VM and install MaxText dependencies
[x] Fix Weight Names in Conversion Script: Use `model.norm.weight`
[x] Run MaxText Conversion: Completed with local HF snapshot
[x] Verify Output: Checkpoint saved at `/home/markdonaho/maxtext/llama-3.1-8b-maxtext-checkpoint`
[x] Download to Local: Checkpoint successfully downloaded from VM to local `./checkpoint_download` directory via `download_from_vm.sh` script.
[ ] Upload to Kaggle Dataset: The local checkpoint directory should be uploaded as a new private Kaggle dataset.
[x] Teardown VM: Delete the GCE VM to avoid costs.

Next Steps:
- Upload the local checkpoint directory (`./checkpoint_download/llama-3.1-8b-maxtext-checkpoint`) as a new private dataset on Kaggle.
- Update the Kaggle notebook to use the new Kaggle dataset as the source for the fine-tuning checkpoint.
- Proceed to Session 2.4 (configure Kaggle for training).

### Session 2.4: Configure Kaggle for MaxText Training [ ]

Objective: To set up the Kaggle TPU notebook to run a MaxText fine-tuning job using the checkpoint from the newly created Kaggle dataset.

Actionable Steps:

[ ] Create Kaggle Dataset: Upload the local checkpoint files to a new private dataset.
[ ] Configure Kaggle Notebook Access: In the notebook, add the new dataset as an input source. The path will typically be `/kaggle/input/<your-dataset-name>/`.
[ ] Clone MaxText in Kaggle: In your notebook, clone the MaxText repository and install its requirements.

!git clone [https://github.com/google/maxtext.git](https://github.com/google/maxtext.git)
!pip install -r maxtext/requirements.txt

[ ] Prepare Training Config: Create a MaxText configuration file (.yml) for your fine-tuning job. This file will define the model paths, dataset, and training parameters. You will point the `load_parameters_path` to your new Kaggle dataset path (e.g., `/kaggle/input/<your-dataset-name>/llama-3.1-8b-maxtext-checkpoint`).

[ ] Initial Verification: Run a small MaxText command (e.g., an evaluation step with `steps=1`) to ensure it can access the Kaggle dataset checkpoint and initialize the model on the TPU correctly before starting the full training job.

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


