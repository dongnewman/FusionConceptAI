using Test
using Serialization

include(joinpath(@__DIR__, "fixture_helpers.jl"))

function v3_serialization_replace_ascii(value, original::AbstractString,
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

function v3_fields_equal_except(left, right, excluded::Symbol)
    typeof(left) === typeof(right) || return false
    all(field === excluded ||
        V3_G.canonical_json(getproperty(left, field)) ==
            V3_G.canonical_json(getproperty(right, field))
        for field in fieldnames(typeof(left)))
end

function v3_rehash_feedback(feedback;
        t0_feedback=feedback.t0_feedback,
        g3_targets=feedback.g3_targets,
        binding_links=feedback.binding_links)
    draft = V3_G.VNextT2ConcreteFeedbackV3(t0_feedback, g3_targets,
        binding_links, V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteFeedbackV3(t0_feedback, g3_targets, binding_links,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_feedback_body(draft)))
end

function v3_rehash_children(children;
        t0_children=children.t0_children,
        expected_commitment=children.expected_commitment,
        realization_state=children.realization_state,
        control_payload=children.control_payload,
        control_state=children.control_state,
        binding_state=children.binding_state)
    draft = V3_G.VNextT2ConcreteG3ChildrenV3(t0_children,
        expected_commitment, realization_state, control_payload,
        control_state, binding_state, V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteG3ChildrenV3(t0_children, expected_commitment,
        realization_state, control_payload, control_state, binding_state,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_children_body(draft)))
end

function v3_rehash_layer_identity(identity; kwargs...)
    values = Dict{Symbol,Any}(
        field => getproperty(identity, field) for field in fieldnames(typeof(identity)))
    for (field, value) in kwargs
        values[field] = value
    end
    draft = V3_G.VNextT2ConcreteLayerIdentityV3(
        values[:layer], values[:source_file_sha256],
        values[:native_source_payload_hash], values[:semantic_body_hash],
        values[:semantic_body_sha256], values[:native_declaration_hash],
        values[:declaration_sha256], values[:source_identity_hash],
        values[:declaration_identity_hash], values[:source_carrier_hash],
        values[:declaration_component_hash], values[:factory_content_identity],
        values[:source_axes], values[:factory_axes],
        V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteLayerIdentityV3(draft.layer,
        draft.source_file_sha256, draft.native_source_payload_hash,
        draft.semantic_body_hash, draft.semantic_body_sha256,
        draft.native_declaration_hash, draft.declaration_sha256,
        draft.source_identity_hash, draft.declaration_identity_hash,
        draft.source_carrier_hash, draft.declaration_component_hash,
        draft.factory_content_identity, draft.source_axes,
        draft.factory_axes,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_layer_identity_body(draft)))
end

function v3_rehash_witness(witness;
        g1=witness.g1, g2=witness.g2, g3=witness.g3,
        t0_transport=witness.t0_transport,
        t0_recheck=witness.t0_recheck,
        parent_bundle=witness.parent_bundle,
        children=witness.children, feedback=witness.feedback,
        coupling=witness.coupling, formal_t1=witness.formal_t1,
        source_status=witness.source_status, resolution=witness.resolution,
        formal_node_accepted=witness.formal_node_accepted,
        gaps=witness.gaps)
    source_bundle_hash = V3_G.canonical_hash((
        domain="vnext-t2-concrete-source-bundle-v3",
        candidate_ref=witness.candidate_ref,
        g1=g1.identity.identity_hash, g2=g2.identity.identity_hash,
        g3=g3.identity.identity_hash, children=children.identity_hash,
        feedback=feedback.identity_hash))
    mdraft = V3_G.VNextT2ConcreteSourceManifestV3(witness.candidate_ref,
        t0_transport.bundle_hash, V3_G.canonical_hash(t0_transport),
        V3_G.canonical_hash(V3_G._vnext_t2_v3_recheck_output_body(t0_recheck)),
        parent_bundle.bundle_hash,
        children.expected_commitment.commitment_hash,
        g1.identity.identity_hash, g2.identity.identity_hash,
        g3.identity.identity_hash, children.identity_hash,
        feedback.identity_hash, source_bundle_hash,
        V3_G.Digest256(repeat("0", 64)))
    manifest = V3_G.VNextT2ConcreteSourceManifestV3(mdraft.candidate_ref,
        mdraft.t0_bundle_hash, mdraft.t0_transport_hash,
        mdraft.t0_recheck_output_hash, mdraft.parent_bundle_hash,
        mdraft.g3_expected_commitment_hash, mdraft.g1_identity_hash,
        mdraft.g2_identity_hash, mdraft.g3_identity_hash,
        mdraft.children_identity_hash, mdraft.feedback_identity_hash,
        mdraft.source_bundle_hash,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_manifest_body(mdraft)))
    draft = V3_G.VNextT2ConcreteSourceWitnessV3(witness.schema_id,
        witness.schema_version, witness.profile, witness.candidate_ref,
        g1, g2, g3, t0_transport, t0_recheck, parent_bundle, children,
        feedback, coupling, manifest, formal_t1, source_status, resolution,
        formal_node_accepted, gaps, V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteSourceWitnessV3(draft.schema_id,
        draft.schema_version, draft.profile, draft.candidate_ref,
        draft.g1, draft.g2, draft.g3, draft.t0_transport,
        draft.t0_recheck, draft.parent_bundle, draft.children,
        draft.feedback, draft.coupling, draft.manifest, draft.formal_t1,
        draft.source_status, draft.resolution, draft.formal_node_accepted,
        draft.gaps, V3_G.canonical_hash(V3_G._vnext_t2_v3_witness_body(draft)))
end

const V3_SHARD_EXECUTED_SITES = Symbol[]
const V3_SHARD_HELPER_PATH = @__FILE__
const V3_SHARD_EXPECTED_SEQUENCE_SHA256 = Dict{Symbol,String}(
    :native_baseline_coupling => "2815c0bbabc23b0d5b9c7305028c5d29ee94428b551f9acc3e438fe565d1ccdd",
    :edited_state_typed_reload => "a3ed42e9ac00d883f5909092b1cbe1912cae0db6e0153e5f1e159919c6531b6d",
    :intrinsic_absence_precedence => "5dbe3f2ea979a2783f2ede9e7d6386b48c7ec3ddd1c24413e47ec584fbd4dc93",
    :foreign_authority_joins => "e17d189132c970048c858cc0fd91dc7b5d46873a08450fdc3c0ce51d8be17a7c",
    :recomputed_source_layer => "25eabfa45aec8727907d275619b18f2b9fd4e0dd94de4dca4d9f1c93191bdd63",
    :feedback_child_serialization => "1d2647b008925cdcfc2553dd783bb2b9505964e7e909b3ea1e3591543f585f03",
)
const V3_SHARD_EXPECTED_SYNTACTIC_SITES = Dict{Symbol,Int}(
    :native_baseline_coupling => 43,
    :edited_state_typed_reload => 16,
    :intrinsic_absence_precedence => 23,
    :foreign_authority_joins => 7,
    :recomputed_source_layer => 8,
    :feedback_child_serialization => 6,
)
const V3_SHARD_EXPECTED_RUNTIME_ASSERTIONS = Dict{Symbol,Int}(
    :native_baseline_coupling => 55,
    :edited_state_typed_reload => 16,
    :intrinsic_absence_precedence => 23,
    :foreign_authority_joins => 7,
    :recomputed_source_layer => 8,
    :feedback_child_serialization => 6,
)

function v3_site!(site::Symbol)
    push!(V3_SHARD_EXECUTED_SITES, site)
    nothing
end

_v3_shard_sha256_file(path) = bytes2hex(SHA.sha256(read(path)))

function _v3_shard_input_pin_hash(driver_path, ledger_path)
    paths = (
        ("source", joinpath(V3_ROOT, "src", "GenomeV5", "Integration",
            "VNextT2ConcreteSourceWitnessV3.jl")),
        ("fixture", joinpath(@__DIR__, "fixture_helpers.jl")),
        ("monolith", joinpath(@__DIR__,
            "vnext_t2_concrete_source_witness_v3_tests.jl")),
        ("helper", V3_SHARD_HELPER_PATH),
        ("driver", driver_path),
        ("ledger", ledger_path),
    )
    material = join((label * "=" * _v3_shard_sha256_file(path)
        for (label, path) in paths), "\n")
    bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(material))))
