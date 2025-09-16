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