# T0 authority recheck R22 limited runtime acceptance

## Receipt and boundary

This document records the limited runtime result of the R22 local profile. The
source receipt is the append-only run directory:

`../local_profile_r22_preflight/run_20260918_150219_852_24a21155b88549b1a17acf75fefc8948/`

The child command was run once with `JULIA_NUM_THREADS=1` and the 300 second
wrapper budget. The wrapper acquired the new profile lock, did not retry, and
left the durable receipt and lock in place. This is a runtime integrity record,
not a declaration of formal authority or UP1 completion.

## Observed runtime facts

| Item | Observed result |
|---|---|
| Wrapper/run status | `runtime_complete` |
| Julia exit code | `0` |
| Julia test summary | `310` passed / `310` total, `4m22.6s` |
| Recorded duration | `266669.1015 ms` (reported as `266669 ms`) |
| Runtime negative dispatch | `25` |
| Protected files | `74/74` comparable and unchanged; `owned_hash_changes={}` |
| Retry/start policy | `startCount=1`, `autoRetry=false`, no retry |
| Process observations | preflight `[]`; first postflight `[]`; second postflight `[]` |
| Postflight Julia/DESC state | zero processes after the consecutive checks |
| Captured stderr | empty; `failure=null`; no timeout or kill record |

The Julia stdout also reports:

```text
UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_STATUS=local_checked_present_or_typed_absent
UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_ACCEPTED=false
UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_T1_T2_CREDIT=false
UP1_04A_VNEXT_T0_AUTHORITY_RECHECK_LOCAL_NEGATIVE_DISPATCH=25
```

## Claim ceiling

The R22 package remains:

- `accepted=false`;
- `T1_T2_CREDIT=false`; and
- `claim_ceiling=contract_only`.

The run supports limited local receipt integrity and runtime observation only.
It does not grant formal T0 authority, T1/T2 credit, provider evidence, mesh
or solver evidence, physical or engineering validation, or search credit. The
25 negative dispatches are runtime-observed dispatches; they are not evidence
that all pending negative classes have been covered.

The phrase “100 snapshots” must not be presented as a runtime count. It is only
a static derivation of 25 negative dispatches multiplied by four expected
receipt objects per call. The receipt contains the before snapshot and two
postflight snapshots at the process-wrapper level, but no independent runtime
counter proving 100 snapshots.

## Remaining gates

The next evidence required is a separately reviewed T1 focused runtime, then T2
identity rebinding/integration and independent two-process replay. The current
R22 result must not be used to close those gates or to bypass the preserved
typed-absence/authority boundaries.
