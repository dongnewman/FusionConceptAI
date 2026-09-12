# Revised execution contract v1

Frozen by the integrating agent before parallel implementation, 2026-09-12.
Starting HEAD: `4d5afdb`. Existing dirty files are protected by the audit in
`runs/revised_chain_20260912_audit`. No Julia/DESC run was active at audit time;
the preceding same-candidate runner has explicit exit 0 and is complete only
for the partial computations described in its report.

## Identity and ownership

The new candidate retains the parent geometry but owns new G1 laws, G2 physical and G3
engineering/scenario declarations. A proposal records the parent candidate hash,
changed declarations and exploratory provenance. Every semantic change requires
a new candidate/context hash and fresh affected upstream execution. No receipt
from the parent may be attached. The parent's G1 identity fixture is replaced by
static MHD stress, pickup, Faraday/RL, protection and ideal active-branch current
continuity laws. The current-continuity invariant describes the series junction;
it does not prove global plasma conservation. The ideal observable applies only
to connected readout. Its exploratory effect threshold and ideal zero noise
floor are not measured noise or a numerical-error estimate.

Each declaration is an immutable typed object with `semantic_view`; parameters
carry name, nominal value, SI unit, interval, source and applicability. Design
assumptions are labeled exploratory, never measured data. Operators are selected
by explicit declarations and typed graphs, without changing the default registry.
Exact-type operators receive the declaration hash through an `ASTConstantV1`
typed payload input; their parameter schema stays rule-derived and empty.
Admission rebuilds the entire expected graph, including node wiring and roles.

## Main integration reuse audit

Legacy checkout reviewed at `32e8e7121c8d21be36aac183d0eb89429d075c19`.
`src/whole_device_provider_dag_v107.jl`: extract explicit stage dependencies;
reject request-index artifact lookup, fixed old model routing and evidence ranks.
Current `ForwardChainContext.jl` and DESC geometry/proof/provider: wrap their exact
candidate revalidation and rebuild requests for the new identity. The previous
`CandidateEndToEndV4.jl` is test-only historical coverage; its fixed unexecuted
stage vocabulary cannot describe this execution. Old G1 identity-only fixture:
reject as the new candidate's physical law declaration. Each branch records its
separate numerical reuse audit in its implementation document.

Shared API (loaded into the existing forward-context module):

* `multiregion_declaration_v4()` -> immutable G2 declaration.
* `engineering_declaration_v4()` -> immutable G3 declaration.
* `validation_declaration_v4()` -> immutable uncertainty/verification declaration.
* `execute_multiregion_v4(context, upstream::NamedTuple, run_dir; kwargs...)`.
* `execute_engineering_v4(context, physics, run_dir; kwargs...)`.
* `execute_verification_uq_v4(context, upstream, physics, engineering, run_dir; kwargs...)`.

`upstream` has fields `bridge`, `geometry`, `proof`, `request`, `result`, `probe`;
all are rebuilt for the new context. The result includes the actual bound DESC
HDF5 receipt. Branch result types must expose `candidate_hash`, `context_hash`,
`status`, `executed`, `solver_exit_code`, `result_hash`, and a `semantic_view`.
Branch validators must bind declarations and actual input bytes, not merely hash
caller assertions. Physical output and its validity must both enter engineering;
verification/UQ consumes these same concrete outputs. Agent-owned detailed APIs
are communicated before use; main owns the frozen integration boundary.

## Files and execution queue

* Main: this contract, `RevisedCandidateV4.jl`, revised candidate example,
  `RevisedWholeDeviceV4.jl`, unified runner, integration tests, overall report/index.
* Physics: `CompleteMultiRegionV4.jl`, `scripts/complete_multiregion_desc_sample.py`,
  focused tests and `complete_multiregion_v4` implementation/report documents.
* Engineering: `MagneticEngineeringV4.jl`, focused tests and
  `magnetic_engineering_v4` implementation/report documents.
* Verification: `ExecutedVerificationUQV4.jl`, independent Python oracle if needed,
  focused tests and `executed_verification_uq_v4` implementation/report documents.

All branches review relevant legacy `outputs/fusion_concept_ai` code BEFORE
implementation and record extract/wrap/test-only/reject with reasons. Branches
may use manufactured inputs for unit tests only. Main serializes ALL heavy
Julia/DESC runs. Agents do not launch provider runs or commit/stage shared files.
Main integrates only reviewed paths, then commits and pushes the milestone.

## Acceptance

Execute every volume/source/exterior/interface term of the explicitly declared
finite-dimensional model, all state Jacobian columns, an actual nonlinear state
update attempt and global source/boundary/volume conservation ledger. Exact
surface evaluations, not finite-offset samples, enter boundary terms. Record
DOFs/test spaces, initial and final states, iteration norms, stopping reason and
numeric exit code. A failed reduced solve is valid execution, not equilibrium.

Execute one physical engineering subsystem consuming real upstream fields and
declared geometry/parameters; distinguish imposed scenario inputs from measured
time histories and plasma stress from material stress. Preserve upstream failure
and applicability limits. Execute independent numerical checks and bounded
parameter sensitivity/propagation without invented probability distributions.
Report quadrature, discretization, solver and model residuals separately.
Physical validation remains unsupported without applicable independent data.

The unified stage record separates declaration, implementation, execution,
measured result, status, exit code, upstream validity and remaining conditions.
Artifacts include source/environment/input/output hashes and commands. Whole
device assessment grants no physical validation, P5 or credible-device credit.

## Resume and final audit

The runner refuses nonempty fresh-run directories. An explicit resume first
compares the complete saved candidate identity bytes, then validates the
upstream receipt and any available physical/engineering/verification checkpoint.
It preserves a rejected run's identity file and existing serialized checkpoints.
Engineering admission requires the exact ordered declared nominal and short
scenarios; duplicate or missing cases cannot stand in for fault execution.

For downstream hardening, r3 imports only the same-revision r2 candidate,
upstream and physics records; `resume_origin.json` records source/destination
hashes. The upstream HDF5 and nominal failed state remain the actual inputs.
Changed engineering/verification source forces their new execution. The manifest
records actual executable/arguments/cwd, all four checkpoint reuse flags, origin
hash, complete receipt paths, external engineering field inputs and raw physics
dependencies, with duplicate-path hash conflicts rejected. The Python byte
auditor also checks the recorded parent manifest and both ends of copied files.

The separate Decimal/box-face audit diagnoses arithmetic cancellation and the
constraint-versus-algorithm residual gap. It cannot replace the production state
or grant physical validation. Compact delivery evidence is generated only after
the unified runner, independent audits and every queued regression have explicit
terminal exit codes. Scope and failed scientific gates remain in that evidence.
