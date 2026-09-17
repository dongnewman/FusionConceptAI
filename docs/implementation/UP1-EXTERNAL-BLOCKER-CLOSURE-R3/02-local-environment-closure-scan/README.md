# UP1 R3 — local environment and binary-source closure scan

This is a read-only Windows host observation for the UP1 reproducibility and
binary-source closure. It was performed from
`D:\006-Programing\LMC\FusionConceptAI` on the existing dirty worktree at
`HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`.

The scan used PowerShell and file reads only. It located executable files and
read file-version resources, file attributes, byte sizes, SHA-256 values,
dependency declarations, and installed-package metadata. It did not start
Julia, Python, DESC, S3, a solver, a compiler, a package manager, or a network
operation; it did not install, modify source/tests, or alter prior evidence.

## Local observations

| subject | observation |
| --- | --- |
| OS | Windows 11 Pro, version `10.0.26200`, build `26200`, AMD64, host `NEWORLDS-LAPTOP` |
| Julia | `C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe`; 169744 bytes; version `1.10.5`; company `JuliaLang`; SHA-256 `8e86e2d48c574393c37bbfb6e922ea4176ba8e1a83f956826f3da24948e389ad` |
| Python (Anaconda) | `D:\Users\Newman\anaconda3\python.exe`; 104264 bytes; version `3.13.5`; company `Python Software Foundation`; SHA-256 `388fe2cffda8a134e7d7dc4e978f7c478857ece6b69694daecbed25e51ec633a` |
| Python (DESC venv) | `D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-desc\Scripts\python.exe`; 253256 bytes; version `3.13.5`; SHA-256 `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1` |
| DESC launcher | `D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-desc\Scripts\desc.exe`; 108373 bytes; no PE version-resource values; SHA-256 `f5796f9665f142a995ee01626b05806facd3e648be9d15784c53729dab0f7d83` |

`python.exe` and `python3.exe` under
`C:\Users\Newman\AppData\Local\Microsoft\WindowsApps` are reparse-point
aliases. They report zero length and cannot be read or hashed in this session;
their path identity and bytes are therefore `typed_unverified`, not a runtime
identity. `python3.exe` also resolves to the MSYS2 installation when that PATH
entry is selected; the MSYS2 Python 3.12.12 file was located and hashed in the
initial probe but is not the project-declared Python runtime.

The DESC virtual environment has a local `pyvenv.cfg` (256 bytes,
SHA-256 `877b2ecf4e68c2afeb078bb02256bc5ab4a7771f2c4157fa76d92e11ba9cb977`)
pointing to Anaconda Python 3.13.5. Its `site-packages` contains 49
`*.dist-info` records with `METADATA` and `RECORD`, but no `direct_url.json`;
the Anaconda base has 508 `conda-meta/*.json` records. These are local package
manager records, not independently trusted provenance.

## Dependency and source declarations

The repository root has `Project.toml` (563 bytes,
SHA-256 `923b78938e12c27e836b269d71a539ae7bb292c9fe9f8cb92f9f9a8cea1370e2`)
and `Manifest.toml` (3348 bytes,
SHA-256 `85074b7a5bd543c0b4155f44db0733d21d53cfd0bf4c2de6704dc858357717e7`).
The manifest declares Julia `1.10.5`, format `2.0`, and a project hash. A
separate Gridap qualification environment has `tools/qualification/gridap/Project.toml`
(55 bytes, SHA-256
`223fb6c8ea33f03989ccb4d76ed80016a3bc2799bc4210490c4e43cc7affceb6`) and
`tools/qualification/gridap/Manifest.toml` (34697 bytes, SHA-256
`2e1d103396d3f3faa13687bd4a95fde287d1f94e8b0006046b65e1e29aa3765a`).

No repository `requirements*.txt`, `requirements*.lock`, `Pipfile*`,
`poetry.lock`, `uv.lock`, `environment*.yml/yaml`, or Python channel lock was
found. The only other `*.lock` hit is a prior R2 aggregate-gate evidence lock,
not a dependency lock. Anaconda `conda-meta` records locally contain channel,
URL, package SHA-256, build and dependency fields (for example the Python
record declares `https://repo.anaconda.com/pkgs/main/win-64`); this is a local
cache/manager declaration and is not an external signed receipt or SBOM.

## Closure result and evidence ceiling

* `local-observed`: executable locations, version-resource values, byte sizes,
  hashes, OS metadata, project/manifest files, `pyvenv.cfg`, and local package
  record counts above.
* `typed_unverified`: local publisher/company/version-resource strings,
  Authenticode-like metadata not independently verified here, WindowsApps
  aliases, conda/pip manager records, and all local hashes as external trust.
* `typed_absent`: candidate-bound import closure, exact Python lock and channel
  freeze, binary-to-candidate identity binding, and a complete runtime/library
  closure.
* `external-authority-required`: signed publisher identity and signature,
  signed download receipt with origin/retrieval time, reproducible build or
  container recipe, SBOM with supplier/license/dependency edges, and an
  independent trust-root/verification receipt for every runtime and imported
  binary/library.

The local SHA-256 values are useful change-detection observations only. They do
not close UP1, establish source authority, or provide candidate/physical/
solver/engineering/B00/B04/R01–R10/parent-goal credit. See `process.json`,
`environment_inventory.json`, `dirty_closure_summary.md`, and `raw/` for the
machine-readable receipt and raw observation notes.
