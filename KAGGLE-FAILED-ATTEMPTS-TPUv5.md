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

### Attempt #5: Incorrect Checkpoint Directory Structure Assumption
- **Date**: 2025-09-16
- **Action**: Attempted to run verification with checkpoint path `/kaggle/input/llama-3-1-8b-maxtext-checkpoint/0`.
- **Outcome**: **Failed**. The code assumed checkpoint files would be in a "0" subdirectory, but they were actually in the root dataset directory.
- **Error**: `FileNotFoundError: The expected checkpoint directory was not found at '/kaggle/input/llama-3-1-8b-maxtext-checkpoint/0'`
- **Root Cause**: Hardcoded assumption that MaxText checkpoints are always in step-numbered subdirectories, but this particular dataset has the checkpoint files directly in the root.
- **Resolution**: Updated checkpoint detection logic to first check if required files (`_CHECKPOINT_METADATA`, `items`) exist directly in the dataset root, with fallback to checking "0" subdirectory if not found.

### Attempt #6: NumPy 2.0.2 Compatibility Issue with TensorFlow
- **Date**: 2025-09-16
- **Action**: Attempted to run MaxText verification with `steps: 1` after resolving checkpoint detection and configuration generation.
- **Outcome**: **Failed**. TensorFlow import failed due to NumPy version incompatibility.
- **Error**: 
  ```
  A module that was compiled using NumPy 1.x cannot be run in
  NumPy 2.0.2 as it may crash. To support both 1.x and 2.x
  versions of NumPy, modules must be compiled with NumPy 2.0.
  AttributeError: _ARRAY_API not found
  ```
- **Root Cause**: TensorFlow 2.9.0 was compiled against NumPy 1.x but the environment has NumPy 2.0.2 installed. The `_ARRAY_API` symbol is missing in NumPy 2.0.2.
- **Evidence**: Return code 1, clear error message indicating NumPy version incompatibility
- **Resolution**: Need to either downgrade NumPy to <2.0 or find TensorFlow version compatible with NumPy 2.0.2

### Attempt #7: Training Invocation Without MaxText Package Context
- **Date**: 2025-09-17
- **Action**: Ran verification via direct script path:
  - Command: `python maxtext/src/MaxText/train.py /kaggle/working/verification_minimal.yml`
- **Outcome**: **Failed**.
- **Error**: 
  ```
  ModuleNotFoundError: No module named 'MaxText'
  ```
- **Root Cause**: Python could not resolve the `MaxText` package because `maxtext/src` was not on `PYTHONPATH` and the script was not invoked as a module.
- **Resolution**: Run with proper import context by either:
  - Setting `PYTHONPATH` to include `maxtext/src` and invoking the module: `python -m MaxText.train ...`, or
  - Exporting `PYTHONPATH` before running the script path.

### Attempt #8: Configuration Missing Checkpoint Load Key
- **Date**: 2025-09-17
- **Action**: Generated minimal YAML (`/kaggle/working/verification_minimal.yml`) with `steps: 1` and `per_device_batch_size: 1` after detecting checkpoint at `/kaggle/input/llama-3-1-8b-maxtext-checkpoint`.
- **Outcome**: **Incomplete configuration**. Checkpoint path not included in YAML, so training would not load preexisting parameters even if invocation succeeded.
- **Evidence**: Printed YAML includes a TODO and omits the checkpoint load key.
- **Root Cause**: Exact checkpoint-loading key in MaxText config not yet confirmed and therefore not written into YAML.
- **Resolution**: Add a deterministic discovery step to identify the correct key from source (grep and source inspection), then regenerate YAML to include the key (e.g., `load_parameters_path: /kaggle/input/llama-3-1-8b-maxtext-checkpoint`) and re-run verification.

### Attempt #9: Protobuf / TensorFlow Incompatibility
- **Date**: 2025-09-17
- **Action**: Ran the refactored notebook which correctly generated the config YAML and invoked the training script.
- **Outcome**: **Failed**.
- **Error**: `TypeError: Descriptors cannot be created directly.`
- **Root Cause**: A known version incompatibility between the `google-protobuf` library and TensorFlow. Newer versions of `protobuf` have stricter API requirements that the version of TensorFlow in the environment does not meet.
- **Resolution**: Set the `PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python` environment variable before running the training script. This forces `protobuf` to use a slower, but more compatible, pure-Python implementation.

### Attempt #10: JAX / MaxText Version Mismatch (`colocated_python`)
- **Date**: 2025-09-17
- **Action**: Ran the verification script after fixing the Protobuf issue.
- **Outcome**: **Failed**.
- **Error**: `ImportError: cannot import name 'colocated_python' from 'jax.experimental'`.
- **Root Cause**: The `main` branch of `MaxText` was too new for the stable JAX version (0.4.34) in the Kaggle environment. The code attempted to import an experimental JAX feature that did not exist in that version.
- **Resolution**: Switched from cloning the shallow `main` branch to cloning the full repository and checking out a specific, known-stable commit (`c581c81`) that is compatible with the environment's JAX version.

