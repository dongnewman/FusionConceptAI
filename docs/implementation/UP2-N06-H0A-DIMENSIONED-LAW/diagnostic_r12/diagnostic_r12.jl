using Serialization
using FusionConceptAI

const G = FusionConceptAI
_h0a_digest(ch) = G.digest256_text(String(ch))

function _diag_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "..", "..", "..", "test", "GenomeV5", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _diag_actual_g1(base, candidate)
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

function _diag_actual_g2(base, candidate)
    uri = replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/")
    ref = G.GenomeContractRef(uri, "v5", base.contract_ref.schema_hash,
        base.contract_ref.canonicalization_hash, base.contract_ref.compatibility_profile)
    G.FieldGeometryGenomeV5(ref, base.region_interface, base.plan,
        base.grammar_profile, base.version_axes)
end

function _diag_actual_g3(base, candidate, g1_ref, g2_ref)
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

function _diag_actual_package()
    candidate = G.QualifiedRefV1("fusionconceptai://candidate/h0a-actual", "v5")
    g1 = _diag_actual_g1(_diag_child_fixture("G1"), candidate)
    g2 = _diag_actual_g2(_diag_child_fixture("G2"), candidate)
    base_g3 = _diag_child_fixture("G3")
    g3 = _diag_actual_g3(base_g3, candidate, g1.contract_ref, g2.contract_ref)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

package = _diag_actual_package()
e0 = G.up2_candidate_physical_binding_from_a(package)
result = G.n06_h0a_bind_actual_a(package, e0)
println("DIAGNOSTIC=H0A_ACTUAL_A_BIND_R12")
println("status=", result.status)
println("errors=", repr(result.errors))
println("gaps=", repr(result.gaps))
println("declaration_type=", typeof(result.declaration))
println("declaration_is_nothing=", result.declaration === nothing)
println("compile_calls=", result.compile_calls)
println("provider_calls=", result.provider_calls)
println("solver_calls=", result.solver_calls)
