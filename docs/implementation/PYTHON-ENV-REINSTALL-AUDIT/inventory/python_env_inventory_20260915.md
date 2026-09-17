# Python environment reinstall inventory

Audit time: 2026-09-15 (Asia/Shanghai). This is a read-only inventory. No package installation, environment mutation, Julia run, DESC run, or source change was performed.

## Scope and identity resolution

`conda env list` exited 0 and reported six entries: three project-local conda prefixes, `base`, `newquant`, and `test`. Excluding the conda root `base`, the five conda entries are the strongest interpretation of “five environments”:

| Candidate | Prefix | Why it is in scope |
|---|---|---|
| `.conda-cql3d-build` | `D:\006-Programing\LMC\outputs\fusion_concept_ai\.conda-cql3d-build` | Project-local conda prefix; contains C/Fortran, HDF5, and NetCDF build packages. |
| `.conda-pleiades-public` | `D:\006-Programing\LMC\outputs\fusion_concept_ai\.conda-pleiades-public` | Project-local conda prefix; contains `pleiades==0.2.0.dev0` and matches `requirements-pleiades-public.txt`. |
| `.conda-vmex` | `D:\006-Programing\LMC\outputs\fusion_concept_ai\.conda-vmex` | Project-local conda prefix; contains `vmex==0.7.0`, `solvax`, JAX, and NetCDF4. |
| `newquant` | `D:\Users\Newman\anaconda3\envs\newquant` | Base-external conda environment listed by the host; its modules and packages are NewQuant-oriented. |
| `test` | `D:\Users\Newman\anaconda3\envs\test` | Base-external conda environment listed by the host; no repository-local ownership was found. |

The repository also contains two real Python venvs that are **not** shown by `conda env list`: `.venv-desc` and `.venv-freegs`. The DESC benchmark README directly invokes `.venv-desc` (`benchmarks/desc_heliotron_v0173/README.md:20-26` and `:36-45`), and the project has `requirements-desc-windows-fixed-boundary.txt` and `requirements-freegs.txt`. They are therefore included below as project-local runtime candidates. The spoken “five” cannot be uniquely mapped from repository evidence alone: it may mean the five non-base conda entries, while a Fusion runtime inventory must also account for these two venvs.

The initial process snapshot was read-only. It showed no active Julia/DESC workload; the transient Python/conda processes observed were the `conda env list` query itself. The final process snapshot was empty for Python/conda/Julia/DESC.

## Results

All interpreter probes used `-B` with `PYTHONDONTWRITEBYTECODE=1`. `sys.prefix` below is from the direct executable probe, not shell activation.

