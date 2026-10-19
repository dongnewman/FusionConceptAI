"""Isolated, candidate-bound physical-edge obligation contract for UP5.

This file is intentionally not included by `FusionRuntimeV4.jl`. It describes
one obligation for each typed graph edge/root and can bind an already-produced
repository-trusted provider receipt after revalidation. It does not compile a
candidate, mutate a queue, dispatch a provider, or activate Search.
"""
module PhysicalEdgeObligationV1Compat

import FusionConceptAI: Digest256, canonical_hash, semantic_view,
    TypedOperatorHypergraphV1, TypedHyperedge, AtomicMIMOHyperedgeV1,
    TypedASTProgramV1, ASTApplyV1, ASTInputV1, ASTParameterV1, ASTConstantV1,
    is_canonical_value
import ..FusionRuntimeV4: ForwardChainContextV4,
    validate_forward_chain_context,
    CapabilitySignatureV4, TrustedProviderRegistryV4,
    TrustedProviderRegistrationV4, TrustedProviderDispatchRequestV4,
    TrustedProviderExecutionReceiptV4,
    validate_trusted_provider_dispatch_request,
    validate_trusted_provider_execution_receipt

export PhysicalEdgeIdentityV1, PhysicalCapabilityRequirementV1,
    PhysicalProviderReceiptStateV1, PhysicalEdgeObligationV1,
    physical_edge_obligations_v1, validate_obligation_set_v1,
    PhysicalEdgeProviderInputV1, physical_edge_provider_input_v1,
    bind_trusted_provider_receipt_v1, assess_candidate_obligations_v1,
    search_activation_disposition_v1

const PHYSICAL_EDGE_OBLIGATION_REVISION_V1 = "up5-physical-edge-obligation-v1"
const _PEO_LAYERS = (:g1_mechanism, :g2_field_geometry,
    :g3_realization, :g3_control)
const _PEO_PROVIDER_STATES = (:unresolved, :completed, :screen_result,
    :failed, :foreign, :stale, :invalid)
const _PEO_RECEIPT_STATES = (:missing, :validated, :rejected)
const _PEO_TOKEN = Ref{Nothing}(nothing)

_peo_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be text"))
    s = String(x)
    !isempty(strip(s)) && isvalid(s) || throw(ArgumentError("$field must be non-empty valid text"))
    s
end

function _peo_digest_or_nothing(x, field)
    x === nothing || x isa Digest256 || throw(ArgumentError("$field must be Digest256 or nothing"))
    x
end

function _peo_identity_body(layer, genome_role, graph_role, graph_hash,
        edge_position, edge_id, edge_hash, program_hash, root_position,
        root_node_hash, operator_id, operator_version, operator_manifest_hash)
    (schema="fusionconceptai:up5-physical-edge-identity-v1",
     layer=layer, genome_role=genome_role, graph_role=graph_role,
     graph_hash=graph_hash, edge_position=edge_position, edge_id=edge_id,
     edge_hash=edge_hash, program_hash=program_hash,
     root_position=root_position, root_node_hash=root_node_hash,
     operator_id=operator_id, operator_version=operator_version,
     operator_manifest_hash=operator_manifest_hash)
end

"""Exact identity of one typed hyperedge root in one Genome-owned graph."""
struct PhysicalEdgeIdentityV1
    layer::Symbol
    genome_role::Symbol
    graph_role::Symbol
    graph_hash::Digest256
    edge_position::Int
    edge_id::String
    edge_hash::Digest256
    program_hash::Digest256
    root_position::Int
    root_node_hash::Digest256
    operator_id::String
    operator_version::String
    operator_manifest_hash::Union{Nothing,Digest256}
    identity_hash::Digest256
    function PhysicalEdgeIdentityV1(token::Base.RefValue{Nothing}, layer::Symbol,
            genome_role::Symbol, graph_role::Symbol, graph_hash::Digest256,
            edge_position::Int, edge_id::String, edge_hash::Digest256,
            program_hash::Digest256, root_position::Int,
            root_node_hash::Digest256, operator_id::String,
            operator_version::String,
            operator_manifest_hash::Union{Nothing,Digest256},
            identity_hash::Digest256)
        token === _PEO_TOKEN || throw(ArgumentError("private edge identity constructor"))
        layer in _PEO_LAYERS || throw(ArgumentError("unknown physical Genome layer"))
        edge_position >= 1 && root_position >= 1 ||
            throw(ArgumentError("edge and root positions must be positive"))
        _peo_text(edge_id, "edge_id")
        _peo_text(operator_id, "operator_id")
        _peo_text(operator_version, "operator_version")
        expected = canonical_hash(_peo_identity_body(layer, genome_role,
            graph_role, graph_hash, edge_position, edge_id, edge_hash,
            program_hash, root_position, root_node_hash, operator_id,
            operator_version, operator_manifest_hash))
        expected == identity_hash || throw(ArgumentError("edge identity hash mismatch"))
        new(layer, genome_role, graph_role, graph_hash, edge_position,
            edge_id, edge_hash, program_hash, root_position, root_node_hash,
            operator_id, operator_version, operator_manifest_hash, identity_hash)
    end
