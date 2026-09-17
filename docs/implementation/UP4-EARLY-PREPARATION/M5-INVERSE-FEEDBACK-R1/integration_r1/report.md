# M5 inverse-feedback integration R1

This integration lane is `pass_limited` for the isolated manufactured fixture.
The current source/test/oracle bytes were frozen and rehashed as
`70b01aed…ac68`, `7e636254…f4a26`, and `6e13536a…9d0ab`. No source, test,
oracle, shared entry, registry, Project, Manifest, candidate, provider, solver,
or evidence artifact was changed.

Four fresh child processes ran strictly serially from
`D:\\006-Programing\\LMC\\FusionConceptAI`: Python oracle twice, then Julia
current tests twice. Both Python runs exited 0 with identical 2,174-byte raw
stdout and combined hash `183b4eec…0647`. Both Julia runs exited 0 and reported
`103/103`; duration-dependent raw hashes differ (`e6a5297f…21d17` and
`d8cadcc4…cc424`) while stderr was empty. Every live raw stream has an exact
copy under the corresponding `archive/raw/` directory.

The independent Fraction oracle and typed Julia test agree on target
`(2/3,1/3)`, recovered `(alpha,beta)=(2,1)`, determinant `3`, eigenvalues
`(1,3)`, margin proxy `1/3`, round-trip residual `(0,0)`, deletion response
`(1/2,0)`, and feedback delta `(1/6,1/3)`. The oracle payload hash was
recomputed as `0664f4a8…31a8`; reversing and then seed-normalizing the
multi-seed list reproduced the same bytes/hash. Seeds `0,1,2` are explicit.

Typed negative controls cover invalid upstream, foreign hash/owner/provenance,
zero/non-identifiable/zero-denominator/singular/non-SPD/impossible targets,
round-trip corruption, seed mismatch, and deletion-no-effect. Static boundary
checks show no optimizer, real-reference, candidate, provider, solver, or
engineering evidence path. The evidence ceiling is exactly
`manufactured_inverse_engineering_feedback/screen_only`; this is not UP4-01,
UP4-02, or formal UP4 credit.

The prior `../test_execution_r1/` package was audited and retained. It contains
three historical Python receipts and two historical Julia receipts, all pass
receipts, but no `failed_attempts` directory and no multi-process capture files.
Those historical records are classified as read-only context and are not
promoted into this integration's authority. M4-D repaired hashes and M5-A
integration hashes are recorded as read-only upstream context in the manifest.

During setup, three Python and three Julia pre-capture/wrong-sequence attempts
were also observed (PIDs `96228`, `46736`, `11240`, `56012`, `53876`, `52820`).
PID `56012` had a wrapper capture timeout with no observed exit/raw; the other
wrong-sequence Julia attempts observed 103/103. All six are explicitly
non-authoritative. Only the final captured Python×2 then Julia×2 sequence is
authoritative.
