"""Focused Julia runner for the DCCE V1 contract and actual-source fixtures.

Running this file executes the focused Julia tests, using the shared
thermal-slab actual-source fixture. The complete thermal suite remains in
thermal_slab_actual_source_focused_test.jl for its separate full consumer run. It does not start DESC or claim physical
validation; the companion Python static QA and independent oracle are separate.
"""

using Test, LinearAlgebra, Serialization, SHA
using FusionConceptAI

const _DCCE_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _DCCE = FusionConceptAI
_DCCE.load_genome_v5_components!()
# Register the source declaration types before loading their typed consumers.
# This idempotent loader performs no historical T2 admission or Git evidence run.
_DCCE.load_vnext_t2_components_v2!()
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredG123DiffusionExecutionV1.jl"))
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredSpatialCompositionExecutionV1.jl"))
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredDiffusionCompileExecuteV1.jl"))
include(joinpath(_DCCE_ROOT, "test", "RuntimeV4", "DeclaredG123DiffusionExecution",
    "fixture.jl"))
include(joinpath(@__DIR__, "thermal_slab_actual_source_fixture.jl"))

const _DCCE_ACTUAL_INPUT_ARTIFACT = get(ENV, "UP2_DCCE_ACTUAL_INPUT_JLS", "")
const _DCCE_ACTUAL_INPUT_PIN_PATHS = (
    "design_identity.json", "g1_source.jl", "g2_source.jl",
    "g3_child_design_source.jl", "g3_source.jl", "identity.jl",
    "manifest.json", "native_mms_source_expressions.json", "scenario.json")

function _dcce_actual_input_source_pins(candidate_directory=_THERMAL_SLAB_CANDIDATE_DIR)
    root = joinpath(_DCCE_ROOT, candidate_directory)
    Tuple((path=relative, sha256=bytes2hex(SHA.sha256(read(joinpath(root, relative)))))
        for relative in _DCCE_ACTUAL_INPUT_PIN_PATHS)
end

function _dcce_actual_input(; transient=false)
    candidate_directory = if transient
        variant = _thermal_materialize_source_variant_v1(_DCCE_ROOT,
            _THERMAL_SLAB_CANDIDATE_DIR, :up2_01_transient_si)
        variant.candidate_directory
    else
        _THERMAL_SLAB_CANDIDATE_DIR
    end
    source_pins = _dcce_actual_input_source_pins(candidate_directory)
    save_artifact = transient && !isempty(_DCCE_ACTUAL_INPUT_ARTIFACT)
    if save_artifact &&
            isfile(_DCCE_ACTUAL_INPUT_ARTIFACT)
        payload = open(Serialization.deserialize, _DCCE_ACTUAL_INPUT_ARTIFACT)
        payload.schema === "dcce-actual-input-v1" ||
            throw(ArgumentError("saved DCCE fixture schema mismatch"))
        payload.source_pins == source_pins ||
            throw(ArgumentError("saved DCCE fixture source pins changed"))
        a = payload.actual_input
        a.candidate isa _DCCE.QualifiedRefV1 &&
            a.g1 isa _DCCE.G1DiffusionDeclarationV1 ||
            throw(ArgumentError("saved DCCE fixture types do not match the loaded namespaces"))
        println("DCCE_ACTUAL_INPUT_REUSED path=$(_DCCE_ACTUAL_INPUT_ARTIFACT) pins=valid")
        flush(stdout)
        return a
    end
    actual = _thermal_source_case(candidate_directory)
    base = actual.spatial
    edges = base.new_geometry.edges
    old_geometry = _DCCE.DeclaredSpatialGeometryV1("focused-old-two-cell",
        (edges[1], (edges[1] + edges[end]) / 2, edges[end]))
    spatial_case = _DCCE.DeclaredSpatialCaseV1(old_geometry,
        base.new_geometry, [0.25, 0.75], base.field, base.boundary,
        base.composition; case_ref="focused-current-source-two-old-cells")
    a = (candidate=actual.built.candidate_ref, g1=actual.built.g1.declaration,
        g2=actual.built.g2.declaration, g3=actual.built.g3.declaration,
        bundle=actual.t0.transport, spatial_case=spatial_case)
    if save_artifact
        mkpath(dirname(abspath(_DCCE_ACTUAL_INPUT_ARTIFACT)))
        open(_DCCE_ACTUAL_INPUT_ARTIFACT, "w") do io
            Serialization.serialize(io, (schema="dcce-actual-input-v1",
                source_pins=source_pins, actual_input=a))
        end
        println("DCCE_ACTUAL_INPUT_SAVED path=$(_DCCE_ACTUAL_INPUT_ARTIFACT) pins=valid")
        flush(stdout)
    end
    a