end

semantic_view(x::PhysicalEdgeIdentityV1) = merge(
    _peo_identity_body(x.layer, x.genome_role, x.graph_role, x.graph_hash,
        x.edge_position, x.edge_id, x.edge_hash, x.program_hash,
        x.root_position, x.root_node_hash, x.operator_id,
        x.operator_version, x.operator_manifest_hash),
    (identity_hash=x.identity_hash,))

canonical_hash(x::PhysicalEdgeIdentityV1) = begin
    expected = canonical_hash(_peo_identity_body(x.layer, x.genome_role,
        x.graph_role, x.graph_hash, x.edge_position, x.edge_id,
        x.edge_hash, x.program_hash, x.root_position, x.root_node_hash,
        x.operator_id, x.operator_version, x.operator_manifest_hash))
    expected == x.identity_hash || throw(ArgumentError("edge identity hash mismatch"))
    expected
end

function _peo_requirement_body(identity_hash, operator_id, operator_version,
        operator_manifest_hash, capability_schema, capability_revision,
        capability_hash, match_state)
    (schema="fusionconceptai:up5-physical-capability-requirement-v1",
     revision=PHYSICAL_EDGE_OBLIGATION_REVISION_V1,
     edge_identity_hash=identity_hash, operator_id=operator_id,
     operator_version=operator_version,
     operator_manifest_hash=operator_manifest_hash,
     capability_schema=capability_schema,
     capability_revision=capability_revision,
     capability_hash=capability_hash, match_state=match_state)
end

"""Versioned capability key for one edge; actual CapabilitySignature is optional until matched."""
struct PhysicalCapabilityRequirementV1
    edge_identity_hash::Digest256
    operator_id::String
    operator_version::String
    operator_manifest_hash::Union{Nothing,Digest256}
    capability_schema::Union{Nothing,String}
    capability_revision::Union{Nothing,String}
    capability_hash::Union{Nothing,Digest256}
    match_state::Symbol
    requirement_hash::Digest256
    function PhysicalCapabilityRequirementV1(token::Base.RefValue{Nothing},
            edge_identity_hash::Digest256, operator_id::String,
            operator_version::String,
            operator_manifest_hash::Union{Nothing,Digest256},
            capability_schema::Union{Nothing,String},
            capability_revision::Union{Nothing,String},
            capability_hash::Union{Nothing,Digest256}, match_state::Symbol,
            requirement_hash::Digest256)
        token === _PEO_TOKEN || throw(ArgumentError("private capability requirement constructor"))
        match_state in (:unmatched, :matched) || throw(ArgumentError("invalid capability match state"))
        if match_state === :unmatched
            capability_schema === nothing && capability_revision === nothing &&
                capability_hash === nothing || throw(ArgumentError("unmatched capability must not carry a signature"))
        else
            capability_schema !== nothing && capability_revision !== nothing &&
                capability_hash !== nothing || throw(ArgumentError("matched capability requires exact signature identity"))
        end
        expected = canonical_hash(_peo_requirement_body(edge_identity_hash,
            operator_id, operator_version, operator_manifest_hash,
            capability_schema, capability_revision, capability_hash, match_state))
        expected == requirement_hash || throw(ArgumentError("capability requirement hash mismatch"))
        new(edge_identity_hash, operator_id, operator_version,
            operator_manifest_hash, capability_schema, capability_revision,
            capability_hash, match_state, requirement_hash)
    end
end

semantic_view(x::PhysicalCapabilityRequirementV1) = merge(
    _peo_requirement_body(x.edge_identity_hash, x.operator_id,
        x.operator_version, x.operator_manifest_hash, x.capability_schema,
        x.capability_revision, x.capability_hash, x.match_state),
    (requirement_hash=x.requirement_hash,))

canonical_hash(x::PhysicalCapabilityRequirementV1) = begin
    expected = canonical_hash(_peo_requirement_body(x.edge_identity_hash,
        x.operator_id, x.operator_version, x.operator_manifest_hash,
        x.capability_schema, x.capability_revision, x.capability_hash,
        x.match_state))
    expected == x.requirement_hash || throw(ArgumentError("capability requirement hash mismatch"))
    expected
end

function _peo_input_body(identity_hash, candidate_hash, genome_bundle_hash,
        context_hash, scenario_hash, capability_hash, payload_hash)
    (schema="fusionconceptai:up5-physical-edge-provider-input-v1",
     revision=PHYSICAL_EDGE_OBLIGATION_REVISION_V1,
     edge_identity_hash=identity_hash, candidate_hash=candidate_hash,
     genome_bundle_hash=genome_bundle_hash, context_hash=context_hash,
     scenario_hash=scenario_hash, capability_hash=capability_hash,
     provider_payload_hash=payload_hash)
end

