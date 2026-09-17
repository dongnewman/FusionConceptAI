# M5 inverse-feedback delivery R1

## Status and boundary

This package records `review_pending` for the isolated manufactured
inverse-realization and engineering-feedback fixture. The claim ceiling is
`manufactured_inverse_engineering_feedback/screen_only`. It is not UP4-01 or
UP4-02 and grants no B07, B08, R, engineering, physical, provider, solver,
candidate, or formal credit.

The fixture consumes the frozen M4-D coupled-control and M5-A
auto-composition outputs as read-only manufactured inputs. No source, test,
oracle, shared entry, registry, Project, Manifest, candidate, provider,
solver, or evidence-authority artifact was changed by the delivery record.

## Frozen inputs and exact results

Current M5 source/test/oracle hashes are respectively
`70b01aed3cde22a54ec0b24e121c52874662214f06c1a38b6ddc18546cc7ac68`,
`7e636254ef5b82ef05d9ba90dc23303933cffef2008ce202e0944972573f4a26`, and
`6e13536aabb62f039bffe6c286e11323347b86b4d3c146270f38e8bf8129d0ab`.
The frozen M4-D hashes are source
`ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785`, test
`1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686`, oracle
`9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`; M5-A
source `e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a`,
test `42562f02370f8f2e32c8e0254e0f480d69e598be747aae9898c3fc4d013b2a08`,
oracle `e9f13fc57a59efa78dd131dfc3fde7433c21d6172dc2d81f03c034c4be13084c`.

The independent Fraction oracle and typed Julia test agree on target
`(2/3,1/3)`, exact recovery `(alpha,beta)=(2,1)`, determinant `3`,
eigenvalues `(1,3)`, margin proxy `1/3`, round-trip residual `(0,0)`, and
multi-seed order `[0,1,2]`. Deleting beta/interface feedback changes the
response to `(1/2,0)`, with delta `(1/6,1/3)`. The canonical oracle payload
hash is `0664f4a8d794c32046168f7890ee4b54f48e9b2caa8a3066c5670eb3c38a31a8`
and the reversed/seed-normalized payload is byte-equal.

## Test and integration receipts

The isolated test package reports `103/103`. Its historical Python PID 105644
started `2026-09-16T11:57:22.1588701Z`, exited 0 at
`2026-09-16T11:57:22.7825224Z`, raw stdout SHA
`183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647`; Julia
PID 23916 exited 0 at `2026-09-16T11:58:07.5843986Z`, raw stdout SHA
`40aa3aa98ec9f062446f895725b5420831ff7d7a01ff51f23c06111cd420e745`.
Both stderr hashes are the empty-stream SHA
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; raw
paths are retained under `../test_execution_r1/archive/raw/`.

The authoritative integration order is Python×2 then Julia×2, strictly
serial: Python PID 52240 started `2026-09-16T12:08:41.4849091Z`, ended
`2026-09-16T12:08:55.5795690Z`, exit 0, stdout/combined SHA
`183b4eec66a36292d4ca14cc4904bd7b4d93f8ccf5905d83cdf0a2d960200647`; Python
PID 75964 started `2026-09-16T12:09:08.0766084Z`, ended
`2026-09-16T12:09:21.7675504Z`, exit 0, same SHA; Julia PID 78816 started
`2026-09-16T12:09:33.3118020Z`, ended `2026-09-16T12:10:02.6483075Z`, exit 0,
103/103, stdout/combined SHA
`e6a5297f999ab0928e006c5dc40430d5eadd3b3846a9c71d3ae1f6b4fd421d17`; Julia
PID 101292 started `2026-09-16T12:10:13.0103435Z`, ended
`2026-09-16T12:10:44.9687006Z`, exit 0, 103/103, stdout/combined SHA
`d8cadcc4cee2c98f2e4cfd3c0e241d3183fba2d86dd960fc49e98836643cc424`.
All four stderr streams have the empty-stream SHA above. Exact raw and
process receipts remain under `../integration_r1/replay_1/archive/raw/` and
`../integration_r1/replay_2/archive/raw/`; Julia raw hashes differ only due
to duration text while semantics agree.

Initial wrong-sequence/pre-capture attempts remain non-authoritative: Python
PIDs 96228, 46736, 11240; Julia PIDs 56012 (capture timeout, no observed
exit/raw), 53876, and 52820. The integration setup failures and all raw
copies remain in the existing integration archive. They are not promoted or
counted.

## Typed controls and next review

Negative controls cover invalid upstream, foreign hash/owner/provenance,
zero/non-identifiable/zero-denominator/singular/non-SPD/impossible targets,
round-trip corruption, seed mismatch, and deletion-no-effect. No optimizer or
real reference is used. A review must independently verify frozen hashes,
serial order, exact Fraction agreement, the feedback deletion delta, typed
failure routing, raw/process receipts, and all prohibited-scope guards before
any Sol/root acceptance decision.

