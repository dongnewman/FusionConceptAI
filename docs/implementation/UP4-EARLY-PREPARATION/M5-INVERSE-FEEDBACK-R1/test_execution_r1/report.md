# M5 inverse-feedback R1 test execution

Status: pass (103/103 Julia tests). The execution lane is isolated and serial: the independent
Python `Fraction` oracle runs first, followed only after a zero exit by the
Julia M4-isolated test. Raw stdout/stderr, command metadata, hashes, and any
failure are retained under `archive/raw/`.

Claim ceiling: `manufactured_inverse_feedback/screen_only`. This execution is
not UP4-01 or UP4-02 and grants no formal, candidate, provider, solver,
physical, or engineering evidence credit.

The Python process exited 0 at 2026-09-16T11:57:22.7825224Z (PID 105644),
then Julia exited 0 at 2026-09-16T11:58:07.5843986Z (PID 23916). The exact
Fraction oracle records target `(2/3,1/3)`, recovered `(alpha,beta)=(2,1)`,
determinant `3`, eigenvalues `(1,3)`, margin `1/3`, exact zero roundtrip,
deletion response `(1/2,0)`, and feedback delta `(1/6,1/3)`. The typed
negative controls include invalid upstream, foreign hash/owner/provenance,
zero/non-identifiable/zero-denominator/singular/non-SPD/impossible targets,
roundtrip corruption, seed mismatch, and deletion-no-effect.

See `execution_summary.json` and `validation_receipt.json` for command,
working-directory, PID, UTC, exit-code, raw-output hashes, input hashes, and
the explicit no-formal-credit boundary. Failure artifacts remain preserved by
the cleanup inventory.
