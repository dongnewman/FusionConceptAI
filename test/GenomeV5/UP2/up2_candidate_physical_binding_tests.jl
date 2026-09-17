using Test
using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _E0_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "up2_candidate_physical_binding_fixtures.json"), String))

function _e0_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _e0_g1(base, candidate)
    old = base.payload.contract_ref
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/")
    ref = G.G1GenomeContractRefV2(uri, old.version, old.schema_hash,
        old.canonicalization_hash, old.compatibility_profile, old.version_axes,
        candidate.id; grammar_profile_hash=old.grammar_profile_hash,
        applicability_profile_hash=old.applicability_profile_hash)
    payload = G.MechanismGenomePayloadV2(ref, base.payload.states,
        base.payload.equation_plan, base.payload.grammar_profile)
    G.MechanismGenomeV5(G.g1_materialize_contract_ref(ref, base.payload.grammar_profile),
        payload, base.version_axes)
end

function _e0_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _e0_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref,
        candidate, base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref,
        candidate, base.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref,
        candidate, base.binding.contract_binding.version_axes)
    bundle = G.G3ContractBindingV2(base.contract_binding.contract_ref,
        candidate, base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains;
        provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(x.feedback_id, x.target_layer,
        x.target_layer === :G1 ? g1_ref : g2_ref, x.channel, x.unit, x.kind,
        x.source_id) for x in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle, realization, control, binding)
end

function _e0_actual_package(candidate_id="fusionconceptai://candidate/candidate-1")
    candidate = G.QualifiedRefV1(candidate_id, "v5")
    g1 = _e0_g1(_e0_child_fixture("G1"), candidate)
    g2 = _e0_g2(_e0_child_fixture("G2"), candidate)
    base_g3 = _e0_child_fixture("G3")
    g3 = _e0_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _e0_expected(package)
    G.UP2E0ExpectedPackageIdentityV1(package.candidate_ref, package.candidate_hash,
        package.g1.contract_ref, package.g2.contract_ref,
        package.g3.contract_binding.contract_ref, package.g1.candidate_hash,
        package.g2.candidate_hash, package.g3.candidate_hash, package.version_axes)
end

@testset "UP2-00E0 actual A bound-input envelope" begin
    @test String(_E0_FIXTURE.schema_id) == "GenomeV5/UP2/UP2CandidatePhysicalBindingV1"
    @test String(_E0_FIXTURE.schema_version) == "v1"
    @test Bool(_E0_FIXTURE.schema_validation_only)
    @test Int(_E0_FIXTURE.mutation_count) == 5
    package = _e0_actual_package()
    package_hash_before = package.candidate_hash
    binding = G.up2_candidate_physical_binding_from_a(package)
    @test package.candidate_hash == package_hash_before
    @test binding.package_hash == package.candidate_hash
    @test binding.candidate_ref == package.candidate_ref
    @test binding.g1_ref == package.g1.contract_ref
    @test binding.g2_ref == package.g2.contract_ref
    @test binding.g3_ref == package.g3.contract_binding.contract_ref
    for ref in (binding.g1_ref, binding.g2_ref, binding.g3_ref)
        @test ref.version == "v5"
        @test !isempty(ref.uri)
        @test !isempty(ref.compatibility_profile)
        @test ref.schema_hash isa G.Digest256
        @test ref.canonicalization_hash isa G.Digest256
    end
    @test binding.g1_component_hash == package.g1.candidate_hash
    @test binding.g2_component_hash == package.g2.candidate_hash
    @test binding.g3_component_hash == package.g3.candidate_hash
    @test binding.version_axes == package.version_axes
    @test binding.schema_hash == G.up2e0_schema_hash()
    @test binding.canonicalization_hash == G.up2e0_canonicalization_hash()
    @test binding.profile_hash == G.up2e0_profile_hash()
    @test binding.binding_hash isa G.Digest256
    @test binding.bound_input_hash isa G.Digest256
    @test binding.binding_hash != binding.package_hash
    @test binding.resolution == :terminal_deferred
    @test binding.n05 === nothing
    @test binding.n06 === nothing
    @test String(_E0_FIXTURE.physical_declarations.N05) in binding.gaps
    @test String(_E0_FIXTURE.physical_declarations.N06) in binding.gaps
    check = G.up2e0_validate_binding(binding)
    @test check.status == :valid
    @test check.compile_calls == check.provider_calls == check.solver_calls == 0
    @test G.up2e0_validate_binding(binding, package).status == :valid
    wrong_gap = G.UP2CandidatePhysicalBindingV1(binding.candidate_ref, binding.package_hash,
        binding.g1_ref, binding.g2_ref, binding.g3_ref, binding.g1_component_hash,
        binding.g2_component_hash, binding.g3_component_hash, binding.version_axes,
        binding.schema_hash, binding.canonicalization_hash, binding.profile_hash,
        nothing, nothing, ("N05_terminal_deferred:wrong", G.UP2E0_N06_AUTHORITY_GAP_V1))
    @test G.up2e0_validate_binding(wrong_gap).status == :fail_closed
    @test "physical_authority_gaps_not_exact" in G.up2e0_validate_binding(wrong_gap).errors
end

