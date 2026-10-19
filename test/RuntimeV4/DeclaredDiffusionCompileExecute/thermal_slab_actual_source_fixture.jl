using Serialization, JSON3, Profile, SHA

# This test is included by the existing focused DCCE runner. Reuse its loaded
# `_DCCE` module and declarations; only the narrow thermal consumer is loaded here.
_DCCE.load_vnext_t2_components_v2!()
const _THERMAL_SLAB_BINDINGS_ABSENT_BEFORE =
    !isdefined(_DCCE, :CompositionSolveProtocolV1) &&
    !isdefined(Main, :SteadyPlanarThermalDiffusionConsumerV1)
const _THERMAL_SLAB_ENSURED_BINDINGS = _DCCE._vnext_up3_thermal_ensure_consumer()
const _THERMAL_SLAB_CONSUMER = _THERMAL_SLAB_ENSURED_BINDINGS.consumer
const _THERMAL_SLAB_CANDIDATE_DIR = "test/fixtures/thermal_slab/thermal-slab-up4-v5-20261001"
const _THERMAL_SLAB_K22_CANDIDATE_DIR = "test/fixtures/thermal_slab/thermal-slab-up4-v5-20261001-k22"
const _THERMAL_SLAB_BASE_NO_LAW_DIR = "tmp/up3_thermal_source_variants/base-no-law"
const _THERMAL_SLAB_FEEDBACK_EDGE_REMOVED_DIR = "tmp/up3_thermal_source_variants/feedback-edge-removed"
include(joinpath(_DCCE_ROOT, "test/fixtures/thermal_slab/thermal_slab_source_variant_builder.jl"))

