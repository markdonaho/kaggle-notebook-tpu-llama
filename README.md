# Project Plan: Fine-Tuning a Llama 3.1 Summarizer for Knowledge Management
Version: 8.8
Date: 2025-09-15
Status: Phase 2 - Major Progress (Argv fix implemented and verified working, new config parameter issue identified)

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
[x] Upload to Kaggle Dataset: The local checkpoint directory has been successfully uploaded as a new private Kaggle dataset.
[x] Teardown VM: Delete the GCE VM to avoid costs.

[x] ~~Upload the local checkpoint directory (`./checkpoint_download/llama-3.1-8b-maxtext-checkpoint`) as a new private dataset on Kaggle.~~
[x] Update the Kaggle notebook to use the new Kaggle dataset as the source for the fine-tuning checkpoint.
[x] Proceed to Session 2.4 (configure Kaggle for training).

### Session 2.4: Configure Kaggle for MaxText Training [⏹️]

Objective: To set up the Kaggle TPU notebook to run a MaxText fine-tuning job using the checkpoint from the newly created Kaggle dataset.

Actionable Steps:

[x] Create Kaggle Dataset: Upload the local checkpoint files to a new private dataset.
[x] Configure Kaggle Notebook Access: In the notebook, add the new dataset as an input source. The path will typically be `/kaggle/input/<your-dataset-name>/`.
[x] **Advanced Dependency Resolution**: Implemented a multi-stage, dynamic commit search in the notebook to find a legacy MaxText commit compatible with the Kaggle TPU's JAX v0.4.34 environment.
    - **"Nuke and Pave" Strategy**: To prevent filesystem state errors, the notebook now `rm -rf`'s the `maxtext` directory and performs a fresh `git clone` in the main execution cell.
    - **Dynamic Commit Search**: The script programmatically searches the git history for the latest commit *without* imports from `jax.experimental.pallas` and `jax.experimental.colocated_python`, successfully identifying commit `6ce556e1` as a compatible candidate.
    - **In-Process Execution**: Switched from a `subprocess` call to `runpy.run_module` to execute the training script within the main notebook kernel, resolving the "TPU already in use" error.
[x] Prepare Training Config: A minimal `minimal_maxtext_config.yaml` is now generated automatically by the notebook.

[✅] **Simplified AQT Setup**: Implemented pinned-commit approach using known-good SHA `3275a461e59b90558352f1b40209e13462f44c38` (2023-09-07). Two-stage installation: zip URL first, then git clone fallback. Added explicit import verification and integrated `tensorboardX` installation. Removed complex dynamic commit search logic.

[✅] **Streamlined MaxText Execution**: Pinned to known-good commit `6ce556e1` (2023-09-11), removed AQT checks from execution cell, simplified to positional config with `--config_path` fallback. Added provenance verification.

[✅] **JAX Compatibility Fixes**: Added KeyArray compatibility shim for JAX 0.4.34, identified sys.path requirements for MaxText imports. Updated failure documentation with latest issues (#15-17). Status: Partially unblocked, verification pending.

[ ] **AQT Installation Correction**: Fixed PyPI package name collision (Anki `aqt` vs Google AQT) by switching to `google/aqt` pinned commit `3275a461e59b90558352f1b40209e13462f44c38` (2023-09-07). Added minimal shim fallback for `aqt.jax.v2.google.maxtext_sweeps`. Updated failure documentation with issues #18-19. Add and run the following dedicated notebook cell BEFORE MaxText execution:

```python
# Install Google AQT from pinned commit; if installed wheel misses aqt/jax/v2,
# vendor it from source into site-packages, then verify and shim google module.
import os, subprocess, sys, importlib, pathlib, shutil

PINNED_SHA = '3275a461e59b90558352f1b40209e13462f44c38'
aqt_dir = "/kaggle/working/aqt-src"
subprocess.run([sys.executable, '-m', 'pip', 'uninstall', '-y', '-q', 'aqt'])
subprocess.run(['bash', '-lc', f'rm -rf {aqt_dir} && git clone https://github.com/google/aqt.git {aqt_dir}'])
subprocess.run(['bash', '-lc', f'cd {aqt_dir} && git fetch --unshallow || git fetch --all --tags --prune'])
subprocess.run(['bash', '-lc', f'cd {aqt_dir} && git checkout {PINNED_SHA}'])
subprocess.run([sys.executable, '-m', 'pip', 'install', '--no-deps', aqt_dir])
subprocess.run([sys.executable, '-m', 'pip', 'install', 'tensorboardX'])

def ok(name):
    try:
        importlib.import_module(name)
        print('OK:', name)
        return True
    except Exception as e:
        print('FAIL:', name, e)
        return False

ok('aqt')
v2 = ok('aqt.jax.v2')
if not v2 and os.path.isdir(f'{aqt_dir}/aqt/jax/v2'):
    import aqt as _aqt
    dest = pathlib.Path(_aqt.__file__).parent / 'jax' / 'v2'
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(f'{aqt_dir}/aqt/jax/v2', dest, dirs_exist_ok=True)
    print('Vendored aqt/jax/v2 into', dest)
    v2 = ok('aqt.jax.v2')
ok('aqt.jax.v2.aqt_dot_general') if v2 else None
if v2 and not ok('aqt.jax.v2.google.maxtext_sweeps'):
    import aqt as _aqt
    gdir = pathlib.Path(_aqt.__file__).parent / 'jax' / 'v2' / 'google'
    gdir.mkdir(parents=True, exist_ok=True)
    (gdir / '__init__.py').write_text('')
    (gdir / 'maxtext_sweeps.py').write_text('def get_sweep():\n    return {}\n')
    ok('aqt.jax.v2.google.maxtext_sweeps')
```

[✅] **Argv Configuration Fix**: Successfully implemented and verified fix for `FileNotFoundError: 'MaxText.train'` error. Modified Step 8 to set `sys.argv = ['train', str(CONFIG_PATH)]` before calling `runpy.run_module('MaxText.train')`. MaxText now reads config file correctly and proceeds to config validation stage.

[ ] **Config Parameter Expansion**: New blocker identified - minimal config YAML missing required parameters (`dtype`, `model_name`, `base_output_directory`, etc.). Need to expand config with all required parameters for MaxText validation.

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


