using Test
using SHA
using TOML
using JSON3
using Serialization
println("UP1_STAGE\tbefore_fusionconceptai_import")
flush(stdout)
using FusionConceptAI
println("UP1_STAGE\tafter_fusionconceptai_import")
flush(stdout)

const G = FusionConceptAI
function _up1_stage(marker::AbstractString)
    println("UP1_STAGE\t", marker)
    flush(stdout)
    nothing
end
_up1_stage("initial_component_load_begin")
G.load_genome_v5_components!()
_up1_stage("initial_component_load_complete")
if !isdefined(G, :G3SFDeclarationV1)
    Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G3", "G3SourceFeedbackLawV1.jl"))
end
if !isdefined(G, :G1DiffusionSourcePayloadV1)
    Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
end
if !isdefined(G, :G1_SOURCE_AUTHORITY_FACTORY_REF_V1)
    Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))
end
if !isdefined(G, :g2mb_declaration_v1)
    Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
end
if !isdefined(G, :G2_SOURCE_AUTHORITY_FACTORY_REF_V1)
    Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))
end
if !isdefined(G, :VNextT0LocalSourceLocatorV1)
    Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "Integration", "VNextDeclarationTransportLocalV1.jl"))
end
if !isdefined(G, :VNextAuthorityRecheckLocalInputV1)
    Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV1.jl"))
end
for (symbol, relative) in (
        (:G3_REALIZATION_CHILD_EDIT_SCHEMA_ID_V1, joinpath("GenomeV5", "G3", "G3RealizationChildEditabilityV1.jl")),
        (:G3_CONTROL_CHILD_EDIT_SCHEMA_ID_V1, joinpath("GenomeV5", "G3", "G3ControlChildEditabilityV1.jl")),
        (:G3_BINDING_CHILD_EDIT_SCHEMA_ID_V1, joinpath("GenomeV5", "G3", "G3BindingChildEditabilityV1.jl")),
        (:G3_BINDING_CHILD_EDIT_SCHEMA_ID_V2, joinpath("GenomeV5", "G3", "G3BindingChildEditabilityV2.jl")),
        (:G3_SOURCE_AUTHORITY_FACTORY_REF_V1, joinpath("GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl")),
        (:VNextT1CanonicalBytesV2, joinpath("Contracts", "VNextT1CanonicalBytesV2.jl")),
        (:VNextAuthorityRecheckLocalV2Input, joinpath("GenomeV5", "Integration", "VNextDeclarationAuthorityRecheckLocalV2.jl")),
        (:CandidateStatePackageV5NextV2, joinpath("Contracts", "CandidateStatePackageV5NextV2.jl")),
        (:VNextT1AdmissionInputV2, joinpath("GenomeV5", "Integration", "VNextGenomeV5IntegrationV2.jl")))
    isdefined(G, symbol) || Base.include(G, joinpath(@__DIR__, "..", "..", "..", "src", relative))
end
_up1_stage("initial_source_components_ready")

const N = G.NativeGitReadCompatibilityV1
const _UP1_REPO_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _UP1_CANDIDATE = G.QualifiedRefV1("local://candidate/up1-freeze-test", "v5")
const _UP1_SOURCE_REF = G.QualifiedRefV1("local://source/up1-freeze-test", "v1")
const _UP1_SOURCE_PATH = "src/up1_source_input.jl"
const _UP1_SOURCE_BYTES = Vector{UInt8}(codeunits("candidate_source = :frozen\n"))
const _UP1_SOURCE_SHA = bytes2hex(SHA.sha256(_UP1_SOURCE_BYTES))

function _up1_write_snapshot(root; source_bytes=_UP1_SOURCE_BYTES,
        scenario_id="scenario-test-001")
    source_path = joinpath(root, split(_UP1_SOURCE_PATH, '/')...)
    mkpath(dirname(source_path))
    write(source_path, source_bytes)
    pin = (role="candidate_design_source", bytes=length(source_bytes),
        sha256=bytes2hex(SHA.sha256(source_bytes)))
    entries = [Dict("logical_path" => _UP1_SOURCE_PATH, "role" => pin.role,
        "bytes" => pin.bytes, "sha256" => pin.sha256)]
    expected = Dict(_UP1_SOURCE_PATH => pin)
    for (relative, role) in ((G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1,
            "candidate_design_source"), (G.G1_AD45_ENVELOPE_RELATIVE_PATH_V1,
            "binding_envelope"))
        source = joinpath(_UP1_REPO_ROOT, split(relative, '/')...)
        bytes = read(source)
        frozen = joinpath(root, split(relative, '/')...)
        mkpath(dirname(frozen))
        write(frozen, bytes)
        row = (role=role, bytes=length(bytes), sha256=bytes2hex(SHA.sha256(bytes)))
        push!(entries, Dict("logical_path" => relative, "role" => row.role,
            "bytes" => row.bytes, "sha256" => row.sha256))
        expected[relative] = row
    end
    manifest = Dict("snapshot" => Dict("schema" => "fusion-up1-04a-vnext-frozen-source-v1",
        "snapshot_id" => "up1-snapshot-test-001", "candidate_ref" => _UP1_CANDIDATE.id,
        "scenario_id" => scenario_id, "entry_count" => length(entries)),
        "entries" => entries)
    manifest_path = joinpath(root, "manifest.toml")
    open(manifest_path, "w") do io
        TOML.print(io, manifest)
    end
    N.UP1FrozenSourceContextV1(root, manifest_path;
        expected_snapshot_id="up1-snapshot-test-001",
        expected_manifest_sha256=bytes2hex(SHA.sha256(read(manifest_path))),
        expected_candidate_ref=_UP1_CANDIDATE.id,
        expected_scenario_id=scenario_id, expected_entries=expected)
end

