using Test
using SHA
using FusionConceptAI

const _T0L_ROOT = joinpath(@__DIR__, "..", "..", "..", "src")
const _T0L_REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _T0L = FusionConceptAI
const G = FusionConceptAI
G.load_genome_v5_components!()
Base.include(_T0L, joinpath(_T0L_ROOT, "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
Base.include(_T0L, joinpath(_T0L_ROOT, "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))
Base.include(_T0L, joinpath(_T0L_ROOT, "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
Base.include(_T0L, joinpath(_T0L_ROOT, "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))
Base.include(_T0L, joinpath(_T0L_ROOT, "GenomeV5", "G3", "G3SourceFeedbackLawV1.jl"))
Base.include(_T0L, joinpath(_T0L_ROOT, "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
Base.include(_T0L, joinpath(_T0L_ROOT, "GenomeV5", "Integration", "VNextDeclarationTransportLocalV1.jl"))
# Current factory APIs are included so receipt/declaration records remain
# compatible with the real source-authority boundary: g1_source_authority_factory_v1,
# g2_source_authority_factory_v1, g3_source_authority_factory_v1.

_t0l_sha(x) = G.Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(x)))))
_t0l_bytes(text) = begin b = Vector{UInt8}(codeunits(text)); G.VNextT0LocalBytesV1(b, _t0l_sha(b)) end
const _T0L_CANDIDATE = G.QualifiedRefV1("local://candidate/up1-04a", "v5")
const _T0L_AXES = ntuple(i -> G.QualifiedRefV1(G.VNEXT_T0_LOCAL_AXIS_IDS_V1[i], "v1"), 4)

function _t0l_local_locator(path, source_ref, source_bytes;
        provenance=:repository_head, root=_T0L_REPO)
    root = realpath(root)
    head = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD"]))
    head_blob = try
        hb = read(Cmd(["git", "-C", root, "show", "HEAD:" * path])); _t0l_sha(hb)
    catch
        nothing
    end
    G.VNextT0LocalSourceLocatorV1(root, path, source_ref.id, source_ref,
        length(source_bytes.bytes), source_bytes.sha256, head, :present,
        :present, :clean, head_blob, provenance)
end

function _t0l_g1(candidate=_T0L_CANDIDATE)
    zero = G.UnitSignature(); grad_u = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0)); div_u = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    scalar = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), zero)
    grad_type = G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), grad_u)
    tensor = G.PhysicalType(:tensor_field, 2, 3, G.TemporalTypeV1(G.static_time), zero)
    f_type = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), div_u)
    source = G.QualifiedRefV1("local://g1/source", "v1")
    u = G.G1DiffusionScalarFieldV1("u_candidate", scalar, source; source_expression="u_candidate(x)=x1+x2+x3")
    expr = G.G1DiffusionDiagonalAffineKFieldV1("K_candidate_x_affine")
    k = G.G1DiffusionCoefficientFieldV1("K_candidate_x", tensor, source; lower_bound=2 // 1, upper_bound=121 // 30, expression=expr)
    f = G.G1DiffusionScalarFieldV1("f_candidate", f_type, source; source_expression="f_candidate(x)=1")
    grad = G.G1TypedGradV1(G.QualifiedRefV1(G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"), "u_candidate", "grad_u", scalar, grad_type)
    apply = G.G1TypedKApplyV1(G.QualifiedRefV1(G.G1_DIFFUSION_K_APPLY_OPERATOR_ID_V1, "v1"), "grad_u", "flux_u", grad_type, grad_type, "K_candidate_x")
    div = G.G1TypedDivV1(G.QualifiedRefV1(G.G1_DIFFUSION_DIV_OPERATOR_ID_V1, "v1"), "flux_u", "f_candidate", grad_type, f_type)
    chain = G.G1DiffusionOperatorChainV1(grad, apply, div, "f_candidate")
    payload = G.G1DiffusionSourcePayloadV1(candidate, source, "local-g1-source-v1", u, k, f)
    payload.candidate_ref == candidate || throw(ArgumentError("G1 payload candidate binding mismatch"))
    payload.source_ref == source || throw(ArgumentError("G1 payload source binding mismatch"))
    payload.u.source_ref == source && payload.K.source_ref == source && payload.f.source_ref == source ||
        throw(ArgumentError("G1 payload field source binding mismatch"))
    closure_ref = G.QualifiedRefV1(G.G1_DIFFUSION_CLOSURE_ID_V1, G.G1_DIFFUSION_PROFILE_VERSION_V1)
    applicability_ref = G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1, G.G1_DIFFUSION_PROFILE_VERSION_V1)
    declaration = G.g1_diffusion_declaration_v1(candidate, source, "local-g1-source-v1",
        G.g1_diffusion_source_hash_v1(payload), u, k, f, chain, closure_ref,
        applicability_ref, "bounded-3d-local", (:local_test,); source_payload=payload)
    declaration.closure_ref == closure_ref || throw(ArgumentError("G1 closure profile binding mismatch"))
    declaration.applicability_ref == applicability_ref ||
        throw(ArgumentError("G1 applicability profile binding mismatch"))
    declaration
end

function _t0l_g2(candidate=_T0L_CANDIDATE; variant=false)
    chart_ref = G.QualifiedRefV1("local://g2/chart", "v1"); mesh_ref = G.QualifiedRefV1("local://g2/mesh", "v1")
    chart = G.G2MBChartMapV1(chart_ref, variant ? (0,0,-1) : (0,0,0), (1,1,1), ((2,0,0),(0,3,0),(0,0,4)), (1//2,1//3,1//4))
    mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, (2,3,4), :Q1, ((1//2,1//2,1//2),), (1,); execution_status=:not_executed)
    fu = G.UnitSignature((0,0,0,0,0,0,1)); qu = G.UnitSignature((0,0,0,0,0,1,0))
    faces = (G.G2MBFaceOwnerV1("x-min",:x_min,"local",(-1,0,0),G.G2MBFaceValueV1(:dirichlet,0,fu)),
        G.G2MBFaceOwnerV1("x-max",:x_max,"local",(1,0,0),G.G2MBFaceValueV1(:neumann,1,qu)),
        G.G2MBFaceOwnerV1("y-min",:y_min,"local",(0,-1,0),G.G2MBFaceValueV1(:dirichlet,0,fu)),
        G.G2MBFaceOwnerV1("y-max",:y_max,"local",(0,1,0),G.G2MBFaceValueV1(:neumann,1,qu)),
        G.G2MBFaceOwnerV1("z-min",:z_min,"local",(0,0,-1),G.G2MBFaceValueV1(:dirichlet,0,fu)),
        G.G2MBFaceOwnerV1("z-max",:z_max,"local",(0,0,1),G.G2MBFaceValueV1(:neumann,1,qu)))
    units = G.G2MBUnitContractV1(G.UnitSignature(), G.UnitSignature((1,0,0,0,0,0,0)), G.UnitSignature((1,0,0,0,0,0,0)), G.UnitSignature((2,0,0,0,0,0,0)), G.UnitSignature((2,0,0,0,0,0,0)), G.UnitSignature((3,0,0,0,0,0,0)), fu, qu)
    contract = G._g2sf_expected_contract()
    source = G.g2mb_source_v1(G.QualifiedRefV1("local://g2/source", "v1"), "local-g2-source-v1", contract, chart, mesh, faces, G.G2MBProfileV1("fusion.g2.metric-boundary.profile"), units, G.G2MBAuthorityV1(:unique_match,:no_match,:no_match))
    G.g2mb_declaration_v1(contract, source)
end

function _t0l_g3(candidate=_T0L_CANDIDATE)
    unit = G.UnitSignature((1,2,-3,0,0,0,0)); owner = "local:g3/device"
    source_id = "local-g3-source"
    endpoints = (G.G3SFEndpointV1("source-power",:source,unit,:out,1,owner), G.G3SFEndpointV1("field-power",:field,unit,:out,-1,owner), G.G3SFEndpointV1("return-power",:return,unit,:out,-1,owner), G.G3SFEndpointV1("heat-power",:heat,unit,:out,-1,owner), G.G3SFEndpointV1("energy-ledger",:ledger,unit,:bidirectional,1,owner))
    split = G.G3SFConservativeSplitV1(3//4,1//8,1//8); heat = G.G3SFHeatRelationV1(:source,:heat,1//8); relation = G.G3SFLedgerRelationV1((:source,:field,:return,:heat),0)
    law = G.G3SFLawV1("source-law","source-power","field-power","return-power","heat-power",3//4,1//8,split,heat,relation,owner)
    entries = (G.G3SFLedgerEntryV1("source-entry","source-power",unit,:out,1,:source,1//1,owner), G.G3SFLedgerEntryV1("field-entry","field-power",unit,:out,-1,:field,-3//4,owner), G.G3SFLedgerEntryV1("return-entry","return-power",unit,:out,-1,:return,-1//8,owner), G.G3SFLedgerEntryV1("heat-entry","heat-power",unit,:out,-1,:heat,-1//8,owner))
    closure = G.G3SFLedgerClosureV1("closure",("source-entry","field-entry","return-entry","heat-entry"),0,unit,owner)
    a1 = G.G3SFAuthorityV1(:G1,candidate,nothing,nothing,:missing); a2 = G.G3SFAuthorityV1(:G2,candidate,nothing,nothing,:missing)
    targets = (G.G3SFFeedbackTargetV1("g1-residual",:G1,"/residual",:residual,unit,:in,1,source_id,owner,a1), G.G3SFFeedbackTargetV1("g2-thermal",:G2,"/thermal",:thermal_load,unit,:in,1,source_id,owner,a2))
    declaration = G.g3_sf_declaration_v1(candidate,source_id,owner,endpoints,law,entries,closure,targets,(a1,a2))
    @test all(target -> target.source_id == source_id, declaration.feedback_targets)
    @test all(target -> target.source_id == declaration.source_id, declaration.feedback_targets)
    declaration
end

function _t0l_factory_result(layer, declaration; g3_scope=:realization)
    root = _T0L_REPO
    if layer === :G1
        path = G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1
        head = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD"]))
        bytes = read(Cmd(["git", "-C", root, "show", "HEAD:" * path]))
        sha = _t0l_sha(bytes)
        locator = G.G1IndependentSourceLocatorV1(root, head, path, length(bytes), sha,
            :present, :present, :clean, sha, :repository_head)
        axes = G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema", "v2"),
            G.QualifiedRefV1("fusion.g1.canonicalization", "v2"),
            G.QualifiedRefV1("fusion.g1.applicability", "v2"),
            G.QualifiedRefV1("fusion.g1.receipt", "v2"))
        ctor = G.G1SourceDeclarationConstructorV1(G.g1_diffusion_declaration_v1,
            declaration.candidate_ref, declaration.operators, declaration.closure_ref,
            declaration.applicability_ref, declaration.applicability_domain,
            declaration.negative_controls)
        return G.g1_source_authority_factory_v1(locator,
            G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"),
            G._g1sf_expected_contract(), declaration.source_payload, axes, ctor)
    elseif layer === :G2
        path = G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1
        head = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD"]))
        bytes = read(Cmd(["git", "-C", root, "show", "HEAD:" * path]))
        sha = _t0l_sha(bytes)
        locator = G.G2IndependentSourceLocatorV1(root, head, path, length(bytes), sha,
            :present, :present, :clean, sha, :repository_head)
        axes = G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema", "v5"),
            G.QualifiedRefV1("fusion.g2.canonicalization", "v5"),
            G.QualifiedRefV1("fusion.g2.applicability", "v5"),
            G.QualifiedRefV1("fusion.g2.receipt", "v5"))
        ctor = G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)
        return G.g2_source_authority_factory_v1(locator,
            G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"),
            G._g2sf_expected_contract(), declaration.source, axes, ctor)
    else
        # G3SourceFeedbackLawV1 is a candidate-consuming declaration, not a
        # realization/control/binding source-authority factory input.
        return declaration
    end
end
function _t0l_factory_receipt_bytes(result)
    b = Vector{UInt8}(codeunits(G.canonical_json(result.receipt)))
    G.VNextT0LocalBytesV1(b, _t0l_sha(b))
end
function _t0l_expect_code(f, code)
    try
        f()
        false
    catch err
        @test occursin(code, sprint(showerror, err))
        true
    end
end
function _t0l_factory_locator(layer, source_locator, source_bytes)
    root = source_locator.repository_root
    head = source_locator.observed_head
    if layer === :G1
        G.G1IndependentSourceLocatorV1(root, head, source_locator.source_path,
            length(source_bytes.bytes), source_bytes.sha256, source_locator.head_path_status,
            source_locator.working_tree_path_status, source_locator.working_tree_status,
            source_locator.head_blob_sha256, source_locator.provenance)
    elseif layer === :G2
        G.G2IndependentSourceLocatorV1(root, head, source_locator.source_path,
            length(source_bytes.bytes), source_bytes.sha256, source_locator.head_path_status,
            source_locator.working_tree_path_status, source_locator.working_tree_status,
            source_locator.head_blob_sha256, source_locator.provenance)
    else
        G.G3IndependentSourceLocatorV1(:realization, root, head,
            source_locator.source_path, length(source_bytes.bytes), source_bytes.sha256,
            source_locator.head_path_status, source_locator.working_tree_path_status,
            source_locator.working_tree_status, source_locator.head_blob_sha256)
    end
end

function _t0l_rebuild_g1_payload(payload, candidate, source_ref)
    u = G.G1DiffusionScalarFieldV1(payload.u.field_id, payload.u.physical_type,
        source_ref; source_expression=payload.u.source_expression)
    k = G.G1DiffusionCoefficientFieldV1(payload.K.field_id, payload.K.physical_type,
        source_ref; spatial_dependency=payload.K.spatial_dependency,
        symmetry=payload.K.symmetry, positive_definite=payload.K.positive_definite,
        lower_bound=payload.K.lower_bound, upper_bound=payload.K.upper_bound,
        expression=payload.K.expression)
    f = G.G1DiffusionScalarFieldV1(payload.f.field_id, payload.f.physical_type,
        source_ref; source_expression=payload.f.source_expression)
    G.G1DiffusionSourcePayloadV1(candidate, source_ref, payload.source_version, u, k, f)
end

function _t0l_factory_builder(candidate, layer, source_ref, declaration_ref,
        source_bytes, semantic_body, source_locator)
    source_locator.source_ref == source_ref || throw(ArgumentError("ignored-builder-input-source_ref"))
    source_locator.source_sha256 == source_bytes.sha256 ||
        throw(ArgumentError("ignored-builder-input-source_bytes"))
    semantic_body.bytes.sha256 == _t0l_sha(semantic_body.bytes.bytes) ||
        throw(ArgumentError("ignored-builder-input-semantic_body"))
    locator = _t0l_factory_locator(layer, source_locator, source_bytes)
    if layer === :G1
        body = semantic_body.body
        fresh_payload = _t0l_rebuild_g1_payload(body.source_payload, candidate, source_ref)
        ctor = G.G1SourceDeclarationConstructorV1(G.g1_diffusion_declaration_v1,
            candidate, body.operators, body.closure_ref, body.applicability_ref,
            body.applicability_domain, body.negative_controls)
        result = G.g1_source_authority_factory_v1(locator,
            G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"),
            G._g1sf_expected_contract(), fresh_payload,
            G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema", "v2"),
                G.QualifiedRefV1("fusion.g1.canonicalization", "v2"),
                G.QualifiedRefV1("fusion.g1.applicability", "v2"),
                G.QualifiedRefV1("fusion.g1.receipt", "v2")), ctor)
    elseif layer === :G2
        body = semantic_body.body
        body.candidate_ref == candidate || throw(ArgumentError("g2-fresh-candidate-envelope-mismatch"))
        body.candidate_envelope.candidate_ref == candidate ||
            throw(ArgumentError("g2-fresh-candidate-envelope-mismatch"))
        body.candidate_envelope.contract_ref == body.contract_ref ||
            throw(ArgumentError("g2-fresh-contract-envelope-mismatch"))
        fresh_source = G.g2mb_source_v1(source_ref, body.source.source_version,
            body.contract_ref, body.source.chart_map, body.source.mesh, body.source.faces,
            body.source.profile, body.source.units, body.source.authority)
        result = G.g2_source_authority_factory_v1(locator,
            G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"),
            body.contract_ref, fresh_source,
            G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema", "v5"),
                G.QualifiedRefV1("fusion.g2.canonicalization", "v5"),
                G.QualifiedRefV1("fusion.g2.applicability", "v5"),
                G.QualifiedRefV1("fusion.g2.receipt", "v5")),
            G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))
    else
        body = semantic_body.body
        body.candidate_ref == candidate || throw(ArgumentError("g3-feedback-fresh-candidate-mismatch"))
        body.source_ref == source_ref || throw(ArgumentError("g3-feedback-source-ref-mismatch"))
        feedback = G.g3_sf_declaration_v1(body.candidate_ref, body.source_id,
            body.owner_scope, body.endpoints, body.law, body.ledger_entries,
            body.ledger_closure, body.feedback_targets, body.upstream_authority)
        feedback_bytes = _t0l_bytes(G.canonical_json(feedback))
        actual_declaration_ref = G.QualifiedRefV1(string(declaration_ref.id, "#actual-",
            feedback_bytes.sha256.value[1:16]), declaration_ref.version)
        normalized = G.vnext_t0_local_normalize_g3_feedback_declaration_v1(
            feedback, candidate, source_ref, source_bytes, source_locator,
            actual_declaration_ref, semantic_body)
        return (normalized, normalized)
    end
    payload = layer === :G3 ? result.source_declaration :
        result.source_declaration.declaration
    declaration_bytes = _t0l_bytes(G.canonical_json(payload))
    actual_declaration_ref = G.QualifiedRefV1(string(declaration_ref.id, "#actual-",
        declaration_bytes.sha256.value[1:16]), declaration_ref.version)
    contract = layer === :G1 ? G._g1sf_expected_contract() :
        layer === :G2 ? G._g2sf_expected_contract() : G.g3_contract_ref(:realization)
    normalized = G.vnext_t0_local_normalize_factory_result_v1(result, layer, layer,
        candidate, source_ref, source_bytes, source_locator, actual_declaration_ref,
        declaration_bytes, contract)
    (normalized, normalized)
end

function _t0l_present(layer, declaration; candidate=_T0L_CANDIDATE, label="visible", path=layer === :G1 ? "src/GenomeV5/G1/DiffusionDeclarationV1.jl" : layer === :G2 ? "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl" : "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl")
    raw = read(joinpath("D:/006-Programing/LMC/FusionConceptAI", path))
    source = G.VNextT0LocalBytesV1(raw, _t0l_sha(raw))
    if layer === :G3
        source_ref = G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback/local", "v1")
        body = merge(G._g3sf_body(declaration), (candidate_ref=candidate, source_ref=source_ref))
        semantic = G.VNextT0LocalSemanticBodyV1(body, _t0l_bytes(G.canonical_json(body)), (label,))
        locator = _t0l_local_locator(path, source_ref, source)
        declaration_bytes = _t0l_bytes(G.canonical_json(declaration))
        declaration_ref = G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback/declaration/" * declaration_bytes.sha256.value, "v1")
        normalized = G.vnext_t0_local_normalize_g3_feedback_declaration_v1(
            declaration, candidate, source_ref, source, locator, declaration_ref, semantic)
    else
        factory_result = _t0l_factory_result(layer, declaration)
        source_ref = layer === :G1 ? declaration.source_ref : declaration.source.source_ref
        body = layer === :G1 ? merge(G._g1d_declaration_body(declaration), (candidate_ref=candidate,)) :
            (candidate_ref=candidate, candidate_envelope=G.VNextT0LocalG2CandidateEnvelopeV1(
            candidate, declaration.contract_ref, declaration.source.source_ref,
                declaration.source.source_hash), contract_ref=declaration.contract_ref, source=declaration.source,
             schema_hash=declaration.schema_hash, canonicalization_hash=declaration.canonicalization_hash,
             profile_hash=declaration.profile_hash, declaration_hash=declaration.declaration_hash)
        semantic = G.VNextT0LocalSemanticBodyV1(body, _t0l_bytes(G.canonical_json(body)), (label,))
        declaration_payload = factory_result.source_declaration.declaration
        declaration_bytes = _t0l_bytes(G.canonical_json(declaration_payload))
        declaration_ref = G.QualifiedRefV1("factory://" * String(layer) * "/declaration/" *
            declaration_bytes.sha256.value, "v1")
        locator = _t0l_local_locator(path, source_ref, source)
        contract = layer === :G1 ? G._g1sf_expected_contract() : G._g2sf_expected_contract()
        normalized = G.vnext_t0_local_normalize_factory_result_v1(factory_result,
            layer, layer, candidate, source_ref, source, locator, declaration_ref,
            declaration_bytes, contract)
    end
    si = G.canonical_hash((kind=:source, ref=source_ref, bytes_sha256=source.sha256))
    di = G.canonical_hash((kind=:declaration, ref=declaration_ref, bytes_sha256=declaration_bytes.sha256))
    factory = G.VNextT0LocalFactoryReceiptV1(candidate, layer, source_ref,
        declaration_ref, _T0L_AXES, :present, normalized)
    receipt = G.VNextT0LocalDeclarationReceiptV1(candidate, layer, source_ref,
        declaration_ref, _T0L_AXES, :present, normalized)
    G.VNextT0LocalPresentDeclarationV1(layer,candidate,source_ref,declaration_ref,si,di,_T0L_AXES,source,declaration_bytes,semantic,locator,factory,receipt)
end

function _t0l_child(kind; candidate=_T0L_CANDIDATE)
    paths = Dict(:realization => "src/GenomeV5/G3/RealizationGenomeV5.jl",
        :control => "src/GenomeV5/G3/ControlGenomeV5.jl",
        :binding => "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl")
    path = paths[kind]; root = realpath(_T0L_REPO)
    head = readchomp(Cmd(["git", "-C", root, "rev-parse", "HEAD"]))
    raw = read(Cmd(["git", "-C", root, "show", "HEAD:" * path]))
    sb = G.VNextT0LocalBytesV1(raw, _t0l_sha(raw))
    locator = G.G3IndependentSourceLocatorV1(kind, root, head, path, length(raw), sb.sha256,
        :present, :present, :clean, sb.sha256)
    result = G.g3_source_authority_factory_v1(kind, locator,
        G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"),
        G.g3_contract_ref(kind), G.g3_version_axes(kind),
        G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/" * String(kind) * "/source-declaration/local", "v1"))
    result.identity.candidate_identity_created == false ||
        throw(ArgumentError("child factory unexpectedly consumed candidate"))
    receipt_raw = Vector{UInt8}(codeunits(G.canonical_json(result.receipt)))
    receipt_bytes = G.VNextT0LocalBytesV1(receipt_raw, _t0l_sha(receipt_raw))
    G.VNextT0LocalChildAbsentV1(kind, candidate, :G3, String(kind), :terminal_deferred,
        "real factory candidate_identity_created=false", false, :G3, receipt_bytes,
        receipt_bytes.sha256, path)
end
function _t0l_child_present(kind; candidate=_T0L_CANDIDATE)
    raw = read("D:/006-Programing/LMC/FusionConceptAI/src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"); sb = G.VNextT0LocalBytesV1(raw, _t0l_sha(raw)); sr = G.QualifiedRefV1("local://g3/source", "v1")
    loc = _t0l_local_locator("src/GenomeV5/G3/G3SourceFeedbackLawV1.jl", sr, sb)
    body = (kind=kind, source_ref=sr, source_sha256=sb.sha256, contract=:candidate_bound_g3)
    cref = G.QualifiedRefV1("local://g3/child/" * String(kind), "v1"); bh = G.canonical_hash(body); ih = G.canonical_hash((candidate_ref=candidate,layer=:G3,child_id=String(kind),kind=kind,child_ref=cref,body_hash=bh,source_ref=sr,source_sha256=sb.sha256))
    G.VNextT0LocalChildPresentV1(kind,candidate,:G3,String(kind),cref,sr,sb,loc,body,bh,ih)
end
function _t0l_feedback(id, target_ref; target_layer=nothing, candidate=_T0L_CANDIDATE)
    inferred_layer = startswith(id, "g1-") ? :G1 :
        startswith(id, "g2-") ? :G2 :
        throw(ArgumentError("feedback target id must identify G1 or G2"))
    layer = target_layer === nothing ? inferred_layer : Symbol(target_layer)
    layer in (:G1, :G2) || throw(ArgumentError("feedback target_layer must be G1 or G2"))
    layer === inferred_layer ||
        throw(ArgumentError("feedback target_layer does not match target id"))
    body = (id=id, relation="same-bundle-target")
    G.VNextT0LocalFeedbackV1(id, layer, candidate, target_ref, body, G.canonical_hash(body))
end

function _t0l_rekey_present(record, source_ref, declaration_ref)
    record isa G.VNextT0LocalPresentDeclarationV1 ||
        throw(ArgumentError("fresh feedback target must remain present"))
    G.VNextT0LocalPresentDeclarationV1(record.layer, record.candidate_ref,
        source_ref, declaration_ref, record.source_identity_hash,
        record.declaration_identity_hash, record.axes, record.source_bytes,
        record.declaration_bytes, record.semantic_body, record.source_locator,
        record.factory_receipt, record.declaration_receipt)
end

@testset "local T0 R20a G1 nested semantic rebind" begin
    declaration = _t0l_g1()
    original_body = G._g1d_declaration_body(declaration)
    original_semantic = G.VNextT0LocalSemanticBodyV1(original_body,
        _t0l_bytes(G.canonical_json(original_body)), ("r20a",))
    fresh_candidate = G.QualifiedRefV1("local://candidate/r20a", "v5")
    fresh_source = G.QualifiedRefV1("local://g1/source#r20a", "v1")
    rebound = G._vnl_t0_semantic_rebind_candidate(original_semantic,
        fresh_candidate, fresh_source)
    body = rebound.body
    payload = body.source_payload
    @test body.candidate_ref == fresh_candidate
    @test body.source_ref == fresh_source
    @test payload.candidate_ref == fresh_candidate
    @test payload.source_ref == fresh_source
    @test body.u.source_ref == fresh_source
    @test body.K.source_ref == fresh_source
    @test body.f.source_ref == fresh_source
    @test body.source_hash == G.g1_diffusion_source_hash_v1(payload)
    @test body.u.physical_type == declaration.u.physical_type
    @test body.u.source_expression == declaration.u.source_expression
    @test body.f.physical_type == declaration.f.physical_type
    @test body.f.source_expression == declaration.f.source_expression
    @test body.K.lower_bound == declaration.K.lower_bound
    @test body.K.upper_bound == declaration.K.upper_bound
    @test body.K.spatial_dependency == declaration.K.spatial_dependency
    @test body.K.symmetry == declaration.K.symmetry
    @test body.K.positive_definite == declaration.K.positive_definite
    @test body.K.expression == declaration.K.expression
    fresh_declaration = G.g1_diffusion_declaration_v1(
        body.candidate_ref, body.source_ref, body.source_version, body.source_hash,
        body.u, body.K, body.f, body.operators, body.closure_ref,
        body.applicability_ref, body.applicability_domain, body.negative_controls;
        ownership=body.ownership, source_payload=payload)
    @test G.g1_diffusion_validate(fresh_declaration) == (:valid, ())
    rebound_again = G._vnl_t0_semantic_rebind_candidate(original_semantic,
        fresh_candidate, fresh_source)
    @test rebound.bytes.bytes == rebound_again.bytes.bytes
    @test rebound.bytes.sha256 == rebound_again.bytes.sha256
    @test G.canonical_json(rebound.body) == G.canonical_json(rebound_again.body)

    old_candidate_payload = G.G1DiffusionSourcePayloadV1(
        declaration.candidate_ref, fresh_source, payload.source_version,
        body.u, body.K, body.f)
    @test_throws ArgumentError G.g1_diffusion_declaration_v1(
        fresh_candidate, fresh_source, body.source_version, body.source_hash,
        body.u, body.K, body.f, body.operators, body.closure_ref,
        body.applicability_ref, body.applicability_domain, body.negative_controls;
        ownership=body.ownership, source_payload=old_candidate_payload)
    stale_candidate = G.QualifiedRefV1("local://candidate/r20a-stale", "v5")
    stale_nested_payload = G.G1DiffusionSourcePayloadV1(
        stale_candidate, original_body.source_ref, original_body.source_version,
        original_body.u, original_body.K, original_body.f)
    stale_nested_body = merge(original_body,
        (source_payload=stale_nested_payload,
         source_hash=G.g1_diffusion_source_hash_v1(stale_nested_payload)))
    stale_nested_semantic = G.VNextT0LocalSemanticBodyV1(stale_nested_body,
        _t0l_bytes(G.canonical_json(stale_nested_body)), ("r20a-stale-nested-candidate",))
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        stale_nested_semantic, fresh_candidate, fresh_source)

    for field in (:u, :K, :f)
        old_fields = (u=field === :u ? declaration.u : body.u,
            K=field === :K ? declaration.K : body.K,
            f=field === :f ? declaration.f : body.f)
        @test_throws ArgumentError G.g1_diffusion_declaration_v1(
            fresh_candidate, fresh_source, body.source_version, body.source_hash,
            old_fields.u, old_fields.K, old_fields.f, body.operators,
            body.closure_ref, body.applicability_ref, body.applicability_domain,
            body.negative_controls; ownership=body.ownership,
            source_payload=payload)
        stale_ref = G.QualifiedRefV1("local://g1/r20a-stale-" * String(field), "v1")
        stale_field = field === :u ? G.G1DiffusionScalarFieldV1(
            original_body.u.field_id, original_body.u.physical_type, stale_ref;
            source_expression=original_body.u.source_expression) :
            field === :K ? G.G1DiffusionCoefficientFieldV1(
                original_body.K.field_id, original_body.K.physical_type, stale_ref;
                spatial_dependency=original_body.K.spatial_dependency,
                symmetry=original_body.K.symmetry,
                positive_definite=original_body.K.positive_definite,
                lower_bound=original_body.K.lower_bound,
                upper_bound=original_body.K.upper_bound,
                expression=original_body.K.expression) :
            G.G1DiffusionScalarFieldV1(original_body.f.field_id,
                original_body.f.physical_type, stale_ref;
                source_expression=original_body.f.source_expression)
        stale_field_body = field === :u ? merge(original_body, (u=stale_field,)) :
            field === :K ? merge(original_body, (K=stale_field,)) :
            merge(original_body, (f=stale_field,))
        stale_field_semantic = G.VNextT0LocalSemanticBodyV1(stale_field_body,
            _t0l_bytes(G.canonical_json(stale_field_body)),
            ("r20a-stale-" * String(field) * "-source-ref",))
        @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
            stale_field_semantic, fresh_candidate, fresh_source)
    end
    @test_throws ArgumentError G.g1_diffusion_declaration_v1(
        fresh_candidate, fresh_source, body.source_version,
        G.digest256_text("r20a-stale-source-hash"), body.u, body.K, body.f,
        body.operators, body.closure_ref, body.applicability_ref,
        body.applicability_domain, body.negative_controls;
        ownership=body.ownership, source_payload=payload)
    stale_body = merge(original_body,
        (source_hash=G.digest256_text("r20a-stale-input-hash"),))
    stale_semantic = G.VNextT0LocalSemanticBodyV1(stale_body,
        _t0l_bytes(G.canonical_json(stale_body)), ("r20a-stale-input",))
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        stale_semantic, fresh_candidate, fresh_source)
end

@testset "local T0 R20b G2 typed source and envelope semantic rebind" begin
    declaration = _t0l_g2()
    original_body = (candidate_ref=_T0L_CANDIDATE,
        candidate_envelope=G.VNextT0LocalG2CandidateEnvelopeV1(
            _T0L_CANDIDATE, declaration.contract_ref, declaration.source.source_ref,
            declaration.source.source_hash),
        contract_ref=declaration.contract_ref, source=declaration.source,
        schema_hash=declaration.schema_hash,
        canonicalization_hash=declaration.canonicalization_hash,
        profile_hash=declaration.profile_hash,
        declaration_hash=declaration.declaration_hash)
    original_semantic = G.VNextT0LocalSemanticBodyV1(original_body,
        _t0l_bytes(G.canonical_json(original_body)), ("r20b",))
    fresh_candidate = G.QualifiedRefV1("local://candidate/r20b", "v5")
    fresh_source = G.QualifiedRefV1("local://g2/source#r20b", "v1")
    rebound = G._vnl_t0_semantic_rebind_candidate(original_semantic,
        fresh_candidate, fresh_source)
    body = rebound.body
    fresh_declaration = G.g2mb_declaration_v1(body.contract_ref, body.source)
    @test body.candidate_ref == fresh_candidate
    @test body.candidate_envelope.candidate_ref == fresh_candidate
    @test body.candidate_envelope.contract_ref == body.contract_ref
    @test body.candidate_envelope.source_ref == fresh_source
    @test body.candidate_envelope.source_hash == body.source.source_hash
    @test body.source.source_ref == fresh_source
    @test body.source.candidate_ref == body.contract_ref
    @test body.source.chart_map == declaration.source.chart_map
    @test body.source.mesh == declaration.source.mesh
    @test body.source.faces == declaration.source.faces
    @test body.source.profile == declaration.source.profile
    @test body.source.units == declaration.source.units
    @test body.source.authority == declaration.source.authority
    @test body.source.source_hash == G.canonical_hash(G._g2mb_source_body(
        body.source.source_ref, body.source.source_version, body.source.candidate_ref,
        body.source.chart_map, body.source.mesh, body.source.faces,
        body.source.profile, body.source.units, body.source.authority))
    @test body.schema_hash == fresh_declaration.schema_hash
    @test body.canonicalization_hash == fresh_declaration.canonicalization_hash
    @test body.profile_hash == fresh_declaration.profile_hash
    @test body.declaration_hash == fresh_declaration.declaration_hash
    rebound_again = G._vnl_t0_semantic_rebind_candidate(original_semantic,
        fresh_candidate, fresh_source)
    @test rebound.bytes.bytes == rebound_again.bytes.bytes
    @test rebound.bytes.sha256 == rebound_again.bytes.sha256
    @test G.canonical_json(rebound.body) == G.canonical_json(rebound_again.body)

    stale_source = G.g2mb_source_v1(
        G.QualifiedRefV1("local://g2/stale-source", "v1"), declaration.source.source_version,
        declaration.contract_ref, declaration.source.chart_map, declaration.source.mesh,
        declaration.source.faces, declaration.source.profile, declaration.source.units,
        declaration.source.authority)
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        G.VNextT0LocalSemanticBodyV1(merge(original_body, (source=stale_source,)),
            _t0l_bytes("r20b-stale-typed-source-ref"), ()), fresh_candidate, fresh_source)
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        G.VNextT0LocalSemanticBodyV1(merge(original_body,
            (candidate_envelope=G.VNextT0LocalG2CandidateEnvelopeV1(
                _T0L_CANDIDATE, declaration.contract_ref, declaration.source.source_ref,
                G.digest256_text("r20b-stale-envelope-source-hash")),)),
            _t0l_bytes("r20b-stale-source-hash"), ()), fresh_candidate, fresh_source)
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        G.VNextT0LocalSemanticBodyV1(merge(original_body,
            (candidate_envelope=G.VNextT0LocalG2CandidateEnvelopeV1(
                _T0L_CANDIDATE, declaration.contract_ref,
                G.QualifiedRefV1("local://g2/envelope-only", "v1"),
                declaration.source.source_hash),)),
            _t0l_bytes("r20b-envelope-source-mismatch"), ()), fresh_candidate, fresh_source)
    foreign_contract = G.GenomeContractRef("foreign://g2/contract", "v5",
        G.g2mb_schema_hash_v1(), G.g2mb_canonicalization_hash_v1(),
        G.g2mb_profile_token_v1(declaration.source.profile))
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        G.VNextT0LocalSemanticBodyV1(merge(original_body,
            (contract_ref=foreign_contract,)),
            _t0l_bytes("r20b-contract-domain-confusion"), ()), fresh_candidate, fresh_source)
    for field in (:schema_hash, :canonicalization_hash, :profile_hash, :declaration_hash)
        stale_body = merge(original_body, NamedTuple{(field,)}((G.digest256_text(
            "r20b-stale-" * String(field)),)))
        @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
            G.VNextT0LocalSemanticBodyV1(stale_body,
                _t0l_bytes("r20b-stale-" * String(field)), ()), fresh_candidate, fresh_source)
    end
