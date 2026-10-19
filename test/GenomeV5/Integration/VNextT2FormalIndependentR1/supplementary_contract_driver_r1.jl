using Test
using SHA
using JSON3
using FusionConceptAI

_t2_sup_sha256(bytes) = bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes))))

length(ARGS) == 4 || error(
    "expected scenario, output directory, coverage map path, coverage map SHA-256")
const T2_SUP_COVERAGE_MAP_PATH = abspath(ARGS[3])
const T2_SUP_COVERAGE_MAP_SHA256 = lowercase(ARGS[4])
const T2_SUP_COVERAGE_MAP_BYTES = read(T2_SUP_COVERAGE_MAP_PATH)
_t2_sup_sha256(T2_SUP_COVERAGE_MAP_BYTES) == T2_SUP_COVERAGE_MAP_SHA256 ||
    error(:supplementary_coverage_map_sha256_mismatch)
const T2_SUP_COVERAGE_MAP = JSON3.read(String(T2_SUP_COVERAGE_MAP_BYTES))
const T2_SUP_SOURCE_PATH =
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/supplementary_contract_driver_r1.jl"
const T2_SUP_SITE_ROWS = filter(row -> String(row.path) == T2_SUP_SOURCE_PATH,
    T2_SUP_COVERAGE_MAP.successor_assertion_sites)
isempty(T2_SUP_SITE_ROWS) && error(:supplementary_source_site_map_empty)
const T2_SUP_SITE_ID_BY_LINE = Dict{Int,String}()
for row in T2_SUP_SITE_ROWS
    line = Int(row.line)
    haskey(T2_SUP_SITE_ID_BY_LINE, line) &&
        error((:supplementary_source_site_line_duplicate, line))
    T2_SUP_SITE_ID_BY_LINE[line] = String(row.id)
end
const T2_SUP_LAST_SITE_TESTSET = Ref{Any}(nothing)

mutable struct T2SupAssertionSiteTestSet <: Test.AbstractTestSet
    inner::Test.DefaultTestSet
    hits::Dict{String,Int}
    unmapped::Vector{String}
end

function T2SupAssertionSiteTestSet(desc; kwargs...)
    inner = Test.DefaultTestSet(desc; kwargs...)
    hits = Dict{String,Int}(String(row.id) => 0 for row in T2_SUP_SITE_ROWS)
    result = T2SupAssertionSiteTestSet(inner, hits, String[])
    T2_SUP_LAST_SITE_TESTSET[] = result
    result
end

function _t2_sup_is_target_source(file)
    normalized = lowercase(replace(string(file), '\\' => '/'))
    basename = split(normalized, '/') |> last
    basename in ("supplementary_contract_driver_r1.jl",
                 "supplementary_contract_driver_r1")
end

function Test.record(testset::T2SupAssertionSiteTestSet,
                     result::Test.Result)
    source = hasfield(typeof(result), :source) ? getfield(result, :source) : nothing
    if source isa LineNumberNode && _t2_sup_is_target_source(source.file)
        site_id = get(T2_SUP_SITE_ID_BY_LINE, source.line, nothing)
        if site_id === nothing
            push!(testset.unmapped, "$(source.file):$(source.line)")
        else
            testset.hits[site_id] += 1
        end
    end
    Test.record(testset.inner, result)
end

function Test.record(testset::T2SupAssertionSiteTestSet,
                     child::Test.AbstractTestSet)
    Test.record(testset.inner, child)
end

function Test.finish(testset::T2SupAssertionSiteTestSet)
    Test.finish(testset.inner)
    isempty(testset.unmapped) || error((:unmapped_supplementary_assertion_sources,
        testset.unmapped))
    testset
end

function _t2_sup_assertion_site_hit_receipt(phase)
    testset = T2_SUP_LAST_SITE_TESTSET[]
    testset isa T2SupAssertionSiteTestSet ||
        error(:supplementary_assertion_site_testset_missing)
    (schema="vnext-t2-source-site-hit-receipt-r1",
     phase=String(phase), source_path=T2_SUP_SOURCE_PATH,
     source_sha256=_t2_sup_sha256(read(@__FILE__)),
     coverage_map_sha256=T2_SUP_COVERAGE_MAP_SHA256,
     hit_count=sum(values(testset.hits)),
     hit_counts=Dict(sort(collect(testset.hits); by=first)),
     unmapped_sources=Tuple(testset.unmapped))
end

const T2_SUP_VERSION = "independent-supplementary-contract-r2"

registry_before = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
include(joinpath(@__DIR__, "..", "VNextT2IdentityReceiptV2",
    "fixture_helpers.jl"))