function _up1_present_g1(context)
    G1 = G
    candidate = _UP1_CANDIDATE
    source_path = G1.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1
    source = N.frozen_source(context, source_path)
    source_bytes = G1.VNextT0LocalBytesV1(copy(source.bytes),
        G1.Digest256(source.sha256))
    source_ref = G1.QualifiedRefV1("local://source/g1/frozen-design", "v1")
    zero = G1.UnitSignature()
    grad_units = G1.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
    div_units = G1.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    scalar_type = G1.PhysicalType(:scalar_field, 0, 3,
        G1.TemporalTypeV1(G1.static_time), zero)
    grad_type = G1.PhysicalType(:vector_field, 1, 3,
        G1.TemporalTypeV1(G1.static_time), grad_units)
    tensor_type = G1.PhysicalType(:tensor_field, 2, 3,
        G1.TemporalTypeV1(G1.static_time), zero)
    residual_type = G1.PhysicalType(:scalar_field, 0, 3,
        G1.TemporalTypeV1(G1.static_time), div_units)
    u = G1.G1DiffusionScalarFieldV1("up1_u", scalar_type, source_ref;
        source_expression="up1_u(x)=x1+x2+x3")
    k_expr = G1.G1DiffusionDiagonalAffineKFieldV1("up1_K")
    k = G1.G1DiffusionCoefficientFieldV1("up1_K", tensor_type, source_ref;
        lower_bound=2 // 1, upper_bound=121 // 30, expression=k_expr)
    f = G1.G1DiffusionScalarFieldV1("up1_f", residual_type, source_ref;
        source_expression="up1_f(x)=1")
    grad = G1.G1TypedGradV1(G1.QualifiedRefV1(G1.G1_DIFFUSION_GRAD_OPERATOR_ID_V1,
        "v1"), "up1_u", "up1_grad_u", scalar_type, grad_type)
    apply = G1.G1TypedKApplyV1(G1.QualifiedRefV1(G1.G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1,
        "v1"), "up1_grad_u", "up1_flux", grad_type, grad_type, "up1_K")
    div = G1.G1TypedDivV1(G1.QualifiedRefV1(G1.G1_DIFFUSION_DIV_OPERATOR_ID_V1,
        "v1"), "up1_flux", "up1_f", grad_type, residual_type)
    operators = G1.G1DiffusionOperatorChainV1(grad, apply, div, "up1_f")
    payload = G1.G1DiffusionSourcePayloadV1(candidate, source_ref,
        "up1-frozen-source-v1", u, k, f)
    closure_ref = G1.QualifiedRefV1(G1.G1_DIFFUSION_CLOSURE_ID_V1,
        G1.G1_DIFFUSION_PROFILE_VERSION_V1)
    applicability_ref = G1.QualifiedRefV1(G1.G1_DIFFUSION_APPLICABILITY_ID_V1,
        G1.G1_DIFFUSION_PROFILE_VERSION_V1)
    constructor = G1.G1SourceDeclarationConstructorV1(
        G1.g1_diffusion_declaration_v1, candidate, operators, closure_ref,
        applicability_ref, "bounded-3d-local", (:local_test,))
    head = "up1:" * context.snapshot_id
    g1_locator = G1.G1IndependentSourceLocatorV1(context.source_root, head,
        source_path, source.byte_count, G1.Digest256(source.sha256), :present,
        :present, :clean, G1.Digest256(source.sha256), :isolated_test_fixture)
    axes = G1.G1VersionAxesV2(G1.QualifiedRefV1("fusion.g1.payload-schema", "v2"),
        G1.QualifiedRefV1("fusion.g1.canonicalization", "v2"),
        G1.QualifiedRefV1("fusion.g1.applicability", "v2"),
        G1.QualifiedRefV1("fusion.g1.receipt", "v2"))
    raw = G1.g1_source_authority_factory_v1(g1_locator,
        G1.QualifiedRefV1(G1.G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"),
        G1._g1sf_expected_contract(), payload, axes, constructor, context)
    raw.receipt.status === :present || error("G1 source factory did not produce a present result")
    declaration = raw.source_declaration.declaration
    declaration_raw = Vector{UInt8}(codeunits(G1.canonical_json(declaration)))
    declaration_bytes = G1.VNextT0LocalBytesV1(declaration_raw,
        G1.Digest256(bytes2hex(SHA.sha256(declaration_raw))))
    declaration_ref = G1.QualifiedRefV1("local://g1/declaration/" *
        declaration_bytes.sha256.value, "v1")
    locator = G1.VNextT0LocalSourceLocatorV1(context.source_root, source_path,
        source_ref.id, source_ref, source.byte_count, G1.Digest256(source.sha256),
        head, :present, :present, :clean, G1.Digest256(source.sha256), :isolated_test_fixture)
    normalized = G1.vnext_t0_local_normalize_factory_result_v1(raw, :G1, :G1,
        candidate, source_ref, source_bytes, locator, declaration_ref,
        declaration_bytes, G1._g1sf_expected_contract(); frozen_context=context)
    t0_axes = ntuple(i -> G1.QualifiedRefV1(
        G1.VNEXT_T0_LOCAL_AXIS_IDS_V1[i], G1.VNEXT_T0_LOCAL_AXIS_VERSION_V1), 4)
    source_identity = G1.canonical_hash((kind=:source, ref=source_ref,
        bytes_sha256=source_bytes.sha256))
    declaration_identity = G1.canonical_hash((kind=:declaration,
        ref=declaration_ref, bytes_sha256=declaration_bytes.sha256))
    factory_receipt = G1.VNextT0LocalFactoryReceiptV1(candidate, :G1, source_ref,
        declaration_ref, t0_axes, :present, normalized)
    declaration_receipt = G1.VNextT0LocalDeclarationReceiptV1(candidate, :G1,
        source_ref, declaration_ref, t0_axes, :present, normalized)
    semantic_value = merge(G1._g1d_declaration_body(declaration),
        (candidate_ref=candidate,))
    semantic_raw = Vector{UInt8}(codeunits(G1.canonical_json(semantic_value)))
    semantic_bytes = G1.VNextT0LocalBytesV1(semantic_raw,
        G1.Digest256(bytes2hex(SHA.sha256(semantic_raw))))
    semantic_body = G1.VNextT0LocalSemanticBodyV1(semantic_value,
        semantic_bytes, (:up1_present_factory_test,))
    G1.VNextT0LocalPresentDeclarationV1(:G1, candidate, source_ref,
        declaration_ref, source_identity, declaration_identity, t0_axes,
        source_bytes, declaration_bytes, semantic_body, locator, factory_receipt,
        declaration_receipt)
end

const _UP4_R2_DIR = "benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2"
const _UP4_R2_CANDIDATE = "fusionconceptai://candidate-design/local-authored-up4-g123-20260928-r2"
const _UP4_R2_SCENARIO = "scenario-local-authored-up4-g123-20260928-r2"
const _UP4_R2_AD45 = "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"
function _up4_r2_open_snapshot()
    root = get(ENV, "UP1_FROZEN_SNAPSHOT_ROOT", "")
    isempty(root) && error("UP1_FROZEN_SNAPSHOT_ROOT must name the persisted R2 snapshot")
    receipt_path = get(ENV, "UP1_FROZEN_RECEIPT_PATH", "")
    isempty(receipt_path) && error("UP1_FROZEN_RECEIPT_PATH must name the independent freeze receipt")
    receipt_sha = lowercase(get(ENV, "UP1_FROZEN_RECEIPT_SHA256", ""))
    occursin(r"^[0-9a-f]{64}$", receipt_sha) || error("UP1_FROZEN_RECEIPT_SHA256 is required")
    receipt_raw = read(receipt_path)
    bytes2hex(SHA.sha256(receipt_raw)) == receipt_sha || error("independent freeze receipt SHA-256 mismatch")
    receipt = JSON3.read(String(copy(receipt_raw)))
    String(receipt.schema) == "up1-candidate-freeze-receipt-v1" ||
        error("freeze receipt schema mismatch")
    String(receipt.snapshot_root) == normpath(abspath(root)) || error("freeze receipt root mismatch")
    String(receipt.candidate_ref) == _UP4_R2_CANDIDATE || error("freeze receipt candidate mismatch")
    String(receipt.scenario_id) == _UP4_R2_SCENARIO || error("freeze receipt scenario mismatch")
    manifest_sha = lowercase(String(receipt.manifest_sha256))
    occursin(r"^[0-9a-f]{64}$", manifest_sha) || error("freeze receipt manifest SHA is invalid")
    entries = Dict{String,Any}()
    for row in receipt.entries
        path = String(row.logical_path)
        haskey(entries, path) && error("duplicate expected frozen path: " * path)
        entries[path] = (role=String(row.role), bytes=Int(row.bytes),
            sha256=lowercase(String(row.sha256)))
    end
    isempty(entries) && error("freeze receipt has no independently pinned entries")
    N.UP1FrozenSourceContextV1(root, joinpath(root, "manifest.toml");
        expected_snapshot_id=String(receipt.snapshot_id),
        expected_manifest_sha256=manifest_sha,
        expected_candidate_ref=_UP4_R2_CANDIDATE,
        expected_scenario_id=_UP4_R2_SCENARIO, expected_entries=entries)
end

function _up4_r2_native_source_expressions(context)
    logical_path = _UP4_R2_DIR * "/native_mms_source_expressions.json"
    entry = N.frozen_source(context, logical_path)
    bytes2hex(SHA.sha256(entry.bytes)) == entry.sha256 ||
        error("frozen native MMS source-expression file hash mismatch")

    manifest_entry = N.frozen_source(context, _UP4_R2_DIR * "/manifest.json")
    identity_entry = N.frozen_source(context, _UP4_R2_DIR * "/design_identity.json")
    scenario_entry = N.frozen_source(context, _UP4_R2_DIR * "/scenario.json")
    manifest = JSON3.read(String(copy(manifest_entry.bytes)))
    identity = JSON3.read(String(copy(identity_entry.bytes)))
    scenario = JSON3.read(String(copy(scenario_entry.bytes)))
    file_rows = filter(row -> String(row.path) == "native_mms_source_expressions.json",
        manifest.files)
    length(file_rows) == 1 || error("candidate manifest must pin one native MMS record")
    only(file_rows).bytes == length(entry.bytes) &&
        lowercase(String(only(file_rows).sha256)) == entry.sha256 ||
        error("candidate manifest native MMS record pin differs from frozen bytes")

    record = JSON3.read(String(copy(entry.bytes)))
    record.schema == "up4-r2-native-mms-source-expressions-v1" ||
        error("native MMS source-expression schema mismatch")
    record.status == "candidate_design_projection_only" ||
        error("native MMS record must remain projection-only")
    record.design_scope == "candidate_design_only" ||
        error("native MMS design scope mismatch")
    record.compiler_rebuild_required === true ||
        error("native MMS record must require a separate compiler rebuild gate")
    expected_fields = union(Set(("schema", "status")),
        Set(String.(manifest.native_g1g2_mms_alignment.source_expression_record.required_fields)))
    actual_fields = Set(String.(propertynames(record)))
    actual_fields == expected_fields || error("native MMS source-expression fields differ from manifest schema")

    record.candidate_id == manifest.candidate_id &&
        record.candidate_id == identity.candidate_id &&
        record.candidate_id == scenario.candidate_id &&
        record.candidate_id == G.UP4_R2_IDENTITY.candidate_id ||
        error("native MMS candidate ID mismatch")
    record.scenario_id == manifest.scenario_id &&
        record.scenario_id == identity.scenario_id &&
        record.scenario_id == scenario.scenario_id &&
        record.scenario_id == G.UP4_R2_IDENTITY.scenario_id ||
        error("native MMS scenario ID mismatch")
    record.candidate_ref == String(manifest.candidate_ref.id) &&
        record.candidate_ref == String(identity.candidate_ref.id) &&
        record.candidate_ref == String(scenario.candidate_ref.id) &&
        record.candidate_ref == G.UP4_R2_IDENTITY.candidate_ref.id ||
        error("native MMS candidate reference mismatch")
    record.scenario_ref == String(manifest.scenario_ref.id) &&
        record.scenario_ref == String(identity.scenario_ref.id) &&
        record.scenario_ref == String(scenario.scenario_ref.id) &&
        record.scenario_ref == G.UP4_R2_IDENTITY.scenario_ref.id ||
        error("native MMS scenario reference mismatch")
    manifest.design_status == "unvalidated_design_input" &&
        identity.design_status == "unvalidated_design_input" &&
        scenario.scenario_status == "unvalidated_design_input" ||
        error("native MMS candidate/scenario status mismatch")

    contract = manifest.native_g1g2_mms_alignment.frozen_contract
    String(record.formula) == "tensor_bubble_product_variable_diagonal_affine_v1" ||
        error("native MMS formula mismatch")
    lower = String.(contract.physical_lower_metres)
    String.(record.physical_lower_metres) == lower && lower == ["1/2", "1/3", "1/4"] ||
        error("native MMS lower chart mismatch")
    upper = String.(contract.physical_upper_metres)
    String.(record.physical_upper_metres) == upper && upper == ["5/2", "10/3", "17/4"] ||
        error("native MMS upper chart mismatch")
    k_base = String.(contract.k_base)
    String.(record.k_base) == k_base && k_base == ["2/1", "3/1", "4/1"] ||
        error("native MMS coefficient base mismatch")
    k_slope = String.(contract.k_slope)
    String.(record.k_slope) == k_slope && k_slope == ["1/10", "1/20", "1/30"] ||
        error("native MMS coefficient slope mismatch")
    record.boundary_semantics == "all_six_faces_zero_dirichlet" ||
        error("native MMS boundary contract mismatch")
    record.source_sign == "minus_div_k_grad" || error("native MMS source-sign mismatch")
    record.length_scale_metres == "1/1" || error("native MMS length-scale mismatch")
    record.profile_source_basis == "GenomeV5/native-length-first-partial-basis-v1" ||
        error("native MMS source profile basis mismatch")
    record.profile_target_basis == "RuntimeV4/SI-kg-m-s-A-K-mol-cd-v1" ||
        error("native MMS target profile basis mismatch")
    record.profile_source_length_axis == 1 && record.profile_target_length_axis == 2 ||
        error("native MMS profile axis mapping mismatch")

    occursin(r"^up1-up4-r2-[0-9a-f]{20}$", String(record.producer_input_snapshot_id)) ||
        error("native MMS producer snapshot identity is malformed")
    for field in (:producer_input_manifest_sha256, :compiler_sha256, :profile_hash,
            :registry_hash, :bundle_hash, :bundle_canonical_sha256,
            :unknown_source_expression_sha256, :source_expression_sha256)
        occursin(r"^[0-9a-f]{64}$", String(getproperty(record, field))) ||
            error("native MMS provenance digest is malformed: " * String(field))
    end
    compiler_entry = N.frozen_source(context,
        "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl")
    bytes2hex(SHA.sha256(compiler_entry.bytes)) == compiler_entry.sha256 ||
        error("same-snapshot compiler source hash mismatch")
    # The producer compiler digest is provenance only. A later native consumer
    # must rebuild and compare the exact profile, registry, bundle and source
    # expressions; source-file SHA equality is not a development permission gate.
    for (field, expression, expected_pin) in (
            (:unknown_source_expression, record.unknown_source_expression,
                String(record.unknown_source_expression_sha256)),
            (:source_expression, record.source_expression, String(record.source_expression_sha256)))
        expression isa AbstractString && !isempty(expression) ||
            error("native MMS expression is empty: " * String(field))
        bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(expression)))) == expected_pin ||
            error("native MMS expression hash mismatch: " * String(field))
    end
    unknown_ast = JSON3.read(String(record.unknown_source_expression))
    source_ast = JSON3.read(String(record.source_expression))
    unknown_ast.schema == "native-g1g2-state-source-expression-v1" &&
        unknown_ast.role == "unknown_with_manufactured_reference" ||
        error("native MMS unknown expression schema/role mismatch")
    source_ast.schema == "native-g1g2-manufactured-source-expression-v1" &&
        source_ast.role == "manufactured_source" ||
        error("native MMS source expression schema/role mismatch")
    String(unknown_ast.unit_profile_hash.value) == String(record.profile_hash) &&
        String(source_ast.unit_profile_hash.value) == String(record.profile_hash) ||
        error("native MMS expression profile hash differs from projection record")
    String(unknown_ast.parameters.formula) == String(record.formula) &&
        String(source_ast.parameters.formula) == String(record.formula) &&
        String(unknown_ast.parameters.source_sign) == String(record.source_sign) &&
        String(source_ast.parameters.source_sign) == String(record.source_sign) ||
        error("native MMS expression formula/sign differs from projection record")
    (entry=entry, record=record, manifest=manifest)
end

_up1_stage("top_level_definitions_through_native_source_projection_complete")

function _up4_r2_present_record(raw, layer, candidate, builder_entry,
        source_entry, upstream_locator, context; expression_entry=nothing)
    source_ref = layer === :G1 ? raw.source_declaration.declaration.source_ref :
        raw.source_declaration.declaration.source.source_ref
    source_bytes = G.VNextT0LocalBytesV1(copy(source_entry.bytes), G.Digest256(source_entry.sha256))
    source_locator = G.VNextT0LocalSourceLocatorV1(context.source_root,
        upstream_locator.source_path, source_ref.id, source_ref, source_entry.byte_count,
        G.Digest256(source_entry.sha256), upstream_locator.observed_head,
        upstream_locator.head_path_status, upstream_locator.working_tree_path_status,
        upstream_locator.working_tree_status, upstream_locator.head_blob_sha256,
        upstream_locator.provenance)
    declaration = raw.source_declaration.declaration
    declaration_bytes = G.VNextT0LocalBytesV1(
        Vector{UInt8}(codeunits(G.canonical_json(declaration))),
        G.Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(G.canonical_json(declaration)))))))
    declaration_ref = G.QualifiedRefV1("local://up4-r2/" * String(layer) * "/declaration/" *
        declaration_bytes.sha256.value, "v1")
    builder_identity = (logical_path=builder_entry.logical_path,
        byte_count=builder_entry.byte_count, sha256=G.Digest256(builder_entry.sha256),
        bytes=copy(builder_entry.bytes))
    expression_identity = expression_entry === nothing ? nothing :
        (logical_path=expression_entry.logical_path,
         byte_count=expression_entry.byte_count,
         sha256=G.Digest256(expression_entry.sha256), bytes=copy(expression_entry.bytes))
    semantic_value = if layer === :G1
        expression_identity === nothing && error("G1 T0 witness requires frozen expression input bytes")
        merge(G._g1d_declaration_body(declaration),
            (candidate_ref=candidate, authored_builder_input=builder_identity,
             authored_expression_input=expression_identity))
    else
        (candidate_ref=candidate,
         candidate_envelope=G.VNextT0LocalG2CandidateEnvelopeV1(candidate,
            declaration.contract_ref, declaration.source.source_ref,
            declaration.source.source_hash),
         contract_ref=declaration.contract_ref, source=declaration.source,
         schema_hash=declaration.schema_hash,
         canonicalization_hash=declaration.canonicalization_hash,
         profile_hash=declaration.profile_hash, declaration_hash=declaration.declaration_hash,
         authored_builder_input=builder_identity)
    end
    semantic_raw = Vector{UInt8}(codeunits(G.canonical_json(semantic_value)))
    semantic_body = G.VNextT0LocalSemanticBodyV1(semantic_value,
        G.VNextT0LocalBytesV1(semantic_raw,
            G.Digest256(bytes2hex(SHA.sha256(semantic_raw)))),
        layer === :G1 ? (:up4_r2_authored_input_bytes, :up4_r2_expression_input_bytes) :
            (:up4_r2_authored_input_bytes,))
    contract_ref = layer === :G1 ? raw.source_declaration.public_contract_ref :
        raw.source_declaration.public_contract_ref
    normalized = G.vnext_t0_local_normalize_factory_result_v1(raw, layer, layer,
        candidate, source_ref, source_bytes, source_locator, declaration_ref,
        declaration_bytes, contract_ref; frozen_context=context)
    axes = ntuple(i -> G.QualifiedRefV1(G.VNEXT_T0_LOCAL_AXIS_IDS_V1[i],
        G.VNEXT_T0_LOCAL_AXIS_VERSION_V1), 4)
    source_identity = G.canonical_hash((kind=:source, ref=source_ref,
        bytes_sha256=source_bytes.sha256))
    declaration_identity = G.canonical_hash((kind=:declaration, ref=declaration_ref,
        bytes_sha256=declaration_bytes.sha256))
    factory_receipt = G.VNextT0LocalFactoryReceiptV1(candidate, layer, source_ref,
        declaration_ref, axes, :present, normalized)
    declaration_receipt = G.VNextT0LocalDeclarationReceiptV1(candidate, layer,
        source_ref, declaration_ref, axes, :present, normalized)
    G.VNextT0LocalPresentDeclarationV1(layer, candidate, source_ref, declaration_ref,
        source_identity, declaration_identity, axes, source_bytes, declaration_bytes,
        semantic_body, source_locator, factory_receipt, declaration_receipt)
end