# One QA-only, deterministic source-bound holdout. It clones the existing
# fixture bytes and pins every changed source file; it does not add a producer
# variant or modify any live fixture.
function _thermal_materialize_up3_blind_holdout_v1(source_root)
    root = realpath(String(source_root))
    old_slug = "thermal-slab-up4-v5-20261001"
    new_slug = "thermal-slab-up4-v5-20261001-up3-blind-l125-k25-t305-n5"
    base_relative = "test/fixtures/thermal_slab/" * old_slug
    candidate_relative = "tmp/up3_source_variants/up3-blind-l125-k25-t305-n5"
    base = joinpath(root, split(base_relative, '/')...)
    generated = Dict{String,Vector{UInt8}}()
    for relative_path in _THERMAL_SOURCE_VARIANT_REQUIRED_PATHS_V1
        text = replace(read(joinpath(base, split(relative_path, '/')...), String),
            old_slug => new_slug)
        text = replace(text, "scenario-" * new_slug => "scenario-" * old_slug)
        text = replace(text, "fusionconceptai://scenario-design/" * new_slug =>
            "fusionconceptai://scenario-design/" * old_slug)
        generated[relative_path] = collect(codeunits(text))
    end
    slug_rewritten_base = replace(base_relative, old_slug => new_slug)
    old_child = slug_rewritten_base * "/g3_child_design_source.jl"
    new_child = candidate_relative * "/g3_child_design_source.jl"
    generated["g3_child_design_source.jl"] = collect(codeunits(
        _thermal_source_variant_replace_once_v1(
            String(generated["g3_child_design_source.jl"]), old_child, new_child,
            "UP3 holdout child source path")))
    g1 = String(generated["g1_source.jl"])
    g1 = _thermal_source_variant_replace_once_v1(g1,
        "domain_max=(2//1, 1//1, 1//1),", "domain_max=(5//4, 1//1, 1//1),",
        "UP3 holdout matching G1 x domain")
    g1 = _thermal_source_variant_replace_once_v1(g1,
        "base_diag=(2//1, 3//1, 4//1), slope_diag=(0//1, 1//10, 0//1)",
        "base_diag=(5//2, 3//1, 4//1), slope_diag=(0//1, 1//10, 0//1)",
        "UP3 holdout G1 Kxx")
    generated["g1_source.jl"] = collect(codeunits(g1))
    g2 = String(generated["g2_source.jl"])
    g2 = _thermal_source_variant_replace_once_v1(g2,
        "((2//1,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1)),",
        "((5//4,0//1,0//1),(0//1,1//1,0//1),(0//1,0//1,1//1)),",
        "UP3 holdout G2 x chart scale")
    g2 = _thermal_source_variant_replace_once_v1(g2,
        "G2MBMeshPlanV1(mesh_ref, chart_ref, (4,1,1), :Q1,",
        "G2MBMeshPlanV1(mesh_ref, chart_ref, (5,1,1), :Q1,",
        "UP3 holdout G2 mesh")
    g2 = _thermal_source_variant_replace_once_v1(g2,
        "G2MBFaceOwnerV1(\"thermal_x_min\", :x_min, \"thermal_slab\", (-1,0,0), dirichlet(300//1)),",
        "G2MBFaceOwnerV1(\"thermal_x_min\", :x_min, \"thermal_slab\", (-1,0,0), dirichlet(305//1)),",
        "UP3 holdout x_min temperature")
    g2 = _thermal_source_variant_replace_once_v1(g2,
        "G2MBFaceOwnerV1(\"thermal_x_max\", :x_max, \"thermal_slab\", (1,0,0), dirichlet(300//1)),",
        "G2MBFaceOwnerV1(\"thermal_x_max\", :x_max, \"thermal_slab\", (1,0,0), dirichlet(305//1)),",
        "UP3 holdout x_max temperature")
    generated["g2_source.jl"] = collect(codeunits(g2))
    generated["g3_source.jl"] = collect(codeunits(
        _thermal_source_variant_replace_once_v1(
            String(generated["g3_source.jl"]), old_child, new_child,
            "UP3 holdout G3 child source path")))
    manifest = replace(read(joinpath(base, "manifest.json"), String),
        old_slug => new_slug)
    manifest = replace(manifest, "scenario-" * new_slug => "scenario-" * old_slug)
    manifest = replace(manifest, "fusionconceptai://scenario-design/" * new_slug =>
        "fusionconceptai://scenario-design/" * old_slug)
    for relative_path in _THERMAL_SOURCE_VARIANT_REQUIRED_PATHS_V1
        manifest = _thermal_source_variant_manifest_pin_v1(manifest, relative_path,
            generated[relative_path])
    end
    generated["manifest.json"] = collect(codeunits(manifest))
    target = joinpath(root, split(candidate_relative, '/')...)
    if ispath(target)
        isdir(target) && !islink(target) ||
            throw(ArgumentError("UP3 holdout target is not a plain directory"))
        files = Set{String}()
        for (directory, directories, names) in walkdir(target)
            isempty(directories) || throw(ArgumentError("UP3 holdout has subdirectories"))
            for name in names
                path = joinpath(directory, name)
                islink(path) && throw(ArgumentError("UP3 holdout contains a link"))
                push!(files, replace(relpath(path, target), '\\' => '/'))
            end
        end
        files == Set(keys(generated)) || throw(ArgumentError("UP3 holdout file set differs"))
        for (relative_path, bytes) in generated
            read(joinpath(target, split(relative_path, '/')...)) == bytes ||
                throw(ArgumentError("UP3 holdout bytes differ: $relative_path"))
        end
    else
        mkpath(target)
        for (relative_path, bytes) in generated
            write(joinpath(target, split(relative_path, '/')...), bytes)
        end
    end
    (source_root=root, candidate_directory=candidate_relative,
     candidate_id=new_slug)
end

