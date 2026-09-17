using Test
using SHA
using JSON3
using FusionConceptAI

const G = FusionConceptAI
const EVIDENCE = normpath(@__DIR__)
const ROOT = normpath(joinpath(EVIDENCE, "..", "..", "..", ".."))
const HEAD_EXPECTED = "b2c04d8339774635aaecd73651efcdb101e01b5d"

git(args...) = readchomp(Cmd(["git", "-C", ROOT, String.(args)...]))
bytes(path) = read(joinpath(ROOT, split(replace(path, '\\' => '/'), '/')...))
sha(bytes_) = Digest256(bytes2hex(SHA.sha256(bytes_)))
write_json(path, value) = open(joinpath(EVIDENCE, path), "w") do io; JSON3.write(io, value); write(io, '\n'); end
write_canonical(path, value) = open(joinpath(EVIDENCE, path), "w") do io; write(io, G.canonical_json(value)); write(io, '\n'); end

function locator_info(path)
    b = bytes(path)
    h = git("rev-parse", "HEAD")
    blob = git("rev-parse", "HEAD:" * path)
    G.Digest256(bytes2hex(SHA.sha256(b))), length(b), h, blob
end

function g1_input()
    u_sig = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
    gu_sig = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
    fu_sig = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    sc = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), u_sig)
    gr = G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), gu_sig)
    tk = G.PhysicalType(:tensor_field, 2, 3, G.TemporalTypeV1(G.static_time), u_sig)
    ff = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), fu_sig)
    source = G.QualifiedRefV1("fusionconceptai://source/ad55-g1-source", "v1")
    u = G.G1DiffusionScalarFieldV1("u", sc, source; source_expression="u=x")
    ke = G.G1DiffusionDiagonalAffineKFieldV1("Kexpr"; base_diag=(2, 3, 4), slope_diag=(1//10, 1//20, 1//30))
    k = G.G1DiffusionCoefficientFieldV1("K", tk, source; lower_bound=2, upper_bound=121//30, expression=ke)
    f = G.G1DiffusionScalarFieldV1("f", ff, source; source_expression="f=1")
    grad = G.G1TypedGradV1(G.QualifiedRefV1("fusionconceptai://G1/GRAD", "v1"), "u", "grad_u", sc, gr)
    kap = G.G1TypedKApplyV1(G.QualifiedRefV1("fusionconceptai://G1/K_APPLY", "v1"), "grad_u", "flux_u", gr, gr, "K")
    div = G.G1TypedDivV1(G.QualifiedRefV1("fusionconceptai://G1/DIV", "v1"), "flux_u", "f", gr, ff)
    chain = G.G1DiffusionOperatorChainV1(grad, kap, div, "f")
    payload = G.G1DiffusionSourcePayloadV1(source, "ad55-g1-source-v1", u, k, f)
    ctor = G.G1SourceDeclarationConstructorV1(G.g1_diffusion_declaration_v1,
        G.QualifiedRefV1("fusionconceptai://source-stage/ad55/G1/declaration", "v5"), chain,
        G.QualifiedRefV1("fusionconceptai://G1/ad55-closure", "v1"),
        G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1, "v1"),
        "ad55-current-head-domain", (:missing_authoritative_source,))
    payload, ctor
end

function g2_input()
    r(n, d=1) = Int64(n) // Int64(d)
    chart_ref = G.QualifiedRefV1("fusionconceptai://source/ad55-g2-chart", "v1")
    mesh_ref = G.QualifiedRefV1("fusionconceptai://source/ad55-g2-mesh", "v1")
    chart = G.G2MBChartMapV1(chart_ref, (0, 0, 0), (1, 1, 1), ((2, 0, 0), (0, 3, 0), (0, 0, 4)), (r(1,2), r(1,3), r(1,4)))
    mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, (2, 3, 4), :Q1, ((r(1,2), r(1,2), r(1,2)), (r(1,4), r(1,4), r(1,4))), (1, r(1,2)); execution_status=:not_executed)
    fu = G.UnitSignature((0, 0, 0, 0, 0, 0, 1)); xu = G.UnitSignature((1, 0, 0, 0, 0, 0, 0)); mu = G.UnitSignature((2, 0, 0, 0, 0, 0, 0)); vu = G.UnitSignature((3, 0, 0, 0, 0, 0, 0)); zu = G.UnitSignature((0, 0, 0, 0, 0, 0, 0)); fl = G.UnitSignature((0, 0, 0, 0, 0, 1, 0))
    faces = (G.G2MBFaceOwnerV1("x0", :x_min, "domain", (-1,0,0), G.G2MBFaceValueV1(:dirichlet, 0, fu)), G.G2MBFaceOwnerV1("x1", :x_max, "domain", (1,0,0), G.G2MBFaceValueV1(:neumann, 1, fl)), G.G2MBFaceOwnerV1("y0", :y_min, "domain", (0,-1,0), G.G2MBFaceValueV1(:dirichlet, 0, fu)), G.G2MBFaceOwnerV1("y1", :y_max, "domain", (0,1,0), G.G2MBFaceValueV1(:neumann, 1, fl)), G.G2MBFaceOwnerV1("z0", :z_min, "domain", (0,0,-1), G.G2MBFaceValueV1(:dirichlet, 0, fu)), G.G2MBFaceOwnerV1("z1", :z_max, "domain", (0,0,1), G.G2MBFaceValueV1(:neumann, 1, fl)))
    profile = G.G2MBProfileV1("fusion.g2.metric-boundary.profile")
    units = G.G2MBUnitContractV1(zu, xu, xu, mu, mu, vu, fu, fl)
    contract = G._g2sf_expected_contract()
    payload = G.g2mb_source_v1(G.QualifiedRefV1("fusionconceptai://source/ad55-g2-source", "v1"), "ad55-g2-source-v1", contract, chart, mesh, faces, profile, units, G.G2MBAuthorityV1(:unique_match, :no_match, :no_match))
    payload, contract
end

function repo_locator_g1(path)
    digest, n, head, blob = locator_info(path)
    G.G1IndependentSourceLocatorV1(ROOT, head, path, n, digest, :present, :present, :clean, G.Digest256(bytes2hex(SHA.sha256(bytes(path)))), :repository_head)
end
function repo_locator_g2(path)
    digest, n, head, blob = locator_info(path)
    G.G2IndependentSourceLocatorV1(ROOT, head, path, n, digest, :present, :present, :clean, G.Digest256(bytes2hex(SHA.sha256(bytes(path)))), :repository_head)
end
function repo_locator_g3(scope, path)
    digest, n, head, blob = locator_info(path)
    G.G3IndependentSourceLocatorV1(scope, ROOT, head, path, n, digest, :present, :present, :clean, digest)
end

function f0()
    checks = String[]
    check(label, condition) = (condition || error("F0 assertion failed: " * label); push!(checks, label); true)
    check("HEAD", git("rev-parse", "HEAD") == HEAD_EXPECTED)
    G.load_genome_v5_components!()
    check("component_order", G.genome_v5_component_layer_order() == (:G1, :G2, :G3))
    before = G.canonical_hash(G.default_operator_registry())
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
    check("g1_factory_defined", isdefined(G, :g1_source_authority_factory_v1))
    check("g2_factory_defined", isdefined(G, :g2_source_authority_factory_v1))
    check("g3_factory_defined", isdefined(G, :g3_source_authority_factory_v1))
    check("registry_unchanged_after_include", G.canonical_hash(G.default_operator_registry()) == before)
    g1p, g1c = g1_input(); g2p, g2contract = g2_input()
    g1axes = G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema", "v2"), G.QualifiedRefV1("fusion.g1.canonicalization", "v2"), G.QualifiedRefV1("fusion.g1.applicability", "v2"), G.QualifiedRefV1("fusion.g1.receipt", "v2"))
    g2axes = G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema", "v5"), G.QualifiedRefV1("fusion.g2.canonicalization", "v5"), G.QualifiedRefV1("fusion.g2.applicability", "v5"), G.QualifiedRefV1("fusion.g2.receipt", "v5"))
    handle = G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")
    g1loc = repo_locator_g1(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
    g2loc = repo_locator_g2(G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1)
    g1 = G.g1_source_authority_factory_v1(g1loc, handle, G._g1sf_expected_contract(), g1p, g1axes, g1c)
    g2 = G.g2_source_authority_factory_v1(g2loc, G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"), g2contract, g2p, g2axes, G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))
    check("g1_negative_nothing_typed_absent", G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(nothing, handle, G._g1sf_expected_contract(), g1p, g1axes, g1c)) == :typed_absent)
    check("g2_negative_nothing_typed_absent", G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(nothing, handle, g2contract, g2p, g2axes, G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))) == :typed_absent)
    stale1 = G.G1IndependentSourceLocatorV1(ROOT, "0000000000000000000000000000000000000000", g1loc.source_path, g1loc.source_bytes, g1loc.source_sha256, :present, :present, :clean, g1loc.head_blob_sha256, :repository_head)
    stale2 = G.G2IndependentSourceLocatorV1(ROOT, "0000000000000000000000000000000000000000", g2loc.source_path, g2loc.source_bytes, g2loc.source_sha256, :present, :present, :clean, g2loc.head_blob_sha256, :repository_head)
    check("g1_negative_stale_head_fail_closed", G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(stale1, handle, G._g1sf_expected_contract(), g1p, g1axes, g1c)) == :fail_closed)
    check("g2_negative_stale_head_fail_closed", G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(stale2, G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"), g2contract, g2p, g2axes, G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))) == :fail_closed)
    check("g1_positive_closure", G.g1_source_factory_result_status(g1) == :present)
    check("g2_positive_closure", G.g2_source_factory_result_status(g2) == :present)
    check("registry_unchanged_after_calls", G.canonical_hash(G.default_operator_registry()) == before)
    g3rows = Dict{String,Any}()
    for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
        path = Dict(:realization=>"src/GenomeV5/G3/RealizationGenomeV5.jl", :control=>"src/GenomeV5/G3/ControlGenomeV5.jl", :binding=>"src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl", :bundle=>"src/GenomeV5/G3/RealizationControlGenomeV5.jl")[scope]
        loc = repo_locator_g3(scope, path)
        r = G.g3_source_authority_factory_v1(scope, loc, G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"), G.g3_contract_ref(scope), G.g3_version_axes(scope), G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad55-s2", "v1"))
        check("g3_positive_" * String(scope), G.g3_factory_result_status(r) == :present)
        g3rows[String(scope)] = (status=String(G.g3_factory_result_status(r)),)
    end
    check("g3_negative_missing_typed_absent", G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle, nothing, G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"), G.g3_contract_ref(:bundle), G.g3_version_axes(:bundle), G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-s2", "v1"))) == :typed_absent)
    check("registry_unchanged_final", G.canonical_hash(G.default_operator_registry()) == before)
    write_json("f0_probe_results.json", (task="AD-55", stage="F0", status="pass", head=git("rev-parse", "HEAD"), assertions=checks, assertion_count=length(checks), registry_hash=before.value, g3=g3rows, claims=(candidate_identity_created=false, final_candidate_or_package_declaration_hash_created=false, trusted_attestation_created=false, provider=false, mesh=false, solver=false, engineering_readiness=false, physics=false, search=false, R01_R10=false, L4=0)))
    println("AD55_F0_PASS=true")
    println("AD55_F0_ASSERTIONS=" * string(length(checks)))
