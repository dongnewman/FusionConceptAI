using Test
using FusionConceptAI
using JSON3
using SHA

const U0 = UnitSignature((0, 0, 0, 0, 0, 0, 0))
const T0 = PhysicalType(:scalar_field, 0, 3, :differential, U0)
const BAD_TEXT = string(Char(0xd800))
mutable struct MutablePayload
    values::Vector{Int}
end

@testset "G1 exact decorated canonical transport" begin
    unit = UnitSignature()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, unit)
    registry = default_operator_registry()
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    function make_payload(prefix::String; intervention::String="intervention", account::String="account")
        identity_program() = begin
            apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
                registry=registry, input_types=(scalar,))
            TypedASTProgramV1((ASTInputV1(1, scalar), apply), (2,), (1,); registry=registry)
        end
        p = identity_program()
        ein = PortAccountEffectV1(ConservationAccountRefV1(account, unit, :input, 1, :inflow), 1 // 1)
        eout = PortAccountEffectV1(ConservationAccountRefV1(account, unit, :output, 1, :outflow), -1 // 1)
        edge_a = AtomicMIMOHyperedgeV1(prefix * "site-a", (MIMOInputBindingV1(1, 1),),
            (MIMOOutputBindingV1(1, 1),), p, governing;
            account_effects=(ein, eout), registry=registry)
        edge_b = AtomicMIMOHyperedgeV1(prefix * "site-b", (MIMOInputBindingV1(1, 2),),
            (MIMOOutputBindingV1(1, 2),), p, governing; registry=registry)
        graph = TypedOperatorHypergraphV1((node(:state, scalar; id=prefix * "state-a"),
            node(:state, scalar; id=prefix * "state-b")), (edge_a, edge_b); registry=registry)
        state_a = StateGeneV1(StateGeneRefV1(prefix * "state-a"), scalar, bounds, (), (), (), state_derived)
        state_b = StateGeneV1(StateGeneRefV1(prefix * "state-b"), scalar, bounds, (), (), (), state_derived)
        observable = ObservableGeneV1(ObservableRefV1(prefix * "obs"),
            ProgramRootRefV1(OperatorSiteRefV1(prefix * "site-a"), 1, scalar),
            QualifiedRefV1(intervention, "v1"), identity_program(), bounds,
            QualifiedRefV1("noise", "v1"), NonnegativeQuantityV1(1 // 10, unit),
            NonnegativeQuantityV1(1 // 10, unit), NonnegativeQuantityV1(1 // 2, unit),
            (QualifiedRefV1("prediction", "v1"),))
        invariant = InvariantV1(InvariantRefV1(prefix * "invariant"), QualifiedRefV1(account, "v1"),
            scope_global, nothing, (InvariantTermV1(StateGeneRefV1(prefix * "state-a"), 1),), (), (), (), 0, entropy_conserved)
        MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (), (observable,), ())
    end
    contract = GenomeContractRef("urn:fusion:test", "v1", repeat("a", 64), repeat("b", 64), "g1")
    profile = CanonicalizationProfileV1("decorated-test", "1",
        CanonicalizationBudgetV1(100_000, 10_000, 512, 8_000_000))
    context = MechanismCanonicalizationContextV1(contract, profile)
    first = canonicalize_mechanism_transport(make_payload("a-"), context)
    renamed = canonicalize_mechanism_transport(make_payload("renamed-"), context)
    @test first isa CanonicalMechanismTransportV1
    @test_throws ArgumentError CanonicalMechanismTransportV1(first.canonical_bytes, context)
    @test_throws ArgumentError CanonicalMechanismTransportV1("{}", context)
    @test_throws ArgumentError CanonicalMechanismTransportV1(first.canonical_bytes[1:end-1], context)
    other_context = MechanismCanonicalizationContextV1(
        GenomeContractRef("urn:fusion:other", "v1", repeat("e", 64), repeat("f", 64), "g1"), profile)
    @test_throws ArgumentError CanonicalMechanismTransportV1(first.canonical_bytes, other_context)
    @test_throws MethodError CanonicalMechanismTransportV1(first.canonical_bytes, context, nothing)
    @test JSON3.read(canonical_mechanism_transport_json(first)).domain == "fusionconceptai:v4:g1-canonical-transport:v1"
    @test JSON3.read(canonical_mechanism_transport_json(first)).canonicalization_version == "1"
    @test canonical_mechanism_transport_json(first) == canonical_mechanism_transport_json(renamed)
    same_identity_profile = CanonicalizationProfileV1("decorated-test", "1",
        CanonicalizationBudgetV1(200_000, 20_000, 512, 8_000_000))
    @test canonical_mechanism_transport_json(first) == canonical_mechanism_transport_json(
        canonicalize_mechanism_transport(make_payload("a-"), MechanismCanonicalizationContextV1(contract, same_identity_profile)))
    changed_profile = CanonicalizationProfileV1("decorated-test-v2", "1",
        CanonicalizationBudgetV1(200_000, 20_000, 512, 8_000_000))
    @test canonical_mechanism_transport_json(first) != canonical_mechanism_transport_json(
        canonicalize_mechanism_transport(make_payload("a-"), MechanismCanonicalizationContextV1(contract, changed_profile)))
    @test canonical_mechanism_transport_json(first) != canonical_mechanism_transport_json(
        canonicalize_mechanism_transport(make_payload("a-"; intervention="other-intervention"), context))
    @test !occursin("a-state-a", canonical_mechanism_transport_json(first))
    @test !occursin("a-site-a", canonical_mechanism_transport_json(first))
    @test occursin("intervention", canonical_mechanism_transport_json(first))
    @test occursin("noise", canonical_mechanism_transport_json(first))
    @test occursin("ast_parameter", canonical_mechanism_transport_json(first)) == false
    extended = FusionConceptAI._g1_transport_extended_incidence(make_payload("a-"))
    @test all(k -> k in extended.kinds, (:state_gene, :invariant_gene, :observable_gene, :ast_input, :ast_apply))
    @test length(extended.kinds) > length(make_payload("a-").operator_graph.nodes) + length(make_payload("a-").operator_graph.hyperedges)
    low_budget = CanonicalizationProfileV1("decorated-test", "1", CanonicalizationBudgetV1(1, 10_000, 512, 8_000_000))
    @test_throws CanonicalizationDeferred canonicalize_mechanism_transport(make_payload("a-"),
        MechanismCanonicalizationContextV1(contract, low_budget))

    layers = mechanism_hash_layers(make_payload("a-"), context)
    @test layers isa MechanismHashLayersV1
    @test fieldcount(typeof(layers)) == 8
    @test all(getfield(layers, i) isa Digest256 for i in 1:8)
    @test mechanism_hash(layers) == layers.decorated_mechanism_hash
    @test_throws ArgumentError CanonicalMechanismV1(first, layers)
    wires = FusionConceptAI._g1_layer_wires(make_payload("a-"), context)
    @test length(wires) == 8
    @test JSON3.read(wires[1]).domain == "fusionconceptai:v4:g1-hash:contract:v1"
    @test JSON3.read(wires[4]).domain == "fusionconceptai:v4:g1-hash:topology:v1"
    @test JSON3.read(wires[8]).domain == "fusionconceptai:v4:g1-hash:candidate-subject:v1"
    @test all(Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(wires[i]))))) == getfield(layers, i) for i in 1:8)
    @test_throws MethodError MechanismHashLayersV1(ntuple(_ -> Digest256(repeat("a", 64)), 8)...)
    renamed_layers = mechanism_hash_layers(make_payload("renamed-"), context)
    @test layers.topology_hash == renamed_layers.topology_hash
    @test layers.operator_program_hash == renamed_layers.operator_program_hash
    @test layers.mechanism_structure_hash == renamed_layers.mechanism_structure_hash
    @test layers.decorated_mechanism_hash == renamed_layers.decorated_mechanism_hash
    @test layers.candidate_subject_hash == renamed_layers.candidate_subject_hash
    domains = ("contract", "canonicalization-profile", "operator-registry", "topology",
        "operator-program", "mechanism-structure", "decorated-mechanism", "candidate-subject")
    @test all(JSON3.read(wires[i]).domain == "fusionconceptai:v4:g1-hash:" * domains[i] * ":v1" for i in 1:8)
    @test JSON3.read(wires[4]).dependencies.contract_hash == layers.contract_hash.value
    @test JSON3.read(wires[4]).dependencies.canonicalization_profile_hash == layers.canonicalization_profile_hash.value
    @test JSON3.read(wires[5]).dependencies.topology_hash == layers.topology_hash.value
    @test JSON3.read(wires[5]).dependencies.operator_registry_hash == layers.operator_registry_hash.value
    @test JSON3.read(wires[6]).dependencies.operator_program_hash == layers.operator_program_hash.value
    @test JSON3.read(wires[7]).dependencies.mechanism_structure_hash == layers.mechanism_structure_hash.value
    @test JSON3.read(wires[8]).dependencies.decorated_mechanism_hash == layers.decorated_mechanism_hash.value
    @test_throws CanonicalizationDeferred FusionConceptAI._g1_layer_canonical(make_payload("a-"), :topology, "{}",
        CanonicalizationProfileV1("layer-low", "1", CanonicalizationBudgetV1(1, 100, 512, 8_000_000)))
    for layer in (:operator_program, :structure, :decorated)
        @test_throws CanonicalizationDeferred FusionConceptAI._g1_layer_canonical(make_payload("a-"), layer, "{}",
            CanonicalizationProfileV1("layer-low-" * String(layer), "1", CanonicalizationBudgetV1(1, 100, 512, 8_000_000)))
    end
    @test mechanism_hash_layers(make_payload("a-"), MechanismCanonicalizationContextV1(contract,
        CanonicalizationProfileV1("decorated-test", "1", CanonicalizationBudgetV1(200_000, 20_000, 512, 8_000_000)))).contract_hash == layers.contract_hash
    split_account_layers = mechanism_hash_layers(make_payload("a-"; account="other-account"), context)
    @test layers.topology_hash == split_account_layers.topology_hash
    @test layers.operator_program_hash == split_account_layers.operator_program_hash
    @test layers.mechanism_structure_hash == split_account_layers.mechanism_structure_hash
    @test layers.decorated_mechanism_hash != split_account_layers.decorated_mechanism_hash
    @test layers.candidate_subject_hash != split_account_layers.candidate_subject_hash
    changed_contract = GenomeContractRef("urn:fusion:changed", "v1", repeat("a", 64), repeat("b", 64), "g1")
    changed_contract_layers = mechanism_hash_layers(make_payload("a-"), MechanismCanonicalizationContextV1(changed_contract, profile))
    @test layers.contract_hash != changed_contract_layers.contract_hash
    @test layers.topology_hash != changed_contract_layers.topology_hash
    @test layers.operator_program_hash != changed_contract_layers.operator_program_hash
    @test layers.mechanism_structure_hash != changed_contract_layers.mechanism_structure_hash
    @test layers.decorated_mechanism_hash != changed_contract_layers.decorated_mechanism_hash
    @test layers.candidate_subject_hash != changed_contract_layers.candidate_subject_hash
    profile_budget_only = CanonicalizationProfileV1("decorated-test", "1",
        CanonicalizationBudgetV1(300_000, 30_000, 512, 8_000_000))
    @test layers.canonicalization_profile_hash == mechanism_hash_layers(make_payload("a-"),
        MechanismCanonicalizationContextV1(contract, profile_budget_only)).canonicalization_profile_hash
    @test layers.candidate_subject_hash == mechanism_hash_layers(make_payload("a-"),
        MechanismCanonicalizationContextV1(contract, profile_budget_only)).candidate_subject_hash
end

include("field_geometry_primitives_tests.jl")

# Keep the independent 4.5b matrices in separate files so their fixture
# helpers cannot accidentally become part of the package's public surface.
include(joinpath(@__DIR__, "mechanism_hash_layers_tests.jl"))
include(joinpath(@__DIR__, "mechanism_hash_layers_adversarial.jl"))
include(joinpath(@__DIR__, "mechanism_phaseb_46_tests.jl"))

