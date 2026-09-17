# UP1 R2 source/axis binding — independent attack review r3

Decision: **pass_limited**. This is a `TEST_ONLY`/`non_evidence` review and
grants no external authority, candidate, provider, engineering, physical or
formal-gate credit. The implementation, tests and evidence were read only;
the only writes are inside this R3 review directory.

## Fresh receipt

- Frozen checkout: `HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`,
  `HEAD^{tree}=e28da2ff057201c2257f6b879d3860b7a49cb428`.
- Fresh `python -B -m unittest discover -s test/up1_external_closure_r2/source_axis_binding -p test_*.py -v`: exit 0, 13/13 passed.
- Fresh `python -B -m py_compile` over implementation and tests: exit 0.
- Two fresh CLI processes with the observed-source fixture: both exit 0,
  distinct PIDs, byte-identical stdout/stderr. All raw streams and hashes are
  recorded in `run_receipt.json` and `evidence_manifest.json`.
- `verification.json`: 31/31 checks passed.

## R3 attack coverage

The 20-case matrix in `attack_matrix.json` contains no findings and covers:

- issuer-only and incomplete external authority rejection with
  `authority_evidence=false` even on `fail_closed` receipts;
- acceptance of the complete five-prerequisite structural authority path;
- foreign material source digest and all original source↔axis↔candidate attacks;
- unknown fields at bundle, submodule, payload, AD56 and edge levels;
- scalar material/edge entries and duplicate JSON keys;
- exact identity schema, state and provenance closed enums;
- deterministic error ordering under axis permutation;
- `HEAD^{tree}`, sorted untracked content records and content digest capture;
- missing/stale fresh observed source rejection;
- typed absence and AD56 non-escalation; and
- component manifest/receipt raw-file existence and SHA-256 agreement.

The component now satisfies the reviewed software boundary: structural
authority output is positive only for a valid bundle with explicit external
prerequisites, while fail-closed, typed-absence and TEST_ONLY paths remain
non-authority. This does not verify any real external issuer or downstream
formal gate.

Disposition: accept this component at `pass_limited` for software contract and
fail-closed validation only. Preserve the frozen external-authority and
downstream gate ceilings; any future implementation or contract change
requires another independent review.
