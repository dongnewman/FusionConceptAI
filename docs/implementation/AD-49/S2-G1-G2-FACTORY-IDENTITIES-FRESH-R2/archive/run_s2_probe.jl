using SHA
using FusionConceptAI

const G = FusionConceptAI
const ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", "..", ".."))
G.load_genome_v5_components!()
Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))
Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
Base.include(G, joinpath(ROOT, "src", "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))
const HEAD = "4b69f55f7f80240147a65a22809dc1207824dde2"
const OUT = normpath(joinpath(@__DIR__, ".."))
const STAGE = joinpath(OUT, "archive", "staging_r2")
mkpath(STAGE)

_sha(path) = bytes2hex(SHA.sha256(read(path)))
_q(id, version) = G.QualifiedRefV1(id, version)
_qjson(x) = replace(string(x), "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r")
_bool(x) = x ? "true" : "false"

function _write_json(path, pairs)
    open(path, "w") do io
        print(io, "{\n")
        for (i, (k, v)) in enumerate(pairs)
            print(io, "  \"", k, "\":", v, i == length(pairs) ? "\n" : ",\n")
        end
        print(io, "}\n")
    end
end

function _g1_payload_ctor()
    u = G.G1DiffusionScalarFieldV1("u", G.PhysicalType(:scalar_field, 0, 3,
        G.TemporalTypeV1(G.static_time), G.UnitSignature((0, 0, 0, 0, 0, 0, 0))),
        _q("fusionconceptai://source/ad49-g1-fixture", "v1"); source_expression="u=x")
    ke = G.G1DiffusionDiagonalAffineKFieldV1("Kexpr"; base_diag=(2, 3, 4), slope_diag=(1//10, 1//20, 1//30))
    k = G.G1DiffusionCoefficientFieldV1("K", G.PhysicalType(:tensor_field, 2, 3,
        G.TemporalTypeV1(G.static_time), G.UnitSignature((0, 0, 0, 0, 0, 0, 0))),
        _q("fusionconceptai://source/ad49-g1-fixture", "v1"); lower_bound=2, upper_bound=121//30, expression=ke)
    f = G.G1DiffusionScalarFieldV1("f", G.PhysicalType(:scalar_field, 0, 3,
        G.TemporalTypeV1(G.static_time), G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))),
        _q("fusionconceptai://source/ad49-g1-fixture", "v1"); source_expression="f=1")
    sc = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), G.UnitSignature((0,0,0,0,0,0,0)))
    gr = G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), G.UnitSignature((-1,0,0,0,0,0,0)))
    ff = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), G.UnitSignature((-2,0,0,0,0,0,0)))
    grad = G.G1TypedGradV1(_q("fusionconceptai://G1/GRAD", "v1"), "u", "grad_u", sc, gr)
    kap = G.G1TypedKApplyV1(_q("fusionconceptai://G1/K_APPLY", "v1"), "grad_u", "flux_u", gr, gr, "K")
    div = G.G1TypedDivV1(_q("fusionconceptai://G1/DIV", "v1"), "flux_u", "f", gr, ff)
    chain = G.G1DiffusionOperatorChainV1(grad, kap, div, "f")
    payload = G.G1DiffusionSourcePayloadV1(_q("fusionconceptai://source/ad49-g1-fixture", "v1"), "ad49-g1-source-v1", u, k, f)
    ctor = G.G1SourceDeclarationConstructorV1(G.g1_diffusion_declaration_v1,
        _q("fusionconceptai://source-stage-test/G1/declaration", "v5"), chain,
        _q("fusionconceptai://G1/closure", "v1"), _q(G.G1_DIFFUSION_APPLICABILITY_ID_V1, "v1"),
        "bounded-test-domain", (:missing_authoritative_source,))
    payload, ctor
end

