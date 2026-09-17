# T0 LocalV1 independent design review R20: nested semantic rebind

日期：2026-09-18（Asia/Shanghai）
审查类型：只读 adversarial design review；未修改产品/测试，未运行 Julia/DESC，未提交。

## Verdict

**NO-GO for implementing or crediting nested semantic rebind as currently
designed.** `_vnl_t0_semantic_rebind_candidate` at
`src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl:1068-1084`
rewrites only the top-level `candidate_ref`/`source_ref` and the G2 envelope.
It does not establish a fresh, internally self-consistent G1/G2/G3 semantic
body. A factory builder can repair some inputs, but the stale body is stored in
the rebuilt record and is subsequently used by T0 binding checks. A shallow
patch or a string/prefix ref substitution would therefore either fail later or
silently weaken the authority boundary. The current R19 runtime issue
(`source edit locator ref mismatch`) is a separate blocker and is not closed by
this design review.

The review does not grant T0/T1/T2 or R01-R10 credit; `accepted=false`,
`contract_only`, `screen_only` remain required.

## Findings by layer

### G1 source payload

`_g1d_declaration_body` contains `source_payload`, `source_hash`, `u`, `K`,
`f`, and the operator/closure/profile fields. The typed
`G1DiffusionSourcePayloadV1` requires candidate identity, one source identity,
and all three field source refs to agree; the declaration constructor also
requires payload fields to equal the declaration fields and recomputes the
source hash.

Current rebind changes the outer `candidate_ref` and `source_ref`, but leaves
`source_payload.candidate_ref`, `source_payload.source_ref`, `u.source_ref`,
`K.source_ref`, `f.source_ref`, and `source_hash` untouched. This is a concrete
stale-nested-identity path, even if the external builder reconstructs a fresh
payload for the factory call.

Required deterministic rebind:

1. Require the exact typed G1 payload and field/operator shape; do not generic-
   merge arbitrary named tuples.
2. Rebuild `u`, `K`, and `f` with the new source ref while preserving their
   typed physical content; rebuild `G1DiffusionSourcePayloadV1` with the fresh
   candidate and source refs.
3. Recompute `source_hash = g1_diffusion_source_hash_v1(payload)` and make the
   body payload, `u/K/f`, and hash mutually identical before serializing bytes.
4. Re-run the declaration-level constructor/validator. Any missing payload,
   wrong type, field mismatch, old candidate/source ref, or non-recomputable
   source evidence is typed `fail_closed`, not a best-effort rebind.

`operators`, closure/applicability/profile identities, domain, ownership and
negative controls are deterministic candidate-independent content only after
their type and field consistency has been checked. They must not be silently
rewritten merely because a candidate URI changed.

### G2 typed source and candidate envelope

The local body carries both `candidate_envelope` and typed `source`. The
envelope's `candidate_ref` is the fresh `QualifiedRefV1`, while
`G2MBSourceV1.candidate_ref` is the v5 `GenomeContractRef`; these are different
identity domains and must not be equated by URI string tricks.

Current rebind updates the envelope candidate/source ref and preserves its old
`source_hash`, but leaves `body.source.source_ref`, `body.source.source_hash`
and the typed source/declaration hashes stale. The current test builder happens
to reconstruct a source from the body, but that does not repair the stored
semantic body.

Required deterministic rebind:

- Require exact typed `G2MBSourceV1`, exact `contract_ref`, and a valid
  candidate envelope.
- Rebuild the source with the new source ref and the old typed chart, mesh,
  faces, profile, units and authority; recompute its canonical `source_hash`.
- Rebuild the envelope with fresh candidate/source refs and the rebuilt source
  hash. Recompute schema/canonicalization/profile/declaration hashes through
  `g2mb_declaration_v1`; do not carry old declaration bytes or hashes.
- Require `source.candidate_ref == contract_ref` and exact expected contract
  identity. If a contract is candidate-specific and no authoritative mapping is
  supplied, stop with typed `fail_closed`/`terminal_deferred` per the contract,
  never by replacing one URI prefix with another.

G2 `authority` and `execution_status` remain contract/deferred evidence only;
rebind must not turn `:not_executed` or synthetic source data into mesh,
provider, solver, engineering, or physical credit.

### G3 upstream authorities and feedback targets

`_g3sf_body` contains top-level candidate/source identities, typed endpoints,
law, ledger entries/closure, `feedback_targets`, and `upstream_authority`.
Each upstream authority and each target's embedded authority repeats the
candidate identity. `g3_sf_validate_v1` requires all authority candidates to
match the declaration, exact G1/G2 layer set, and exact target-authority
projection.

Current rebind updates only top-level candidate/source. It leaves
`upstream_authority[*].candidate_ref` and
`feedback_targets[*].authority.candidate_ref` bound to the old candidate. The
G3 factory builder then forwards those stale authorities into
`g3_sf_declaration_v1`, so a nested candidate mismatch is expected; blindly
retagging an authority would be worse because it could forge cross-layer
authority.