### Attempt #11: `PYTHONPATH` Not Propagating to Subprocess
- **Date**: 2025-09-18
- **Action**: Ran the fully refactored notebook. Step 4 set `os.environ['PYTHONPATH']` and `sys.path` before calling `subprocess.Popen` with `python -m MaxText.train`.
- **Outcome**: **Failed**.
- **Error**: `ModuleNotFoundError: No module named 'MaxText'`
- **Root Cause**: The `PYTHONPATH` set in the notebook's Python kernel (`os.environ`) did not correctly propagate to the new Python process launched by `subprocess.Popen`. The subprocess environment was not configured to find the `MaxText` module.
- **Resolution**: Modify the subprocess call to explicitly set the `PYTHONPATH` as part of the command itself, ensuring the environment is correctly configured for the module execution. This is more robust than modifying the parent process's environment.

### Attempt #12: PYTHONPATH with Module Invocation (`-m`) Fails
- **Date**: 2025-09-18
- **Action**: Modified Step 4 to prepend `PYTHONPATH=/kaggle/working/maxtext/src` to the shell command and invoked the script as a module: `... python -m MaxText.train ...`.
- **Outcome**: **Failed**.
- **Error**: `ModuleNotFoundError: No module named 'MaxText'`
- **Root Cause**: Despite setting `PYTHONPATH` correctly for the subprocess shell, Python's module (`-m`) resolution mechanism failed to find the `MaxText` package. The reason for this is unclear but likely specific to the Kaggle notebook's `subprocess` or shell environment. The `PYTHONPATH` variable appears to be ignored by the `python -m` command in this context.
- **Resolution**: Change the invocation method. Instead of using `python -m`, invoke the script directly via its full path (`.../maxtext/src/MaxText/train.py`). This changes how Python sets up its `sys.path` and may be more robust. The `PYTHONPATH` must still be set to `/kaggle/working/maxtext/src` to ensure the script's internal imports (`from MaxText import ...`) resolve correctly.

### Attempt #13: Direct Script Invocation Fails with "No such file"
- **Date**: 2025-09-18
- **Action**: Modified Step 4 to call the training script by its full, absolute path: `... python /kaggle/working/maxtext/src/MaxText/train.py ...`.
- **Outcome**: **Failed**.
- **Error**: `can't open file ... No such file or directory` (Return Code 2)
- **Root Cause**: The operating system cannot find the file at the specified path. The previous `ModuleNotFoundError` was a Python import issue; this is a more fundamental filesystem path issue. The most likely cause is case sensitivity in the path (`MaxText` vs. `maxtext`).
- **Resolution**: Add a diagnostic cell to the notebook to list the directory contents (`ls -R`) and confirm the exact, case-sensitive path to `train.py`. Then, update the execution command in Step 4 to use the verified correct path.

### Attempt #13: (Update) Assumed `src` Directory Does Not Exist
- **Date**: 2025-09-18
- **Action**: Ran a diagnostic cell to list the contents of the assumed `/kaggle/working/maxtext/src` directory.
- **Outcome**: **Failed**.
- **Error**: `ls: cannot access '/kaggle/working/maxtext/src': No such file or directory`
- **Root Cause**: The fundamental assumption about the repository's structure was incorrect. The MaxText repository at the pinned commit (`4651cb3c73de`) does not have a `src` directory. The `train.py` script and its associated packages are located elsewhere.
- **Resolution**: Modify the diagnostic cell to list the *entire* contents of `/kaggle/working/maxtext` to discover the correct directory structure. Then, update the `PYTHONPATH` and the direct script path in the execution step to match the real file locations.

### Attempt #14: Missing Configuration Parameters (`base_emb_dim`)
- **Date**: 2025-09-18
- **Action**: Executed the corrected notebook with hardcoded paths after repository structure correction.
- **Outcome**: **Partial Success** - Significant progress made.
- **Error**: `ValueError: Key base_emb_dim does not exist in config /kaggle/working/verification_minimal.yml`
- **Root Cause**: The YAML configuration was missing required parameters that MaxText expects for model initialization. The error occurred during config validation after successful module loading and checkpoint detection.
- **Evidence**: Execution progressed to "Updating following parameters in config base_emb_dim: 4096" before failing
- **Resolution**: Updated the YAML configuration with comprehensive parameters including:
  - `base_emb_dim: 4096` (resolves immediate error)
  - `dtype: "bfloat16"` (from historical attempts)
  - Complete model architecture parameters for llama3.1-8b
  - Training hyperparameters with sensible defaults
- **Status**: Configuration updated, ready for testing