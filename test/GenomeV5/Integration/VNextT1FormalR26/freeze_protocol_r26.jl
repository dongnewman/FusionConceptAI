using SHA, JSON3, Dates

const ROOT = realpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const OUTPUT = joinpath(@__DIR__, "protocol_r26_v9.json")
const ACTIVE_JULIA_HARNESSES = (
    "test/GenomeV5/Integration/VNextT1FormalR26/vnext_t1_v1_formal_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/v1_semantic_contract_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/path_guard_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/v1_shard_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/v2_formal_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/binding_missing_wire_formal_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/freeze_protocol_r26.jl",
)

r26_freeze_sha(bytes) = uppercase(bytes2hex(sha256(bytes)))
function r26_freeze_reject_parse_nodes(x, rel)
    x isa Expr || return
    x.head in (:error, :incomplete) && error("active harness parse error: $rel: $x")
    foreach(child -> r26_freeze_reject_parse_nodes(child, rel), x.args)
end
function r26_freeze_parse_harness(rel)
    bytes = read(joinpath(ROOT, rel))
    ast = Meta.parseall(String(copy(bytes)))
    r26_freeze_reject_parse_nodes(ast, rel)
    (path=rel, bytes=length(bytes), sha256=r26_freeze_sha(bytes), parsed=true)
end

# This gate runs before any repository include or product import. Meta.parseall
# can return Expr(:error/:incomplete), so every returned node is checked.
const HARNESS_PARSE_GATE = [r26_freeze_parse_harness(rel)
    for rel in ACTIVE_JULIA_HARNESSES]

include(joinpath(@__DIR__, "path_guard_r26.jl"))

const BASELINE_REL = "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl"
const SUCCESSOR_REL = "test/GenomeV5/Integration/VNextT1FormalR26/vnext_t1_v1_formal_r26.jl"
const MAP_REL = "docs/implementation/UP1-04A-VNEXT-T1/astra_semantic_review_20260922_r1/baseline_target_obligation_map.json"
const V2_REL = "test/GenomeV5/Integration/VNextT1V2/vnext_t1_v2_same_chain_tests.jl"
const V1_CARRIER_REFERENCE_REL =
    "docs/implementation/UP1-04A-VNEXT-T1/independent_carrier_cold_path_r1/manifest.json"
const V2_CARRIER_RECEIPT_REL =
    "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r11_wire_bound_package/r11b_replay_receipt.md"
const V2_CARRIER_ARTIFACT_REL =
    "docs/implementation/UP1-04A-VNEXT-T1/agent_local_r11_wire_bound_package/candidate_state_package_v5_next_v2_r11.serialized"
