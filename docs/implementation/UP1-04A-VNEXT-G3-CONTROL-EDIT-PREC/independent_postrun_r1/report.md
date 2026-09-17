# UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC independent postrun review R1

Date: 2026-09-15  
Repository: `D:\\006-Programing\\LMC\\FusionConceptAI`  
Reviewer: different `gpt-5.6-luna` / high  
Mode: read-only static and receipt review; no Julia/DESC run

## Verdict

`changes_requested`. The final R7 focused receipt is internally valid and
reports 51/51 passing software assertions, but the implementation does not
yet satisfy the frozen AD-32 contract. Three source-level gaps remain. The
local software precursor therefore cannot be independently accepted yet. If
repaired and independently rerun, its maximum scope remains
`accepted_limited` local control software only; the machine node, actual
control child, source-backed T1 mapping, T0/T1/T2, provider, mesh,
engineering, physical, search, B00/B04 and R01-R10 remain false.

## Receipt integrity and round binding

All seven receipt JSON files parse. For every round, the recorded stdout and
stderr byte counts and SHA-256 values match the raw files. The final R7
receipt is:

- PID `65740`, UTC `2026-09-15T03:14:35.8149106Z` to
  `2026-09-15T03:14:47.9238389Z`, exit `0`;
- stdout 136 bytes, SHA256
  `842f14ca09374053fb2491f459154c003ad5783ed216f653408053c32d267c8f`;
- stderr 0 bytes, SHA256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`;
- focused summary: 51 passed, 0 failed, 0 errored, 0 broken;
- dirty rows 4343 before and 4346 after; Julia and DESC process counts were
  zero before and after.

The preserved run history classifies R1--R3 as loader/setup failures, R4 as
32 passed / 13 failed / 3 errored, and R5--R7 as passing focused contract
runs (48/48, 48/48 and 51/51). R5, R6 and R7 are bound separately: R5 used
the pre-R6 source/test pair recorded by `repair_r5`; R6 used the repaired
source with the unchanged R5 test; R7 kept the R6 source and used the
strengthened final test. Only R7 is a candidate for a final software review;
R1--R6 remain immutable history.

The final implementation manifest's frozen source-feedback, old
`ControlGenomeV5`, realization sibling and AD-32 manifest hashes all match
the current files. The final source hash is
`7a11562caf25e138e6e8ae0adac79d4e384577c936e8fb7f29dcb8c8256b4882`; the
final test hash is
`aa34bcb8fef7211d071d8f2b3a23fd193e6d0081ecf1908cc3fafa679f794fb9`.

## Blocking source findings

1. **Provenance slots are not bound to the payload candidate.**
   `G3ControlSourceRecordV1` checks that its four slots agree with each other
   (`src/GenomeV5/G3/G3ControlChildEditabilityV1.jl:304-315`), but
   `G3ControlSourcePayloadV1` does not check that those slots' `candidate_ref`
   equals `payload.key.candidate_ref` (`:385-403`).
   `g3_control_admit_source_v1` can therefore accept a source record whose
   four typed provenance slots belong to another candidate, provided its
   record and content hashes are recomputed. This violates candidate-bound
   provenance and is not covered by the R7 test. The minimal repair is a
   source/payload admission check for all four slot candidates, plus a
   foreign-provenance negative and a typed-absence candidate mismatch case.

2. **The edit is not limited to `fault.mode`.**
   The replacement path freezes source ID, owner scope, signal ports,
   controllers and plan, then requires one changed fault and checks only its
   `fault_id` and new `mode` (`:975-996`). It does not compare the changed
   fault's `target_id`, `safe_action`, `detection_signal_id` or `deadline` to
   the prior fault. A replacement can therefore change `mode` and one of
   those other fields while passing `_g3ce_validate_body` and being applied.
   This contradicts the old `g3_edit_fault` mode-only behavior and the R7
   proposal. The minimal repair is to require the changed fault to equal the
   prior fault in every field except `mode` (or rebuild through the existing
   mode-only helper), with a negative covering each immutable field class.

3. **A forged operation result hash is not closed.**
   `G3ControlStateV1` checks the history previous-state chain and only rejects
   a zero `record.resulting_state_hash` (`:473-501`). The current-state recipe
   hashes only the operation-hash tuple (`_g3ce_history_hashes` and
   `_g3ce_state_hash`, `:764-775`); it never requires the last record's
   `resulting_state_hash` to equal `current_state_hash` or to equal the
   canonical state reached by that record. A nonzero forged result hash can
   therefore survive construction when the remaining fields are made
   internally consistent. The minimal repair is a closed equality check for
   the terminal result hash and explicit negative coverage for forged and
   non-adjacent result hashes, while retaining the non-recursive hash recipe.

## Evidence gaps and boundaries

The implementation's failure helper returns the original state object and the
exception path also returns the original state, which is consistent with
failure atomicity. However, the R7 test captures canonical bytes for the
stale-state path only; it does not capture bytes and SHA equality for each
foreign, forged, stale-source, dynamic, multi-fault, duplicate and ordering
negative. The next focused test must add those assertions before the local
precursor can be accepted.

The static review confirms a closed typed body, candidate/parent/child key,
derived parent binding and source-record/payload refs, four typed provenance
slots, immutable source fields, separate contract/physical axes, empty/first/
second operation transitions, global operation-ID checks, stale/foreign/
forged/dynamic/multi-fault controls, typed absence and internal
`program_exception` containment. These positives do not waive the three
blocking findings above.

The AD-32 architecture boundary remains `accepted_limited`; the implementation
node remains `planned` / `proposal` / `accepted=false` /
`review_pending`. Old control/V5/package/registry paths, core planning files,
T0 authority and all historical receipts were read-only in this review.