@testset "UP2-00E0 reusable G2 plan and candidate-owned identity" begin
    p1 = _e0_actual_package("fusionconceptai://candidate/candidate-1")
    p2 = _e0_actual_package("fusionconceptai://candidate/candidate-2")
    b1 = G.up2_candidate_physical_binding_from_a(p1)
    b2 = G.up2_candidate_physical_binding_from_a(p2)
    @test G.canonical_hash(p1.g2.plan) == G.canonical_hash(p2.g2.plan)
    @test p1.g2.contract_ref != p2.g2.contract_ref
    @test p1.g2.candidate_hash != p2.g2.candidate_hash
    @test p1.candidate_hash != p2.candidate_hash
    @test b1.package_hash != b2.package_hash
    @test b1.bound_input_hash != b2.bound_input_hash
    @test b1.binding_hash != b2.binding_hash
    @test G.up2e0_validate_binding(b1, p2).status == :fail_closed
    @test "source_package_hash_mismatch" in G.up2e0_validate_binding(b1, p2).errors
end

@testset "UP2-00E0 fail-closed identity mutations" begin
    package = _e0_actual_package()
    expected = _e0_expected(package)
    rows = Dict(String(x.id) => x for x in _E0_FIXTURE.mutations)

    foreign_candidate = G.QualifiedRefV1("fusionconceptai://candidate/foreign", "v5")
    e1 = G.UP2E0ExpectedPackageIdentityV1(foreign_candidate, expected.package_hash,
        expected.g1_ref, expected.g2_ref, expected.g3_ref, expected.g1_component_hash,
        expected.g2_component_hash, expected.g3_component_hash, expected.version_axes)
    r1 = G.up2e0_check_package(package, e1)
    @test r1.status == Symbol(String(rows["E0-01-foreign-candidate-ref"].expected_status))
    @test "candidate_ref_mismatch" in r1.errors
    @test r1.compile_calls == r1.provider_calls == r1.solver_calls == 0

    stale_hash = G.digest256_text("stale-package-hash")
    e2 = G.UP2E0ExpectedPackageIdentityV1(expected.candidate_ref, stale_hash,
        expected.g1_ref, expected.g2_ref, expected.g3_ref, expected.g1_component_hash,
        expected.g2_component_hash, expected.g3_component_hash, expected.version_axes)
    r2 = G.up2e0_check_package(package, e2)
    @test r2.status == :fail_closed
    @test "package_hash_mismatch" in r2.errors

    foreign_g2 = G.GenomeContractRef("fusionconceptai://GenomeV5/G2/foreign", "v5",
        expected.g2_ref.schema_hash, expected.g2_ref.canonicalization_hash,
        expected.g2_ref.compatibility_profile)
    e3 = G.UP2E0ExpectedPackageIdentityV1(expected.candidate_ref, expected.package_hash,
        expected.g1_ref, foreign_g2, expected.g3_ref, expected.g1_component_hash,
        expected.g2_component_hash, expected.g3_component_hash, expected.version_axes)
    r3 = G.up2e0_check_package(package, e3)
    @test r3.status == :fail_closed
    @test "G2_ref_mismatch" in r3.errors

    stale_component = G.digest256_text("stale-component-hash")
    e4 = G.UP2E0ExpectedPackageIdentityV1(expected.candidate_ref, expected.package_hash,
        expected.g1_ref, expected.g2_ref, expected.g3_ref, expected.g1_component_hash,
        stale_component, expected.g3_component_hash, expected.version_axes)
    r4 = G.up2e0_check_package(package, e4)
    @test r4.status == :fail_closed
    @test "G2_component_hash_mismatch" in r4.errors

    foreign_axes = (g1=expected.version_axes.g1, g2=(tampered_axis=:foreign,),
        g3=expected.version_axes.g3)
    e5 = G.UP2E0ExpectedPackageIdentityV1(expected.candidate_ref, expected.package_hash,
        expected.g1_ref, expected.g2_ref, expected.g3_ref, expected.g1_component_hash,
        expected.g2_component_hash, expected.g3_component_hash, foreign_axes)
    r5 = G.up2e0_check_package(package, e5)
    @test r5.status == :fail_closed
    @test "version_axes_mismatch" in r5.errors
    injected = (args...) -> throw(ErrorException("unexpected internal fault"))
    unexpected = G._up2e0_check_package_with_inspector(package, expected.candidate_ref,
        expected.package_hash, expected.version_axes, injected)
    @test unexpected.status == :program_exception
    @test unexpected.compile_calls == unexpected.provider_calls == unexpected.solver_calls == 0
    binding = G.up2_candidate_physical_binding_from_a(package)
    injected_checker = (pkg) -> G._up2e0_check_package_with_inspector(pkg, pkg.candidate_ref,
        pkg.candidate_hash, pkg.version_axes, injected)
    joined_unexpected = G._up2e0_validate_binding_with_checker(binding, package, injected_checker)
    @test joined_unexpected.status == :program_exception
    @test "package_source_exception:unexpected internal fault" in joined_unexpected.errors
    @test joined_unexpected.compile_calls == joined_unexpected.provider_calls == joined_unexpected.solver_calls == 0
    injected_expected_checker = (pkg, ref, hash, axes) ->
        G._up2e0_check_package_with_inspector(pkg, ref, hash, axes, injected)
    expected_unexpected = G._up2e0_check_expected_with_checker(package, expected,
        injected_expected_checker)
    @test expected_unexpected.status == :program_exception
    @test "package_source_exception:unexpected internal fault" in expected_unexpected.errors
    @test expected_unexpected.compile_calls == expected_unexpected.provider_calls == expected_unexpected.solver_calls == 0
end

@testset "UP2-00E0 typed extension boundary" begin
    package = _e0_actual_package()
    @test_throws TypeError G.up2_candidate_physical_binding_from_a(package; n05="synthetic")
    @test_throws TypeError G.up2_candidate_physical_binding_from_a(package; n06="synthetic")
    @test_throws ArgumentError G.GenomeContractRef("", "v5", G.up2e0_schema_hash(),
        G.up2e0_canonicalization_hash(), "profile")
end