function _up4_r2_present_g3_record(candidate, design, builder_entry, child_entry,
        child_design, context)
    source_ref = design.source_ref
    source_bytes_raw = copy(builder_entry.bytes)
    source_sha = bytes2hex(SHA.sha256(source_bytes_raw))
    source_sha == builder_entry.sha256 || error("frozen G3 builder hash changed")
    source_bytes = G.VNextT0LocalBytesV1(source_bytes_raw, G.Digest256(source_sha))
    source_locator = G.VNextT0LocalSourceLocatorV1(context.source_root,
        builder_entry.logical_path, source_ref.id, source_ref,
        builder_entry.byte_count, G.Digest256(builder_entry.sha256),
        "up1:" * context.snapshot_id, :not_observed, :not_observed,
        :not_observed, nothing, :up1_frozen_snapshot)
    declaration = design.declaration
    child_bytes_raw = copy(child_entry.bytes)
    child_sha = bytes2hex(SHA.sha256(child_bytes_raw))
    child_sha == child_entry.sha256 || error("frozen G3 child design hash changed")
    child_bytes = G.VNextT0LocalBytesV1(child_bytes_raw, G.Digest256(child_sha))
    semantic_value = merge(G._g3sf_body(declaration),
        (candidate_ref=candidate, source_ref=source_ref,
         authored_child_design=(schema=child_design.schema,
             design_scope=child_design.design_scope,
             candidate_id=child_design.candidate_id,
             scenario_id=child_design.scenario_id,
             geometry=child_design.geometry, control_design=child_design.control_design,
             realization=child_design.realization, control=child_design.control),
         authored_child_design_input=child_bytes,
         authored_typed_ledger_source=design.typed_ledger_source))
    semantic_raw = Vector{UInt8}(codeunits(G.canonical_json(semantic_value)))
    semantic_body = G.VNextT0LocalSemanticBodyV1(semantic_value,
        G.VNextT0LocalBytesV1(semantic_raw,
            G.Digest256(bytes2hex(SHA.sha256(semantic_raw)))),
        (:up4_r2_g3_feedback_input_bytes, :up4_r2_g3_child_design_input_bytes))
    declaration_raw = Vector{UInt8}(codeunits(G.canonical_json(declaration)))
    declaration_bytes = G.VNextT0LocalBytesV1(declaration_raw,
        G.Digest256(bytes2hex(SHA.sha256(declaration_raw))))
    declaration_ref = G.QualifiedRefV1("local://up4-r2/G3/declaration/" *
        declaration_bytes.sha256.value, "v1")
    normalized = G.vnext_t0_local_normalize_g3_feedback_declaration_v1(
        declaration, candidate, source_ref, source_bytes, source_locator,
        declaration_ref, semantic_body; frozen_context=context)
    axes = ntuple(i -> G.QualifiedRefV1(G.VNEXT_T0_LOCAL_AXIS_IDS_V1[i],
        G.VNEXT_T0_LOCAL_AXIS_VERSION_V1), 4)
    source_identity = G.canonical_hash((kind=:source, ref=source_ref,
        bytes_sha256=source_bytes.sha256))
    declaration_identity = G.canonical_hash((kind=:declaration,
        ref=declaration_ref, bytes_sha256=declaration_bytes.sha256))
    factory_receipt = G.VNextT0LocalFactoryReceiptV1(candidate, :G3,
        source_ref, declaration_ref, axes, :present, normalized)
    declaration_receipt = G.VNextT0LocalDeclarationReceiptV1(candidate, :G3,
        source_ref, declaration_ref, axes, :present, normalized)
    G.VNextT0LocalPresentDeclarationV1(:G3, candidate, source_ref,
        declaration_ref, source_identity, declaration_identity, axes,
        source_bytes, declaration_bytes, semantic_body, source_locator,
        factory_receipt, declaration_receipt)
end

function _up4_r2_present_g3_child(kind, candidate, entry, context, child_design)
    raw = copy(entry.bytes)
    sha = bytes2hex(SHA.sha256(raw))
    sha == entry.sha256 || error("frozen G3 child source hash changed")
    bytes = G.VNextT0LocalBytesV1(raw, G.Digest256(sha))
    source_ref = G.QualifiedRefV1(
        "fusionconceptai://candidate-design/" * G.UP4_R2_IDENTITY.candidate_id *
        "/g3-child-design", "v1")
    locator = G.VNextT0LocalSourceLocatorV1(context.source_root,
        entry.logical_path, source_ref.id, source_ref, entry.byte_count,
        G.Digest256(entry.sha256), "up1:" * context.snapshot_id,
        :not_observed, :not_observed, :not_observed, nothing,
        :up1_frozen_snapshot)
    child_projection = kind === :realization ? child_design.realization :
        kind === :control ? child_design.control :
        (schema=child_design.schema, design_scope=child_design.design_scope,
         candidate_id=child_design.candidate_id, scenario_id=child_design.scenario_id,
         geometry=child_design.geometry, control_design=child_design.control_design,
         realization=child_design.realization, control=child_design.control)
    body = (kind=kind, source_ref=source_ref, source_sha256=bytes.sha256,
        contract=:candidate_bound_g3, child_design=child_projection)
    child_ref = G.QualifiedRefV1("local://GenomeV5/G3/" * String(kind) * "/" * sha, "v1")
    body_hash = G.canonical_hash(body)
    identity_hash = G.canonical_hash((candidate_ref=candidate, layer=:G3,
        child_id=String(kind), kind=kind, child_ref=child_ref,
        body_hash=body_hash, source_ref=source_ref, source_sha256=bytes.sha256))
    G.VNextT0LocalChildPresentV1(kind, candidate, :G3, String(kind),
        child_ref, source_ref, bytes, locator, body, body_hash, identity_hash)
end

function _up4_r2_write_t0_receipt(path, context, candidate, admission, g3_record)
    isempty(path) && throw(ArgumentError("UP1_T0_RECEIPT_OUT must be set for the producer run"))
    ispath(path) && throw(ArgumentError("refusing to overwrite immutable UP1 T0 receipt: " * path))
    admission.status === :valid || throw(ArgumentError("T0 receipt requires valid admission"))
    receipt = (schema="up1-up4-r2-t0-recheck-receipt-v1",
        snapshot_id=context.snapshot_id,
        manifest_sha256=context.manifest_sha256,
        candidate_ref=(id=candidate.id, version=candidate.version),
        status=admission.status, resolution=admission.resolution,
        bundle_hash=admission.transport.bundle_hash.value,
        g3_declaration_ref=(id=g3_record.declaration_ref.id,
            version=g3_record.declaration_ref.version),
        g3_declaration_identity_hash=g3_record.declaration_identity_hash.value)
    bytes = Vector{UInt8}(codeunits(JSON3.write(receipt)))
    io = Base.Filesystem.open(path,
        Base.JL_O_WRONLY | Base.JL_O_CREAT | Base.JL_O_EXCL, 0o666)
    try
        write(io, bytes)
        flush(io)
    finally
        close(io)
    end
    read(path) == bytes || throw(ArgumentError("written UP1 T0 receipt bytes changed"))
    bytes2hex(SHA.sha256(bytes))
end

function _up4_r2_write_native_t1_admission(path, admission, context, candidate,
        t0_receipt_path, t0_receipt_sha256,
        g3_receipt_path, g3_receipt_sha256)
    isempty(path) && throw(ArgumentError("UP1_NATIVE_T1_ADMISSION_OUT must be nonempty"))
    admission isa G.VNextT1AdmissionResultV2 ||
        throw(ArgumentError("native handoff requires the actual VNextT1AdmissionResultV2"))
    for (name, value) in (("freeze receipt SHA-256", get(ENV,
            "UP1_FROZEN_RECEIPT_SHA256", "")),
            ("T0 receipt SHA-256", t0_receipt_sha256),
            ("G3 expected receipt SHA-256", g3_receipt_sha256))
        occursin(r"^[0-9a-f]{64}$", lowercase(String(value))) ||
            throw(ArgumentError(name * " is missing or malformed"))
    end
    isempty(t0_receipt_path) && throw(ArgumentError("T0 receipt path is missing"))
    isempty(g3_receipt_path) && throw(ArgumentError("G3 expected receipt path is missing"))
    ispath(path) && throw(ArgumentError(
        "refusing to overwrite immutable native T1 admission artifact: " * path))
    sidecar_path = path * ".json"
    ispath(sidecar_path) && throw(ArgumentError(
        "refusing to overwrite immutable native T1 admission sidecar: " * sidecar_path))
    io = Base.Filesystem.open(path,
        Base.JL_O_WRONLY | Base.JL_O_CREAT | Base.JL_O_EXCL, 0o666)
    try
        Serialization.serialize(io, admission)
        flush(io)
    finally
        close(io)
    end
    raw = read(path)
    isempty(raw) && throw(ArgumentError("serialized native T1 admission is empty"))
    artifact_sha256 = bytes2hex(SHA.sha256(raw))
    t1_package = admission.package
    sidecar = (schema="up1-native-t1-admission-artifact-sidecar-v1",
        snapshot_id=context.snapshot_id,
        manifest_sha256=context.manifest_sha256,
        freeze_receipt_path=normpath(abspath(ENV["UP1_FROZEN_RECEIPT_PATH"])),
        freeze_receipt_sha256=lowercase(ENV["UP1_FROZEN_RECEIPT_SHA256"]),
        t0_receipt_path=normpath(abspath(t0_receipt_path)),
        t0_receipt_sha256=lowercase(String(t0_receipt_sha256)),
        g3_expected_receipt_path=normpath(abspath(g3_receipt_path)),
        g3_expected_receipt_sha256=lowercase(String(g3_receipt_sha256)),
        candidate_ref=(id=candidate.id, version=candidate.version),
        scenario_id=G.UP4_R2_IDENTITY.scenario_id,
        artifact_path=normpath(abspath(path)), artifact_bytes=length(raw),
        artifact_sha256=artifact_sha256,
        t1_status=String(admission.status), t1_resolution=String(admission.resolution),
        t1_accepted=admission.accepted, t1_claim_ceiling=String(admission.claim_ceiling),
        package_hash=t1_package.package_hash.value,
        package_semantic_identity=t1_package.semantic_identity.value,
        package_bundle_hash=t1_package.bundle_hash.value)
    sidecar_raw = Vector{UInt8}(codeunits(JSON3.write(sidecar)))
    sidecar_io = Base.Filesystem.open(sidecar_path,
        Base.JL_O_WRONLY | Base.JL_O_CREAT | Base.JL_O_EXCL, 0o666)
    try
        write(sidecar_io, sidecar_raw)
        flush(sidecar_io)
    finally
        close(sidecar_io)
    end
    read(sidecar_path) == sidecar_raw ||
        throw(ArgumentError("native T1 admission sidecar bytes changed after write"))
    println("UP1_NATIVE_T1_ADMISSION_WRITTEN\t", path, "\t", length(raw),
        "\t", artifact_sha256, "\tsidecar=", sidecar_path, "\t",
        bytes2hex(SHA.sha256(sidecar_raw)))
    flush(stdout)
    artifact_sha256
end

function _up4_r2_absent_children(candidate)
    bytes = Vector{UInt8}(codeunits("{}"))
    receipt = G.VNextT0LocalBytesV1(bytes, G.Digest256(bytes2hex(SHA.sha256(bytes))))
    ntuple(i -> begin
        kind = G.VNEXT_T0_LOCAL_CHILD_KINDS_V1[i]
        G.VNextT0LocalChildAbsentV1(kind, candidate, :G3, String(kind),
            :terminal_deferred, "UP4 R2 child evidence is not part of this bounded admission",
            false, :G3, receipt, receipt.sha256,
            "src/GenomeV5/G3/" * String(kind) * ".jl")
    end, 3)
end

_up1_stage("top_level_definitions_through_absent_children_complete")
_up1_stage("r2_run_definition_begin")

