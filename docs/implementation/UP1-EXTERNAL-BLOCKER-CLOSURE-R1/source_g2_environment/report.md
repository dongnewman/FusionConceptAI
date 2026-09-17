# W3 source/G2/environment closure report (repair R2)

## Result

Repair R2 adds an independent strict production-profile G2 evaluator/schema, duplicate-key and unknown-field rejection, per-security-field negative cases, explicit TEST_ONLY non-evidence handling, and input/output artifact hash linkage. The bounded R2 validator attempts are preserved: PID `24644` exit `1` failed on an incorrect validator repo-root index; the corrected retry PID `111940` exit `1` returned `fail_closed` with an empty assertion detail. No passing R2 receipt is claimed. The result remains `preparation_only`, `screen_only`, never an UP1 or formal-credit receipt. Current dirty status/patch hashes differ from the old freeze and are recorded as `typed_drift_terminal_deferred`; no freeze was silently rewritten and no new AD was created.

## Frozen source and material status

Repair note: the paragraph below records the pre-repair freeze and is superseded for current validation. Current status SHA-256 is `8ad8e9f6a3e3c98cbc4ad0fba5c332cd0ab70a0d01a687a10d85bea232c70fc7`; current patch SHA-256 is `3665717b31dbd8224f29185a86446997c9c500ef406df0e4288fd57a4e60ecc1`. The old `d05d1f...`/`fb9098...` pair remains immutable historical input. This is `typed_drift_terminal_deferred`; no freeze rewrite or new AD.

The audit observed HEAD `b2c04d8339774635aaecd73651efcdb101e01b5d`, tree `e28da2ff057201c2257f6b879d3860b7a49cb428`, dirty-status SHA-256 `d05d1f0057c40bb3caa348506cd16fc94ba97ff0c9d6666513a872072a89e09a`, and dirty-patch SHA-256 `fb9098af62f30d8b74a13ccac2ad5722a51f1e4879fcf72b4076a0985e53b8ed`. G1/G2 source objects are HEAD-bound in the snapshot; G3 realization differs between HEAD and the working tree. Existing AD-55/AD-56 records remain historical/read-only. AD-43 supplies four source-only axis contract materials (shared schema, G1 evidence, G2 applicability, G2 evidence) with exact URI/hash/media/schema/owner; each candidate binding remains typed absent. The four G2 V5 version identifiers are also recorded separately and are not substituted for the AD-43 axis materials.

## G2 mapping and external inputs

No authoritative namespace/version/interval/issuer/signature/key chain/revocation/anti-replay record was supplied. The mapping is therefore `typed_absent`; contradictions, duplicates, stale intervals, foreign hashes/owners and replayed/revoked signatures are specified as `fail_closed`. Responsibility, authoritative source and recovery condition are listed per input in `external_input_register.json`.

## Environment and binary closure

Observed local OS/architecture/locale/timezone and Julia 1.10.5/Python 3.13.5/Git 2.51.0 executable paths and hashes are recorded as observations, not candidate provenance. Project/Manifest hashes are frozen. The complete import closure, channel/build metadata, publisher signatures, download origins, recipes, SBOMs and licenses are absent and remain deferred. No Julia, DESC, mesh, solver or recomputation was run.

## Repair controls

The production path has no present record. `g2_production_profile_schema.json` and `production_g2_evaluator.py` reject duplicate keys, unknown fields, missing/invalid namespace, version, effective interval/trusted time, issuer identity/chain, signature bytes/algorithm/key id/certificate chain, trust-root policy/EKU/key-usage/name constraints, revocation status/freshness, nonce/sequence/idempotency/replay, ambiguity/conflict, and source-candidate-evidence edge mismatches. `valid_present.json` is an explicit synthetic `TEST_ONLY` profile: structural acceptance returns `non_evidence` and never production admission. Parameterized negative cases plus a duplicate-key fixture are executed through the evaluator and must reject. Every typed absence carries owner, authoritative source, authority reference, recovery and expiry. The external input register has a canonical JSON fingerprint and no-repeat rule. Source/evidence inverse edges are hash/URI checked; candidate edges remain typed absent. Environment and binaries remain typed absent until non-shape, candidate-bound import/artifact and signed provenance closure exists.

## Independent review points

1. The R2 validator attempts are preserved in `raw/`; a future round must diagnose the empty assertion and rerun `python -B static_validator.py` with bytecode disabled. Input/output artifact maps exclude manifest, cleanup, and validation receipt self-hashes by policy.
2. Recompute HEAD/tree/status/patch hashes and confirm no source/test/registry/shared-doc path changed.
3. Check every absent axis/mapping/environment/binary record has a typed code, owner, authoritative source and recovery condition.
4. Verify historical AD-55/AD-56 references are not promoted to candidate or trust authority.
5. Confirm the claim ceiling remains `preparation_only/screen_only` and no T0/T1/T2/B00/B04/R/L4/parent credit is asserted.
6. Confirm the exact pre-existing `__pycache__/static_validator.cpython-313.pyc` and empty `__pycache__` directory were removed, with no replacement bytecode generated.

## Repair R3 disposition

The targeted diagnostic (PID `10148`, exit `0`) identified the preserved R2 empty assertion as current dirty status/patch drift from the recorded snapshot, not an evaluator acceptance defect. The repair keeps the historical snapshot immutable and changes only the validator's interpretation to an explicit `typed_drift_terminal_deferred` state; it does not rebind source authority or create an AD.

One fresh authoritative `python -B static_validator.py` run (PID `102332`, exit `0`) passed the exact manifest set, HEAD/tree binding, four-axis typed absence, G2 typed absence, environment/binary typed absence, canonical input fingerprint, 24 production negative cases plus duplicate-key rejection, and TEST_ONLY non-evidence. The emitted result reports `negative_case_count=25` including the duplicate-key case. Raw stdout/stderr/combined, PID, UTC, exit and hashes are recorded in `repair_r3/` and `validation_receipt.json`; both historical R2 failures remain preserved. No Julia, DESC, mesh, solver, recomputation, gate credit or source authority is claimed.
