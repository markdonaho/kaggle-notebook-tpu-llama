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

### 11. AQT Tarball 404 and Legacy Submodule Missing (2025-09-10 ~17:00Z)
- Method: Attempted to install AQT via direct tarball (to avoid git auth) and added import verification. Specifically tried `https://github.com/google-research/aqt/archive/refs/heads/main.tar.gz` and a vendored fallback target directory; then ran MaxText in-process.
- Errors:
  - `ERROR: HTTP error 404` for `https://github.com/google-research/aqt/archive/refs/heads/main.tar.gz`.
  - `ModuleNotFoundError: No module named 'aqt.jax.v2.google'` from `MaxText/layers.py` (imports `from aqt.jax.v2.google import maxtext_sweeps`).
  - Note: `aqt.jax.v2.aqt_dot_general` imported successfully, proving the installed (modern) AQT layout differs from what this MaxText commit expects.
- Analysis: The MaxText commit `6ce556e1` (2023-09-11) expects the historical AQT package layout including `aqt.jax.v2.google`. Installing HEAD/main of AQT (2025 layout) does not provide this module. We must time-synchronize AQT to a 2023 commit compatible with MaxText.
- Resolution (next): Pin and install AQT from a historical commit (e.g., `3275a461e59b90558352f1b40209e13462f44c38`, dated 2023-09-07) via direct tarball:
  - `!pip install --no-deps --quiet "https://github.com/google/aqt/archive/3275a461e59b90558352f1b40209e13462f44c38.tar.gz"`
  - Then re-run the in-process MaxText execution with `--config=...`.

## Current Status (as of 2025-09-10 ~17:00Z)
**BLOCKED (actionable)** - AQT must be installed from a time-synchronized historical commit to provide `aqt.jax.v2.google`. Next step is to update the notebook to install `google/aqt@3275a461e59b90558352f1b40209e13462f44c38` (Sep 7, 2023) and re-run. This aligns AQT with MaxText `6ce556e1`.

### 12. AQT Repository URL Fix (2025-09-10 ~12:15Z)
- **Method**: Updated notebook to use correct `google/aqt` repository instead of `google-research/aqt`
- **Fix**: Changed AQT installation URLs from `google-research/aqt/archive/refs/heads/main.tar.gz` to `google/aqt/archive/3275a461e59b90558352f1b40209e13462f44c38.tar.gz`
- **Status**: Notebook updated, ready for testing on Kaggle TPU environment

### 13. AQT Tarball 404 and Subsequent `tensorboardX` Failure (2025-09-11)
- **Method**: Executed the notebook with the corrected AQT tarball URL pointing to a historical commit.
- **Error 1**: The corrected tarball URL `https://github.com/google/aqt/archive/3275a461e59b90558352f1b40209e13462f44c38.tar.gz` still resulted in a 404 error.
- **Analysis 1**: Direct tarball downloads for specific commits are unreliable.
- **Resolution Attempt**: Implemented an AQT "shim" in the notebook. If the legacy `aqt.jax.v2.google.maxtext_sweeps` module failed to import, the code would create a dummy module structure on the filesystem to satisfy the import and allow execution to proceed for verification purposes.
- **Error 2**: After implementing the shim, a new error emerged: `ModuleNotFoundError: No module named 'tensorboardX'`.
- **Analysis 2**: The historical MaxText commit (`6ce556e1`) has another implicit dependency on `tensorboardX`, which was not being installed.

### 14. Robust AQT Git Clone and Persistent `google` Module Failure (2025-09-11)
- **Method**: To address both the tarball and `tensorboardX` issues, a dedicated dependency setup cell was created in the notebook. This cell performs the following steps:
  1.  `git clone` the `google/aqt` repository into `/kaggle/working/aqt-src`.
  2.  Programmatically search the git history for the latest commit that contains the legacy `aqt.jax.v2.google.maxtext_sweeps.py` file.
  3.  `git checkout` that specific commit.
  4.  Install AQT from the local source (`pip install .`).
  5.  Install `tensorboardX`.
- **Error**: The execution of this new cell failed. The log output shows the script could not find a commit containing the legacy module: `Warning: No commit with both legacy modules found; using current HEAD`. Consequently, the subsequent import check `import aqt.jax.v2.google.maxtext_sweeps` failed with `No module named 'aqt.jax.v2.google'`.
- **Analysis**: The logic to find the correct historical commit in the AQT repository is flawed. The `git cat-file -e` check for `aqt/jax/v2/google/maxtext_sweeps.py` is likely failing for all commits, causing the script to fall back to using the `HEAD` commit, which does not have the required module structure. The shim creation also fails because the base `aqt.jax.v2.google` path doesn't exist.

