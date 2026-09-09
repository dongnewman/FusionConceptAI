# RuntimeV4 typed 3-D discretization controls

## Decision

This isolated slice implements the remaining
`required_typed_three_d_discretization_controls` input edge. It does not modify
or enter the RuntimeV4 aggregator.

The declaration contains:

- a candidate-owned mesh identifier, mesh family, finite positive
  characteristic length, bounded radial/poloidal/toroidal resolutions, and
  bounded geometry order;
- one immutable control for every accepted oriented-interface volume, trace,
  and multiplier space, including exact polynomial and quadrature orders;
- closed nonlinear method and Jacobian policies with finite positive absolute,
  relative, and step tolerances plus bounded iterations;
- closed linear method and preconditioner policies with finite positive
  tolerance, bounded iterations, and restart length;
- a closed uniform or residual-adaptive refinement policy with finite positive
  indicator tolerance, bounded levels, and bounded refinement ratio.

## Candidate and context ownership

The declaration must occur exactly once in current G2. When the accepted
`ThreeDOrientedInterfaceDeclarationSetV4` is present, the compiler reconstructs
its region and interface references from the current typed G2 graph and
requires the discretization space IDs and orders to match every reconstructed
volume, trace, and multiplier space exactly.

`ThreeDDiscretizationControlBindingV4` is created before the forward context.
It seals the candidate identity; G2 Genome, graph, and graph-binding identities;
mesh ID; every oriented discrete-space identity; oriented declaration and
subject-binding identities; region/interface reference identities; mission;
bounds; and selected scenario. The final compiler rebuilds that binding from
the validated `ForwardChainContextV4` and requires exactly one matching
discretization binding and one matching oriented-interface binding in the
subject.

## Status semantics

The generic G2 fixture reports `recoverable_gap` for the declaration and
subject binding. The manufactured fixture alone reports `input_complete` after
the full identity reconstruction. Here `input_complete` means only that the
discretization-control input edge is complete; it is not a solver result,
provider admission, evidence record, physical pass, or complete 3-D device
input.

## Legacy-output disposition

Legacy artifacts under `outputs/fusion_concept_ai` were inspected only for
bounded control vocabulary. They carry no current RuntimeV4 authority.

| Disposition | Legacy material | Decision |
| --- | --- | --- |
| Extract | `scripts/desc_fourier_runner.py` | Re-express only its explicit spectral/grid resolution, tolerance, iteration, and continuation-control concepts as closed immutable typed values. Do not copy its backend request or result authority. |
| Wrap | none | No legacy object has the required candidate/context and oriented-space identities. This slice instead structurally binds the already accepted current `ThreeDOrientedInterfaceInputV4` declarations and binding. |
| Test-only | `scripts/desc_w7x_runner.py`, `scripts/desc_candidate_equilibrium_convergence_runner_v1.py`, and the three-level intent in `src/multiregion_conservation_providers_v116.jl` | Retain only malformed-input and future refinement/convergence-test ideas; packaged W7-X and analytic meshes are not candidate-derived inputs. |
| Reject | `scripts/run_desc_candidate_equilibrium_convergence_v1.jl`, `src/adapters/stellarator_desc_fourier_v1.jl`, and legacy dictionary/provider authority in `src/multiregion_interface_assembly_v93.jl` and `src/multiregion_conservation_providers_v116.jl` | Do not import old Genome routing, mutable dictionaries, provider execution, results, or pass/unsupported authority. |

## Authority boundary

No provider or solver is selected or executed. The slice emits no evidence and
grants no pass, promotion, P5 readiness, physical/engineering validation, or
terminal authority. Its claim ceiling is `screen_only`; credible physical-
device count remains zero.
