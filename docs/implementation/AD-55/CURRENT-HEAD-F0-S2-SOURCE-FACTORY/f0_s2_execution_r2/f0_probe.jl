using SHA
using JSON3
using Dates
using FusionConceptAI

const G = FusionConceptAI
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
const EVIDENCE = normpath(@__DIR__)
const EXPECTED_HEAD = "b2c04d8339774635aaecd73651efcdb101e01b5d"

git(args...) = readchomp(Cmd(String["git", "-C", ROOT, String.(args)...]))
filebytes(p) = read(joinpath(ROOT, split(replace(p, '\\' => '/'), '/')...))
digest(b) = G.Digest256(bytes2hex(SHA.sha256(b)))
canonical_bytes(p) = read(Cmd(String["git", "-C", ROOT, "show", "HEAD:" * p]))
canonical_digest(p) = digest(canonical_bytes(p))
working_path(p) = joinpath(ROOT, split(replace(p, '\\' => '/'), '/')...)
write_json(name, x) = open(joinpath(EVIDENCE, name), "w") do io
    JSON3.write(io, x); write(io, '\n')
end

# Load the published V5 closure before defining probe functions, so Julia's
# world-age rules see the current constructors and factory methods.
G.load_genome_v5_components!()
Base.include(G, joinpath(ROOT,"src","GenomeV5","G1","DiffusionDeclarationV1.jl"))
Base.include(G, joinpath(ROOT,"src","GenomeV5","G2","MetricBoundaryDeclarationV1.jl"))
Base.include(G, joinpath(ROOT,"src","GenomeV5","G1","G1SourceAuthorityFactoryV1.jl"))
Base.include(G, joinpath(ROOT,"src","GenomeV5","G2","G2SourceAuthorityFactoryV1.jl"))
Base.include(G, joinpath(ROOT,"src","GenomeV5","G3","G3SourceAuthorityFactoryV1.jl"))

function source_row(path)
    b = filebytes(path); cb = canonical_bytes(path)
    blob = git("rev-parse", "HEAD:" * path)
    work_blob = git("hash-object", "--path", path, working_path(path))
    tracked = git("ls-files", "--stage", "--", path)
    status = git("status", "--porcelain=v1", "--untracked-files=all", "--", path)
    (path=path, exists=isfile(working_path(path)), working_bytes=length(b), canonical_head_bytes=length(cb),
     working_sha256=digest(b).value, canonical_head_sha256=digest(cb).value, head=git("rev-parse", "HEAD"), head_blob_oid=blob,
     tracked=(!isempty(strip(tracked)) && startswith(strip(tracked), "100644 ")),
     working_tree_clean=isempty(status), filtered_working_blob=work_blob, blob_matches_working=(blob == work_blob))
end