"""Typed request envelope that makes a provider request specific to one edge."""
struct PhysicalEdgeProviderInputV1
    edge_identity_hash::Digest256
    candidate_hash::Digest256
    genome_bundle_hash::Digest256
    context_hash::Digest256
    scenario_hash::Digest256
    capability_hash::Digest256
    provider_payload::Any
    provider_payload_hash::Digest256
    input_binding_hash::Digest256
    function PhysicalEdgeProviderInputV1(token::Base.RefValue{Nothing},
            edge_identity_hash::Digest256, candidate_hash::Digest256,
            genome_bundle_hash::Digest256, context_hash::Digest256,
            scenario_hash::Digest256, capability_hash::Digest256,
            provider_payload, provider_payload_hash::Digest256,
            input_binding_hash::Digest256)
        token === _PEO_TOKEN || throw(ArgumentError("private edge-bound input constructor"))
        is_canonical_value(provider_payload) ||
            throw(ArgumentError("edge provider payload must be canonical"))
        canonical_hash(provider_payload) == provider_payload_hash ||
            throw(ArgumentError("edge provider payload hash mismatch"))
        body = _peo_input_body(edge_identity_hash, candidate_hash,
            genome_bundle_hash, context_hash, scenario_hash, capability_hash,
            provider_payload_hash)
        canonical_hash(body) == input_binding_hash ||
            throw(ArgumentError("edge provider input binding hash mismatch"))
        new(edge_identity_hash, candidate_hash, genome_bundle_hash,
            context_hash, scenario_hash, capability_hash, provider_payload,
            provider_payload_hash, input_binding_hash)
    end
end

semantic_view(x::PhysicalEdgeProviderInputV1) = merge(
    _peo_input_body(x.edge_identity_hash, x.candidate_hash,
        x.genome_bundle_hash, x.context_hash, x.scenario_hash,
        x.capability_hash, x.provider_payload_hash),
    (input_binding_hash=x.input_binding_hash,))

canonical_hash(x::PhysicalEdgeProviderInputV1) = begin
    is_canonical_value(x.provider_payload) ||
        throw(ArgumentError("edge provider payload is no longer canonical"))
    canonical_hash(x.provider_payload) == x.provider_payload_hash ||
        throw(ArgumentError("edge provider payload changed"))
    expected = canonical_hash(_peo_input_body(x.edge_identity_hash,
        x.candidate_hash, x.genome_bundle_hash, x.context_hash,
        x.scenario_hash, x.capability_hash, x.provider_payload_hash))
    expected == x.input_binding_hash ||
        throw(ArgumentError("edge provider input binding hash mismatch"))
    canonical_hash(semantic_view(x))
end

function _peo_requirement(identity::PhysicalEdgeIdentityV1,
        capability::Union{Nothing,CapabilitySignatureV4}=nothing)
    schema = nothing
    revision = nothing
    signature_hash = nothing
    match_state = :unmatched
    if capability !== nothing
        capability.operator == string(identity.operator_id, "@", identity.operator_version) ||
            throw(ArgumentError("capability operator/version does not match edge root"))
        schema, revision = capability.schema, capability.revision
        signature_hash = canonical_hash(capability)
        match_state = :matched
    end
    body = _peo_requirement_body(identity.identity_hash, identity.operator_id,
        identity.operator_version, identity.operator_manifest_hash,
        schema, revision, signature_hash, match_state)
    PhysicalCapabilityRequirementV1(_PEO_TOKEN, identity.identity_hash,
        identity.operator_id, identity.operator_version,
        identity.operator_manifest_hash, schema, revision, signature_hash,
        match_state, canonical_hash(body))
end

function _peo_provider_body(provider_state, receipt_state, provider_backend,
        provider_manifest_hash, registry_hash, request_hash, receipt_hash,
        input_hash, output_hash, provider_status, exit_code, failure_code)
    (schema="fusionconceptai:up5-physical-provider-receipt-state-v1",
     revision=PHYSICAL_EDGE_OBLIGATION_REVISION_V1,
     provider_state=provider_state, receipt_state=receipt_state,
     provider_backend=provider_backend,
     provider_manifest_hash=provider_manifest_hash,
     registry_hash=registry_hash, request_hash=request_hash,
     receipt_hash=receipt_hash, input_hash=input_hash,
     output_hash=output_hash, provider_status=provider_status,
     exit_code=exit_code, failure_code=failure_code)
end

