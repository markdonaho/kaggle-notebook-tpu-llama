# Kaggle Notebook Failed Attempts - MaxText Environment
**Date Created:** 2025-09-10  
**Purpose:** Document all attempted approaches to resolve dependency and execution errors within the Kaggle TPU notebook environment. This log begins after the successful conversion and upload of the Llama 3.1 MaxText checkpoint.

## Root Cause Summary
The primary challenge is a multi-faceted dependency conflict between the Kaggle TPU environment's constraints, the evolving MaxText repository, and Python's behavior. Key conflicting factors include:
- **Fixed JAX Version:** Kaggle TPUs require specific JAX/JAXLIB versions (e.g., `0.4.23`, later updated to `0.4.34`) to function, which often lag behind the latest releases.
- **Evolving MaxText Dependencies:** The `main` branch of MaxText is continuously updated, requiring newer versions of libraries like `flax`, `optax`, `orbax-checkpoint`, and JAX itself.
- **Introduction of New Features:** Newer MaxText commits introduced dependencies on experimental JAX features like `pallas.ops.attention`, which are not present in the TPU-compatible JAX versions.
- **Python Bytecode Caching:** The Kaggle environment sometimes executes stale, cached `.pyc` files, making it appear as though changes (like checking out an older commit) have no effect.

---

## Failed Approaches & Resolutions Log

### 1. Initial NumPy 2.x Incompatibility
- **Method:** Cloned the `main` branch of MaxText and installed dependencies via `requirements.txt`.
- **Error:** `A module that was compiled using NumPy 1.x cannot be run in NumPy 2.0.2`.
- **Analysis:** The pre-compiled JAX TPU wheels are built against NumPy 1.x and are incompatible with the default NumPy 2.x in the Kaggle environment.
- **Resolution:** Force-reinstalled a compatible NumPy version: `!pip install numpy==1.26.4 --quiet`.

### 2. JAX Version Mismatch with MaxText Dependencies
- **Method:** After pinning NumPy, reran the dependency installation.
- **Error:** `pip` dependency resolver errors. Libraries like `orbax-checkpoint`, `optax`, and `flax` required `jax>=0.4.27`, but the installed version was `0.4.23`.
- **Analysis:** The `HEAD` of MaxText requires newer dependencies than are compatible with the base JAX version for TPUs.
- **Resolution Attempt:** Pinned the MaxText repository to a specific older commit (`c58317f`) assumed to be compatible.

### 3. Invalid Git Commit Reference
- **Method:** Attempted to run `git checkout c58317f` in the notebook.
- **Error:** `fatal: reference is not a tree`.
- **Analysis:** The specific commit hash was either incorrect or not present in the default shallow clone performed by `git clone`.
- **Resolution Attempt:** Switched to a more robust date-based checkout to find a commit from a known-good period: `git rev-list -n 1 --before="2024-05-31" HEAD`.

### 4. Flax and JAX API Mismatch
- **Method:** Successfully checked out an older commit (`f12ba54a`) and installed its dependencies.
- **Error:** `AttributeError: module 'jax.tree_util' has no attribute 'register_dataclass'`.
- **Analysis:** Even on the older commit, the installed version of `flax` required a newer JAX API than was available in JAX `0.4.23`.
- **Resolution Attempt:** Upgraded the JAX stack to `jax==0.4.34` and `jaxlib==0.4.34` to satisfy the `flax` requirement.

### 5. Persistent `pallas.ops.attention` Import Error
- **Method:** With the JAX stack upgraded to `0.4.34`, attempted to run the minimal verification script.
- **Error:** `ImportError: cannot import name 'attention' from 'jax.experimental.pallas.ops'`.
- **Analysis:** This became the primary blocker. The checked-out version of MaxText still contained code that imported a Pallas feature not available in the TPU-compatible `jax==0.4.34`. The issue persisted even when attempting to check out older commits, suggesting the problem was more complex.
- **Resolution Attempts:**
    1.  **Dynamic Pre-Pallas Commit Search:** Implemented a sophisticated helper script in the notebook to walk backwards through the git history commit-by-commit, read the contents of `MaxText/layers/attentions.py`, and stop at the first commit where the `pallas.ops.attention` import was not present.
    2.  **Bytecode Cache Clearing:** Formulated the hypothesis that stale `.pyc` files were causing the import error to persist across runs. Added a step to forcefully remove all `__pycache__` directories (`find . -type d -name "__pycache__" -exec rm -r {} +`) after cloning and checking out a commit to ensure the interpreter was using the correct source files.
    