Required rebind policy:

- Preserve endpoints, law, ledger, closure, target paths/quantities/units/
  directions/signs/source_id/owner scope exactly after typed validation.
- Rebuild every non-evidence authority projection and enforce one authority per
  G1/G2 layer. A `:missing` or `:historical_absent` authority with all contract
  and source material absent may be rebound to the fresh candidate, while
  retaining its deferred status and no authority credit.
- `:stale` and `:contradictory` records must not be erased or normalized into
  `:missing`; preserve their diagnostic meaning and fail closed unless a
  separately defined, candidate-bound re-attestation exists.
- For `:actual`, candidate, contract ref/hash, source ref/bytes/hash and
  trusted receipt are evidence. They **must fail closed** on old-candidate or
  old-source identity. They may only be replaced by a new authoritative G1/G2
  result whose candidate, full contract identity, source identity, bytes/hash,
  axes and receipt are exact; then recompute
  `g3_sf_authority_content_hash_v1` and rebuild both upstream and target
  authority copies. No deterministic `candidate_ref` rewrite is allowed.
- Re-run `g3_sf_validate_v1`, including target-authority canonical equality,
  after reconstruction. Missing authority remains `terminal_deferred`; a
  contradiction or unexpected exception remains `fail_closed`.

## Cross-G1/G2 fresh-reference mapping

Fresh refs must be mapped as typed identities, not by suffix or textual prefix:

| Old edge | Fresh mapping rule | Missing/ambiguous rule |
|---|---|---|
| G1/G2 source ref | map to the corresponding new declaration's generated source ref | fail closed |
| G1/G2 declaration ref | map to the corresponding new declaration ref emitted by its fresh factory result | fail closed |
| external `VNextT0LocalFeedbackV1.target_ref` | preserve whether the old ref was source or declaration, then map to the same kind of fresh ref | fail closed; current code always chooses fresh declaration ref |
| G3 actual authority source/contract refs | map only through fresh authoritative result and exact join | fail closed; no string rewrite |
| G3 missing/historical absence | no source/contract ref exists; rebind candidate only and retain gap | terminal_deferred |

The current `fresh_feedback` path at lines 1231-1235 resolves by target layer
but always writes `fresh_declarations[target_record].declaration_ref`.
That is not a semantics-preserving map if the original feedback targeted the
old source ref. The implementation must first classify the old target as exact
old source or exact old declaration, then map the same identity kind. Foreign,
stale, duplicate, or unclassifiable refs must not be guessed.

## Required assertions and negative vectors

The implementation slice is not ready until isolated tests exercise actual
construction (not token checks) for at least:

1. G1 nested payload candidate mismatch, source mismatch in each of `u/K/f`,
   stale source hash, and payload-vs-declaration field mismatch: all
   `fail_closed`, no partial record.
2. G2 stale typed source ref, stale source hash, envelope/source hash mismatch,
   contract-domain confusion, and stale declaration/profile hashes:
   `fail_closed`, no provider/mesh/solver calls.
3. G3 old candidate in upstream authority, old candidate in a target authority,
   target authority projection mismatch, duplicate/missing G1/G2 layer, and
   source/contract evidence retagged without re-attestation: `fail_closed`.
4. G3 `:missing` and `:historical_absent` with no material: fresh candidate,
   valid typed structure, `terminal_deferred`, zero evidence credit.
5. G3 `:actual` with every field present but old candidate/source refs, and
   `:actual` with tampered contract hash: `fail_closed`; a fresh exact authority
   receipt is the only positive path.
6. Feedback records targeting old G1/G2 source refs versus declaration refs:
   each maps to the same kind; foreign/ambiguous target refs fail closed.
7. Determinism: same typed input and fresh refs yield identical semantic bytes
   and hashes; changing any source/authority evidence changes the hash.

Every negative vector must assert status/errors and absence of partial edit,
transport, authority, or evidence credit. Synthetic inputs remain
`contract_only`/`screen_only`; no runtime or physical claim is implied.

## Current evidence boundary and hashes

The review is source/test/doc read-only. Current product/test/static-QA/task
manifest hashes are recorded for provenance; the R19 report records the
separate runtime locator mismatch and remains the current runtime blocker.

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | 74966 | `efeae3112009b0e8d4b0902bb0c0da305b49bba40a919b1c4fd24b68f336ec8e` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | 53115 | `f288da66084e74739629e54d80c83c286848f50aa9ad49b6e47f05a19e602f34` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py` | 18745 | `1879616b2ce1a800c1e39f01abe8c7c321cc6a2fd8f353ccf43747a13cb4d14e` |
| `docs/v4_multitopology_generation/task_manifest.json` | 97171 | `84af082ba5fff336dd89ae506f6b8e680f96f0af2e657ae926d6e9cc666fd6ad` |
