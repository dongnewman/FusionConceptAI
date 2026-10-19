using Test
using Serialization

include(joinpath(@__DIR__, "VNextT2ConcreteSourceWitnessV3",
    "fixture_helpers.jl"))

function _up1_g3_bridge_replace_ascii(value, original::AbstractString,
        replacement::AbstractString)
    ncodeunits(original) == ncodeunits(replacement) ||
        error(:serialization_replacement_length_mismatch)
    io = IOBuffer()
    Serialization.serialize(io, value)
    bytes = take!(io)
    needle = Vector{UInt8}(codeunits(original))
    changed = Vector{UInt8}(codeunits(replacement))
    hits = Int[]
    last = length(bytes) - length(needle) + 1
    for index in 1:max(last, 0)
        @views bytes[index:index + length(needle) - 1] == needle &&
            push!(hits, index)
    end
    length(hits) == 1 || error((:serialization_replacement_hit_count,
        original, length(hits)))
    copyto!(bytes, only(hits), changed, 1, length(changed))
    Serialization.deserialize(IOBuffer(bytes))
end

@testset "UP1 local G3 authority bridge adapter" begin
    chain = v3_chain()
    initial_links = chain.bridge.binding_state.source_payload.initial_links
    local_authority = V3_G.vnext_g3_binding_authority_bridge_local_v1(
        chain.recheck, chain.expected, chain.realization_state,
        chain.control_state, chain.binding_key; initial_links=initial_links)
    @test local_authority isa V3_G.VNextG3BindingAuthorityBridgeLocalResultV1
    @test local_authority.status === :local_checked_present

    adapted_bridge = V3_G.vnext_concrete_source_witness_g3_bridge_v1(
        chain.recheck, chain.expected, local_authority,
        chain.realization_state, chain.control_payload, chain.control_state,
        chain.binding_key; initial_links=initial_links)
    @test adapted_bridge.status === :local_checked_present
    @test adapted_bridge.projection.candidate_ref == chain.transport.candidate_ref
    @test adapted_bridge.projection.parent_g3_declaration_ref ==
        chain.recheck.output.g3.declaration_ref
    @test adapted_bridge.projection.parent_g3_declaration_hash ==
        chain.recheck.output.g3.declaration_identity_hash
    @test V3_G.canonical_json(adapted_bridge.binding_state) ==
        V3_G.canonical_json(local_authority.binding_state)

    adapted_build = V3_G.prepare_vnext_t2_concrete_source_witness_v3(
        chain.transport, chain.recheck, chain.parent, chain.expected,
        adapted_bridge, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key)
    @test adapted_build.status === :source_ready
    @test adapted_build.witness.candidate_ref == chain.transport.candidate_ref
    @test adapted_build.witness.formal_t1.status === :typed_absent
    @test adapted_build.witness.formal_node_accepted == false

    compatibility_bridge = V3_G.vnext_t2_concrete_g3_bridge_v3(
        chain.recheck, chain.expected, chain.realization_state,
        chain.control_payload, chain.control_state, chain.binding_key;
        initial_links=initial_links)
    @test V3_G.canonical_json(compatibility_bridge) ==
        V3_G.canonical_json(chain.bridge)

    foreign_chain = v3_chain(candidate=V3_G.QualifiedRefV1(
        "fusionconceptai://candidate/up1-g3-foreign-bridge", "v5"))
    foreign_local_authority =
        V3_G.vnext_g3_binding_authority_bridge_local_v1(
            foreign_chain.recheck, foreign_chain.expected,
            foreign_chain.realization_state, foreign_chain.control_state,
            foreign_chain.binding_key;
            initial_links=foreign_chain.bridge.binding_state.source_payload.initial_links)
    foreign_bridge = V3_G.vnext_concrete_source_witness_g3_bridge_v1(
        chain.recheck, chain.expected, foreign_local_authority,
        chain.realization_state, chain.control_payload, chain.control_state,
        chain.binding_key; initial_links=initial_links)
    @test foreign_bridge.status === :fail_closed
    @test :g3_local_bridge_reconstruction_mismatch in foreign_bridge.errors

    mismatched_authority =
        V3_G.VNextG3BindingAuthorityBridgeLocalResultV1(
            local_authority.status, local_authority.resolution,
            local_authority.self_consistency, false,
            local_authority.binding_state, local_authority.errors,
            local_authority.reasons)
    mismatched_bridge = V3_G.vnext_concrete_source_witness_g3_bridge_v1(
        chain.recheck, chain.expected, mismatched_authority,
        chain.realization_state, chain.control_payload, chain.control_state,
        chain.binding_key; initial_links=initial_links)
    @test mismatched_bridge.status === :fail_closed
    @test :g3_local_bridge_reconstruction_mismatch in mismatched_bridge.errors

    forged_hash = V3_G.digest256_text("forged-expected-commitment")
    forged_expected = _up1_g3_bridge_replace_ascii(chain.expected,
        chain.expected.commitment_hash.value, forged_hash.value)
    @test forged_expected.commitment_hash == forged_hash
    @test forged_expected.commitment_hash !=
        V3_G.vnext_g3_binding_expected_commitment_hash_v1(forged_expected)
    forged_bridge = V3_G.vnext_concrete_source_witness_g3_bridge_v1(
        chain.recheck, forged_expected, local_authority,
        chain.realization_state, chain.control_payload, chain.control_state,
        chain.binding_key; initial_links=initial_links)
    @test forged_bridge.status === :fail_closed
    @test :expected_commitment_hash_mismatch in forged_bridge.errors

    absent_g3 = V3_G.VNextT0LocalAbsentDeclarationV1(:G3,
        chain.transport.candidate_ref, :missing_material, :terminal_deferred)
    absent_admission = V3_G.vnext_declaration_transport_local_v1(
        chain.transport.candidate_ref,
        (chain.declarations[1], chain.declarations[2], absent_g3),
        chain.transport.children, ();
        frozen_contexts=Main._T0L_CONTEXTS)
    absent_transport = absent_admission.transport
    absent_recheck = V3_G.vnext_declaration_authority_recheck_local_v1(
        V3_G.VNextAuthorityRecheckLocalInputV1(
            chain.transport.candidate_ref, absent_transport,
            absent_transport.declarations))
    absent_local_authority =
        V3_G.vnext_g3_binding_authority_bridge_local_v1(
            absent_recheck, chain.expected, chain.realization_state,
            chain.control_state, chain.binding_key;
            initial_links=initial_links)
    @test absent_local_authority.status === :typed_absent
    absent_forged_bridge = V3_G.vnext_concrete_source_witness_g3_bridge_v1(
        absent_recheck, forged_expected, local_authority,
        chain.realization_state, chain.control_payload, chain.control_state,
        chain.binding_key; initial_links=initial_links)
    @test absent_forged_bridge.status === :typed_absent
    @test absent_forged_bridge.errors == ()
    @test absent_forged_bridge.reasons == (:t0_typed_absent,)
    absent_bridge = V3_G.vnext_concrete_source_witness_g3_bridge_v1(
        absent_recheck, chain.expected, absent_local_authority,
        chain.realization_state, chain.control_payload, chain.control_state,
        chain.binding_key; initial_links=initial_links)
    @test absent_bridge.status === :typed_absent
    absent_witness = V3_G.prepare_vnext_t2_concrete_source_witness_v3(
        absent_transport, absent_recheck, chain.parent, nothing,
        absent_bridge, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key)
    @test absent_witness.status === :typed_absent
    @test absent_witness.witness === nothing

    invalid_realization = _up1_g3_bridge_replace_ascii(
        chain.realization_state, "declared_consistent", "invalid_admissionxx")
    invalid_control = _up1_g3_bridge_replace_ascii(
        chain.control_state, "declared_consistent", "invalid_admissionxx")
    combined_invalid_legacy_bridge = V3_G.vnext_t2_concrete_g3_bridge_v3(
        chain.recheck, chain.expected, invalid_realization,
        chain.control_payload, invalid_control, chain.binding_key;
        initial_links=initial_links)
    @test combined_invalid_legacy_bridge.status === :fail_closed
    @test combined_invalid_legacy_bridge.errors ==
        (:realization_state_invalid, :control_state_invalid)
    exception_legacy_bridge = V3_G.vnext_t2_concrete_g3_bridge_v3(
        chain.recheck, chain.expected, chain.realization_state,
        chain.control_payload, chain.control_state, chain.binding_key;
        initial_links=nothing)
    @test exception_legacy_bridge.status === :program_exception
    @test exception_legacy_bridge.errors == (:v3_bridge_program_exception,)
end