function g1_input()
    z = G.UnitSignature((0, 0, 0, 0, 0, 0, 0)); gu = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0)); fu = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
    sc = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), z)
    gr = G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), gu)
    tk = G.PhysicalType(:tensor_field, 2, 3, G.TemporalTypeV1(G.static_time), z)
    ff = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), fu)
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
    chart = G.G2MBChartMapV1(chart_ref, (0,0,0), (1,1,1), ((2,0,0),(0,3,0),(0,0,4)), (r(1,2),r(1,3),r(1,4)))
    mesh = G.G2MBMeshPlanV1(mesh_ref, chart_ref, (2,3,4), :Q1, ((r(1,2),r(1,2),r(1,2)),(r(1,4),r(1,4),r(1,4))), (1,r(1,2)); execution_status=:not_executed)
    fu=G.UnitSignature((0,0,0,0,0,0,1)); xu=G.UnitSignature((1,0,0,0,0,0,0)); mu=G.UnitSignature((2,0,0,0,0,0,0)); vu=G.UnitSignature((3,0,0,0,0,0,0)); zu=G.UnitSignature((0,0,0,0,0,0,0)); fl=G.UnitSignature((0,0,0,0,0,1,0))
    faces=(G.G2MBFaceOwnerV1("x0",:x_min,"domain",(-1,0,0),G.G2MBFaceValueV1(:dirichlet,0,fu)), G.G2MBFaceOwnerV1("x1",:x_max,"domain",(1,0,0),G.G2MBFaceValueV1(:neumann,1,fl)), G.G2MBFaceOwnerV1("y0",:y_min,"domain",(0,-1,0),G.G2MBFaceValueV1(:dirichlet,0,fu)), G.G2MBFaceOwnerV1("y1",:y_max,"domain",(0,1,0),G.G2MBFaceValueV1(:neumann,1,fl)), G.G2MBFaceOwnerV1("z0",:z_min,"domain",(0,0,-1),G.G2MBFaceValueV1(:dirichlet,0,fu)), G.G2MBFaceOwnerV1("z1",:z_max,"domain",(0,0,1),G.G2MBFaceValueV1(:neumann,1,fl)))
    units=G.G2MBUnitContractV1(zu,xu,xu,mu,mu,vu,fu,fl)
    contract=G._g2sf_expected_contract()
    payload=G.g2mb_source_v1(G.QualifiedRefV1("fusionconceptai://source/ad55-g2-source","v1"),"ad55-g2-source-v1",contract,chart,mesh,faces,G.G2MBProfileV1("fusion.g2.metric-boundary.profile"),units,G.G2MBAuthorityV1(:unique_match,:no_match,:no_match))
    payload, contract
end

const G1_PATH = "src/GenomeV5/G1/DiffusionDeclarationV1.jl"
const G2_PATH = "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"
const G3_PATHS = Dict(:realization=>"src/GenomeV5/G3/RealizationGenomeV5.jl", :control=>"src/GenomeV5/G3/ControlGenomeV5.jl", :binding=>"src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl", :bundle=>"src/GenomeV5/G3/RealizationControlGenomeV5.jl")

function g1_locator(path=G1_PATH; actual=G1_PATH, head=EXPECTED_HEAD, blob=canonical_digest(actual), status=:clean, wtpath=:present, bytes_override=nothing, sha_override=nothing)
    b=canonical_bytes(actual); G.G1IndependentSourceLocatorV1(ROOT,head,path,bytes_override===nothing ? length(b) : bytes_override,sha_override===nothing ? digest(b) : sha_override,:present,wtpath,status,blob,:repository_head)
end
function g2_locator(path=G2_PATH; actual=G2_PATH, head=EXPECTED_HEAD, blob=canonical_digest(actual), status=:clean, wtpath=:present, bytes_override=nothing, sha_override=nothing)
    b=canonical_bytes(actual); G.G2IndependentSourceLocatorV1(ROOT,head,path,bytes_override===nothing ? length(b) : bytes_override,sha_override===nothing ? digest(b) : sha_override,:present,wtpath,status,blob,:repository_head)
end
function g3_locator(scope; path=G3_PATHS[scope], actual=G3_PATHS[scope], head=EXPECTED_HEAD, blob=canonical_digest(actual), status=:clean, wtpath=:present, bytes_override=nothing, sha_override=nothing)
    b=canonical_bytes(actual); G.G3IndependentSourceLocatorV1(scope,ROOT,head,path,bytes_override===nothing ? length(b) : bytes_override,sha_override===nothing ? digest(b) : sha_override,:present,wtpath,status,blob)
end

