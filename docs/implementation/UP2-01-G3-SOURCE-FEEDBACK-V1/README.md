# UP2-01-G3-SOURCE-FEEDBACK-V1

This directory records the first contract-only G3 source and feedback preparation slice.
The implementation is additive and candidate-owned. It defines typed source, field,
return, heat, ledger, and feedback target declarations, exact rational evaluation, and
content-hash-preserving edits.

The current fixture deliberately has no real external G1/G2 authority. Its admission is
therefore `proposal`, `accepted=false`, `resolution=terminal_deferred`, and
`claim_ceiling=contract_only`. A structural contradiction is `fail_closed`; an
unexpected exception is kept as `program_exception` in the admission API.

The historical actual-A/H0 receipts remain read-only context. This slice does not bind
them into the declaration and does not change old G3, G1/G2, UP2 H0/E1/E2, shared
entries, runs, or evidence. A future VNEXT step must create a fresh candidate identity,
rebuild G1/G2 refs and hashes, and pass the same-candidate authority gate before any
execution work.

## Files

- `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl`: typed law, authority, feedback, evaluator, admission, and edit API.
- `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json`: candidate-owned numeric fixture.
- `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl`: focused contract tests (not run in this slice).
- `static_qa.py`: explicit Python static/JSON/hash checker; it does not invoke Julia or DESC.
- `evidence_manifest.json`: content hashes and classification receipt.

## Integration request

UP1-04A-VNEXT must provide a fresh same-candidate G1 and G2 public ref/hash pair for
each feedback target and the source law. The shared entry must compare candidate ref,
layer ref, four axes, source ID, law hash, endpoint units/directions/signs, and authority
status. This request is recorded only; this slice does not edit the shared entry.

