using Test
using JSON3
using Serialization
using FusionConceptAI

const _N07N08_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n07_n08_geometry_fixtures.json"), String))
const _G2_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "..", "G2", "fixtures.json"), String))
const G = FusionConceptAI

_qref(x; version="v2") = G.QualifiedRefV1(String(x), version)
_ratio(x) = x isa Integer ? Int64(x) // 1 : begin
    s = String(x); occursin("/", s) ? (parse(Int64, split(s, "/")[1]) // parse(Int64, split(s, "/")[2])) : parse(Int64, s) // 1
end
_ratios(xs, n) = ntuple(i -> _ratio(xs[i]), n)
_symbols(xs) = Tuple(Symbol(String(x)) for x in xs)

function _g2_from_fixture(case_id::String)
    case = first(x for x in _G2_FIXTURE.legal_cases if String(x.case_id) == case_id)
    regions = Tuple(G.G2RegionV2(String(r.id), _ratios(r.lower, 3), _ratios(r.upper, 3),
        _qref(r.chart_ref), _qref(r.embedding_ref), _qref(r.field_space_ref), _symbols(r.boundary_kinds))
        for r in case.regions)
    i = case.interface
    iface = G.G2InterfaceV2(_qref(i.id), String(i.left_region_id), String(i.right_region_id),
        findfirst(==(String(i.axis)), ("x", "y", "z")), _ratio(i.coordinate), Int(i.normal),
        Symbol(String(i.continuity)), Symbol(String(i.transfer)))
    contract = G.RegionInterfaceContractV2(regions, (iface,))
    c = case.plan.chart
    chart = G.G2ChartPlanV2(_qref(c.chart_ref), _qref(c.frame_ref), _symbols(c.axes), Symbol(String(c.map_kind)))
    e = case.plan.embedding
    embedding = G.G2EmbeddingPlanV2(_qref(e.embedding_ref), _qref(e.chart_ref), 3, Symbol(String(e.kind)))
    f = case.plan.field_space
    field = G.G2FieldSpacePlanV2(_qref(f.ref), Symbol(String(f.value_shape)), Symbol(String(f.continuity)), String(f.state_unit))
    m = case.plan.mesh
    mesh = G.G2MeshPlanV2(_qref(m.ref), Tuple(String(x) for x in m.region_ids),
        ntuple(j -> Int(m.cells[j]), 3), Symbol(String(m.basis)), Symbol(String(m.quadrature)))
    x = case.plan.exterior
    patches = Tuple(G.G2BoundaryFacePatchV2(Symbol(String(p.face)), String(p.region_id),
        _ratios(p.lower, 2), _ratios(p.upper, 2)) for p in x.patches)
    exterior = G.G2ExteriorPlanV2(_qref(x.ref), Tuple(String(z) for z in x.boundary_region_ids),
        Symbol(String(x.condition)), _symbols(x.faces); boundary_patches=patches,
        provider_match=Symbol(String(case.profile.provider_match)))
    plan = G.FieldSpacePlanV2(_qref(case.plan.plan_ref), chart, embedding, field, mesh, exterior)
    p = case.profile
    profile = G.SpatialGrammarProfileV2(_qref(p.profile_ref), _qref(p.canonicalization_ref),
        _qref(p.applicability_ref), Int(_G2_FIXTURE.ambient_dimension),
        _symbols(p.topologies), _symbols(p.mesh_families);
        provider_match=Symbol(String(p.provider_match)))
    a = _G2_FIXTURE.version_axes
    axes = G.G2VersionAxesV2(_qref(a.payload_schema.id; version=String(a.payload_schema.version)),
        _qref(a.canonicalization.id; version=String(a.canonicalization.version)),
        _qref(a.applicability.id; version=String(a.applicability.version)),
        _qref(a.receipt.id; version=String(a.receipt.version)))
    ref = G.GenomeContractRef("fusionconceptai://GenomeV5/G2/candidate-1", "v5",
        G.g2_schema_hash(), G.g2_canonicalization_hash(), G.g2_compatibility_profile_token(profile))
    G.FieldGeometryGenomeV5(ref, contract, plan, profile, axes)
end

function _n07n08_specs()
    Tuple(G.N07N08MutationSpecV1(String(x.id), Symbol(String(x.class_id)), String(x.field_path),
        String(x.source_locator), Symbol(String(x.source_type)), Symbol(String(x.mutation_kind)),
        Symbol(String(x.expected_error)), getfield(G, Symbol(String(x.expected_resolution))),
        Int(x.expected_provider_calls)) for x in _N07N08_FIXTURE.mutations)
end

function _child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _actual_g1(base, candidate)
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

function _actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _actual_g3(base, candidate, g1_ref, g2_ref)
    rb = G.G3ContractBindingV2(base.realization.contract_binding.contract_ref, candidate,
        base.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base.control.contract_binding.contract_ref, candidate,
        base.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base.binding.contract_binding.contract_ref, candidate,
        base.binding.contract_binding.version_axes)
    bundle = G.G3ContractBindingV2(base.contract_binding.contract_ref, candidate,
        base.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base.realization.network,
        base.realization.material_domains, base.realization.manufacturing_domains; provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base.control.signal_ports, base.control.controllers,
        base.control.faults, base.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(x.feedback_id, x.target_layer,
        x.target_layer === :G1 ? g1_ref : g2_ref, x.channel, x.unit, x.kind, x.source_id)
        for x in base.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base.binding.links, feedback)
    G.RealizationControlGenomeV5(bundle, realization, control, binding)
end

function _actual_package()
    c = G.QualifiedRefV1("fusionconceptai://candidate/candidate-1", "v5")
    g1 = _actual_g1(_child_fixture("G1"), c)
    g2 = _actual_g2(_child_fixture("G2"), c)
    g3base = _child_fixture("G3")
    g3 = _actual_g3(g3base, c, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=c)
end

@testset "UP2-00B fixture and actual G2 projection" begin
    @test String(_N07N08_FIXTURE.schema_id) == "GenomeV5/UP2/N07N08GeometryProjectionV1"
    @test Int(_N07N08_FIXTURE.mutation_count) == 10
    @test Bool(_N07N08_FIXTURE.schema_validation_only)
    package = _actual_package()
    @test package isa G.CandidateStatePackageV5
    actual = G.n07_n08_projection_from_a(package)
    foreign_g2 = _g2_from_fixture("split_y_half")
    for (case, p) in (("actual_A_package", actual),
                      ("supplemental_split_y_half", G.n07_n08_projection_from_g2(
                          foreign_g2, actual.candidate_ref, foreign_g2.candidate_hash)))
        @test p.projection_hash isa G.Digest256
        @test length(p.fields) == 10
        for spec in _n07n08_specs()
            result = G.n07_n08_validate_mutation(p, spec)
            @test result.status == :fail_closed
            @test result.error_code == spec.expected_error
            @test result.error_path == spec.field_path
            @test result.mutated_input_hash != result.input_hash
            @test result.compile_calls == result.provider_calls == result.solver_calls == 0
        end
    end
end

@testset "UP2-00B independent classification and boundaries" begin
    g2 = _g2_from_fixture("split_x_1")
    p = G.n07_n08_projection_from_g2(g2, G.QualifiedRefV1("fusionconceptai://candidate/candidate-1", "v5"), g2.candidate_hash)
    spec = first(x for x in _n07n08_specs() if x.id == "N08-03")
    forged_oracle = G.N07N08MutationSpecV1(spec.id, spec.class_id, spec.field_path,
        spec.source_locator, spec.source_type, spec.mutation_kind, :invalid_boundary,
        spec.expected_resolution, 0)
    @test G.n07_n08_validate_mutation(p, forged_oracle).error_code == :invalid_boundary
    @test_throws ArgumentError G.n07_n08_projection_from_g2(g2,
        G.QualifiedRefV1("fusionconceptai://candidate/candidate-1", "v4"), g2.candidate_hash)
end