const DEPENDENCIES = (
    "Project.toml", "Manifest.toml",
    BASELINE_REL, SUCCESSOR_REL, MAP_REL, V2_REL,
    "test/GenomeV5/Integration/VNextT1FormalR26/v1_semantic_contract_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/path_guard_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/v1_shard_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/v2_formal_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/binding_missing_wire_formal_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/run_recorded_r26.py",
    "test/GenomeV5/Integration/VNextT1FormalR26/freeze_protocol_r26.jl",
    "test/GenomeV5/Integration/VNextT1FormalR26/formal_controller_r26.py",
    "test/GenomeV5/Integration/VNextT1FormalR26/merge_r26.py",
    "test/GenomeV5/Integration/VNextT1FormalR26/static_qa_r26.py",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "test/GenomeV5/Integration/vnext_t1_projection_diagnostic_v1.jl",
    "test/GenomeV5/Integration/VNextT1V1R18/formal_contract_v2_checks.jl",
    "test/GenomeV5/Integration/vnext_g3_binding_authority_bridge_local_v1_tests.jl",
    V1_CARRIER_REFERENCE_REL, V2_CARRIER_RECEIPT_REL,
    V2_CARRIER_ARTIFACT_REL,
    "src/Contracts/CandidateStatePackageV5Next.jl",
    "src/Contracts/CandidateStatePackageV5NextV2.jl",
    "src/Contracts/VNextT1CanonicalBytesV2.jl",
    "src/Contracts/VNextT1CandidateBindingV2.jl",
    "src/Contracts/VNextT1PackageBindingAdapterV2.jl",
    "src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl",
    "src/GenomeV5/Integration/VNextGenomeV5Integration.jl",
    "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl",
    "src/GenomeV5/Integration/VNextG3BindingAuthorityBridgeLocalV1.jl",
    "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV2.jl",
    "src/FusionConceptAI.jl",
    "src/IR/PhysicalTypes.jl",
    "src/IR/OperatorRegistry.jl",
    "src/Canonical/ClosedCanonicalByteWriter.jl",
    "src/Canonical/CanonicalJSON.jl",
    "src/Canonical/Hashes.jl",
    "src/Contracts/StatusDimensions.jl",
    "src/Contracts/GenomeContractRegistry.jl",
    "src/GenomeV5/Integration/GenomeV5Integration.jl",
    "src/GenomeV5/G1/GrammarProfileV2.jl",
    "src/GenomeV5/G1/EquationPlanV2.jl",
    "src/GenomeV5/G1/MechanismGenomePayloadV2.jl",
    "src/GenomeV5/G1/MechanismGenomeV5.jl",
    "src/GenomeV5/G2/SpatialGrammarProfileV2.jl",
    "src/GenomeV5/G2/RegionInterfaceContractV2.jl",
    "src/GenomeV5/G2/FieldSpacePlanV2.jl",
    "src/GenomeV5/G2/FieldGeometryGenomeV5.jl",
    "src/GenomeV5/G3/RealizationGenomeV5.jl",
    "src/GenomeV5/G3/ControlGenomeV5.jl",
    "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
)

sha(bytes) = r26_freeze_sha(bytes)
digest(rel) = begin bytes=read(r26_guard_existing_repo_file(ROOT, rel;
        label="freeze dependency"));
    (path=rel, bytes=length(bytes), sha256=sha(bytes)) end
expr_hash(x) = sha(codeunits(sprint(show, x)))
function semantic_ast(x)
    x isa LineNumberNode && return nothing
    x isa Expr || return x
    Expr(x.head, map(semantic_ast, x.args)...)
end
semantic_expr_hash(x) = sha(codeunits(sprint(show, semantic_ast(x))))
test_macro(x) = x isa Expr && x.head === :macrocall &&
    string(x.args[1]) in ("@test", "@test_throws")
testset_macro(x) = x isa Expr && x.head === :macrocall &&
    string(x.args[1]) == "@testset"

function parse_checked(rel)
    ast = Meta.parseall(read(joinpath(ROOT, rel), String))
    function check(x)
        x isa Expr || return
        x.head in (:error, :incomplete) && error("parse error: $rel")
        foreach(check, x.args)
    end
    check(ast); ast
end

function collect_tests(x, rows=Any[])
    if x isa Expr
        if test_macro(x)
            line = x.args[2] isa LineNumberNode ? x.args[2].line : 0
            push!(rows, (line=line, macro_name=string(x.args[1]),
                expression_hash=expr_hash(x),
                semantic_expression_hash=semantic_expr_hash(x)))
        end
        foreach(arg -> collect_tests(arg, rows), x.args)
    end
    rows
end

function collect_top_testsets(ast)
    rows = Any[]
    top = ast isa Expr && ast.head === :toplevel ? ast.args : Any[ast]
    for expression in top
        testset_macro(expression) || continue
        title = only(filter(x -> x isa String, expression.args[3:end]))
        push!(rows, (title=title, ast_sha256=expr_hash(expression)))
    end
    rows
end

function target_id(index)
    index <= 63 ? "r18v2-" * lpad(string(index), 3, '0') :
        "r26-extra-" * lpad(string(index - 63), 3, '0')
end

const CHANGED = Set(("r18v2-013", "r18v2-043", "r18v2-044", "r18v2-045",
    "r18v2-046", "r18v2-047", "r18v2-048", "r18v2-049"))
