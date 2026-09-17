# UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC independent postrun review R2

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Scope: AD-32 control implementation R8/R9 and preserved receipts

## Verdict

`changes_requested`. The R8/R9 source and focused-test slice closes the three
R1 source findings and the R9 receipt is a valid `167/167` software-contract
run. The implementation archive is not internally synchronized: its
`manifest.json.focused_test` points to `test_r9.receipt.json` and carries the
R9 stdout/stderr hashes, but its PID, UTC interval, dirty-row counts and
process metadata are still from an earlier R7 record. The archive must be
repaired before independent acceptance can be recorded.

This review supports only a local software precursor after that archive repair.
Machine-node acceptance, actual control, source-backed T1, realization,
binding, feedback, T0/T1/T2, provider, mesh, engineering, physical, search,
B00/B04 and R01-R10 credits remain false.

## R8 failure and R9 receipt binding

The preserved R8 receipt is real and remains immutable:

* PID `46780`, UTC `2026-09-15T03:30:40.7140500Z` through
  `2026-09-15T03:30:58.9388129Z`, exit `1`.
* stdout: `24976` bytes,
  `fc60b39ec9563abe64f46f4fce52ee9e463e0758d7ea93385fbd19ca8e9c7dbc`.
* stderr: `212` bytes,
  `59b7fd7bebd3485c80c931d166245896f7a183723c4dfa1f24742792372b4e86`.
* exit file: `1` byte,
  `6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b`.
* The raw stderr classifies `149 passed, 18 failed, 0 errored, 0 broken`;
  the repeated failures are the failure helper's byte comparison after
  `String(::Vector{UInt8})` consumed the captured vector.
* R8 dirty rows were `310` before and after; Julia and DESC process snapshots
  were empty.

The preserved R9 receipt is internally consistent and points at the current
source/test inputs:

* PID `51564`, UTC `2026-09-15T03:32:47.1548572Z` through
  `2026-09-15T03:33:03.4679458Z`, exit `0`, summary `167/167`.
* stdout: `138` bytes,
  `6c21dbb806fc5c200ea2f11d31c2b342e8fb6ac0c40d1336c50513bcb354455f`;
  stderr: `0` bytes,
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
* exit file: `1` byte,
  `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`.
* Dirty rows were `310` before and after; Julia and DESC process snapshots
  were empty.
* R9 input hashes include source
  `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb`, test
  `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289`,
  realization sibling
  `01bdfd40f1a824b8530fc51f6ff319e40dda4edbce275c62276e5431f78f25bf`,
  feedback `70b045dd3a1fcbfc60f58e0b742c296507343ffc3736aaefd8c2a40e212750d0`,
  AD-32 manifest
  `c160c6fe95cc427a2eb260f932ac88ec4661ed146b3593dac12b8fa9beec867e`,
  old ControlGenomeV5
  `eb0c672d6d7146fef03a12038240c101e64e2949ddfddb48eb983d92fb7c7135`, and
  Project.toml
  `923b78938e12c27e836b269d71a539ae7bb292c9fe9f8cb92f9f9a8cea1370e2`.

The current files independently rehash to source bytes `64083` and the source
hash above, and test bytes `18919` and the test hash above. The frozen sibling,
feedback, old V5 and AD-32 manifest hashes also match. Scoped `git diff --check`
passes. No Julia or DESC command was run by this review.

## R1 blocker closure

The current source closes the candidate/provenance and identity gap. The
`G3ControlSourceRecordV1` constructor requires all four slots to have the same
candidate, and `G3ControlSourcePayloadV1` checks every slot candidate against
`key.candidate_ref`, enforces the control child kind, and rechecks derived
candidate, parent declaration/hash and child contract identity bindings
(`src/GenomeV5/G3/G3ControlChildEditabilityV1.jl:286-407`). The test rebuilds a
foreign record and its record hash and requires payload construction to reject
it (`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:111-123`).

The replacement path freezes source ID, owner scope, signal ports, controllers
and plan, then requires exactly one changed fault. It checks fault ID and mode,
and explicitly compares target ID, safe action, detection signal and deadline
to the prior fault (`src/GenomeV5/G3/G3ControlChildEditabilityV1.jl:1001-1023`).
The test exercises each carried field separately and in combination, plus
rebind, delete, zero-mode and multi-fault cases
(`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:241-269`).

The state constructor now validates every operation's key, previous-state
chain, operation hash, source refs and nonzero resulting hash, recomputes the
current state hash, and requires the terminal record's resulting hash to equal
that recomputed value (`src/GenomeV5/G3/G3ControlChildEditabilityV1.jl:487-517`).
The forged nonzero terminal-result case is explicitly rejected by the test
(`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:277-290`). The
resulting hash is calculated after the operation hash while the state recipe
uses operation hashes, so this remains acyclic.

The R9 helper uses `String(copy(before_bytes))` before invoking the failure
path, preserving the R8 historical failure and avoiding mutation of the bytes
being compared (`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:56-70`).
For each covered negative, it checks status, original object identity,
canonical bytes, SHA, history identity, last-operation hash and current-state
hash. The covered negative set includes stale state/source, duplicate, foreign
key/parent/child, forged record, dynamic body, multi-fault, zero/insert/delete,
rebind, all four carried fields plus the combined case, and typed absence.

## Blocking archive inconsistency

`docs/implementation/UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC/manifest.json` has
`focused_test.final_receipt = test_r9.receipt.json`, R9 exit/stdout/stderr
hashes and `167/167`, but still records PID `65740`, the UTC interval
`03:14:35.8149106Z`–`03:14:47.9238389Z`, dirty rows `4343` to `4346`, and
scalar process counts. The bound R9 receipt records PID `51564`, the
`03:32:47.1548572Z`–`03:33:03.4679458Z` interval, dirty rows `310` to `310`,
and empty process arrays. This is a concrete receipt-to-manifest mismatch,
not a physical or source-contract finding.

Minimal repair: update only the implementation archive's focused-test
execution metadata to the R9 receipt (including PID, UTC, dirty rows and
process snapshots), revalidate the JSON and archive diff, then perform a fresh
independent status sync. Preserve all R1-R9 receipts and the R8 failure.

## Boundary decision

Until that metadata repair is independently rechecked, the result is
`changes_requested`. After repair, the source/test evidence is sufficient for
`accepted_limited` local control software precursor review only. It does not
provide actual child population, control authority, T0/T1/T2 completion,
provider/mesh/engineering evidence, physical realization or search evidence.