end

function _dcce_composition_with_payloads(composition; source=nothing, boundary=nothing)
    components = map(composition.components) do component
        ports = map(component.ports) do port
            payload = port.account == "source" ? source :
                port.account == "boundary" ? boundary : nothing
            payload === nothing && return port
            _DCCE.DeclaredSpatialPortV1(port.port_ref, port.direction,
                port.quantity, port.unit, port.account; role=port.role,
                ledger_sign=port.ledger_sign, payload=payload,
                magnitude=port.magnitude)
        end
        _DCCE.DeclaredSpatialComponentV1(component.component_ref, ports)
    end
    _DCCE.DeclaredSpatialCompositionV1(components; plan_ref=composition.plan_ref)
end

function _dcce_time_mass(a)
    capacity = a.g1.source_payload.transient_capacity
    _DCCE.DeclaredSpatialTimeMassV1(capacity.coefficient, capacity.units,
        a.g1.source_ref; closed=capacity.closed)
end

@testset "DCCE V1 compile, lower, compose, and execute" begin
    a = _dcce_actual_input()
    out = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, a.spatial_case)
    @test out.claim_ceiling === :screen_only
    @test out.accepted === false
    @test out.status === :terminal_deferred
    @test out.compile.status === :ready
    @test out.lowering.status === :ready
    @test out.lowering.field_count == 1
    @test out.lowering.coefficient_kind === :diagonal
    @test out.lowering.time_unit === nothing
    @test out.lowering.transient_capacity === nothing
    @test out.composition.status === :terminal_deferred
    @test out.numerical.status === :terminal_deferred
    @test out.aggregate.status === :terminal_deferred
    @test out.aggregate.provider_calls == 0
    @test out.aggregate.mesh_calls == 0
    @test out.aggregate.solver_calls == 1
    @test out.aggregate.dgd_solver_calls == 0
    @test out.aggregate.fv_solver_calls == 1
    @test out.numerical.fv.status === :ready
    fv = out.numerical.fv
    expected_fv_matrix = ((12.0, -4.0, 0.0, 0.0),
        (-4.0, 8.0, -4.0, 0.0), (0.0, -4.0, 8.0, -4.0),
        (0.0, 0.0, -4.0, 12.0))
    expected_fv_rhs = (2400.5, 0.5, 0.5, 2400.5)
    expected_fv_solution = (300.125, 300.25, 300.25, 300.125)
    @test all(isapprox(fv.matrix[i][j], expected_fv_matrix[i][j]; atol=1e-12)
        for i in 1:4, j in 1:4)
    @test all(isapprox(fv.rhs[i], expected_fv_rhs[i]; atol=1e-12) for i in 1:4)
    @test all(isapprox(fv.solution[i], expected_fv_solution[i]; atol=1e-12) for i in 1:4)
    @test fv.residual_norm <= 1e-12
    @test out.composition.transfer.transfer.new_state == (0.25, 0.25, 0.75, 0.75)
    @test isapprox(out.composition.transfer.transfer.conservation_residual, 0.0; atol=1e-12)
    @test !isempty(out.composition.semantic_hash)
end

