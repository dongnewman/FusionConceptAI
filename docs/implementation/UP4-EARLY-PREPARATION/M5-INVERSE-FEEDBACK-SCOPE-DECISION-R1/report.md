# M5 inverse realization and engineering feedback scope decision R1

## Decision

Sol/root authorizes one isolated manufactured inverse-realization plus
engineering-feedback fixture. Status is `authorized_not_started`; claim
ceiling is `manufactured_inverse_feedback/screen_only`. This is not UP4-01 or
UP4-02 and grants no B07, B08, R, UP2, provider, solver, physical,
engineering, candidate, or parent credit.

The fixture may consume frozen outputs from accepted-limited M4-D coupled
solve control and M5-A auto-composition. It must remain a manufactured,
screen-only control and may cite existing G3 typed feedback/edit scaffolds as
references only; those scaffolds must not be modified or treated as provider
or engineering evidence.

## Frozen inverse contract

The forward family is

`A(α,β) = [[α,-β],[-β,α]]`, `rhs = [1,0]`, with hidden
`α=2`, `β=1`, target `(2/3,1/3)`. The inverse fixture must recover α and β
exactly as `Rational` values from the target, validate `α > |β| > 0`,
`det(A)=3`, and record the eigen/margin proxy `(1,3)`. The round-trip
residual must be exactly zero and multiple seeds must produce deterministic
identical outputs. No floating approximation may silently widen this contract.

Engineering feedback negative control: deleting β/interface feedback must
change the recovered/forward control to `(1/2,0)` and the response must
change. Singular, non-identifiable, impossible-target, foreign-hash,
foreign-owner, and foreign-provenance inputs must produce typed failures.
Failure is not a physical or engineering claim.

## Frozen inputs and ownership

The input bundle is the accepted M4-D/M5-A evidence, not a source-authority
or provider assertion. M4-D source SHA is
`ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785`, test
SHA `1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686`, and
oracle SHA `9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3`.
M5-A source SHA is
`e6262a11ca47f527dfa67f08974febfd69a0334e1c64baeec7657249f0e1945a`, test
SHA `42562f02370f8f2e32c8e0254e0f480d69e598be747aae9898c3fc4d013b2a08`,
and oracle SHA
`e9f13fc57a59efa78dd131dfc3fde7433c21d6172dc2d81f03c034c4be13084c`.
Any changed input requires a new freeze and independent review; unchanged
input must not cause repeated S3 or a new AD.

Suggested future ownership is source
`src/RuntimeV4/M4Isolated/ManufacturedInverseFeedbackV1.jl`, test
`test/RuntimeV4/M4Isolated/manufactured_inverse_feedback_v1_tests.jl`, oracle
`test/RuntimeV4/M4Isolated/oracles/inverse_feedback_oracle_v1.py`, and
evidence `docs/implementation/UP4-EARLY-PREPARATION/M5-INVERSE-FEEDBACK-R1/`.
The implementation, test/oracle, integration, documentation, and independent
review owners must be five pairwise-distinct Luna roles.

## Prohibitions and re-entry

Do not modify `task_manifest`, the 39-node graph, `default_operator_registry`,
shared entry, `Project.toml`, `Manifest.toml`, or the referenced G3
scaffolds. Do not construct a provider, run a production/PDE solver, perform
candidate generation, or publish physical/engineering evidence. Heavy
recomputation is serial and must retain raw stdout/stderr, PID, UTC, exit,
input/output/artifact hashes, and failures.

Formal re-entry remains exactly:
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
Fresh G1/G2/G3, candidate identity, and solver-input receipts are required;
this scope decision cannot close any formal gate.

Decision authority is `Sol/root`; recorder is Luna `m4_scope_record`, model
`gpt-5.6-luna`, effort `high`. No Julia, Python, or solver is run for this
record.