function _up4_r2_run(mode::Symbol)
    mode in (:positive, :consumer, :negatives) || error("unsupported UP4 R2 mode: $mode")
    _up1_stage("r2_component_load_begin")
    G.load_genome_v5_components!()
    _up1_stage("r2_component_load_complete")
    _up1_stage("r2_freeze_open_begin")
    context = _up4_r2_open_snapshot()
    _up1_stage("r2_freeze_open_complete")
    root = context.source_root
    frozen_receipt_path = ENV["UP1_FROZEN_RECEIPT_PATH"]
    @test N.activate_up1_frozen_runtime!(context)
    consumer_helper_sha256 = nothing
    consumer_bridge_sha256 = nothing
    if mode === :consumer
        bridge_path = "src/GenomeV5/Integration/VNextG3BindingAuthorityBridgeLocalV1.jl"
        bridge_entry = N.frozen_source(context, bridge_path)
        bridge_raw = copy(bridge_entry.bytes)
        consumer_bridge_sha256 = bytes2hex(SHA.sha256(bridge_raw))
        consumer_bridge_sha256 == bridge_entry.sha256 ||
            error("frozen UP1 G3 authority bridge hash mismatch")
        Base.include_string(G, String(bridge_raw), bridge_path)
        println("UP1_G3_BRIDGE_PINNED\t", bridge_path, "\t",
            consumer_bridge_sha256)
        flush(stdout)
        for (path, sentinel) in (
                ("src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl",
                    :T0LocalParentBaselineInputV1),
                ("src/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl",
                    :VNextT2ConcreteSourceWitnessV3))
            source_entry = N.frozen_source(context, path)
            source_raw = copy(source_entry.bytes)
            source_sha256 = bytes2hex(SHA.sha256(source_raw))
            source_sha256 == source_entry.sha256 ||
                error("frozen UP1 source witness component hash mismatch: $path")
            isdefined(G, sentinel) || Base.include_string(G, String(source_raw), path)
            println("UP1_SOURCE_WITNESS_COMPONENT_PINNED\t", path, "\t",
                source_sha256)
            flush(stdout)
        end
        helper_path = "test/GenomeV5/Integration/up1_g3_expected_consumer_helpers.jl"
        helper_entry = N.frozen_source(context, helper_path)
        helper_raw = copy(helper_entry.bytes)
        consumer_helper_sha256 = bytes2hex(SHA.sha256(helper_raw))
        consumer_helper_sha256 == helper_entry.sha256 ||
            error("frozen UP1 G3 consumer helper hash mismatch")
        Base.include_string(Main, String(helper_raw), helper_path)
        println("UP1_G3_CONSUMER_HELPERS_PINNED\t", helper_path, "\t",
            consumer_helper_sha256)
        flush(stdout)
    end
    _up1_stage("r2_frozen_runtime_active")
    _up1_stage("r2_identity_g1_g2_include_begin")
    Base.include_string(G, String(copy(N.frozen_source(context,
        _UP4_R2_DIR * "/identity.jl").bytes)), _UP4_R2_DIR * "/identity.jl")
    Base.include_string(G, String(copy(N.frozen_source(context,
        _UP4_R2_DIR * "/g1_source.jl").bytes)), _UP4_R2_DIR * "/g1_source.jl")
    Base.include_string(G, String(copy(N.frozen_source(context,
        _UP4_R2_DIR * "/g2_source.jl").bytes)), _UP4_R2_DIR * "/g2_source.jl")
    g3_builder_entry = N.frozen_source(context, _UP4_R2_DIR * "/g3_source.jl")
    g3_child_entry = N.frozen_source(context, _UP4_R2_DIR * "/g3_child_design_source.jl")
    g3_child_sha = bytes2hex(SHA.sha256(g3_child_entry.bytes))
    @test g3_child_sha == g3_child_entry.sha256
    Base.include_string(G, String(copy(g3_child_entry.bytes)),
        _UP4_R2_DIR * "/g3_child_design_source.jl")
    g3_child_design = Base.invokelatest(G.up4_r2_g3_child_design_source_v1)
    g3_builder_sha = bytes2hex(SHA.sha256(g3_builder_entry.bytes))
    @test g3_builder_sha == g3_builder_entry.sha256
    Base.include_string(G, String(copy(g3_builder_entry.bytes)), _UP4_R2_DIR * "/g3_source.jl")
    _up1_stage("r2_g3_builder_include_complete")
    _up1_stage("r2_locator_builder_include_begin")
    Base.include_string(G, String(copy(N.frozen_source(context,
        _UP4_R2_DIR * "/factory_locators.jl").bytes)), _UP4_R2_DIR * "/factory_locators.jl")
    _up1_stage("r2_locator_builder_include_complete")

    _up1_stage("r2_factory_locator_builder_begin")
    candidate = G.UP4_R2_IDENTITY.candidate_ref
    observations = Base.invokelatest(G.up4_r2_build_factory_locators, context)
    _up1_stage("r2_factory_locator_builder_complete")
    g1_builder = observations.audit_inputs.candidate.G1_design
    g2_builder = observations.audit_inputs.candidate.G2_design
    g3_builder_input = observations.audit_inputs.candidate.G3_design
    g1_expression_input = observations.audit_inputs.candidate.G1_expressions
    @test g1_builder.bytes == N.frozen_source(context, _UP4_R2_DIR * "/g1_source.jl").bytes
    @test g2_builder.bytes == N.frozen_source(context, _UP4_R2_DIR * "/g2_source.jl").bytes
    @test g3_builder_input.bytes == g3_builder_entry.bytes
    expression_entry = N.frozen_source(context,
        _UP4_R2_DIR * "/native_mms_source_expressions.json")
    g1_expression_input.bytes == expression_entry.bytes ||
        error("locator did not expose the same-snapshot G1 expression record bytes")
    g1_expression_input.sha256 == expression_entry.sha256 ||
        error("locator G1 expression record SHA differs from frozen source")
    @test G.Digest256(bytes2hex(SHA.sha256(g1_builder.bytes))) == G.Digest256(g1_builder.sha256)
    @test G.Digest256(bytes2hex(SHA.sha256(g2_builder.bytes))) == G.Digest256(g2_builder.sha256)
    @test G.Digest256(bytes2hex(SHA.sha256(g3_builder_input.bytes))) == G.Digest256(g3_builder_input.sha256)

    _up1_stage("r2_g1_g2_g3_design_builders_begin")
    source_projection = _up4_r2_native_source_expressions(context)
    source_projection.entry.bytes == g1_expression_input.bytes ||
        error("G1 source-expression builder input is not the audited frozen locator entry")
    isdefined(Main, :FusionRuntimeV4) &&
        error("UP1 source-only gate must not load RuntimeV4 or the native compiler")
    g1 = Base.invokelatest(G.up4_r2_build_g1_design, source_projection.record)
    isdefined(Main, :FusionRuntimeV4) &&
        error("UP1 source-only G1 builder unexpectedly loaded RuntimeV4")
    g2 = Base.invokelatest(G.up4_r2_build_g2_design, source_projection.record)
    g3_design = Base.invokelatest(G.up4_r2_build_g3_design,
        g3_child_design; source_file_sha256=g3_child_sha)
    _up1_stage("r2_g1_g2_g3_design_builders_complete")
    g1.declaration.u.source_expression == source_projection.record.unknown_source_expression ||
        error("G1 builder did not project exact frozen unknown expression bytes")
    g1.declaration.f.source_expression == source_projection.record.source_expression ||
        error("G1 builder did not project exact frozen source expression bytes")
    g2.candidate_id == source_projection.record.candidate_id ||
        error("G2 builder candidate differs from frozen native MMS record")
    g2.scenario_id == source_projection.record.scenario_id ||
        error("G2 builder scenario differs from frozen native MMS record")
    g2.candidate_ref == candidate || error("G2 builder candidate ref mismatch")
    g2.source.chart_map.domain_lower == (0//1, 0//1, 0//1) ||
        error("G2 chart domain lower is not the unit cube")
    g2.source.chart_map.domain_upper == (1//1, 1//1, 1//1) ||
        error("G2 chart domain upper is not the unit cube")
    record_lower = Tuple(begin
        numerator, denominator = split(String(value), "/"; limit=2)
        parse(Int64, numerator) // parse(Int64, denominator)
    end for value in source_projection.record.physical_lower_metres)
    record_upper = Tuple(begin
        numerator, denominator = split(String(value), "/"; limit=2)
        parse(Int64, numerator) // parse(Int64, denominator)
    end for value in source_projection.record.physical_upper_metres)
    record_lengths = ntuple(i -> record_upper[i] - record_lower[i], 3)
    @test g2.source.chart_map.offset == record_lower
    @test g2.source.chart_map.jacobian_rows ==
        ((record_lengths[1], 0//1, 0//1), (0//1, record_lengths[2], 0//1),
         (0//1, 0//1, record_lengths[3]))
    @test G.g2mb_chart_image_bounds(g2.source.chart_map) ==
        ntuple(i -> (record_lower[i], record_upper[i]), 3)
    @test g2.source.mesh.chart_ref == g2.source.chart_map.chart_ref
    @test g2.source.mesh.cells == (2, 3, 4)
    @test g2.source.mesh.basis === :Q1
    @test g2.source.mesh.execution_status === :not_executed
    @test Set(face.face for face in g2.source.faces) ==
        Set((:x_min, :x_max, :y_min, :y_max, :z_min, :z_max))
    @test length(g2.source.faces) == 6
    @test all(face -> face.value.kind === :dirichlet && face.value.value == 0//1 &&
        face.ownership === :candidate_owned, g2.source.faces)
    @test g2.mesh_execution === :not_executed
    @test g2.physical_resolution === :unknown
    println("UP1_NATIVE_MMS_PROJECTION_OBSERVED\trecord_sha256=",
        source_projection.entry.sha256,
        "\tunknown_sha256=", source_projection.record.unknown_source_expression_sha256,
        "\tsource_sha256=", source_projection.record.source_expression_sha256,
        "\tcompiler_rebuild_required=true\tcompiler_loaded=false",
        "\tnative_solver=not_run\tphysical_credit=none")
    flush(stdout)
    @test g3_design.candidate_id == G.UP4_R2_IDENTITY.candidate_id
    @test g3_design.scenario_id == G.UP4_R2_IDENTITY.scenario_id
    @test g3_design.candidate_ref == candidate
    @test g3_design.source_ref.id == "fusionconceptai://GenomeV5/G3/source-feedback/local-authored-up4-g123-20260928-r2"
    @test g3_design.validation[1] === :valid
    @test g3_design.upstream_authority_status == (G1=:missing, G2=:missing)
    @test g3_child_design.schema == "up4-r2-g3-child-design-source-v1"
    @test g3_child_design.design_scope == "candidate_design_only"
    @test g3_child_design.candidate_id == G.UP4_R2_IDENTITY.candidate_id
    @test g3_child_design.scenario_id == G.UP4_R2_IDENTITY.scenario_id
    @test g3_design.child_source_sha256 == G.Digest256(g3_child_sha)
    @test g3_design.realization_state.state_status === :present
    @test g3_design.control_state.state_status === :present
    @test g3_design.realization_state.payload.body == g3_child_design.realization
    @test g3_design.control_state.editable_body == g3_child_design.control
    @test g3_design.realization_state.payload.source_record.evidence_receipt.source_hash ==
        G.Digest256(g3_child_sha)
    @test g3_design.control_source_record.evidence_receipt_version.source_hash ==
        G.Digest256(g3_child_sha)
    @test g3_design.control_state.source_payload_ref.source_record_ref.record_hash ==
        g3_design.control_source_record.source_record_hash
    @test g3_design.binding_absent === nothing
    @test g3_design.physical_resolution === :unknown
    ledger = g3_design.typed_ledger_source
    @test ledger.design_scope === :candidate_design_only
    @test ledger.account_owners == g3_child_design.account_owners
    @test ledger.owner_scope_account_membership ==
        g3_child_design.owner_scope_account_membership
    @test all(account -> account isa G.G3LedgerAccountV2 &&
        account.owner == only(filter(owner -> owner.account_id == account.account_id,
            ledger.account_owners)).owner, ledger.accounts)
    @test Tuple(entry.entry_id for entry in ledger.entries) ==
        Tuple(entry.entry_id for entry in g3_child_design.realization.ledger_entries)
    @test Tuple(closure.closure_id for closure in ledger.closures) ==
        Tuple(closure.closure_id for closure in g3_child_design.realization.ledger_closures)
    @test all(balance -> balance.actual_balance == balance.expected_balance,
        ledger.balances)
    @test only(ledger.balances).actual_balance == 0
    # Object-level negatives exercise the builder; no source-byte authority is
    # claimed for these deliberately edited in-memory inputs.
    @test_throws ArgumentError Base.invokelatest(G.up4_r2_build_g3_design,
        merge(g3_child_design, (account_owners=((account_id="design_energy",),),));
        source_file_sha256=g3_child_sha)
    @test_throws ArgumentError Base.invokelatest(G.up4_r2_build_g3_design,
        merge(g3_child_design, (account_owners=(g3_child_design.account_owners[1],
            g3_child_design.account_owners[1]),)); source_file_sha256=g3_child_sha)
    @test_throws ArgumentError Base.invokelatest(G.up4_r2_build_g3_design,
        merge(g3_child_design, (owner_scope_account_membership=((
            owner_scope=g3_child_design.realization.owner_scope,
            account_ids=("unknown_account",)),),)); source_file_sha256=g3_child_sha)
    @test_throws ArgumentError Base.invokelatest(G.up4_r2_build_g3_design,
        merge(g3_child_design, (owner_scope_account_membership=((
            owner_scope="wrong_scope", account_ids=("design_energy",)),),));
        source_file_sha256=g3_child_sha)
    _up1_stage("r2_g3_bundle_factory_begin")
    g3_handle = G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")
    g3_source_declaration_ref = G.QualifiedRefV1(
        "fusionconceptai://GenomeV5/G3/bundle/source-declaration/up4-r2", "v1")
    g3_factory_present = Base.invokelatest(G.g3_source_authority_factory_v1,
        :bundle, observations.G3.bundle, g3_handle, G.g3_contract_ref(:bundle),
        G.g3_version_axes(:bundle), g3_source_declaration_ref, context)
    _up1_stage("r2_g3_bundle_factory_complete")
    @test g3_factory_present.identity isa G.PresentG3FactoryIdentityV1
    @test g3_factory_present.receipt isa G.PresentG3FactoryConstructionReceiptV1
    @test g3_factory_present.receipt.status === :present
    @test g3_factory_present.receipt.scope === :bundle
    @test !g3_factory_present.receipt.candidate_identity_created
    @test g3_factory_present.receipt.g3_source_declaration_hash_created
    @test !g3_factory_present.receipt.final_candidate_or_package_declaration_hash_created
    @test !g3_factory_present.receipt.trusted_attestation_created
    @test g3_factory_present.source_declaration.source_declaration_hash ==
        g3_factory_present.receipt.source_declaration_hash
    g1_axes = G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema", "v2"),
        G.QualifiedRefV1("fusion.g1.canonicalization", "v2"),
        G.QualifiedRefV1("fusion.g1.applicability", "v2"),
        G.QualifiedRefV1("fusion.g1.receipt", "v2"))
    g1_declaration = g1.declaration
    g1_constructor = G.G1SourceDeclarationConstructorV1(G.g1_diffusion_declaration_v1,
        candidate, g1_declaration.operators, g1_declaration.closure_ref,
        g1_declaration.applicability_ref, g1_declaration.applicability_domain,
        g1_declaration.negative_controls)
    handle = G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")
    g2_axes = G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema", "v5"),
        G.QualifiedRefV1("fusion.g2.canonicalization", "v5"),
        G.QualifiedRefV1("fusion.g2.applicability", "v5"),
        G.QualifiedRefV1("fusion.g2.receipt", "v5"))
    g2_constructor = G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)

    if mode in (:positive, :consumer)
        _up1_stage("r2_native_g1_g2_factories_begin")
        raw_g1 = G.g1_source_authority_factory_v1(observations.G1, handle,
            G._g1sf_expected_contract(), g1.source_payload, g1_axes,
            g1_constructor, context)
        @test raw_g1.receipt.status === :present
        @test raw_g1.receipt.trusted == false
        @test !raw_g1.receipt.candidate_identity_created && !raw_g1.receipt.final_hash_created
        raw_g2 = G.g2_source_authority_factory_v1(observations.G2, handle,
            g2.contract_ref, g2.source, g2_axes, g2_constructor, context)
        @test raw_g2.receipt.status === :present
        @test raw_g2.receipt.trusted == false
        @test !raw_g2.receipt.candidate_identity_created && !raw_g2.receipt.final_hash_created
        _up1_stage("r2_native_g1_g2_factories_complete")

        _up1_stage("r2_t0_present_records_begin")
        g1_record = _up4_r2_present_record(raw_g1, :G1, candidate, g1_builder,
            observations.audit_inputs.schema.G1, observations.G1, context;
            expression_entry=expression_entry)
        g2_record = _up4_r2_present_record(raw_g2, :G2, candidate, g2_builder,
            observations.audit_inputs.schema.G2, observations.G2, context)
        g3_record = _up4_r2_present_g3_record(candidate, g3_design,
            g3_builder_input, g3_child_entry, g3_child_design, context)
        _up1_stage("r2_t0_present_records_complete")
        declarations = (g1_record, g2_record, g3_record)
        children = ntuple(i -> _up4_r2_present_g3_child(
            G.VNEXT_T0_LOCAL_CHILD_KINDS_V1[i], candidate, g3_child_entry,
            context, g3_child_design), 3)
        feedback = Tuple(begin
            target_record = only(filter(record ->
                record.layer === target.target_layer, declarations))
            body = (candidate_ref=candidate,
                source_ref=target_record.source_ref,
                declaration_ref=target_record.declaration_ref,
                target_ref=target_record.source_ref,
                feedback_targets=(target,),
                source_g3_ref=g3_record.source_ref,
                source_g3_declaration_ref=g3_record.declaration_ref,
                target=target)
            G.VNextT0LocalFeedbackV1(target.target_id,
                target.target_layer, candidate, target_record.source_ref,
                body, G.canonical_hash(body))
        end for target in g3_design.declaration.feedback_targets)
        _up1_stage("r2_t0_transport_begin")
        admission = G.vnext_declaration_transport_local_v1(candidate, declarations,
            children, feedback; frozen_context=context)
        println("UP1_T0_OBSERVED\t", admission.status, "\t", admission.resolution,
            "\terrors=", repr(admission.errors), "\tgaps=", repr(admission.gaps),
            "\thas_transport=", admission.transport !== nothing)
        flush(stdout)
        admission.status === :valid || error(
            "UP1 T0 transport was not valid: status=$(admission.status), " *
            "resolution=$(admission.resolution), errors=$(repr(admission.errors)), " *
            "gaps=$(repr(admission.gaps)), has_transport=$(admission.transport !== nothing)")
        t0_receipt_sha256 = nothing
        if mode === :positive && haskey(ENV, "UP1_T0_RECEIPT_OUT")
            t0_receipt_sha256 = _up4_r2_write_t0_receipt(
                ENV["UP1_T0_RECEIPT_OUT"], context, candidate, admission, g3_record)
            println("UP1_T0_RECEIPT_WRITTEN\t", ENV["UP1_T0_RECEIPT_OUT"],
                "\t", t0_receipt_sha256)
            flush(stdout)
        elseif mode === :consumer
            t0_receipt, t0_receipt_sha256 = Base.invokelatest(
                _up4_r2_read_pinned_json,
                get(ENV, "UP1_T0_RECEIPT_PATH", ""),
                get(ENV, "UP1_T0_RECEIPT_SHA256", ""), "UP1 T0 receipt")
            @test t0_receipt.schema == "up1-up4-r2-t0-recheck-receipt-v1"
            @test t0_receipt.status == "valid"
            @test t0_receipt.resolution == "local_contract_ready"
            println("UP1_T0_RECEIPT_CONSUMED\t", ENV["UP1_T0_RECEIPT_PATH"],
                "\t", t0_receipt_sha256)
            flush(stdout)
        end
        _up1_stage("r2_t0_transport_complete")
        @test admission.status === :valid
        @test admission.resolution === :local_contract_ready
        @test !admission.accepted && admission.claim_ceiling === :contract_only
        @test admission.transport.frozen_source_authority.manifest_sha256 == context.manifest_sha256
        @test admission.transport.declarations[1].semantic_body.body.authored_builder_input.bytes == g1_builder.bytes
        admission.transport.declarations[1].semantic_body.body.authored_expression_input.bytes ==
            expression_entry.bytes || error("T0 G1 semantic witness omitted frozen expression record bytes")
        admission.transport.declarations[1].semantic_body.body.authored_expression_input.sha256 ==
            G.Digest256(expression_entry.sha256) || error("T0 G1 semantic witness expression SHA mismatch")
        @test admission.transport.declarations[2].semantic_body.body.authored_builder_input.bytes == g2_builder.bytes
        @test admission.transport.declarations[3].source_bytes.bytes == g3_builder_input.bytes
        @test admission.transport.declarations[3].semantic_body.body.authored_child_design_input.bytes ==
            g3_child_entry.bytes
        @test admission.transport.declarations[3].semantic_body.body.authored_child_design_input.sha256 ==
            G.Digest256(g3_child_sha)
        @test all(c -> c isa G.VNextT0LocalChildPresentV1, admission.transport.children)
        @test all(c -> c.source_bytes.bytes == g3_child_entry.bytes, admission.transport.children)
        @test admission.transport.declarations[3].source_bytes.sha256 == G.Digest256(g3_builder_input.sha256)
        _up1_stage("r2_v1_recheck_begin")
        recheck_input = G.VNextAuthorityRecheckLocalInputV1(candidate,
            admission.transport, declarations; frozen_context=context)
        recheck = G.vnext_declaration_authority_recheck_local_v1(recheck_input)
        println("UP1_V1_OBSERVED\t", recheck.status, "\t", recheck.resolution,
            "\terrors=", repr(recheck.errors), "\treasons=", repr(recheck.reasons),
            "\thas_output=", recheck.output !== nothing)
        flush(stdout)
        recheck.status === :fail_closed || error(
            "UP1 V1 did not preserve its G3-child compatibility rejection: " *
            "status=$(recheck.status), resolution=$(recheck.resolution), " *
            "errors=$(repr(recheck.errors)), reasons=$(repr(recheck.reasons)), " *
            "has_output=$(recheck.output !== nothing)")
        _up1_stage("r2_v1_recheck_complete")
        @test recheck.status === :fail_closed
        @test :g3_child_present_forbidden in recheck.errors
        @test recheck.output === nothing
        @test recheck.prior_bundle_sha256 == admission.transport.bundle_hash
        _up1_stage("r2_v2_recheck_begin")
        v2_recheck = G.vnext_declaration_authority_recheck_local_v2(
            G.VNextAuthorityRecheckLocalV2Input(candidate, admission.transport))
        println("UP1_V2_OBSERVED\t", v2_recheck.status, "\t",
            v2_recheck.resolution, "\terrors=", repr(v2_recheck.errors),
            "\treasons=", repr(v2_recheck.reasons),
            "\thas_output=", v2_recheck.output !== nothing)
        flush(stdout)
        v2_recheck.status === :local_checked_present || error(
            "UP1 V2 recheck was not local_checked_present: status=$(v2_recheck.status), " *
            "resolution=$(v2_recheck.resolution), errors=$(repr(v2_recheck.errors)), " *
            "reasons=$(repr(v2_recheck.reasons)), has_output=$(v2_recheck.output !== nothing)")
        _up1_stage("r2_v2_recheck_complete")
        @test v2_recheck.status === :local_checked_present
        @test v2_recheck.resolution === :resolved
        @test isempty(v2_recheck.errors) && isempty(v2_recheck.reasons)
        @test v2_recheck.prior_bundle_sha256 == admission.transport.bundle_hash
        @test v2_recheck.output isa G.VNextAuthorityRecheckLocalV2Checked
        @test v2_recheck.output.candidate_ref == candidate
        @test v2_recheck.output.bundle_hash == admission.transport.bundle_hash
        @test all(d -> d isa G.VNextT0LocalPresentDeclarationV1,
            v2_recheck.output.declarations)
        @test all(c -> c isa G.VNextT0LocalChildPresentV1,
            v2_recheck.output.children)
        @test !v2_recheck.output.g3_children_deferred
        parent_commitments = ntuple(i -> G.vnext_t1_parent_commitment_v2(
            candidate, admission.transport.declarations[i]), 2)

        consumer_result = nothing
        expected_receipt_sha256 = nothing
        if mode === :consumer
            consumer_result = Base.invokelatest(_up4_r2_independent_g3_consumer,
                context, candidate, admission, g3_record, t0_receipt,
                t0_receipt_sha256, g3_child_entry, g3_builder_entry,
                g1, g2, v2_recheck, g3_design, g3_child_sha,
                parent_commitments)
            g3_authority_projection = consumer_result.g3_authority
            expected_commitment = consumer_result.expected_commitment
            expected_receipt_sha256 = consumer_result.expected_receipt_sha256
            g3_bridge = consumer_result.g3_bridge
            t1_v2 = consumer_result.t1_v2
        else
            _up1_stage("r2_t1_v2_begin")
            g3_authority_projection = (status=:typed_absent,
                resolution=:terminal_deferred, authority_verified=false,
                expected_commitment=nothing,
                reason=:independent_expected_commitment_missing,
                source_design_sha256=g3_child_sha,
                source_factory_status=g3_factory_present.receipt.status)
            t1_v2 = G.vnext_t1_admit_v2(G.VNextT1AdmissionInputV2(candidate,
                admission.transport, v2_recheck, parent_commitments,
                nothing, g3_authority_projection))
            println("UP1_T1_V2_OBSERVED\t", t1_v2.status, "\t",
                t1_v2.resolution, "\terrors=", repr(t1_v2.errors), "\treasons=n/a",
                "\tgaps=", repr(t1_v2.gaps), "\thas_output=", t1_v2.package !== nothing)
            flush(stdout)
            t1_v2.status === :terminal_deferred || error(
                "UP1 T1 V2 was not terminal_deferred: status=$(t1_v2.status), " *
                "resolution=$(t1_v2.resolution), errors=$(repr(t1_v2.errors)), " *
                "gaps=$(repr(t1_v2.gaps)), has_package=$(t1_v2.package !== nothing)")
            _up1_stage("r2_t1_v2_complete")
            @test t1_v2.package === nothing
            @test :g3_typed_absent in t1_v2.gaps
            @test g3_authority_projection.reason === :independent_expected_commitment_missing
            @test g3_authority_projection.source_factory_status === :present
            @test g3_authority_projection.source_design_sha256 == g3_child_sha
        end
        expected_commitment = consumer_result === nothing ? nothing :
            consumer_result.expected_commitment
        g3_bridge = consumer_result === nothing ? nothing : consumer_result.g3_bridge
        g3_authority_projection = consumer_result === nothing ?
            g3_authority_projection : consumer_result.g3_authority
        @test t1_v2.status === (mode === :consumer ? :prepared_not_executed : :terminal_deferred)
        @test t1_v2.resolution === :terminal_deferred
        @test !t1_v2.accepted && t1_v2.claim_ceiling === :contract_only
        if mode === :consumer
            @test t1_v2.package isa G.CandidateStatePackageV5NextV2
            @test isempty(t1_v2.errors) && t1_v2.gaps == (:t1_runtime_unresolved,)
            @test G.vnext_t1_package_v2_validate(t1_v2.package) === nothing
            @test t1_v2.package.status === :prepared_not_executed
            @test t1_v2.package.resolution === :terminal_deferred
            @test t1_v2.package.g3_authority.binding_state_hash ==
                g3_bridge.binding_state.state_hash
            if haskey(ENV, "UP1_NATIVE_T1_ADMISSION_OUT")
                _up4_r2_write_native_t1_admission(
                    ENV["UP1_NATIVE_T1_ADMISSION_OUT"], t1_v2, context,
                    candidate, ENV["UP1_T0_RECEIPT_PATH"], t0_receipt_sha256,
                    ENV["UP1_G3_EXPECTED_RECEIPT_PATH"], expected_receipt_sha256)
            end
        end
        @test declarations[1] isa G.VNextT0LocalPresentDeclarationV1
        @test declarations[2] isa G.VNextT0LocalPresentDeclarationV1
        present_wrong_candidate = G.QualifiedRefV1(
            "fusionconceptai://candidate-design/wrong", "v5")
        present_wrong_t0 = G.vnext_declaration_transport_local_v1(
            present_wrong_candidate, declarations, children; frozen_context=context)
        @test present_wrong_t0.status === :fail_closed
        @test :snapshot_candidate_mismatch in present_wrong_t0.errors
        present_wrong_v1 = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(present_wrong_candidate,
                admission.transport, declarations; frozen_context=context))
        @test present_wrong_v1.status === :fail_closed
        @test :candidate_mismatch in present_wrong_v1.errors
        @test N.up1_frozen_runtime_git_attempts() == 0
        v1_checked_output = (status=recheck.status, resolution=recheck.resolution,
            errors=recheck.errors, reasons=recheck.reasons,
            has_output=recheck.output !== nothing,
            prior_bundle_sha256=recheck.prior_bundle_sha256,
            g3_child_source_sha256=g3_child_sha,
            child_identity_hashes=Tuple(c.child_identity_hash for c in admission.transport.children),
            children_present=all(c -> c isa G.VNextT0LocalChildPresentV1,
                admission.transport.children))
        v2_output = (status=v2_recheck.status, resolution=v2_recheck.resolution,
            errors=v2_recheck.errors, reasons=v2_recheck.reasons,
            prior_bundle_sha256=v2_recheck.prior_bundle_sha256,
            output_candidate_ref=v2_recheck.output.candidate_ref,
            output_bundle_hash=v2_recheck.output.bundle_hash,
            declaration_identity_hashes=Tuple(d.declaration_identity_hash
                for d in v2_recheck.output.declarations),
            g3_children_deferred=v2_recheck.output.g3_children_deferred)
        g3_authority_output = (status=g3_authority_projection.status,
            authority_verified=hasproperty(g3_authority_projection, :authority_verified) ?
                g3_authority_projection.authority_verified : false,
            reason=hasproperty(g3_authority_projection, :reason) ?
                g3_authority_projection.reason : nothing,
            factory_scope=g3_factory_present.receipt.scope,
            factory_source_sha256=g3_factory_present.receipt.source_sha256,
            expected_commitment=expected_commitment === nothing ? nothing :
                expected_commitment.commitment_hash,
            bridge_status=g3_bridge === nothing ? nothing : g3_bridge.status,
            bridge_binding_state_hash=g3_bridge === nothing ||
                g3_bridge.binding_state === nothing ? nothing :
                g3_bridge.binding_state.state_hash)
        t1_output = (status=t1_v2.status, resolution=t1_v2.resolution,
            accepted=t1_v2.accepted, claim_ceiling=t1_v2.claim_ceiling,
            package_present=t1_v2.package !== nothing, gaps=t1_v2.gaps,
            g3_authority=g3_authority_output,
            g3_expected_commitment=expected_commitment === nothing ? nothing :
                expected_commitment.commitment_hash,
            package_hash=t1_v2.package === nothing ? nothing : t1_v2.package.package_hash,
            package_semantic_identity=t1_v2.package === nothing ? nothing :
                t1_v2.package.semantic_identity,
            package_wire_sha256=t1_v2.package === nothing ? nothing : t1_v2.package.wire.sha256,
            g3_expected_receipt_sha256=expected_receipt_sha256,
            consumer_bridge_sha256=consumer_bridge_sha256,
            consumer_helper_sha256=consumer_helper_sha256,
            t0_receipt_sha256=t0_receipt_sha256)
        result_projection = (status=recheck.status, resolution=recheck.resolution,
            accepted=recheck.accepted, claim_ceiling=recheck.claim_ceiling,
            errors=recheck.errors, reasons=recheck.reasons,
            output=v1_checked_output, prior_bundle_sha256=recheck.prior_bundle_sha256,
            v2_recheck=v2_output, t1_v2=t1_output,
            g1_expression_input=(logical_path=source_projection.entry.logical_path,
                bytes=source_projection.entry.byte_count,
                sha256=source_projection.entry.sha256,
                unknown_source_expression_sha256=source_projection.record.unknown_source_expression_sha256,
                source_expression_sha256=source_projection.record.source_expression_sha256,
                producer_input_snapshot_id=source_projection.record.producer_input_snapshot_id,
                producer_input_manifest_sha256=source_projection.record.producer_input_manifest_sha256,
                compiler_sha256=source_projection.record.compiler_sha256,
                profile_hash=source_projection.record.profile_hash,
                registry_hash=source_projection.record.registry_hash,
                bundle_hash=source_projection.record.bundle_hash,
                bundle_canonical_sha256=source_projection.record.bundle_canonical_sha256))
        println("UP4_R2_REPLAY_IDENTITY\t", context.snapshot_id, "\t",
            context.manifest_sha256, "\t", g1_builder.sha256, "\t",
            g2_builder.sha256, "\t", g3_builder_sha, "\t",
            source_projection.entry.sha256, "\t",
            source_projection.record.unknown_source_expression_sha256, "\t",
            source_projection.record.source_expression_sha256, "\t",
            source_projection.record.compiler_sha256, "\t",
            source_projection.record.profile_hash, "\t",
            source_projection.record.bundle_hash, "\t",
            g3_child_sha, "\t",
            G.canonical_hash(v1_checked_output.child_identity_hashes).value, "\t",
            string(g3_factory_present.receipt.status), "\t",
            string(consumer_helper_sha256 === nothing ? "not_loaded" :
                consumer_helper_sha256), "\t",
            string(consumer_bridge_sha256 === nothing ? "not_loaded" :
                consumer_bridge_sha256), "\t",
            string(expected_receipt_sha256 === nothing ? "absent" :
                expected_receipt_sha256), "\t",
            string(g3_authority_output.bridge_status), "\t",
            string(g3_authority_output.expected_commitment === nothing ? "absent" :
                g3_authority_output.expected_commitment.value), "\t",
            string(g3_authority_output.bridge_binding_state_hash === nothing ? "absent" :
                g3_authority_output.bridge_binding_state_hash.value), "\t",
            string(t1_output.package_semantic_identity === nothing ? "absent" :
                t1_output.package_semantic_identity.value), "\t",
            string(t1_output.package_wire_sha256 === nothing ? "absent" :
                t1_output.package_wire_sha256.value), "\t",
            admission.transport.bundle_hash.value, "\t",
            string(v2_recheck.status), "\t", G.canonical_hash(v2_output).value, "\t",
            string(t1_v2.status), "\t", G.canonical_hash(t1_output).value, "\t",
            G.canonical_hash(result_projection).value)
        flush(stdout)
        return nothing
    end

    # Negative-only process: wrong-candidate T0/V1 checks use typed absence and do not
    # repeat the expensive G1/G2 positive transport path.
    children = _up4_r2_absent_children(candidate)
    absent_declarations = ntuple(i -> G.VNextT0LocalAbsentDeclarationV1(
        G.VNEXT_T0_LOCAL_LAYERS_V1[i], candidate, :missing_material,
        :terminal_deferred), 3)
    absent_admission = G.vnext_declaration_transport_local_v1(candidate,
        absent_declarations, children; frozen_context=context)
    @test absent_admission.status === :valid
    absent_recheck = G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(candidate, absent_admission.transport,
            absent_declarations; frozen_context=context))
    @test absent_recheck.status === :typed_absent
    g3_factory_absent = G.g3_source_authority_factory_v1(:bundle,
        nothing, nothing, nothing, nothing)
    @test g3_factory_absent.receipt.status === :typed_absent
    wrong_g3_candidate = G.QualifiedRefV1(
        "fusionconceptai://candidate-design/wrong-g3", "v5")
    @test_throws ArgumentError G.vnext_t0_g3_absent_from_factory_v1(
        wrong_g3_candidate, g3_design, g3_factory_absent)
    realization_absent_factory = G.g3_source_authority_factory_v1(:realization,
        nothing, nothing, nothing, nothing)
    @test realization_absent_factory.receipt.status === :typed_absent
    @test realization_absent_factory.receipt.scope === :realization
    @test_throws ArgumentError G.vnext_t0_g3_absent_from_factory_v1(
        candidate, g3_design, realization_absent_factory)
    wrong_candidate = G.QualifiedRefV1("fusionconceptai://candidate-design/wrong", "v5")
    wrong_admission = G.vnext_declaration_transport_local_v1(wrong_candidate,
        absent_declarations, children; frozen_context=context)
    @test wrong_admission.status === :fail_closed
    @test :snapshot_candidate_mismatch in wrong_admission.errors
    wrong_recheck = G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(wrong_candidate, absent_admission.transport,
            absent_declarations; frozen_context=context))
    @test wrong_recheck.status === :fail_closed

    fake_g1_status = G.G1IndependentSourceLocatorV1(observations.G1.repository_root,
        observations.G1.observed_head, observations.G1.source_path,
        observations.G1.source_bytes, observations.G1.source_sha256,
        :present, :not_observed, :not_observed, nothing, :up1_frozen_snapshot)
    fake_g1_result = G.g1_source_authority_factory_v1(fake_g1_status, handle,
        G._g1sf_expected_contract(), g1.source_payload, g1_axes,
        g1_constructor, context)
    @test fake_g1_result.receipt.status === :fail_closed
    @test fake_g1_result.receipt.reason === :locator_git_status_claim_invalid
    fake_g1_blob = G.G1IndependentSourceLocatorV1(observations.G1.repository_root,
        observations.G1.observed_head, observations.G1.source_path,
        observations.G1.source_bytes, observations.G1.source_sha256,
        :not_observed, :not_observed, :not_observed, G.Digest256(repeat("0", 64)),
        :up1_frozen_snapshot)
    fake_g1_blob_result = G.g1_source_authority_factory_v1(fake_g1_blob, handle,
        G._g1sf_expected_contract(), g1.source_payload, g1_axes,
        g1_constructor, context)
    @test fake_g1_blob_result.receipt.status === :fail_closed
    @test fake_g1_blob_result.receipt.reason === :locator_git_blob_claim_invalid

    fake_g2_status = G.G2IndependentSourceLocatorV1(observations.G2.repository_root,
        observations.G2.observed_head, observations.G2.source_path,
        observations.G2.source_bytes, observations.G2.source_sha256,
        :present, :not_observed, :not_observed, nothing, :up1_frozen_snapshot)
    fake_g2_result = G.g2_source_authority_factory_v1(fake_g2_status, handle,
        g2.contract_ref, g2.source, g2_axes, g2_constructor, context)
    @test fake_g2_result.receipt.status === :fail_closed
    @test fake_g2_result.receipt.reason === :locator_git_status_claim_invalid
    fake_g2_blob = G.G2IndependentSourceLocatorV1(observations.G2.repository_root,
        observations.G2.observed_head, observations.G2.source_path,
        observations.G2.source_bytes, observations.G2.source_sha256,
        :not_observed, :not_observed, :not_observed, G.Digest256(repeat("0", 64)),
        :up1_frozen_snapshot)
    fake_g2_blob_result = G.g2_source_authority_factory_v1(fake_g2_blob, handle,
        g2.contract_ref, g2.source, g2_axes, g2_constructor, context)
    @test fake_g2_blob_result.receipt.status === :fail_closed
    @test fake_g2_blob_result.receipt.reason === :locator_git_blob_claim_invalid

    mktempdir() do output
        test_root = joinpath(output, "snapshot")
        cp(root, test_root; force=true)
        test_receipt = JSON3.read(String(copy(read(frozen_receipt_path))))
        receipt_dict = JSON3.read(JSON3.write(test_receipt), Dict{String,Any})
        receipt_dict["snapshot_root"] = normpath(abspath(test_root))
        receipt_path = joinpath(output, "freeze_receipt.json")
        function use_test_snapshot()
            raw = Vector{UInt8}(codeunits(JSON3.write(receipt_dict)))
            write(receipt_path, raw)
            ENV["UP1_FROZEN_SNAPSHOT_ROOT"] = test_root
            ENV["UP1_FROZEN_RECEIPT_PATH"] = receipt_path
            ENV["UP1_FROZEN_RECEIPT_SHA256"] = bytes2hex(SHA.sha256(raw))
            _up4_r2_open_snapshot()
        end
        g1_path = joinpath(test_root, split(_UP4_R2_DIR * "/g1_source.jl", '/')...)
        original_g1 = read(g1_path)
        write(g1_path, vcat(original_g1, UInt8[0x20]))
        @test_throws ArgumentError use_test_snapshot()
        write(g1_path, original_g1)
        g2_path = joinpath(test_root, split(_UP4_R2_DIR * "/g2_source.jl", '/')...)
        original_g2 = read(g2_path)
        rm(g2_path)
        @test_throws ArgumentError use_test_snapshot()
        write(g2_path, original_g2)
        write(g2_path, vcat(original_g2, UInt8[0x20]))
        @test_throws ArgumentError use_test_snapshot()
        write(g2_path, original_g2)
        g3_path = joinpath(test_root, split(_UP4_R2_DIR * "/g3_source.jl", '/')...)
        original_g3 = read(g3_path)
        rm(g3_path)
        @test_throws ArgumentError use_test_snapshot()
        write(g3_path, original_g3)
        write(g3_path, vcat(original_g3, UInt8[0x20]))
        @test_throws ArgumentError use_test_snapshot()
        write(g3_path, original_g3)
        g3_child_path = joinpath(test_root,
            split(_UP4_R2_DIR * "/g3_child_design_source.jl", '/')...)
        original_g3_child = read(g3_child_path)
        rm(g3_child_path)
        @test_throws ArgumentError use_test_snapshot()
        write(g3_child_path, original_g3_child)
        write(g3_child_path, vcat(original_g3_child, UInt8[0x20]))
        @test_throws ArgumentError use_test_snapshot()
        write(g3_child_path, original_g3_child)
        expression_path = joinpath(test_root,
            split(_UP4_R2_DIR * "/native_mms_source_expressions.json", '/')...)
        original_expression_record = read(expression_path)
        rm(expression_path)
        try
            use_test_snapshot()
            error("missing frozen G1 expression record was not rejected")
        catch err
            err isa ArgumentError || rethrow()
        end
        write(expression_path, original_expression_record)
        write(expression_path, vcat(original_expression_record, UInt8[0x20]))
        try
            use_test_snapshot()
            error("tampered frozen G1 expression record was not rejected")
        catch err
            err isa ArgumentError || rethrow()
        end
        write(expression_path, original_expression_record)
        manifest_path = joinpath(test_root, "manifest.toml")
        original_manifest = read(manifest_path)
        write(manifest_path, "not = [valid")
        @test_throws ArgumentError use_test_snapshot()
        write(manifest_path, original_manifest)

        workspace_root = get(ENV, "UP1_WORKSPACE_ROOT", "")
        isempty(workspace_root) && error("UP1_WORKSPACE_ROOT must name the live repository")
        workspace_root = normpath(abspath(workspace_root))
        realpath(workspace_root) != realpath(context.source_root) ||
            error("workspace mutation control must not target the frozen snapshot")
        receipt_for_workspace = JSON3.read(String(copy(read(frozen_receipt_path))))
        workspace_pins = Dict(String(row.logical_path) => lowercase(String(row.sha256))
            for row in receipt_for_workspace.entries)
        workspace_g1_rel = _UP4_R2_DIR * "/g1_source.jl"
        workspace_g2_rel = _UP4_R2_DIR * "/g2_source.jl"
        workspace_expression_rel = _UP4_R2_DIR * "/native_mms_source_expressions.json"
        workspace_g3_child_rel = _UP4_R2_DIR * "/g3_child_design_source.jl"
        workspace_g1 = joinpath(workspace_root, split(workspace_g1_rel, '/')...)
        workspace_g2 = joinpath(workspace_root, split(workspace_g2_rel, '/')...)
        workspace_expression = joinpath(workspace_root, split(workspace_expression_rel, '/')...)
        workspace_g3_child = joinpath(workspace_root, split(workspace_g3_child_rel, '/')...)
        workspace_g1_before, workspace_g2_before, workspace_expression_before,
            workspace_g3_child_before = read(workspace_g1), read(workspace_g2),
            read(workspace_expression), read(workspace_g3_child)
        bytes2hex(SHA.sha256(workspace_g1_before)) == workspace_pins[workspace_g1_rel] ||
            error("workspace G1 input differs from freeze receipt before mutation")
        bytes2hex(SHA.sha256(workspace_g2_before)) == workspace_pins[workspace_g2_rel] ||
            error("workspace G2 input differs from freeze receipt before mutation")
        bytes2hex(SHA.sha256(workspace_expression_before)) == workspace_pins[workspace_expression_rel] ||
            error("workspace G1 expression input differs from freeze receipt before mutation")
        bytes2hex(SHA.sha256(workspace_g3_child_before)) == workspace_pins[workspace_g3_child_rel] ||
            error("workspace G3 child input differs from freeze receipt before mutation")
        try
            write(workspace_g1, vcat(workspace_g1_before, UInt8[0x20]))
            write(workspace_g2, vcat(workspace_g2_before, UInt8[0x20]))
            write(workspace_expression, vcat(workspace_expression_before, UInt8[0x20]))
            write(workspace_g3_child, vcat(workspace_g3_child_before, UInt8[0x20]))
            reread = Base.invokelatest(G.up4_r2_build_factory_locators, context)
            @test reread.audit_inputs.candidate.G1_design.bytes == g1_builder.bytes
            @test reread.audit_inputs.candidate.G2_design.bytes == g2_builder.bytes
            reread.audit_inputs.candidate.G1_expressions.bytes == expression_entry.bytes ||
                error("workspace changes altered frozen expression input")
            reread.audit_inputs.candidate.G3_child_design.bytes == g3_child_entry.bytes ||
                error("workspace changes altered frozen G3 child input")
            @test reread.G1.observed_head == "up1:" * context.snapshot_id
            @test reread.G2.observed_head == "up1:" * context.snapshot_id
            @test N.up1_frozen_runtime_git_attempts() == 0
        finally
            write(workspace_g1, workspace_g1_before)
            write(workspace_g2, workspace_g2_before)
            write(workspace_expression, workspace_expression_before)
            write(workspace_g3_child, workspace_g3_child_before)
            bytes2hex(SHA.sha256(read(workspace_g1))) == workspace_pins[workspace_g1_rel] ||
                error("workspace G1 input was not restored to freeze receipt pin")
            bytes2hex(SHA.sha256(read(workspace_g2))) == workspace_pins[workspace_g2_rel] ||
                error("workspace G2 input was not restored to freeze receipt pin")
            bytes2hex(SHA.sha256(read(workspace_expression))) == workspace_pins[workspace_expression_rel] ||
                error("workspace G1 expression input was not restored to freeze receipt pin")
            bytes2hex(SHA.sha256(read(workspace_g3_child))) == workspace_pins[workspace_g3_child_rel] ||
                error("workspace G3 child input was not restored to freeze receipt pin")
        end
    end