FusionConceptAI.load_vnext_t2_components_v2!()
registry_after = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
registry_before == registry_after || error(:supplementary_fixture_registry_drift)

function main(args)
length(args) == 4 || error("expected scenario, output directory, coverage map path, and SHA-256")
mode = Symbol(args[1])
mode in (:edited_operation, :child_coupling) ||
    error((:unknown_supplementary_mode, mode))
output = abspath(args[2])
mkpath(output)
observations_path = joinpath(output, "observations.jsonl")
summary_path = joinpath(output, "summary.json")
ispath(observations_path) && error(:supplementary_observations_exist)
ispath(summary_path) && error(:supplementary_summary_exists)

stream = open(observations_path, "w")
test_error = nothing
observed = String[]
try
    phase_name = mode === :edited_operation ?
        "supplementary_edited_operation" : "supplementary_child_coupling"
    @testset T2SupAssertionSiteTestSet "VNext T2 supplementary synthetic contract" begin
        # Each process constructs exactly one natural source-backed scenario.
        # These preserve old synthetic-local obligations but cannot establish
        # a formal T1 authority gate.
        if mode === :edited_operation
            chain = t2_chain(edited_realization=true)
            result = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(
                chain.build)
            row = (schema="vnext-t2-independent-supplementary-observation-r1",
                case_id="SUP_EDITED_OPERATION_DEFERRAL",
                value_type=string(typeof(result)), status=result.status,
                resolution=result.resolution, reason=result.reason,
                errors=result.errors, gaps=result.gaps,
                committed=result.committed,
                evidence_kind=chain.build.input.formal_gate.evidence_kind,
                formal_t1_accepted=
                    chain.build.input.formal_gate.formal_t1_accepted,
                attempted_counts=FusionConceptAI.semantic_view(
                    result.attempted_trace.counts),
                committed_counts=FusionConceptAI.semantic_view(
                    result.committed_counts),
                package_hash_before=chain.package.package_hash,
                package_hash_after=chain.build.input.package.package_hash,
                prior_ledger_fingerprint_before=nothing,
                prior_ledger_fingerprint_after=result.ledger === nothing ?
                    nothing : result.ledger.ledger_hash,
                formal_qualification=false)
            line = FusionConceptAI.canonical_json(row)
            println(stream, line)
            flush(stream)
            println("VNEXT_T2_SUPPLEMENTARY_ACTUAL=" * line)
            flush(stdout)

            @test chain.build.status === :prepared_not_executed
            @test chain.build.resolution === :terminal_deferred
            @test chain.build.input isa FusionConceptAI.VNextT2UP2BoundInputV2
            validation = FusionConceptAI.vnext_t2_up2_validate_input_v2(
                chain.build.input)
            @test validation.status === :valid
            @test validation.reason === :none
            @test chain.build.input.formal_gate.evidence_kind === :synthetic_local
            @test chain.formal_gate_verified === false
            @test chain.build.input.formal_gate.formal_t1_accepted
            @test chain.build.input.formal_gate.
                formal_t1_software_acceptance_receipt_hash ==
                chain.synthetic_software_acceptance_receipt_hash
            @test chain.build.input.formal_gate.
                candidate_t1_admission_receipt_hash ==
                chain.synthetic_candidate_admission_receipt_hash
            @test result.status === :complete_contract_receipts
            @test result.resolution === :terminal_deferred
            @test result.reason === :none
            @test result.committed
            @test result.ledger isa FusionConceptAI.VNextT2ReceiptLedgerV2
            @test result.ledger.counts ==
                FusionConceptAI.VNextT2InvocationCountsV2(
                    1, 1, 1, 1, 1, 0, 0, 0)
            @test result.attempted_trace.counts == result.ledger.counts
            @test Tuple(x.consumer_id for x in
                result.attempted_trace.events) ==
                FusionConceptAI.VNEXT_T2_CONSUMER_ORDER_V2
            @test :formal_gate_verified_false_synthetic_local in
                result.ledger.gaps
            @test result.ledger.accepted === false
            @test result.ledger.claim_ceiling === :contract_only
            @test :realization_full_operation_replay_evidence_not_carried in
                chain.source.witness.gaps
            @test result.ledger.receipts[4].status === :typed_absent
            @test result.ledger.receipts[4].resolution === :terminal_deferred
            @test result.ledger.receipts[4].reason ===
                :e2_operation_replay_evidence_missing
            @test :full_child_operation_replay_evidence in
                result.ledger.receipts[4].unsupported_capabilities
            @test :realization_full_operation_replay_evidence_not_carried in
                result.ledger.gaps
            @test chain.package.package_hash ==
                chain.build.input.package.package_hash
            @test FusionConceptAI.vnext_t1_package_v2_validate(
                chain.build.input.package) === nothing
            push!(observed, "SUP_EDITED_OPERATION_DEFERRAL")
            push!(observed, "SUP_SYNTHETIC_GATE_BOUNDARY")
        else
            contradiction = t2_chain(coherent_g3_child=false)
            result = FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(
                contradiction.build)
            row = (schema="vnext-t2-independent-supplementary-observation-r1",
                case_id="SUP_CHILD_COUPLING_CONTRADICTION",
                value_type=string(typeof(result)), status=result.status,
                resolution=result.resolution, reason=result.reason,
                errors=result.errors, gaps=result.gaps,
                committed=result.committed,
                source_coupling_status=
                    contradiction.source.witness.coupling.status,
                evidence_kind=
                    contradiction.build.input.formal_gate.evidence_kind,
                formal_t1_accepted=
                    contradiction.build.input.formal_gate.formal_t1_accepted,
                attempted_counts=FusionConceptAI.semantic_view(
                    result.attempted_trace.counts),
                committed_counts=FusionConceptAI.semantic_view(
                    result.committed_counts),
                package_hash_before=contradiction.package.package_hash,
                package_hash_after=
                    contradiction.build.input.package.package_hash,
                prior_ledger_fingerprint_before=nothing,
                prior_ledger_fingerprint_after=result.ledger === nothing ?
                    nothing : result.ledger.ledger_hash,
                formal_qualification=false)
            line = FusionConceptAI.canonical_json(row)
            println(stream, line)
            flush(stream)
            println("VNEXT_T2_SUPPLEMENTARY_ACTUAL=" * line)
            flush(stdout)

            @test contradiction.source.witness.coupling.status === :fail_closed
            @test result.status === :fail_closed
            @test result.resolution === :none
            @test result.reason === :e2_declared_source_child_contradiction
            @test !result.committed
            @test result.ledger === nothing
            @test result.committed_counts ==
                FusionConceptAI.VNextT2InvocationCountsV2()
            @test result.attempted_trace.counts ==
                FusionConceptAI.VNextT2InvocationCountsV2(
                    1, 1, 1, 1, 0, 0, 0, 0)
            @test Tuple(x.consumer_id for x in
                result.attempted_trace.events) == (:E0, :GI1A, :E1, :E2)
            @test contradiction.package.package_hash ==
                contradiction.build.input.package.package_hash
            push!(observed, "SUP_CHILD_COUPLING_CONTRADICTION")
            push!(observed, "SUP_SYNTHETIC_GATE_BOUNDARY")
        end
    end