end

@testset "local T0 present bundle is source/hash bound and order independent" begin
    g1_input = _t0l_g1()
    @test g1_input.source_payload.candidate_ref == _T0L_CANDIDATE
    @test g1_input.source_payload.source_ref == g1_input.source_ref
    @test g1_input.source_payload.u.source_ref == g1_input.source_ref
    @test g1_input.source_payload.K.source_ref == g1_input.source_ref
    @test g1_input.source_payload.f.source_ref == g1_input.source_ref
    @test g1_input.closure_ref == G.QualifiedRefV1(G.G1_DIFFUSION_CLOSURE_ID_V1,
        G.G1_DIFFUSION_PROFILE_VERSION_V1)
    @test g1_input.applicability_ref == G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1,
        G.G1_DIFFUSION_PROFILE_VERSION_V1)
    @test G.g1_source_factory_result_status(_t0l_factory_result(:G1, _t0l_g1())) === :present
    @test G.g2_source_factory_result_status(_t0l_factory_result(:G2, _t0l_g2())) === :present
    @test G.g3_sf_declaration_hash_v1(_t0l_factory_result(:G3, _t0l_g3())) isa G.Digest256
    g1, g2, g3 = _t0l_g1(), _t0l_g2(), _t0l_g3()
    declarations = (_t0l_present(:G1, g1), _t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"), _t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (_t0l_child(:realization), _t0l_child(:control), _t0l_child(:binding))
    feedback = (_t0l_feedback("g1-residual", declarations[1].declaration_ref), _t0l_feedback("g2-thermal", declarations[2].declaration_ref))
    a = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, declarations, children, feedback)
    b = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE,
        (declarations[3], declarations[1], declarations[2]), (children[3], children[1], children[2]),
        (feedback[2], feedback[1]))
    # Keep the first admission error visible; do not dereference a missing
    # transport after fail-closed validation has rejected the bundle.
    @test a.errors == ()
    @test a.status === :valid
    @test a.accepted === false
    @test a.claim_ceiling === :contract_only
    @test a.resolution === :terminal_deferred
    # Observe the permutation admission before the guard; the guard only
    # prevents cascade dereferences when transport construction fails.
    @test b.errors == ()
    @test b.status === :valid
    @test b.accepted === false
    @test b.claim_ceiling === :contract_only
    @test b.resolution === :terminal_deferred
    @test :g3_child_terminal_deferred in a.gaps
    @test :g3_child_terminal_deferred in b.gaps
    if a.status === :valid && a.transport !== nothing && b.status === :valid && b.transport !== nothing
        @test a.transport.bundle_hash == b.transport.bundle_hash
        @test G.vnext_t0_local_bundle_hash_recompute_v1(a.transport) == a.transport.bundle_hash
        @test a.transport.declarations[1].layer === :G1
        @test a.transport.children[1].kind === :realization
    end
    g2_body = declarations[2].semantic_body.body
    @testset "g2_typed_source_hash_tamper" begin
        tampered_envelope = G.VNextT0LocalG2CandidateEnvelopeV1(
            _T0L_CANDIDATE, g2_body.contract_ref, g2_body.source.source_ref,
            G.digest256_text("tampered-g2-typed-source-hash"))
        tampered_body = merge(g2_body, (candidate_envelope=tampered_envelope,))
        tampered_semantic = G.VNextT0LocalSemanticBodyV1(tampered_body,
            _t0l_bytes(G.canonical_json(tampered_body)), ("typed-source-hash-tamper",))
        tampered_record = G.VNextT0LocalPresentDeclarationV1(
            declarations[2].layer, declarations[2].candidate_ref, declarations[2].source_ref,
            declarations[2].declaration_ref, declarations[2].source_identity_hash,
            declarations[2].declaration_identity_hash, declarations[2].axes,
            declarations[2].source_bytes, declarations[2].declaration_bytes,
            tampered_semantic, declarations[2].source_locator,
            declarations[2].factory_receipt, declarations[2].declaration_receipt)
        tampered_admission = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE,
            (declarations[1], tampered_record, declarations[3]), children, feedback)
        @test tampered_admission.status === :fail_closed
        @test :factory_result_source_content_mismatch in tampered_admission.errors
    end

    @testset "g2_self_consistent_typed_source_fabrication" begin
        fake_declaration = _t0l_g2(; variant=true)
        fake_source = fake_declaration.source
        fake_body = merge(g2_body, (source=fake_source,
            candidate_envelope=G.VNextT0LocalG2CandidateEnvelopeV1(
                _T0L_CANDIDATE, fake_declaration.contract_ref, fake_source.source_ref,
                fake_source.source_hash),
            contract_ref=fake_declaration.contract_ref,
            schema_hash=fake_declaration.schema_hash,
            canonicalization_hash=fake_declaration.canonicalization_hash,
            profile_hash=fake_declaration.profile_hash))
        fake_semantic = G.VNextT0LocalSemanticBodyV1(fake_body,
            _t0l_bytes(G.canonical_json(fake_body)), ("self-consistent-typed-source",))
        fake_record = G.VNextT0LocalPresentDeclarationV1(
            declarations[2].layer, declarations[2].candidate_ref, declarations[2].source_ref,
            declarations[2].declaration_ref, declarations[2].source_identity_hash,
            declarations[2].declaration_identity_hash, declarations[2].axes,
            declarations[2].source_bytes, declarations[2].declaration_bytes,
            fake_semantic, declarations[2].source_locator,
            declarations[2].factory_receipt, declarations[2].declaration_receipt)
        fake_admission = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE,
            (declarations[1], fake_record, declarations[3]), children, feedback)
        @test fake_admission.status === :fail_closed
        @test :factory_result_typed_declaration_mismatch in fake_admission.errors
    end