## Current Status (as of 2025-09-11)
**BLOCKED** - The attempt to create a robust, self-healing AQT installation has failed. The script is unable to identify the correct historical AQT commit, leading to a persistent `ModuleNotFoundError` for the required `aqt.jax.v2.google` submodule. The immediate next step is to fix the commit-finding logic within the AQT setup cell in the Kaggle notebook.

### 15. AQT via google-research monorepo snapshot fails (2025-09-11)
- Method: Cloned `google-research/google-research`, checked out a snapshot before 2023-09-10, and attempted `pip install /kaggle/working/google-research/aqt`.
- Error: `pip install google-research/aqt exit code: 1`; subsequent imports failed with `No module named 'aqt'`.
- Analysis: The monorepo snapshot did not install a top-level `aqt` package with the legacy layout. The fallback shim that only created `aqt/jax/v2/google/maxtext_sweeps.py` was insufficient because the `aqt` package itself was not importable.

### 16. MaxText in-process run: 'layers' import failure due to sys.path (2025-09-11)
- Method: Executed `MaxText.train` via `runpy` at commit `6ce556e1`.
- Error: `ModuleNotFoundError: No module named 'layers'` from `MaxText/train.py`.
- Resolution: Added both the repo root (`/kaggle/working/maxtext`) and the package root (`/kaggle/working/maxtext/MaxText`) to `sys.path` prior to running. This progressed execution to the next error.

### 17. JAX API mismatch: `jax.random.KeyArray` missing (2025-09-11)
- Method: Continued in-process execution after fixing `sys.path`.
- Error: `AttributeError: module 'jax.random' has no attribute 'KeyArray'` arising in `MaxText/aqt/jax/v2/config.py` type annotations.
- Analysis: The older MaxText/AQT code expects `jax.random.KeyArray`, which is not present in `jax==0.4.34` on Kaggle TPUs.
- Resolution Attempt: Inserted a compatibility shim before running MaxText: define `jax.random.KeyArray = jax.Array` (fallback to `jnp.ndarray` if needed). Re-run pending to verify.

## Current Status (as of 2025-09-11 ~08:45)
**PARTIALLY UNBLOCKED (verification pending)**
- Addressed import path issue for `layers` via `sys.path` fix.
- Added JAX `KeyArray` compatibility shim to satisfy older AQT/MaxText type usage.
- AQT legacy module `aqt.jax.v2.google.maxtext_sweeps` still not available via install; monorepo approach failed; minimal shim is only viable if base `aqt` package imports. Next action: re-run minimal `steps: 1` and observe; if imports still fail, revisit AQT install source (e.g., pinned commit ZIP for `google/aqt`, or vendored minimal modules).

### 18. Wrong PyPI `aqt` package (Anki) caused `import anki.lang` failure (2025-09-11)
- Method: Installed `aqt` from PyPI as a base, then attempted to shim `aqt.jax.v2.google.maxtext_sweeps`.
- Error: `ModuleNotFoundError: No module named 'anki'` during `import aqt` in `MaxText/MaxText/layers.py` dependency chain.
- Analysis: PyPI's `aqt` resolves to the Anki Qt application package, not Google's Accurate Quantized Training (AQT) library required by MaxText. The shim layered on top of the wrong base package and could not succeed.
- Resolution: Uninstall PyPI `aqt`, clone `google/aqt` and pin to historical commit `3275a461e59b90558352f1b40209e13462f44c38` (2023-09-07), install from local source (`pip install --no-deps /kaggle/working/aqt-src`), keep a minimal shim only if `aqt.jax.v2.google.maxtext_sweeps` remains absent. Re-run pending.

