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