| Environment | Python executable and identity | pip/conda smoke | Key import smoke | Fingerprint and impact |
|---|---|---|---|---|
| `.conda-cql3d-build` | No `python.exe` at prefix root or `Scripts\python.exe`. | `conda list --prefix --json`: exit 0, 57 records. A probe through `conda run --prefix ... python` exited 0 but resolved `D:\Users\Newman\anaconda3\python.exe` (base), so it is not evidence of a prefix Python. | Not applicable; this prefix has no Python package. Key packages are `hdf5 2.2.0`, `libnetcdf 4.10.0`, `netcdf-fortran 4.6.4`. | Conda-list aggregate SHA256 `1a6ef74d91aa06f727ffc82048eff9580b9e95e15fd33ec7e51cdb90842c3179`; Python executable absent. Impact is limited to the C/Fortran/NetCDF build boundary; Python-dependent checks cannot use this prefix. |
| `.conda-pleiades-public` | `...\.conda-pleiades-public\python.exe`; CPython 3.9.25, AMD64/64-bit; `sys.prefix` equals the prefix. | `python -B -m pip --version`: exit 0 (`pip 26.0.1`); `pip check`: exit 0; `conda list --prefix --json`: exit 0, 51 records. | `pleiades 0.2.0-dev`, `numpy 1.26.4`, `scipy 1.13.1`, `matplotlib 3.9.4`, `IPython 8.18.1`: all imported successfully, exit 0. | Python exe SHA256 `3c573165deb67c2af3ab3495044a04bfb0d895edb2611ebe3e9cb77a6629715b`; conda-list aggregate SHA256 `01d0f5e0e0c8ffbf1ca128250561758fce6d1068ac2b357c4c1abcba74a4e56e`. Basic runtime is healthy. |
| `.conda-vmex` | `...\.conda-vmex\python.exe`; CPython 3.12.13, AMD64/64-bit; `sys.prefix` equals the prefix. | `python -B -m pip --version`: exit 0 (`pip 26.2.1`); `pip check`: exit 0; `conda list --prefix --json`: exit 0, 48 records. | `vmex 0.7.0`, `jax 0.11.1`, `jaxlib 0.11.1`, `booz_xform_jax 0.1.0`, `netCDF4 1.7.4`, `numpy 2.5.2`, `scipy 1.18.1`: all imported successfully, exit 0. | Python exe SHA256 `0937d5ac6dd108c73b0fad5d25c8da700038673f212242dbae4901fce8573de6`; conda-list aggregate SHA256 `372cb412c480fdd73bfdfc6d60b7f6187c003063817e171a9b02015dc2841e19`. Basic runtime is healthy. |
| `.venv-desc` | `...\.venv-desc\Scripts\python.exe`; CPython 3.13.5, AMD64/64-bit; `sys.prefix` equals the venv, `base_prefix` is `D:\Users\Newman\anaconda3`. | `python -B -m pip --version`: exit 0 (`pip 26.2.1`); `pip check`: exit 1: `desc-opt 0.17.3 requires jax-finufft, which is not installed.` | `desc 0.17.3`, `jax 0.9.2`, `jaxlib 0.9.2`, `numpy 2.4.2`, `scipy 1.18.0`, `h5py 3.16.0`, `netCDF4 1.7.3`: all imported successfully, exit 0. | Python exe SHA256 `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1`; `pyvenv.cfg` SHA256 `877b2ecf4e68c2afeb078bb02256bc5ab4a7771f2c4157fa76d92e11ba9cb977`; pip-list aggregate SHA256 `7b7908e939c0da6b1ce3ffa076a1940156c46f8cb8f60997e7e92d76ae4cf1a5`. The missing package is an acknowledged Windows boundary: requirements line 1 says DESC's `jax-finufft` has no Windows wheel and the fixed-boundary path is supported; NUFFT-backed objectives remain unavailable by design. |
| `.venv-freegs` | `...\.venv-freegs\Scripts\python.exe`; CPython 3.13.5, AMD64/64-bit; `sys.prefix` equals the venv, `base_prefix` is `D:\Users\Newman\anaconda3`; `include-system-site-packages=true`. | `python -B -m pip --version`: exit 0 (`pip 25.1.1`); `pip check`: exit 0. | `freegs 0.8.2`, `numpy 2.1.3`, `scipy 1.15.3`, `h5py 3.12.1`: all imported successfully, exit 0. The optional `netCDF4` probe failed with `ModuleNotFoundError`; it is not declared by `requirements-freegs.txt` (which declares only `FreeGS==0.8.2` and `freeqdsk==0.5.2`). `numpy`, `scipy`, and `h5py` resolved from the base site-packages because system site packages are enabled. | Python exe SHA256 `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1`; `pyvenv.cfg` SHA256 `15cfb3763bd78a314d331d69e8b6cf6b01fedc08709f55bf09103743619f1e44`; pip-list aggregate SHA256 `751a4012396c3b64bc3bf927c01f7d1f14cb5b1ac80f4a39341da369579a017d`. Runtime is usable for the declared FreeGS dependency, but it is not isolated from base. |
| `newquant` | `D:\Users\Newman\anaconda3\envs\newquant\python.exe`; CPython 3.11.15, AMD64/64-bit; `sys.prefix` equals the environment. | `python -B -m pip --version`: exit 0 (`pip 26.1.2`); `pip check`: exit 0; `conda list --prefix --json`: exit 0, 136 records. | `numpy 2.1.3`, `pandas 2.2.3`, `pytest 9.1.0`, `duckdb 1.5.4`: all imported successfully, exit 0. | Python exe SHA256 `1904297e70a9b68f6c9443768d096ee06ffcf61b0c0c296bff2dceb8b982d68f`; conda-list aggregate SHA256 `578cc30eac3673e494803b681be73f76383a22af2637cb5e28385f25c69a82fe`. Healthy as a standalone environment; project ownership is outside FusionConceptAI and should not be inferred from this audit. |
| `test` | `D:\Users\Newman\anaconda3\envs\test\python.exe`; CPython 3.8.20, AMD64/64-bit; `sys.prefix` equals the environment. | `python -B -m pip --version`: exit 0 (`pip 24.2`); `pip check`: exit 0; `conda list --prefix --json`: exit 0, 65 records. | `numpy 1.24.4` and `scipy 1.10.1` imported successfully. `pytest` and `h5py` probes failed with `ModuleNotFoundError`; this does not contradict `pip check` because neither is a declared dependency. | Python exe SHA256 `fce6b676f4892be540fa3172ae8e2b6f347fb80fc8a0af40a5b0d7e78e33241b`; conda-list aggregate SHA256 `50c9e4713ab67e6dd4ffc604b852818bb307899d51213e254c3722b82c92b72b`. Interpreter is healthy for its installed set; no FusionConceptAI ownership was established. |

For reference, `base` is CPython 3.13.5 AMD64 at `D:\Users\Newman\anaconda3`, with `conda list` exit 0 and 567 records. It is the conda launcher/root and the `home` for both project venvs; it was excluded from the five non-base conda candidates.

## Commands and evidence boundary

The common interpreter probe was:

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
& <prefix-python> -B -c '<sys.executable, platform.python_version, platform.machine, pointer width, sys.prefix, module imports>'
& <prefix-python> -B -m pip --version
& <prefix-python> -B -m pip check
```

For conda prefixes, the package probe was:

```powershell
& 'D:\Users\Newman\anaconda3\Scripts\conda.exe' list --prefix <prefix> --json
```

The aggregate fingerprint hashes the canonical, name/version/build/channel-sorted `conda list --json` records for conda prefixes. Venv fingerprints combine the direct Python executable SHA256, `pyvenv.cfg` SHA256, and name/version-sorted `pip list --format=json` records. These fingerprints identify this audit snapshot; they do not prove numerical, solver, DESC, FreeGS, Pleiades, VMEX, or physical readiness.
