# Spatial pickup engineering v1

This implementation consumes current-state spatial artifacts and computes the
plasma-current contribution to an external finite-aperture pickup. It does not
interpret a sampled plasma pressure as structural stress, or a prescribed ramp
as an observed or solved plasma time history. Actual execution evidence is in
the companion report; source implementation alone does not satisfy execution.

## Legacy review before implementation

| Legacy source | Decision | Reason |
| --- | --- | --- |
| `../outputs/fusion_concept_ai/scripts/desc_stellarator_finite_build_coil_runner.py`, `segment_sources` / `biot_savart_segments` | extract | Reuse the universal SI cross-product kernel and finite-distance guard. Reimplement Julia integration of current-state `J dV` and `K dA`; none of the old coil geometry, current settings or receipts are reused. |
| `../outputs/fusion_concept_ai/src/adapters/stellarator_desc_regularized_coil_force_v1.jl` | reject | Candidate-specific hashes, old routing and coil-only force evidence do not bind the new spatial plasma candidate. |
| Legacy finite-build coil adapter/proxy | reject | A pre-existing coil force does not supply this candidate's external coil system or a pressure-to-component load mapping. |
| Legacy `dynamic_fault_provider_v108.jl` | reject | Fixed growth scenarios and quench proxies do not provide actual plasma dynamics or current-state circuit excitation. |
| Current reduced `MagneticEngineeringV4.jl` | test-only reference | The prior BE energy loss motivates the exact-flow regression; its local-boundary-field projection and stepper are not used in production spatial flux or circuit propagation. |
| Analytic current-loop / manufactured current CSV fixtures | test-only | These verify SI kernels, interface signs and malformed-input rejection; the unified runner accepts only replay-validated actual physics artifacts. |

No legacy authority is wrapped. The parent builds the three Genome layers and
typed operator hypergraph. Engineering requires exactly one candidate-owned
`SpatialPickupEngineeringDeclarationV4` in G3 realization and calls
`validate_spatial_candidate_v4` before execution and replay. It does not route
by a model family name.

## Actual input and finite aperture

`SpatialCurrentInputV4` binds candidate/context/case/state/geometry hashes and
the volume, internal-interface and exterior CSV byte hashes. Physics validates
the state-to-artifact mapping before engineering admission. Engineering then
checks exact schemas and row counts, finite positive SI measures, normals,
and the independent interface relation

`K = n × (B_plus - B_minus) / mu0`.

Each current source has weight `J dV` or `K dA`, in A m. The field computation is

`B_plasma(x) = mu0/(4 pi) sum[weighted_current × (x-y) / |x-y|^3]`.

The stationary circular disk has center `(R_upper + 0.05, 0, 0) m`, normal
`(0,0,1)`, radius `0.005 m`, and `10` co-located ideal turns. `R_upper` is the
candidate-owned analytic cylindrical bound, not the greatest sampled radius.
The minimum declared-map aperture gap is `0.045 m`. Four radial Gauss points
and 32 periodic angular points integrate `N integral_disk B_plasma · n dA`.
The resulting Wb quantity is **flux linkage**, including turns.

Three geometry claims remain distinct:

1. The declaration's analytic map is separated from the ideal aperture.
2. Actual current quadrature points are checked against that enclosure, and
   their distance to the entire disk is evaluated. Source/aperture intersection
   is rejected. Failed enclosure does not move the candidate-owned pickup.
3. Continuous solved-interior enclosure is proved only when the physics-bound
   actual DESC Fourier-Zernike bound artifact is supported and its upper radius
   is no greater than the candidate bound. Otherwise that claim is unsupported.

The bound artifact and its provenance are included in the result. Neither the
disk nor its bound describes a complete winding pack, cable route, supports or
hardware exclusion envelope.

An independent transfer formulation computes the vector potential `A_unit`
of a mathematical 1-A circular test loop using 128 line quadrature points and
then `N sum(weighted_current · A_unit)/(1 A)`. This reciprocity/Stokes comparison
uses a line integral rather than the production disk field integral. It checks
the transfer on the same source quadrature; it does not establish source mesh
convergence, current closure or validation against a physical measurement.

Exterior net/absolute current and interface normal-current jumps are reported.
Missing external coil currents, outer `B_plus`/sheet current and return-current
closure stay unknown. A non-solenoidal/truncated source still yields a computable
contribution integral, but does not become a self-contained magnetostatic
engineering solution. `physical_validation=:unsupported` and
`engineering_qualified=false` remain explicit, including after a numerical pass.

## Static result and conditional circuit

The actual upstream is static. For the stationary coil, the computed static
flux linkage has `induced_emf_V=0`. Both conditional circuit runs consume this
same actual linkage as their amplitude and then apply the separately declared
10%/2-ms design ramp. The ramp is not manufactured replacement input for the
static transfer; it is an additional conditional scenario and receives no
plasma-dynamics or physical validation credit.

The lumped winding resistance and circuit are

`R_wire = resistivity (2 pi radius N)/(pi wire_radius^2)`,

`L di/dt + (R_wire + R_branch)i = -d(flux_linkage)/dt`,