"""Hashes and typed status of a provider attempt; raw evaluator output is not copied here."""
struct PhysicalProviderReceiptStateV1
    provider_state::Symbol
    receipt_state::Symbol
    provider_backend::Union{Nothing,String}
    provider_manifest_hash::Union{Nothing,Digest256}
    registry_hash::Union{Nothing,Digest256}
    request_hash::Union{Nothing,Digest256}
    receipt_hash::Union{Nothing,Digest256}
    input_hash::Union{Nothing,Digest256}
    output_hash::Union{Nothing,Digest256}
    provider_status::Union{Nothing,Symbol}
    exit_code::Union{Nothing,Int}
    failure_code::Union{Nothing,Symbol}
    state_hash::Digest256
    function PhysicalProviderReceiptStateV1(token::Base.RefValue{Nothing},
            provider_state::Symbol, receipt_state::Symbol,
            provider_backend::Union{Nothing,String},
            provider_manifest_hash::Union{Nothing,Digest256},
            registry_hash::Union{Nothing,Digest256},
            request_hash::Union{Nothing,Digest256},
            receipt_hash::Union{Nothing,Digest256},
            input_hash::Union{Nothing,Digest256},
            output_hash::Union{Nothing,Digest256},
            provider_status::Union{Nothing,Symbol},
            exit_code::Union{Nothing,Int},
            failure_code::Union{Nothing,Symbol}, state_hash::Digest256)
        token === _PEO_TOKEN || throw(ArgumentError("private provider state constructor"))
        provider_state in _PEO_PROVIDER_STATES || throw(ArgumentError("invalid provider state"))
        receipt_state in _PEO_RECEIPT_STATES || throw(ArgumentError("invalid receipt state"))
        if receipt_state === :missing
            provider_state === :unresolved && all(isnothing,
                (provider_backend, provider_manifest_hash, registry_hash,
                 request_hash, receipt_hash, input_hash, output_hash,
                 provider_status, exit_code, failure_code)) ||
                throw(ArgumentError("missing receipt state carries provider evidence"))
        elseif receipt_state === :validated
            provider_state in (:completed, :screen_result, :failed) &&
                all(x -> x !== nothing, (provider_backend,
                    provider_manifest_hash, registry_hash, request_hash,
                    receipt_hash, input_hash, output_hash, provider_status,
                    exit_code)) && failure_code === nothing ||
                throw(ArgumentError("validated receipt state is incomplete"))
        else
            provider_state in (:foreign, :stale, :invalid) &&
                failure_code !== nothing ||
                throw(ArgumentError("rejected receipt needs a typed failure"))
        end
        expected = canonical_hash(_peo_provider_body(provider_state,
            receipt_state, provider_backend, provider_manifest_hash,
            registry_hash, request_hash, receipt_hash, input_hash,
            output_hash, provider_status, exit_code, failure_code))
        expected == state_hash || throw(ArgumentError("provider state hash mismatch"))
        new(provider_state, receipt_state, provider_backend,
            provider_manifest_hash, registry_hash, request_hash, receipt_hash,
            input_hash, output_hash, provider_status, exit_code,
            failure_code, state_hash)
    end
end

semantic_view(x::PhysicalProviderReceiptStateV1) = merge(
    _peo_provider_body(x.provider_state, x.receipt_state,
        x.provider_backend, x.provider_manifest_hash, x.registry_hash,
        x.request_hash, x.receipt_hash, x.input_hash, x.output_hash,
        x.provider_status, x.exit_code, x.failure_code),
    (state_hash=x.state_hash,))

canonical_hash(x::PhysicalProviderReceiptStateV1) = begin
    expected = canonical_hash(_peo_provider_body(x.provider_state,
        x.receipt_state, x.provider_backend, x.provider_manifest_hash,
        x.registry_hash, x.request_hash, x.receipt_hash, x.input_hash,
        x.output_hash, x.provider_status, x.exit_code, x.failure_code))
    expected == x.state_hash || throw(ArgumentError("provider state hash mismatch"))
    expected
end

function _peo_provider_state(; provider_state=:unresolved,
        receipt_state=:missing, provider_backend=nothing,
        provider_manifest_hash=nothing, registry_hash=nothing,
        request_hash=nothing, receipt_hash=nothing, input_hash=nothing,
        output_hash=nothing, provider_status=nothing, exit_code=nothing,
        failure_code=nothing)
    body = _peo_provider_body(provider_state, receipt_state,
        provider_backend, provider_manifest_hash, registry_hash, request_hash,
        receipt_hash, input_hash, output_hash, provider_status, exit_code,
        failure_code)
    PhysicalProviderReceiptStateV1(_PEO_TOKEN, provider_state,
        receipt_state, provider_backend, provider_manifest_hash,
        registry_hash, request_hash, receipt_hash, input_hash, output_hash,
        provider_status, exit_code, failure_code, canonical_hash(body))
end

function _peo_obligation_body(identity, candidate_hash, genome_bundle_hash,
        context_hash, scenario_hash, requirement, provider)
    (schema="fusionconceptai:up5-physical-edge-obligation-v1",
     revision=PHYSICAL_EDGE_OBLIGATION_REVISION_V1,
     identity=identity, candidate_hash=candidate_hash,
     genome_bundle_hash=genome_bundle_hash, context_hash=context_hash,
     scenario_hash=scenario_hash, requirement=requirement, provider=provider)
end

