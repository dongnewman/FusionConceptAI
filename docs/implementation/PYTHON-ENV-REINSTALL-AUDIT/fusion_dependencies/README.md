# FusionConceptAI Python environment reinstall audit

Audit date: 2026-09-15 (Asia/Shanghai). This is a read-only audit after the
local scientific environments were recreated. No package installation,
solver, Julia, DESC, VMEX, or new run was started by this audit.

The source repository is `D:\006-Programing\LMC\FusionConceptAI`. The pinned
Python backends are materialized in the sibling generated-project checkout
`D:\006-Programing\LMC\outputs\fusion_concept_ai`; the source repository
contains receipts that refer to those paths.

## Environments and declared dependency sources

The five local prefixes found from the project configuration are:

| Prefix | Role | Source of declaration | Python status |
|---|---|---|---|
| `outputs/fusion_concept_ai/.venv-desc` | DESC 0.17.3 fixed-boundary and field providers | `requirements-desc-windows-fixed-boundary.txt` | Python 3.13.5, launcher present |
| `outputs/fusion_concept_ai/.venv-freegs` | FreeGS 0.8.2 / freeqdsk 0.5.2 | `requirements-freegs.txt` | Python 3.13.5, launcher present; system site packages enabled |
| `outputs/fusion_concept_ai/.conda-pleiades-public` | public Pleiades WHAM adapter | `requirements-pleiades-public.txt` | Python 3.9.25, present |
| `outputs/fusion_concept_ai/.conda-vmex` | VMEX 0.7.0 executable and Python package | `conda-meta` plus project VMEX scripts | Python 3.12.13, present |
| `outputs/fusion_concept_ai/.conda-cql3d-build` | CQL3D public Fortran/netCDF build tools | `scripts/audit_cql3d_public_build_regression_v2.jl` | No Python by design |

The root `conda env list` only displays the three Conda prefixes; the two
`.venv-*` prefixes are ordinary virtual environments and are not listed by
that command.

The requirement files are fully satisfied by installed distribution metadata
for DESC, FreeGS, and Pleiades. The DESC environment intentionally omits
`jax-finufft`: `requirements-desc-windows-fixed-boundary.txt` documents that
the dependency has no native Windows wheel and limits this environment to the
fixed-boundary path.

## Import and dependency smoke evidence

Commands were run as `python -B -c` against each prefix. Exit codes are the
process exit codes.

| Environment | Smoke result | `pip check` | Interpretation |
|---|---|---:|---|
| `.venv-desc\Scripts\python.exe` | exit 0; `desc 0.17.3`, `numpy 2.4.2`, `scipy 1.18.0`, `jax 0.9.2`, `jaxlib 0.9.2`, `h5py 3.16.0`, `netCDF4 1.7.3`, `jaxtyping 0.3.11` imported from this venv | exit 1: `desc-opt 0.17.3 requires jax-finufft, which is not installed` | Fixed-boundary DESC import path is available; NUFFT-backed features remain unavailable by declared design |
| `.venv-freegs\Scripts\python.exe` | exit 0; `freegs 0.8.2`, `freeqdsk 0.5.2`, `numpy 2.1.3`, `scipy 1.15.3`, `h5py 3.12.1` imported | exit 0, no broken requirements | FreeGS software import path is available; NumPy/SciPy/h5py resolve from the base installation because this venv has `include-system-site-packages = true` |
| `.conda-pleiades-public\python.exe` | exit 0; `pleiades 0.2.0-dev`, `numpy 1.26.4`, `scipy 1.13.1`, `matplotlib 3.9.4` imported | exit 0, no broken requirements | Public Pleiades adapter import path is available under required Python 3.9 |
| `.conda-vmex\python.exe` | `vmex`, `vmex.core`, `vmec_jax`, and `booz_xform_jax` imported; `vmex 0.7.0`, exit 0 | exit 0, no broken requirements | VMEX Python package path is available; project calls the executable, not a `vmec` Python module |
| `.conda-cql3d-build` | no Python executable or pip; prefix contains Fortran compiler/make and netCDF libraries | not applicable | This is a build-tool prefix, not one of the Python consumers |

