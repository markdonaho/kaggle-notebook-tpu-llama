# Project Plan: Fine-Tuning a Llama 3.1 Summarizer for Knowledge Management
Version: 9.0
Date: 2025-09-16
Status: Phase 2 - Strategic Pivot to TPU v5e

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

## Phase 2: Environment & Model Preparation (TPU v5e Pivot) ✅
Goal: To establish a stable fine-tuning environment on Kaggle TPU v5e and prepare the JAX-native Llama 3.1 model using the MaxText framework. This pivot renders most previous workarounds for the TPU v3 environment obsolete.

### Session 2.1: Strategic Pivot Planning ✅
- [x] **Strategic Decision**: Complete pivot from TPU v3-8 to TPU v5e platform
- [x] **Documentation Update**: Updated README.md to Version 9.0 with simplified Phase 2 plan
- [x] **Archive Management**: Moved legacy TPU v3 files to Archive/ directory
- [x] **New Log Initialization**: Created KAGGLE-FAILED-ATTEMPTS-TPUv5.md for new platform

### Session 2.2: Kaggle Environment Setup (TPU v5e) ✅
- [x] Create a new Kaggle Notebook and select the "TPU v5e" accelerator.
- [x] Verify the JAX version and TPU device count. The expectation is a modern JAX stack that is compatible with the latest MaxText version.
  - **Evidence**: JAX 0.4.34, 8 TPU devices detected, successful JAX test operation

### Session 2.3: MaxText Installation and Configuration ✅
- [x] Clone the `main` branch of the `google/maxtext` repository.
  - **Evidence**: Repository cloned successfully, HEAD at commit a55e18af31a76179e589314878af0a5195e7d7bd
- [x] Install dependencies directly from `requirements.txt`. The modern JAX environment should prevent the dependency conflicts experienced on TPU v3.
  - **Evidence**: All requirements installed successfully, JAX 0.4.34 preserved, import verification passed
  - **Note**: Minor TF version conflicts present but non-blocking for JAX training path
- [x] Configure the notebook to access the Kaggle dataset containing the converted MaxText checkpoint.
  - **Evidence**: Dynamic checkpoint detection implemented, works with actual dataset structure (`['items', '_CHECKPOINT_METADATA']` in root directory), `MAXTEXT_CHECKPOINT_DIR` environment variable set
- [x] Create a new `config.yaml` file for the fine-tuning job. This may require updating parameters to match the latest MaxText version's requirements.
  - **Evidence**: Implemented as inline YAML generated within the Kaggle notebook for a self-contained environment; saved to `/kaggle/working` during execution. Uses only verified parameters from source code inspection.

### Session 2.4: Systematic Assumption Elimination ✅
- [x] Eliminate all assumptions in the notebook and implement evidence-based approach.
  - **Evidence**: Systematic assumption identification and elimination completed, source code verification implemented
- [x] Restore proper notebook structure with descriptive markdown blocks and section numbering.
  - **Evidence**: Proper section numbering (6-10) restored, descriptive markdown blocks added for all code sections
- [x] Implement dynamic checkpoint detection without hardcoded assumptions.
  - **Evidence**: Checkpoint detection works regardless of directory structure, comprehensive validation added
- [x] Resolve TensorFlow protobuf conflicts using documented solutions.
  - **Evidence**: `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` environment variable set
- [x] Verify MaxText configuration parameters against actual source code.
  - **Evidence**: Source code inspection completed, most assumed parameters don't exist, only `steps` and `per_device_batch_size` verified

### Session 2.5: Verification Run 🔄
- [ ] Execute a minimal `steps: 1` training run to verify that the environment, model checkpoint, and configuration are all working correctly. This confirms the successful setup on the new TPU v5e platform.
  - **Status**: Ready for execution with verified parameters, NumPy/TensorFlow compatibility issues need resolution.

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


