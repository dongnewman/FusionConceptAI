# UP1 R4 environment/binary external-input recheck

## Verdict

`new_ad=false`, `s3_rerun=false`, `formal_credit=none`.

The recheck is `typed_absent` for candidate-bound environment closure and
binary provenance. The locally visible Project/Manifest files and executable
hashes are `untrusted` (`local_observed_not_external_authority`): they provide
bytes and some version observations, but do not provide candidate binding,
publisher/source signatures, download origin, build recipe, SBOM, license,
platform matrix, or a reproducible build chain. No newly usable input was
found relative to the R4 frozen scan.

## Frozen scope and method

- Repository: `D:\006-Programing\LMC\FusionConceptAI`
- Fixed HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`
- Audit UTC: `2026-09-17T04:01:35.9384378Z`
- Audit process: PID `94364`
- Allowed writes: this `environment-binary/` directory only.
- Actions: PowerShell/Git static metadata, file hashes, path existence, and
  source-text inspection only. No dependency installation, network access,
  Julia/DESC/S3 invocation, or test execution.

The relevant `git diff --quiet` returned exit `0`; the four Project/Manifest
paths and the R4 environment-closure source/test paths have no diff from the
fixed HEAD. Existing R4 delta evidence also records `changed_count=0` for its
nine frozen environment/runtime inputs.

## Findings

| Input class | Observation | Classification | Closure result |
|---|---|---|---|
| Root `Project.toml` / `Manifest.toml` | 563/3348 bytes; SHA-256 `923b7893…1370e2` / `85074b7a…57717e7`; Manifest declares Julia `1.10.5` | present local lock/declaration | `untrusted` |
| Gridap `Project.toml` / `Manifest.toml` | 55/34697 bytes; SHA-256 `223fb6c8…affceb6` / `2e1d1033…3765a`; Manifest declares Julia `1.10.5` | present local lock/declaration | `untrusted` |
| Python exact lock/channel freeze | No `requirements*.txt`, `requirements*.lock`, `Pipfile.lock`, `poetry.lock`, `uv.lock`, `environment*.yml`, `conda-lock.yml`, or `pixi.lock` in workspace | absent | `typed_absent` |
| Known runtime/binary paths | Julia, Anaconda Python, DESC venv Python, DESC launcher, and Git are present and hashable; hashes match the R3/R4 local inventory | local bytes only | `untrusted` |
| Candidate-bound import/package/artifact ledger | No candidate reference or non-empty candidate-bound import/artifact closure | absent | `typed_absent` |
| Publisher/source/download/build provenance | No candidate-bound signed receipt, origin/download receipt, or build recipe | absent | `typed_absent` |
| SBOM and license closure | No candidate-bound SBOM/license package; no top-level `LICENSE*` file | absent | `typed_absent` |
| Platform/build chain | Host/runtime observations are not an attested platform matrix or reproducible build chain | not supplied | `typed_absent` |
| R4 collector implementation | Static observation-only implementation is present; its policy forbids install/network/env capture and treats missing provenance as typed absent | local tool evidence | `untrusted` |

The historical R4 files under `docs/implementation/` are bookkeeping and
local test evidence. Their presence does not turn an old fixture, receipt, or
schema into external authority; no newly supplied response/anchor bundle was
found at the frozen intake paths (`response`, `anchors`, `local_spool`,
`local_receipts`, `incoming`, `intake`).

## Responsibility and recovery contract

| Gap | Responsible party | Required recovery |
|---|---|---|
| Candidate environment/import/package/artifact closure | execution/environment provider | Supply one candidate-bound manifest covering every imported module, package, channel/build, loader path, runtime artifact and exact SHA-256, with candidate/HEAD binding. |
| Binary origin and publisher trust | binary publisher/distributor plus independent provenance reviewer | Supply signed origin/download receipt, publisher signature/trust chain, exact binary hashes, platform/architecture, and independent verification receipt. |
| Build reproducibility | environment/build owner | Supply pinned build recipe/container/toolchain, platform matrix, lock/channel freeze, and deterministic rebuild receipt. |
| SBOM/license | publisher/distributor or environment owner | Supply candidate-bound SPDX/CycloneDX (or equivalent) SBOM with dependency edges and license records, all hash-bound to the binaries. |
| Authority/intake | external authority/channel owner | Return a fresh, signed, replayable response bundle through a verified channel; local hashes and Windows certificate-store observations cannot substitute. |

Only after the complete bundle is received should the owner rebuild the
candidate identity/upstream receipts and run exactly one fresh authority
recheck. If any field is missing or hash/signature/candidate binding fails,
retain `typed_absent`/`untrusted`, `formal_credit=none`, and do not rerun S3.

## Evidence files

- `receipt.json`: structured recheck verdict and per-class disposition.
- `hash_manifest.json`: SHA-256/size inventory for this report, receipt, raw
  captures, and inspected workspace inputs.
- `raw/`: static command captures with PID, UTC, exit, digest, and failure
  fields.