end

function v3_finish_shard!(scenario::Symbol, driver_path, ledger_path)
    sequence_text = join(String.(V3_SHARD_EXECUTED_SITES), ",")
    sequence_hash = bytes2hex(SHA.sha256(
        Vector{UInt8}(codeunits(sequence_text))))
    unique_sites = unique(V3_SHARD_EXECUTED_SITES)
    sequence_hash == V3_SHARD_EXPECTED_SEQUENCE_SHA256[scenario] ||
        error((:shard_runtime_sequence_mismatch, scenario, sequence_hash))
    length(unique_sites) == V3_SHARD_EXPECTED_SYNTACTIC_SITES[scenario] ||
        error((:shard_syntactic_site_count_mismatch, scenario,
            length(unique_sites)))
    length(V3_SHARD_EXECUTED_SITES) ==
        V3_SHARD_EXPECTED_RUNTIME_ASSERTIONS[scenario] ||
        error((:shard_runtime_assertion_count_mismatch, scenario,
            length(V3_SHARD_EXECUTED_SITES)))
    input_pin_hash = _v3_shard_input_pin_hash(driver_path, ledger_path)
    println("V3_SHARD_RESULT scenario=", scenario,
        " syntactic_sites=", length(unique_sites),
        " runtime_assertions=", length(V3_SHARD_EXECUTED_SITES),
        " site_sequence_sha256=", sequence_hash,
        " input_pin_sha256=", input_pin_hash,
        " site_ids=", join(String.(unique_sites), ","))
    flush(stdout)
    nothing
end