"""One edge/root obligation bound to candidate, Genome bundle and forward context."""
struct PhysicalEdgeObligationV1
    identity::PhysicalEdgeIdentityV1
    candidate_hash::Digest256
    genome_bundle_hash::Digest256
    context_hash::Digest256
    scenario_hash::Digest256
    requirement::PhysicalCapabilityRequirementV1
    provider::PhysicalProviderReceiptStateV1
    obligation_hash::Digest256
    function PhysicalEdgeObligationV1(token::Base.RefValue{Nothing},
            identity::PhysicalEdgeIdentityV1, candidate_hash::Digest256,
            genome_bundle_hash::Digest256, context_hash::Digest256,
            scenario_hash::Digest256,
            requirement::PhysicalCapabilityRequirementV1,
            provider::PhysicalProviderReceiptStateV1,
            obligation_hash::Digest256)
        token === _PEO_TOKEN || throw(ArgumentError("private edge obligation constructor"))
        canonical_hash(identity)
        canonical_hash(requirement)
        canonical_hash(provider)
        requirement.edge_identity_hash == identity.identity_hash ||
            throw(ArgumentError("capability requirement is detached from edge identity"))
        requirement.operator_id == identity.operator_id &&
            requirement.operator_version == identity.operator_version ||
            throw(ArgumentError("capability requirement is detached from edge root"))
        expected = canonical_hash(_peo_obligation_body(identity,
            candidate_hash, genome_bundle_hash, context_hash, scenario_hash,
            requirement, provider))
        expected == obligation_hash || throw(ArgumentError("obligation hash mismatch"))
        new(identity, candidate_hash, genome_bundle_hash, context_hash,
            scenario_hash, requirement, provider, obligation_hash)
    end
end

semantic_view(x::PhysicalEdgeObligationV1) = merge(
    _peo_obligation_body(x.identity, x.candidate_hash,
        x.genome_bundle_hash, x.context_hash, x.scenario_hash,
        x.requirement, x.provider), (obligation_hash=x.obligation_hash,))

canonical_hash(x::PhysicalEdgeObligationV1) = begin
    canonical_hash(x.identity); canonical_hash(x.requirement); canonical_hash(x.provider)
    expected = canonical_hash(_peo_obligation_body(x.identity,
        x.candidate_hash, x.genome_bundle_hash, x.context_hash,
        x.scenario_hash, x.requirement, x.provider))
    expected == x.obligation_hash || throw(ArgumentError("obligation hash mismatch"))
    expected
end

"""Wrap provider payload only after matching the edge's exact operator capability."""
function physical_edge_provider_input_v1(obligation::PhysicalEdgeObligationV1,
        capability::CapabilitySignatureV4, provider_payload)
    canonical_hash(obligation)
    capability.operator == string(obligation.identity.operator_id, "@",
        obligation.identity.operator_version) ||
        throw(ArgumentError("capability operator/version does not match edge"))
    capability_hash = canonical_hash(capability)
    is_canonical_value(provider_payload) ||
        throw(ArgumentError("provider payload must be canonical"))
    payload_hash = canonical_hash(provider_payload)
    body = _peo_input_body(obligation.identity.identity_hash,
        obligation.candidate_hash, obligation.genome_bundle_hash,
        obligation.context_hash, obligation.scenario_hash, capability_hash,
        payload_hash)
    PhysicalEdgeProviderInputV1(_PEO_TOKEN,
        obligation.identity.identity_hash, obligation.candidate_hash,
        obligation.genome_bundle_hash, obligation.context_hash,
        obligation.scenario_hash, capability_hash, provider_payload,
        payload_hash, canonical_hash(body))
end

function _peo_make_obligation(identity, candidate_hash, genome_bundle_hash,
        context_hash, scenario_hash; requirement=_peo_requirement(identity),
        provider=_peo_provider_state())
    body = _peo_obligation_body(identity, candidate_hash,
        genome_bundle_hash, context_hash, scenario_hash, requirement, provider)
    PhysicalEdgeObligationV1(_PEO_TOKEN, identity, candidate_hash,
        genome_bundle_hash, context_hash, scenario_hash, requirement,
        provider, canonical_hash(body))
end

function _peo_program_parts(edge::TypedHyperedge)
    program = TypedASTProgramV1(edge.ast)
    program.nodes, program.roots, canonical_hash(program), program
end

function _peo_program_parts(edge::AtomicMIMOHyperedgeV1)
    canonical_hash(edge.program) == edge.program_hash ||
        throw(ArgumentError("atomic MIMO program hash mismatch"))
    edge.program.nodes, edge.program.roots, edge.program_hash, edge.program
end

function _peo_operator_ref(node::ASTApplyV1)
    q = node.operator_ref.qualified
    q.id, q.version
end
_peo_operator_ref(::ASTInputV1) = ("state_input", "v1")
_peo_operator_ref(::ASTParameterV1) = ("parameter_input", "v1")
_peo_operator_ref(::ASTConstantV1) = ("constant_input", "v1")
_peo_operator_ref(node) = throw(ArgumentError("unsupported physical AST root kind $(typeof(node))"))