The VMEX executable checks found both
`outputs/fusion_concept_ai/.conda-vmex/Scripts/vmec.exe` and `vmex.exe`, each
108,366 bytes with SHA-256
`D139A1B2FF2883FFBA2362E1D98F279BA8BF3001E709C31E1CCF40CDB82674C2`.

## Consumer bindings and receipt behavior

The source repository has explicit Python consumers for DESC and FreeGS. DESC
provider execution probes, in order, `DESC_PYTHON`, a local `.venv-desc`, the
sibling `outputs/fusion_concept_ai/.venv-desc`, and `PATH`; the provider receipt
stores the executable path and SHA-256, DESC module path and SHA-256, command,
exit codes, and output hashes. The RuntimeV4 field, basis, rho-surface, and
static-balance providers all validate these receipt bindings.

The source also contains a hard-coded FreeGS runtime constant pointing to
`D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Scripts\python.exe`.
The high-fidelity adapter portfolio and tests use the sibling `.venv-desc`,
`.venv-freegs`, `.conda-pleiades-public`, and `.conda-vmex` paths. Pleiades
uses Python 3.9 intentionally because the public source imports
`collections.Iterable`.

Existing revised-chain receipt evidence records the DESC executable as
`outputs/fusion_concept_ai/.venv-desc/Scripts/python.exe` and the module as
`.../.venv-desc/Lib/site-packages/desc/__init__.py`. The current recreated
files have the same SHA-256 values recorded in that receipt:

- Python executable: `CEC2FAB4B3258900CC330346DE8C664E57FA04227406920A6EDB06F0EFEEEBB1`;
- DESC module: `F3FACF2F730B9BCAC9D0AC38DA6DE6A1B4C5C1173BE5C3D0B7F9EB3DEE179AD5`.

This establishes byte identity for those two receipt-bound files. It does not
revalidate the old physical run or transfer its scientific status to the new
environment.

## Mainline decision and claim boundary

The software mainline can continue through the DESC fixed-boundary provider,
FreeGS import path, Pleiades public adapter, and VMEX executable discovery at
the level of environment/import readiness. The only expected dependency gap is
DESC's deliberately absent `jax-finufft`; NUFFT-backed objectives must remain
classified as unavailable.

The audit does not establish a successful physical provider run, convergence,
cross-code agreement, or hardware/device readiness. Existing RuntimeV4 and
spatial receipts remain bound to their recorded executable/module hashes and
their prior run artifacts. Any new physical execution must create a fresh
receipt after the current source, input, solver, and environment hashes are
bound together.

## Reproducibility commands

```powershell
$root = 'D:\006-Programing\LMC\outputs\fusion_concept_ai'
& "$root\.venv-desc\Scripts\python.exe" -B -c "import desc,numpy,scipy,jax,jaxlib,h5py,netCDF4; print(desc.__version__, numpy.__version__, scipy.__version__, jax.__version__, jaxlib.__version__, h5py.__version__, netCDF4.__version__)"
& "$root\.venv-desc\Scripts\python.exe" -m pip check
& "$root\.venv-freegs\Scripts\python.exe" -B -c "import freegs,freeqdsk,numpy,scipy; print(freegs.__version__, freeqdsk.__version__, numpy.__version__, scipy.__version__)"
& "$root\.venv-freegs\Scripts\python.exe" -m pip check
& "$root\.conda-pleiades-public\python.exe" -B -c "import pleiades,numpy,scipy,matplotlib; print(pleiades.__version__, numpy.__version__, scipy.__version__, matplotlib.__version__)"
& "$root\.conda-pleiades-public\python.exe" -m pip check
& "$root\.conda-vmex\python.exe" -B -c "import vmex,vmec_jax,booz_xform_jax; print(vmex.__version__)"
& "$root\.conda-vmex\python.exe" -m pip check
```