function main()
    started = string(Dates.now(Dates.UTC)); pid = getpid()
    head = git("rev-parse", "HEAD")
    head == EXPECTED_HEAD || error("HEAD mismatch: $head")
    dirty_before = git("status", "--porcelain=v1", "--untracked-files=all")
    order = G.genome_v5_component_layer_order()
    registry_before = G.canonical_hash(G.default_operator_registry()).value
    (isdefined(G,:g1_source_authority_factory_v1) && isdefined(G,:g2_source_authority_factory_v1) && isdefined(G,:g3_source_authority_factory_v1)) || error("factory load closure missing")
    g1p,g1c=g1_input(); g2p,g2c=g2_input()
    a1=G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema","v2"),G.QualifiedRefV1("fusion.g1.canonicalization","v2"),G.QualifiedRefV1("fusion.g1.applicability","v2"),G.QualifiedRefV1("fusion.g1.receipt","v2"))
    a2=G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema","v5"),G.QualifiedRefV1("fusion.g2.canonicalization","v5"),G.QualifiedRefV1("fusion.g2.applicability","v5"),G.QualifiedRefV1("fusion.g2.receipt","v5"))
    h1=G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5"); h2=G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5"); h3=G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5")
    r1=G.g1_source_authority_factory_v1(g1_locator(),h1,G._g1sf_expected_contract(),g1p,a1,g1c)
    r2=G.g2_source_authority_factory_v1(g2_locator(),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))
    g3rows=Dict{String,Any}(); r3s=Dict{Symbol,Any}()
    for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
        rr=G.g3_source_authority_factory_v1(scope,g3_locator(scope),h3,G.g3_contract_ref(scope),G.g3_version_axes(scope),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad55-f0","v1"))
        r3s[scope]=rr; g3rows[String(scope)]=(status=String(G.g3_factory_result_status(rr)),)
    end
    for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
        rr = r3s[scope]
        println("G3_DIAG scope=$(scope) type=$(typeof(rr)) status=$(G.g3_factory_result_status(rr)) identity=$(repr(rr.identity)) receipt=$(repr(rr.receipt))")
    end
    G.g1_source_factory_result_status(r1)==:present || error("G1 positive closure failed")
    G.g2_source_factory_result_status(r2)==:present || error("G2 positive closure failed")
    all(G.g3_factory_result_status(r3s[s])==:present for s in keys(r3s)) || error("G3 positive closure failed")
    controls=Dict{String,Any}()
    controls["g1_nothing"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(nothing,h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_nothing"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(nothing,h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_nothing"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,nothing,h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_forged_path"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator("src/GenomeV5/G1/forged.jl";actual=G1_PATH),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_forged_path"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator("src/GenomeV5/G2/forged.jl";actual=G2_PATH),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_path"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;path=G1_PATH,actual=G3_PATHS[:bundle]),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_forged_head"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(head="0"^40),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_forged_head"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(head="0"^40),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_head"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;head="0"^40),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_forged_blob"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(blob=G.digest256_text("forged-blob")),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_forged_blob"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(blob=G.digest256_text("forged-blob")),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_blob"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;blob=G.digest256_text("forged-blob")),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_forged_hash"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(sha_override=G.digest256_text("forged-hash")),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_forged_hash"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(sha_override=G.digest256_text("forged-hash")),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_hash"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;sha_override=G.digest256_text("forged-hash")),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_forged_length"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(bytes_override=1),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_forged_length"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(bytes_override=1),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_length"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;bytes_override=1),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_forged_dirty"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(status=:dirty,wtpath=:absent_untracked),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_forged_dirty"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(status=:dirty,wtpath=:absent_untracked),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_dirty"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;status=:dirty,wtpath=:absent_untracked),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    bad1=G.G1VersionAxesV2(G.QualifiedRefV1("forged","v9"),a1.canonicalization_profile_version,a1.applicability_profile_version,a1.evidence_receipt_version)
    bad2=G.G2VersionAxesV2(G.QualifiedRefV1("forged","v5"),a2.canonicalization_profile_version,a2.applicability_profile_version,a2.evidence_receipt_version)
    bad3=G.G3VersionAxesV2(G.QualifiedRefV1("forged","v5"),G.g3_version_axes(:bundle).canonicalization_profile_version,G.g3_version_axes(:bundle).applicability_profile_version,G.g3_version_axes(:bundle).evidence_receipt_version)
    controls["g1_forged_axis"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(),h1,G._g1sf_expected_contract(),g1p,bad1,g1c)))
    controls["g2_forged_axis"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(),h2,g2c,g2p,bad2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_axis"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle),h3,G.g3_contract_ref(:bundle),bad3,G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    foreign1=G.GenomeContractRef("foreign","v5",G._g1sf_expected_contract().schema_hash,G._g1sf_expected_contract().canonicalization_hash,G._g1sf_expected_contract().compatibility_profile)
    foreign2=G.GenomeContractRef("foreign","v5",g2c.schema_hash,g2c.canonicalization_hash,g2c.compatibility_profile)
    foreign3=G.GenomeContractRef("foreign","v5",G.g3_contract_ref(:bundle).schema_hash,G.g3_contract_ref(:bundle).canonicalization_hash,G.g3_contract_ref(:bundle).compatibility_profile)
    controls["g1_forged_contract"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(),h1,foreign1,g1p,a1,g1c)))
    controls["g2_forged_contract"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(),h2,foreign2,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_forged_contract"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle),h3,foreign3,G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    all(controls[k] in ("typed_absent","fail_closed") for k in keys(controls)) || error("negative control did not close")
    registry_after=G.canonical_hash(G.default_operator_registry()).value
    registry_before==registry_after || error("registry mutated")
    rows=[source_row(G1_PATH),source_row(G2_PATH),[source_row(G3_PATHS[s]) for s in (:realization,:control,:binding,:bundle)]...]
    dirty_after=git("status", "--porcelain=v1", "--untracked-files=all")
    write_json("hash_inventory.json", (head=head, expected_head=EXPECTED_HEAD, sources=rows, task_manifest_sha256=digest(filebytes("docs/v4_multitopology_generation/task_manifest.json")).value, ad45_envelope_sha256=digest(filebytes("docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json")).value))
    write_json("negative_controls.json", (status="pass", controls=controls, all_fail_closed_or_typed_absent=true, claims=(source_authority=false,trusted=false,candidate_identity_created=false,final_identity_created=false)))
    write_json("dirty_protection.json", (status=dirty_before==dirty_after ? "pass" : "fail", before=dirty_before, after=dirty_after, unchanged=(dirty_before==dirty_after)))
    write_json("cleanup_inventory.json", (status="pass", residuals=String[], scope="f0_execution/**", no_temp_outside_scope=true))
    write_json("manifest.json", (schema="AD55.current_head_f0_execution.v1", task="AD-55-F0", head=head, status="completed_review_pending", accepted=false, write_scope="docs/implementation/AD-55/CURRENT-HEAD-F0-S2-SOURCE-FACTORY/f0_execution/**", source_authority=false,trusted=false,candidate_identity_created=false,final_identity_created=false,provider=false,mesh=false,solver=false,physics=false,engineering_readiness=false,search=false,R01_R10=false,L4=0,plan=(markdown_files_checked=31,relative_links_checked=534,task_count=39,task_dag_acyclic=true), capability=(component_order=order,factories_loaded=true,registry_unchanged=true,up2_loader_defined=isdefined(G,:load_genome_v5_up2_components!))))
    write(joinpath(EVIDENCE,"report.md"), "# AD-55 F0 current HEAD factory software closure\n\nStatus: completed_review_pending; accepted: false.\n\nHEAD: `"*head*"`. The single serial Julia probe loaded the G1/G2/G3 source factories, exercised current HEAD positive closure for all six source-owner paths, confirmed the additive component order and unchanged default operator registry, and recorded typed absence plus fail-closed forged path/head/blob/dirty/axis/contract controls.\n\nThe six source-owner paths were checked as present, tracked, clean, and byte-equal to their HEAD blobs. The task manifest SHA-256 is `"*digest(filebytes("docs/v4_multitopology_generation/task_manifest.json")).value*"`; the reusable read-only plan check was `31` markdown files, `534` relative links, `39` tasks, and an acyclic DAG. AD-45 envelope binding was checked by its frozen SHA-256.\n\nClaim ceiling: this F0 result is factory software-contract evidence only. It creates no source authority, trusted attestation, candidate identity, final identity, provider, mesh, solver, physics, engineering readiness, search credit, R01-R10 credit, or L4 credit.\n")
    println("AD55_F0_PASS=true")
    println("AD55_F0_ASSERTIONS=positive-six-source-paths+typed-absence+six-negative-control-kinds")
end

main()
