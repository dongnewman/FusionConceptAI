# AD-40 RepositoryDesignSourceAuthorityV1 independent review R1

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Verdict: `changes_requested`

## Scope

This review independently checks the AD-40 architecture proposal and its
machine manifest against the current v4 README, the common contract, the
orchestration and work-order contracts, AD-30/33/34/36/37/39, the current G1
and G2 declaration sources, the parent-binding and T0 authority-recheck
sources, and the existing AD-40 raw receipts. The reviewed proposal,
manifest, cleanup inventory and historical receipts were not modified.

The observed repository HEAD is
`4b69f55f7f80240147a65a22809dc1207824dde2`, matching the AD-40 manifest. The
worktree remains dirty with pre-existing or concurrent changes; the review
did not touch them. The current plan validator reported 31 markdown files,
485 relative links and 39 acyclic tasks with exit `0` (PID `78328`).

## Architecture finding

The proposed repository design source authority is architecturally coherent
within a software-only ceiling. It separates `schema_factory_source`,
`candidate_declaration_payload` and `software_source_receipt`; binds the
future record to repository HEAD, relative path, exact bytes, schema,
canonicalization, applicability, public contract, candidate binding and four
provenance axes; and requires a separate factory/declaration receipt and
fresh identity review. The proposal explicitly forbids fixture, synthetic,
legacy and historical-receipt reuse and requires a source change to create a
new candidate identity and rebuild affected upstream receipts.

The distinction is supported by the current source. G1 and G2 expose typed
payload/declaration/factory APIs, but the only current constructor call sites
outside their definitions are synthetic or focused-test paths. The only
matching `SourceBackedV1DeclarationReceiptV1(...)` and
`PresentParentBaselineBindingV1(...)` occurrences are private type
constructors. AD-37/AD-39 therefore remain correct that no fresh,
candidate-bound source-backed G1/G2 declaration is currently present. A
future repository-owned canonical payload can be a software design-source
authority only after the proposed authoring, exact-byte record, candidate
binding, four-axis, factory, identity-review and AD-37 publication gates
produce fresh receipts.

The ceiling is correctly limited to
`authority_class=repository_design_source` and
`software_source_provenance_only`. The proposal does not substitute this
authority for external reference truth, experiment, provider, mesh, solver,
engineering, manufacturing, physical or R01–R10 evidence. It also keeps
`present`, T0, T1, T2, provider, mesh, solver, engineering, physical and
R01–R10 false, creates no candidate hash and creates no machine node.

## Work-order and source checks

All seven future work orders have exact product paths, inputs, outputs, a
three-way result union, dependencies, forbidden edges, exit gates, cleanup
and AD-36 sidecar boundaries. The local six-edge graph is acyclic. The G1 and
G2 payload authoring orders are sibling-parallel; authority records depend on
both payload orders; binding/provenance precedes factory receipts, fresh
identity review and then the AD-37 publication input. Future product paths do
not exist in the checkout. No AD-40 product path escaped the proposed
directory, and the current four observed source artifact byte counts and
SHA-256 values all match the manifest:

| source role | bytes | SHA-256 prefix |
|---|---:|---|
| G1 schema/factory source | 31743 | `14d26ee556029bd1f...` |
| G2 schema/factory source | 30773 | `261516671151647b...` |
| parent-binding source | 26420 | `feaa25406350f76c...` |
| authority-recheck source | 14684 | `e942e3553b1a5f78...` |

The direct source audit found no current non-definition construction of a
source-backed present receipt. No Julia, DESC, provider, mesh, solver or
physical command was run by this review.

## Required repair

AD-40 cannot yet be accepted even as an `accepted_limited` architecture
record because its own validation evidence is not closed under AD-35. The
existing `archive/validation_receipt_r2.json` points to the raw validation
stdout and stderr files and records PID/UTC/exit, but it omits:

- SHA-256 for stdout, stderr and the combined raw stream;
- explicit input hashes and output/artifact hashes for the validation;
- a machine-readable mapping that the recorded hashes equal the referenced
  bytes.

The raw files are present, and the review independently computed their
current values (`validation_final_stdout.txt`: 1161 bytes,
`d91e97690f82661fa4d7c9f47c416413f9fb7c890ca3ae5950a9683a767e33a8`;
`validation_stderr.txt`: 1 byte,
`01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`).
This is an evidence-receipt defect, not evidence that the architecture or
the source hashes are wrong. The implementer must add an append-only AD-40
receipt repair containing those raw hashes, combined-stream hash, frozen
input hashes, product/output hashes, command/cwd/PID/UTC/exit and a final
scoped recheck. The prior failure and R2 receipts must remain untouched.

After that repair, a different Luna should rerun the receipt-closure and
scope checks. The repaired record may then be eligible for `pass_limited`
for architecture and finite work-order scope only. It must not dispatch
payload authoring, create a candidate identity or promote present/T0/T1/T2,
provider, mesh, solver, physical or R01–R10 credit by itself.

## Review boundary and cleanup

This review created only its own `independent_review_r1/` report, manifest
and validation sidecar. No source, test, fixture, launcher, core document,
task manifest, candidate payload, candidate hash, machine node or runtime
artifact was created. No existing AD-40 file, historical failure receipt,
dirty file or unrelated process artifact was removed or rewritten.