@testset "G1 transport binds MIMO positions to incidence ports" begin
    unit = UnitSignature()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, unit)
    registry = default_operator_registry()
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    function make_mimo_payload(; reverse_tuple=false, remap_nodes=false)
        apply1 = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(scalar,))
        apply2 = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (2,), (;);
            registry=registry, input_types=(scalar,))
        program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), apply1, apply2),
            (3, 4), (1, 2); registry=registry)
        sample_apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(scalar,))
        sample_program = TypedASTProgramV1((ASTInputV1(1, scalar), sample_apply), (2,), (1,); registry=registry)
        input_bindings = reverse_tuple ?
            (MIMOInputBindingV1(2, remap_nodes ? 1 : 2), MIMOInputBindingV1(1, remap_nodes ? 2 : 1)) :
            (MIMOInputBindingV1(1, remap_nodes ? 2 : 1), MIMOInputBindingV1(2, remap_nodes ? 1 : 2))
        output_bindings = reverse_tuple ?
            (MIMOOutputBindingV1(2, remap_nodes ? 1 : 2), MIMOOutputBindingV1(1, remap_nodes ? 2 : 1)) :
            (MIMOOutputBindingV1(1, remap_nodes ? 2 : 1), MIMOOutputBindingV1(2, remap_nodes ? 1 : 2))
        account_in = PortAccountEffectV1(ConservationAccountRefV1("account", unit, :input, 1, :inflow), 1 // 1)
        account_out = PortAccountEffectV1(ConservationAccountRefV1("account", unit, :output, 1, :outflow), -1 // 1)
        edge = AtomicMIMOHyperedgeV1("mimo-edge", input_bindings, output_bindings, program, governing;
            account_effects=(account_in, account_out), registry=registry)
        graph = TypedOperatorHypergraphV1((node(:state, scalar; id="state-a"), node(:state, scalar; id="state-b")),
            (edge,); registry=registry)
        state_a = StateGeneV1(StateGeneRefV1("state-a"), scalar, bounds, (), (), (), state_derived)
        state_b = StateGeneV1(StateGeneRefV1("state-b"), scalar, bounds, (), (), (), state_derived)
        observable = ObservableGeneV1(ObservableRefV1("obs"), ProgramRootRefV1(OperatorSiteRefV1("mimo-edge"), 1, scalar),
            QualifiedRefV1("intervention", "v1"), sample_program, bounds, QualifiedRefV1("noise", "v1"),
            NonnegativeQuantityV1(1 // 10, unit), NonnegativeQuantityV1(1 // 10, unit), NonnegativeQuantityV1(1 // 2, unit),
            (QualifiedRefV1("prediction", "v1"),))
        invariant = InvariantV1(InvariantRefV1("invariant"), QualifiedRefV1("account", "v1"), scope_global, nothing,
            (InvariantTermV1(StateGeneRefV1("state-a"), 1),), (), (), (), 0, entropy_conserved)
        MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (), (observable,), ())
    end
    contract = GenomeContractRef("urn:fusion:mimo-transport-test", "v1", repeat("c", 64), repeat("d", 64), "g1")
    profile = CanonicalizationProfileV1("mimo-transport-test", "1", CanonicalizationBudgetV1(100_000, 10_000, 512, 8_000_000))
    normal = make_mimo_payload()
    reordered = make_mimo_payload(reverse_tuple=true)
    remapped = make_mimo_payload(remap_nodes=true)
    normal_json = canonical_mechanism_transport_json(canonicalize_mechanism_transport(normal, MechanismCanonicalizationContextV1(contract, profile)))
    reordered_json = canonical_mechanism_transport_json(canonicalize_mechanism_transport(reordered, MechanismCanonicalizationContextV1(contract, profile)))
    remapped_json = canonical_mechanism_transport_json(canonicalize_mechanism_transport(remapped, MechanismCanonicalizationContextV1(contract, profile)))
    @test normal_json == reordered_json
    @test normal_json != remapped_json
    @test count(==(:atomic_edge), FusionConceptAI._g1_transport_extended_incidence(normal).kinds) == 1
end

mutable struct MutableNumber <: Number
    value::Int
end
struct InjectInteger <: Integer
end
Base.string(::InjectInteger) = "0,\"injected\":true"
struct OpaqueValue
    value::Int
end
mutable struct MutableText <: AbstractString
    data::String
end
Base.ncodeunits(x::MutableText) = ncodeunits(x.data)
Base.codeunit(::Type{MutableText}) = UInt8
Base.codeunit(x::MutableText, i::Integer) = codeunit(x.data, i)
Base.codeunits(x::MutableText) = codeunits(x.data)
Base.getindex(x::MutableText, i::Int) = getindex(x.data, i)
Base.iterate(x::MutableText, state=1) = iterate(x.data, state)
Base.isvalid(x::MutableText, i::Int) = isvalid(x.data, i)
struct UnknownRule <: OperatorTypeRuleV1
end
struct AlwaysRule <: OperatorTypeRuleV1
end
struct FunctionRule <: OperatorTypeRuleV1
    executable::Function
end

function fixture_graph(; reverse=false, labels=("alpha", "beta"), ids=("n-a", "n-b"))
    ns = [node(:state, T0; id=ids[1], label=labels[1]), node(:state, T0; id=ids[2], label=labels[2])]
    ast = ast_leaf(:state, T0)
    es = [TypedHyperedge("edge-x", (1,), (2,), ast, :governing)]
    reverse ? TypedOperatorHypergraphV1(reverse(ns), [TypedHyperedge("edge-y", (2,), (1,), ast, :governing)]) : TypedOperatorHypergraphV1(ns, es)
end

@testset "P0 contract refs and independent genome hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", repeat(string(i), 64), repeat(string(i+1), 64), "profile-v4") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    @test all(x -> x isa Digest256, (registry.mechanism.schema_hash, registry.field_geometry.schema_hash, registry.realization_control.schema_hash))
    g = fixture_graph()
    m = MechanismGenomeV4(1, refs[1], g)
    f = FieldGeometryGenomeV4(2, refs[2], g)
    r = RealizationControlGenomeV4(3, 4, refs[3], g, g)
    @test all(x -> length(string(x)) == 64, (mechanism_hash(m), field_geometry_hash(f), realization_control_hash(r)))
    @test mechanism_hash(m) == mechanism_hash(MechanismGenomeV4(999, refs[1], fixture_graph(labels=("other-a", "other-b"), ids=("z", "y"))))
    @test_throws ArgumentError GenomeContractRef("urn:x", "v4", "hash", "canon", "")
    @test_throws ArgumentError ApplicabilityRecord("obligation", required, "not-a-digest")
    @test_throws ArgumentError GenomeContractRef(BAD_TEXT, "v4", repeat("a", 64), repeat("b", 64), "profile")
    @test_throws ArgumentError ApplicabilityRecord(BAD_TEXT, required)
end

@testset "P0 temporal algebra and immutable operator registry" begin
    clock = QualifiedRefV1("clock", "v1")
    differential = TemporalTypeV1(differential_time)
    @test PhysicalType(:scalar_field, 0, 3, differential, U0).temporal_type == differential
    @test PhysicalType(:scalar_field, 0, 3, :differential, U0).temporal_type.kind == differential_time
    @test_throws ArgumentError PhysicalType(:scalar_field, 0, 3, :unknown_time, U0)
    registry = default_operator_registry()
    @test length(registry.operators) == 20
    t = PhysicalType(:scalar_field, 0, 3, differential, U0)
    static = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), U0)
    @test validate_operator_signature(registry, OperatorRefV1("ADD", "v1"), (t, t), (t,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("ADD", "v1"),
        (t, PhysicalType(:scalar_field, 0, 3, differential, UnitSignature((1, 0, 0, 0, 0, 0, 0)))), (t,))
    @test validate_operator_signature(registry, OperatorRefV1("SCALAR_MUL", "v1"), (static, t), (t,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("SCALAR_MUL", "v1"),
        (PhysicalType(:scalar_field, 0, 2, TemporalTypeV1(static_time), U0), t), (t,))
    dt_out = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, UInt8(1)), UnitSignature((0, 0, -1, 0, 0, 0, 0)))
    @test validate_operator_signature(registry, OperatorRefV1("DT", "v1"), (t,), (dt_out,))
    other_clock = QualifiedRefV1("other-clock", "v1")
    @test_throws ArgumentError TemporalTypeV1(differential_time, UInt8(1), other_clock)
    discrete = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, UInt8(0), clock), U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DT", "v1"), (discrete,), (discrete,))
    @test validate_operator_signature(registry, OperatorRefV1("SAMPLE", "v1"), (t,), (discrete,); parameters=(target_clock=clock,))
    @test validate_operator_signature(registry, OperatorRefV1("HOLD", "v1"), (discrete,), (t,); parameters=(target_kind=:differential_time,))
    @test validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (t,), (t,); parameters=(delay_seconds=0.25,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (t,), (t,); parameters=(delay_seconds=-1.0,))
    add_manifest = operator_manifest(registry, "ADD")
    @test_throws ArgumentError register_operator(registry, add_manifest)
    empty_registry = OperatorRegistryV1()
    extended = register_operator(empty_registry, add_manifest)
    @test isempty(empty_registry.operators) && length(extended.operators) == 1
    @test_throws ArgumentError OperatorManifestV1(add_manifest.operator_ref, add_manifest.input_arity, add_manifest.output_arity,
        add_manifest.input_type_rule, add_manifest.output_type_rule; manifest_hash=digest256_text("tampered"))
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("UNKNOWN", "v1"), 1, 1, UnknownRule(), UnknownRule())
end

@testset "P0 temporal registry remediation adversarial controls" begin
    clock = QualifiedRefV1("clock", "v1")
    @test :time_kind in propertynames(T0)
    @test_throws ArgumentError TemporalTypeV1(static_time, 1)
    @test_throws ArgumentError TemporalTypeV1(static_time, 0, clock)
    @test_throws ArgumentError TemporalTypeV1(algebraic_time, 1)
    @test_throws ArgumentError TemporalTypeV1(differential_time, 0, clock)
    @test_throws ArgumentError TemporalTypeV1(discrete_time, 0)
    @test_throws ArgumentError TemporalTypeV1(discrete_time, 1, clock)
    @test_throws ArgumentError TemporalTypeV1(event_time, 0)
    @test_throws ArgumentError TemporalTypeV1(event_time, 1, clock)
    @test_throws ArgumentError TemporalTypeV1(differential_time, 256)

    registry = default_operator_registry()
    differential = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    discrete = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, 0, clock), U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("ADD", "v1"),
        (differential, discrete), (differential,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DT", "v1"), (differential,), (differential,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("SAMPLE", "v1"), (differential,), (discrete,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("HOLD", "v1"), (discrete,), (differential,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"),
        (PhysicalType(:scalar_field, 0, 3, :static, U0),), (PhysicalType(:scalar_field, 0, 3, :static, U0),);
        parameters=(delay_seconds=1.0,))

    length_unit = UnitSignature((0, -1, 0, 0, 0, 0, 0))
    laplace_unit = UnitSignature((0, -2, 0, 0, 0, 0, 0))
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    @test validate_operator_signature(registry, OperatorRefV1("LAPLACE", "v1"), (scalar,),
        (PhysicalType(:scalar_field, 0, 3, :differential, laplace_unit),))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("LAPLACE", "v1"), (scalar,),
        (PhysicalType(:scalar_field, 0, 3, :differential, length_unit),))

    control = PhysicalType(:control_signal, 0, 3, :differential, U0)
    event = PhysicalType(:event_signal, 0, 3, TemporalTypeV1(event_time, 0, clock), U0)
    event_state = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, 0, clock), U0)
    @test validate_operator_signature(registry, OperatorRefV1("THRESHOLD_SWITCH", "v1"), (control, scalar), (scalar,))
    @test validate_operator_signature(registry, OperatorRefV1("EVENT_RESET", "v1"), (event, event_state), (event_state,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("EVENT_RESET", "v1"), (event, scalar), (scalar,))
    other_event_state = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, 0, QualifiedRefV1("other-clock", "v1")), U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("EVENT_RESET", "v1"), (event, other_event_state), (other_event_state,))

    add = operator_manifest(registry, "ADD")
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        commutative_input_groups=((1, 1),))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        commutative_input_groups=((1, 2), (2,)))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        allowed_conservation_effects=(:energy,), forbidden_conservation_effects=(:energy,))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        pure=false)
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        max_derivative_contribution=1)
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 3, 2, AlwaysRule(), AlwaysRule())
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, FunctionRule(identity), FunctionRule(identity))
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("DELAY", "v1"), 1, 1, DelayRuleV1(), DelayRuleV1())
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("SAMPLE", "v1"), 1, 1, SamplingRuleV1(false), SamplingRuleV1(false))
    @test canonical_hash(registry) == canonical_hash(OperatorRegistryV1(reverse(registry.operators)))
    dt_ok = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, 1), UnitSignature((0, 0, -1, 0, 0, 0, 0)))
    @test TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:dt, (1,), dt_ok)), 2, (1,)).root == 2
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar),
        TypedASTNode(:dt, (1,), PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, 1), UnitSignature((0, 0, 1, 0, 0, 0, 0))))), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar),
        TypedASTNode(:dt, (1,), PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, 2), UnitSignature((0, 0, -1, 0, 0, 0, 0))))), 2, (1,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,);
        parameters=(delay_seconds=true,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,);
        parameters=(delay_seconds=big(10)^10000,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,);
        parameters=(delay_seconds=1.0, unknown=:x))
    bad_symbol = Symbol(String(UInt8[0xff]))
    @test !is_canonical_value(bad_symbol)
    @test_throws ArgumentError PhysicalType(bad_symbol, 0, 3, :differential, U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("HOLD", "v1"), (discrete,),
        (scalar,); parameters=(target_kind=bad_symbol,))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        commutative_input_groups=((true, 2),))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,);
        registry=OperatorRegistryV1())
end

@testset "P0 sealed AST value and manifest checks" begin
    registry = default_operator_registry()
    @test_throws ArgumentError TypedASTNode(:state, (), T0, (mutable_value=Any[1],))
    @test TypedASTNode(:state, (), T0, (exact_rational=1//2,)).parameters.exact_rational == 1//2
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0),
        TypedASTNode(:add, (1, 1), vector)), 2, (1,); registry=registry)
    add = operator_manifest(registry, "ADD")
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        parameter_schema=(OperatorParameterSpecV1(:evil, :symbol, true),))
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("DT_EVIL", "v1"), 1, 1,
        TimeDerivativeRuleV1(), TimeDerivativeRuleV1(); max_derivative_contribution=0)
    @test validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"),
        (T0,), (T0,); parameters=(delay_seconds=1//2,))
end

@testset "P0 typed tensor operators and AST manifest bindings" begin
    registry = default_operator_registry()
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    tensor = PhysicalType(:vector_field, 2, 3, :differential, U0)
    @test validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (vector, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (scalar, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (vector, vector), (vector,))
    rank2 = PhysicalType(:vector_field, 2, 3, :differential, U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (vector, rank2), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (rank2, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (rank2, rank2), (scalar,))
    @test validate_operator_signature(registry, OperatorRefV1("TENSOR_PRODUCT", "v1"), (vector, vector), (tensor,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("TENSOR_PRODUCT", "v1"), (vector, vector), (vector,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("TENSOR_PRODUCT", "v1"), (vector, vector),
        (PhysicalType(:vector_field, 2, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0))),))
    @test validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=1,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=0,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=true,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=big(1),))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (vector,);
        parameters=(contraction_order=1,))

    dot_ast = TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,); registry=registry)
    extra = OperatorManifestV1(OperatorRefV1("UNUSED", "v1"), 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1))
    registry_extra = register_operator(registry, extra)
    dot_ast_extra = TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,); registry=registry_extra)
    @test canonical_hash(dot_ast) == canonical_hash(dot_ast_extra)
    dot = operator_manifest(registry, "DOT")
    dot_alt = OperatorManifestV1(dot.operator_ref, 2, 1, DotProductRuleV1(), DotProductRuleV1(); allowed_roles=(:boundary,))
    registry_alt = OperatorRegistryV1(tuple((o for o in registry.operators if o.operator_ref != dot.operator_ref)..., dot_alt))
    dot_ast_alt = TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,); registry=registry_alt)
    @test canonical_hash(dot_ast) != canonical_hash(dot_ast_alt)
    @test length(dot_ast.manifest_bindings) == 1
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,);
        registry=registry, manifest_bindings=())

    add_ast = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:add, (1, 1), scalar)), 2, (1,); registry=registry)
    add = operator_manifest(registry, "ADD")
    add_alt = OperatorManifestV1(add.operator_ref, 2, 1, SameTypeVariadicRuleV1(2, 2), SameTypeVariadicRuleV1(2, 2);
        allowed_roles=(:boundary,), commutative_input_groups=((1, 2),))
    registry_add_alt = OperatorRegistryV1(tuple((o for o in registry.operators if o.operator_ref != add.operator_ref)..., add_alt))
    add_ast_alt = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:add, (1, 1), scalar)), 2, (1,); registry=registry_add_alt)
    @test canonical_hash(add_ast) != canonical_hash(add_ast_alt)
    @test canonical_hash(add_ast) == canonical_hash(TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:add, (1, 1), scalar)), 2, (1,); registry=registry))
    @test_throws ArgumentError operator_manifest(registry, "INTEGRAL_KERNEL")
    @test_throws ArgumentError ContractRuleV1(1)
    contract_k1 = TypedAST((TypedASTNode(:state, (), rank2), TypedASTNode(:state, (), rank2),
        TypedASTNode(:contract, (1, 2), rank2, (contraction_order=1,))), 3, (1, 2); registry=registry)
    contract_k2 = TypedAST((TypedASTNode(:state, (), rank2), TypedASTNode(:state, (), rank2),
        TypedASTNode(:contract, (1, 2), scalar, (contraction_order=2,))), 3, (1, 2); registry=registry)
    @test contract_k1.nodes[end].output_type.tensor_rank == 2
    @test contract_k2.nodes[end].output_type.tensor_rank == 0
    @test canonical_hash(contract_k1) != canonical_hash(contract_k2)
end