function _thermal_build_source_case(candidate_directory=_THERMAL_SLAB_CANDIDATE_DIR; source_root=_DCCE_ROOT)
    dcce_timing = get(ENV, "UP2_DCCE_TIMING", "0") == "1"
    source_case_started_ns = dcce_timing ? time_ns() : 0
    if dcce_timing
        println("UP2_DCCE_SOURCE_CASE_BEGIN candidate_directory=$(candidate_directory)")
        flush(stdout)
    end

    stage_started_ns = dcce_timing ? time_ns() : 0
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_BEGIN stage=candidate_records")
        flush(stdout)
    end
    built = _DCCE._vnext_current_source_candidate_records_v1(source_root, candidate_directory)
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_END stage=candidate_records elapsed_ms=", round((time_ns() - stage_started_ns) / 1.0e6; digits=3))
        flush(stdout)
    end

    stage_started_ns = dcce_timing ? time_ns() : 0
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_BEGIN stage=source_records")
        flush(stdout)
    end
    records = _DCCE._vnext_current_source_records_v1(built)
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_END stage=source_records elapsed_ms=", round((time_ns() - stage_started_ns) / 1.0e6; digits=3))
        flush(stdout)
    end

    stage_started_ns = dcce_timing ? time_ns() : 0
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_BEGIN stage=t0_transport")
        flush(stdout)
    end
    t0 = _DCCE.vnext_declaration_transport_local_v1(built.candidate_ref,
        records.declarations, records.children, records.feedback; frozen_context=source_root)
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_END stage=t0_transport elapsed_ms=", round((time_ns() - stage_started_ns) / 1.0e6; digits=3))
        flush(stdout)
    end
    @test t0.status === :valid
    stage_started_ns = dcce_timing ? time_ns() : 0
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_BEGIN stage=independent_g3_inputs")
        flush(stdout)
    end
    independent = _DCCE._vnext_current_source_independent_g3_inputs_v1(built, records,
        t0.transport)
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_END stage=independent_g3_inputs elapsed_ms=", round((time_ns() - stage_started_ns) / 1.0e6; digits=3))
        flush(stdout)
    end

    stage_started_ns = dcce_timing ? time_ns() : 0
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_BEGIN stage=current_t1_continue")
        flush(stdout)
    end
    current = _DCCE._vnext_current_source_continue_v1(built.candidate_ref, t0, source_root,
        independent.expected, independent.realization_state,
        independent.control_payload, independent.control_state,
        independent.binding_key; initial_links=independent.initial_links)
    if dcce_timing
        println("UP2_DCCE_SOURCE_STAGE_END stage=current_t1_continue elapsed_ms=", round((time_ns() - stage_started_ns) / 1.0e6; digits=3))
        flush(stdout)
    end
    if current.status !== :prepared_not_executed
        validation = hasproperty(current, :witness_validation) ?
            current.witness_validation : nothing
        witness_status = validation !== nothing && hasproperty(validation, :status) ?
            validation.status : :not_present
        witness_errors = validation !== nothing && hasproperty(validation, :errors) ?
            validation.errors : ()
        current_status = hasproperty(current, :status) ? current.status : :not_present
        current_resolution = hasproperty(current, :resolution) ? current.resolution : :not_present
        println("THERMAL_SLAB_T1_COMPACT_CURRENT=", (status=current_status,
            resolution=current_resolution, witness_status=witness_status,
            witness_errors=witness_errors))
    end
    @test current.status === :prepared_not_executed

    chart_map = built.g2.declaration.source.chart_map
    x_lower = Float64(chart_map.offset[1] +
        chart_map.jacobian_rows[1][1] * chart_map.domain_lower[1])
    x_upper = Float64(chart_map.offset[1] +
        chart_map.jacobian_rows[1][1] * chart_map.domain_upper[1])
    nx = Int(built.g2.declaration.source.mesh.cells[1])
    nx > 0 || throw(ArgumentError("thermal G2 mesh must have positive x cell count"))
    x_edges = Tuple(Float64.(collect(range(x_lower, x_upper; length=nx + 1))))
    old_geometry = _DCCE.DeclaredSpatialGeometryV1("thermal-source-old",
        (x_lower, x_upper))
    new_geometry = _DCCE.DeclaredSpatialGeometryV1(
        "thermal-source-$(nx)-cell", x_edges)
    x_centers = ntuple(i -> (x_edges[i] + x_edges[i + 1]) / 2, nx)
    y_center = Float64(chart_map.offset[2] + chart_map.jacobian_rows[2][2] *
        (chart_map.domain_lower[2] + chart_map.domain_upper[2]) / 2)
    z_center = Float64(chart_map.offset[3] + chart_map.jacobian_rows[3][3] *
        (chart_map.domain_lower[3] + chart_map.domain_upper[3]) / 2)
    k_cells = ntuple(i -> Float64(_DCCE.g1_diffusion_k_eval(
        built.g1.declaration.K.expression, (x_centers[i], y_center, z_center))[1][1]), nx)
    spatial_field = _DCCE.DeclaredSpatialFieldV1(k_cells, ones(nx))
    x_face_values = Dict(face.face => face.value.value for face in
        built.g2.declaration.source.faces if face.face in (:x_min, :x_max))
    x_left_temperature = Float64(x_face_values[:x_min])
    x_right_temperature = Float64(x_face_values[:x_max])
    boundary = _DCCE.DeclaredSpatialBoundaryV1(:dirichlet,
        x_left_temperature, :dirichlet, x_right_temperature)
    source = ntuple(_ -> 1.0, nx)
    ends = (x_left_temperature, x_right_temperature)
    port(id, direction, quantity, unit, account, role, sign, payload, magnitude) =
        _DCCE.DeclaredSpatialPortV1(id, direction, quantity, unit, account;
            role=role, ledger_sign=sign, payload=payload, magnitude=magnitude)
    components = (
        _DCCE.DeclaredSpatialComponentV1("source-producer", (port("source-out",
            :output, :source, "W/m^3", "source", :source, 1, source, 1.0),)),
        _DCCE.DeclaredSpatialComponentV1("source-consumer", (port("source-in",
            :input, :source, "W/m^3", "source", :source, -1, source, 1.0),)),
        _DCCE.DeclaredSpatialComponentV1("boundary-producer", (port("boundary-out",
            :output, :field, "K", "boundary", :boundary, 1, ends, 1.0),)),
        _DCCE.DeclaredSpatialComponentV1("boundary-consumer", (port("boundary-in",
            :input, :field, "K", "boundary", :boundary, -1, ends, 1.0),)),
        _DCCE.DeclaredSpatialComponentV1("field-producer", (port("field-out",
            :output, :field, "K", "field", :field, 1, nothing, 1.0),)),
        _DCCE.DeclaredSpatialComponentV1("field-consumer", (port("field-in",
            :input, :field, "K", "field", :field, -1, nothing, 1.0),)))
    composition = _DCCE.DeclaredSpatialCompositionV1(components; plan_ref="thermal-slab-screen")
    spatial = _DCCE.DeclaredSpatialCaseV1(old_geometry, new_geometry,
        (x_left_temperature,), spatial_field, boundary, composition;
        case_ref="source-bound-thermal-slab")
    if dcce_timing
        println("UP2_DCCE_SOURCE_CASE_END candidate_directory=$(candidate_directory) elapsed_ms=", round((time_ns() - source_case_started_ns) / 1.0e6; digits=3))
        flush(stdout)
    end
    (built=built, records=records, t0=t0, independent=independent, current=current, spatial=spatial)
end

# Build each source-bound fixture lazily once per test phase. The focused
# runner still starts a fresh process for replay; consumers below are invoked
# independently in every testset and are never cached.
const _THERMAL_SLAB_CASE_CACHE = Dict{Tuple{String,String},Any}()
function _thermal_source_case(candidate_directory=_THERMAL_SLAB_CANDIDATE_DIR; source_root=_DCCE_ROOT)
    key = (abspath(String(source_root)), String(candidate_directory))
    get!(_THERMAL_SLAB_CASE_CACHE, key) do
        _thermal_build_source_case(candidate_directory; source_root=source_root)
    end
end