@testset "DCCE negative gate names are explicitly dispatched" begin
    a = _dcce_actual_input()
    observed = Dict{Symbol,Tuple{Symbol,Symbol}}()
    foreign = _DCCE.QualifiedRefV1("foreign://candidate", "v5")
    candidate_bad = _DCCE.dcce_compile_execute_v1(foreign, a.g1, a.g2, a.g3,
        a.bundle, a.spatial_case)
    observed[:candidate_mismatch] = (candidate_bad.status, candidate_bad.code)
    missing_boundary = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, a.spatial_case.old_state,
        a.spatial_case.field, nothing, a.spatial_case.composition)
    missing = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, missing_boundary)
    observed[:missing_boundary] = (missing.status, missing.code)
    pure_neumann = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, a.spatial_case.old_state,
        a.spatial_case.field, _DCCE.DeclaredSpatialBoundaryV1(:neumann, 0.0,
            :neumann, 0.0), _dcce_composition_with_payloads(
                a.spatial_case.composition; boundary=(0.0, 0.0)))
    pure = _DCCE.execute_declared_spatial_composition(pure_neumann;
        expected_source_ref=a.g1.source_ref)
    observed[:pure_neumann] = (pure.status, pure.code)
    @test observed[:candidate_mismatch] == (:fail_closed, :candidate_mismatch)
    @test observed[:missing_boundary] == (:fail_closed, :missing_boundary)
    @test observed[:pure_neumann] == (:numerical_fail, :pure_neumann_singular)
    @test haskey(observed, :candidate_mismatch) && haskey(observed, :missing_boundary)
    @test _DCCE.DCCE_CLAIM_CEILING_V1 === :screen_only
    @test :terminal_deferred in _DCCE.DCCE_STATUSES_V1
end

@testset "DCCE single-step transient scalar diffusion" begin
    a = _dcce_actual_input(transient=true)
    transient_case = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, a.spatial_case.old_state,
        a.spatial_case.field, a.spatial_case.boundary,
        a.spatial_case.composition; case_ref="be-one-step", time_interval=(0.0, 0.25),
        time_unit=:second,
        time_mass=_dcce_time_mass(a))
    transient = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, transient_case)
    capacity = a.g1.source_payload.transient_capacity
    @test transient.lowering.status === :ready
    @test transient.lowering.temporal === :transient
    @test transient.lowering.expression_subset === :diagonal_affine_backward_euler
    @test transient.lowering.time_unit === :second
    @test transient.lowering.transient_capacity == capacity
    @test transient.numerical.status === :terminal_deferred
    @test transient.numerical.fv.residual_measure_kind === :normwise_backward_error
    @test transient.numerical.fv.residual_measure <= 1e-12
    @test transient.numerical.fv.residual_norm < 1e-8
    @test transient.numerical.fv.time_step.interval == (0.0, 0.25)
    @test transient.numerical.fv.time_step.dt == 0.25
    widths = diff(transient_case.new_geometry.edges)
    @test transient.numerical.fv.time_step.mass == Tuple(capacity.coefficient .* widths)
    @test transient.numerical.fv.time_step.history ==
        transient.composition.transfer.transfer.new_state
    history = collect(transient.numerical.fv.time_step.history)
    mass = collect(transient.numerical.fv.time_step.mass)
    diffusion = _DCCE.assemble_declared_spatial_fv(transient_case.new_geometry,
        transient_case.field, transient_case.boundary; edges=transient.composition.edges)
    @test diffusion.valid
    @test all(isapprox(transient.numerical.fv.matrix[i][j],
        diffusion.assembly.matrix[i,j] + (i == j ? mass[i]/0.25 : 0.0); atol=1e-12)
        for i in eachindex(mass), j in eachindex(mass))
    @test all(isapprox(transient.numerical.fv.rhs[i],
        diffusion.assembly.rhs[i] + mass[i]*history[i]/0.25; atol=1e-12)
        for i in eachindex(mass))
    @test transient.numerical.fv.matrix != diffusion.assembly.matrix
    @test transient.numerical.fv.rhs != diffusion.assembly.rhs
    wrong_capacity_case = _DCCE.DeclaredSpatialCaseV1(
        transient_case.old_geometry, transient_case.new_geometry,
        transient_case.old_state, transient_case.field, transient_case.boundary,
        transient_case.composition; case_ref="wrong-authored-capacity",
        time_interval=(0.0, 0.25), time_unit=:second,
        time_mass=_DCCE.DeclaredSpatialTimeMassV1(2 * capacity.coefficient,
            capacity.units, a.g1.source_ref; closed=true))
    wrong_capacity = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2,
        a.g3, a.bundle, wrong_capacity_case)
    @test wrong_capacity.status === :fail_closed
    @test wrong_capacity.code === :time_capacity_source_mismatch
    transfer = _DCCE.measure_overlap_transfer(transient_case.old_geometry,
        transient_case.new_geometry, transient_case.old_state)
    assembled = _DCCE.assemble_declared_spatial_fv(transient_case.new_geometry,
        transient_case.field, transient_case.boundary)
    wrong_source = _DCCE.declared_spatial_backward_euler_system(transient_case,
        transfer.transfer, assembled.assembly; expected_source_ref="foreign://g1/source")
    @test wrong_source.status === :fail_closed
    @test wrong_source.code === :time_mass_source_mismatch
    unbound_mass = _DCCE.declared_spatial_backward_euler_system(transient_case,
        transfer.transfer, assembled.assembly)
    @test unbound_mass.status === :terminal_deferred
    @test unbound_mass.code === :time_mass_source_binding_absent

    bad_interval_case = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, a.spatial_case.old_state,
        a.spatial_case.field, a.spatial_case.boundary,
        a.spatial_case.composition; case_ref="bad-be-interval",
        time_interval=(0.25, 0.25), time_unit=:second,
        time_mass=_dcce_time_mass(a))
    bad_interval = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, bad_interval_case)
    @test bad_interval.status === :fail_closed
    @test bad_interval.code === :invalid_time_interval

    missing_capacity_case = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, a.spatial_case.old_state,
        a.spatial_case.field, a.spatial_case.boundary,
        a.spatial_case.composition; case_ref="missing-be-capacity",
        time_interval=(0.0, 0.25))
    missing_capacity = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, missing_capacity_case)
    @test missing_capacity.status === :terminal_deferred
    @test missing_capacity.code === :time_capacity_typed_absent

    bad_history_case = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, [0.25], a.spatial_case.field,
        a.spatial_case.boundary, a.spatial_case.composition;
        case_ref="bad-be-history", time_interval=(0.0, 0.25),
        time_unit=:second,
        time_mass=_dcce_time_mass(a))
    bad_history = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, bad_history_case)
    @test bad_history.status === :fail_closed
    @test bad_history.code === :state_size_mismatch
