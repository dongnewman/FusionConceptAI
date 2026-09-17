# Independent review r1: UP2-00C N10 identity and receipt

Verdict: pass_limited for the actual-A, candidate-bound, contract-only identity and receipt projection. The author archive remains review_pending and accepted=false. No B00/B04, provider, mesh, engineering, physical, or R01-R10 credit is granted.

## Runtime evidence

The independent pre-run snapshot recorded zero Julia and zero DESC processes. Exactly one synchronous focused command was run:

    julia --startup-file=no --project=. test/GenomeV5/UP2/run_n10_identity_receipt.jl

Runner PID 18116 started at 2026-09-14T09:03:29.9232236+08:00 and ended at 2026-09-14T09:05:48.3677782+08:00, with real exit 0. Independent stdout is 4296 bytes and reports actual-A identity/receipt 80/80 and foreign candidate/receipt controls 7/7. Stderr is zero bytes. The exit artifact records 0 and post_processes.json is []. No Julia or DESC process remains.

## Actual-A source and identity

The N10 checker validates a structurally valid CandidateStatePackageV5, deferred A resolution, claim ceiling none, concrete G1/G2/G3 types, candidate-bound G2 ref and hash, v5 outer refs, typed G3 binding child, exact five-field identity projections, candidate-specific G2 URI, receipt candidate, package hash recomputation, and fresh receipt identity-after recomputation.

The five source fields are the G1 schema hash, G2 canonicalization hash, typed G3 binding child ref compared with component_identity.g3_child_refs.binding, package candidate_hash compared with canonical recomputation, and fresh migration receipt candidate_identity_after compared with identity and axes recomputation.

The focused test constructs actual A from versioned G1/G2/G3 fixture constructors. It checks package hash 67bf32d7d55b06eac1f495a50fcb1620babd48d9ebbce14867f854f32b3064a5 and receipt-after identity 31f3390f62193e274b781c5e61d15ffd7c6097e5fab160000f36af47106542b0. The same G2 plan is reused across two candidates, but each gets a different public ref, component hash, and package hash; cross-candidate G2 reuse is rejected.

## Mutation and legacy boundary

N10-01 and N10-02 use foreign hashes, N10-03 uses the actual sibling control child ref, N10-04 uses a synthetic attempted candidate hash, and N10-05 uses a fresh receipt identity-after attempt. The validator checks exact source metadata, rejects nonzero invocation counters, derives mismatches from authoritative values or package recomputation, and does not read expected_error. The forged N10-04 oracle control still returns invalid_type.

Fresh A has no V4 legacy records, so legacy provenance remains terminal_deferred. The low-level projection constructor is not independent A provenance and is not B04-admissible. No provider, solver, mesh, engineering, physical, B04, or R01-R10 conclusion follows.

Only this independent review directory was written. Retain the author archive as review_pending and accept only this bounded N10 identity and receipt contract slice.