function _peo_operator_manifest_hash(program::TypedASTProgramV1,
        node::ASTApplyV1)
    q = node.operator_ref.qualified
    hits = Tuple(binding[2] for binding in program.used_manifest_bindings
        if binding[1].qualified.id == q.id && binding[1].qualified.version == q.version)
    length(hits) == 1 || throw(ArgumentError("operator manifest binding is missing or ambiguous"))
    only(hits)
end
_peo_operator_manifest_hash(::Nothing, ::ASTApplyV1) = nothing
_peo_operator_manifest_hash(program, node) = nothing

function _peo_layer(genome_role::Symbol, graph_role::Symbol)
    genome_role === :mechanism && graph_role === :mechanism && return :g1_mechanism
    genome_role === :field_geometry && graph_role === :field_geometry && return :g2_field_geometry
    genome_role === :realization_control && graph_role === :realization && return :g3_realization
    genome_role === :realization_control && graph_role === :control && return :g3_control
    throw(ArgumentError("forward graph ownership does not map to a G1/G2/G3 edge"))
end

function _peo_edge_identity(genome, graph_binding, edge_position::Int,
        edge::Union{TypedHyperedge,AtomicMIMOHyperedgeV1}, root_position::Int)
    graph = graph_binding.graph::TypedOperatorHypergraphV1
    1 <= edge_position <= length(graph.hyperedges) &&
        graph.hyperedges[edge_position] === edge ||
        throw(ArgumentError("edge position does not identify graph edge"))
    nodes, roots, program_hash, program = _peo_program_parts(edge)
    1 <= root_position <= length(roots) || throw(ArgumentError("root position out of range"))
    root_node_position = roots[root_position]
    1 <= root_node_position <= length(nodes) || throw(ArgumentError("root node index out of range"))
    root_node = nodes[root_node_position]
    operator_id, operator_version = _peo_operator_ref(root_node)
    manifest_hash = root_node isa ASTApplyV1 ?
        _peo_operator_manifest_hash(program, root_node) : nothing
    layer = _peo_layer(genome.role, graph_binding.role)
    edge_hash = graph_binding.hyperedge_identity_hashes[edge_position]
    body = _peo_identity_body(layer, genome.role, graph_binding.role,
        graph_binding.canonical_graph_hash, edge_position, edge.edge_id,
        edge_hash, program_hash, root_position, canonical_hash(root_node),
        operator_id, operator_version, manifest_hash)
    PhysicalEdgeIdentityV1(_PEO_TOKEN, layer, genome.role,
        graph_binding.role, graph_binding.canonical_graph_hash,
        edge_position, edge.edge_id, edge_hash, program_hash, root_position,
        canonical_hash(root_node), operator_id, operator_version,
        manifest_hash, canonical_hash(body))
end