@testset "P0 constructor dispatch closure subprocess" begin
    project = Base.active_project()
    script = """
using FusionConceptAI
FusionConceptAI._checked_int(::Int, ::String) = typemax(Int)
FusionConceptAI._validated_string(::String, ::String) = \"polluted\"
FusionConceptAI._default_manifest(::String, ::Int, ::SameTypeVariadicRuleV1; kwargs...) = error(\"polluted\")
@assert SameTypeVariadicRuleV1(2, 2).minimum_arity == 2
@assert QualifiedRefV1(\"clock\", \"v1\").id == \"clock\"
@assert length(default_operator_registry().operators) == 20
println(\"constructor-dispatch-subprocess-ok\")
"""
    @test success(`$(Base.julia_cmd()) --project=$project -e $script`)
end

@testset "P0 registry-validated multi-root typed AST programs" begin
    registry = default_operator_registry()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    add_node = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_node), (3,), (1, 2); registry=registry)
    @test program.roots == (3,)
    @test length(program.used_manifest_bindings) == 1
    @test_throws MethodError ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;), scalar, ((1, 2),), true, true, nothing)
    @test_throws MethodError TypedASTProgramV1((ASTInputV1(1, scalar),), (1,), (1,), ())
    add_left = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    add_right = ASTApplyV1(OperatorRefV1("ADD", "v1"), (4, 3), (;); registry=registry, input_types=(scalar, scalar))
    three_to_five = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar), add_left, add_right), (5,), (1, 2, 3); registry=registry)
    @test three_to_five.nodes[5].output_type == scalar
    duplicate_add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    duplicate_add_2 = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    combine_duplicate = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 4), (;); registry=registry, input_types=(scalar, scalar))
    cse_copy = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), duplicate_add, duplicate_add_2, combine_duplicate), (5,), (1, 2); registry=registry)
    cse_shared_final = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 3), (;); registry=registry, input_types=(scalar, scalar))
    cse_shared = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), duplicate_add, cse_shared_final), (4,), (1, 2); registry=registry)
    @test length(cse_copy.nodes) == length(cse_shared.nodes)
    @test canonical_hash(cse_copy) == canonical_hash(cse_shared)
    stateful_copy_a = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    stateful_copy_b = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    stateful_program = TypedASTProgramV1((ASTInputV1(1, scalar), stateful_copy_a, stateful_copy_b), (2, 3), (1,); registry=registry)
    @test length(stateful_program.nodes) == 3
    program_dispatch_script = """
    using FusionConceptAI
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((0,0,0,0,0,0,0)))
    registry = default_operator_registry()
    apply = ASTApplyV1(OperatorRefV1(\"ADD\", \"v1\"), (1,2), (;); registry=registry, input_types=(scalar,scalar))
    program = TypedASTProgramV1((ASTInputV1(1,scalar), ASTInputV1(2,scalar), apply), (3,), (1,2); registry=registry)
    before = canonical_hash(program)
    FusionConceptAI._canonical(::NamedTuple) = \"{}\"
    @assert canonical_hash(program) == before
    """
    @test success(`$(Base.julia_cmd()) --project=$(Base.active_project()) -e $program_dispatch_script`)
    @test canonical_hash(program) == canonical_hash(TypedASTProgramV1((ASTInputV1(2, scalar), ASTInputV1(1, scalar),
        ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 1), (;); registry=registry, input_types=(scalar, scalar))), (3,), (2, 1); registry=registry))
    mixed = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, vector)), (1, 2), (1, 2); registry=registry)
    @test mixed.roots == (1, 2)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar),), (), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar),), (1, 1), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar),), (2,), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(1, scalar)), (1,), (1, 2); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_node), (3,), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_node, ASTParameterV1(:dead, scalar)), (3,), (1, 2); registry=registry)
    cycle = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    @test_throws ArgumentError TypedASTProgramV1((cycle,), (1,), (); registry=registry)
    @test_throws ArgumentError ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, vector))

    roots_a = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, vector)), (1, 2), (1, 2); registry=registry)
    roots_b = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, vector)), (2, 1), (1, 2); registry=registry)
    @test canonical_hash(roots_a) != canonical_hash(roots_b)
    old = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,); registry=registry)
    bridged = TypedASTProgramV1(old; registry=registry)
    @test bridged.roots == (2,) && bridged.input_ports == (1,)
    @test length(bridged.used_manifest_bindings) == 1
    old_with_metadata = TypedAST((TypedASTNode(:state, (), scalar, (state_name=:x,)),
        TypedASTNode(:parameter, (), scalar, (name=:gain, scale=2,)),
        TypedASTNode(:add, (1, 2), scalar)), 3, (1,); registry=registry)
    metadata_bridge = TypedASTProgramV1(old_with_metadata; registry=registry)
    @test metadata_bridge.nodes[1].parameters == (state_name=:x,)
    @test metadata_bridge.nodes[2].parameters == (name=:gain, scale=2)
    old_constant_without_value = TypedAST((TypedASTNode(:constant, (), scalar, (scale=2,)),), 1, (); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1(old_constant_without_value; registry=registry)
    custom_identity = OperatorManifestV1(OperatorRefV1("IDENTITY", "v1"), 1, 1,
        SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1); allowed_roles=(:governing,))
    custom_registry = OperatorRegistryV1(filter(m -> m.operator_ref.qualified.id != "IDENTITY", registry.operators))
    custom_registry = register_operator(custom_registry, custom_identity)
    old_custom = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,); registry=custom_registry)
    @test_throws ArgumentError TypedASTProgramV1(old_custom; registry=registry)
    grouped_manifest = OperatorManifestV1(OperatorRefV1("ADD_NONCONTIG", "v1"), 3, 1,
        SameTypeVariadicRuleV1(3, 3), SameTypeVariadicRuleV1(3, 3); commutative_input_groups=((2, 3),))
    grouped_registry = register_operator(registry, grouped_manifest)
    grouped_a = ASTApplyV1(OperatorRefV1("ADD_NONCONTIG", "v1"), (1, 2, 3), (;);
        registry=grouped_registry, input_types=(scalar, scalar, scalar))
    grouped_b = ASTApplyV1(OperatorRefV1("ADD_NONCONTIG", "v1"), (1, 3, 2), (;);
        registry=grouped_registry, input_types=(scalar, scalar, scalar))
    grouped_program_a = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar), grouped_a), (4,), (1, 2, 3); registry=grouped_registry)
    grouped_program_b = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar), grouped_b), (4,), (1, 2, 3); registry=grouped_registry)
    @test canonical_hash(grouped_program_a) == canonical_hash(grouped_program_b)
    interleaved_add_a = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    interleaved_add_b = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    interleaved_outer = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 4), (;); registry=registry, input_types=(scalar, scalar))
    interleaved_roots = TypedASTProgramV1((ASTInputV1(1, scalar), interleaved_add_a, interleaved_add_b,
        ASTInputV1(4, scalar), interleaved_outer), (3, 5), (1, 4); registry=registry)
    @test length(interleaved_roots.roots) == 2 && length(unique(interleaved_roots.roots)) == 2
    @test interleaved_roots.input_ports == (1, 4)
    @test canonical_hash(interleaved_roots) isa Digest256
    root_add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    root_neg = ASTApplyV1(OperatorRefV1("NEG", "v1"), (1,), (;); registry=registry, input_types=(scalar,))
    root_outer = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 4), (;); registry=registry, input_types=(scalar, scalar))
    three_roots = TypedASTProgramV1((ASTInputV1(1, scalar), interleaved_add_a, root_add, root_neg, root_outer), (3, 4, 5), (1,); registry=registry)
    @test three_roots.roots == (3, 4, 5) && three_roots.input_ports == (1,)
    @test canonical_hash(three_roots) isa Digest256
    @test canonical_hash(three_roots) != canonical_hash(TypedASTProgramV1(three_roots.nodes, (4, 3, 5), three_roots.input_ports; registry=registry))
    shift_outer = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 4), (;); registry=registry, input_types=(scalar, scalar))
    shift_root = ASTApplyV1(OperatorRefV1("NEG", "v1"), (2,), (;); registry=registry, input_types=(scalar,))
    shifted_two_roots = TypedASTProgramV1((ASTInputV1(1, scalar), interleaved_add_a, interleaved_add_b,
        ASTInputV1(4, scalar), shift_outer, shift_root), (5, 6), (1, 4); registry=registry)
    @test shifted_two_roots.input_ports == (1, 3) && shifted_two_roots.roots == (4, 5)
    @test canonical_hash(shifted_two_roots) isa Digest256

    delay1 = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    delay2 = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    two_delays = TypedASTProgramV1((ASTInputV1(1, scalar), delay1, delay2), (2, 3), (1,); registry=registry)
    one_delay = TypedASTProgramV1((ASTInputV1(1, scalar), delay1), (2,), (1,); registry=registry)
    @test canonical_hash(two_delays) != canonical_hash(one_delay)
end

@testset "P0 atomic MIMO hyperedges and conservation contracts" begin
    registry = default_operator_registry()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    identity_ref = OperatorRefV1("IDENTITY", "v1")
    p1 = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(identity_ref, (1,), (;); registry=registry, input_types=(scalar,))), (2,), (1,); registry=registry)
    e1 = AtomicMIMOHyperedgeV1("one", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry)
    g1 = TypedOperatorHypergraphV1((node(:input, scalar; id="n1", label="visible"), node(:output, scalar; id="n2", label="visible")), (e1,))
    @test length(g1.hyperedges) == 1 && g1.hyperedges[1].program_hash isa Digest256
    @test canonical_hash(e1) == canonical_hash(AtomicMIMOHyperedgeV1("different-id", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry))
    @test occursin("fusionconceptai:v4:atomic-mimo-hyperedge:v1", canonical_json(e1))
    @test canonical_hash(e1) != canonical_hash(g1)
    sparse_edge = AtomicMIMOHyperedgeV1("sparse", (MIMOInputBindingV1(1, 1_000_000),), (MIMOOutputBindingV1(1, 2_000_000),), p1, additive; registry=registry)
    @test occursin("\"graph_node\":1000000", canonical_json(sparse_edge))
    @test canonical_hash(sparse_edge) == canonical_hash(sparse_edge)
    @test @allocated(canonical_json(sparse_edge)) < 1_000_000
    @test canonical_hash(g1) == canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar; id="x", label="hidden"), node(:output, scalar; id="y", label="hidden")),
        (AtomicMIMOHyperedgeV1("renamed", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry),)))

    add_ref = OperatorRefV1("ADD", "v1")
    p2 = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTApplyV1(add_ref, (1, 2), (;); registry=registry, input_types=(scalar, scalar))), (3,), (1, 2); registry=registry)
    e2 = AtomicMIMOHyperedgeV1("two", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), (MIMOOutputBindingV1(1, 3),), p2, additive; registry=registry)
    g2 = TypedOperatorHypergraphV1((node(:input, scalar), node(:input, scalar), node(:output, scalar)), (e2,))
    @test length(g2.hyperedges) == 1
    p35_nodes = AbstractTypedASTNodeV1[ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar)]
    for i in 1:5
        push!(p35_nodes, ASTApplyV1(identity_ref, ((i - 1) % 3 + 1,), (;); registry=registry, input_types=(scalar,)))
    end
    p35 = TypedASTProgramV1(Tuple(p35_nodes), (4, 5, 6, 7, 8), (1, 2, 3); registry=registry)
    e35 = AtomicMIMOHyperedgeV1("five", Tuple(MIMOInputBindingV1(i, i) for i in 1:3),
        Tuple(MIMOOutputBindingV1(i, i + 3) for i in 1:5), p35, additive; registry=registry)
    g35 = TypedOperatorHypergraphV1(tuple((node(:port, scalar) for _ in 1:8)...), (e35,))
    @test length(g35.hyperedges) == 1 && canonical_hash(g35) isa Digest256
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad", (MIMOInputBindingV1(1, 1),), (), p1, additive; registry=registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(1, 1)), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(2, 2),), p1, additive; registry=registry)
    @test_throws ArgumentError TypedOperatorHypergraphV1((node(:input, vector), node(:output, scalar)), (e1,))
    sub = ASTApplyV1(OperatorRefV1("SUB", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    sub_rev = ASTApplyV1(OperatorRefV1("SUB", "v1"), (2, 1), (;); registry=registry, input_types=(scalar, scalar))
    psub = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), sub), (3,), (1, 2); registry=registry)
    psub_rev = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), sub_rev), (3,), (1, 2); registry=registry)
    @test canonical_hash(psub) != canonical_hash(psub_rev)
    esub = AtomicMIMOHyperedgeV1("sub", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), (MIMOOutputBindingV1(1, 3),), psub, additive; registry=registry)
    esub_rev = AtomicMIMOHyperedgeV1("sub-rev", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), (MIMOOutputBindingV1(1, 3),), psub_rev, additive; registry=registry)
    @test canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:input, scalar), node(:output, scalar)), (esub,))) !=
        canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:input, scalar), node(:output, scalar)), (esub_rev,)))
    add_rev = ASTApplyV1(add_ref, (2, 1), (;); registry=registry, input_types=(scalar, scalar))
    @test canonical_hash(p2) == canonical_hash(TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_rev), (3,), (1, 2); registry=registry))

    account_a = ConservationAccountRefV1("energy", U0, :output, 1, :minus)
    account_b = ConservationAccountRefV1("energy", U0, :output, 2, :plus)
    pair = InterfaceFluxPairV1(PortAccountEffectV1(account_a, -1//1), PortAccountEffectV1(account_b, 1//1))
    iface_nodes = (ASTInputV1(1, scalar), ASTApplyV1(identity_ref, (1,), (;); registry=registry, input_types=(scalar,)), ASTApplyV1(OperatorRefV1("NEG", "v1"), (1,), (;); registry=registry, input_types=(scalar,)))
    iface_program = TypedASTProgramV1(iface_nodes, (2, 3), (1,); registry=registry)
    iface_edge = AtomicMIMOHyperedgeV1("iface", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)), iface_program, interface; interface_flux_pairs=(pair,), registry=registry)
    @test TypedOperatorHypergraphV1((node(:input, scalar), node(:out, scalar), node(:out, scalar)), (iface_edge,)).hyperedges[1] isa AtomicMIMOHyperedgeV1
    iface_edge_reordered = AtomicMIMOHyperedgeV1("iface-reordered", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(2, 3), MIMOOutputBindingV1(1, 2)), iface_program, interface; interface_flux_pairs=(pair,), registry=registry)
    @test canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:out, scalar), node(:out, scalar)), (iface_edge,))) ==
        canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:out, scalar), node(:out, scalar)), (iface_edge_reordered,)))
    iface_program_swapped = TypedASTProgramV1(iface_nodes, (3, 2), (1,); registry=registry)
    iface_edge_swapped = AtomicMIMOHyperedgeV1("iface-swapped", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)), iface_program_swapped, interface; interface_flux_pairs=(pair,), registry=registry)
    @test canonical_hash(iface_edge) != canonical_hash(iface_edge_swapped)
    @test_throws ArgumentError InterfaceFluxPairV1(PortAccountEffectV1(account_a, -1//1), PortAccountEffectV1(account_b, -1//1))
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("duplicate-pair", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)), iface_program, interface; interface_flux_pairs=(pair, pair), registry=registry)
    @test_throws ArgumentError PortAccountEffectV1(account_a, 1.0)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("source", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, source; registry=registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("iface", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 2)), iface_program, interface; registry=registry)
    legacy = TypedHyperedge("legacy", (1,), (2,), TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,); registry=registry), :additive)
    @test AtomicMIMOHyperedgeV1(legacy; registry=registry).program isa TypedASTProgramV1
    legacy_renumbered = TypedHyperedge("legacy-renumbered", (2,), (1,), legacy.ast, :additive)
    @test TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)),
        (AtomicMIMOHyperedgeV1(legacy_renumbered; registry=registry),)).hyperedges[1] isa AtomicMIMOHyperedgeV1
    renumbered = AtomicMIMOHyperedgeV1("renumbered", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), p1, additive; registry=registry)
    renumbered_graph = TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)), (renumbered,))
    @test canonical_hash(renumbered_graph) == canonical_hash(g1)
    tampered_manifest = OperatorManifestV1(identity_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:additive,), allowed_conservation_effects=(:net_creation,))
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("mismatch", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive;
        registry=OperatorRegistryV1((tampered_manifest,)))
    source_ref = OperatorRefV1("IDENTITY", "v1")
    source_manifest = OperatorManifestV1(source_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:source,), allowed_conservation_effects=(:net_creation,))
    source_registry = OperatorRegistryV1((source_manifest,))
    source_program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(source_ref, (1,), (;); registry=source_registry, input_types=(scalar,))), (2,), (1,); registry=source_registry)
    source_account = ConservationAccountRefV1("energy", U0, :output, 1, :plus)
    source_effect = PortAccountEffectV1(source_account, 1//1)
    source_edge = AtomicMIMOHyperedgeV1("source-ok", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), source_program, source; account_effects=(source_effect,), registry=source_registry)
    @test TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)), (source_edge,); registry=source_registry).hyperedges[1] isa AtomicMIMOHyperedgeV1
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("nonsource", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; account_effects=(source_effect,), registry=registry)
    particle_account = ConservationAccountRefV1("particles", U0, :output, 1, :minus)
    particle_effect = PortAccountEffectV1(particle_account, -1//1)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("cross-ledger", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive;
        account_effects=(source_effect, particle_effect), registry=registry)
    bad_units = PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    @test_throws ArgumentError TypedOperatorHypergraphV1((node(:output, bad_units), node(:input, scalar)), (source_edge,); registry=source_registry)
    bad_endpoint = ConservationAccountRefV1("energy", U0, :output, 99, :plus)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad-endpoint", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), source_program, source; account_effects=(PortAccountEffectV1(bad_endpoint, 1//1),), registry=source_registry)
    policy_manifest = OperatorManifestV1(source_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:source,), allowed_conservation_effects=(:redistribution,), forbidden_conservation_effects=(:net_creation,))
    policy_registry = OperatorRegistryV1((policy_manifest,))
    policy_program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(source_ref, (1,), (;); registry=policy_registry, input_types=(scalar,))), (2,), (1,); registry=policy_registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("policy", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), policy_program, source; account_effects=(source_effect,), registry=policy_registry)
    sink_manifest = OperatorManifestV1(source_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:sink,), allowed_conservation_effects=(:net_destruction,))
    sink_registry = OperatorRegistryV1((sink_manifest,))
    sink_program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(source_ref, (1,), (;); registry=sink_registry, input_types=(scalar,))), (2,), (1,); registry=sink_registry)
    sink_account = ConservationAccountRefV1("energy", U0, :output, 1, :minus)
    sink_effect = PortAccountEffectV1(sink_account, -1//1)
    sink_edge = AtomicMIMOHyperedgeV1("sink-ok", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), sink_program, sink; account_effects=(sink_effect,), registry=sink_registry)
    @test TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)), (sink_edge,); registry=sink_registry).hyperedges[1] isa AtomicMIMOHyperedgeV1
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("sink-wrong-sign", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), sink_program, sink; account_effects=(source_effect,), registry=sink_registry)
end