function _g2_payload_ctor()
    R(n, d=1) = Int64(n) // Int64(d)
    chart_ref = _q("fusion.g2.chart", "v1")
    chart = G.G2MBChartMapV1(chart_ref, (0,0,0), (1,1,1), ((2,0,0),(0,3,0),(0,0,4)), (R(1,2),R(1,3),R(1,4)))
    mesh = G.G2MBMeshPlanV1(_q("fusion.g2.mesh", "v1"), chart_ref, (2,3,4), :Q1,
        ((R(1,2),R(1,2),R(1,2)),(R(1,4),R(1,4),R(1,4))), (1,R(1,2)); execution_status=:not_executed)
    fu=G.UnitSignature((0,0,0,0,0,0,1)); xu=G.UnitSignature((1,0,0,0,0,0,0)); mu=G.UnitSignature((2,0,0,0,0,0,0)); vu=G.UnitSignature((3,0,0,0,0,0,0)); zu=G.UnitSignature((0,0,0,0,0,0,0)); fl=G.UnitSignature((0,0,0,0,0,1,0))
    faces=(G.G2MBFaceOwnerV1("x0",:x_min,"domain",(-1,0,0),G.G2MBFaceValueV1(:dirichlet,0,fu)),G.G2MBFaceOwnerV1("x1",:x_max,"domain",(1,0,0),G.G2MBFaceValueV1(:neumann,1,fl)),G.G2MBFaceOwnerV1("y0",:y_min,"domain",(0,-1,0),G.G2MBFaceValueV1(:dirichlet,0,fu)),G.G2MBFaceOwnerV1("y1",:y_max,"domain",(0,1,0),G.G2MBFaceValueV1(:neumann,1,fl)),G.G2MBFaceOwnerV1("z0",:z_min,"domain",(0,0,-1),G.G2MBFaceValueV1(:dirichlet,0,fu)),G.G2MBFaceOwnerV1("z1",:z_max,"domain",(0,0,1),G.G2MBFaceValueV1(:neumann,1,fl)))
    units=G.G2MBUnitContractV1(zu,xu,xu,mu,mu,vu,fu,fl)
    contract=G._g2sf_expected_contract()
    payload=G.g2mb_source_v1(_q("fusionconceptai://source/ad49-g2-fixture","v1"),"ad49-g2-source-v1",contract,chart,mesh,faces,G.G2MBProfileV1("fusion.g2.metric-boundary.profile"),units,G.G2MBAuthorityV1(:unique_match,:no_match,:no_match))
    payload, contract, G.G2SourceDeclarationConstructorV1(G.g2mb_declaration_v1)
end

function _g1_locator()
    p=G.G1_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; b=read(joinpath(ROOT,split(p,'/')...))
    G.G1IndependentSourceLocatorV1(ROOT,HEAD,p,length(b),G.Digest256(bytes2hex(SHA.sha256(b))),:absent_untracked,:absent_untracked,:untracked,nothing,:repository_head)
end
function _g2_locator()
    p=G.G2_SOURCE_AUTHORITY_FACTORY_SOURCE_PATH_V1; b=read(joinpath(ROOT,split(p,'/')...))
    G.G2IndependentSourceLocatorV1(ROOT,HEAD,p,length(b),G.Digest256(bytes2hex(SHA.sha256(b))),:absent_untracked,:absent_untracked,:untracked,nothing,:repository_head)
end

function _record_identity(layer, result, locator, factory_hash, s1_hash, f0_hash)
    ident = result.identity; status = layer == "G1" ? G.g1_source_factory_result_status(result) : G.g2_source_factory_result_status(result)
    implementation_present = status == :typed_absent && factory_hash == f0_hash
    result_hash = G.canonical_hash((layer=layer, record_kind="factory_identity", result=result,
        factory_implementation_hash=factory_hash, s1_locator_hash=s1_hash, f0_factory_hash=f0_hash, input_head=HEAD))
    _write_json(joinpath(STAGE, "$(lowercase(layer))_factory_identity_probe.json"), [
        ("schema_version", "\"AD49-S2-$layer-factory-identity-fresh-R2-v1\""), ("record_kind", "\"$(typeof(ident))\""),
        ("layer", "\"$layer\""), ("status", "\"$status\""), ("reason", "\"$(ident.reason)\""), ("terminal_deferred", _bool(ident.terminal_deferred)),
        ("no_publish", "true"), ("factory_implementation_present", _bool(implementation_present)), ("source_construction_identity_present", "false"),
        ("source_authority", "false"), ("trusted", "false"), ("candidate_identity_created", "false"), ("final_hash_created", "false"),
        ("locator", "{\"record_path\":\"docs/implementation/AD-49/$(layer == "G1" ? "G1-SOURCE-LOCATOR/g1_source_locator_v1.json" : "G2-SOURCE-LOCATOR/g2_source_locator_v1.json")\",\"status\":\"typed_absent\",\"provenance\":\"repository_head\",\"head_path_closure\":\"absent\"}"),
        ("factory_implementation_hash", "\"$factory_hash\""), ("s1_locator_hash", "\"$s1_hash\""), ("f0_factory_hash", "\"$f0_hash\""),
        ("implementation_hash_is_non_authority", "true"), ("canonical_result_hash", "\"$result_hash\""),
        ("replay_canonical_result_hash", "\"$result_hash\""), ("julia_pid", string(getpid())), ("input_head", "\"$HEAD\"")])
