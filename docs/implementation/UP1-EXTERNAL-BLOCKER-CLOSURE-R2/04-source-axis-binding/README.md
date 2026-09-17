# UP1 R2 source/axis binding

This additive component freezes the software input identity used by the UP1 external-closure handoff and validates an exact four-axis join.

The immutable source identity contains the full 40-hex `HEAD`, its `HEAD^{tree}`, dirty-status digest, patch digest, sorted untracked path/content records and an explicit submodule/closure record. Its derived digest excludes reverse edges and the self field. A fresh observed identity is mandatory and must match the frozen immutable facts. Each axis material contains a content digest, namespace, version, issuer, UTC issue time and candidate id. The source-side and candidate-side reverse edges must match the material byte-for-byte, including the material digest. Missing, repeated, unknown, foreign or ambiguous axes, hash mismatch and observed source drift are fail-closed.

The four axis names are `payload_schema_version`, `canonicalization_profile_version`, `applicability_profile_version` and `evidence_receipt_version`. `EXTERNAL_ISSUED` additionally requires validated external signature, project trust root, trusted time, revocation and G2 mapping, plus per-axis signature references; issuer text alone is never sufficient. Missing external issuer material is represented as `typed_absence` with `terminal_deferred`; a complete fixture is explicitly `TEST_ONLY`/`non_evidence`. AD56 is retained only as dirty software bookkeeping and cannot provide authority evidence. Unknown schema/fields, scalar objects and duplicate JSON keys are rejected; errors are canonically sorted.

## Reproduce

From the repository root:

```text
python -B -m unittest discover -s test/up1_external_closure_r2/source_axis_binding -p test_*.py -v
python -B tools/up1_external_closure_r2/source_axis_binding/source_axis_binding.py --input test/up1_external_closure_r2/source_axis_binding/fixtures/typed_absence.json
```

The CLI emits canonical JSON on stdout and exits `0` for a valid test/typed-absence receipt, `1` for a contradiction, and `2` for a program/input exception. The raw streams, process id, UTC timestamps, exit code and SHA-256 values are recorded in `validation_receipt.json`.

Claim ceiling: software contract and fail-closed validation only. No external issuer, candidate authority, provider, engineering or physical evidence is claimed.
