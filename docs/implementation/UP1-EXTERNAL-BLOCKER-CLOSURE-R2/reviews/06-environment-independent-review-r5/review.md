# UP1 R2 environment provenance independent review R5

## Decision

`pass_limited`. The authenticated-closure repair is effective for the R4
finding set: authority/verified time, download origin/retrieved time, binary
license, and SBOM supplier/license are now recomputed and bound to the
declaration, external expected context, and signed receipt payload. Mutating
any of those fields while synchronously recomputing the declaration closure
and declaration hash, but leaving the external context unchanged, returns
`fail_closed`.

No unresolved P1/P2 was found in this independent pass. This is a validator
and evidence-boundary result only; it is not candidate, source, provider,
solver, engineering, physical, B00, B04, UP1, R, or parent-goal completion.

## Fresh verification

This was a read-only review of the 06 implementation/tests/docs, with the
facts in 10-environment-capture used only as preparation evidence. No audited
file was changed and no installation or download was performed.

* Fresh `python -B -m pytest -q test/up1_external_closure_r2/environment_provenance`
  twice: `16 passed` on each run.
* Fresh `python -B -m py_compile` over all focused Python files: exit 0.
* Independent Ed25519 verification over two binary subject signatures, the
  signed receipt, and the outer envelope: `4/4`.
* 06 manifest: exact 20 files, all listed bytes and SHA-256 values match;
  pycache/pyc excluded.
* 10 capture manifest: all 56 artifact hashes match (its declared exact set
  has 57 entries including the manifest/self-exclusion convention).
* Two fresh validator runs produce identical `present/admissible` semantics;
  the signed TEST_ONLY positive remains `non_evidence`.

## R5 targeted closure attacks

Each of the following was mutated independently in a signed fixture. The
declaration `authenticated_closure` and `declaration_sha256` were recomputed
after mutation, while the caller-owned external context and trust anchor were
left unchanged. For the two download-receipt cases, the receipt self-digest
was also recomputed. All seven cases returned `fail_closed:reject`:

* `authority_proof.authority`;
* `authority_proof.verified_at_utc`;
* `binaries[0].download_receipt.origin`;
* `binaries[0].download_receipt.retrieved_utc`;
* `binaries[0].license`;
* `sbom.components[0].supplier`;
* `sbom.components[0].license`.

An attacker-generated Ed25519 key with synchronized binary, receipt, and outer
signatures also failed against the unchanged external anchor. A bundle-owned
`expected_context` was rejected.

## R1-R4 regression controls

All prior structural and chain attacks failed closed: missing/absolute/
traversal/case paths, root/hash/version/path drift, duplicate identities,
SBOM orphan/empty/unknown/cycle/coverage/purl/ref attacks, publisher and
subject drift, opaque/profile/signature/receipt/recipe forgery, root
status/claim manipulation, runtime-path substitution, external context and
anchor mismatch, missing or wrong frozen hashes, and missing root for signed
validation. Duplicate JSON keys and unknown fields remain rejected.

The complete matrix and raw outputs are in `raw/attack_matrix.txt` and the
other files listed by `validation_receipt.json`.

## 10-environment-capture boundary

The comparison package remains non-authoritative preparation evidence:
`machine_observation.observation_status=local_observation_only`, manifest
claim ceiling `preparation_only/screen_only`, dependency closure
`typed_absent`, binary entries `observed_not_candidate_bound`, and authority
gaps `terminal_deferred`. Local observation therefore supplies no external
authority or candidate-bound promotion evidence.

## Claim ceiling

`pass_limited` means only that the reviewed environment-provenance validator
and its negative controls are internally consistent at this snapshot. It
grants no UP1 or parent-goal credit and does not convert the 10 capture facts
into authenticated external evidence.
