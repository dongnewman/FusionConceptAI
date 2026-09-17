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

function canon(x)
    x isa G.Digest256 && return x.value
    x isa Symbol && return String(x)
    if x isa AbstractString || x isa Number || x isa Bool || x === nothing
        return x
    end
    x isa NamedTuple && return Dict{String,Any}(string(k)=>canon(getfield(x,k)) for k in keys(x))
    (x isa Tuple || x isa AbstractVector) && return [canon(v) for v in x]
    x isa AbstractDict && return Dict{String,Any}(string(k)=>canon(v) for (k,v) in x)
    isstructtype(typeof(x)) && return Dict{String,Any}(string(f)=>canon(getfield(x,f)) for f in fieldnames(typeof(x)))
    string(x)
end
write_canon(name,x) = write_json(name, canon(x))

function main()
    started=string(Dates.now(Dates.UTC)); head=git("rev-parse","HEAD"); head==EXPECTED_HEAD || error("HEAD mismatch: $head")
    dirty_before=git("status","--porcelain=v1","--untracked-files=all")
    g1p,g1c=g1_input(); g2p,g2c=g2_input()
    a1=G.G1VersionAxesV2(G.QualifiedRefV1("fusion.g1.payload-schema","v2"),G.QualifiedRefV1("fusion.g1.canonicalization","v2"),G.QualifiedRefV1("fusion.g1.applicability","v2"),G.QualifiedRefV1("fusion.g1.receipt","v2"))
    a2=G.G2VersionAxesV2(G.QualifiedRefV1("fusion.g2.payload-schema","v5"),G.QualifiedRefV1("fusion.g2.canonicalization","v5"),G.QualifiedRefV1("fusion.g2.applicability","v5"),G.QualifiedRefV1("fusion.g2.receipt","v5"))
    h1=G.QualifiedRefV1(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5"); h2=G.QualifiedRefV1(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5"); h3=G.QualifiedRefV1(G.G3_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5")
    r1=G.g1_source_authority_factory_v1(g1_locator(),h1,G._g1sf_expected_contract(),g1p,a1,g1c)
    r2=G.g2_source_authority_factory_v1(g2_locator(),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))
    G.g1_source_factory_result_status(r1)==:present || error("G1 S2 not present")
    G.g2_source_factory_result_status(r2)==:present || error("G2 S2 not present")
    write_canon("g1_identity.json",G.semantic_view(r1.identity)); write_canon("g1_declaration.json",G.semantic_view(r1.source_declaration)); write_canon("g1_receipt.json",G.semantic_view(r1.receipt))
    write_canon("g2_identity.json",G.semantic_view(r2.identity)); write_canon("g2_declaration.json",G.semantic_view(r2.source_declaration)); write_canon("g2_receipt.json",G.semantic_view(r2.receipt))
    statuses=Dict{String,Any}(); g3s=Dict{Symbol,Any}()
    for scope in G.G3_SOURCE_AUTHORITY_FACTORY_SCOPES_V1
        rr=G.g3_source_authority_factory_v1(scope,g3_locator(scope),h3,G.g3_contract_ref(scope),G.g3_version_axes(scope),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/$(scope)/source-declaration/ad55-f0","v1")); g3s[scope]=rr
        G.g3_factory_result_status(rr)==:present || error("G3 S2 not present: $scope")
        write_canon("g3_$(scope)_identity.json",G.semantic_view(rr.identity)); write_canon("g3_$(scope)_declaration.json",G.semantic_view(rr.source_declaration)); write_canon("g3_$(scope)_receipt.json",G.semantic_view(rr.receipt)); statuses[String(scope)]="present"
    end
    controls=Dict{String,String}()
    controls["g1_nothing"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(nothing,h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_nothing"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(nothing,h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_nothing"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,nothing,h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_path"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator("src/GenomeV5/G1/forged.jl";actual=G1_PATH),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_path"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator("src/GenomeV5/G2/forged.jl";actual=G2_PATH),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_path"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;path=G1_PATH),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_head"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(head="0"^40),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_head"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(head="0"^40),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_head"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;head="0"^40),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_blob"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(blob=G.digest256_text("forged")),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_blob"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(blob=G.digest256_text("forged")),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_blob"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;blob=G.digest256_text("forged")),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_dirty"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(status=:dirty,wtpath=:absent_untracked),h1,G._g1sf_expected_contract(),g1p,a1,g1c)))
    controls["g2_dirty"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(status=:dirty,wtpath=:absent_untracked),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1))))
    controls["g3_dirty"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;status=:dirty,wtpath=:absent_untracked),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    bad1=G.G1VersionAxesV2(G.QualifiedRefV1("forged","v9"),a1.canonicalization_profile_version,a1.applicability_profile_version,a1.evidence_receipt_version); bad2=G.G2VersionAxesV2(G.QualifiedRefV1("forged","v5"),a2.canonicalization_profile_version,a2.applicability_profile_version,a2.evidence_receipt_version); ba3=G.g3_version_axes(:bundle); bad3=G.G3VersionAxesV2(G.QualifiedRefV1("forged","v5"),ba3.canonicalization_profile_version,ba3.applicability_profile_version,ba3.evidence_receipt_version)
    controls["g1_axis"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(),h1,G._g1sf_expected_contract(),g1p,bad1,g1c))); controls["g2_axis"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(),h2,g2c,g2p,bad2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)))); controls["g3_axis"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle),h3,G.g3_contract_ref(:bundle),bad3,G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    foreign1=G.GenomeContractRef("foreign","v5",G._g1sf_expected_contract().schema_hash,G._g1sf_expected_contract().canonicalization_hash,G._g1sf_expected_contract().compatibility_profile); foreign2=G.GenomeContractRef("foreign","v5",g2c.schema_hash,g2c.canonicalization_hash,g2c.compatibility_profile); foreign3=G.GenomeContractRef("foreign","v5",G.g3_contract_ref(:bundle).schema_hash,G.g3_contract_ref(:bundle).canonicalization_hash,G.g3_contract_ref(:bundle).compatibility_profile)
    controls["g1_contract"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(),h1,foreign1,g1p,a1,g1c))); controls["g2_contract"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(),h2,foreign2,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)))); controls["g3_contract"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle),h3,foreign3,G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_hash"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(sha_override=G.digest256_text("forged")),h1,G._g1sf_expected_contract(),g1p,a1,g1c))); controls["g2_hash"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(sha_override=G.digest256_text("forged")),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)))); controls["g3_hash"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;sha_override=G.digest256_text("forged")),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    controls["g1_length"]=String(G.g1_source_factory_result_status(G.g1_source_authority_factory_v1(g1_locator(bytes_override=1),h1,G._g1sf_expected_contract(),g1p,a1,g1c))); controls["g2_length"]=String(G.g2_source_factory_result_status(G.g2_source_authority_factory_v1(g2_locator(bytes_override=1),h2,g2c,g2p,a2,G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)))); controls["g3_length"]=String(G.g3_factory_result_status(G.g3_source_authority_factory_v1(:bundle,g3_locator(:bundle;bytes_override=1),h3,G.g3_contract_ref(:bundle),G.g3_version_axes(:bundle),G.QualifiedRefV1("fusionconceptai://GenomeV5/G3/bundle/source-declaration/ad55-f0","v1"))))
    all(controls[k] == "fail_closed" for k in keys(controls) if !endswith(k,"nothing")) || error("negative control did not fail closed"); controls["g1_nothing"]=="typed_absent" && controls["g2_nothing"]=="typed_absent" && controls["g3_nothing"]=="typed_absent" || error("nothing control did not typed_absent")
    write_json("negative_controls.json",(status="pass",controls=controls,claims=(source_authority=false,trusted=false,candidate_identity_created=false,final_identity_created=false,provider=false,mesh=false,solver=false,engineering_readiness=false,physics=false,search=false,R01_R10=false,L4=0)))
    write_json("s2_status.json",(head=head,status="pass",g1="present",g2="present",g3=statuses,started_utc=started))
    println("AD55_S2_PASS=true"); println("AD55_S2_SCOPES=6"); println("AD55_S2_NEGATIVE_CONTROLS=pass")
end
main()
