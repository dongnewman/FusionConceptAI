# UP2-01-G3-SOURCE-FEEDBACK-V1 repair R3

Status: `proposal`; `review_pending=true`; `accepted=false`; claim ceiling: `contract_only`.

R2 required removal of the public `fault_seam` keyword from `g3_sf_admit_v1`, while preserving a controlled internal classification path. The public admission method now accepts only the declaration value and routes through `_g3sf_admit_core_v1`. The unexported `_g3sf_admit_fault_seam_v1` helper is the only focused-test seam for an injected internal fault and returns `program_exception`; ordinary typed contradictions and hash tamper remain `fail_closed`. The focused test also asserts that a public keyword call raises `MethodError`.

The efficiency edit test now evaluates the edited declaration at 120 W and independently checks field=105 W, return=0 W, heat=15 W, all four declared ledger coefficients (`source=1`, `field=-7/8`, `return=0`, `heat=-1/8`), energy residual=0, and ledger residual=0. The declaration hash must change after the edit.

Authority handling remains bounded: bare `actual` is `fail_closed` with `unattested_authority`; a caller-supplied trusted-looking receipt remains `terminal_deferred` behind the same-candidate `VNEXT` gate. Missing external authority remains `terminal_deferred`. No historical A/H0 receipt is rebound and no G1/G2 authority is claimed.

## R2 before hashes

- `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl`: `70be33201ed053223a3b4ccf80e90ee6338a4db47bc933212861ba415a953a00`
- `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json`: `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40`
- `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl`: `e9302fa2aaeff261c8d0a442468a9497541c0956051a59499c1ba40fabdeeefa`
- `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py`: `d1dfc51ba0c82ae5f7a7e35bff304926a29024e33fb6a9a72bdf88cb49cbd11a`

## R3 after hashes

- `src/GenomeV5/G3/G3SourceFeedbackLawV1.jl`: `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0`
- `test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json`: `7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40`
- `test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl`: `37a66fcee910b123183df0f6c8eec568f617e5702b6e62875a4d7e6f4d5c5838`
- `docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py`: `ff1ae5e48c83f6240a38ed1c16f39c24d141572d63e8544447313e59cb5f01f0`

## Static QA receipt

Command: `D:\Users\Newman\anaconda3\python.exe docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py`

Exit code: `0`. JSON parsing, exact synthetic closure, typed relation presence, declaration tamper gate, public fault-seam rejection, internal fault seam coverage, efficiency closure coverage, authority gates, candidate ownership, and manifest hashes all passed. Julia/DESC/compiler/provider/mesh/solver were not run; all execution counters remain zero and no physical evidence or R01-R10 credit is granted.

This R3 package is ready for a different Luna static independent precheck. It remains pending review and is not accepted.
