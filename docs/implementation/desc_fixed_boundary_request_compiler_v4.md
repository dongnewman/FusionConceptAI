# Runtime V4 DESC fixed-boundary request compiler

## Scope

`DESCFixedBoundaryRequestCompilerV4.jl` is an isolated, candidate-bound
translation-contract slice for the audited DESC 0.17.3 fixed-boundary schema.
It consumes only a `ForwardChainContextV4`, reconstructs the current
`ThreeDPhysicalInputCompositionV4`, validates candidate-owned DESC convention
and control declarations plus all subject bindings, and returns an exact
recoverable gap.

The current typed geometry does not supply an independently executable proof
that its physical chart has the declared DESC coordinate, Fourier-phase, and
orientation semantics. Consequently this revision cannot emit a request.
There is no public request-ready fixture and no caller-provided string, method,
artifact reference, Boolean, or hash can turn the declaration into proof.

The slice does not select a provider, serialize an input file, start a process,
run DESC, parse a result, issue a receipt, or emit evidence. It is not wired
into a core include or provider registry.

## Candidate-owned declarations

### `DESCGeometryCompatibilityV4`

`declare_desc_geometry_convention` records a proposed convention and binds it
to the exact physical declaration, physical-to-region support map, support
reference, and chart reference. It pins:

- coordinate order `(rho, theta, zeta)`;
- normalized radial domain `rho` from zero to one;
- field-period domain `zeta` from zero to `2pi/NFP`;
- radial basis `cos(m*theta - n*NFP*zeta)`;
- vertical basis `sin(m*theta - n*NFP*zeta)`;
- identity mapping from Runtime poloidal/toroidal modes to DESC `m/n`;
- ascending monic powers `rho^k` for profile coefficient index `k`;
- right-handed orientation with `e_theta x e_zeta` outward;
- SI metres for boundary coefficients.

This is a convention declaration, not a compatibility certificate.
`geometric_compatibility_proved` is compiler-fixed to `false`. The type has no
proof method or proof-artifact field.

### `DESCFixedBoundaryRequestDeclarationV4`

This declaration owns only DESC-specific settings:

| Field | Admitted range or value |
|---|---|
| `L`, `M` | integers `2..12` |
| `N` | integer `1..12` |
| `L_grid`, `M_grid`, `N_grid` | each at least its spectral value and at most `24` |
| optimizer | `desc_lsq_exact` only |
| `max_iterations` | integer `1..200` |
| `ftol`, `xtol`, `gtol` | finite `1e-12..1e-3` |
| `pressure_step`, `boundary_step` | finite `0.05..1` |
| `shaping_first` | `Bool` |
| `max_force_normalized_magnetic` | finite `1e-5..0.1` |
| `max_fixed_constraint_error` | finite `1e-15..1e-8` |
| `min_sqrt_g` | finite `0..1` |

The compiler pins runner version, model identity, source binding, and the
absence of generic-control translation. Every canonical-hash operation
revalidates the declaration's types, ranges, semantics, hash, and authority
ceiling.

## Binding and circularity boundary

`DESCFixedBoundaryRequestBindingV4` seals the request declaration and convention
declaration to the candidate, compiled prefix, G2 genome and graph, graph
binding, composition binding, every composition component declaration/binding,
mission, bounds, and scenario.

The factory receives the composition binding plus all six typed component
bindings. It reloads the six declarations from the compiled candidate, rebuilds
the composition binding from the candidate/prefix/registry/mission/bounds/
comparison/scenario tuple, and requires both its canonical hash and semantic
view to equal the supplied composition binding. A foreign component or
composition therefore cannot be hidden behind a self-consistent caller hash.

The subject binding deliberately excludes `context_hash`,
`physical_subject_hash`, and reconstructed composition `input_hash`; including
them would create a hash cycle because the binding contributes to the subject
and context hashes.

The only public compilation entry point is:

```julia
compile_desc_fixed_boundary_request(context::ForwardChainContextV4)
```

An absent convention declaration, control declaration, or request binding is
a recoverable capability gap. Duplicate request bindings are an integrity
error. A request binding without exactly one convention declaration, one
control declaration, one composition binding, and every exact upstream
component binding is an orphan integrity error, including when the upstream
composition itself is incomplete.

## Latent runner mapping

The private, validated mapping projects the following exact schema for a future
adapter:

```text
runner_version, model_id, source_binding,
boundary, profiles, resolution, solver, audit
```

Boundary mode tuple order is preserved. Each Runtime coefficient becomes
`(m=poloidal_mode, n=toroidal_mode, coefficient_m=coefficient_m)`. Pressure
and iota coefficients retain their order. The validator independently checks
the exact nested field sets, immutable tuple representation, mode uniqueness,
range and symmetry membership, positive major-radius dominance, strict
orientation, spectral coverage, 21-point profile gates, solver controls, and
audit controls.

This mapping is exercised only as a private unit. The public resolution never
contains it, and `desc_fixed_boundary_runner_payload` cannot accept a forged
dormant request.

The generic `ThreeDDiscretizationControlInputV4` identity is retained in the
dormant envelope design, but none of its mesh, finite-element, nonlinear,
linear-solver, or refinement fields is translated. The declaration states
`generic_control_translation=:none`; a future mapping requires a separately
reviewed typed contract.

## Closed validation boundary

In addition to the proof gap, the domain validator reports recoverable reasons
for field periods outside `2..8`, non-stellarator-symmetric boundaries, channel
counts outside `1..30`, modes outside `|m|,|n|<=6`, modes that DESC symmetry
would truncate, invalid R(0,0) or major-radius dominance, non-right-handed
orientation, insufficient spectral coverage, current rather than iota,
power-series lengths above 13, flux outside `1e-4..100 Wb`, pressure failures
on 21 audited radial samples, and iota outside absolute `0.02..3` on those
samples.

These are backend-capability gaps, not permanent no-solution claims. Integrity
failures throw `ArgumentError`. Neither path returns a partial request.
Resolution validation admits only the closed gap vocabulary in deterministic
order and rejects empty, unknown, duplicate, wildcarded, or reordered gaps.

## Construction and forgery resistance

The convention, controls, binding, dormant request, and resolution use inner
constructors guarded by identity against one private mutable flyweight token.
Recreating the token type does not recreate the accepted identity. Canonical
validators recompute fixed bodies and enforce the complete semantic ceiling,
so a caller that reaches internals cannot make an invalid object valid merely
by recomputing its hash. The dormant request validator always rejects because
this revision has no verified geometry-proof contract.

## Authority ceiling

Convention, controls, binding, dormant request, resolution, and manifest carry
`model_class=manufactured_input_fixture`, `claim_ceiling=screen_only`, zero
credible devices, and false provider selection/execution,
`solver_execution_attempted`, solver execution, physical validation,
engineering validation, evidence, pass, promotion, P5, and terminal authority.
`geometric_compatibility_proved=false` is explicit wherever geometry readiness
could otherwise be inferred.