`d(flux_change_estimate)/dt = -R_branch i` while the readout is connected.

For each constant-EMF interval, `s=e/R`, `tau=L/R`, and
`i(t+h)=s+(i(t)-s) exp(-h/tau)`. Analytic integrals of `i` and `i^2` give
the readout and Joule energy. Small `h/tau` series avoid cancellation; they do
not define time-stepping error. The independently checkable energy identity is
`integral(e i dt) - integral(R i^2 dt) - Delta(L i^2/2) = 0` up to roundoff.
No BE numerical-dissipation term is added to the energy balance.

The controller still samples every `10 us`; exact propagation does not alter
its declared sampling cadence. The readout short begins at `1 ms`. Threshold
crossing within an interval is an analytic diagnostic, while the actual latch
fires only on a sampled current. It commutates to a closed `100 ohm` dump path
at that sample time. A trajectory row is the right limit after propagation
through the preceding interval but before any newly latched dump commutation:
`branch_resistance_ohm` and `readout_connected` name the preceding interval,
`relay_latched` is the post-detection latch state, and `commutation_pending`
marks the one row for which the latch has fired but the dump branch is not yet
active. The initial row is separately tagged `initial_condition`.

Event records are tagged `instantaneous_commutation_left_right_limits`. They
preserve continuous inductor-current left/right values and explicitly record
branch resistance, branch voltage and readout connection on both sides. Branch voltage maxima include the immediate dump
voltage, which can exceed the following sample value. Switch arcing, diode
voltage, parasitic capacitance and actual relay timing are unsupported models.

## Parameters and scope

All component values below are explicit exploratory design specifications,
not inferred from a legacy model name, measurements or tolerance distributions.
Intervals define deterministic design bounds only.

| Parameter | Nominal | Declared interval |
| --- | ---: | --- |
| Pickup radius | 0.005 m | [0.0045, 0.0055] m |
| Center offset | 0.05 m | fixed |
| Turns | 10 | fixed |
| Wire radius | 0.0001 m | fixed |
| Resistivity | 1.72e-8 ohm m | [1.6e-8, 1.9e-8] ohm m |
| Series inductance | 0.001 H | fixed |
| Readout resistance | 10 ohm | [8, 12] ohm |
| Ramp / duration | 10% / 0.002 s | fixed conditional design scenario |
| Total circuit duration | 0.004 s | fixed |
| Sample cadence | 1e-5 s | fixed |
| Short onset / resistance | 0.001 s / 0.01 ohm | fixed fault scenario |
| Latch threshold / dump | 0.02 A / 100 ohm | fixed ideal protection design |

The fixed nominal `mu0=1.25663706127e-6 N A^-2` comes from the
[NIST 2022 CODATA table](https://physics.nist.gov/cuu/pdf/all.pdf); its metrological
uncertainty is not propagated. Constant permeability, isothermal resistivity,
co-located turns and lumped components are applicability assumptions. These
are not thermal, structural, radiation or hardware qualification models.

## API and replay

Include `SpatialExecutionTypesV4.jl` before this module in the same namespace.
The candidate declaration uses operators `SPATIAL_CURRENT_BIOT_SAVART_V4`,
`FINITE_APERTURE_FLUX_V4`, and `EXACT_PICKUP_RL_PROTECTION_V4`, with the parent
binding its canonical declaration hash in exact typed graph constants.

`execute_spatial_engineering_v4(context, physics, run_dir)` consumes all four
cases, in order: nominal coarse, nominal fine, low-flux coarse, high-flux coarse.
It writes finite-disk fields, nominal/short traces and switch-event CSVs for
each case. Per-case records carry actual state/input hashes, upstream status,
transfer metrics, static output, both conditional results and current closure.
`input_identity_valid=true` means that candidate/context/case/state/geometry
identities and artifact bytes passed validation and replay. It is deliberately
separate from `physical_upstream_valid=false`, which records that the physical
state is not qualified because convergence/closure/applicability can remain
absent. The legacy `upstream_valid` field is retained as an alias of
`physical_upstream_valid`, not the artifact-identity verdict.

`transfer_exit_code` reports finite-aperture/reciprocity execution and
`circuit_exit_code` reports both conditional circuit calculations. The retained
aggregate `solver_exit_code` is their maximum. A program exception is neither
one of these scientific/numerical exits nor a scientific failure; the unified
runner owns its separate stage-execution ledger. Failed upstream cases remain
failed engineering cases even when all engineering exits are 0. Other
unqualified cases remain unsupported.

`validate_spatial_engineering_result_v4(context, physics, result)` first calls
the full physics validator, then rereads genuine current artifacts and replays
the transfer and both circuits. It compares all computed fields, every output
CSV byte, the current source implementation hash and same-candidate identity.
It does not invoke another DESC run.

Focused entry point, from the repository root after promotion:

```powershell
julia --project=. test/runtime_v4_spatial_pickup_engineering_tests.jl
```

During staging use the identical relative path under
`runs/spatial_chain_20260912_staging/test/`. The integrating agent owns the
single execution queue, measured logs, exit artifacts and final acceptance.
