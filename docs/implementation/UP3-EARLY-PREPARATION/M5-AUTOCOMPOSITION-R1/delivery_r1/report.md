# M5-A auto-composition delivery R1

## Delivery status

This document package records `delivery_complete_review_pending` for the
isolated manufactured auto-composition fixture. The claim ceiling is
`manufactured_auto_composition/screen_only`. It is not UP3-01 and grants no
formal credit. No candidate, provider, production solver, physical,
engineering, or evidence-authority claim is made.

The delivered fixture composes the accepted-limited M4 A–D controls into the
existing canonical IR/graph concepts. The integration evidence recomputed a
`TypedASTProgramV1` with 8 nodes, roots `(5,6,7,8)`, and input ports
`(1,2,3)`, plus a `TypedOperatorHypergraphV1` with 7 nodes and 4 edges in
`M5-A,M5-B,M5-C,M5-D` order. It preserves 4 stage identities, 7 typed ports,
and 3 owner/interface joins. The independent Python oracle produced equal
canonical and permutation-normalized hash
`a0823a76ddac17bd193a03c8ed86945d06c4637649611f248a53383dd0d6f6fe`.

## Frozen inputs and ownership

The frozen source SHA-256 values are: M5 source
`e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a`; A
`0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57`; B
`0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c`; C
`20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa`; D
`ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785`.
The current M5 test is `42562f02370f8f2e32c8e0254e0f480d69e598be747aae9898c3fc4d013b2a08`,
oracle `e9f13fc57a59efa78dd131dfc3fde7433c21d6172dc2d81f03c034c4be13084c`;
retained D test/oracle inputs are
`1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686` and
`9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`.

The source, test/oracle, integration, documentation, and independent-review
owners are pairwise-distinct Luna roles. Existing shared entry and default
operator registry were not changed.

## Test and integration evidence

R1/R2 test receipts remain preserved with process-time fields
`not_recorded`; they are not upgraded. The authoritative R3 replay was
strictly serial, Python oracle first then Julia: Python PID 100208, started
`2026-09-16T10:47:31.6812383Z`, exit 0, ended
`2026-09-16T10:47:31.7545334Z`, canonical stdout/combined SHA
`bd23dd1e0b5ec3254cee7cfc6e15efebde553c85f3a01876205b3175a32e4ae7`, stderr
empty SHA `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`;
Julia PID 93044, started `2026-09-16T10:47:31.7865318Z`, exit 0, ended
`2026-09-16T10:48:13.1727911Z`, 110/110, stdout/combined SHA
`981f815fd93797e3ae34c05b487283ae0352259a7036e6de11929bd408216699`, empty
stderr SHA as above. Raw paths are retained in the existing `repair_r3/archive/raw/`.

The authoritative integration replay was also strictly serial and ran
Python/Julia twice. Python PID 46816 started
`2026-09-16T10:56:18.7241353Z`, ended `2026-09-16T10:56:18.8594020Z`, exit 0,
stdout/combined SHA `bd23dd1e0b5ec3254cee7cfc6e15efebde553c85f3a01876205b3175a32e4ae7`;
Julia PID 107252 started `2026-09-16T11:00:21.3018648Z`, ended
`2026-09-16T11:01:06.4333251Z`, exit 0, 110/110, stdout/combined SHA
`cbf324207aa25e8b6c7051b28755bb76f434dab89ce3f5c6c7e0828931aac1b3`.
Python PID 43256 started `2026-09-16T11:01:35.9995702Z`, ended
`2026-09-16T11:01:36.1071669Z`, exit 0, same Python SHA; Julia PID 110680
started `2026-09-16T11:01:57.0403693Z`, ended
`2026-09-16T11:02:34.6230229Z`, exit 0, 110/110, stdout/combined SHA
`9c734d04bc6c0db45a801046654313a38035c33ea2b5c147331d6603ffc39ae4`.
All integration stderr streams are empty with SHA
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; exact
raw and process metadata remain under `integration_r1/replay_1` and
`replay_2`. Julia duration differences explain differing raw hashes; semantic
110/110 agrees.

R3 wrapper-only failures (`attempt1_wrapper_failure`,
`attempt2_exitcode_failure`, `attempt3_taskoutput_failure`) and two
non-authoritative integration setup failures (direct Python wrapper variable
PID assignment and direct Julia wait timeout) remain archived and excluded
from authoritative counts.

## Boundaries and next review

Provider dropout is `terminal_deferred` with no provider constructed. Negative
typed controls cover invalid A/B/C/D, foreign input/hash/identity,
unit/rank/port/domain/owner/interface mismatch, missing capability, and
label/order mismatch. The fixture does not modify `task_manifest`, the
39-node graph, `default_operator_registry`, shared entry, `Project.toml`, or
`Manifest.toml`, and does not close UP3-01, UP2, B00, B04, R01–R10, L4, or the
parent goal. Re-entry requires the full fresh formal route and authority
checks; this delivery is not a substitute for those gates.