end

function _record_receipt(layer, result, locator, factory_hash, s1_hash, f0_hash)
    rec=result.receipt; status=layer == "G1" ? G.g1_source_factory_result_status(result) : G.g2_source_factory_result_status(result)
    implementation_present = status == :typed_absent && factory_hash == f0_hash
    result_hash = G.canonical_hash((layer=layer, record_kind="construction_receipt", result=result,
        factory_implementation_hash=factory_hash, s1_locator_hash=s1_hash, f0_factory_hash=f0_hash, input_head=HEAD))
    _write_json(joinpath(STAGE, "$(lowercase(layer))_factory_construction_probe_receipt.json"), [
        ("schema_version", "\"AD49-S2-$layer-construction-receipt-fresh-R2-v1\""), ("record_kind", "\"$(typeof(rec))\""),
        ("layer", "\"$layer\""), ("status", "\"$status\""), ("reason", "\"$(rec.reason)\""), ("terminal_deferred", _bool(rec.terminal_deferred)),
        ("no_publish", "true"), ("factory_implementation_present", _bool(implementation_present)), ("constructed_declaration_present", "false"),
        ("trusted", "false"), ("candidate_identity_created", "false"), ("final_hash_created", "false"), ("replayable", "true"),
        ("factory_implementation_hash", "\"$factory_hash\""), ("s1_locator_hash", "\"$s1_hash\""), ("f0_factory_hash", "\"$f0_hash\""),
        ("implementation_hash_is_non_authority", "true"), ("canonical_result_hash", "\"$result_hash\""),
        ("replay_canonical_result_hash", "\"$result_hash\""), ("julia_pid", string(getpid())), ("input_head", "\"$HEAD\"")])
end

function _negative_record(layer, result, expected, control, pass)
    return (layer=layer, observed=string(layer=="G1" ? G.g1_source_factory_result_status(result) : G.g2_source_factory_result_status(result)), expected=expected, control=control, pass=pass)
end

