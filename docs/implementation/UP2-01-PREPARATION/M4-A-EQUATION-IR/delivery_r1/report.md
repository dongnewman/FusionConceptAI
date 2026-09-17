# M4-A equation IR delivery R1

Status: `delivery_complete_review_pending`  
Recorder: documentation owner Luna `m4_scope_record` (`gpt-5.6-luna`, high)  
Frozen HEAD: `b2c04d8339774635aaecd73651efcdb101e01b5d`

## Delivery decision and ceiling

This record delivers the already implemented and independently executed
manufactured equation declaration slice A for review. Its claim ceiling is
`manufactured_control` / `screen_only`. It is a declaration and isolated IR
control only. It is not residual lowering, discretization, topology transfer,
coupled solving, a candidate, a provider, physical evidence, or engineering
evidence.

The delivery remains `delivery_complete_review_pending`; this documentation
record is not Sol acceptance. It does not close or credit `UP2-01`, `UP2`,
`B00`, `B04`, provider, mesh, engineering, physical, `R01-R10`, or `L4`.
Slices B (real discrete matrix/vector), C (topology transfer), and D (coupled
solve) remain unauthorized.

## Frozen inputs and ownership

The frozen implementation inputs are:

- `src/RuntimeV4/M4Isolated/ManufacturedEquationIRV1.jl` — SHA-256
  `0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57`.
- `test/RuntimeV4/M4Isolated/manufactured_equation_ir_v1_tests.jl` — SHA-256
  `654c2c06d0ab0d9a12a20c602a422b35ab84b2a9d00cda034a15beb79d558634`.
- `test/RuntimeV4/M4Isolated/oracles/equation_ir_oracle_v1.py` — SHA-256
  `0c975eabec07ff1263139636e31a36ccae27f3c437f80b8e9a667e1da329129e`.

The source implementer, test/oracle owner, independent reviewer, and
integration/documentation owner are four pairwise-distinct Luna roles. This
record is owned only by the integration/documentation recorder and does not
reassign or merge those roles. The reviewer must not review their own change
or the same change of any other role.

The source is standalone and has no imports/includes. The test loads it only
through its isolated `include` harness and imports Julia stdlib `Test` and
`SHA`. The oracle imports only Python stdlib `fractions`, `json`, `math`, and
`sys`. No shared RuntimeV4 entrypoint, registry, Project, Manifest, candidate
manifest, or shared entry file was modified.

## API, typed failures, and mathematical control

The delivered API is the isolated declaration/validation surface:
`M4UnitV1`, `M4RationalV1`, `M4DomainDeclarationV1`,
`M4ScalarFieldDeclarationV1`, `M4OperatorDeclarationV1`,
`M4DiagonalCoefficientDeclarationV1`, `M4SourceDeclarationV1`,
`M4BoundaryClosureDeclarationV1`, `M4ProvenanceDeclarationV1`,
`ManufacturedEquationIRV1`, `manufactured_equation_ir_v1`,
`manufactured_equation_payload`, `validate_manufactured_equation_ir`, and
`is_valid_manufactured_equation_ir`.

The stable typed-failure controls cover `unknown_operator`,
`unit_closure_failure`, `nonpositive_coefficient`,
`non_spd_coefficient`, `non_unique_source_owner`,
`missing_boundary_closure`, `foreign_source_reference`, and
`terminal_deferred` (time and multifield). Exceptions are not used to encode
IR gaps in the validator result.

The frozen manufactured control is

`R(u) = -div(K grad(u)) - f = 0` on `[0,1 m]^3`, with `L=1 m`,
`u=x/L+y/L+z/L`, and
`K=diag(2+0.1x/L, 3+0.05y/L, 4+z/(30L)) m^2`.

The independent fractions oracle derives
`div(K grad(u)) = 1/10 + 1/20 + 1/30 = 11/60`,
`f = -11/60`, and exact residual `-11/60 - (-11/60) = 0`; its floating
residual is `0.0` within `1e-12`. Time-dependent and multifield scopes remain
`terminal_deferred`.

## Execution evidence retained from distinct upstream owners

The integration owner executed four fresh processes strictly serially in the
order Python oracle, Python oracle, Julia test, Julia test. All exits were
zero and all stderr files were empty. The command receipts and raw paths are:

1. Python PID `66548`, `2026-09-16T06:43:06.1684674Z` to
   `2026-09-16T06:43:06.9325295Z`, receipt
   `integration_r1/command_01_python_oracle.receipt.json`, raw
   `integration_r1/raw/integration_01_python_oracle.{stdout,stderr,combined}.raw`
   and archived `integration_r1/archive/raw/` equivalents.
2. Python PID `43308`, `2026-09-16T06:43:21.7654023Z` to
   `2026-09-16T06:43:22.6235762Z`, receipt
   `integration_r1/command_02_python_oracle.receipt.json`, raw
   `integration_r1/raw/integration_02_python_oracle.{stdout,stderr,combined}.raw`
   and archived `integration_r1/archive/raw/` equivalents.
3. Julia PID `107376`, `2026-09-16T06:43:39.1295672Z` to
   `2026-09-16T06:43:42.3194345Z`, receipt
   `integration_r1/command_03_julia_tests.receipt.json`, raw
   `integration_r1/raw/integration_03_julia_tests.{stdout,stderr,combined}.raw`
   and archived `integration_r1/archive/raw/` equivalents; semantic result
   `42/42`.
4. Julia PID `6828`, `2026-09-16T06:43:58.0611013Z` to
   `2026-09-16T06:44:00.5611905Z`, receipt
   `integration_r1/command_04_julia_tests.receipt.json`, raw
   `integration_r1/raw/integration_04_julia_tests.{stdout,stderr,combined}.raw`
   and archived `integration_r1/archive/raw/` equivalents; semantic result
   `42/42`.

The two Python canonical payloads are semantically equal. Julia human timing
bytes differ, so the accepted comparison is semantic pass/total, not timing
byte identity. The earlier test wrapper metadata-capture failure remains
preserved at
`test_execution_r1/failure_history/attempt_001_metadata_capture_failure.combined.raw`;
it is a process-recording failure, not a scientific or test failure. Existing
integration/test reports and all raw/receipt histories are retained.

## Independent review gate and formal boundary

The next gate is an independent Luna review of the frozen three inputs, API,
oracle mathematics, typed negative controls, serial evidence, role separation,
and exact cleanup. The reviewer must confirm no source/test/oracle/shared-entry
mutation, no candidate/provider/physics claim, and consistency of every
receipt PID, UTC interval, exit code, input hash, output hash, and raw path.

If that review passes, only Sol may issue a separate `accepted_limited`
decision, with ceiling no higher than `manufactured_control` / `screen_only`.
That decision must still leave A declaration/IR-only and must not authorize B,
C, or D. No local A delivery substitutes for M1, external trust, fresh G1/G2/G3,
candidate identity, T0/T1/T2, aggregate, B00/B04, solver, provider, physics,
engineering, or R01-R10 gates.

Any formal re-entry remains exactly
`T0 → authority recheck → T1 → T2 → aggregate → UP2-00 → UP1-04B → UP1-04 → UP2-01`.
The 39-node dependency and all acceptance gates remain open.