end

@testset "source-bound 8x8 backward-Euler MMS and time refinement" begin
    a = _dcce_actual_input(transient=true)
    geometry = a.spatial_case.new_geometry
    n = length(geometry.edges) - 1
    widths = diff(geometry.edges)
    centers = (geometry.edges[1:end-1] .+ geometry.edges[2:end]) ./ 2
    field = a.spatial_case.field
    boundary = a.spatial_case.boundary
    left_value = boundary.left_value
    right_value = boundary.right_value
    left_value == right_value || error("MMS fixture requires equal admitted x-face temperatures")
    reference_temperature = left_value
    composition = _dcce_composition_with_payloads(a.spatial_case.composition;
        source=Tuple(field.source), boundary=(left_value, right_value))
    coupling = _DCCE.DeclaredSpatialCouplingV1(1, 2, 0.5,
        _DCCE.UnitSignature((-2, 0, 0, 0, 0, 0, 0)), a.g1.source_ref; closed=true)
    capacity = a.g1.source_payload.transient_capacity
    thermal_time = capacity.coefficient *
        (geometry.edges[end] - geometry.edges[1])^2 / minimum(field.k_cells)
    @test thermal_time > 0.0
    # Refine over a fixed short physical horizon (5% of the characteristic
    # rhoCp*L^2/k time) so the 10/20-step BE errors remain in the first-order
    # regime while the independent solution still uses SI M and seconds.
    refinement_horizon = thermal_time / 20

    # Independent 8x8 two-field semidiscrete operator around the admitted
    # constant-face/source steady state. Opposite perturbation modes excite
    # the exchange term without altering the source contract.
    oracle = zeros(2n, 2n)
    for offset in (0, n)
        for i in 1:n-1
            conductance = 1.0 / (widths[i]/(2field.k_cells[i]) +
                widths[i+1]/(2field.k_cells[i+1]))
            oracle[offset+i,offset+i] += conductance
            oracle[offset+i+1,offset+i+1] += conductance
            oracle[offset+i,offset+i+1] -= conductance
            oracle[offset+i+1,offset+i] -= conductance
        end
        oracle[offset+1,offset+1] += field.k_cells[1] / (widths[1]/2)
        oracle[offset+n,offset+n] += field.k_cells[end] / (widths[end]/2)
    end
    for i in 1:n
        transfer = coupling.coefficient * widths[i]
        oracle[i,i] += transfer; oracle[n+i,n+i] += transfer
        oracle[i,n+i] -= transfer; oracle[n+i,i] -= transfer
    end
    mass = vcat(capacity.coefficient .* widths,
        capacity.coefficient .* widths)
    initial_mode = sin.(pi .* centers)
    boundary_state = fill(reference_temperature, 2n)
    source_rhs = vcat(widths .* field.source, widths .* field.source)
    equilibrium = boundary_state + oracle \ source_rhs
    initial = equilibrium .+ vcat(initial_mode, -initial_mode)
    exact_final = equilibrium .+
        exp(-Diagonal(1.0 ./ mass) * oracle * refinement_horizon) *
            (initial .- equilibrium)

    function integrate_be(dt)
        steps = round(Int, refinement_horizon / dt)
        @test steps in (10, 20)
        state1 = collect(initial[1:n]); state2 = collect(initial[n+1:end])
        maximum_residual = 0.0
        for step in 1:steps
            time_mass = _dcce_time_mass(a)
            case = _DCCE.DeclaredSpatialCaseV1(geometry, geometry, state1,
                field, boundary, composition; case_ref="source-bound-be-mms-$dt-$step",
                time_interval=((step-1)*dt, step*dt), time_unit=:second,
                time_mass=time_mass, component_fields=(field, field),
                component_boundaries=(boundary, boundary),
                component_old_states=(state1, state2), couplings=(coupling,))
            out = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
                a.bundle, case)
            out.lowering.status === :ready || println("DCCE_MULTIFIELD_DIAGNOSTIC dt=",dt,
                " status=",out.status," code=",out.code,
                " detail=",repr(out.aggregate.detail),
                " lowering=",repr(out.lowering))
            @test out.lowering.status === :ready
            @test out.lowering.field_count == 2
            @test out.numerical.fv.status === :ready
            matrix = [out.numerical.fv.matrix[i][j] for i in 1:2n, j in 1:2n]
            rhs = collect(out.numerical.fv.rhs)
            solution = collect(out.numerical.fv.solution)
            @test all(isapprox(matrix[i,j], oracle[i,j] +
                (i == j ? mass[i] / dt : 0.0); atol=1e-12)
                for i in 1:2n, j in 1:2n)
            history = vcat(state1, state2)
            @test all(isapprox(rhs[i], (oracle * equilibrium)[i] +
                mass[i] * history[i] / dt; atol=1e-12)
                for i in 1:2n)
            @test out.numerical.fv.residual_measure_kind === :normwise_backward_error
            @test out.numerical.fv.residual_measure <= 1e-12
            maximum_residual = max(maximum_residual,
                out.numerical.fv.residual_measure)
            state1 = solution[1:n]; state2 = solution[n+1:end]
        end
        vcat(state1, state2), maximum_residual
    end

    dt_1, dt_2 = refinement_horizon / 10, refinement_horizon / 20
    result_1, residual_1 = integrate_be(dt_1)
    result_2, residual_2 = integrate_be(dt_2)
    e1 = norm(result_1 - exact_final) / sqrt(2n)
    e2 = norm(result_2 - exact_final) / sqrt(2n)
    @test all(isfinite, (residual_1, residual_2, e1, e2))
    @test max(residual_1, residual_2) <= 1e-12
    @test e1 > e2 > 0.0
    @test 1.7 < e1/e2 < 2.3