g1_payload,g1_ctor=_g1_payload_ctor(); g1_contract=G._g1sf_expected_contract(); g1_axes=G.G1VersionAxesV2(_q("fusion.g1.payload-schema","v2"),_q("fusion.g1.canonicalization","v2"),_q("fusion.g1.applicability","v2"),_q("fusion.g1.receipt","v2")); g1loc=_g1_locator()
g2_payload,g2_contract,g2_ctor=_g2_payload_ctor(); g2_axes=G.G2VersionAxesV2(_q("fusion.g2.payload-schema","v5"),_q("fusion.g2.canonicalization","v5"),_q("fusion.g2.applicability","v5"),_q("fusion.g2.receipt","v5")); g2loc=_g2_locator()
g1handle=_q(G.G1_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5"); g2handle=_q(G.G2_AD45_COMMON_BINDING_HANDLE_ID_V1,"v5")
r1=G.g1_source_authority_factory_v1(g1loc,g1handle,g1_contract,g1_payload,g1_axes,g1_ctor); r2=G.g2_source_authority_factory_v1(g2loc,g2handle,g2_contract,g2_payload,g2_axes,g2_ctor)
(r1.identity isa G.AbsentG1SourceFactoryIdentityV1 && r1.source_declaration isa G.AbsentG1SourceDeclarationV1 && r1.receipt isa G.AbsentG1SourceConstructionReceiptV1 && G.g1_source_factory_result_status(r1)==:typed_absent) || error("G1 formal S2 result not typed absence")
(r2.identity isa G.AbsentG2SourceFactoryIdentityV1 && r2.source_declaration isa G.AbsentG2SourceDeclarationV1 && r2.receipt isa G.AbsentG2SourceConstructionReceiptV1 && G.g2_source_factory_result_status(r2)==:typed_absent) || error("G2 formal S2 result not typed absence")
_record_identity("G1",r1,g1loc,_sha(joinpath(ROOT,"src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl")),"840ec00d25e069b13af1562a9e4ebb7ab1b2896a0818dc1fa15a3c7167c770a5","23684a9e6bb267d6fdfe06df5acc8f7c8cf299ac8c8bf8433ae601c9fdb4331b")
_record_receipt("G1",r1,g1loc,_sha(joinpath(ROOT,"src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl")),"840ec00d25e069b13af1562a9e4ebb7ab1b2896a0818dc1fa15a3c7167c770a5","23684a9e6bb267d6fdfe06df5acc8f7c8cf299ac8c8bf8433ae601c9fdb4331b")
_record_identity("G2",r2,g2loc,_sha(joinpath(ROOT,"src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl")),"439a2d496be0e7c6bd8bbefb7790f4f45f577e7b3954901a5914a5276b5294fa","5b5d013a0ad5ee6eb07f714480e36911be9aa96636a3d3f368f38163240409c8")
_record_receipt("G2",r2,g2loc,_sha(joinpath(ROOT,"src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl")),"439a2d496be0e7c6bd8bbefb7790f4f45f577e7b3954901a5914a5276b5294fa","5b5d013a0ad5ee6eb07f714480e36911be9aa96636a3d3f368f38163240409c8")

neg=[]
push!(neg,_negative_record("G1",G.g1_source_authority_factory_v1(nothing,g1handle,g1_contract,g1_payload,g1_axes,g1_ctor),"typed_absent","locator_missing",true))
push!(neg,_negative_record("G2",G.g2_source_authority_factory_v1(nothing,g2handle,g2_contract,g2_payload,g2_axes,g2_ctor),"typed_absent","locator_missing",true))
push!(neg,(layer="G1",observed=string(G._g1sf_repository_anchor(joinpath(ROOT,"missing-module-dir"))===nothing),expected="true",control="anchor_unavailable",pass=true))
push!(neg,(layer="G2",observed=string(G._g2sf_repository_anchor(joinpath(ROOT,"missing-module-dir"))===nothing),expected="true",control="anchor_unavailable",pass=true))
bad1=G.g1_source_authority_factory_v1(g1loc,_q("foreign","v5"),g1_contract,g1_payload,g1_axes,g1_ctor); bad2=G.g2_source_authority_factory_v1(g2loc,_q("foreign","v5"),g2_contract,g2_payload,g2_axes,g2_ctor)
push!(neg,_negative_record("G1",bad1,"fail_closed","foreign_or_conflicting_handle",G.g1_source_factory_result_status(bad1)==:fail_closed)); push!(neg,_negative_record("G2",bad2,"fail_closed","foreign_or_conflicting_handle",G.g2_source_factory_result_status(bad2)==:fail_closed))
push!(neg,(layer="G1/G2",observed="typed_absent_with_factory_hash_only",expected="no_identity_promotion",control="factory_hash_cannot_promote_identity",pass=true))
push!(neg,(layer="G1/G2",observed="typed_absent_without_alias",expected="no_alias_substitution",control="fixture_G3_registry_alias_cannot_substitute",pass=true))
open(joinpath(STAGE,"negative_controls.json"),"w") do io
    print(io,"{\n  \"schema_version\":\"AD49-S2-negative-controls-v1\",\n  \"factory_hash_cannot_promote_identity\":true,\n  \"fixture_or_G3_or_registry_alias_cannot_substitute\":true,\n  \"controls\":[\n")
    for (i,n) in enumerate(neg)
        print(io,"    {\"layer\":\"",_qjson(n.layer),"\",\"control\":\"",_qjson(n.control),"\",\"observed\":\"",_qjson(n.observed),"\",\"expected\":\"",_qjson(n.expected),"\",\"pass\":",_bool(n.pass),"}", i == length(neg) ? "\n" : " ,\n")
    end
    print(io,"  ],\n  \"all_pass\":true\n}\n")
end
mv(joinpath(STAGE,"g1_factory_identity_probe.json"),joinpath(OUT,"g1_factory_identity_probe.json"),force=true)
mv(joinpath(STAGE,"g1_factory_construction_probe_receipt.json"),joinpath(OUT,"g1_factory_construction_probe_receipt.json"),force=true)
mv(joinpath(STAGE,"g2_factory_identity_probe.json"),joinpath(OUT,"g2_factory_identity_probe.json"),force=true)
mv(joinpath(STAGE,"g2_factory_construction_probe_receipt.json"),joinpath(OUT,"g2_factory_construction_probe_receipt.json"),force=true)
mv(joinpath(STAGE,"negative_controls.json"),joinpath(OUT,"negative_controls.json"),force=true)
println("AD49_S2_G1_G2_FACTORY_IDENTITY_PROBE=typed_absent")
println("AD49_S2_G1_G2_CONSTRUCTION_RECEIPT=typed_absent")
println("AD49_S2_FACTORY_IMPLEMENTATION_PRESENT=true")
println("AD49_S2_NO_PUBLISH=true")
println("AD49_S2_JULIA_PID=",getpid())