end

function s2()
    G.load_genome_v5_components!()
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))
    Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
    git("rev-parse", "HEAD") == HEAD_EXPECTED || error("S2 HEAD mismatch")
    g1p, g1c = g1_input(); g2p, g2contract = g2_input()
    g1axes = G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema", "v2"), G.QualifiedRefV1("fusion.g1.canonicalization", "v2"), G.QualifiedRefV1("fusion.g1.applicability", "v2"), G.QualifiedRefV1("fusion.g1.receipt", "v2"))
    g2axes = G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema", "v5"), G.QualifiedRefV1("fusion.g2.canonicalization", "v5"), G.QualifiedRefV1("fusion.g2.applicability", "v5"), G.QualifiedRefV1("fusion.g2.receipt", "v5"))
    h1 = G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"); h2 = G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5"); h3 = G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1, "v5")
    g1 = G.g1_source_authority_factory_v1(repo_locator_g1(G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1), h1, G._g1sf_expected_contract(), g1p, g1axes, g1c)
    g2 = G.g2_source_authority_factory_v1(repo_locator_g2(G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1), h2, g2contract, g2p, g2axes, G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))
    G.g1_source_factory_result_status(g1) == :present || error("G1 current repository source locator did not produce present")
    G.g2_source_factory_result_status(g2) == :present || error("G2 current repository source locator did not produce present")
    write_canonical("g1_factory_identity.json", g1.identity); write_canonical("g1_source_declaration.json", g1.source_declaration); write_canonical("g1_construction_receipt.json", g1.receipt)
    write_canonical("g2_factory_identity.json", g2.identity); write_canonical("g2_source_declaration.json", g2.source_declaration); write_canonical("g2_construction_receipt.json", g2.receipt)
    rows = Dict{String,Any}()
    paths = Dict(:realization=>"src/GenomeV5/G3/RealizationGenomeV5.jl", :control=>"src/GenomeV5/G3/ControlGenomeV5.jl", :binding=>"src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl", :bundle=>"src/GenomeV5/G3/RealizationControlGenomeV5.jl")
    for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
        r = G.g3_source_authority_factory_v1(scope, repo_locator_g3(scope, paths[scope]), h3, G.g3_contract_ref(scope), G.g3_version_axes(scope), G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad55-s2", "v1"))
        G.g3_factory_result_status(r) == :present || error("G3 current repository source locator did not produce present for " * String(scope))
        key = String(scope)
        write_canonical("g3_" * key * "_factory_identity.json", r.identity); write_canonical("g3_" * key * "_source_declaration.json", r.source_declaration); write_canonical("g3_" * key * "_construction_receipt.json", r.receipt)
        rows[key] = (identity_hash=G.canonical_hash(r.identity).value, declaration_hash=G.canonical_hash(r.source_declaration).value, receipt_hash=G.canonical_hash(r.receipt).value, status="present")
    end
    write_json("s2_results.json", (task="AD-55", stage="S2", head=git("rev-parse", "HEAD"), g1=(identity_hash=G.canonical_hash(g1.identity).value, declaration_hash=G.canonical_hash(g1.source_declaration).value, receipt_hash=G.canonical_hash(g1.receipt).value, status="present"), g2=(identity_hash=G.canonical_hash(g2.identity).value, declaration_hash=G.canonical_hash(g2.source_declaration).value, receipt_hash=G.canonical_hash(g2.receipt).value, status="present"), g3=rows, claims=(candidate_identity_created=false, final_candidate_or_package_declaration_hash_created=false, trusted_attestation_created=false, provider=false, mesh=false, solver=false, engineering_readiness=false, physics=false, search=false, R01_R10=false, L4=0)))
    println("AD55_S2_PASS=true")
    println("AD55_S2_CANONICAL_RESULTS_WRITTEN=true")
end

mode = isempty(ARGS) ? "f0" : ARGS[1]
mode == "f0" ? f0() : mode == "s2" ? s2() : error("unknown mode: " * mode)
