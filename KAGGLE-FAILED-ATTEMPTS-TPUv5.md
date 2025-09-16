# Kaggle Notebook Failed Attempts - TPU v5e Environment
**Date Created:** 2025-09-16
**Purpose:** Document all attempted approaches to resolve dependency and execution errors within the Kaggle TPU v5e notebook environment. This log begins after the strategic pivot from TPU v3-8.

### Attempt #1: Direct Pip Install
- **Date**: 2025-09-16
- **Action**: Ran `pip install -r maxtext/requirements.txt` directly.
- **Outcome**: **Failed**. The installation failed during the build process for the `sentencepiece` package.
- **Error**: `Failed to find sentencepiece pkgconfig`.
- **Root Cause**: The build script for `sentencepiece` requires the `pkg-config` system utility, which was not present in the base Kaggle TPU v5e environment.
- **Resolution**: Updated the installation script to run `apt-get update && apt-get install -y pkg-config` before executing the `pip install` command. This successfully resolved the dependency issue.

### Attempt #2: Wrong MaxText Entrypoint (multihost_runner.py)
- **Date**: 2025-09-16
- **Action**: Ran 1-step verification with auto-detected entrypoint.
  - Command: `python maxtext/multihost_runner.py /kaggle/working/verification_minimal.yml`
- **Outcome**: **Failed**. `multihost_runner.py` expects remote TPU orchestration flags.
- **Error**: `multihost_runner.py: error: the following arguments are required: --TPU_PREFIX, --COMMAND`
- **Root Cause**: Entrypoint detection prioritized `multihost_runner.py` over the local training module (`src/maxtext/train.py`).
- **Resolution**: Updated verification cell to run `maxtext.train` as a module with `PYTHONPATH` set to `maxtext/src`, falling back to direct script path if needed. This avoids `multihost_runner` and its required flags.

### Attempt #3: Fragile Checkpoint Auto-Detection
- **Date**: 2025-09-16
- **Action**: Implemented a checkpoint path auto-detection script using `rglob` to find `_CHECKPOINT_METADATA` and `manifest.ocdbt` files.
- **Outcome**: **Failed**. The script was brittle and could not reliably locate the checkpoint directory, resulting in a `FileNotFoundError` even when the dataset was correctly attached.
- **Error**: `FileNotFoundError: Could not find a MaxText checkpoint under /kaggle/input.`
- **Root Cause**: Overly complex and heuristic-based file searching (`rglob` with parent directory assumptions) is not a reliable way to locate dataset contents in the Kaggle environment.
- **Resolution**: Replaced the entire auto-detection cell with a simple, direct path validation targeting the known dataset location (`/kaggle/input/llama-3-1-8b-maxtext-checkpoint/0`). This is more robust and less error-prone.

### Attempt #4: Missing `load_parameters_path` in Config
- **Date**: 2025-09-16
- **Action**: Ran the verification script after successfully locating the checkpoint path and setting the `MAXTEXT_CHECKPOINT_DIR` environment variable.
- **Outcome**: **Failed**. The script did not load the checkpoint because the configuration YAML was missing the necessary key to specify the model path.
- **Error**: (Implicit) The script ran as if no checkpoint was provided, ignoring the found path.
- **Root Cause**: The environment variable `MAXTEXT_CHECKPOINT_DIR` was set, but the YAML generation logic did not include the `load_parameters_path` key, which is what MaxText's `train.py` actually uses to load a checkpoint.
- **Resolution**: Updated the YAML generation cell to read the `MAXTEXT_CHECKPOINT_DIR` environment variable and dynamically insert its value into the `.yml` file under the `load_parameters_path` key.