"""Enumerate every typed edge/root from the validated G1, G2 and G3 graphs.

Identical operator strings on distinct edges remain separate obligations because
the key includes graph role/hash, edge position/id/hash and root position/hash.
"""
function physical_edge_obligations_v1(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    candidate_hash = context.candidate_hash
    bundle_hash = context.candidate.canonical_hashes.genome_bundle_hash
    context_hash = context.context_hash
    scenario_hash = context.scenario_hash
    obligations = PhysicalEdgeObligationV1[]
    for genome in context.genome_bindings
        for graph_binding in genome.graph_bindings
            graph = graph_binding.graph::TypedOperatorHypergraphV1
            graph_binding.canonical_graph_hash == canonical_hash(graph) ||
                throw(ArgumentError("forward graph hash changed during obligation enumeration"))
            for (edge_position, edge) in enumerate(graph.hyperedges)
                nodes, roots, _, _ = _peo_program_parts(edge)
                for root_position in eachindex(roots)
                    identity = _peo_edge_identity(genome, graph_binding,
                        edge_position, edge, root_position)
                    push!(obligations, _peo_make_obligation(identity,
                        candidate_hash, bundle_hash, context_hash,
                        scenario_hash))
                end
            end
        end
    end
    hashes = Tuple(x.identity.identity_hash for x in obligations)
    length(unique(hashes)) == length(hashes) ||
        throw(ArgumentError("duplicate edge-root identity in validated Genome graphs"))
    Tuple(obligations)
end

"""Require complete ordered coverage of the context's typed edge/root inventory."""
function validate_obligation_set_v1(context::ForwardChainContextV4,
        obligations::Tuple{Vararg{PhysicalEdgeObligationV1}})
    validate_forward_chain_context(context)
    expected = physical_edge_obligations_v1(context)
    length(obligations) == length(expected) ||
        throw(ArgumentError("typed obligation set does not cover every edge/root"))
    actual_hashes = Tuple(canonical_hash(x.identity) for x in obligations)
    expected_hashes = Tuple(canonical_hash(x.identity) for x in expected)
    length(unique(actual_hashes)) == length(actual_hashes) ||
        throw(ArgumentError("typed obligation set collapses or duplicates edge identity"))
    actual_hashes == expected_hashes ||
        throw(ArgumentError("typed obligation set has missing, foreign, stale, or reordered edges"))
    for obligation in obligations
        canonical_hash(obligation)
        obligation.candidate_hash == context.candidate_hash ||
            throw(ArgumentError("obligation belongs to another candidate"))
        obligation.genome_bundle_hash == context.candidate.canonical_hashes.genome_bundle_hash ||
            throw(ArgumentError("obligation belongs to another Genome bundle"))
        obligation.context_hash == context.context_hash ||
            throw(ArgumentError("obligation belongs to a stale forward context"))
        obligation.scenario_hash == context.scenario_hash ||
            throw(ArgumentError("obligation belongs to another scenario"))
    end
    dispatched_request_hashes = Tuple(x.provider.request_hash for x in obligations
        if x.provider.receipt_state === :validated)
    length(unique(dispatched_request_hashes)) == length(dispatched_request_hashes) ||
        throw(ArgumentError("one trusted provider request cannot discharge multiple edge obligations"))
    canonical_hash((revision=PHYSICAL_EDGE_OBLIGATION_REVISION_V1,
        candidate_hash=context.candidate_hash, context_hash=context.context_hash,
        obligation_hashes=Tuple(x.obligation_hash for x in obligations)))
end

function _peo_with_state(obligation::PhysicalEdgeObligationV1,
        requirement::PhysicalCapabilityRequirementV1,
        provider::PhysicalProviderReceiptStateV1)
    _peo_make_obligation(obligation.identity, obligation.candidate_hash,
        obligation.genome_bundle_hash, obligation.context_hash,
        obligation.scenario_hash; requirement, provider)
end

function _peo_attempt_state(obligation, request, receipt;
        provider_state::Symbol, failure_code::Symbol,
        receipt_state::Symbol=:rejected)
    registration = request.registration
    backend = registration === nothing ? nothing : registration.manifest.backend
    manifest_hash = registration === nothing ? nothing : registration.manifest.manifest_hash
    provider = _peo_provider_state(provider_state=provider_state,
        receipt_state=receipt_state, provider_backend=backend,
        provider_manifest_hash=manifest_hash, registry_hash=request.registry_hash,
        request_hash=request.request_hash, receipt_hash=receipt.receipt_hash,
        input_hash=request.input_hash, output_hash=receipt.output_hash,
        provider_status=receipt.status, exit_code=receipt.exit_code,
        failure_code=failure_code)
    _peo_with_state(obligation, obligation.requirement, provider)
end

"""Bind an existing trusted request/receipt, preserving typed rejection state.

This method never calls an executor. Candidate, Genome, context, scenario,
capability, registry, request and receipt are all rechecked against the current
repository-owned trust validators before a receipt is marked validated. The
request input must carry the typed edge identity envelope; the legacy trusted
request shape alone cannot discharge an edge. The complete edge set is also
required so one request/receipt cannot be reused for multiple edges.
"""
function bind_trusted_provider_receipt_v1(
        obligation::PhysicalEdgeObligationV1,
        obligations::Tuple{Vararg{PhysicalEdgeObligationV1}},
        context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4,
        capability::CapabilitySignatureV4,
        request::TrustedProviderDispatchRequestV4,
        receipt::TrustedProviderExecutionReceiptV4)
    canonical_hash(obligation)
    set_ok = try
        validate_obligation_set_v1(context, obligations)
        any(x -> x.identity.identity_hash == obligation.identity.identity_hash,
            obligations)
    catch
        false
    end
    set_ok || return _peo_attempt_state(obligation, request, receipt;
        provider_state=:invalid, failure_code=:typed_obligation_set_invalid)
    edge_input = request.input
    edge_input isa PhysicalEdgeProviderInputV1 ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:invalid, failure_code=:request_missing_edge_identity)
    context_ok = try
        validate_forward_chain_context(context)
        context.candidate_hash == obligation.candidate_hash &&
        context.candidate.canonical_hashes.genome_bundle_hash == obligation.genome_bundle_hash &&
        context.context_hash == obligation.context_hash &&
        context.scenario_hash == obligation.scenario_hash
    catch
        false
    end
    context_ok || return _peo_attempt_state(obligation, request, receipt;
        provider_state=:stale, failure_code=:candidate_or_context_mismatch)

    expected_operator = string(obligation.identity.operator_id, "@",
        obligation.identity.operator_version)
    capability.operator == expected_operator ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:invalid, failure_code=:capability_edge_mismatch)
    capability_hash = canonical_hash(capability)
    requirement = _peo_requirement(obligation.identity, capability)

    input_ok = try
        canonical_hash(edge_input)
        edge_input.edge_identity_hash == obligation.identity.identity_hash &&
        edge_input.candidate_hash == obligation.candidate_hash &&
        edge_input.genome_bundle_hash == obligation.genome_bundle_hash &&
        edge_input.context_hash == obligation.context_hash &&
        edge_input.scenario_hash == obligation.scenario_hash &&
        edge_input.capability_hash == capability_hash &&
        request.input_hash == canonical_hash(edge_input)
    catch
        false
    end
    input_ok || return _peo_attempt_state(obligation, request, receipt;
        provider_state=:stale, failure_code=:edge_bound_provider_input_mismatch)

    request.registry_hash == registry.registry_hash ||
        return _peo_with_state(obligation, requirement,
            _peo_provider_state(provider_state=:foreign, receipt_state=:rejected,
                provider_backend=request.registration === nothing ? nothing : request.registration.manifest.backend,
                provider_manifest_hash=request.registration === nothing ? nothing : request.registration.manifest.manifest_hash,
                registry_hash=request.registry_hash, request_hash=request.request_hash,
                receipt_hash=receipt.receipt_hash, input_hash=request.input_hash,
                output_hash=receipt.output_hash, provider_status=receipt.status,
                exit_code=receipt.exit_code, failure_code=:provider_registry_mismatch))
    request.context_hash == context.context_hash &&
        request.scenario_hash == context.scenario_hash &&
        request.subject_hash == context.subject.physical_subject_hash ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:stale, failure_code=:request_context_mismatch)
    canonical_hash(request.capability) == capability_hash ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:invalid, failure_code=:request_capability_mismatch)
    request.status === :ready_for_dispatch ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:invalid, failure_code=:request_not_dispatchable)
    validate_trusted_provider_dispatch_request(request, registry, context,
        capability, request.input) ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:invalid, failure_code=:request_revalidation_failed)
    validate_trusted_provider_execution_receipt(receipt, request, registry,
        context) ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:foreign, failure_code=:receipt_revalidation_failed)

    registration = request.registration
    registration isa TrustedProviderRegistrationV4 ||
        return _peo_attempt_state(obligation, request, receipt;
            provider_state=:invalid, failure_code=:provider_registration_missing)
    backend = registration.manifest.backend
    manifest_hash = registration.manifest.manifest_hash
    state = receipt.status === :completed && receipt.exit_code == 0 ?
        :completed : receipt.status === :physical_model_screen ? :screen_result : :failed
    provider = _peo_provider_state(provider_state=state,
        receipt_state=:validated, provider_backend=backend,
        provider_manifest_hash=manifest_hash, registry_hash=registry.registry_hash,
        request_hash=request.request_hash, receipt_hash=receipt.receipt_hash,
        input_hash=request.input_hash, output_hash=receipt.output_hash,
        provider_status=receipt.status, exit_code=receipt.exit_code)
    _peo_with_state(obligation, requirement, provider)
