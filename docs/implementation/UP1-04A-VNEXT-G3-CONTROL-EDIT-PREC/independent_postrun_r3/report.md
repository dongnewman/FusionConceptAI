# UP1-04A-VNEXT-G3-CONTROL-EDIT-PREC independent postrun review R3

Date: 2026-09-15  
Reviewer: different Luna/high, read-only  
Scope: updated AD-32 implementation manifest, status sync R1, R9 receipt/raw
files, current source/test, and preserved R1-R9 history

## Verdict

`pass_limited`. The R2 archive metadata repair is now synchronized: the parent
implementation manifest's focused-test record matches `test_r9.receipt.json`,
and the status-sync manifest's recorded after-hash equals the independently
recomputed parent-manifest hash. R9 remains a valid `167/167` software
contract receipt, and the three R2 code findings remain closed.

This supports only a local software precursor `accepted_limited` review. It
does not accept the machine node or actual control, T0/T1/T2, provider, mesh,
engineering, physical, search, B00/B04, or R01-R10 credits. No physical or
engineering claim is made.

## R9 receipt and manifest recheck

The R9 receipt was independently rehashed and bound to the current files:

* PID `51564`; UTC
  `2026-09-15T03:32:47.1548572Z` through
  `2026-09-15T03:33:03.4679458Z`; exit `0`; summary `167/167`.
* stdout: `138` bytes,
  `6c21dbb806fc5c200ea2f11d31c2b342e8fb6ac0c40d1336c50513bcb354455f`.
* stderr: `0` bytes,
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
* exit file: `1` byte,
  `5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9`.
* Dirty rows are `310` before and after. The receipt records empty Julia and
  DESC process arrays, equivalent to zero processes.
* Receipt SHA256 is
  `21dfa6a5475402165cc01a95765f63d434a362e006e5699269db93a889da21b1`.

The current parent implementation manifest rehashes to
`1769612256e963d31baadc961f505a6d326e3b3ffe5cd4a35149957ea5a40c47`, exactly
the status-sync R1 `manifest_sha256_after`. Its focused-test PID, UTC, exit,
summary, stdout/stderr bytes and hashes, dirty counts, and zero process counts
match R9. The status-sync R1 record also binds the same receipt hash and the
same current source/test hashes. The recorded before-hash is preserved as
`ddaad62a859e43b2d153e3335970a949bbf68764e8294e8934bfcc92a79ab1f4`.

Current source and test rehashes are unchanged from R9:

* `src/GenomeV5/G3/G3ControlChildEditabilityV1.jl`: `64083` bytes,
  `54f30536c965b223797831e8bd01fdeb0a115d0073701ef0c04e84a7ab2ec0eb`.
* `test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl`: `18919` bytes,
  `5b7a85d988d50aaf25916a9da3ff4c7af764abe993cf252498e54829193c7289`.

The parent manifest and status-sync JSON parse successfully, and scoped
`git diff --check` passes. This review ran no Julia or DESC command.

## Preserved round history

The parent manifest preserves R1-R9 in order. R1-R4 remain exit-1 iterative
repair history; R5-R7 remain focused passes; R8 remains the documented
`149 passed, 18 failed, 0 errored, 0 broken` run caused by the snapshot
consumption helper bug; and R9 remains the final exit-0 `167/167` run after
the copy-safe helper repair. No historical receipt or raw output was replaced.

## R2 code findings remain closed

The source-record constructor requires all four provenance slots to share a
candidate, and payload construction compares every slot candidate to the
payload key candidate and rechecks child kind plus derived parent/child
identity (`src/GenomeV5/G3/G3ControlChildEditabilityV1.jl:286-417`). The
foreign-provenance test rebuilds the record hash and still requires rejection
(`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:111-123`).

The replacement path freezes source ID, owner scope, signal ports, controllers
and plan, requires one changed fault, and compares fault ID, target ID, safe
action, detection signal and deadline. Only mode may change
(`src/GenomeV5/G3/G3ControlChildEditabilityV1.jl:1001-1018`). The test keeps
the individual and combined carried-field negatives, plus zero, delete,
rebind and multi-fault negatives
(`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:241-269`).

State construction validates the previous-state chain and operation hashes,
recomputes current state, and requires the terminal resulting hash to equal
that current hash (`src/GenomeV5/G3/G3ControlChildEditabilityV1.jl:487-517`).
The forged nonzero terminal-result case remains rejected
(`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:277-290`).

The failure helper still hashes `String(copy(before_bytes))` and checks status,
object identity, canonical bytes, SHA, history identity, last-operation hash
and current-state hash (`test/GenomeV5/G3/g3_control_child_editability_v1_tests.jl:56-70`).

## Boundary decision

The implementation manifest remains `review_pending`, with machine node
`planned`, `proposal`, and `accepted=false`; this independent result does not
promote that node. The local software contract may proceed as
`accepted_limited` after the parent records this independent pass. All higher
authority, actual-child, physical, engineering, provider/mesh, search and
R01-R10 states remain false.
