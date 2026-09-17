using JSON3
using Serialization
using FusionConceptAI

const G = FusionConceptAI
const _OBS_RESULT_PATH = normpath(ARGS[1])
const _H0A_SOURCE = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "src", "GenomeV5", "UP2", "N06DimensionedLedgerLawV1.jl"))
const _LAYER_FIXTURE = normpath(joinpath(@__DIR__, "..", "..", "..", "..", "test", "GenomeV5", "UP1-04", "layer_fixture_child.jl"))

# Match the production runner's loader and source include before constructing
# the actual-A package.  This does not include the N06 test file, so no N06
# @testset is executed as a side effect.
G.load_genome_v5_up2_components!()
Base.include(G, _H0A_SOURCE)

function _obs_child_fixture(layer::String)
    output = tempname()
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $(_LAYER_FIXTURE) $layer $output`)
    value = open(output, "r") do io
        Serialization.deserialize(io)
    end
    rm(output; force=true)
    value
end

function _obs_actual_g1(base, candidate)
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

function _obs_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _obs_actual_g3(base, candidate, g1_ref, g2_ref)
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

function _obs_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/h0a-actual-observation-r1", "v5")
    g1 = _obs_actual_g1(_obs_child_fixture("G1"), candidate)
    g2 = _obs_actual_g2(_obs_child_fixture("G2"), candidate)
    base_g3 = _obs_child_fixture("G3")
    g3 = _obs_actual_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

package = _obs_actual_package()
e0 = G.up2_candidate_physical_binding_from_a(package)
result = G.n06_h0a_bind_actual_a(package, e0)

function _obs_type(x)
    x === nothing ? nothing : string(typeof(x))
end
function _obs_text_tuple(x)
    [string(v) for v in x]
end
function _obs_digest(x)
    x === nothing ? nothing : string(x)
end

payload = Dict{String,Any}(
    "observation" => "H0A_ACTUAL_A_BIND_R1",
    "loader" => "load_genome_v5_up2_components!",
    "source_include" => _H0A_SOURCE,
    "fixture_path" => _LAYER_FIXTURE,
    "status" => string(result.status),
    "errors" => _obs_text_tuple(result.errors),
    "gaps" => _obs_text_tuple(result.gaps),
    "declaration_type" => _obs_type(result.declaration),
    "declaration_is_nothing" => result.declaration === nothing,
    "declaration_gap_code" => result.declaration === nothing ? nothing : string(result.declaration.gap_code),
    "declaration_reason" => result.declaration === nothing ? nothing : string(result.declaration.reason),
    "compile_calls" => result.compile_calls,
    "provider_calls" => result.provider_calls,
    "solver_calls" => result.solver_calls,
    "candidate_ref" => string(package.candidate_ref),
    "candidate_hash" => _obs_digest(package.candidate_hash),
    "e0_package_hash" => _obs_digest(e0.package_hash),
    "e0_bound_input_hash" => _obs_digest(e0.bound_input_hash),
    "e0_candidate_ref" => string(e0.candidate_ref),
    "package_type" => string(typeof(package)),
    "e0_type" => string(typeof(e0)),
    "child_fixture_is_test_oracle" => true,
    "child_fixture_note" => "layer_fixture_child.jl serializes the existing G1/G2/G3 test fixtures; N06 test file and its assertions were not included"
)

open(_OBS_RESULT_PATH, "w") do io
    JSON3.write(io, payload)
end

println("OBSERVATION=H0A_ACTUAL_A_BIND_R1")
println("status=", result.status)
println("errors=", repr(result.errors))
println("gaps=", repr(result.gaps))
println("declaration_type=", typeof(result.declaration))
println("declaration_is_nothing=", result.declaration === nothing)
println("compile_calls=", result.compile_calls)
println("provider_calls=", result.provider_calls)
println("solver_calls=", result.solver_calls)
println("candidate_hash=", package.candidate_hash)
println("e0_bound_input_hash=", e0.bound_input_hash)