end

function _peo_deferred(status, reasons)
    (status=status, activated=false, reasons=Tuple(reasons),
     claim_ceiling=:none, physical_validation=false,
     engineering_validation=false, candidate_discovery_credit=0,
     credible_device_count=0)
end

"""Assess contract closure only; this function never activates Search or awards credit."""
function assess_candidate_obligations_v1(context::ForwardChainContextV4,
        obligations::Tuple{Vararg{PhysicalEdgeObligationV1}};
        unresolved_nonterminals=())
    coverage = try
        validate_obligation_set_v1(context, obligations)
        nothing
    catch
        :typed_obligation_set_invalid
    end
    coverage === nothing || return _peo_deferred(:deferred, (coverage,))
    gaps = try Tuple(_peo_text(g, "compiler unresolved nonterminal") for g in unresolved_nonterminals) catch
        return _peo_deferred(:deferred, (:invalid_compiler_gap_input,))
    end
    isempty(gaps) || return _peo_deferred(:deferred,
        (:compiler_gap_has_no_edge_bound_resolution,))
    isempty(obligations) && return _peo_deferred(:deferred,
        (:candidate_has_no_typed_physical_edge_obligations,))
    any(x -> x.provider.receipt_state !== :validated, obligations) &&
        return _peo_deferred(:deferred, (:provider_receipt_missing_or_rejected,))
    any(x -> x.provider.provider_state !== :completed, obligations) &&
        return _peo_deferred(:deferred, (:provider_did_not_complete,))
    any(x -> x.requirement.match_state !== :matched, obligations) &&
        return _peo_deferred(:deferred, (:capability_signature_not_matched,))
    (status=:contract_ready_unwired, activated=false, reasons=(:shared_compiler_queue_entry_not_wired,),
     claim_ceiling=:none, physical_validation=false,
     engineering_validation=false, candidate_discovery_credit=0,
     credible_device_count=0)
end

"""Explicit Search decision: deferred until a root-owned compiler/queue seam exists."""
function search_activation_disposition_v1(context::ForwardChainContextV4,
        obligations::Tuple{Vararg{PhysicalEdgeObligationV1}};
        unresolved_nonterminals=())
    assessment = assess_candidate_obligations_v1(context, obligations;
        unresolved_nonterminals)
    (status=:deferred, activated=false,
     reason=assessment.status === :contract_ready_unwired ?
        :shared_compiler_queue_entry_not_wired : only(assessment.reasons),
     contract_assessment=assessment, claim_ceiling=:none,
     physical_validation=false, engineering_validation=false,
     candidate_discovery_credit=0, credible_device_count=0)
end

end # module PhysicalEdgeObligationV1Compat