@testset "P0 MIMO authority dispatch and closed identity" begin
    project = Base.active_project()
    script = """
using FusionConceptAI
FusionConceptAI._canonical(::FusionConceptAI.PortAccountEffectV1) = "{}"
registry = default_operator_registry()
u = UnitSignature()
t = PhysicalType(:scalar_field, 0, 3, :differential, u)
r = OperatorRefV1("IDENTITY", "v1")
p = TypedASTProgramV1((ASTInputV1(1, t), ASTApplyV1(r, (1,), (;); registry=registry, input_types=(t,))), (2,), (1,); registry=registry)
e = AtomicMIMOHyperedgeV1("e", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), p, additive; registry=registry)
g = TypedOperatorHypergraphV1((node(:output, t), node(:input, t)), (e,))
    @assert canonical_hash(g) isa Digest256
    @assert canonical_hash(e) isa Digest256
    println("mimo-closed-identity-ok")
"""
    @test success(`$(Base.julia_cmd()) --project=$project -e $script`)
end

@testset "canonical identity/label and permutation invariance" begin
    a = fixture_graph(labels=("visible-a", "visible-b"), ids=("first", "second"))
    b = fixture_graph(labels=("redacted-a", "redacted-b"), ids=("other-1", "other-2"))
    @test canonical_hash(a) == canonical_hash(b)
    # Same directed relation after relabeling node order.
    ast = ast_leaf(:state, T0)
    c = TypedOperatorHypergraphV1([node(:state, T0; id="x"), node(:state, T0; id="y")], [TypedHyperedge("e", (2,), (1,), ast, :governing)])
    d = TypedOperatorHypergraphV1([node(:state, T0; id="y"), node(:state, T0; id="x")], [TypedHyperedge("e2", (1,), (2,), ast, :governing)])
    @test canonical_hash(c) == canonical_hash(d)
end

@testset "independent status dimensions and authority" begin
    @test StatusVectorV4(required, no_match, terminal_deferred, proposed, terminal_deferred_stage).match_status == no_match
    @test StatusVectorV4(required, no_match, terminal_deferred, proposed, terminal_deferred_stage).applicability == required
    @test_throws ArgumentError ApplicabilityRecord("obligation", not_applicable)
    @test_throws ArgumentError ApplicabilityRecord("", required)
    @test IntermediateAuthorityProtocolV4(:compiler) isa AuthorityProtocolV4
    @test !(:FinalWholeDeviceAuthorityV4 in names(FusionConceptAI, all=false))
    @test !(:AuthorityToken in names(FusionConceptAI, all=false))
    @test !(:TerminalDecisionV4 in names(FusionConceptAI, all=false))
end

@testset "typed Proposal/Evidence isolation and six hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", digest256_text("s" * string(i)), digest256_text("c" * string(i)), "profile") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    g = fixture_graph()
    m = MechanismGenomeV4(1, refs[1], g); f = FieldGeometryGenomeV4(2, refs[2], g); r = RealizationControlGenomeV4(3, 4, refs[3], g, g)
    p = ProposalEnvelopeV4("p", "candidate", (), :mcts, (), "cell", (;), (;), 1.0, digest256_text("model"), :compile)
    econtent = EvidenceContentV4(digest256_text("physical"), digest256_text("scenario"), digest256_text("solver"), digest256_text("provider"), "backend", digest256_text("numeric"), required, nothing, unique_match, resolved, unknown, (MetricWithUnit(:x, 1.0, U0),), nothing, (), "", screen_only)
    e = evidence_envelope(econtent)
    mission = MissionContractRef("urn:mission", "v4", digest256_text("schema"), digest256_text("canon"))
    pkg = CandidateStatePackageV4("display", mission, m, f, r, registry; proposal_lineage=(p,))
    @test length(pkg.canonical_hashes.solver_input_hashes) == 0
    @test pkg.proposal_lineage[1] isa ProposalEnvelopeV4
    @test isempty(pkg.stage_evidence_refs)
    @test canonical_hash(pkg) == canonical_hash(CandidateStatePackageV4("different-display", mission, m, f, r, registry; proposal_lineage=(p,)))
    @test_throws MethodError CandidateStatePackageV4("display", refs[1], m, f, r, registry; stage_evidence_refs=(p,))
    @test e isa EvidenceEnvelopeV4
    @test e.evidence_id == evidence_id_for(e.content)
end

@testset "conditional e-graph is P1-deferred" begin
    g = fixture_graph()
    eg = derive_conditional_egraph(g)
    @test eg.source_hash == canonical_hash(g)
    @test_throws ArgumentError derive_conditional_egraph(g, (; self_attested=true))
    @test !(:EquivalenceCertificateV1 in names(FusionConceptAI, all=false))
end