end

function _up1_n03_r54_targeted_preflight()
    envpath(name) = begin
        value = get(ENV, name, "")
        isempty(value) && error("$name is required for the R54 N03 targeted preflight")
        normpath(abspath(value))
    end
    artifact_path = envpath("UP1_N03_R54_ARTIFACT_PATH")
    sidecar_path = envpath("UP1_N03_R54_SIDECAR_PATH")
    freeze_receipt_path = envpath("UP1_N03_R54_FREEZE_RECEIPT_PATH")
    implementation_path = envpath("UP1_N03_IMPLEMENTATION_PATH")
    implementation_sha256 = lowercase(get(ENV, "UP1_N03_IMPLEMENTATION_SHA256", ""))
    occursin(r"^[0-9a-f]{64}$", implementation_sha256) ||
        error("UP1_N03_IMPLEMENTATION_SHA256 must pin the implementation bytes")

    artifact_bytes = read(artifact_path)
    sidecar = JSON3.read(String(copy(read(sidecar_path))))
    @test sidecar.schema == "up1-native-t1-admission-artifact-sidecar-v1"
    @test normpath(abspath(String(sidecar.artifact_path))) == artifact_path
    @test Int(sidecar.artifact_bytes) == length(artifact_bytes)
    @test bytes2hex(SHA.sha256(artifact_bytes)) == String(sidecar.artifact_sha256)
    @test normpath(abspath(String(sidecar.freeze_receipt_path))) == freeze_receipt_path

    freeze_receipt_bytes = read(freeze_receipt_path)
    @test bytes2hex(SHA.sha256(freeze_receipt_bytes)) ==
        String(sidecar.freeze_receipt_sha256)
    receipt = JSON3.read(String(copy(freeze_receipt_bytes)))
    @test receipt.schema == "up1-candidate-freeze-receipt-v1"
    @test receipt.snapshot_id == sidecar.snapshot_id
    @test receipt.manifest_sha256 == sidecar.manifest_sha256
    @test receipt.scenario_id == sidecar.scenario_id
    @test receipt.candidate_ref == sidecar.candidate_ref.id
    manifest_path = joinpath(String(receipt.snapshot_root), "manifest.toml")
    manifest_bytes = read(manifest_path)
    @test bytes2hex(SHA.sha256(manifest_bytes)) == String(receipt.manifest_sha256)
    manifest = TOML.parse(String(copy(manifest_bytes)))
    @test manifest["snapshot"]["snapshot_id"] == String(sidecar.snapshot_id)
    @test manifest["snapshot"]["candidate_ref"] == String(sidecar.candidate_ref.id)
    @test manifest["snapshot"]["scenario_id"] == String(sidecar.scenario_id)

    source_paths = (
        g1_builder=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g1_source.jl", role="candidate_design_source"),
        g1_declaration_source=(path="src/GenomeV5/G1/DiffusionDeclarationV1.jl", role="production_source"),
        g2_builder=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g2_source.jl", role="candidate_design_source"),
        g2_declaration_source=(path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl", role="production_source"),
        g3_builder=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g3_source.jl", role="candidate_design_source"),
        g3_child_design=(path="benchmarks/candidate_designs/local-authored-up4-g123-20260928-r2/g3_child_design_source.jl", role="candidate_design_source"),
    )
    pin_for(pin_receipt, manifest_entries, logical_path, expected_role) = begin
        rows = filter(row -> row.logical_path == logical_path, pin_receipt.entries)
        length(rows) == 1 || error("freeze receipt lacks unique source pin $logical_path")
        row = only(rows)
        row.role == expected_role ||
            error("unexpected freeze receipt role for $logical_path")
        manifest_rows = filter(entry -> entry["logical_path"] == logical_path,
            manifest_entries)
        length(manifest_rows) == 1 ||
            error("snapshot manifest lacks unique source pin $logical_path")
        manifest_row = only(manifest_rows)
        @test manifest_row["role"] == row.role
        @test Int(manifest_row["bytes"]) == Int(row.bytes)
        @test String(manifest_row["sha256"]) == String(row.sha256)
        raw = read(joinpath(String(pin_receipt.snapshot_root), split(logical_path, '/')...))
        @test length(raw) == Int(row.bytes)
        @test bytes2hex(SHA.sha256(raw)) == String(row.sha256)
        (bytes=Int(row.bytes), sha256=G.Digest256(String(row.sha256)))
    end
    source_pins = (; (role => pin_for(receipt, manifest["entries"], source.path, source.role)
        for (role, source) in pairs(source_paths))...)

    contracts_root = normpath(joinpath(dirname(implementation_path), "..", "..", "Contracts"))
    for (file, sentinel) in (("VNextT1CandidateBindingV2.jl", :VNextT1CandidateBindingInputV2),
            ("VNextT1PackageBindingAdapterV2.jl", :VNextT1PackageBindingAdapterResultV2))
        path = joinpath(contracts_root, file)
        raw = read(path)
        digest = bytes2hex(SHA.sha256(raw))
        isdefined(G, sentinel) && error(
            "run the targeted preflight in a fresh process; $sentinel is already loaded")
        Base.include_string(G, String(copy(raw)), path)
        println("UP1_N03_CURRENT_DEFINITION\t", path, "\t", length(raw), "\t", digest)
    end

    implementation_bytes = read(implementation_path)
    @test bytes2hex(SHA.sha256(implementation_bytes)) == implementation_sha256
    isdefined(G, :N03VNextLocalEventProjectionV1) && error(
        "run the targeted preflight in a fresh process so the explicitly pinned N03 implementation is loaded")
    Base.include_string(G, String(copy(implementation_bytes)), implementation_path)

    admission = Serialization.deserialize(IOBuffer(artifact_bytes))
    @test admission isa G.VNextT1AdmissionResultV2
    @test admission.package isa G.CandidateStatePackageV5NextV2
    package = admission.package
    @test admission.status === :prepared_not_executed
    @test admission.resolution === :terminal_deferred
    @test !admission.accepted && admission.claim_ceiling === :contract_only
    @test package.package_hash.value == String(sidecar.package_hash)
    @test package.semantic_identity.value == String(sidecar.package_semantic_identity)
    @test package.bundle_hash.value == String(sidecar.package_bundle_hash)

    candidate_ref = G.QualifiedRefV1(String(sidecar.candidate_ref.id),
        String(sidecar.candidate_ref.version))
    prefix = "fusionconceptai://candidate-design/"
    startswith(candidate_ref.id, prefix) || error("R54 candidate reference has an unexpected namespace")
    candidate_id = candidate_ref.id[length(prefix)+1:end]
    projection_args = (; candidate_ref, candidate_id, scenario_id=String(sidecar.scenario_id),
        snapshot_id=String(sidecar.snapshot_id),
        manifest_sha256=G.Digest256(String(sidecar.manifest_sha256)),
        package_hash=package.package_hash, semantic_identity=package.semantic_identity,
        bundle_hash=package.bundle_hash)

    @testset "R54 actual T1 package to current N03 targeted preflight" begin
        projected = Base.invokelatest(G.n03_vnext_t1_local_event_projection, package;
            projection_args..., source_pins=source_pins)
        binding_error = hasproperty(projected, :errors) ? repr(projected.errors) : "not_exposed"
        println("UP1_N03_R54_OBSERVED\tstatus=", projected.status,
            "\tresolution=", projected.resolution, "\treason=", projected.reason,
            "\tauthority_gap=", repr(projected.authority_gap),
            "\tbinding_error=", binding_error)
        flush(stdout)
        @test projected.status === :local_source_bound
        @test projected.resolution === :terminal_deferred
        @test projected.event_id == "initial_enable"
        @test projected.trigger === :initial
        @test projected.time == 0//1
        @test projected.time_basis === nothing

        missing_pins = Base.invokelatest(G.n03_vnext_t1_local_event_projection, package;
            projection_args..., source_pins=nothing)
        @test missing_pins.status === :typed_absent
        @test missing_pins.resolution === :terminal_deferred

        wrong_hash_pins = merge(source_pins,
            (; g3_builder=(bytes=source_pins.g3_builder.bytes,
                sha256=G.Digest256(repeat("0", 64)))))
        wrong_hash = Base.invokelatest(G.n03_vnext_t1_local_event_projection, package;
            projection_args..., source_pins=wrong_hash_pins)
        @test wrong_hash.status === :fail_closed
        @test wrong_hash.resolution === :none

        wrong_candidate_ref = G.QualifiedRefV1(
            "fusionconceptai://candidate-design/not-r54", "v5")
        wrong_candidate = Base.invokelatest(G.n03_vnext_t1_local_event_projection, package;
            candidate_ref=wrong_candidate_ref, candidate_id=candidate_id,
            scenario_id=projection_args.scenario_id,
            snapshot_id=projection_args.snapshot_id,
            manifest_sha256=projection_args.manifest_sha256,
            package_hash=projection_args.package_hash,
            semantic_identity=projection_args.semantic_identity,
            bundle_hash=projection_args.bundle_hash, source_pins=source_pins)
        @test wrong_candidate.status === :fail_closed
        @test wrong_candidate.resolution === :none
    end
    println("UP1_N03_R54_PREFLIGHT\tartifact_sha256=", sidecar.artifact_sha256,
        "\tfreeze_receipt_sha256=", sidecar.freeze_receipt_sha256,
        "\timplementation_sha256=", implementation_sha256)
    flush(stdout)

    r55_artifact_env = get(ENV, "UP1_N03_R55_ARTIFACT_PATH", "")
    if !isempty(r55_artifact_env)
        r55_artifact_path = normpath(abspath(r55_artifact_env))
        r55_sidecar_path = envpath("UP1_N03_R55_SIDECAR_PATH")
        r55_freeze_receipt_path = envpath("UP1_N03_R55_FREEZE_RECEIPT_PATH")
        r55_artifact_bytes = read(r55_artifact_path)
        r55_sidecar = JSON3.read(String(copy(read(r55_sidecar_path))))
        @test r55_sidecar.schema == "up1-native-t1-admission-artifact-sidecar-v1"
        @test normpath(abspath(String(r55_sidecar.artifact_path))) == r55_artifact_path
        @test Int(r55_sidecar.artifact_bytes) == length(r55_artifact_bytes)
        @test bytes2hex(SHA.sha256(r55_artifact_bytes)) == String(r55_sidecar.artifact_sha256)
        @test normpath(abspath(String(r55_sidecar.freeze_receipt_path))) == r55_freeze_receipt_path

        r55_freeze_receipt_bytes = read(r55_freeze_receipt_path)
        @test bytes2hex(SHA.sha256(r55_freeze_receipt_bytes)) ==
            String(r55_sidecar.freeze_receipt_sha256)
        r55_receipt = JSON3.read(String(copy(r55_freeze_receipt_bytes)))
        @test r55_receipt.schema == "up1-candidate-freeze-receipt-v1"
        @test r55_receipt.snapshot_id == r55_sidecar.snapshot_id
        @test r55_receipt.manifest_sha256 == r55_sidecar.manifest_sha256
        @test r55_receipt.scenario_id == r55_sidecar.scenario_id
        @test r55_receipt.candidate_ref == r55_sidecar.candidate_ref.id
        r55_manifest_path = joinpath(String(r55_receipt.snapshot_root), "manifest.toml")
        r55_manifest_bytes = read(r55_manifest_path)
        @test bytes2hex(SHA.sha256(r55_manifest_bytes)) == String(r55_receipt.manifest_sha256)
        r55_manifest = TOML.parse(String(copy(r55_manifest_bytes)))
        @test r55_manifest["snapshot"]["snapshot_id"] == String(r55_sidecar.snapshot_id)
        @test r55_manifest["snapshot"]["candidate_ref"] == String(r55_sidecar.candidate_ref.id)
        @test r55_manifest["snapshot"]["scenario_id"] == String(r55_sidecar.scenario_id)

        r55_source_pins = (; (role => pin_for(r55_receipt, r55_manifest["entries"],
            source.path, source.role)
            for (role, source) in pairs(source_paths))...)
        @test r55_source_pins.g3_child_design.sha256.value ==
            "93666f2306a93039a874dcc352df653d19ecf2dc8385502ea587b37d9560cc71"
        r55_admission = Serialization.deserialize(IOBuffer(r55_artifact_bytes))
        @test r55_admission isa G.VNextT1AdmissionResultV2
        @test r55_admission.package isa G.CandidateStatePackageV5NextV2
        r55_package = r55_admission.package
        @test r55_admission.status === :prepared_not_executed
        @test r55_admission.resolution === :terminal_deferred
        @test !r55_admission.accepted && r55_admission.claim_ceiling === :contract_only
        @test r55_package.package_hash.value == String(r55_sidecar.package_hash)
        @test r55_package.semantic_identity.value == String(r55_sidecar.package_semantic_identity)
        @test r55_package.bundle_hash.value == String(r55_sidecar.package_bundle_hash)

        r55_candidate_ref = G.QualifiedRefV1(String(r55_sidecar.candidate_ref.id),
            String(r55_sidecar.candidate_ref.version))
        @test r55_candidate_ref == candidate_ref
        r55_projection_args = (; candidate_ref=r55_candidate_ref, candidate_id,
            scenario_id=String(r55_sidecar.scenario_id),
            snapshot_id=String(r55_sidecar.snapshot_id),
            manifest_sha256=G.Digest256(String(r55_sidecar.manifest_sha256)),
            package_hash=r55_package.package_hash,
            semantic_identity=r55_package.semantic_identity,
            bundle_hash=r55_package.bundle_hash)

        @testset "R55 actual T1 package consumes candidate design event-time policy" begin
            # This projection API has no compile/provider/solver invocation counter;
            # zero calls here are supported by its code path only.
            r55_projected = Base.invokelatest(G.n03_vnext_t1_local_event_projection,
                r55_package; r55_projection_args..., source_pins=r55_source_pins)
            @test r55_projected.status === :local_source_bound
            @test r55_projected.resolution === :terminal_deferred
            @test r55_projected.reason === :candidate_design_event_time_policy_consumed
            @test r55_projected.event_id == "initial_enable"
            @test r55_projected.trigger === :initial
            @test r55_projected.time == 0//1
            @test r55_projected.time_basis === :event
            @test r55_projected.authority_scope === :local_source_data
            @test r55_projected.authority_gap == "candidate_authored_event_time_policy_is_design_only"

            g3_declaration = only(filter(d -> d.layer === :G3, r55_package.declarations))
            g3_body = JSON3.read(String(G.copy_bytes(g3_declaration.semantic_body_bytes)))
            policy = g3_body.authored_child_design.control_design.event_time_policy
            @test String(policy.basis) == "event"
            @test String(policy.unit) == "second"
            @test String(policy.clock) == "controller_elapsed"
            @test String(policy.origin) == "controller_initialization"
            @test String(policy.initial_trigger) == "initial"
            @test Int(policy.initial_time.numerator) == 0
            @test Int(policy.initial_time.denominator) == 1

            r55_missing_pins = Base.invokelatest(G.n03_vnext_t1_local_event_projection,
                r55_package; r55_projection_args..., source_pins=nothing)
            @test r55_missing_pins.status === :typed_absent
            @test r55_missing_pins.resolution === :terminal_deferred
        end
        println("UP1_N03_R55_PREFLIGHT\tartifact_sha256=", r55_sidecar.artifact_sha256,
            "\tfreeze_receipt_sha256=", r55_sidecar.freeze_receipt_sha256,
            "\tg3_child_design_sha256=", r55_source_pins.g3_child_design.sha256.value)
        flush(stdout)
    end
end

_up1_stage("r2_run_definition_complete")
_up1_stage("mode_dispatch_begin")

const _UP1_FROZEN_SOURCE_MODE = get(ENV, "UP1_FROZEN_SOURCE_MODE", "default")
if _UP1_FROZEN_SOURCE_MODE == "up4_r2_positive"
    @testset "UP1 neutral frozen reader with UP4 R2 authored G1/G2 positive" begin
        _up4_r2_run(:positive)
    end
elseif _UP1_FROZEN_SOURCE_MODE == "up4_r2_negatives"
    @testset "UP1 neutral frozen reader with UP4 R2 authored G1/G2 negatives" begin
        _up4_r2_run(:negatives)
    end
elseif _UP1_FROZEN_SOURCE_MODE == "up4_r2_consumer"
    @testset "UP1 neutral frozen reader with UP4 R2 independent G3 consumer" begin
        _up4_r2_run(:consumer)
    end
elseif _UP1_FROZEN_SOURCE_MODE == "up4_r2_native_reload"
    # Load only the frozen type and builder definitions for a separate process
    # that deserializes the producer's actual T1 admission artifact.
elseif _UP1_FROZEN_SOURCE_MODE == "n03_r54_targeted_preflight"
    @testset "N03 actual R54 package targeted preflight" begin
        _up1_n03_r54_targeted_preflight()
    end
elseif _UP1_FROZEN_SOURCE_MODE == "default"
@testset "UP1 neutral frozen reader through T0 and V1 recheck" begin
    mktempdir() do root
        context = _up1_write_snapshot(root)
        _, parsed_entries = N._up1_manifest_entries(
            TOML.parsefile(joinpath(root, "manifest.toml")))
        @test all(pin -> pin isa NamedTuple, values(parsed_entries))
        locator = G.VNextT0LocalSourceLocatorV1(root, _UP1_SOURCE_PATH,
            _UP1_SOURCE_REF.id, _UP1_SOURCE_REF, length(_UP1_SOURCE_BYTES),
            G.Digest256(_UP1_SOURCE_SHA), "frozen-input", :present, :present,
            :clean, nothing, :repository_head)

        @test_throws ArgumentError G._vnl_t0_locator_bytes(locator; frozen_context=context)
        @test_throws ArgumentError N.frozen_source(context, _UP1_SOURCE_PATH)
        @test N.activate_up1_frozen_runtime!(context)
        @test G._vnl_t0_locator_bytes(locator; frozen_context=context) == _UP1_SOURCE_BYTES
        @test_throws ArgumentError G._vnl_t0_locator_bytes(locator)
        @test G._vnl_t0_snapshot_candidate_matches(context, _UP1_CANDIDATE)
        wrong_candidate = G.QualifiedRefV1("local://candidate/other", "v5")
        @test !G._vnl_t0_snapshot_candidate_matches(context, wrong_candidate)
        mktempdir() do other_root
            other_context = _up1_write_snapshot(other_root)
            @test_throws ArgumentError N.frozen_source(other_context, _UP1_SOURCE_PATH)
            @test N.frozen_source(context, _UP1_SOURCE_PATH).bytes == _UP1_SOURCE_BYTES
        end

        absent_declarations = ntuple(i -> G.VNextT0LocalAbsentDeclarationV1(
            G.VNEXT_T0_LOCAL_LAYERS_V1[i], _UP1_CANDIDATE, :missing_material,
            :terminal_deferred), 3)
        receipt_bytes = G.VNextT0LocalBytesV1(Vector{UInt8}(codeunits("{}")),
            G.Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits("{}"))))))
        child_kinds = (:realization, :control, :binding)
        absent_children = ntuple(i -> G.VNextT0LocalChildAbsentV1(child_kinds[i],
            _UP1_CANDIDATE, :G3, String(child_kinds[i]), :terminal_deferred,
            "missing material", false, :G3, receipt_bytes, receipt_bytes.sha256,
            "src/GenomeV5/G3/" * String(child_kinds[i]) * ".jl"), 3)
        wrong_candidate_admission = G.vnext_declaration_transport_local_v1(
            wrong_candidate, absent_declarations, absent_children;
            frozen_context=context)
        @test wrong_candidate_admission.status === :fail_closed
        @test :snapshot_candidate_mismatch in wrong_candidate_admission.errors
        mapped_admission = G.vnext_declaration_transport_local_v1(_UP1_CANDIDATE,
            absent_declarations, absent_children;
            frozen_contexts=Dict((_UP1_SOURCE_PATH, _UP1_SOURCE_SHA) => context))
        @test mapped_admission.status === :fail_closed
        @test :up1_singular_context_required in mapped_admission.errors
        admission = G.vnext_declaration_transport_local_v1(_UP1_CANDIDATE,
            absent_declarations, absent_children; frozen_context=context)
        @test admission.status === :valid
        bundle = admission.transport
        @test bundle.frozen_source_authority.scenario_id == context.scenario_id
        recheck = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_UP1_CANDIDATE, bundle,
                absent_declarations; frozen_context=context))
        @test recheck.status === :typed_absent
        missing_context_recheck = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_UP1_CANDIDATE, bundle,
                absent_declarations))
        @test missing_context_recheck.status === :fail_closed
        @test :frozen_source_context_missing in missing_context_recheck.errors
        wrong_recheck = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(wrong_candidate, bundle,
                absent_declarations; frozen_context=context))
        @test wrong_recheck.status === :fail_closed
        @test :candidate_mismatch in wrong_recheck.errors

        present_g1 = _up1_present_g1(context)
        @test present_g1 isa G.VNextT0LocalPresentDeclarationV1
        @test present_g1.source_locator.provenance === :isolated_test_fixture
        @test present_g1.source_bytes.bytes == N.frozen_source(context,
            G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1).bytes
        present_declarations = (present_g1, absent_declarations[2],
            absent_declarations[3])
        present_admission = G.vnext_declaration_transport_local_v1(
            _UP1_CANDIDATE, present_declarations, absent_children;
            frozen_context=context)
        @test present_admission.status === :valid
        @test present_admission.transport.frozen_source_authority ==
            bundle.frozen_source_authority
        present_recheck = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_UP1_CANDIDATE,
                present_admission.transport, present_declarations;
                frozen_context=context))
        @test present_recheck.status === :typed_absent
        @test :g1_material_absent ∉ present_recheck.reasons
        @test !(:frozen_source_authority_mismatch in present_recheck.errors)
        original_manifest = read(joinpath(root, "manifest.toml"))
        alternate_context = _up1_write_snapshot(root; scenario_id="scenario-test-002")
        write(joinpath(root, "manifest.toml"), original_manifest)
        alternate_identity_recheck = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_UP1_CANDIDATE,
                present_admission.transport, present_declarations;
                frozen_context=alternate_context))
        @test alternate_identity_recheck.status === :fail_closed
        @test :frozen_source_authority_mismatch in alternate_identity_recheck.errors
        missing_present_context = G.vnext_declaration_authority_recheck_local_v1(
            G.VNextAuthorityRecheckLocalInputV1(_UP1_CANDIDATE,
                present_admission.transport, present_declarations))
        @test missing_present_context.status === :fail_closed
        @test :frozen_source_context_missing in missing_present_context.errors
        @test_throws ArgumentError G._vnl_t0_locator_bytes(
            present_g1.source_locator)

        workspace_copy = joinpath(dirname(root), basename(root) * "_workspace_input.jl")
        write(workspace_copy, "edited after the freeze")
        @test G._vnl_t0_locator_bytes(locator; frozen_context=context) == _UP1_SOURCE_BYTES
        rm(workspace_copy; force=true)

        write(joinpath(root, split(_UP1_SOURCE_PATH, '/')...), "tampered")
        @test_throws ArgumentError N.frozen_source(context, _UP1_SOURCE_PATH)
        write(joinpath(root, split(_UP1_SOURCE_PATH, '/')...), _UP1_SOURCE_BYTES)
        write(joinpath(root, "manifest.toml"), "not = [valid")
        @test_throws ArgumentError N.frozen_source(context, _UP1_SOURCE_PATH)
        @test_throws ArgumentError N.git_text(root, "status")
        @test N.up1_frozen_runtime_git_attempts() == 1
        audit = N.up1_frozen_runtime_git_audit()
        @test length(audit) == 1
        @test only(audit).api_name == "git_text"
        expected_identity = (context.snapshot_id, context.manifest_sha256,
            context.candidate_ref, context.scenario_id, context.source_root)
        @test only(audit).identity == expected_identity
    end

    mktempdir() do root
        context = _up1_write_snapshot(root)
        write(joinpath(root, "unlisted.txt"), "extra")
        @test context isa N.UP1FrozenSourceContextV1
        @test_throws ArgumentError N.UP1FrozenSourceContextV1(root,
            joinpath(root, "manifest.toml");
            expected_snapshot_id=context.snapshot_id,
            expected_manifest_sha256=context.manifest_sha256,
            expected_candidate_ref=context.candidate_ref,
            expected_scenario_id=context.scenario_id,
            expected_entries=context.expected_entries)
    end

    mktempdir() do root
        context = _up1_write_snapshot(root)
        manifest_root = joinpath(root, "other")
        mkpath(manifest_root)
        @test_throws ArgumentError N.UP1FrozenSourceContextV1(root,
            joinpath(manifest_root, "manifest.toml");
            expected_snapshot_id=context.snapshot_id,
            expected_manifest_sha256=context.manifest_sha256,
            expected_candidate_ref=context.candidate_ref,
            expected_scenario_id=context.scenario_id,
            expected_entries=context.expected_entries)
    end

    mktempdir() do root
        context = _up1_write_snapshot(root)
        rm(joinpath(root, split(_UP1_SOURCE_PATH, '/')...); force=true)
        @test_throws ArgumentError N.UP1FrozenSourceContextV1(root,
            joinpath(root, "manifest.toml");
            expected_snapshot_id=context.snapshot_id,
            expected_manifest_sha256=context.manifest_sha256,
            expected_candidate_ref=context.candidate_ref,
            expected_scenario_id=context.scenario_id,
            expected_entries=context.expected_entries)
    end
end
else
    error("unknown UP1_FROZEN_SOURCE_MODE: " * _UP1_FROZEN_SOURCE_MODE)
end
