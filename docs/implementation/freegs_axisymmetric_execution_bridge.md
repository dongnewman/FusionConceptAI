# Runtime V4 candidate-bound FreeGS axisymmetric execution bridge

## Scope and authority

This isolated bridge executes one narrow physical model: a static,
axisymmetric, free-boundary Grad--Shafranov equilibrium using the pinned local
FreeGS environment. It is a `screen_only` physical-model execution. It is not
physical validation, numerical V&V, engineering qualification, integrated
whole-device closure, P5 evidence, or terminal candidate authority.

The bridge does not modify `FusionRuntimeV4.jl`, the closure aggregators, the
accepted conservative multi-region module, or any historical artifact. FreeGS
does not supply the current multi-region contract's 3-D constitutive and
interface operators, so this implementation does not invent a conversion into
that contract. The new edge is instead:

```text
current G2 fields: AxisymmetricEquilibriumDeclarationV4
      + current compiled G2 graph identity
      + frozen mission / bounds / scenario
                         |
                         v
subject.bindings: AxisymmetricEquilibriumBindingV4
                         |
          external ForwardChainContextV4 revalidation
                         |
                         v
canonical JSON -> pinned Python -> controlled FreeGS runner
                         |
                         v
physical_model_screen | recoverable_gap_unknown
```

## Typed ownership boundary

`AxisymmetricEquilibriumDeclarationV4` is stored in the current
`FieldGeometryGenomeV4.fields` tuple. Its nested values are typed, immutable
domain, filament-coil, `ConstrainPaxisIp` profile, shape-constraint, and solver
records. There is no caller-provided `physical=true` field and no arbitrary
dictionary in the Julia core.

`make_axisymmetric_equilibrium_binding` accepts only a declaration that occurs
exactly once in the current candidate's G2 fields. It seals:

- the current G2 Genome hash;
- the canonical G2 graph hash and the forward graph binding hash;
- the current mission and bounds hashes;
- the selected frozen scenario hash; and
- the typed declaration hash.

The resulting `AxisymmetricEquilibriumBindingV4` must occur exactly once in
`ForwardChainContextV4.subject.bindings`. Every public input, execution, and
receipt-validation function first calls `validate_forward_chain_context`; the
bridge then recomputes all binding identities from that context. A NamedTuple,
dictionary, duplicate binding, foreign G2 declaration, graph substitution, or
mission/bounds/scenario drift is rejected before process execution.

## Process and evidence capture

The interpreter is fixed to:

```text
D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Scripts\python.exe
```

The controlled script is the repository-owned absolute path resolved from
`scripts/runtime_v4_freegs_axisymmetric_runner.py`. Julia writes the exact
canonical JSON input, launches the fixed command without a shell, captures
stdout, stderr, and exit code, and hashes the interpreter, runner code, exact
input bytes, exact output bytes, backend semantic input, backend result, and
environment manifest. The controlled runner emits the SHA-256 of the exact
output bytes it wrote on its stdout summary line. Julia recomputes that digest
from the file it actually read and refuses `physical_model_screen` unless they
are equal. The environment manifest includes Python executable and file hash
plus Python, FreeGS, freeqdsk, NumPy, SciPy, and platform versions.

The Python boundary rejects missing or extra JSON keys. Dependency and solver
exceptions emit `recoverable_gap_unknown`, retain a diagnostic output, and do
not become `unsupported`, physical failure, or pruning evidence. A successful
receipt requires process exit 0, controlled output status
`physical_model_screen`, finite typed metrics, exact context/binding echoes,
an exact stdout-to-output byte-hash match, and a second external receipt
validation against the current files and context.

Artifacts are written under
`runs/runtime_v4_freegs_axisymmetric_current_fixture_v1/` by the integration
script. The fixture is current and self-consistent, but manufactured. It does
not reuse any historical candidate result or result hash.

## Legacy classification

| Legacy item under `outputs/fusion_concept_ai` | Classification | Current use |
|---|---|---|
| `scripts/freegs_runner.py` | `extract` | FreeGS call sequence, strict bounded-input checks, and independent finite-difference residual were reimplemented behind current typed ownership. |
| `scripts/freegs_candidate_equilibrium_convergence_runner_v1.py` | `test-only` | Three-grid metric intent informed negative/acceptance coverage; no old result enters current evidence. |
| `scripts/run_freegs_candidate_equilibrium_convergence_v1.jl` | `reject` | It loads an old Genome, constructs mutable dictionaries, and binds historical source/result artifacts. |
| `src/runtime_equilibrium_evidence.jl` | `reject` | Its old sidecars and C2-support authority do not cross into Runtime V4. |
| `docs/freegs_fidelity1.md` and equilibrium schemas | `test-only` | Supported FreeGS subset and claim-boundary vocabulary only; old IDs, authority, and outputs are not imported. |

## Files and commands

- `src/RuntimeV4/FreeGSAxisymmetricExecution.jl`: typed declaration, binding,
  canonical ABI, execution, receipt, and external validation.
- `scripts/runtime_v4_freegs_axisymmetric_runner.py`: controlled process.
- `examples/runtime_v4_freegs_axisymmetric_execution.jl`: current G2/subject
  fixture.
- `scripts/run_v4_freegs_axisymmetric_execution.jl`: real integration run.
- `test/runtime_v4_freegs_axisymmetric_execution_tests.jl`: ownership,
  negative, and real pinned-execution checks.

```powershell
julia --startup-file=no --project=. examples/runtime_v4_freegs_axisymmetric_execution.jl
julia --startup-file=no --project=. test/runtime_v4_freegs_axisymmetric_execution_tests.jl
julia --startup-file=no --project=. scripts/run_v4_freegs_axisymmetric_execution.jl
```