@testset "P0 negative controls and bounded large-graph canonicalization" begin
    @test occursin("\\u0001", canonical_json((control="\u0001",)))
    @test_throws ArgumentError canonical_json(InjectInteger())
    for value in (Float16(1.5), Float32(1.5), Float64(1.5), Float32(1.0e-6), Float64(1.0e20))
        encoded = canonical_json((value=value,))
        parsed = JSON3.read(encoded)
        @test parsed.value == Float64(value)
    end
    @test canonical_json((value=-0.0,)) == canonical_json((value=0.0,))
    @test JSON3.read(canonical_json((value=-0.0,))).value == 0
    @test_throws ArgumentError canonical_json((value=NaN,))
    @test_throws ArgumentError canonical_json((value=Inf,))
    malformed_utf8 = String(UInt8[0xff])
    lone_surrogate = string(Char(0xd800))
    @test_throws ArgumentError canonical_json((value=malformed_utf8,))
    @test_throws ArgumentError canonical_json((value=lone_surrogate,))
    unicode_json = canonical_json((汉字="磁约束", emoji="🚀", separator=string(Char(0x2028)), control="\u0001"))
    unicode_value = JSON3.read(unicode_json, Dict{String,Any})
    @test unicode_value["汉字"] == "磁约束"
    @test unicode_value["emoji"] == "🚀"
    @test unicode_value["separator"] == string(Char(0x2028))
    @test unicode_value["control"] == "\u0001"
    @test_throws ArgumentError canonical_json(Dict{Any,Any}(1 => :a, "1" => :b))
    matrix_json = canonical_json(reshape([1, 2, 3, 4], 2, 2))
    @test occursin("shape", matrix_json) && occursin("values", matrix_json)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:add, (1, 1), PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0))))), 2)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:identity, (1,), PhysicalType(:vector_field, 1, 3, :differential, U0))), 2)
    @test ast_leaf(:parameter, T0).input_ports == ()
    @test_throws ArgumentError TypedASTNode(:operator_hole, (), T0)
    state1 = TypedASTNode(:state, (), T0)
    state2 = TypedASTNode(:state, (), T0)
    @test_throws ArgumentError TypedAST((state1,), 1, (1, 1))
    @test_throws ArgumentError TypedAST((state1, state2), 1, (1,))
    @test_throws ArgumentError TypedAST((state1, state2), 1, (1, 2))
    @test_throws ArgumentError TypedAST((state1, state2, TypedASTNode(:identity, (1,), T0)), 3, (1, 2))
    @test_throws ArgumentError TypedAST((state1, TypedASTNode(:parameter, (), T0)), 1, (1,))
    @test_throws ArgumentError TypedAST((state1, TypedASTNode(:identity, (1,), T0)), 1, (1,))
    t1 = PhysicalType(:vector_field, 1, 3, :differential, U0)
    @test_throws ArgumentError TypedOperatorHypergraphV1((node(:state, t1), node(:state, T0)),
        (TypedHyperedge("bad-port", (1,), (2,), ast_leaf(:state, T0), :governing),))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:dt, (1,), T0)), 2, (1,))
    static3d = PhysicalType(:scalar_field, 0, 3, :static, U0)
    static_dt = PhysicalType(:scalar_field, 0, 3, :static, UnitSignature((0, 0, -1, 0, 0, 0, 0)))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), static3d), TypedASTNode(:dt, (1,), static_dt)), 2, (1,))
    t2 = PhysicalType(:scalar_field, 0, 2, :differential, U0)
    t3 = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), t2), TypedASTNode(:state, (), t3),
        TypedASTNode(:mul, (1, 2), t2)), 3, (1, 2))
    inv_length = UnitSignature((0, -1, 0, 0, 0, 0, 0))
    scalar3d = PhysicalType(:open_value, 0, 3, :differential, U0)
    vector3d = PhysicalType(:open_value, 1, 3, :differential, U0)
    gradient_bad = PhysicalType(:open_value, 1, 2, :static, inv_length)
    divergence_bad = PhysicalType(:open_value, 0, 2, :static, inv_length)
    curl_bad = PhysicalType(:open_value, 1, 2, :static, inv_length)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar3d), TypedASTNode(:gradient, (1,), gradient_bad)), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector3d), TypedASTNode(:divergence, (1,), divergence_bad)), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector3d), TypedASTNode(:curl, (1,), curl_bad)), 2, (1,))
    vector0d = PhysicalType(:open_value, 1, 0, :differential, U0)
    curl0d = PhysicalType(:open_value, 1, 0, :differential, inv_length)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector0d), TypedASTNode(:curl, (1,), curl0d)), 2, (1,))
    scalar0d = PhysicalType(:scalar_field, 0, 0, :differential, U0)
    gradient0d = PhysicalType(:vector_field, 1, 0, :differential, inv_length)
    divergence0d = PhysicalType(:scalar_field, 0, 0, :differential, inv_length)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar0d), TypedASTNode(:gradient, (1,), gradient0d)), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector0d), TypedASTNode(:divergence, (1,), divergence0d)), 2, (1,))
    scalar3d_field = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    vector3d_field = PhysicalType(:vector_field, 1, 3, :differential, U0)
    gradient_ok = PhysicalType(:vector_field, 1, 3, :differential, inv_length)
    divergence_ok = PhysicalType(:scalar_field, 0, 3, :differential, inv_length)
    curl_ok = PhysicalType(:vector_field, 1, 3, :differential, inv_length)
    @test TypedAST((TypedASTNode(:state, (), scalar3d_field), TypedASTNode(:gradient, (1,), gradient_ok)), 2, (1,)).root == 2
    @test TypedAST((TypedASTNode(:state, (), vector3d_field), TypedASTNode(:divergence, (1,), divergence_ok)), 2, (1,)).root == 2
    @test TypedAST((TypedASTNode(:state, (), vector3d_field), TypedASTNode(:curl, (1,), curl_ok)), 2, (1,)).root == 2
    refs = [GenomeContractRef("urn:test:" * string(i), "v4", digest256_text("s" * string(i)), digest256_text("c" * string(i)), "profile") for i in 1:3]
    g = fixture_graph(); r1 = RealizationControlGenomeV4(11, 12, refs[3], g, g; realization=(; basis=:a), control=(;))
    r2 = RealizationControlGenomeV4(11, 12, refs[3], g, g; realization=(; basis=:b), control=(;))
    @test realization_hash(r1) != realization_hash(r2)
    @test control_hash(r1) == control_hash(r2)
    @test coupled_realization_control_hash(r1) != coupled_realization_control_hash(r2)
    registry = GenomeContractRegistryV4(refs...)
    m = MechanismGenomeV4(1, refs[1], g); f = FieldGeometryGenomeV4(2, refs[2], g)
    foreign = GenomeContractRef("urn:foreign", "v4", digest256_text("foreign"), digest256_text("foreign-canon"), "profile")
    rf = RealizationControlGenomeV4(3, 4, foreign, g, g)
    mission = MissionContractRef("urn:mission", "v4", digest256_text("ms"), digest256_text("mc"))
    deferred = CandidateStatePackageV4("id", mission, m, f, rf, registry)
    @test deferred.resolution == terminal_deferred
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, rf, registry; lifecycle=compiled)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, rf, registry; applicability_records=(ApplicabilityRecord("obligation", required),))
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, rf, registry; claim_ceiling=screen_only)
    @test migrate_legacy((; old_status=:pass)).resolution == terminal_deferred
    @test migrate_legacy((; mission_contract_ref=:m, mechanism_genome_ref=:a, field_geometry_genome_ref=:b, realization_control_genome_ref=:c, status=:pass)).resolution == terminal_deferred
    p = ProposalEnvelopeV4("p", "c", (), :search, (), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError ProposalEnvelopeV4("p", "c", (), :search, (Any[1],), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError MechanismGenomeV4(1, refs[1], g; invariants=(Any[1],))
    @test_throws ArgumentError FieldGeometryGenomeV4(2, refs[2], g; fields=(Dict(:mutable => true),))
    @test_throws ArgumentError MechanismGenomeV4(UInt64(1), refs[1], g, (MutablePayload([1]),), ())
    @test_throws ArgumentError MechanismGenomeV4(UInt64(1), refs[1], g, (MutableNumber(1),), ())
    @test_throws ArgumentError MechanismGenomeV4(UInt64(1), refs[1], g, (MutableText("mutable"),), ())
    @test_throws ArgumentError RealizationControlGenomeV4(8, 8, refs[3], g, g)
    @test_throws ArgumentError MetricWithUnit(:huge, big(10)^10000, U0)
    @test_throws ArgumentError ProposalEnvelopeV4("huge", "c", (), :search, (), "cell", (;), (;), big(10)^10000, digest256_text("model"), :compile)
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=unique_match, resolution_status=resolved, stage_outcome=unknown, metrics_with_units=(p,))
    nodes9 = [node(Symbol("kind_", i), T0; id=string(i)) for i in 1:9]
    nodes16 = [node(Symbol("kind_", i), T0; id=string(i)) for i in 1:16]
    g9 = TypedOperatorHypergraphV1(nodes9, ()); g9p = TypedOperatorHypergraphV1(reverse(nodes9), ())
    g16 = TypedOperatorHypergraphV1(nodes16, ()); g16p = TypedOperatorHypergraphV1(reverse(nodes16), ())
    t = @elapsed begin
        @test canonical_hash(g9) == canonical_hash(g9p)
        @test canonical_hash(g16) == canonical_hash(g16p)
    end
    @test t < 5.0
    cyc_nodes = [node(:same, T0; id=string(i)) for i in 1:9]
    cyc_ast = ast_leaf(:state, T0)
    cyc_edges = [TypedHyperedge("cycle-" * string(i), (i,), (mod1(i + 1, 9),), cyc_ast, :additive) for i in 1:9]
    cyc = TypedOperatorHypergraphV1(cyc_nodes, cyc_edges)
    elapsed = @elapsed begin
        cyc_hash = canonical_hash(cyc)
        @test cyc_hash isa Digest256
        perm = collect(9:-1:1)
        inverse = Dict(old => new for (new, old) in enumerate(perm))
        perm_edges = [TypedHyperedge("renamed-" * string(i),
            (inverse[i],), (inverse[mod1(i + 1, 9)],), cyc_ast, :additive) for i in 1:9]
        @test cyc_hash == canonical_hash(TypedOperatorHypergraphV1(reverse(cyc_nodes), perm_edges))
    end
    @test elapsed < 2.0
    cycle32_nodes = [node(:same, T0; id=string(i)) for i in 1:32]
    cycle32_edges = [TypedHyperedge("cycle32-" * string(i), (i,), (mod1(i + 1, 32),), cyc_ast, :additive) for i in 1:32]
    cycle32 = TypedOperatorHypergraphV1(cycle32_nodes, cycle32_edges)
    cycle32_hash = nothing
    cycle32_elapsed = @elapsed (cycle32_hash = canonical_hash(cycle32))
    @test cycle32_hash isa Digest256
    @test cycle32_elapsed < 30.0
    cycle6 = TypedOperatorHypergraphV1(
        [node(:same, T0; id=string(i)) for i in 1:6],
        [TypedHyperedge("c6-" * string(i), (i,), (mod1(i + 1, 6),), cyc_ast, :additive) for i in 1:6])
    triangles = TypedOperatorHypergraphV1(
        [node(:same, T0; id=string(i)) for i in 1:6],
        vcat([TypedHyperedge("tri-" * string(i), (i,), (mod1(i + 1, 3),), cyc_ast, :additive) for i in 1:3],
             [TypedHyperedge("tri-" * string(i), (i,), (3 + mod1(i - 3 + 1, 3),), cyc_ast, :additive) for i in 4:6]))
    @test canonical_hash(cycle6) != canonical_hash(triangles)
    tiny_budget = CanonicalizationBudgetV1(1, 100, 512, 8_000_000)
    @test_throws CanonicalizationDeferred canonical_hash(cycle6, CanonicalizationProfileV1("tiny", "1", tiny_budget))
    @test_throws ArgumentError CanonicalizationBudgetV1(0, 100, 512, 8_000_000)
    @test_throws ArgumentError CanonicalizationBudgetV1(true, 100, 512, 8_000_000)
    profile_alt = CanonicalizationProfileV1("exact-incidence-alt", "1", default_canonicalization_profile().budget)
    @test canonical_hash(cycle6, profile_alt) != canonical_hash(cycle6)
    @test occursin("typed-incidence-graph", canonical_json(cycle6))
    @test JSON3.read(canonical_json(cycle6)) !== nothing
    golden_graph = TypedOperatorHypergraphV1([node(:same, T0; id="display")], ())
    golden = JSON3.read(read(joinpath(@__DIR__, "fixtures", "exact_incidence_golden.json"), String))
    @test canonical_json(golden_graph) == String(golden.canonical_json)
    @test canonical_hash(golden_graph).value == String(golden.sha256)
    fixed_pairs = ((3, 4), (4, 2), (3, 1), (4, 3))
    fixed_edges = [TypedHyperedge("fixed-" * string(i), (pair[1],), (pair[2],), cyc_ast, :additive)
                   for (i, pair) in enumerate(fixed_pairs)]
    fixed_graph = TypedOperatorHypergraphV1([node(:same, T0; id=string(i)) for i in 1:4], fixed_edges)
    node_permutation = (4, 3, 1, 2)
    inverse_node_permutation = Dict(old => new for (new, old) in enumerate(node_permutation))
    edge_permutation = (3, 2, 4, 1)
    fixed_permuted_edges = [begin
        pair = fixed_pairs[i]
        TypedHyperedge("permuted-" * string(i), (inverse_node_permutation[pair[1]],),
            (inverse_node_permutation[pair[2]],), cyc_ast, :additive)
    end for i in edge_permutation]
    fixed_permuted = TypedOperatorHypergraphV1(
        [node(:same, T0; id="permuted-" * string(i)) for i in node_permutation], fixed_permuted_edges)
    @test canonical_hash(fixed_graph) == canonical_hash(fixed_permuted)
    small_graph = TypedOperatorHypergraphV1([node(:same, T0; id="a"), node(:same, T0; id="b")],
        (TypedHyperedge("small", (1,), (2,), cyc_ast, :additive),))
    small_incidence = FusionConceptAI._incidence_graph(small_graph)
    @test length(small_incidence.kinds) == 5
    @test Set(small_incidence.kinds) == Set((:graph_node, :legacy_edge, :input_port, :output_port))
    @test JSON3.read(canonical_json(small_graph)) !== nothing
    # Independent test-only oracle: all 2! labelings and a closed encoder;
    # it intentionally does not call any production permutation/leaf helpers.
    function independent_quote(s)
        io = IOBuffer(); print(io, '"')
        for c in s
            c == '"' && (print(io, "\\\""); continue)
            c == '\\' && (print(io, "\\\\"); continue)
            c == '\n' && (print(io, "\\n"); continue)
            c == '\r' && (print(io, "\\r"); continue)
            c == '\t' && (print(io, "\\t"); continue)
            UInt32(c) < 0x20 && (print(io, "\\u", lpad(string(UInt32(c), base=16), 4, '0')); continue)
            print(io, c)
        end
        print(io, '"'); String(take!(io))
    end
    function independent_incidence_bytes(incidence, order)
        rank = zeros(Int, length(order))
        for (new, old) in enumerate(order)
            rank[old] = new
        end
        vertices = "[" * join(("{\"kind\":" * independent_quote(String(incidence.kinds[old])) *
            ",\"local_color\":" * independent_quote(incidence.local_colors[old]) * "}" for old in order), ",") * "]"
        arcs = sort([(rank[source], rank[target], label) for (source, target, label) in incidence.arcs])
        arc_text = "[" * join(("{\"label\":" * independent_quote(a[3]) * ",\"source\":" *
            string(a[1]) * ",\"target\":" * string(a[2]) * "}" for a in arcs), ",") * "]"
        "{\"canonicalization_version\":\"1\",\"domain\":\"fusionconceptai:v4:typed-incidence-graph:v1\",\"profile\":{\"profile_id\":\"exact-incidence\",\"version\":\"1\",\"vertices\":" * vertices * ",\"arcs\":" * arc_text * "}}"
    end
    independent_permutations(n) = begin
        result = Vector{Vector{Int}}()
        values = collect(1:n)
        function visit(position)
            position > n && (push!(result, copy(values)); return nothing)
            for j in position:n
                values[position], values[j] = values[j], values[position]
                visit(position + 1)
                values[position], values[j] = values[j], values[position]
            end
            nothing
        end
        visit(1); result
    end
    independent_oracle(incidence) = minimum(independent_incidence_bytes(incidence, order) for order in independent_permutations(length(incidence.kinds)))
    tiny_kinds = (:graph_node, :graph_node)
    tiny_colors = ("same", "same")
    tiny_arcs = ((1, 2, "link"), (2, 1, "link"))
    tiny_incidence = FusionConceptAI._IncidenceGraphV1(tiny_kinds, tiny_colors, tiny_arcs)
    tiny_initial_colors = invoke(FusionConceptAI._incidence_initial_colors, Tuple{Tuple}, tiny_colors)
    tiny_exact = FusionConceptAI._incidence_search(tiny_incidence, tiny_initial_colors,
        default_canonicalization_profile(), Ref(0), Ref(0))
    @test tiny_exact == independent_oracle(tiny_incidence)
    @test canonical_json(small_graph) == independent_oracle(small_incidence)
    scalar_incidence_type = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    atomic_registry = default_operator_registry()
    identity = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=atomic_registry, input_types=(scalar_incidence_type,))
    one_program = TypedASTProgramV1((ASTInputV1(1, scalar_incidence_type), identity), (2,), (1,); registry=atomic_registry)
    one_edge = AtomicMIMOHyperedgeV1("golden-one", (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 2),), one_program, governing; registry=atomic_registry)
    one_graph = TypedOperatorHypergraphV1((node(:input, scalar_incidence_type), node(:output, scalar_incidence_type)), (one_edge,))
    one_incidence = FusionConceptAI._incidence_graph(one_graph)
    @test length(one_incidence.kinds) == 5
    @test canonical_json(one_graph) == independent_oracle(one_incidence)
    add_one = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;);
        registry=atomic_registry, input_types=(scalar_incidence_type, scalar_incidence_type))
    ordered_program = TypedASTProgramV1((ASTInputV1(1, scalar_incidence_type), ASTInputV1(2, scalar_incidence_type), add_one),
        (3,), (1, 2); registry=atomic_registry)
    ordered_edge = AtomicMIMOHyperedgeV1("golden-ordered", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)),
        (MIMOOutputBindingV1(1, 3),), ordered_program, governing; registry=atomic_registry)
    ordered_graph = TypedOperatorHypergraphV1((node(:input, scalar_incidence_type), node(:input, scalar_incidence_type),
        node(:output, scalar_incidence_type)), (ordered_edge,))
    ordered_incidence = FusionConceptAI._incidence_graph(ordered_graph)
    @test length(ordered_incidence.kinds) == 7
    @test canonical_json(ordered_graph) == independent_oracle(ordered_incidence)
    random_state = Ref(UInt(0x5eed))
    draw_small = () -> begin
        random_state[] = random_state[] * UInt(1664525) + UInt(1013904223)
        Int(mod(random_state[], UInt(4))) + 1
    end
    for trial in 1:3
        random_pairs = vcat([(i, mod1(i + 1, 4)) for i in 1:4],
            [(draw_small(), draw_small()) for _ in 1:trial])
        random_edges = [TypedHyperedge("random-" * string(i), (pair[1],), (pair[2],), cyc_ast, :additive)
                        for (i, pair) in enumerate(random_pairs)]
        random_graph = TypedOperatorHypergraphV1([node(:same, T0; id=string(i)) for i in 1:4], random_edges)
        random_permutation = collect(1:4)
        for k in 4:-1:2
            j = mod1(draw_small(), k)
            random_permutation[k], random_permutation[j] = random_permutation[j], random_permutation[k]
        end
        random_inverse = Dict(old => new for (new, old) in enumerate(random_permutation))
        random_edges_permuted = [TypedHyperedge("random-permuted-" * string(i),
            (random_inverse[pair[1]],), (random_inverse[pair[2]],), cyc_ast, :additive)
            for (i, pair) in enumerate(random_pairs)]
        random_graph_permuted = TypedOperatorHypergraphV1(
            [node(:same, T0; id="random-permuted-" * string(i)) for i in random_permutation], random_edges_permuted)
        @test canonical_hash(random_graph) == canonical_hash(random_graph_permuted)
    end
    round_budget = CanonicalizationBudgetV1(100_000, 1, 512, 8_000_000)
    @test_throws CanonicalizationDeferred canonical_hash(cycle6, CanonicalizationProfileV1("round-limited", "1", round_budget))
    incidence_dispatch_script = """
    using FusionConceptAI
    t = PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((0,0,0,0,0,0,0)))
    ast = ast_leaf(:state, t)
    ns = [node(:same, t; id=string(i)) for i in 1:4]
    es = [TypedHyperedge(string(i), (src,), (dst,), ast, :additive)
          for (i, src, dst) in ((1,3,4),(2,4,2),(3,3,1),(4,4,3))]
    g = TypedOperatorHypergraphV1(ns, es)
    before = canonical_json(g)
    FusionConceptAI._incidence_add_arc!(::Vector{Tuple{Int,Int,String}}, ::Int, ::Int, ::String) = error("polluted arc")
    FusionConceptAI._IncidenceGraphV1(::NTuple{N,Symbol}, ::NTuple{M,String}, ::NTuple{K,Tuple{Int,Int,String}}) where {N,M,K} = error("polluted incidence constructor")
    FusionConceptAI._incidence_initial_colors(::NTuple{N,String}) where {N} = [99]
    FusionConceptAI._ast_program_canonical(::NamedTuple) = "{}"
    FusionConceptAI._incidence_signature_key(::Int, ::Tuple, ::Tuple) = "polluted-signature"
    FusionConceptAI._canonical(::NamedTuple) = "{}"
    @assert canonical_json(g) == before
    println("incidence-dispatch-closed-ok")
    """
    @test success(`$(Base.julia_cmd()) --project=$(Base.active_project()) -e $incidence_dispatch_script`)
    @test_throws ArgumentError EvidenceRef("not-a-hash")
    @test_throws ArgumentError EvidenceRef(repeat("a", 64) * "0")
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=no_match, resolution_status=resolved, stage_outcome=pass, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=no_match, resolution_status=resolved, stage_outcome=unknown, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=unique_match, resolution_status=resolved, stage_outcome=unknown, claim_ceiling=validation_vvuq, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws Exception CandidateStatePackageV4("id", mission, m, f, r1, CanonicalHashesV4("a", "b", "c", "d", nothing, ()), resolved, terminal_classified, (), (), (), (), (), "authority", none)
    @test_throws Exception CandidateStatePackageV4("id", mission, m, f, r1, CanonicalHashesV4("a", "b", "c", "d", nothing, ()), resolved, proposed, (), (), (), (), (), nothing, validation_vvuq)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry, terminal_classified, (), (), (), (), (), none)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry, proposed, (), (), (), (), (), validation_vvuq)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; applicability_records=(ApplicabilityRecord("", required),))
    opaque = OpaqueValue(1)
    @test_throws ArgumentError MechanismGenomeV4(1, refs[1], g; invariants=(opaque,))
    @test_throws ArgumentError ProposalEnvelopeV4("opaque", "c", (), :search, (opaque,), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError TypedASTNode(:state, (), T0, (opaque=opaque,))
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; lifecycle=compiled)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; lifecycle=dormant)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; lifecycle=proof_pruned)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; compilation_records=(; compiled=true,))
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; claim_ceiling=screen_only)
    @test_throws ArgumentError TypedNode(BAD_TEXT, :state, T0, "")
    @test_throws ArgumentError TypedHyperedge(BAD_TEXT, (1,), (2,), ast_leaf(:state, T0), :governing)
    @test_throws ArgumentError ProposalEnvelopeV4(BAD_TEXT, "c", (), :search, (), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError CandidateStatePackageV4(BAD_TEXT, mission, m, f, r1, registry)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; archive_memberships=(BAD_TEXT,))
    @test_throws ArgumentError LegacyMigrationResultV4(resolved, nothing, "forged")
    @test_throws ArgumentError FusionConceptAI.LegacyMigrationResultV4(resolved, nothing, "forged")
    h = digest256_text("evidence-negative")
    metric = (MetricWithUnit(:x, 1.0, U0),)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, BAD_TEXT, h, required, nothing, unique_match, resolved, unknown, metric, nothing, (), "", screen_only)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, no_match, terminal_deferred, unknown, metric, nothing, (), "", screen_only)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, unique_match, terminal_deferred, pass, metric, nothing, (), "", screen_only)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, nothing, unique_match, resolved, not_applicable_stage, metric, nothing, (), "", screen_only)
    @test_throws Exception EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, unique_match, resolved, unknown, (Any[1],), nothing, (), "", screen_only)
    @test_throws ArgumentError StatusVectorV4(required, no_match, resolved, proposed, unknown)
    @test_throws ArgumentError StatusVectorV4(required, no_match, terminal_deferred, proposed, unknown)
    @test_throws ArgumentError StatusVectorV4(required, no_match, terminal_deferred, proposed, physical_fail)
    @test_throws ArgumentError StatusVectorV4(required, unique_match, resolved, proposed, terminal_deferred_stage)
    @test StatusVectorV4(required, no_match, terminal_deferred, proposed, terminal_deferred_stage).resolution == terminal_deferred
    for outcome in (unknown, physical_fail, numerical_fail, pass)
        @test_throws ArgumentError StatusVectorV4(not_applicable, unique_match, resolved, proposed, outcome)
    end
    @test_throws ArgumentError StatusVectorV4(required, unique_match, resolved, proposed, not_applicable_stage)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, nothing, unique_match, resolved, unknown, metric, nothing, (), "", screen_only)
    na_record = ApplicabilityRecord("not-applicable-obligation", not_applicable, h)
    @test EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, na_record, unique_match, resolved, not_applicable_stage, metric, nothing, (), "", screen_only).applicability == not_applicable
    for outcome in (unknown, physical_fail, numerical_fail, pass)
        @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, na_record, unique_match, resolved, outcome, metric, nothing, (), "", screen_only)
    end
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, unique_match, resolved, not_applicable_stage, metric, nothing, (), "", screen_only)
    @test_throws MethodError StatusVectorV4()
    @test_throws MethodError DerivedEGraphViewV4(digest256_text("fake-source"), g)
