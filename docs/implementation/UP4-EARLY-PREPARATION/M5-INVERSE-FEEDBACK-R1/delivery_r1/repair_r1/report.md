# M5 inverse-feedback delivery repair R1

## Current state

P1 repair closure is recorded as `review_pending` under the existing delivery
contract. The claim ceiling remains
`manufactured_inverse_engineering_feedback/screen_only`; formal credit is
`none`. The repaired source SHA is
`f0dcf8aa0dc199a4e3404ecec1a4f516b899e1cfd523454d698f9afe91553976` and the
repaired test SHA is
`f2279400356a786c83a13ad3f82400af052e64f5bbc8ceefbf0e8119e6903ea2`. The
oracle is unchanged at
`6e13536aabb62f039bffe6c286e11323347b86b4d3c146270f38e8bf8129d0ab`.

The repair closes the P1 nested M4-D/M5-A snapshot and corruption-validation
coverage: stored derived fields, nested source/hash/identity/owner/provenance,
joint owner/provenance, and composition-hash mutations are typed failures
without exceptions. The authoritative Julia test result is `203/203`.

## Authoritative replay

The repaired integration ran strictly serially in the order Python oracle ×2,
then Julia tests ×2. Python PID 70992 started
`2026-09-16T12:48:13.1760814Z`, ended `2026-09-16T12:48:25.7488467Z`, exit 0,
stdout/combined SHA
`183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647`. Python
PID 28660 started `2026-09-16T12:48:35.9870982Z`, ended
`2026-09-16T12:48:51.4672691Z`, exit 0, same SHA. Julia PID 111376 started
`2026-09-16T12:49:03.6382942Z`, ended `2026-09-16T12:50:02.8854109Z`, exit 0,
`203/203`, stdout/combined SHA
`efe652a328d1a5e56f1df629d6e5a038075639bf8b60005ec3cf17440e16a96d`.
Julia PID 52692 started `2026-09-16T12:50:14.2425776Z`, ended
`2026-09-16T12:51:46.9577061Z`, exit 0, `203/203`, stdout/combined SHA
`b0202162fd5b9a35bf0c3f093a0152e0c452f8e6e0794381f55edce62d654299`.
All authoritative stderr streams are empty with SHA
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
Exact raw/process records remain in the existing integration repair archive.

The independent probe PID 38880 started
`2026-09-16T12:56:34.6590614Z`, ended `2026-09-16T12:57:26.4966378Z`, exit 0,
and reported 25/25 typed failures with zero exceptions. Its stdout SHA is
`6a36aa87312847a3d8a152d8b078b41550f4a8223ddbcdc28ac3fee660888892`; stderr
is the empty-stream SHA above. It independently recomputed the M5-A
composition hash
`722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694`.

## Preserved history and boundaries

The earlier `103/103` record, wrong-sequence and timeout attempts, and probe
setup failures (including PIDs 84444 and 84684) remain preserved as
non-authoritative history. No prior failure is deleted or upgraded. Shared
entry, default registry, Project/Manifest, source/test/oracle ownership, and
all formal evidence boundaries remain unchanged. This repair does not close
UP4-01/02, B07, B08, R, engineering, physical, provider, solver, candidate,
or parent credit.

Recorder is Luna `m4_scope_record`; implementation, test/oracle, integration,
documentation, and independent review remain distinct roles. No Julia,
Python, or solver was run for this documentation package.