const MAPPING_KIND_OVERRIDES = Dict(
    "r18v2-043" => "strengthen_label_isolation_canonical_invariance",
)
const EXTRA_KINDS = (
    "add_forward_mismatch_exact_metadata",
    "add_reverse_mismatch_exact_metadata",
    "add_coherent_true_absence_exact_metadata",
    "add_true_absence_carrier_hash_join",
    "add_v1_rejection_all_three_rechecks",
    "add_fixture_immutability",
    "add_malformed_absence_rejection",
)
const SHARDS = (
    (name="carrier", indices=collect(1:6), max_wall_seconds=220.0),
    (name="contract", indices=collect(7:70), max_wall_seconds=220.0),
)

ispath(OUTPUT) && error("protocol already exists")
length(DEPENDENCIES) == length(unique(DEPENDENCIES)) || error("duplicate dependency")
all(id -> id in CHANGED, keys(MAPPING_KIND_OVERRIDES)) ||
    error("mapping override is not declared changed")
path_guard = r26_path_guard_selftest(ROOT, joinpath(ROOT,
    "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922"))
before = [digest(rel) for rel in DEPENDENCIES]
baseline_digest = digest(BASELINE_REL)
baseline_digest.bytes == 13248 || error("baseline byte drift")
baseline_digest.sha256 == "A1D590ED3BF7A125C3A90A36F509ED24D4A653BD74F7371FDBF36ABA3CFACE72" ||
    error("baseline source drift")
map_digest = digest(MAP_REL)
map_digest.bytes == 18177 || error("map byte drift")
map_digest.sha256 == "1DD29FC1022381CE14C2B90BB74FD06D358A6F1F69879353B7A0FB185843C723" ||
    error("map drift")
successor_digest = digest(SUCCESSOR_REL)
v2_source_digest = digest(V2_REL)
v1_carrier_reference = digest(V1_CARRIER_REFERENCE_REL)
v2_carrier_receipt = digest(V2_CARRIER_RECEIPT_REL)
v2_carrier_artifact = digest(V2_CARRIER_ARTIFACT_REL)
v1_carrier_reference.bytes == 3517 &&
    v1_carrier_reference.sha256 ==
        "0E50AF582960067CFC29519AAE6ED3B0C53A51CA9CD5E072DD88C4755ACF46E3" ||
    error("V1 carrier reference drift")
v2_carrier_receipt.bytes == 1534 &&
    v2_carrier_receipt.sha256 ==
        "10C0E46D05D018C9C9BE384F88AE6374C8F0BBAC4B3B0019A9E8AEF0FDF9B487" ||
    error("V2 carrier receipt drift")
v2_carrier_artifact.bytes == 9394561 &&
    v2_carrier_artifact.sha256 ==
        "E7598CAB8D2AFBAA83E152B47E8ACE713295BB77A7EB3BD0FB928871A31492E3" ||
    error("V2 carrier artifact drift")

baseline = collect_tests(parse_checked(BASELINE_REL))
successor = collect_tests(parse_checked(SUCCESSOR_REL))
length(baseline) == 63 || error("baseline target count drift")
length(successor) == 70 || error("successor target count drift")
frozen_map = JSON3.read(read(joinpath(ROOT, MAP_REL), String))
length(frozen_map.rows) == 63 || error("map count drift")

function shard_for(index)
    only(row.name for row in SHARDS if index in row.indices)
end

targets = Any[]
for index in eachindex(successor)
    id = target_id(index)
    if index <= 63
        mapped = frozen_map.rows[index]
        String(mapped.baseline_target) == id || error("map ID drift: $id")
        baseline[index].line == Int(mapped.source_line) || error("map line drift: $id")
        baseline[index].expression_hash == String(mapped.source_ast_sha256) ||
            error("map AST drift: $id")
        baseline_kind = String(mapped.mapping_kind)
        kind = get(MAPPING_KIND_OVERRIDES, id, baseline_kind)
        !(id in CHANGED) && successor[index].semantic_expression_hash !=
            baseline[index].semantic_expression_hash &&
            error("unchanged target AST drift: $id")
        baseline_line = baseline[index].line
        baseline_hash = baseline[index].expression_hash
    else
        kind = EXTRA_KINDS[index - 63]
        baseline_kind = nothing
        baseline_line = nothing
        baseline_hash = nothing
    end
    push!(targets, (id=id, baseline_mapping_kind=baseline_kind,
        mapping_kind=kind, shard=shard_for(index),
        baseline_line=baseline_line, baseline_ast_sha256=baseline_hash,
        successor_line=successor[index].line,
        successor_ast_sha256=successor[index].expression_hash,
        successor_semantic_ast_sha256=successor[index].semantic_expression_hash,
        macro_name=successor[index].macro_name))