end

@testset "local T0 rejects stale bytes, foreign candidate, duplicate layer and path escape" begin
    # source_path escape is rejected before any local source is admitted.
    g1, g2, g3 = _t0l_g1(), _t0l_g2(), _t0l_g3()
    d = [_t0l_present(:G1, g1), _t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"), _t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl")]
    children = (_t0l_child(:realization), _t0l_child(:control), _t0l_child(:binding))
    base = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, Tuple(d), children)
    stale = _t0l_present(:G1, g1)
    stale_source = G.VNextT0LocalBytesV1(stale.source_bytes.bytes, G.digest256_text("stale-source-claim"))
    stale = G.VNextT0LocalPresentDeclarationV1(stale.layer, stale.candidate_ref, stale.source_ref, stale.declaration_ref,
        stale.source_identity_hash, stale.declaration_identity_hash, stale.axes, stale_source, stale.declaration_bytes, stale.semantic_body, stale.source_locator,
        stale.factory_receipt, stale.declaration_receipt)
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (stale, d[2], d[3]), children)
    @test result.status === :fail_closed
    @test :source_bytes_hash_mismatch in result.errors
    foreign = G.QualifiedRefV1("local://candidate/foreign", "v5")
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (d[1], _t0l_present(:G2, _t0l_g2(foreign); candidate=foreign, path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"), d[3]), children)
    @test result.status === :fail_closed
    @test :foreign_candidate in result.errors
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (d[1], d[1], d[3]), children)
    @test result.status === :fail_closed
    @test :layer_set_invalid in result.errors
    @test_throws ArgumentError G.VNextT0LocalSourceLocatorV1("root", "../escape.jl", "local://escape", G.QualifiedRefV1("local://escape", "v1"), 1, _t0l_sha(UInt8[0]), "head", :present, :present, :clean, nothing, :repository_head)
    # A symlinked source path is checked with realpath/containment by the production locator read.
    @test occursin("symlink", "symlink_escape")
    @testset "real symlink escape is rejected or explicitly skipped" begin
        root = mktempdir(); outside = mktempdir()
        link = joinpath(root, "link"); target = joinpath(outside, "escaped.jl")
        write(target, UInt8[0x23])
        try
            symlink(outside, link)
            sr = G.QualifiedRefV1("local://symlink", "v1")
            loc = G.VNextT0LocalSourceLocatorV1(realpath(root), "link/escaped.jl", sr.id, sr, 1, _t0l_sha(UInt8[0x23]), "fixture", :present, :present, :clean, nothing, :isolated_test_fixture)
            @test_throws ArgumentError G._vnl_t0_locator_bytes(loc)
        catch err
            @info "symlink creation unsupported; negative control skipped" error=typeof(err)
            @test_skip true
        end
    end
    @test_throws ArgumentError G.VNextT0LocalFactoryReceiptV1(
        _T0L_CANDIDATE, :G2, d[1].source_ref, d[1].declaration_ref,
        d[1].axes, :present, d[1].factory_receipt.factory_result)
    @test_throws ArgumentError G.VNextT0LocalFactoryResultV1(
        d[1].factory_receipt.factory_result.factory_id,
        d[1].factory_receipt.factory_result.factory_version, :G1,
        d[1].factory_receipt.factory_result.candidate_ref, d[1].layer,
        d[1].source_ref, d[1].source_bytes, length(d[1].source_bytes.bytes),
        d[1].factory_receipt.factory_result.locator,
        d[1].factory_receipt.factory_result.locator_provenance,
        d[1].declaration_ref, d[1].declaration_bytes,
        d[1].factory_receipt.factory_result.declaration_hash, :present,
        d[1].factory_receipt.factory_result.contract_ref,
        G.digest256_text("tampered-content"), d[1].factory_receipt.factory_result.axes,
        d[1].factory_receipt.factory_result.upstream_receipt_bytes,
        d[1].factory_receipt.factory_result.upstream_receipt_hash)
    @test _t0l_expect_code(() -> G.VNextT0LocalFactoryResultV1(
        d[1].factory_receipt.factory_result.factory_id,
        d[1].factory_receipt.factory_result.factory_version, :G1,
        d[1].factory_receipt.factory_result.candidate_ref, d[1].layer,
        d[1].source_ref, d[1].source_bytes, length(d[1].source_bytes.bytes),
        d[1].factory_receipt.factory_result.locator,
        d[1].factory_receipt.factory_result.locator_provenance,
        d[1].declaration_ref, d[1].declaration_bytes,
        d[1].factory_receipt.factory_result.declaration_hash, :present,
        d[1].factory_receipt.factory_result.contract_ref,
        G.digest256_text("tampered-content"), d[1].factory_receipt.factory_result.axes,
        d[1].factory_receipt.factory_result.upstream_receipt_bytes,
        d[1].factory_receipt.factory_result.upstream_receipt_hash),
        "factory_result_content_identity_mismatch")
    # Same concrete result type with self-consistent replacement bytes/identity
    # is still stale because the current declaration bytes are different.
    original_result = d[1].factory_receipt.factory_result
    stale_factory_id = G.QualifiedRefV1("foreign://stale-factory", "v1")
    stale_factory_version = "v999"
    stale_axes = (G.QualifiedRefV1("foreign-axis", "v1"), original_result.axes[2],
        original_result.axes[3], original_result.axes[4])
    stale_decl_bytes_raw = vcat(d[1].declaration_bytes.bytes, UInt8[0x00])
    stale_decl_bytes = G.VNextT0LocalBytesV1(stale_decl_bytes_raw, _t0l_sha(stale_decl_bytes_raw))
    stale_decl_hash = stale_decl_bytes.sha256
    stale_content = G.canonical_hash((factory_id=stale_factory_id,
        factory_version=stale_factory_version, factory_api=original_result.factory_api,
        candidate_ref=original_result.candidate_ref, layer=original_result.layer,
        source_ref=original_result.source_ref, source_bytes=original_result.source_bytes,
        source_size=original_result.source_size,
        locator=original_result.locator,
        locator_provenance=original_result.locator_provenance,
        declaration_ref=original_result.declaration_ref, declaration_bytes=stale_decl_bytes,
        declaration_hash=stale_decl_hash, status=original_result.status,
        contract_ref=original_result.contract_ref, axes=stale_axes,
        upstream_receipt_bytes=original_result.upstream_receipt_bytes,
        upstream_receipt_hash=original_result.upstream_receipt_hash))
    stale_result = G.VNextT0LocalFactoryResultV1(stale_factory_id,
        stale_factory_version, original_result.factory_api,
        original_result.candidate_ref, original_result.layer, original_result.source_ref,
        original_result.source_bytes, original_result.source_size,
        original_result.locator,
        original_result.locator_provenance, original_result.declaration_ref,
        stale_decl_bytes, stale_decl_hash, original_result.status,
        original_result.contract_ref, stale_content, stale_axes,
        original_result.upstream_receipt_bytes, original_result.upstream_receipt_hash)
    stale_factory = G.VNextT0LocalFactoryReceiptV1(_T0L_CANDIDATE, :G1,
        d[1].source_ref, d[1].declaration_ref, d[1].axes, :present, stale_result)
    stale_declaration = G.VNextT0LocalDeclarationReceiptV1(_T0L_CANDIDATE, :G1,
        d[1].source_ref, d[1].declaration_ref, d[1].axes, :present, stale_result)
    stale_record = G.VNextT0LocalPresentDeclarationV1(d[1].layer, d[1].candidate_ref,
        d[1].source_ref, d[1].declaration_ref, d[1].source_identity_hash,
        d[1].declaration_identity_hash, d[1].axes, d[1].source_bytes,
        d[1].declaration_bytes, d[1].semantic_body, d[1].source_locator,
        stale_factory, stale_declaration)
    stale_admission = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE,
        (stale_record, d[2], d[3]), children)
    @test stale_admission.status === :fail_closed
    @test :factory_result_declaration_content_mismatch in stale_admission.errors
    @test :factory_result_id_mismatch in stale_admission.errors
    @test :factory_result_version_mismatch in stale_admission.errors
    @test :factory_result_axes_mismatch in stale_admission.errors
    tampered_locator = G.VNextT0LocalSourceLocatorV1(
        original_result.locator.repository_root, original_result.locator.source_path,
        original_result.locator.source_uri, original_result.locator.source_ref,
        original_result.locator.source_size, original_result.locator.source_sha256,
        original_result.locator.observed_head, original_result.locator.head_path_status,
        original_result.locator.working_tree_path_status, original_result.locator.working_tree_status,
        original_result.locator.head_blob_sha256, :isolated_test_fixture)
    tampered_content = G.canonical_hash((factory_id=original_result.factory_id,
        factory_version=original_result.factory_version, factory_api=original_result.factory_api,
        candidate_ref=original_result.candidate_ref, layer=original_result.layer,
        source_ref=original_result.source_ref, source_bytes=original_result.source_bytes,
        source_size=original_result.source_size, locator=tampered_locator,
        locator_provenance=:isolated_test_fixture, declaration_ref=original_result.declaration_ref,
        declaration_bytes=original_result.declaration_bytes,
        declaration_hash=original_result.declaration_hash, status=original_result.status,
        contract_ref=original_result.contract_ref, axes=original_result.axes,
        upstream_receipt_bytes=original_result.upstream_receipt_bytes,
        upstream_receipt_hash=original_result.upstream_receipt_hash))
    tampered_result = G.VNextT0LocalFactoryResultV1(original_result.factory_id,
        original_result.factory_version, original_result.factory_api,
        original_result.candidate_ref, original_result.layer, original_result.source_ref,
        original_result.source_bytes, original_result.source_size, tampered_locator,
        :isolated_test_fixture, original_result.declaration_ref,
        original_result.declaration_bytes, original_result.declaration_hash,
        original_result.status, original_result.contract_ref, tampered_content,
        original_result.axes, original_result.upstream_receipt_bytes,
        original_result.upstream_receipt_hash)
    tampered_factory = G.VNextT0LocalFactoryReceiptV1(_T0L_CANDIDATE, :G1,
        d[1].source_ref, d[1].declaration_ref, d[1].axes, :present, tampered_result)
    tampered_declaration = G.VNextT0LocalDeclarationReceiptV1(_T0L_CANDIDATE, :G1,
        d[1].source_ref, d[1].declaration_ref, d[1].axes, :present, tampered_result)
    tampered_record = G.VNextT0LocalPresentDeclarationV1(d[1].layer,
        d[1].candidate_ref, d[1].source_ref, d[1].declaration_ref,
        d[1].source_identity_hash, d[1].declaration_identity_hash, d[1].axes,
        d[1].source_bytes, d[1].declaration_bytes, d[1].semantic_body,
        d[1].source_locator, tampered_factory, tampered_declaration)
    tampered_admission = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE,
        (tampered_record, d[2], d[3]), children)
    @test tampered_admission.status === :fail_closed
    @test :factory_result_locator_provenance_mismatch in tampered_admission.errors
    @test _t0l_expect_code(() -> G.vnext_t0_local_normalize_factory_result_v1(
        _t0l_factory_result(:G1, _t0l_g1(G.QualifiedRefV1("local://candidate/stale-g1", "v5"))),
        :G1, :G1, _T0L_CANDIDATE, d[1].source_ref, d[1].source_bytes,
        d[1].source_locator, d[1].declaration_ref, d[1].declaration_bytes,
        G._g1sf_expected_contract()), "factory_result_candidate_mismatch")
    @test _t0l_expect_code(() -> G.vnext_t0_local_normalize_factory_result_v1(
        _t0l_factory_result(:G2, _t0l_g2(; variant=true)), :G2, :G2,
        _T0L_CANDIDATE, d[2].source_ref, d[2].source_bytes, d[2].source_locator,
        d[2].declaration_ref, d[2].declaration_bytes, G._g2sf_expected_contract()),
        "factory_result_declaration_content_mismatch")
    @test _t0l_expect_code(() -> G.vnext_t0_local_normalize_factory_result_v1(
        _t0l_factory_result(:G2, _t0l_g2()), :G2, :G2, _T0L_CANDIDATE,
        G.QualifiedRefV1("foreign://source", "v1"), d[2].source_bytes,
        d[2].source_locator, d[2].declaration_ref, d[2].declaration_bytes,
        G._g2sf_expected_contract()), "factory_result_source_ref_mismatch")
    @test _t0l_expect_code(() -> G.vnext_t0_local_normalize_g3_feedback_declaration_v1(
        g3, _T0L_CANDIDATE, G.QualifiedRefV1("foreign://feedback-source", "v1"),
        d[3].source_bytes, d[3].source_locator, d[3].declaration_ref,
        d[3].semantic_body), "g3_feedback_body_source_ref_mismatch")
    wrong_feedback = (_t0l_feedback("g1-residual", G.QualifiedRefV1("local://foreign/target", "v1")),)
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, Tuple(d), children, wrong_feedback)
    @test result.status === :fail_closed
    @test :feedback_target_ref_mismatch in result.errors
    wrong_axis = G.VNextT0LocalPresentDeclarationV1(d[1].layer, d[1].candidate_ref, d[1].source_ref, d[1].declaration_ref, d[1].source_identity_hash, d[1].declaration_identity_hash, (G.QualifiedRefV1("foreign-axis", "v1"), d[1].axes[2], d[1].axes[3], d[1].axes[4]), d[1].source_bytes, d[1].declaration_bytes, d[1].semantic_body, d[1].source_locator, d[1].factory_receipt, d[1].declaration_receipt)
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (wrong_axis, d[2], d[3]), children)
    @test :axes_identity_or_order_invalid in result.errors
    edited_semantic_value = (edited=true, original=d[1].semantic_body.body)
    edit_body = G.VNextT0LocalSemanticBodyV1(edited_semantic_value, _t0l_bytes(G.canonical_json(edited_semantic_value)), ("edited",))
    @test_throws ArgumentError G.vnext_t0_local_source_edit_v1(
        d[1], G.VNextT0LocalBytesV1(vcat(d[1].source_bytes.bytes, UInt8[0x0a]),
        _t0l_sha(vcat(d[1].source_bytes.bytes, UInt8[0x0a]))), edit_body)
    edit_root = joinpath("D:/006-Programing/LMC/FusionConceptAI", "tmp", "t0_local_r3_source_edit")
    mkpath(edit_root)
    edit_path = joinpath(edit_root, "G1_DiffusionDeclarationV1.edited.jl")
    edited_bytes = vcat(d[1].source_bytes.bytes, UInt8[0x0a, 0x23, 0x20, 0x73, 0x6f, 0x75, 0x72, 0x63, 0x65, 0x2d, 0x65, 0x64, 0x69, 0x74])
    write(edit_path, edited_bytes)
    edited_sha = _t0l_sha(edited_bytes)
    edited_source_ref = G.QualifiedRefV1(string(d[1].source_ref.id, "#source-", edited_sha.value[1:16]), d[1].source_ref.version)
    edited_locator = _t0l_local_locator("tmp/t0_local_r3_source_edit/G1_DiffusionDeclarationV1.edited.jl", edited_source_ref, G.VNextT0LocalBytesV1(edited_bytes, edited_sha); provenance=:repository_head)
    rebuilt = G.vnext_t0_local_rebuild_after_source_edit_v1(
        _T0L_CANDIDATE, Tuple(d), children,
        (_t0l_feedback("g1-residual", d[1].declaration_ref),
         _t0l_feedback("g2-thermal", d[2].declaration_ref)), :G1,
        G.VNextT0LocalBytesV1(edited_bytes, edited_sha), edit_body;
        new_source_locator=edited_locator, factory_builder=_t0l_factory_builder)
    @test rebuilt.admission.status === :fail_closed
    @test :factory_builder_fail_closed in rebuilt.admission.errors
    rm(edit_root; recursive=true, force=true)
    @test base.accepted === false
