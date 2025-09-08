# Failed Conversion Attempts - Llama 3.1 to Flax

**Date Created:** 2025-09-05  
**Purpose:** Document all attempted approaches to avoid repeating failed methods

## Root Cause Identified
The fundamental issue is that the `transformers` library does not support conversion of sharded safetensors checkpoints to Flax format. Error: `NotImplementedError: Support for sharded checkpoints using safetensors is coming soon!`

## Failed Approaches

### 1. Direct `from_pt=True` Conversion
**Method:** Using `FlaxAutoModelForCausalLM.from_pretrained(model_id, from_pt=True, dtype=jnp.bfloat16)`
**Result:** `NotImplementedError` - library limitation
**Files Modified:** `run_conversion.sh` (multiple iterations)

### 2. GitHub Source Installation
**Method:** Installing `transformers` directly from GitHub main branch
**Command:** `pip install git+https://github.com/huggingface/transformers.git`
**Result:** Same `NotImplementedError` - the limitation exists even in the latest code
**Files Modified:** `run_conversion.sh`

### 3. Generic Conversion Script Search
**Method:** Looking for `convert_pytorch_checkpoint_to_flax.py` script
**Result:** Script does not exist in modern transformers library
**Evidence:** GitHub search shows only model-specific conversion scripts (BERT, CVT, OPT, etc.)
**Files Modified:** `run_conversion.sh` (multiple iterations)

### 4. Download-First Approach
**Method:** Download PyTorch model first, then convert locally
**Steps:**
1. Use `huggingface-cli download` to get complete model
2. Clone transformers repo to get conversion scripts
3. Run conversion script on downloaded files
**Result:** Would fail due to #3 - no generic conversion script exists

### 5. Version-Specific Script Search
**Method:** Checking out specific transformers version (v4.36.2)
**Result:** Script path `./scripts/conversion/` does not exist in that version
**Error:** `ls: cannot access './scripts/conversion/': No such file or directory`

## What We Learned

1. **Library Limitation is Real:** The `NotImplementedError` is not a bug but a known limitation
2. **No Generic Scripts:** Modern transformers library only has model-specific conversion scripts
3. **Version Doesn't Matter:** The limitation exists across different versions of the library
4. **Download vs Stream:** The issue is not about downloading vs streaming - it's about the conversion logic itself

## Current Status
**BLOCKED** - Session 2.3 cannot proceed with current approach. The project plan's assumption that `from_pt=True` would work for Llama 3.1 is incorrect.

## Next Steps Required
- Research alternative conversion methods outside of transformers library
- Look for community solutions or workarounds
- Consider using different model formats or conversion tools
- Wait for transformers library to implement safetensors support for Flax conversion

## Files That Were Modified (Don't Revert These)
- `run_conversion.sh` - Contains our latest working script (though it won't work due to library limitation)
- `README.md` - Updated to reflect blocked status
- Session archives - Document the debugging process

## Key Error Messages to Remember
```
NotImplementedError: Support for sharded checkpoints using safetensors is coming soon!
OSError: Can't load the model for 'meta-llama/Meta-Llama-3.1-8B-Instruct'
ls: cannot access './scripts/conversion/': No such file or directory
```

## 6. VM Environment Setup Failures
**Method**: Iteratively building a VM setup script (`run_conversion.sh`) for MaxText.
**Result**: Encountered and bypassed several OS-level and Python environment configuration issues.
**Failed Sub-Approaches**:
- **Debian Backports for Python 3.10**: `apt-get` failed with a 404 error, indicating the repository was unavailable.
- **Pyenv Installation**: Failed in a non-interactive `gcloud compute ssh` command with `pyenv: command not found` because `~/.bashrc` was not sourced.
- **Initial Conda Install**: Failed due to non-interactive script being blocked by Anaconda's Terms of Service prompt.
- **Conda Python 3.10 Env**: Failed dependency resolution for `flax>=0.11.0`, which required Python 3.11+.
- **Missing `torch` Dependency**: The conversion script failed with `ModuleNotFoundError: No module named 'torch'` because the library was not installed in the conda environment.
- **Incorrect Python Execution**: The script failed with `ModuleNotFoundError: No module named 'MaxText'` because it was being run as a file (`python MaxText/...`) instead of as a module (`python -m MaxText...`), preventing relative imports.
- **Incorrect `model-size` Argument**: The script failed with a `NotImplementedError` because the generic `model-size` "8b" was used instead of the specific key "llama3.1-8b" required by the script's parameter dictionary.
- **Hugging Face Model Path**: The script failed with `IndexError: list index out of range` because it was expecting a local path to `.pth` files, not a Hugging Face model identifier. This was resolved by adding the `--huggingface-checkpoint True` flag.

## 7. MaxText Conversion Script Failures (Post-Environment Setup)
**Method**: Iteratively debugging the `llama_or_mistral_ckpt.py` script and its execution within the `run_conversion.sh` automation script.
**Result**: Uncovered and resolved a series of issues related to file paths, Python module resolution, and incorrect assumptions about the model's weight names.

**Failed Sub-Approaches & Resolutions**:
- **Incorrect Patch Path**: The `sed` command to patch the conversion script initially failed with `sed: can't read llama_or_mistral_ckpt.py: No such file or directory`.
    - **Resolution**: The file was located in a subdirectory. Corrected the path to `src/MaxText/llama_or_mistral_ckpt.py`.
- **Module Not Found**: The script failed with `ModuleNotFoundError: No module named 'MaxText'`, even when running from the `maxtext` directory.
    - **Resolution**: The cloned repository was not installed as a package. Added `pip install -e .` to the script to install it in editable mode, making the `MaxText` module available to the Python interpreter.
- **Persistent `KeyError` Cycle**: The script toggled between `KeyError: 'norm.weight'` and `KeyError: 'model.norm.weight'`, indicating the `sed` patch was working but the underlying assumption was wrong.
    - **Resolution**: Added a diagnostic step to the script (`inspect_keys.py`) to print all weight names from the downloaded model. This confirmed the correct key was indeed `model.norm.weight`.
- **Python Bytecode Caching**: The `sed` patch appeared to have no effect on subsequent runs, causing the same `KeyError`. This was identified as a potential caching issue where Python was executing the old, un-patched `.pyc` file.
    - **Resolution**: Added a command `find . -type d -name "__pycache__" -exec rm -r {} +` to the script to forcefully clear all Python bytecode caches before running the conversion. This, combined with the correct `sed` command, is the final configuration.
- **Shell Syntax Error**: An attempt to run the key-inspection code as an inline Python command failed with `syntax error near unexpected token '('` due to how the shell interpreted the string.
    - **Resolution**: Switched from an inline command to copying and executing a dedicated `.py` script (`inspect_keys.py`) to avoid shell parsing issues.
