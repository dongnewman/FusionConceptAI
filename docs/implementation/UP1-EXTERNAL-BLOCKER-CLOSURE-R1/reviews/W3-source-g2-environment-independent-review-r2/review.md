# W3 source/G2/environment independent review — round 2

## Decision

`rework_required`. The R1 bundle now closes the snapshot, typed-absence accountability, canonical no-repeat fingerprint, source/evidence inverse-edge, environment/binary fail-closed, drift, and raw PID/hash controls for preparation. It does not yet close the future-G2-present admission mechanically: the validator only checks that requirement names exist and its TEST_ONLY positive fixture omits several required security fields. The source validation receipt also lacks a per-input/per-output artifact hash map. No formal gate credit is granted.

The ceiling remains `preparation_only/screen_only`; this review grants no T0/T1/T2, B00, B04, UP1, R, L4, or parent-goal credit.

## Scope and boundary

Reviewed `source_g2_environment/**`, the prior W3 review, and the declared v4/AD references read-only. Only this directory was written. No source, test, registry, shared document, AD, key, certificate, executable, fixture, or source bundle file was changed. R01–R10 and the 39-node dependency DAG remain untouched.

## Recheck evidence

- All 27 source files are in the declared exact set, including the pre-existing/generated `__pycache__/static_validator.cpython-313.pyc`; cleanup inventory also owns it. It is not deleted here.
- Every source JSON parsed with duplicate-key rejection. The independent canonical fingerprint recomputed to `96cf258fa20442513b3a409860a7dbbb780f7048199fd7dc3d380584be9cb6c1`.
- Source validator rerun by this review: PID `87820`, exit `0`, UTC `2026-09-16T15:43:32.6163634Z`–`2026-09-16T15:43:33.6016312Z`. Positive and negative TEST_ONLY fixtures passed. Raw stdout/stderr/combined files and hashes are in this review's `raw/` directory.
- Recorded source validator PID `91276` and both failed attempts (`105624`, `93020`) have hash-matching raw files. PID 91276 stderr is only Git LF→CRLF warnings; exit is 0 and stdout is the pass JSON. The two failed attempts are preserved and classified.
- HEAD is `b2c04d8339774635aaecd73651efcdb101e01b5d`; tree is `e28da2ff057201c2257f6b879d3860b7a49cb428`. Current status/patch hashes are `8ad8e9f6a3e3c98cbc4ad0fba5c332cd0ab70a0d01a687a10d85bea232c70fc7`/`3665717b31dbd8224f29185a86446997c9c500ef406df0e4288fd57a4e60ecc1`; historical `d05d1f...`/`fb9098...` remain typed absence and `typed_drift_terminal_deferred`, with no new AD.
- All four AD-43 source-only axis references exist and their bytes match the declared hashes. Candidate edges remain explicitly typed absent. G2 mapping, candidate/environment closure, and binary provenance remain no-publish typed absence.

## Prior-finding disposition

W3-P1-002, W3-P1-003, W3-P1-004, W3-P2-001, W3-P2-002, and W3-P2-003 are substantively closed for the preparation claim. W3-P1-001 is closed only as a non-authoritative fixture control: `fixture_role=TEST_ONLY`, `status=test_only`, and `production_present_admission=false`; this is not production validation. W3-P2-004 remains open in mechanical form, and W3-P3-001 remains partially open; see `findings.json`.

## Formal blockers and recovery

Fresh S3 trust root, signed G2 mapping, certificate/policy chain, revocation and trusted-time evidence, candidate identity, complete import/artifact/environment closure, and signed binary provenance remain external inputs. Their absence is correctly terminal-deferred and no-repeat while the fingerprint is unchanged. Recovery requires the responsible authority/provider to supply changed, independently verifiable inputs, followed by a new exact snapshot, validator negative controls, raw receipt linkage, and independent Luna review. No Julia/solver/DESC/mesh/recompute was run.