catch error
    test_error = error
finally
    close(stream)
    phase_name = mode === :edited_operation ?
        "supplementary_edited_operation" : "supplementary_child_coupling"
    site_hits = _t2_sup_assertion_site_hit_receipt(phase_name)
    summary = (schema="vnext-t2-independent-supplementary-summary-r2",
        driver_version=T2_SUP_VERSION, mode=mode,
        status=test_error === nothing ? :pass : :fail,
        observed_case_ids=Tuple(observed),
        assertion_site_hit_receipt_schema=site_hits.schema,
        assertion_site_hit_phase=site_hits.phase,
        assertion_site_hit_source_path=site_hits.source_path,
        assertion_site_hit_source_sha256=site_hits.source_sha256,
        assertion_site_hit_coverage_map_sha256=site_hits.coverage_map_sha256,
        assertion_site_hit_count_observed=site_hits.hit_count,
        assertion_site_hit_counts=site_hits.hit_counts,
        unmapped_assertion_sources=site_hits.unmapped_sources,
        observation_file_sha256=_t2_sup_sha256(read(observations_path)),
        evidence_kind=:synthetic_local, formal_qualification=false,
        formal_t2_accepted=false, physical_acceptance=false,
        scientific_acceptance=false, actual_model_attestation="unavailable",
        error_type=test_error === nothing ? nothing : string(typeof(test_error)),
        error_text=test_error === nothing ? nothing : sprint(showerror,
            test_error))
    open(summary_path, "w") do io
        write(io, FusionConceptAI.canonical_json(summary) * "\n")
        flush(io)
    end
    println("VNEXT_T2_SUPPLEMENTARY_SUMMARY=" *
        FusionConceptAI.canonical_json(summary))
    flush(stdout)
end
test_error === nothing || throw(test_error)
println("VNEXT_T2_SUPPLEMENTARY_CONTRACT=PASS")
flush(stdout)
end

main(ARGS)