end

@testset "DCCE coupled two-field block diffusion" begin
    a = _dcce_actual_input(transient=true)
    field1 = a.spatial_case.field
    n = length(a.spatial_case.new_geometry.edges) - 1
    field2 = _DCCE.DeclaredSpatialFieldV1(fill(2.0, n),
        collect(field1.source))
    boundary2 = a.spatial_case.boundary
    coupling = _DCCE.DeclaredSpatialCouplingV1(1, 2, 0.5,
        _DCCE.UnitSignature((-2, 0, 0, 0, 0, 0, 0)), a.g1.source_ref; closed=true)
    capacity = a.g1.source_payload.transient_capacity.coefficient
    thermal_time = capacity *
        (a.spatial_case.new_geometry.edges[end] - a.spatial_case.new_geometry.edges[1])^2 /
        minimum(field1.k_cells)
    block_horizon = thermal_time / 20
    state1_old = [0.1, 0.3]
    state2_old = [0.6, 0.8]
    function make_case(c; labels=("u", "v"))
        components = a.spatial_case.composition.components
        relabelled = Tuple(_DCCE.DeclaredSpatialComponentV1(labels[mod1(i, 2)] *
            "-" * string(i), comp.ports) for (i, comp) in enumerate(components))
        composition = _DCCE.DeclaredSpatialCompositionV1(relabelled; plan_ref="unseen-plan")
        _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
            a.spatial_case.new_geometry, state1_old, field1, a.spatial_case.boundary,
            composition; case_ref="heldout-block-case", time_interval=(0.0, block_horizon / 10),
            time_unit=:second,
            time_mass=_dcce_time_mass(a),
            component_fields=(field1, field2),
            component_boundaries=(a.spatial_case.boundary, boundary2),
            component_old_states=(state1_old, state2_old), couplings=(c,))
    end
    case = make_case(coupling)
    out = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, case)
    @test out.lowering.status === :ready
    @test out.lowering.field_count == 2
    @test out.lowering.dimension == 1
    @test out.lowering.expression_subset === :diagonal_affine_multifield_backward_euler
    @test out.lowering.coefficient_kind === :diagonal_with_declared_exchange
    @test out.lowering.time_interval == case.time_interval
    @test out.lowering.time_unit === :second
    @test out.lowering.transient_capacity == a.g1.source_payload.transient_capacity
    @test length(out.lowering.k_cells) == 2
    @test all(length(k) == n for k in out.lowering.k_cells)
    @test length(out.lowering.source) == 2
    @test all(length(f) == n for f in out.lowering.source)
    @test length(out.lowering.boundary) == 2
    @test length(out.lowering.couplings) == 1
    @test out.numerical.fv.status === :ready
    @test length(out.numerical.fv.solution) == 2n
    @test length(out.numerical.fv.matrix) == 2n
    @test all(length(row) == 2n for row in out.numerical.fv.matrix)
    @test out.numerical.fv.residual_norm <= 1e-12
    @test length(out.composition.transfer.component_transfers) == 2
    @test out.numerical.fv.time_step.history[1] == (0.1, 0.1, 0.3, 0.3)
    @test out.numerical.fv.time_step.history[2] == (0.6, 0.6, 0.8, 0.8)
    direct = _DCCE.execute_declared_spatial_composition(case;
        expected_source_ref=a.g1.source_ref,
        expected_capacity=a.g1.source_payload.transient_capacity)
    @test direct.status === :ready
    @test all(isapprox(direct.solution[i], out.numerical.fv.solution[i]; atol=1e-12)
        for i in eachindex(direct.solution))

    # Independent uniform-K block oracle with distinct source/boundary loads,
    # exchange coefficient c*cell_width, and backward-Euler mass.
    widths = diff(case.new_geometry.edges); dt = block_horizon / 10
    capacity = a.g1.source_payload.transient_capacity.coefficient
    scalar1 = zeros(4,4); scalar2 = zeros(4,4)
    for i in 1:n-1
        conductance1 = 1.0 / (widths[i]/(2 * field1.k_cells[i]) +
            widths[i+1]/(2 * field1.k_cells[i+1]))
        conductance2 = 1.0 / (widths[i]/(2 * field2.k_cells[i]) +
            widths[i+1]/(2 * field2.k_cells[i+1]))
        for matrix in (scalar1, scalar2)
            conductance = matrix === scalar1 ? conductance1 : conductance2
            matrix[i,i] += conductance; matrix[i+1,i+1] += conductance
            matrix[i,i+1] -= conductance; matrix[i+1,i] -= conductance
        end
    end
    scalar1[1,1] += 2 * field1.k_cells[1] / widths[1]
    scalar1[end,end] += 2 * field1.k_cells[end] / widths[end]
    scalar2[1,1] += 2 * field2.k_cells[1] / widths[1]
    scalar2[end,end] += 2 * field2.k_cells[end] / widths[end]
    oracle = zeros(8, 8)
    oracle[1:4,1:4] .= scalar1
    oracle[5:8,5:8] .= scalar2
    for i in 1:4
        coupling_mass = coupling.coefficient * widths[i]
        oracle[i,i] += coupling_mass + capacity * widths[i]/dt
        oracle[i+4,i+4] += coupling_mass + capacity * widths[i]/dt
        oracle[i,i+4] -= coupling_mass
        oracle[i+4,i] -= coupling_mass
    end
    left1 = 2 * field1.k_cells[1] / widths[1]
    right1 = 2 * field1.k_cells[end] / widths[end]
    left2 = 2 * field2.k_cells[1] / widths[1]
    right2 = 2 * field2.k_cells[end] / widths[end]
    rhs1 = widths .* collect(field1.source)
    rhs1[1] += left1 * a.spatial_case.boundary.left_value
    rhs1[end] += right1 * a.spatial_case.boundary.right_value
    rhs2 = widths .* collect(field2.source)
    rhs2[1] += left2 * boundary2.left_value; rhs2[end] += right2 * boundary2.right_value
    old1 = collect(out.numerical.fv.time_step.history[1])
    old2 = collect(out.numerical.fv.time_step.history[2])
    rhs1 .+= capacity .* widths/dt .* old1
    rhs2 .+= capacity .* widths/dt .* old2
    oracle_rhs = vcat(rhs1, rhs2)
    @test all(isapprox(out.numerical.fv.matrix[i][j], oracle[i,j]; atol=1e-12)
        for i in 1:8, j in 1:8)
    @test all(isapprox(out.numerical.fv.rhs[i], oracle_rhs[i]; atol=1e-12)
        for i in 1:8)
    @test all(isapprox(out.numerical.fv.solution[i], (oracle \ oracle_rhs)[i]; atol=1e-12)
        for i in 1:8)
    # An unseen composition label and held-out coupling value follow the same
    # entry point, and changing the declared coefficient changes the block.
    heldout = _DCCE.DeclaredSpatialCouplingV1(1, 2, 0.8, coupling.units,
        a.g1.source_ref; closed=true)
    out_heldout = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, make_case(heldout; labels=("unseen-left", "unseen-right")))
    @test out_heldout.numerical.fv.status === :ready
    @test out_heldout.numerical.fv.matrix != out.numerical.fv.matrix
    @test out_heldout.lowering.field_count == 2
    @test out_heldout.lowering.expression_subset === :diagonal_affine_multifield_backward_euler
    @test out_heldout.lowering.coefficient_kind === :diagonal_with_declared_exchange

    unbound = _DCCE.DeclaredSpatialCouplingV1(1, 2, 0.5, coupling.units,
        "foreign://source"; closed=true)
    bad_binding = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, make_case(unbound))
    @test bad_binding.status === :fail_closed
    @test bad_binding.code === :multifield_coupling_invalid
    @test_throws ArgumentError _DCCE.DeclaredSpatialCaseV1(
        a.spatial_case.old_geometry, a.spatial_case.new_geometry, state1_old,
        field1, a.spatial_case.boundary, a.spatial_case.composition;
        component_fields=(field1, field2),
        component_boundaries=(a.spatial_case.boundary, boundary2),
        component_old_states=(state1_old,), couplings=(coupling,))
end

println("DCCE_DECLARED_DIFFUSION_COMPILE_EXECUTE_V1_JULIA_FOCUSED_COMPLETED=true")
println("DCCE_DECLARED_DIFFUSION_COMPILE_EXECUTE_V1_DESC_EXECUTED=false")
flush(stdout)