### 19. AQT legacy layout still missing during MaxText run (2025-09-12)
- Method: Fresh clone of MaxText at commit `6ce556e1`; executed training via in-process `runpy` with sequential config flags (`--config`, `--config_file`, `--config_files`, `--yaml_config`, `--config_path`).
- Error: `ModuleNotFoundError: No module named 'aqt.jax.v2'` from `MaxText/layers.py` import `from aqt.jax.v2 import aqt_dot_general as aqt`.
- Analysis: The notebook session did not have the legacy AQT package layout installed at run time. Either the AQT setup cell did not execute or the install did not pin to a historical commit that exposes `aqt/jax/v2`. The presence of `Found 8 devices.` confirms JAX initialized; failure occurs at first AQT import.
- Resolution (next): Add a dedicated AQT install cell early in the notebook that:
  1) `git clone https://github.com/google/aqt.git /kaggle/working/aqt-src`
  2) `cd /kaggle/working/aqt-src && git checkout 3275a461e59b90558352f1b40209e13462f44c38`
  3) `pip install --no-deps /kaggle/working/aqt-src`
  4) `pip install tensorboardX`
  5) Verify with `python - <<'PY'\nimport importlib; import sys; m = importlib.import_module('aqt.jax.v2'); print('AQT v2 OK:', m.__file__)\nPY`
If the import still fails, vendor a minimal shim only after confirming base `aqt` is importable.

### 20. Pinned AQT commit installed, but `aqt.jax.v2` still not importable (2025-09-12)
- Method: Simplified Step 7 to deterministically clone `google/aqt`, checkout pinned SHA `3275a461e59b90558352f1b40209e13462f44c38`, install from local source (no deps), install `tensorboardX`, then run MaxText in-process.
- Error: `ModuleNotFoundError: No module named 'aqt.jax.v2'` raised from `MaxText/MaxText/layers.py` at the point it imports `from aqt.jax.v2 import aqt_dot_general as aqt`.
- Analysis: The pinned AQT source likely contains `aqt/jax/v2` on disk but that subpackage is not included in the wheel/installed package at that commit (packaging excludes the directory). As a result, `pip install` succeeds yet the `v2` API is missing at runtime.
- Resolution (next): After installing AQT from local source, if `import aqt.jax.v2` fails but `/kaggle/working/aqt-src/aqt/jax/v2` exists, copy that folder directly into the installed package location (e.g., `site-packages/aqt/jax/v2`). Then re-try imports. Keep the minimal shim for `aqt.jax.v2.google.maxtext_sweeps` only if the base `v2` package imports successfully.

### 21. In-process MaxText run fails: config argv parsed as 'MaxText.train' (2025-09-12)
- Method: Fresh clone at commit `6ce556e1`; AQT installed and verified; ran in-process via `runpy.run_module('MaxText.train')` with:
  - `sys.path += ['/kaggle/working/maxtext', '/kaggle/working/maxtext/MaxText']`
  - `sys.argv = ['-m', 'MaxText.train', '/kaggle/working/config/minimal_maxtext_config.yaml']`
- Error:
  - `FileNotFoundError: [Errno 2] No such file or directory: 'MaxText.train'`
  - Origin: `MaxText/pyconfig.py` reads `argv[1]` as the YAML path; our `argv[1]` was `'MaxText.train'` due to the `-m` style argv we set.
- Analysis:
  - This legacy entrypoint expects the config file as positional `argv[1]` (no flags). Passing `['-m', 'MaxText.train', CONFIG]` shifts the config to `argv[2]`, causing `pyconfig` to try opening `'MaxText.train'` as a file.
- Resolution:
  - Set `sys.argv` to a minimal positional form where `argv[1]` is the YAML path, e.g. `sys.argv = ['train', str(CONFIG_PATH)]` (or `['', CONFIG]`). Then call `runpy.run_module('MaxText.train', run_name='__main__')`.
  - Keep both repo and package roots on `sys.path`.

### 22. Second run after manual filepath lookup: new error (2025-09-12)
- Method: User manually located an older/legacy filepath in the MaxText repo and adjusted the notebook accordingly; re-ran the verification step.
- Error: [awaiting exact notebook output from user]
- Analysis (preliminary):
  - If the error is a path issue (e.g., missing module/file), likely candidates are:
    1) Wrong relative base when opening YAML (use absolute `CONFIG_PATH`).
    2) Import path for `layers` or `pyconfig` (ensure both repo root and `MaxText/` added to `sys.path`).
    3) Flag name mismatch (`--config*`) vs positional-only config in this commit.
  - If it’s an import error involving AQT or `tensorboardX`, verify Step 7 ran successfully in the same kernel session.
- Resolution (next):
  - Apply the argv fix from #21, then re-run.
  - If error persists, share the exact stack trace to finalize this entry and adjust paths/flags accordingly.
