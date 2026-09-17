using Test
using JSON3
using Serialization

const G = FusionConceptAI
const _UP2_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "fixtures.json"), String))

function _up2_fixture_specs()
    Tuple(G.UP2MutationSpecV1(String(row.id), Symbol(String(row.class_id)),
        String(row.field_path), String(row.source_locator), Symbol(String(row.source_type)),
        Symbol(String(row.mutation_kind)), Symbol(String(row.expected_error)),
        getfield(G, Symbol(String(row.expected_resolution))), Int(row.expected_provider_calls),
        String(row.detail)) for row in _UP2_FIXTURE.mutations)
end

function _up2_value(spec)
    spec.id in ("N01-01", "N01-02", "N01-03") && return G.UP2IntegerValueV1(0)
    spec.id == "N01-04" && return G.UP2IntegerValueV1(3)
    spec.id == "N01-05" && return G.UP2SymbolValueV1(:scalar)
    spec.id == "N02-03" && return G.UP2TextValueV1("1")
    spec.id == "N05-01" && return G.UP2TextValueV1("flux-left")
    spec.id == "N05-02" && return G.UP2TextValueV1("flux-right")
    spec.id == "N05-03" && return G.UP2IntegerValueV1(1)
    spec.id == "N05-04" && return G.UP2IntegerValueV1(-1)
    spec.id == "N05-05" && return G.UP2UnitValueV1(G.UnitSignature())
    spec.source_type === :integer && return G.UP2IntegerValueV1(0)
    spec.source_type === :symbol && return G.UP2SymbolValueV1(:valid)
    spec.source_type === :text && return G.UP2TextValueV1("1")
    spec.source_type === :rational && return G.UP2RationalValueV1(0 // 1)
    spec.source_type === :unit && return G.UP2UnitValueV1(G.UnitSignature())
    spec.source_type === :tuple && return G.UP2TupleValueV1((:valid,), :symbol)
    spec.source_type === :hash && return G.UP2HashValueV1(G.Digest256(repeat("a", 64)))
    spec.source_type === :ref && return G.UP2RefValueV1(G.QualifiedRefV1("fusionconceptai://candidate/up2", "v5"))
    error("unhandled source type $(spec.source_type)")
end

function _up2_reference_input()
    refs = (
        G.GenomeContractRef("fusionconceptai://GenomeV5/G1/candidate-up2", "v5",
            G.Digest256(repeat("1", 64)), G.Digest256(repeat("2", 64)), "g1-up2-profile"),
        G.GenomeContractRef("fusionconceptai://GenomeV5/G2/candidate-up2", "v5",
            G.Digest256(repeat("3", 64)), G.Digest256(repeat("4", 64)), "g2-up2-profile"),
        G.GenomeContractRef("fusionconceptai://GenomeV5/G3/candidate-up2", "v5",
            G.Digest256(repeat("5", 64)), G.Digest256(repeat("6", 64)), "g3-up2-profile"))
    fields = Tuple(G.UP2SemanticFieldV1(spec.id, spec.field_path, spec.source_locator,
        spec.source_type, _up2_value(spec)) for spec in _up2_fixture_specs())
    state = G.UP2PrecompilerStateV1(fields,
        G.UP2FluxPairV1("pair-1", "flux-left", "flux-right", 1, -1, G.UnitSignature()))
    mission = G.UP2MissionBoundsV1("up2_contract_smoke", "scalar_field", "1", "m",
        (0 // 1, 0 // 1, 0 // 1), (1 // 1, 1 // 1, 1 // 1), :static)
    G.UP2PrecompilerInputV1(G.QualifiedRefV1("fusionconceptai://candidate/up2-reference", "v5"),
        refs[1], refs[2], refs[3], G.Digest256(repeat("a", 64)), G.Digest256(repeat("b", 64)),
        G.Digest256(repeat("c", 64)), G.Digest256(repeat("d", 64)), mission, state,
        G.Digest256(repeat("e", 64)), :a_limited, G.terminal_deferred, G.none)
end

function _up2_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _up2_actual_g1(base, candidate)
    old = base.payload.contract_ref
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = G.G1GenomeContractRefV2(uri, old.version, old.schema_hash, old.canonicalization_hash,
        old.compatibility_profile, old.version_axes, candidate.id;
        grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = G.MechanismGenomePayloadV2(ref, base.payload.states,
        base.payload.equation_plan, base.payload.grammar_profile)
    G.MechanismGenomeV5(G.g1_materialize_contract_ref(ref, base.payload.grammar_profile), payload, base.version_axes)
end

function _up2_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _up2_actual_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref,
        candidate, base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref,
        candidate, base.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref,
        candidate, base.binding.contract_binding.version_axes)
    bundle_binding = G.G3ContractBindingV2(base.contract_binding.contract_ref,
        candidate, base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains;
        provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(ch.feedback_id, ch.target_layer,
        ch.target_layer === :G1 ? g1_ref : g2_ref, ch.channel, ch.unit, ch.kind,
        ch.source_id) for ch in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle_binding, realization, control, binding)
end

function _up2_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/candidate-1", "v5")
    g1 = _up2_actual_g1(_up2_child_fixture("G1"), candidate)
    g2 = _up2_actual_g2(_up2_child_fixture("G2"), candidate)
    g3base = _up2_child_fixture("G3")
    g3 = _up2_actual_g3(g3base, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

@testset "UP2-00 fixture is schema-bound" begin
    specs = _up2_fixture_specs()
    @test _UP2_FIXTURE.fixture_id == "UP2-00-N01-N10-001"
    @test _UP2_FIXTURE.schema_id == "GenomeV5/UP2/TypedPrecompilerContractV1"
    @test String(_UP2_FIXTURE.schema_version) == "v2"
    @test Bool(_UP2_FIXTURE.schema_validation_only)
    @test Int(_UP2_FIXTURE.mutation_count) == 50
    @test length(specs) == 50
    @test Tuple(G.semantic_view.(specs)) == Tuple(G.semantic_view.(G.up2_expected_mutations()))
end

@testset "UP2-00 real N01 N02 slice and N05 deferred" begin
    input = _up2_reference_input()
    @test G.up2_validate_input(input)
    @test G.up2_schema_hash() isa G.Digest256
    real_specs = filter(x -> x.class_id in (:N01, :N02), _up2_fixture_specs())
    @test length(real_specs) == 10
    for spec in real_specs
        counter = G.UP2InvocationCounterV1()
        result = G.up2_validate_mutation(input, spec; counter=counter)
        expected = :invalid_type
        @test result.error_code == expected
        @test result.error_path == spec.field_path
        @test result.status == :fail_closed
        @test result.mutated_input_hash != input.input_hash
        @test result.compile_calls == 0
        @test result.provider_calls == 0
        @test result.solver_calls == 0
        @test !result.evidence_reused
    end
end

@testset "UP2-00 A projection entrance is typed and package-bound" begin
    input = _up2_reference_input()
    mission = input.mission_bounds
    projection = G.UP2AProjectionV1(input.candidate_ref, input.package_hash,
        input.state.fields, input.state.flux_pair)
    @test projection.projection_hash isa G.Digest256
    @test G.up2_flux_pair_valid(projection.flux_pair)
    @test_throws MethodError G.up2_input_from_a(input, mission, projection, input.source_manifest_hash)
end

@testset "UP2-00 actual A package projection slice" begin
    package = _up2_actual_package()
    @test package isa G.CandidateStatePackageV5
    projection = G.up2_projection_from_a(package)
    mission = G.UP2MissionBoundsV1("actual_a_package", "scalar_field", "1", "m",
        (0 // 1, 0 // 1, 0 // 1), (1 // 1, 1 // 1, 1 // 1), :static)
    source_manifest_hash = G.digest256_text(read(joinpath(@__DIR__, "..", "UP1-04", "fixtures.json"), String))
    input = G.up2_input_from_a(package, mission, source_manifest_hash)
    @test G.up2_validate_input(input)
    for spec in filter(x -> x.class_id in (:N01, :N02), _up2_fixture_specs())
        result = G.up2_validate_mutation(input, spec)
        @test result.status == :fail_closed
        @test result.error_code == :invalid_type
        @test result.error_path == spec.field_path
        @test result.mutated_input_hash != result.input_hash
        @test result.compile_calls == 0
        @test result.provider_calls == 0
        @test result.solver_calls == 0
    end
    for spec in filter(x -> x.class_id === :N05, _up2_fixture_specs())
        @test_throws ArgumentError G.up2_validate_mutation(input, spec)
    end
    forged_fields = Tuple(i == 1 ? G.UP2SemanticFieldV1(
        projection.fields[i].id, projection.fields[i].field_path,
        projection.fields[i].source_locator, projection.fields[i].source_type,
        G.UP2IntegerValueV1(-1)) : projection.fields[i] for i in eachindex(projection.fields))
    forged = G.UP2AProjectionV1(package.candidate_ref, package.candidate_hash,
        forged_fields, projection.flux_pair)
    @test_throws ArgumentError G.up2_input_from_a(package, mission, forged,
        source_manifest_hash)
end

@testset "UP2-00 pending classes do not self-certify" begin
    input = _up2_reference_input()
    pending = filter(x -> !(x.class_id in (:N01, :N02)), _up2_fixture_specs())
    @test length(pending) == 40
    for spec in pending
        @test_throws ArgumentError G.up2_validate_mutation(input, spec)
    end
end

@testset "UP2-00 admission boundaries" begin
    input = _up2_reference_input()
    @test_throws ArgumentError G.UP2PrecompilerInputV1(input.candidate_ref, input.g1_ref,
        G.GenomeContractRef("urn:fusion:g2:old", "v5", input.g2_ref.schema_hash,
            input.g2_ref.canonicalization_hash, input.g2_ref.compatibility_profile), input.g3_ref,
        input.g1_hash, input.g2_hash, input.g3_hash, input.package_hash, input.mission_bounds,
        input.state, input.source_manifest_hash, :a_limited, G.terminal_deferred, G.none)
    @test_throws ArgumentError G.UP2PrecompilerInputV1(input.candidate_ref, input.g1_ref,
        input.g2_ref, input.g3_ref, input.g1_hash, input.g2_hash, input.g3_hash,
        input.package_hash, input.mission_bounds, input.state, input.source_manifest_hash,
        :unreviewed, G.terminal_deferred, G.none)
    counter = G.UP2InvocationCounterV1()
    @test_throws ArgumentError G.up2_provider!(counter, :forbidden)
    @test G.up2_provider_calls(counter) == 0
end
