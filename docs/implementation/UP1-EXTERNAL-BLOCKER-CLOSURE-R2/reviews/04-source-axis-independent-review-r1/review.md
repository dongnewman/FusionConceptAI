# UP1 R2 source/axis binding — independent attack review r1

Decision: **rework**. This is a `TEST_ONLY` review and carries no authority,
candidate, provider, engineering, physical or formal-gate credit. The review
read only the source-axis implementation/tests/evidence, the R2 frozen
contract, and the R2 source-capture inventory. It wrote only this review
directory.

## Fresh receipt

- Frozen checkout observed: `HEAD=b2c04d8339774635aaecd73651efcdb101e01b5d`,
  `HEAD^{tree}=e28da2ff057201c2257f6b879d3860b7a49cb428`.
- `python -B -m unittest discover -s test/up1_external_closure_r2/source_axis_binding -p test_*.py -v`: exit 0, 8/8 passed.
- Two fresh `python -B -m source_axis_binding` processes over
  `fixtures/typed_absence.json`: both exit 0, canonical stdout SHA-256
  `ac1d828d48fd33b1844a98e2434b84f0b7d6bc8c6efe2da946c0cfd495b1c0e8`, and
  distinct PIDs. Raw streams and process metadata are in `run_receipt.json`.
- The attack matrix has ten cases; seven semantic validator gaps plus
  duplicate-key parsing and two source-capture gaps are reproducible in
  `attack_matrix.json`. All raw outputs are under `raw/` and hashes are in
  `evidence_manifest.json`.

## Findings

### F1 — P1: issuer label alone can produce `authority_evidence=true`

At `source_axis_binding.py:201-209` the authority predicate is only
`provenance_class == external_issued`, `state == EXTERNAL_ISSUED`, and every
issuer is a non-`typed_absence:` string. It does not verify a detached
signature, trust root/key usage, trusted receipt time, revocation/OCSP/CRL,
freshness, anti-replay, or authoritative G2 mapping. The result then emits
`authority_evidence=true` at lines 298-305. The attack case
`AUTH-ISSUER-ONLY-NO-SIGNATURE-TIME-G2` therefore returns valid/authority true.
`MISSING-SIGNATURE-TRUSTED-TIME-G2-MAPPING` reproduces the same bypass.
This contradicts the frozen interface's forbidden promotions and the
11-source-capture missing-field list. The component must never promote
authority; at most it can report structurally bound non-evidence or typed
absence.

### F2 — P1: an axis can carry a foreign source digest and still pass

The loop at `source_axis_binding.py:274-293` computes an expected edge from the
bundle source digest but never checks `material["source_identity_digest"]`.
That field is included in `material_digest`, so a test can set it to a foreign
64-hex value, recompute the material digest and both edges, and obtain a valid
`TEST_ONLY` receipt. `FOREIGN-MATERIAL-SOURCE-DIGEST` is that exact case. This
breaks the required source↔axis↔candidate same-source join even though the
reverse edges themselves look exact.

### F3 — P1: schema and malformed collection entries are silently accepted

The validator never checks the bundle or identity schema (`source_axis_binding.py:164-200`),
and `_materials_as_list`/`_edge_map` silently filter non-mapping entries at
lines 132-149. Consequently an unrecognized top-level schema, unknown fields,
an extra scalar material, or an extra scalar edge can be added and still
produce a valid receipt. These are `UNKNOWN-SCHEMA-AND-FIELDS`,
`SCALAR-MATERIAL-SILENTLY-DROPPED`, and `SCALAR-EDGE-SILENTLY-DROPPED` in the
matrix. Strict object schemas and rejection of every non-object/unknown key
are needed for deterministic exact-set validation.

### F4 — P1: duplicate JSON keys are accepted by the CLI

`main()` calls ordinary `json.loads` at `source_axis_binding.py:323`; Python's
default decoder silently keeps the last duplicate key. A raw bundle with two
top-level `candidate_id` keys is accepted as `TEST_ONLY` with exit 0 in
`DUPLICATE-JSON-KEY-CLI`. The parser needs a duplicate-detecting
`object_pairs_hook` and must classify duplicates as `fail_closed` (not allow a
last-wins rewrite of a signed/canonical object).

### F5 — source capture does not bind the captured tree or untracked bytes

`capture_source_identity()` captures `HEAD`, status text and tracked diffs at
`source_axis_binding.py:82-100`, but never captures `git rev-parse HEAD^{tree}`.
The frozen `11-source-capture/snapshot.json` has a distinct `head_tree` field.
More importantly, `git status --untracked-files=all` contributes only path
names to `dirty_status_digest`, while `git diff` does not include untracked
file bytes. In this intentionally untracked-heavy worktree, an untracked
source file can change content without changing either captured digest. The
matrix records `CAPTURE-MISSING-HEAD-TREE` and
`CAPTURE-UNTRACKED-CONTENT-BLIND`. A fresh observed capture is also optional
(`observed_source_identity=None`), so validation can otherwise accept a
self-reported fake source identity. Bind tree OID and content-address every
in-scope dirty/untracked source, and require the observation for any admission
path.

### F6 — P2: failing receipts are order-sensitive under axis permutation

`materials` is traversed in input order at `source_axis_binding.py:218-223`
and errors are appended in that order at `258-293`; only `axis_set` and
missing/unknown summaries are sorted. Reversing the same two-invalid-axis
bundle changes the canonical receipt's error array and paths, as shown by
`ERROR-ORDER-AXIS-PERMUTATION`. If axis arrays are semantically unordered,
normalize them before validation or sort errors by canonical path/code before
emitting receipts; otherwise a caller can get different receipt bytes for the
same set of facts.

## Boundary checks

The advertised positive typed-absence CLI receipt is present under
`04-source-axis-binding/raw/` and its two declared hashes match the current
files. The component manifest and receipt correctly state a limited/software
claim ceiling and `authority_evidence=false` for the fixture. The defect is
that implementation code can contradict that ceiling for a caller-supplied
external-looking bundle; therefore the limited fixture receipt does not close
the findings. No AD56 label or local Git fact was credited as authority.

Required disposition: return to implementation, add strict schema/duplicate
key handling and source/material consistency checks, make source capture
content- and tree-bound, and permanently force this component's output to
non-evidence until the separate authority intake verifies the missing external
fields. Re-run the attack matrix and an independent review after the patch.
