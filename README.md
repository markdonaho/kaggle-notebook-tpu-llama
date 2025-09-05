# Project Plan: Fine-Tuning a Llama 3.1 Summarizer for Knowledge Management
Version: 7.0 Date: 2025-09-04 Status: Phase 2 Revised
## Legend
- ✅: Complete
- 🔄: In Progress / Revised
- ⏹️: Blocked
- [ ]: Not Started
## 1.0 Introduction & Vision
This document outlines the complete, end-to-end plan to fine-tune a `meta-llama/Meta-Llama-3.1-8B-Instruct` model to serve as a specialized "Summarizer AI." The vision is to create a model that can automatically process raw meeting, podcast, and video transcripts and generate structured, interconnected, and human-readable knowledge summaries in Obsidian-flavored Markdown.

This Summarizer AI is the foundational component of a larger automated knowledge management pipeline. The subsequent phases of that pipeline, including the development of a RAG-based "Collaborator AI" and the implementation of a vector database, are considered separate projects that will build upon the successful completion of this plan.

## Phase 1: Training Data Development ✅
**Goal:** To produce a high-quality dataset of 500-2000 examples that teach the model to generate structured summary chunks associated with specific document sections.
- **Session 1.1:** Raw Data Acquisition & "Golden Record" Creation ✅
- **Session 1.2:** Dataset Chunking and Formatting (Tag and Assemble Method) ✅

## Phase 2: Environment & Model Preparation 🔄
**Goal:** To prepare a JAX-native, Flax-converted version of the Llama 3.1 model and establish a stable, modern fine-tuning environment on Kaggle TPUs.
- **Session 2.1:** Kaggle Environment Setup ✅
  - [x] Create a new Notebook on Kaggle and select the "TPU v3-8" accelerator. ✅
- **Session 2.2:** JAX and Library Installation ✅
  - **Objective:** To establish a stable and up-to-date library configuration in the main Kaggle training notebook.
  - **Actionable Steps:**
    - In the first cell, run the installation command with the latest verified libraries. The dependency conflicts from the initial attempts are no longer a concern as the model conversion will happen offline.
      ```python
      # STEP 1: COMPREHENSIVE ENVIRONMENT SETUP
      !pip install "jax[tpu]" -f https://storage.googleapis.com/jax-releases/libtpu_releases.html
      !pip install git+https://github.com/huggingface/transformers.git flax optax datasets sentencepiece orbax-checkpointing pyyaml
      ```
    - Verify the connection to all 8 TPU cores.
- **Session 2.3:** Model Conversion & Kaggle Dataset Creation (GCP Method) [ ]
  - **Objective:** To bypass Kaggle's RAM and disk limitations by using a powerful Google Cloud VM for a one-time model conversion. The final Flax model will be saved as a private Kaggle Dataset for fast, reliable access.
  - **Path A (Primary): Convert and Upload to Kaggle**
    - [ ] Create GCP VM: Spin up a temporary, powerful Google Compute Engine VM (e.g., n2-standard-8 with 32GB RAM and 100GB disk) from a Deep Learning image.
    - [ ] Run Conversion Script on VM: SSH into the VM and run a clean Python script using the latest libraries to download the PyTorch model, convert it to Flax, and save it.
      ```python
      # convert_model.py (to be run on GCP VM)
      import jax.numpy as jnp
      from transformers import FlaxAutoModelForCausalLM, AutoTokenizer

      model_id = "meta-llama/Meta-Llama-3.1-8B-Instruct"
      save_path = f"./{model_id.split('/')[-1]}-Flax"

      print(f"Starting conversion for {model_id}...")
      flax_model = FlaxAutoModelForCausalLM.from_pretrained(
          model_id, from_pt=True, dtype=jnp.bfloat16
      )
      tokenizer = AutoTokenizer.from_pretrained(model_id)

      print(f"Saving converted Flax model to {save_path}...")
      flax_model.save_pretrained(save_path)
      tokenizer.save_pretrained(save_path)
      print("✅ Conversion complete!")
      ```
    - [ ] Download Locally: Use `gcloud compute scp` to download the final `Meta-Llama-3.1-8B-Instruct-Flax` directory from the VM to your local machine.
    - [ ] Create Kaggle Dataset: Use the Kaggle UI or API to upload the directory and create a new private dataset.
    - [ ] Teardown VM: Shut down or delete the GCP VM to avoid incurring further costs.
  - **Path B (Backup): Convert and Store in GCS**
    - [ ] Upload to GCS: If the Kaggle Dataset path fails, run the conversion on the GCP VM as described above, but instead of downloading, upload the final directory directly to a Google Cloud Storage (GCS) bucket.
      ```bash
      gcloud storage cp -r ./Meta-Llama-3.1-8B-Instruct-Flax gs://your-gcs-bucket-name/
      ```
    - [ ] Configure Kaggle Access: Create a GCP Service Account with "Storage Object Viewer" permissions, generate a JSON key, and add it to Kaggle secrets.
- **Session 2.4:** Model Loading & Verification [ ]
  - **Objective:** To successfully load the pre-converted Flax model from the Kaggle Dataset into the main training notebook.
  - **Actionable Steps:**
    - [ ] Attach Dataset: In the main TPU notebook, use the "Add Data" panel to attach the private Kaggle dataset created in Session 2.3.
    - [ ] Load from Local Path: Modify the loading script to point to the immutable `/kaggle/input/...path`. The `from_pt=True` flag is no longer needed.
      ```python
      # LOAD TOKENIZER AND MODEL FROM KAGGLE DATASET
      import jax
      from transformers import AutoTokenizer, FlaxAutoModelForCausalLM

      local_model_path = "/kaggle/input/meta-llama-3-1-8b-instruct-flax/Meta-Llama-3.1-8B-Instruct-Flax"

      print(f"Loading tokenizer and Flax model from: {local_model_path}...")
      tokenizer = AutoTokenizer.from_pretrained(local_model_path)
      model = FlaxAutoModelForCausalLM.from_pretrained(
          local_model_path,
          dtype=jax.numpy.bfloat16,
      )
      print("✅ Tokenizer and Flax model loaded successfully.")
      ```
    - [ ] Final Verification: Print the model config to confirm successful loading.

## Phase 3: Fine-Tuning the Summarizer Model [ ]
**Goal:** To efficiently fine-tune the Llama 3.1 8B-Instruct model on the prepared dataset using LoRA and a JAX-compiled, multi-core training loop.
- [ ] Load & Tokenize Data
- [ ] Configure LoRA
- [ ] Define Training State
- [ ] Implement JIT & PMAP-Compiled Training Step
- [ ] Execute Training Loop
- [ ] Implement Checkpointing
- [ ] Save Final Adapters

## Phase 4: Inference, Validation, and Assembly [ ]
**Goal:** To test the fine-tuned model and build the final "Tag and Assemble" pipeline that generates complete summary documents efficiently.
- [ ] Load Fine-Tuned Model
- [ ] Qualitative Validation
- [ ] Develop the Full Summarization Pipeline ("Tag and Assemble")

## Phase 5: Saving & Deploying the Model [ ]
**Goal:** To save the final model for persistent use and separate the training environment from the inference environment.
- [ ] Push to Hub
- [ ] Create Inference Notebook
