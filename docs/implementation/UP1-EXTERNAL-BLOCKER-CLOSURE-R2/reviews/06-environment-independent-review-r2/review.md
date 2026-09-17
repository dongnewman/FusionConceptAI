# UP1 R2 environment provenance independent review R2

## Decision

`rework` (P1 remains). The R1 structural false-admissions are now closed,
including path containment/existence, root hash checks, version/path bindings,
duplicate identities, SBOM coverage/unknown edges/cycles, nested receipt and
recipe digest checks, root status/claim derivation, typed runtime paths and
the checked TEST_ONLY positive. However, the authority/signature layer still
accepts arbitrary opaque signature metadata and does not verify or bind the
signature cryptographically. A fully internally recomputed path substitution
therefore still reaches `present/admissible` with the unchanged opaque
signature text.

## Scope and fresh checks

Read-only review of the 06 implementation, tests, docs and the factual
10-environment-capture package. No installation or download was performed.

Fresh commands:

* `python -B -m pytest -q test/up1_external_closure_r2/environment_provenance`
  twice: `11 passed` each run.
* `python -B -m py_compile` for all focused Python files: exit 0.
* The 06 exact file set is `20/20` (excluding `__pycache__`/`.pyc`), and all
  listed byte/hash entries match.
* The 10 capture manifest has `47/47` artifact hashes matching at this audit.
* Duplicate JSON keys are rejected; validator and CLI semantic outputs are
  deterministic across fresh runs after stripping intentional PID/UTC fields.

The complete attack output is in `raw/attack_matrix.txt`.

## Findings

### F1 — P1: `signed_verified` is an unauthenticated boolean; opaque signature
metadata can be replaced

For each of `authority_proof.signed_receipt.signature`, `issuer`, `key_id`,
`trust_root` and `verification_method`, replacing the value with `attacker`
still returned `present/admissible`. The same is true for each outer authority
signature field and for a binary's opaque `signature` field. The validator
checks shape, `verified == true`, subject metadata and receipt/recipe
canonical digests, but does not verify a signature, bind the outer signature to
the signed receipt, or bind the binary signature value to any signed payload.

This defeats the authority boundary: an attacker can update path/hash,
recompute all internal subject, receipt, recipe, declaration and SBOM values,
leave the fixture's opaque signature text unchanged, and obtain
`present/admissible` (`fully_recomputed_binary_path_substitution` and
`fully_recomputed_lock_path_substitution` both reproduced this). For a
production signed closure, require an offline-verifiable cryptographic
signature/trust-root chain over the complete canonical envelope, or require a
candidate-bound externally verified receipt whose authenticated digest covers
all authority metadata and every identity. A caller-controlled `verified`
boolean is insufficient; otherwise downgrade to `typed_absent`.

### F2 — P2: SBOM component metadata and reference multiplicity remain weakly
bound

Changing a component `purl` to `pkg:evil/other@9` still returned
`present/admissible`. Duplicating a binary's `sbom_refs` entry also passed.
The validator binds component name/version/sha256 to the binary and enforces
component/edge coverage, but does not validate purl/name/version consistency
or reject duplicate references inside one binary. Enforce purl identity
syntax and consistency (or explicitly make purl a signed opaque field), and
require each `sbom_refs` list to be unique and canonical.

### F3 — P2: lock and binary path semantics can be rewritten together

When a lock path was changed to an existing unrelated repository file and its
hash plus declaration hash were recomputed, the result remained
`present/admissible`; the same fully recomputed binary path substitution also
passed. The root containment and byte-hash controls correctly stop stale or
escaping substitutions, but there is no candidate-bound external authority
that prevents a self-consistent declaration from selecting the wrong file,
and no basename/type policy for `Project.toml`/`Manifest.toml`. This is a
consequence of F1's unauthenticated receipt and should be closed by the same
authenticated candidate envelope; additionally enforce lock basename/type and
the candidate's expected artifact set where available.

## Controls that now pass

The following R1 attacks all failed closed: missing, absolute and traversal
paths; stale runtime/binary/lock hashes; runtime/binary version and path drift;
duplicate runtime/lock/binary identities; SBOM orphan, empty, unknown-edge,
cycle and uncovered-component cases; publisher/subject, receipt digest/subject
and recipe digest/subject drift; root status and claim-ceiling changes;
untyped/duplicate/case-drift runtime paths; and signed validation without a
root. The complete synthetic `test_only_positive.json` returned
`non_evidence`. Unknown fields and duplicate JSON keys remain rejected.

## 10-environment-capture boundary

The capture package remains local/preparation evidence only:

* `machine_observation.observation_status=local_observation_only`;
* `manifest.claim_ceiling=preparation_only/screen_only`;
* `dependency_closure.status=typed_absent`, `candidate_ref=null`;
* all four binary inventory entries are `observed_not_candidate_bound`;
* six authority gaps remain typed absent, including missing candidate freeze,
  import closure, external binary provenance, trust root, artifact binding and
  `NO_AUTHORITY_FROM_LOCAL_OBSERVATION`.

Its 47 raw artifact hashes were internally consistent at this run. These local
facts cannot repair F1 or promote the 06 authority proof.

## Claim ceiling

This review grants no candidate, source-authority, provider, solver,
engineering, physical, B00, B04, UP1, R or parent-goal credit. Because F1 is
P1, the requested no-P1/P2 condition for `pass_limited` is not met.