end

@testset "local T0 fresh source edit rebuilds all declarations with honest deferred children" begin
    g1, g2, g3 = _t0l_g1(), _t0l_g2(), _t0l_g3()
    declarations = (_t0l_present(:G1, g1),
        _t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        _t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (_t0l_child(:realization), _t0l_child(:control), _t0l_child(:binding))
    feedback = (_t0l_feedback("g1-residual", declarations[1].declaration_ref),
        _t0l_feedback("g2-thermal", declarations[2].declaration_ref))
    fixture_root = mktempdir()
    fixture_source_path = "src/GenomeV5/G1/DiffusionDeclarationV1.jl"
    edit_path = joinpath(fixture_root, split(fixture_source_path, '/')...)
    mkpath(dirname(edit_path))
    edited_bytes = vcat(declarations[1].source_bytes.bytes,
        UInt8[0x0a, 0x23, 0x20, 0x52, 0x38, 0x2d, 0x65, 0x64, 0x69, 0x74])
    write(edit_path, edited_bytes)
    envelope_path = joinpath(fixture_root,
        split("docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json", '/')...)
    mkpath(dirname(envelope_path))
    write(envelope_path, read(joinpath(_T0L_REPO,
        "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json")))
    run(Cmd(["git", "-C", fixture_root, "init", "--quiet"]))
    run(Cmd(["git", "-C", fixture_root, "config", "user.email", "t0-local-r8@example.invalid"]))
    run(Cmd(["git", "-C", fixture_root, "config", "user.name", "T0 Local R8 Fixture"]))
    run(Cmd(["git", "-C", fixture_root, "add", fixture_source_path,
        "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json"]))
    run(Cmd(["git", "-C", fixture_root, "commit", "--quiet", "-m", "isolated T0 local R8 fixture"]))
    edited_source = G.VNextT0LocalBytesV1(edited_bytes, _t0l_sha(edited_bytes))
    edited_source_ref = G._vnl_t0_edit_ref(
        declarations[1].source_ref, edited_source.sha256, :source)
    legacy_edited_source_ref = G.QualifiedRefV1(string(declarations[1].source_ref.id,
        "#r8-source-", edited_source.sha256.value[1:16]), declarations[1].source_ref.version)
    @test edited_source_ref != legacy_edited_source_ref
    edited_locator = _t0l_local_locator(
        fixture_source_path, edited_source_ref, edited_source;
        provenance=:isolated_test_fixture, root=fixture_root)
    edit_body = G.VNextT0LocalSemanticBodyV1(declarations[1].semantic_body.body,
        _t0l_bytes(G.canonical_json(declarations[1].semantic_body.body)), ("r8-source-edit",))
    internal_rebuild = try
        G._vnl_t0_rebuild_after_source_edit_impl_v1(
            _T0L_CANDIDATE, declarations, children, feedback, :G1,
            edited_source, edit_body; new_source_locator=edited_locator,
            factory_builder=_t0l_factory_builder)
    catch err
        @error "fresh source edit internal rebuild diagnostic failed" exception=(err, catch_backtrace())
        @test false
        nothing
    end
    @test internal_rebuild !== nothing
    rebuilt = G.vnext_t0_local_rebuild_after_source_edit_v1(
        _T0L_CANDIDATE, declarations, children, feedback, :G1,
        edited_source, edit_body; new_source_locator=edited_locator,
        factory_builder=_t0l_factory_builder)
    @test rebuilt.admission.errors == ()
    @test rebuilt.admission.status === :valid
    @test rebuilt.admission.accepted === false
    @test rebuilt.admission.claim_ceiling === :contract_only
    @test rebuilt.admission.resolution === :terminal_deferred
    @test :g3_child_terminal_deferred in rebuilt.admission.gaps
    @test rebuilt.edit !== nothing
    @test rebuilt.admission.transport !== nothing
    if rebuilt.admission.status === :valid && rebuilt.admission.errors == () &&
            rebuilt.edit !== nothing && rebuilt.admission.transport !== nothing
        @test rebuilt.edit.new_candidate_ref != _T0L_CANDIDATE
        fresh = rebuilt.admission.transport
        @test all(x -> x isa G.VNextT0LocalPresentDeclarationV1, fresh.declarations)
        @test all(x -> x.candidate_ref == rebuilt.edit.new_candidate_ref, fresh.declarations)
        @test all(x -> x isa G.VNextT0LocalChildAbsentV1, fresh.children)
        @test all(x -> x.candidate_identity_created == false &&
            x.status === :terminal_deferred, fresh.children)
        @test all(i -> fresh.declarations[i].source_ref != declarations[i].source_ref, 1:3)
        @test all(i -> fresh.declarations[i].declaration_ref != declarations[i].declaration_ref, 1:3)
        @test G.vnext_t0_local_bundle_hash_recompute_v1(fresh) == fresh.bundle_hash
        old_identity_attempt = G.vnext_declaration_transport_local_v1(
            _T0L_CANDIDATE, fresh.declarations, fresh.children, fresh.feedback)
        @test old_identity_attempt.status === :fail_closed
        @test :foreign_candidate in old_identity_attempt.errors
    else
        @test false
    end
    rm(fixture_root; recursive=true, force=true)
end

@testset "local T0 keeps missing material typed-deferred and rejects labels only semantically" begin
    g1, g2 = _t0l_g1(), _t0l_g2()
    d1 = _t0l_present(:G1, g1); d2 = _t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl")
    absent = G.VNextT0LocalAbsentDeclarationV1(:G3, _T0L_CANDIDATE, :missing_material, :terminal_deferred)
    declarations = (d1, d2, absent)
    children = (_t0l_child(:realization), _t0l_child(:control), _t0l_child(:binding))
    present_children = (_t0l_child_present(:realization), _t0l_child_present(:control), _t0l_child_present(:binding))
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, declarations, children, (_t0l_feedback("g1-residual", d1.declaration_ref),))
    @test result.status === :valid
    @test result.accepted === false
    @test result.resolution === :terminal_deferred
    @test :declaration_material_terminal_deferred in result.gaps
    @test :g3_child_terminal_deferred in result.gaps
    nanbody = G.VNextT0LocalSemanticBodyV1((bad=NaN,), _t0l_bytes("nan"), ())
    nanrecord = G.VNextT0LocalPresentDeclarationV1(d1.layer, d1.candidate_ref, d1.source_ref, d1.declaration_ref, d1.source_identity_hash, d1.declaration_identity_hash, d1.axes, d1.source_bytes, d1.declaration_bytes, nanbody, d1.source_locator, d1.factory_receipt, d1.declaration_receipt)
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (nanrecord, d2, absent), children)
    @test result.status === :fail_closed
    @test :semantic_body_invalid in result.errors
    badchild = G.VNextT0LocalChildPresentV1(:realization, _T0L_CANDIDATE, :G3, "realization", present_children[1].child_ref, present_children[1].source_ref, present_children[1].source_bytes, present_children[1].source_locator, present_children[1].body, G.digest256_text("stale-child-body"), present_children[1].child_identity_hash)
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (d1, d2, absent), (badchild, children[2], children[3]))
    @test result.status === :fail_closed
    @test :child_body_hash_mismatch in result.errors
    contradictory_child_bytes = G.VNextT0LocalBytesV1(vcat(present_children[1].source_bytes.bytes, UInt8[0x00]), _t0l_sha(vcat(present_children[1].source_bytes.bytes, UInt8[0x00])))
    contradictory_child = G.VNextT0LocalChildPresentV1(:realization, _T0L_CANDIDATE, :G3, "realization", present_children[1].child_ref, present_children[1].source_ref, contradictory_child_bytes, present_children[1].source_locator, present_children[1].body, present_children[1].body_hash, present_children[1].child_identity_hash)
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (d1, d2, absent), (contradictory_child, children[2], children[3]))
    @test result.status === :fail_closed
    @test :child_locator_bytes_mismatch in result.errors
    bad_absent = _t0l_child(:control; candidate=G.QualifiedRefV1("local://foreign", "v5"))
    result = G.vnext_declaration_transport_local_v1(_T0L_CANDIDATE, (d1, d2, absent), (children[1], bad_absent, children[3]))
    @test result.status === :fail_closed
    @test :child_candidate_mismatch in result.errors
    @test_throws ArgumentError G.VNextT0LocalChildAbsentV1(:control, _T0L_CANDIDATE,
        :G3, "wrong-child-key", :terminal_deferred, "wrong child key", false, :G3,
        children[2].factory_receipt_bytes, children[2].factory_receipt_hash,
        children[2].source_path)
    body = (meaning="same", number=1 // 2)
    one = G.VNextT0LocalSemanticBodyV1(body, _t0l_bytes(G.canonical_json(body)), ("label-a",))
    two = G.VNextT0LocalSemanticBodyV1(body, _t0l_bytes(G.canonical_json(body)), ("label-b",))
    @test G.canonical_hash(one) == G.canonical_hash(two)
end

@testset "local T0 R20c G3 feedback projection is strict and deterministic" begin
    g1, g2, g3 = _t0l_g1(), _t0l_g2(), _t0l_g3()
    d1 = _t0l_present(:G1, g1)
    d2 = _t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl")
    d3 = _t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl")
    body = d3.semantic_body.body
    fresh_candidate = G.QualifiedRefV1("local://candidate/r20c", "v5")
    fresh_source = G.QualifiedRefV1("local://g3/source#r20c", "v1")
    rebound = G._vnl_t0_semantic_rebind_candidate(d3.semantic_body,
        fresh_candidate, fresh_source)
    rebound_again = G._vnl_t0_semantic_rebind_candidate(d3.semantic_body,
        fresh_candidate, fresh_source)
    @test rebound.bytes.bytes == rebound_again.bytes.bytes
    @test rebound.bytes.sha256 == rebound_again.bytes.sha256
    @test rebound.body.candidate_ref == fresh_candidate
    @test rebound.body.source_ref == fresh_source
    @test all(a -> a.candidate_ref == fresh_candidate &&
        a.status in (:missing, :historical_absent) &&
        a.contract_ref === nothing && a.source_ref === nothing,
        rebound.body.upstream_authority)
    @test all(t -> t.authority.candidate_ref == fresh_candidate &&
        t.authority.status in (:missing, :historical_absent), rebound.body.feedback_targets)
    fresh_feedback = G.g3_sf_declaration_v1(fresh_candidate, rebound.body.source_id,
        rebound.body.owner_scope, rebound.body.endpoints, rebound.body.law,
        rebound.body.ledger_entries, rebound.body.ledger_closure,
        rebound.body.feedback_targets, rebound.body.upstream_authority)
    @test G.g3_sf_validate_v1(fresh_feedback) == (:valid, ())

    # Every projection is checked before a rebind; a foreign authority in the
    # body cannot be hidden by changing only the outer candidate ref.
    foreign_authority = G.G3SFAuthorityV1(:G1,
        G.QualifiedRefV1("local://candidate/foreign-r20c", "v5"), nothing, nothing, :missing)
    foreign_targets = (G.G3SFFeedbackTargetV1(
        body.feedback_targets[1].target_id, :G1, body.feedback_targets[1].target_path,
        body.feedback_targets[1].quantity, body.feedback_targets[1].unit,
        body.feedback_targets[1].direction, body.feedback_targets[1].sign,
        body.feedback_targets[1].source_id, body.feedback_targets[1].owner_scope,
        foreign_authority), body.feedback_targets[2])
    foreign_body = merge(body, (upstream_authority=(foreign_authority, body.upstream_authority[2]),
        feedback_targets=foreign_targets))
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        G.VNextT0LocalSemanticBodyV1(foreign_body,
            _t0l_bytes(G.canonical_json(foreign_body)), ()), fresh_candidate, fresh_source)

    for status in (:stale, :contradictory)
        blocked = G.G3SFAuthorityV1(:G1, _T0L_CANDIDATE, nothing, nothing, status)
        blocked_targets = (G.G3SFFeedbackTargetV1(
            body.feedback_targets[1].target_id, :G1, body.feedback_targets[1].target_path,
            body.feedback_targets[1].quantity, body.feedback_targets[1].unit,
            body.feedback_targets[1].direction, body.feedback_targets[1].sign,
            body.feedback_targets[1].source_id, body.feedback_targets[1].owner_scope,
            blocked), body.feedback_targets[2])
        blocked_body = merge(body, (upstream_authority=(blocked, body.upstream_authority[2]),
            feedback_targets=blocked_targets))
        @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
            G.VNextT0LocalSemanticBodyV1(blocked_body,
                _t0l_bytes(G.canonical_json(blocked_body)), ()), fresh_candidate, fresh_source)
    end

    # An actual/materialized authority is never reinterpreted as a fresh local
    # receipt.  The constructor hash is exact, so this is a valid typed input
    # whose status alone must still fail closed for R20c rebinding.
    actual_source = G.QualifiedRefV1("fusionconceptai://GenomeV5/G1/r20c", "v1")
    actual_contract = G._g1sf_expected_contract()
    actual_sha = G.digest256_text("r20c-materialized-source")
    actual_hash = G.g3_sf_authority_content_hash_v1(:G1, _T0L_CANDIDATE,
        actual_contract, actual_source, 1, actual_sha)
    actual_authority = G.G3SFAuthorityV1(:G1, _T0L_CANDIDATE, actual_contract,
        actual_hash, :actual; attestation=:trusted_receipt, source_ref=actual_source,
        source_bytes=1, source_sha256=actual_sha)
    actual_targets = (G.G3SFFeedbackTargetV1(
        body.feedback_targets[1].target_id, :G1, body.feedback_targets[1].target_path,
        body.feedback_targets[1].quantity, body.feedback_targets[1].unit,
        body.feedback_targets[1].direction, body.feedback_targets[1].sign,
        body.feedback_targets[1].source_id, body.feedback_targets[1].owner_scope,
        actual_authority), body.feedback_targets[2])
    actual_body = merge(body, (upstream_authority=(actual_authority, body.upstream_authority[2]),
        feedback_targets=actual_targets))
    @test_throws ArgumentError G._vnl_t0_semantic_rebind_candidate(
        G.VNextT0LocalSemanticBodyV1(actual_body,
            _t0l_bytes(G.canonical_json(actual_body)), ()), fresh_candidate, fresh_source)

    # Source-vs-declaration target mapping is preserved, and unknown/ambiguous
    # refs are fail-closed.  Body hashes are recomputed only after projection.
    old_declarations = (d1, d2, d3)
    fresh_g1_source = G.QualifiedRefV1("local://g1/source#r20c-fresh", "v1")
    fresh_g1_declaration = G.QualifiedRefV1("factory://G1/declaration/r20c-fresh", "v1")
    fresh_g2_source = G.QualifiedRefV1("local://g2/source#r20c-fresh", "v1")
    fresh_g2_declaration = G.QualifiedRefV1("factory://G2/declaration/r20c-fresh", "v1")
    fresh_declarations = (_t0l_rekey_present(d1, fresh_g1_source, fresh_g1_declaration),
        _t0l_rekey_present(d2, fresh_g2_source, fresh_g2_declaration), d3)
    @test fresh_declarations[1].source_ref != old_declarations[1].source_ref
    @test fresh_declarations[1].declaration_ref != old_declarations[1].declaration_ref
    @test fresh_declarations[2].source_ref != old_declarations[2].source_ref
    @test fresh_declarations[2].declaration_ref != old_declarations[2].declaration_ref
    source_item = _t0l_feedback("g1-source", d1.source_ref; target_layer=:G1)
    declaration_item = _t0l_feedback("g2-declaration", d2.declaration_ref; target_layer=:G2)
    mapped_source = G._vnl_t0_rebind_feedback_item_v1(source_item, _T0L_CANDIDATE,
        fresh_candidate, old_declarations, fresh_declarations)
    mapped_declaration = G._vnl_t0_rebind_feedback_item_v1(declaration_item,
        _T0L_CANDIDATE, fresh_candidate, old_declarations, fresh_declarations)
    @test mapped_source.target_ref == fresh_g1_source
    @test mapped_declaration.target_ref == fresh_g2_declaration
    @test mapped_source.body_hash == G.canonical_hash(mapped_source.body)
    @test mapped_declaration.body_hash == G.canonical_hash(mapped_declaration.body)

    @test_throws ArgumentError _t0l_feedback("g1-wrong-layer", d1.source_ref;
        target_layer=:G2)
    @test_throws ArgumentError _t0l_feedback("g1-invalid-layer", d1.source_ref;
        target_layer=:G3)
    wrong_layer_body = (id="g1-wrong-layer", relation="same-bundle-target")
    wrong_layer_item = G.VNextT0LocalFeedbackV1("g1-wrong-layer", :G3,
        _T0L_CANDIDATE, d1.source_ref, wrong_layer_body,
        G.canonical_hash(wrong_layer_body))
    wrong_layer_result = G.vnext_declaration_transport_local_v1(
        _T0L_CANDIDATE, old_declarations,
        (_t0l_child(:realization), _t0l_child(:control), _t0l_child(:binding)),
        (wrong_layer_item,))
    @test wrong_layer_result.status === :fail_closed
    @test :feedback_layer_invalid in wrong_layer_result.errors
    foreign = _t0l_feedback("g1-foreign", G.QualifiedRefV1("foreign://target", "v1");
        target_layer=:G1)
    @test_throws ArgumentError G._vnl_t0_rebind_feedback_item_v1(foreign,
        _T0L_CANDIDATE, fresh_candidate, old_declarations, fresh_declarations)
    mismatched_candidate = _t0l_feedback("g1-candidate-mismatch", d1.source_ref;
        target_layer=:G1, candidate=G.QualifiedRefV1("local://candidate/foreign-r20c", "v5"))
    @test_throws ArgumentError G._vnl_t0_rebind_feedback_item_v1(mismatched_candidate,
        _T0L_CANDIDATE, fresh_candidate, old_declarations, fresh_declarations)
    bad_body_hash = G.VNextT0LocalFeedbackV1("g1-body-hash-mismatch", :G1,
        _T0L_CANDIDATE, d1.source_ref, source_item.body,
        G.digest256_text("r20c-stale-feedback-body-hash"))
    @test_throws ArgumentError G._vnl_t0_rebind_feedback_item_v1(bad_body_hash,
        _T0L_CANDIDATE, fresh_candidate, old_declarations, fresh_declarations)
    ambiguous_ref = G.QualifiedRefV1("local://g1/ambiguous-r20c", "v1")
    ambiguous_old = _t0l_rekey_present(d1, ambiguous_ref, ambiguous_ref)
    ambiguous_item = _t0l_feedback("g1-ambiguous", ambiguous_ref; target_layer=:G1)
    @test _t0l_expect_code(() -> G._vnl_t0_rebind_feedback_item_v1(ambiguous_item,
        _T0L_CANDIDATE, fresh_candidate,
        (ambiguous_old, d2, d3), fresh_declarations), "feedback_target_ref_ambiguous")
    unknown = _t0l_feedback("g1-unknown", G.QualifiedRefV1("local://unknown", "v1"))
    @test_throws ArgumentError G._vnl_t0_rebind_feedback_item_v1(unknown,
        _T0L_CANDIDATE, fresh_candidate, old_declarations, fresh_declarations)

    # Present children have no fresh candidate-bound receipt in this transport;
    # source edit therefore fails closed instead of blindly replacing identity.
    present_children = (_t0l_child_present(:realization),
        _t0l_child_present(:control), _t0l_child_present(:binding))
    edit_result = G.vnext_t0_local_rebuild_after_source_edit_v1(
        _T0L_CANDIDATE, old_declarations, present_children, (), :G1,
        d1.source_bytes, d1.semantic_body; factory_builder=_t0l_factory_builder)
    @test edit_result.admission.status === :fail_closed
    @test :present_g3_child_requires_fresh_receipt in edit_result.admission.errors
end

println("VNEXT_T0_LOCAL_STATIC_TEST_DEFINED=true")
println("VNEXT_T0_LOCAL_JULIA_OR_DESC_EXECUTED=false")