### 6. "Known-Good" Commit Still Contains Pallas Imports
- **Method:** Implemented a single, atomic execution cell to force-checkout a supposedly Pallas-free commit (`5a6580f3`), install MaxText as an editable package, perform aggressive cleanup, verify `attentions.py`, and run via `python -m`.
- **Error 1:** `ERROR: ... does not appear to be a Python project: neither 'setup.py' nor 'pyproject.toml' found.`
- **Analysis 1:** The `pip install -e .` command failed because older MaxText commits are not structured as installable Python packages.
- **Error 2:** `ImportError: cannot import name 'attention' from 'jax.experimental.pallas.ops'`.
- **Analysis 2:** The verification step (`head -n 30 MaxText/layers/attentions.py | grep "pallas"`) definitively proved that the "known-good" commit (`5a6580f3`) *still contains Pallas imports*. This contradicts earlier file checks and reveals the core problem: we have yet to identify a truly Pallas-free commit that is compatible with our environment. The previous `git checkout` and file-read checks were producing misleading results, likely due to filesystem state instability in the notebook environment. The atomic execution cell revealed the true, persistent state of the file.

## Current Status (as of 2025-09-10)
**BLOCKED** - The `pallas.ops.attention` `ImportError` remains the unresolved issue. The latest "atomic execution" attempt proved that our previously identified "Pallas-free" commit was incorrect. The immediate next step is to find a genuinely Pallas-free commit hash.

---
## Session of 2025-09-10: Systematic Commit Search & Layered Failures

This session employed a "Nuke and Pave" strategy to ensure a clean environment for each attempt, which successfully eliminated filesystem inconsistency as a variable. However, it revealed a cascade of new dependency and environment issues.

### 7. "Nuke and Pave" with Manual Commit (`c7af09f5`)
- **Method:** Deleted the entire `maxtext` directory, re-cloned it, and checked out commit `c7af09f5` (identified as the parent of the first commit using `pallas.ops.attention`).
- **Error 1:** `FATAL Flags parsing error: Unknown command line flag 'config'`.
- **Analysis 1:** The argument parsing at this older commit is different; `--config` is not a valid flag.
- **Error 2 (Latent):** A manual check of `attentions.py` at this commit revealed an import for `jax.experimental.pallas.ops.tpu import flash_attention`.
- **Analysis 2:** The initial `git log -S` search for `pallas.ops.attention` was too specific. The entire `jax.experimental.pallas` namespace is problematic, and this commit still uses it.

### 8. Dynamic Search for Pre-Pallas/Pre-Colocated Commit
- **Method:** Upgraded the notebook script to dynamically search the entire git history for the latest commit where *neither* `jax.experimental.pallas` *nor* `jax.experimental.colocated_python` were present in the codebase. This successfully identified commit `6ce556e1...` (from 2023-09-11).
- **Error:** `RuntimeError: Unable to initialize backend 'tpu': ABORTED: The TPU is already in use by process with pid 10.`
- **Analysis:** The script was executing MaxText in a subprocess (`python -m MaxText.train`), which tried to initialize the JAX TPU backend a second time. The main notebook kernel (pid 10) had already acquired the lock on the TPU, causing the subprocess to fail.

### 9. In-Process Execution with `runpy`
- **Method:** To solve the TPU lock, the script was modified to run the MaxText training module within the same process as the notebook kernel using Python's `runpy.run_module` function.
- **Error:** `ModuleNotFoundError: No module named 'aqt.jax.v2.google'`.
- **Analysis:** The dynamically identified "good" commit (`6ce556e1...`) has an implicit dependency on the `aqt` (AQT: Accurate Quantized Training) library, which was not installed.

### 10. AQT Dependency Installation Failure
- **Method:** Added logic to the script to automatically install the `aqt` dependency. It first tried `pip install --no-deps aqt` and then attempted to install directly from the `google-research/aqt` GitHub repository.
- **Error:** `pip install aqt` did not make the module available. The `git+https` installation failed with `fatal: could not read Username for 'https://github.com': No such device or address`.
- **Analysis:** The Kaggle notebook environment blocks or mishandles `pip` installations that rely on cloning a git repository. The standard `aqt` package on PyPI may not contain the specific `aqt.jax.v2.google` submodule required by this old version of MaxText.

## Current Status (as of 2025-09-10 EOD)
**BLOCKED** - We have successfully identified a MaxText commit (`6ce556e1`) that is free of the problematic JAX experimental APIs (`pallas` and `colocated_python`). However, this commit requires the `aqt` library, and we are blocked by the Kaggle environment's inability to install it correctly via `pip install git+...`. The next session must focus on finding a way to get the `aqt` library and its specific submodules installed in the notebook.