end

@testset "G1 sealed mechanism gene primitives" begin
    refs = (
        StateGeneRefV1("state"), InvariantRefV1("invariant"), ParameterRefV1("parameter"),
        SymmetryRefV1("symmetry"), ObservableRefV1("observable"), OperatorSiteRefV1("operator"),
        ConstraintRefV1("constraint"), HoleRefV1("hole"))
    @test length(unique(string(getfield(x, :value)) for x in refs)) == 8
    @test all(x -> x.value isa String && isvalid(x.value), refs)
    @test_throws ArgumentError StateGeneRefV1("")
    @test_throws ArgumentError StateGeneRefV1(BAD_TEXT)
    @test_throws ArgumentError StateGeneRefV1(MutableText("mutable"))
    @test_throws ArgumentError InvariantRefV1(StateGeneRefV1("state"))
    @test_throws ArgumentError ParameterRefV1(1)

    closed = ExactFiniteIntervalV1(1 // 2, 3 // 2; allow_equal=true)
    strict = ExactFiniteIntervalV1(1, 2, false)
    @test closed.lower == 1 // 2 && closed.upper == 3 // 2 && closed.allow_equal
    @test strict.lower == 1 // 1 && !strict.allow_equal
    @test ExactFiniteIntervalV1(2, 2, true).lower == ExactFiniteIntervalV1(2, 2).upper
    @test_throws ArgumentError ExactFiniteIntervalV1(2, 2, false)
    @test_throws ArgumentError ExactFiniteIntervalV1(3, 2, true)
    @test_throws ArgumentError ExactFiniteIntervalV1(1.0, 2)
    @test_throws ArgumentError ExactFiniteIntervalV1(big(1) // big(2), 2)
    @test_throws ArgumentError ExactFiniteIntervalV1(true, 2)
    unit = UnitSignature()
    @test QuantityIntervalV1(closed, unit).interval == closed
    @test NonnegativeQuantityV1(0, unit).value == 0 // 1
    @test NonnegativeQuantityV1(3 // 2, unit).value == 3 // 2
    @test_throws ArgumentError NonnegativeQuantityV1(-1 // 2, unit)
    @test_throws ArgumentError NonnegativeQuantityV1(1.0, unit)
    @test_throws ArgumentError QuantityIntervalV1((closed,), unit)

    matrix = ExactRationalMatrixV1(((1 // 2, 0), (0, 1)))
    @test matrix.rows == ((1 // 2, 0 // 1), (0 // 1, 1 // 1))
    @test_throws ArgumentError ExactRationalMatrixV1(())
    @test_throws ArgumentError ExactRationalMatrixV1(((),))
    @test_throws ArgumentError ExactRationalMatrixV1(((1,), (1, 2)))
    @test_throws ArgumentError ExactRationalMatrixV1(((1.0,),))
    @test_throws ArgumentError ExactRationalMatrixV1(((MutablePayload([1]),),))
    @test_throws ArgumentError ExactRationalMatrixV1([[1]])

    @test state_derived isa StateEpistemicV1
    @test StateEpistemicV1(0) == state_derived
    @test state_not_applicable isa StateEpistemicV1
    @test scope_global isa InvariantScopeV1
    @test entropy_conserved isa EntropyDirectionV1
    @test transform_log isa ParameterTransformKindV1
    @test symmetry_equivariant isa SymmetryBehaviorV1
    @test net_creation isa ConservationEffectKindV1
    parity = ParityActionV1(QualifiedRefV1("generator", "v1"), odd)
    @test parity.sign == odd
    @test_throws ArgumentError ParityActionV1(QualifiedRefV1("generator", "v1"), :odd)
    @test canonical_json(matrix) isa String
    @test canonical_json(parity) isa String
end

@testset "G1 primitive domain-separated canonical identity" begin
    same_word_refs = (StateGeneRefV1("same"), InvariantRefV1("same"), ParameterRefV1("same"),
                      SymmetryRefV1("same"), ObservableRefV1("same"), OperatorSiteRefV1("same"),
                      ConstraintRefV1("same"), HoleRefV1("same"))
    @test length(unique(canonical_hash(x) for x in same_word_refs)) == 8
    @test all(occursin("fusionconceptai:v4:g1-primitive:v1", canonical_json(x)) for x in same_word_refs)
    interval_a = ExactFiniteIntervalV1(1 // 2, 2 // 1)
    interval_b = ExactFiniteIntervalV1(2 // 4, 4 // 2)
    @test canonical_hash(interval_a) == canonical_hash(interval_b)
    primitives = Any[same_word_refs..., interval_a, QuantityIntervalV1(interval_a, U0),
        NonnegativeQuantityV1(1 // 2, U0), ExactRationalMatrixV1(((1 // 2, 0), (0, 1))),
        ParityActionV1(QualifiedRefV1("generator", "v1"), odd), state_derived,
        state_not_applicable, entropy_not_applicable, scope_global, transform_linear,
        symmetry_discrete, symmetry_invariant, redistribution]
    @test all(begin
        text = canonical_json(value)
        parsed = JSON3.read(text)
        haskey(parsed, :domain) && haskey(parsed, :canonicalization_version) && haskey(parsed, :kind) && haskey(parsed, :payload)
    end for value in primitives)
    @test canonical_json(state_not_applicable) != canonical_json(entropy_not_applicable)
    @test canonical_hash(state_not_applicable) != canonical_hash(entropy_not_applicable)
    dispatch_script = """
    using FusionConceptAI
    values = Any[StateGeneRefV1(\"same\"), ExactFiniteIntervalV1(1//2, 2),
        QuantityIntervalV1(ExactFiniteIntervalV1(1//2, 2), UnitSignature()),
        NonnegativeQuantityV1(1//2, UnitSignature()),
        ExactRationalMatrixV1(((1//2, 0), (0, 1))),
        ParityActionV1(QualifiedRefV1(\"g\", \"v1\"), odd), state_not_applicable,
        entropy_not_applicable, scope_global, transform_linear, symmetry_discrete,
        symmetry_invariant, redistribution]
    before = (map(canonical_json, values), map(canonical_hash, values))
    FusionConceptAI._canonical(::NamedTuple) = \"{}\"
    FusionConceptAI._jsonquote(::String) = \"\\\"polluted\\\"\"
    FusionConceptAI._gene_text(::String, ::String) = error(\"polluted text helper\")
    FusionConceptAI._gene_rational(::Rational{Int64}, ::String) = error(\"polluted rational helper\")
    @assert before == (map(canonical_json, values), map(canonical_hash, values))
    println(\"g1-primitive-dispatch-closed-ok\")
    """
    @test success(`$(Base.julia_cmd()) --project=$(Base.active_project()) -e $dispatch_script`)
end

@testset "G1 state invariant parameter and symmetry genes" begin
    unit = UnitSignature()
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    state_ref = StateGeneRefV1("state-a")
    state = StateGeneV1(state_ref, T0, bounds, (), (), (), state_derived)
    @test state.state_ref == state_ref && state.physical_bounds.unit == T0.units
    @test_throws ArgumentError StateGeneV1(state_ref, T0,
        QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), UnitSignature((1, 0, 0, 0, 0, 0, 0))), (), (), (), state_derived)
    action = ParityActionV1(QualifiedRefV1("parity", "v1"), odd)
    @test StateGeneV1(state_ref, T0, bounds, (action,), (SymmetryRefV1("g"),), (ConstraintRefV1("c"),), state_measured).epistemic_state == state_measured
    @test_throws ArgumentError StateGeneV1(state_ref, T0, bounds, (action, action), (), (), state_derived)
    @test_throws ArgumentError StateGeneV1(state_ref, T0, bounds, (), (SymmetryRefV1("same"),), (ConstraintRefV1("same"),), state_derived)
    @test_throws ArgumentError StateGeneV1(state_ref, T0, bounds, [action], (), (), state_derived)

    term = InvariantTermV1(state_ref, 2 // 3)
    @test term.coefficient == 2 // 3
    @test_throws ArgumentError InvariantTermV1(state_ref, 0)
    @test_throws ArgumentError InvariantTermV1(state_ref, 1.0)
    invariant_ref = InvariantRefV1("energy-invariant")
    account = QualifiedRefV1("account", "v1")
    invariant = InvariantV1(invariant_ref, account, scope_global, nothing, (term,), (), (), (), -3, entropy_conserved)
    @test invariant.scope_ref === nothing && invariant.tolerance_log10 == -3
    @test InvariantV1(invariant_ref, account, scope_domain, QualifiedRefV1("domain", "v1"), (term,), (), (), (), 0, entropy_nondecreasing).scope == scope_domain
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, QualifiedRefV1("bad", "v1"), (term,), (), (), (), 0, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_interface, nothing, (term,), (), (), (), 0, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, nothing, (), (), (), (), 0, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, nothing, (term, term), (), (), (), 0, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, nothing, (term,), (OperatorSiteRefV1("x"),), (OperatorSiteRefV1("x"),), (), 0, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, nothing, (term,), (), (), (), 1, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, nothing, (term,), (), (), (), -32769, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, nothing, (term,), (), (), (), 0.0, entropy_conserved)
    @test_throws ArgumentError InvariantV1(invariant_ref, account, scope_global, nothing, (term,), (), (), (), 0, :conserved)

    linear = ParameterTransformSpecV1(transform_linear)
    logarithmic = ParameterTransformSpecV1(transform_log)
    scale = NonnegativeQuantityV1(1, unit)
    signed = ParameterTransformSpecV1(transform_signed_log, scale)
    @test linear.scale === nothing && logarithmic.scale === nothing && signed.scale == scale
    @test_throws ArgumentError ParameterTransformSpecV1(transform_linear, scale)
    @test_throws ArgumentError ParameterTransformSpecV1(transform_log, scale)
    @test_throws ArgumentError ParameterTransformSpecV1(transform_signed_log, NonnegativeQuantityV1(0, unit))
    parameter_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), unit)
    parameter = ParameterGeneV1(ParameterRefV1("linear"), unit, linear, parameter_bounds, -0.0)
    @test parameter.normalized_gene == 0.0
    @test isapprox(derive_parameter_value(parameter, -1), -2.0) && isapprox(derive_parameter_value(parameter, 0), 0.0) && isapprox(derive_parameter_value(parameter, 1), 2.0)
    positive_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(1, 100, false), unit)
    log_parameter = ParameterGeneV1(ParameterRefV1("log"), unit, logarithmic, positive_bounds, 0)
    @test isapprox(derive_parameter_value(log_parameter, -1), 1.0) && isapprox(derive_parameter_value(log_parameter, 1), 100.0)
    signed_parameter = ParameterGeneV1(ParameterRefV1("signed"), unit, signed, parameter_bounds, 0)
    @test isapprox(derive_parameter_value(signed_parameter, -1), -2.0) && isapprox(derive_parameter_value(signed_parameter, 0), 0.0) && isapprox(derive_parameter_value(signed_parameter, 1), 2.0)
    @test_throws ArgumentError ParameterGeneV1(ParameterRefV1("bad-log"), unit, logarithmic, parameter_bounds, 0)
    @test_throws ArgumentError ParameterGeneV1(ParameterRefV1("bad-bounds"), unit, linear, QuantityIntervalV1(ExactFiniteIntervalV1(1, 1, true), unit), 0)
    @test_throws ArgumentError ParameterGeneV1(ParameterRefV1("bad-unit"), UnitSignature((1, 0, 0, 0, 0, 0, 0)), linear, parameter_bounds, 0)
    @test_throws ArgumentError ParameterGeneV1(ParameterRefV1("bad-n"), unit, linear, parameter_bounds, NaN)
    @test_throws ArgumentError ParameterGeneV1(ParameterRefV1("bad-n"), unit, linear, parameter_bounds, 2)
    @test_throws ArgumentError derive_parameter_value(parameter, 2)

    identity_matrix = ExactRationalMatrixV1(((1, 0), (0, 1)))
    swap_matrix = ExactRationalMatrixV1(((0, 1), (1, 0)))
    state_action = StateSymmetryActionV1(state_ref, swap_matrix)
    discrete_symmetry = SymmetryGeneV1(SymmetryRefV1("swap"), symmetry_discrete, swap_matrix, (state_action,), 2, symmetry_invariant, 0)
    continuous_symmetry = SymmetryGeneV1(SymmetryRefV1("continuous"), symmetry_continuous, identity_matrix, (), nothing, symmetry_equivariant, 1 // 10)
    @test discrete_symmetry.group_order == UInt32(2) && continuous_symmetry.group_order === nothing
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_discrete, identity_matrix, (), 1, symmetry_invariant, 0)
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_discrete, identity_matrix, (), true, symmetry_invariant, 0)
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_discrete, ExactRationalMatrixV1(((1, 0, 0), (0, 1, 0))), (), 2, symmetry_invariant, 0)
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_discrete, identity_matrix, (StateSymmetryActionV1(state_ref, ExactRationalMatrixV1(((1,),))),), 2, symmetry_invariant, 0)
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_discrete, ExactRationalMatrixV1(((2, 0), (0, 2))), (), 2, symmetry_invariant, 0)
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_discrete, identity_matrix, (state_action, state_action), 2, symmetry_invariant, 0)
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_continuous, identity_matrix, (), 2, symmetry_invariant, 0)
    @test_throws ArgumentError SymmetryGeneV1(SymmetryRefV1("bad"), symmetry_continuous, identity_matrix, (), nothing, symmetry_invariant, -1 // 2)
    @test canonical_json(discrete_symmetry) != canonical_json(continuous_symmetry)
    @test occursin("fusionconceptai:v4:g1-primitive:v1", canonical_json(invariant))
    @test canonical_hash(invariant) == canonical_hash(InvariantV1(invariant_ref, account, scope_global, nothing, (term,), (), (), (), -3, entropy_conserved))
    gene_dispatch_script = """
    using FusionConceptAI
    u = UnitSignature(); sr = StateGeneRefV1(\"s\")
    before = InvariantTermV1(sr, 1//1)
    FusionConceptAI._g1_gene_rational(::Rational{Int64}, ::String) = error(\"polluted rational\")
    FusionConceptAI._g1_require_tuple_type(::Tuple, ::Type, ::String) = error(\"polluted tuple\")
    FusionConceptAI._g1_square_matrix(::ExactRationalMatrixV1, ::String) = error(\"polluted matrix\")
    @assert InvariantTermV1(sr, 1//1) == before
    @assert StateGeneV1(sr, PhysicalType(:scalar_field, 0, 3, :differential, u), QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), u), (), (), (), state_derived).state_ref == sr
    @assert SymmetryGeneV1(SymmetryRefV1(\"s\"), symmetry_continuous, ExactRationalMatrixV1(((1,),)), (), nothing, symmetry_invariant, 0).ref.value == \"s\"
    println(\"g1-gene-dispatch-closed-ok\")
    """
    @test success(`$(Base.julia_cmd()) --project=$(Base.active_project()) -e $gene_dispatch_script`)
end

@testset "G1 sealed gene hash and endpoint remediation" begin

@testset "G1 observables and typed operator holes" begin
    unit = UnitSignature()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, unit)
    vector = PhysicalType(:vector_field, 1, 3, :differential, unit)
    registry = default_operator_registry()
    identity = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=registry, input_types=(scalar,))
    sampling = TypedASTProgramV1((ASTInputV1(1, scalar), identity), (2,), (1,); registry=registry)
    root = ProgramRootRefV1(OperatorSiteRefV1("site"), 1, scalar)
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    floor = NonnegativeQuantityV1(1 // 10, unit)
    minimum = NonnegativeQuantityV1(1 // 2, unit)
    intervention = QualifiedRefV1("intervention", "v1")
    noise_model = QualifiedRefV1("noise", "v1")
    competitor = QualifiedRefV1("prediction", "v1")
    observable_ref = ObservableRefV1("observable")
    observable = ObservableGeneV1(observable_ref, root, intervention, sampling, interval,
        noise_model, floor, floor, minimum, (competitor,))
    @test observable.expression_root.declared_type == scalar
    @test length(observable.competing_prediction_refs) == 1
    @test JSON3.read(canonical_json(observable)).kind == "observable_gene"
    @test length(canonical_hash(observable).value) == 64
    @test_throws ArgumentError ProgramRootRefV1(OperatorSiteRefV1("site"), 0, scalar)
    @test_throws ArgumentError ProgramRootRefV1(OperatorSiteRefV1("site"), true, scalar)
    @test_throws ArgumentError ProgramRootRefV1("site", 1, scalar)
    bad_input = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=registry, input_types=(vector,))
    bad_sampling = TypedASTProgramV1((ASTInputV1(1, vector), bad_input), (2,), (1,); registry=registry)
    @test_throws ArgumentError ObservableGeneV1(observable_ref, root, intervention, bad_sampling,
        interval, noise_model, floor, floor, minimum, (competitor,))
    wrong_interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false),
        UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    @test_throws ArgumentError ObservableGeneV1(observable_ref, root, intervention, sampling,
        wrong_interval, noise_model, floor, floor, minimum, (competitor,))
    @test_throws ArgumentError ObservableGeneV1(observable_ref, root, intervention, sampling,
        interval, noise_model, floor, floor, NonnegativeQuantityV1(1 // 5, unit), (competitor,))
    @test_throws ArgumentError ObservableGeneV1(observable_ref, root, intervention, sampling,
        interval, noise_model, floor, floor, minimum, ())
    @test_throws ArgumentError ObservableGeneV1(observable_ref, root, intervention, sampling,
        interval, noise_model, floor, floor, minimum, (competitor, competitor))
    @test_throws ArgumentError ObservableGeneV1(observable_ref, root, intervention, sampling,
        interval, noise_model, floor, floor, NonnegativeQuantityV1(1 // 10, unit), (competitor,))

    budget = HoleComplexityBudgetV1(12, 2, 1, 0, 0, 1)
    @test JSON3.read(canonical_json(budget)).kind == "hole_complexity_budget"
    @test_throws ArgumentError HoleComplexityBudgetV1(13, 2, 1, 0, 0, 1)
    @test_throws ArgumentError HoleComplexityBudgetV1(12, 3, 1, 0, 0, 1)
    @test_throws ArgumentError HoleComplexityBudgetV1(12, 2, 2, 0, 0, 1)
    @test_throws ArgumentError HoleComplexityBudgetV1(true, 2, 1, 0, 0, 1)
    @test_throws ArgumentError HoleComplexityBudgetV1(big(1), 2, 1, 0, 0, 1)
    @test_throws ArgumentError HoleComplexityBudgetV1(12, 2, 1, 0, 0, 0)

    condition = IdentifiabilityConditionV1(intervention, observable_ref, minimum,
        NonnegativeQuantityV1(1 // 5, unit))
    @test JSON3.read(canonical_json(condition)).kind == "identifiability_condition"
    @test_throws ArgumentError IdentifiabilityConditionV1(intervention, observable_ref, minimum,
        NonnegativeQuantityV1(1, unit))
    @test_throws ArgumentError IdentifiabilityConditionV1(intervention, observable_ref, minimum,
        NonnegativeQuantityV1(1 // 5, UnitSignature((1, 0, 0, 0, 0, 0, 0))))

    state_a = StateGeneRefV1("state-a")
    state_b = StateGeneRefV1("state-b")
    alt_a = QualifiedRefV1("alternative-a", "v1")
    alt_b = QualifiedRefV1("alternative-b", "v1")
    oos_a = QualifiedRefV1("oos-a", "v1")
    oos_b = QualifiedRefV1("oos-b", "v1")
    hole = TypedOperatorHoleV1(HoleRefV1("hole"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a, alt_b), (condition,),
        (observable_ref,), (oos_a, oos_b))
    @test JSON3.read(canonical_json(hole)).kind == "typed_operator_hole"
    @test canonical_hash(hole) == canonical_hash(TypedOperatorHoleV1(HoleRefV1("hole"), (state_a,),
        (scalar,), QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_b, alt_a), (condition,),
        (observable_ref,), (oos_b, oos_a)))
    @test_throws ArgumentError TypedOperatorHoleV1(HoleRefV1("hole"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (redistribution,), budget,
        QualifiedRefV1("null", "v1"), (alt_a,), (condition,), (observable_ref,), (oos_a,))
    @test_throws ArgumentError TypedOperatorHoleV1(HoleRefV1("hole"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (QualifiedRefV1("null", "v1"),), (condition,),
        (observable_ref,), (oos_a,))
    @test_throws ArgumentError TypedOperatorHoleV1(HoleRefV1("hole"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a,), (), (observable_ref,), (oos_a,))
    @test_throws ArgumentError TypedOperatorHoleV1(HoleRefV1("hole"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a,), (condition,),
        (ObservableRefV1("other"),), (oos_a,))
    @test_throws ArgumentError TypedOperatorHoleV1(HoleRefV1("hole"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a,), (condition,), (observable_ref,), ())
    @test_throws Exception ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=registry, input_types=(hole,))
    @test_throws Exception OperatorManifestV1(OperatorRefV1("ALIEN", "v1"), 1, 1, hole, hole)

    two_input_hole = TypedOperatorHoleV1(HoleRefV1("hole-2"), (state_a, state_b), (scalar, vector),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a, alt_b), (condition,),
        (observable_ref,), (oos_a, oos_b))
    swapped_io = TypedOperatorHoleV1(HoleRefV1("hole-2"), (state_b, state_a), (vector, scalar),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a, alt_b), (condition,),
        (observable_ref,), (oos_a, oos_b))
    @test canonical_hash(two_input_hole) != canonical_hash(swapped_io)

    other_observable = ObservableRefV1("other-observable")
    other_condition = IdentifiabilityConditionV1(intervention, other_observable, minimum,
        NonnegativeQuantityV1(1 // 5, unit))
    mixed_conditions = TypedOperatorHoleV1(HoleRefV1("mixed-conditions"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a,), (condition, other_condition),
        (observable_ref, other_observable), (oos_a,))
    @test length(mixed_conditions.identifiability_conditions) == 2
    @test_throws ArgumentError TypedOperatorHoleV1(HoleRefV1("duplicate-condition"), (state_a,), (scalar,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a,), (condition, condition),
        (observable_ref,), (oos_a,))
    extreme_interval = QuantityIntervalV1(ExactFiniteIntervalV1(typemin(Int64), 0, false), unit)
    extreme_observable = ObservableGeneV1(ObservableRefV1("extreme"), root, intervention, sampling,
        extreme_interval, noise_model, NonnegativeQuantityV1(0, unit),
        NonnegativeQuantityV1(0, unit), NonnegativeQuantityV1(1, unit), (competitor,))
    @test extreme_observable.minimum_effect_size.value == 1

    before = (canonical_json(observable), canonical_hash(observable), canonical_json(hole), canonical_hash(hole))
    FusionConceptAI._g1_hole_sorted(::Tuple{QualifiedRefV1}, ::Function) = "polluted"
    FusionConceptAI._g1_unique_keys(::Tuple{QualifiedRefV1}, ::String, ::Function) = throw(ArgumentError("polluted"))
    FusionConceptAI._g1_unique_local_refs(::Tuple{StateGeneRefV1,StateGeneRefV1}, ::String) = nothing
    @test_throws ArgumentError TypedOperatorHoleV1(HoleRefV1("polluted-inputs"), (state_a, state_a), (scalar, scalar),
        QualifiedRefV1("causal", "v1"), (redistribution,), (net_creation,), budget,
        QualifiedRefV1("null", "v1"), (alt_a, alt_b), (condition,),
        (observable_ref,), (oos_a, oos_b))
    @test before == (canonical_json(observable), canonical_hash(observable), canonical_json(hole), canonical_hash(hole))
end

@testset "G1 mechanism payload typed hypergraph closure" begin
    unit = UnitSignature()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, unit)
    registry = default_operator_registry()
    function identity_program()
        apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(scalar,))
        TypedASTProgramV1((ASTInputV1(1, scalar), apply), (2,), (1,); registry=registry)
    end
    program_a, program_b = identity_program(), identity_program()
    account_in = PortAccountEffectV1(ConservationAccountRefV1("account", unit, :input, 1, :inflow), 1 // 1)
    account_out = PortAccountEffectV1(ConservationAccountRefV1("account", unit, :output, 1, :outflow), -1 // 1)
    edge_a = AtomicMIMOHyperedgeV1("site-a", (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 1),), program_a, governing;
        account_effects=(account_in, account_out), registry=registry)
    edge_b = AtomicMIMOHyperedgeV1("site-b", (MIMOInputBindingV1(1, 2),),
        (MIMOOutputBindingV1(1, 2),), program_b, governing; registry=registry)
    graph = TypedOperatorHypergraphV1((node(:state, scalar; id="state-a"),
        node(:state, scalar; id="state-b")), (edge_a, edge_b); registry=registry)
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    state_a = StateGeneV1(StateGeneRefV1("state-a"), scalar, bounds, (), (), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1("state-b"), scalar, bounds, (), (), (), state_derived)
    sample = identity_program()
    observable = ObservableGeneV1(ObservableRefV1("obs"),
        ProgramRootRefV1(OperatorSiteRefV1("site-a"), 1, scalar),
        QualifiedRefV1("intervention", "v1"), sample, bounds,
        QualifiedRefV1("noise", "v1"), NonnegativeQuantityV1(1 // 10, unit),
        NonnegativeQuantityV1(1 // 10, unit), NonnegativeQuantityV1(1 // 2, unit),
        (QualifiedRefV1("prediction", "v1"),))
    invariant = InvariantV1(InvariantRefV1("invariant"), QualifiedRefV1("account", "v1"),
        scope_global, nothing, (InvariantTermV1(StateGeneRefV1("state-a"), 1),), (), (), (), 0,
        entropy_conserved)
    symmetry_matrix = ExactRationalMatrixV1(((1,),))
    symmetry = SymmetryGeneV1(SymmetryRefV1("symmetry"), symmetry_continuous, symmetry_matrix,
        (StateSymmetryActionV1(StateGeneRefV1("state-a"), symmetry_matrix),), nothing,
        symmetry_invariant, 0)
    payload = MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (symmetry,),
        (observable,), ())
    @test payload.operator_graph === graph
    @test length(payload.states) == 2
    @test JSON3.read(canonical_json(payload)).kind == "mechanism_genome_payload"
    @test canonical_hash(payload) isa Digest256
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (invariant,),
        TypedOperatorHypergraphV1((node(:state, scalar; id="state-a"),),
            (TypedHyperedge("legacy", (), (1,),
                TypedAST((TypedASTNode(:state, (), scalar),), 1; registry=registry), :governing),)),
        (), (symmetry,), (observable,), ())
    bad_gauge = StateGeneV1(StateGeneRefV1("state-a"), scalar, bounds, (),
        (SymmetryRefV1("missing-gauge"),), (), state_derived)
    @test_throws ArgumentError MechanismGenomePayloadV1((bad_gauge, state_b), (invariant,), graph,
        (), (symmetry,), (observable,), ())
    bad_account = InvariantV1(InvariantRefV1("bad-account"), QualifiedRefV1("missing-account", "v1"),
        scope_global, nothing, (InvariantTermV1(StateGeneRefV1("state-a"), 1),), (), (), (), 0,
        entropy_conserved)
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (bad_account,), graph,
        (), (symmetry,), (observable,), ())
    bad_scope = InvariantV1(InvariantRefV1("bad-scope"), QualifiedRefV1("account", "v1"),
        scope_domain, QualifiedRefV1("missing-scope", "v1"),
        (InvariantTermV1(StateGeneRefV1("state-a"), 1),), (), (), (), 0, entropy_conserved)
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (bad_scope,), graph,
        (), (symmetry,), (observable,), ())
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a,), (invariant,), graph, (), (symmetry,), (observable,), ())
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (), graph, (), (symmetry,), (observable,), ())
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, StateGeneV1(StateGeneRefV1("wrong"), scalar, bounds, (), (), (), state_derived)),
        (invariant,), graph, (), (symmetry,), (observable,), ())
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (invariant,),
        TypedOperatorHypergraphV1((node(:state, scalar; id="state-a"), node(:state, scalar; id="state-b")),
            (AtomicMIMOHyperedgeV1("", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 1),),
                program_a, governing; registry=registry), edge_b); registry=registry),
        (), (symmetry,), (observable,), ())
    bad_root = ObservableGeneV1(ObservableRefV1("bad"),
        ProgramRootRefV1(OperatorSiteRefV1("missing-site"), 1, scalar),
        QualifiedRefV1("intervention", "v1"), sample, bounds,
        QualifiedRefV1("noise", "v1"), NonnegativeQuantityV1(1 // 10, unit),
        NonnegativeQuantityV1(1 // 10, unit), NonnegativeQuantityV1(1 // 2, unit),
        (QualifiedRefV1("prediction", "v1"),))
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (symmetry,), (bad_root,), ())
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph,
        (ParameterGeneV1(ParameterRefV1("dangling"), unit, ParameterTransformSpecV1(transform_linear), bounds, 0),),
        (symmetry,), (observable,), ())
    @test MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (), (observable,), ()).symmetries == ()
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (symmetry,), (), ())
    @test MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (symmetry,), (observable,), ()).symmetries == (symmetry,)
    extra_rule = SameTypeVariadicRuleV1(1, 1)
    extra_manifest = OperatorManifestV1(OperatorRefV1("EXTRA", "v1"), 1, 1,
        extra_rule, extra_rule; allowed_roles=(:governing,), allowed_conservation_effects=(:redistribution,))
    extra_registry = register_operator(registry, extra_manifest)
    extra_program = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=extra_registry, input_types=(scalar,))
    extra_program = TypedASTProgramV1((ASTInputV1(1, scalar), extra_program), (2,), (1,);
        registry=extra_registry)
    extra_edge = AtomicMIMOHyperedgeV1("site-b-extra", (MIMOInputBindingV1(1, 2),),
        (MIMOOutputBindingV1(1, 2),), extra_program, governing; registry=extra_registry)
    mixed_registry_graph = TypedOperatorHypergraphV1((node(:state, scalar; id="state-a"),
        node(:state, scalar; id="state-b")), (edge_a, extra_edge))
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (invariant,),
        mixed_registry_graph, (), (symmetry,), (observable,), ())
    bad_constraint = AtomicMIMOHyperedgeV1("constraint-wrong-owner",
        (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), program_a, constraint;
        registry=registry)
    wrong_owner_graph = TypedOperatorHypergraphV1((node(:state, scalar; id="state-a"),
        node(:state, scalar; id="state-b")), (edge_a, edge_b, bad_constraint))
    state_with_wrong_constraint = StateGeneV1(StateGeneRefV1("state-a"), scalar, bounds, (), (),
        (ConstraintRefV1("constraint-wrong-owner"),), state_derived)
    @test_throws ArgumentError MechanismGenomePayloadV1((state_with_wrong_constraint, state_b),
        (invariant,), wrong_owner_graph, (), (symmetry,), (observable,), ())
    parameter_unit = UnitSignature()
    parameter_gene = ParameterGeneV1(ParameterRefV1("p"), parameter_unit,
        ParameterTransformSpecV1(transform_linear), bounds, 0)
    parameter_type = PhysicalType(:scalar_parameter, 0, 0, TemporalTypeV1(static_time), parameter_unit)
    parameter_program = TypedASTProgramV1((ASTParameterV1(:p, parameter_type),), (1,), (); registry=registry)
    @test FusionConceptAI._g1_payload_validate_parameters((parameter_gene,), [parameter_program]) === nothing
    wrong_parameter_types = (PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), parameter_unit),
        PhysicalType(:scalar_parameter, 1, 0, TemporalTypeV1(static_time), parameter_unit),
        PhysicalType(:scalar_parameter, 0, 1, TemporalTypeV1(static_time), parameter_unit),
        PhysicalType(:scalar_parameter, 0, 0, TemporalTypeV1(differential_time), parameter_unit),
        PhysicalType(:scalar_parameter, 0, 0, TemporalTypeV1(static_time), UnitSignature((1,0,0,0,0,0,0))))
    for wrong_type in wrong_parameter_types
        wrong_program = TypedASTProgramV1((ASTParameterV1(:p, wrong_type),), (1,), (); registry=registry)
        @test_throws ArgumentError FusionConceptAI._g1_payload_validate_parameters((parameter_gene,), [wrong_program])
    end
    control_type = PhysicalType(:control_signal, 0, 3, TemporalTypeV1(static_time), unit)
    event_manifest = OperatorManifestV1(OperatorRefV1("CUSTOM_EVENT", "v1"), 2, 1,
        EventTransitionRuleV1(:threshold_switch), EventTransitionRuleV1(:threshold_switch);
        allowed_roles=(:event,), pure=false, event=true)
    event_registry = register_operator(registry, event_manifest)
    event_program() = begin
        event_apply = ASTApplyV1(OperatorRefV1("CUSTOM_EVENT", "v1"), (1, 2), (;);
            registry=event_registry, input_types=(control_type, scalar))
        TypedASTProgramV1((ASTInputV1(1, control_type), ASTInputV1(2, scalar), event_apply),
            (3,), (1, 2); registry=event_registry)
    end
    event_edges = Tuple(AtomicMIMOHyperedgeV1("event-$(i)",
        (MIMOInputBindingV1(1, 2 + i), MIMOInputBindingV1(2, 1)),
        (MIMOOutputBindingV1(1, 1),), event_program(), event; registry=event_registry) for i in 1:3)
    event_governing_a = AtomicMIMOHyperedgeV1("event-governing-a",
        (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 1),), program_a, governing;
        account_effects=(account_in, account_out), registry=event_registry)
    event_governing_b = AtomicMIMOHyperedgeV1("event-governing-b",
        (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 2),), program_b, governing;
        registry=event_registry)
    event_graph = TypedOperatorHypergraphV1((node(:state, scalar; id="state-a"),
        node(:state, scalar; id="state-b"), node(:control, control_type; id="control-1"),
        node(:control, control_type; id="control-2"), node(:control, control_type; id="control-3")),
        (event_governing_a, event_governing_b, event_edges...))
    @test_throws ArgumentError MechanismGenomePayloadV1((state_a, state_b), (invariant,), event_graph,
        (), (symmetry,), (observable,), ())
    hold_rule = SamplingRuleV1(true)
    hold_manifest = OperatorManifestV1(OperatorRefV1("CUSTOM_HOLD", "v1"), 1, 1,
        hold_rule, hold_rule; allowed_roles=(:governing,),
        parameter_schema=(OperatorParameterSpecV1(:target_kind, :symbol, true),),
        pure=true, stateful=false)
    hold_registry = register_operator(registry, hold_manifest)
    discrete_type = PhysicalType(:scalar_field, 0, 3,
        TemporalTypeV1(discrete_time, 0, QualifiedRefV1("clock", "v1")), unit)
    hold_apply = ASTApplyV1(OperatorRefV1("CUSTOM_HOLD", "v1"), (1,),
        (target_kind=:static_time,); registry=hold_registry, input_types=(discrete_type,))
    hold_program = TypedASTProgramV1((ASTInputV1(1, discrete_type), hold_apply), (2,), (1,);
        registry=hold_registry)
    @test FusionConceptAI._g1_payload_program_metrics(hold_program, hold_registry)[4] == 0
    authority_script = """
    using FusionConceptAI
    u = UnitSignature(); t = PhysicalType(:scalar_field, 0, 3, :differential, u)
    r = default_operator_registry()
    a = ASTApplyV1(OperatorRefV1(\"IDENTITY\", \"v1\"), (1,), (;); registry=r, input_types=(t,))
    p = TypedASTProgramV1((ASTInputV1(1, t), a), (2,), (1,); registry=r)
    e = AtomicMIMOHyperedgeV1(\"e\", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 1),), p, governing; registry=r)
    g = TypedOperatorHypergraphV1((node(:state, t; id=\"s\"),), (e,))
    @eval FusionConceptAI _g1_payload_edge_role(::AtomicMIMOHyperedgeV1) = event
    FusionConceptAI._g1_payload_validate_governing(g)
    """
    @test success(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $authority_script`)
end
    unit = UnitSignature()
    interval = ExactFiniteIntervalV1(-7 // 3, 11 // 5, false)
    quantity_bounds = QuantityIntervalV1(interval, unit)
    transform = ParameterTransformSpecV1(transform_linear)
    parameter = ParameterGeneV1(ParameterRefV1("endpoint"), unit, transform, quantity_bounds, 0)
    expected_hash = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(canonical_json(transform))))))
    @test canonical_hash(transform) == expected_hash
    matrix = ExactRationalMatrixV1(((0, 1), (1, 0)))
    action = StateSymmetryActionV1(StateGeneRefV1("s"), matrix)
    expected_action_hash = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(canonical_json(action))))))
    @test canonical_hash(action) == expected_action_hash
    @test parameter_value(parameter, -1) == Float64(-7 // 3)
    @test parameter_value(parameter, 1) == Float64(11 // 5)
    log_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(7 // 5, 11 // 5, false), unit)
    log_parameter = ParameterGeneV1(ParameterRefV1("log-endpoint"), unit, ParameterTransformSpecV1(transform_log), log_bounds, 0)
    @test parameter_value(log_parameter, -1) == Float64(7 // 5)
    @test parameter_value(log_parameter, 1) == Float64(11 // 5)
    signed_parameter = ParameterGeneV1(ParameterRefV1("signed-endpoint"), unit,
        ParameterTransformSpecV1(transform_signed_log, NonnegativeQuantityV1(1, unit)), quantity_bounds, 0)
    @test parameter_value(signed_parameter, -1) == Float64(-7 // 3)
    @test parameter_value(signed_parameter, 1) == Float64(11 // 5)
    p1 = ParityActionV1(QualifiedRefV1("a\0b", "c"), even)
    p2 = ParityActionV1(QualifiedRefV1("a", "b\0c"), odd)
    @test StateGeneV1(StateGeneRefV1("nul"), T0, QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit), (p1, p2), (), (), state_derived).state_ref.value == "nul"
    @test_throws ArgumentError StateGeneV1(StateGeneRefV1("nul"), T0, QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit), (p1, p1), (), (), state_derived)
    gauge_a, gauge_b = SymmetryRefV1("a"), SymmetryRefV1("b")
    state_a = StateGeneV1(StateGeneRefV1("set"), T0, QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit), (), (gauge_a, gauge_b), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1("set"), T0, QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit), (), (gauge_b, gauge_a), (), state_derived)
    @test canonical_hash(state_a) == canonical_hash(state_b)
    term_a, term_b = InvariantTermV1(StateGeneRefV1("a"), 1), InvariantTermV1(StateGeneRefV1("b"), 2)
    inv_a = InvariantV1(InvariantRefV1("i"), QualifiedRefV1("account", "v1"), scope_global, nothing, (term_a, term_b), (), (), (), 0, entropy_conserved)
    inv_b = InvariantV1(InvariantRefV1("i"), QualifiedRefV1("account", "v1"), scope_global, nothing, (term_b, term_a), (), (), (), 0, entropy_conserved)
    @test canonical_hash(inv_a) == canonical_hash(inv_b)
    parameter_dispatch_script = """
    using FusionConceptAI
    u = UnitSignature(); t = PhysicalType(:scalar_field, 0, 3, :differential, u)
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-7//3, 11//5, false), u)
    gene = ParameterGeneV1(ParameterRefV1(\"p\"), u, ParameterTransformSpecV1(transform_linear), bounds, 0)
    parity = ParityActionV1(QualifiedRefV1(\"parity\", \"v1\"), odd)
    state = StateGeneV1(StateGeneRefV1(\"state\"), t, bounds, (parity,), (SymmetryRefV1(\"g2\"), SymmetryRefV1(\"g1\")), (), state_derived)
    term = InvariantTermV1(StateGeneRefV1(\"state\"), 1)
    invariant = InvariantV1(InvariantRefV1(\"inv\"), QualifiedRefV1(\"account\", \"v1\"), scope_global, nothing, (term,), (), (), (), 0, entropy_conserved)
    matrix = ExactRationalMatrixV1(((1,),))
    symmetry = SymmetryGeneV1(SymmetryRefV1(\"sym\"), symmetry_continuous, matrix, (StateSymmetryActionV1(StateGeneRefV1(\"state\"), matrix),), nothing, symmetry_invariant, 0)
    before = parameter_value(gene, -1.0)
    before_objects = (map(canonical_json, (state, invariant, symmetry)), map(canonical_hash, (state, invariant, symmetry)))
    FusionConceptAI.derive_parameter_value(::ParameterGeneV1, ::Float64) = 999.0
    FusionConceptAI._g1_gene_sorted_payload(::Tuple, ::Function) = \"polluted\"
    @assert parameter_value(gene, -1.0) == before
    @assert parameter_value(gene, 1.0) == Float64(11//5)
    @assert before_objects == (map(canonical_json, (state, invariant, symmetry)), map(canonical_hash, (state, invariant, symmetry)))
    println(\"g1-parameter-dispatch-closed-ok\")
    """
    @test success(`$(Base.julia_cmd()) --project=$(Base.active_project()) -e $parameter_dispatch_script`)
end