end

v2_testsets = collect_top_testsets(parse_checked(V2_REL))
length(v2_testsets) == 7 || error("V2 top-level testset count drift")
shards = [(name=row.name,
    target_ids=[target_id(i) for i in row.indices],
    max_wall_seconds=row.max_wall_seconds) for row in SHARDS]
all_ids = reduce(vcat, [row.target_ids for row in shards])
length(all_ids) == 70 && length(unique(all_ids)) == 70 ||
    error("shard ownership is not an exact 70-target partition")

after = [digest(rel) for rel in DEPENDENCIES]
before == after || error("dependency changed during freeze")
head = readchomp(Cmd(["git", "-C", ROOT, "rev-parse", "HEAD"]))
protocol = (schema="vnext_t1_independent_formal_r26_protocol_v9",
    created_utc=string(Dates.now(Dates.UTC)), base_head=head,
    formal_T1=false, scientific_acceptance=false,
    actual_model_attestation="unavailable", path_guard_selftest=path_guard,
    harness_parse_gate=HARNESS_PARSE_GATE,
    resources=(carrier_seconds=10.0, carrier_expected_bytes=8269571,
        package_integrator_seconds=30.0,
        reload_adapter_seconds=30.0, fresh_process_wall_seconds=240.0,
        process_tree_rss_bytes=2^31),
    v1=(baseline=merge(baseline_digest, (map_path=MAP_REL,
            map_bytes=map_digest.bytes, map_sha256=map_digest.sha256)),
        successor=successor_digest,
        source_carrier_fixture=(fixture="first_actual_v1_t1_fixture_transport",
            fixture_source=SUCCESSOR_REL,
            fixture_source_sha256=successor_digest.sha256,
            carrier_source="src/Contracts/VNextT1CanonicalBytesV2.jl",
            operation="canonical_json_to_vector_then_first_v2_owned_carrier_copy_and_sha",
            expected_bytes=8269571,
            raw_sha256="1abdd43b057c6f6ba7dc020cf3c4a9239823cc2081f00583a405f7d0d91645f8",
            limit_seconds=10.0,
            reference_manifest=v1_carrier_reference),
        baseline_target_count=63,
        successor_target_count=70, changed_target_ids=sort!(collect(CHANGED)),
        targets=targets, shards=shards),
    v2=(source=v2_source_digest,
        carrier_fixture=(fixture="original_v2_same_chain_fixture",
            fixture_source=V2_REL,
            fixture_source_sha256=v2_source_digest.sha256,
            expected_bytes=8267526,
            wire_sha256="aed5b8f16b9a27c76fe5b098e1e52015d7b4090de1563915a02dcff413885e1a",
            reference_receipt=v2_carrier_receipt,
            reference_artifact=v2_carrier_artifact),
        legacy_testset_count=7, legacy_testsets=v2_testsets),
    binding=(case_count=16, missing_expected_wire_cases=8,
        present_expected_wire_cases=8),
    dependencies=before)
open(OUTPUT, "w") do io
    JSON3.write(io, protocol); flush(io)
end
println("R26_PROTOCOL_FREEZE=PASS path=", relpath(OUTPUT, ROOT),
    " targets=70 baseline=63 extras=7 v2_testsets=7 dependencies=", length(before),
    " sha256=", digest(relpath(OUTPUT, ROOT)).sha256)
flush(stdout)
