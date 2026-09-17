# AD-23 independent review

Verdict: `pass_limited` for architecture/schema consistency and provenance only. AD-23 remains `review_pending` / `accepted=false`; this review grants no UP2 implementation, N10 execution, B00/B04, provider, mesh, solver, engineering, physical, or R01-R10 credit.

## Evidence and bounded change

The author archive is internally reproducible. The protected before snapshot of `18_sources_and_architecture_decisions.md` is SHA-256 `fc191125bbcc72accc168a20568b13f6d2401ab9ce58e85da725fa54f08583e8` (25,913 bytes), and its current/after content is SHA-256 `30976b4d0b89e676f16f4402197200bc56c0d61e6f1a96245529c2bce94eab03` (31,055 bytes). The author bounded patch is SHA-256 `640987a0cdc85e7e4a0e2880b1c9a4c2aae67182e8a68b1ebc1160d6b276d2bf`; its expected before/after difference exit is `1`. Author `validate_plan.py` exit is `0` with `checks: pass`, 31 markdown files, 297 links, acyclic DAG, and no errors. Author scoped `git diff --check` exit is `0`.

I independently rehashed these inputs and reran only read-only documentation checks. `validate_plan.py` exit was `0`; bounded `git diff --check --no-index before after` exit was `1` with only the expected before/after difference and line-ending warnings. The historical UP2 fixture containing N10-01..05 has no working-tree diff (exit `0`), so the old rows remain byte-preserved. Input and check hashes are in `before_hashes.json`; no author file, core file, source, test, task manifest, README, or run was written by this review.

## AD-23 consistency

The appended AD-23 text at `18_sources_and_architecture_decisions.md:163-184` correctly treats the five N10 rows as provisional until a new versioned schema/fixture/hash freeze. It retains old rows and attempts, requires source-derived classification, and preserves the AD-19/AD-20/AD-21/AD-22 split: a foreign or stale value that is present and comparable is a structural `invalid_type`/`fail_closed` case; absent mapping, authority, or provenance is `terminal_deferred`. It explicitly keeps fresh receipt identity mismatch separate from stale legacy receipt coverage and preserves the full legacy evidence requirements.

The architecture text accurately records the actual A package representation. `src/Contracts/CandidateStatePackageV5.jl:159-173` stores concrete parameterized G1/G2/G3 fields, a typed `G2CandidateBindingV5`, `NamedTuple` component identity, receipt, candidate hash, and structural/resolution state. `src/GenomeV5/Integration/GenomeV5Integration.jl:80-85` projects a `GenomeContractRef` into the five-field identity tuple `(uri, version, schema_hash, canonicalization_hash, compatibility_profile)`. The G3 child projection at `:62-68` is likewise a tuple of those identities; the authoritative typed binding remains reachable through each concrete child `contract_binding.contract_ref`, including `package.g3.binding.contract_binding.contract_ref`.

The candidate and receipt claims match the code. The identity verifier at `GenomeV5Integration.jl:146-189` compares candidate ref, all three component hashes, G2 candidate binding, G1 candidate binding, G3 child refs, axes, receipt candidate ref, and `candidate_identity_after`. Integration builds the identity from actual component refs and hashes at `:323-330`, computes its identity digest, and constructs the fresh receipt with that digest at `:331-333`. The package constructor independently recomputes `candidate_hash` from package version, candidate ref, component identity, axes, and receipt at `CandidateStatePackageV5.jl:219-226`.

The classification boundary is also represented in the implementation seam. Integration rejects a supplied receipt unless it is exactly the fresh factory receipt (`GenomeV5Integration.jl:274-281`), records ref/candidate mismatches as structural errors (`:284-305`), keeps authority/provider/mapping gaps in the gap channel (`:311-321`), and makes structural errors `:fail_closed` while unresolved gaps are `terminal_deferred` (`:334-337`). The deferred migration factory requires actual `GenomeContractRef` values, rejects placeholder/pending/synthetic URI and zero digest inputs, and emits `lossless=false`, `:terminal_deferred` records with unverified provenance (`CandidateStatePackageV5.jl:128-156`). This supports the AD-23 distinction without treating a nonzero, typed V4 ref as proof of lossless migration.

## Limits and follow-up gate

The current five N10 rows remain historical provisional rows. Their existing paths include the known N10-03 mismatch (`...g3_child_refs/binding::GenomeContractRef` versus the identity tuple), and N10-02/N10-05 retain old terminal-deferred labels. AD-23 correctly requires a new schema to correct them; it does not silently promote or rewrite them. A future N10 projection still needs actual A package baseline, attempted typed value, source path/type, source-derived classification, receipt identity, and invocation counters, including constructor-rejection receipts. No such N10 implementation or execution is accepted here.

The architecture text does not shrink the parent DAG or R01-R10 obligations. It keeps UP2 total open, requires a fresh schema/hash/checker and independent review before formal B04, and explicitly excludes reused evidence and synthetic low-level inputs. The result is therefore `pass_limited`, bounded to the AD-23 decision and its before/after provenance.

## Process isolation note

No Julia/DESC command was run for this review. A post-review process check observed four Julia processes (PIDs 67836, 62896, 19284, 55912; starts 08:27:25–08:27:53) belonging to other queued work. They were not started, inspected beyond process identity, or terminated by this review. AD-23 remains a documentation-only review.
