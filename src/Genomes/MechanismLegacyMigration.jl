"""Fail-closed, declaration-driven bridge from the legacy G1 representation."""

@enum G1LegacyMigrationReasonV1 migration_lossless missing_mapping_resource mapping_not_applicable contract_incompatible legacy_ast_unrepresentable legacy_gene_semantics_unrepresentable legacy_edge_completion_missing canonicalization_budget_exhausted

struct G1LegacyEdgeCompletionV1
    source_edge_id::String
    account_effects::Tuple{Vararg{PortAccountEffectV1}}
    interface_flux_pairs::Tuple{Vararg{InterfaceFluxPairV1}}
    function G1LegacyEdgeCompletionV1(source_edge_id::AbstractString, account_effects, interface_flux_pairs)
        id = invoke(_validated_string, Tuple{AbstractString,AbstractString}, source_edge_id, "legacy source edge id")
        !isempty(id) || throw(ArgumentError("legacy source edge id cannot be empty"))
        account_effects isa Tuple || throw(ArgumentError("legacy account effects must be an immutable tuple"))
        interface_flux_pairs isa Tuple || throw(ArgumentError("legacy interface pairs must be an immutable tuple"))
        effects = account_effects
        pairs = interface_flux_pairs
        all(typeof(x) === PortAccountEffectV1 for x in effects) || throw(ArgumentError("legacy account effects must be typed"))
        all(typeof(x) === InterfaceFluxPairV1 for x in pairs) || throw(ArgumentError("legacy interface pairs must be typed"))
        new(id, effects, pairs)
    end
end

struct _G1LegacyASTUnrepresentable <: Exception end

function _g1_migration_tuple(value::Any, T::Type, field::String)
    value isa Tuple || throw(ArgumentError("$field must be an immutable tuple"))
    all(typeof(x) === T for x in value) || throw(ArgumentError("$field contains an unsealed value"))
    value
end

function _g1_migration_unique(values::Tuple, key::Function, field::String)
    for i in eachindex(values), j in (i + 1):length(values)
        key(values[i]) == key(values[j]) && throw(ArgumentError("$field contains duplicate identities"))
    end
    values
end

function _g1_migration_contract_equal(a::GenomeContractRef, b::GenomeContractRef)
    a.uri == b.uri && a.version == b.version && a.schema_hash.value == b.schema_hash.value &&
        a.canonicalization_hash.value == b.canonicalization_hash.value && a.compatibility_profile == b.compatibility_profile
end

function _g1_migration_type_equal(a::PhysicalType, b::PhysicalType)
    ta, tb = a.temporal_type, b.temporal_type
    clock_equal = (ta.clock_ref === nothing && tb.clock_ref === nothing) ||
        (ta.clock_ref !== nothing && tb.clock_ref !== nothing && ta.clock_ref.id == tb.clock_ref.id && ta.clock_ref.version == tb.clock_ref.version)
    a.value_kind == b.value_kind && a.tensor_rank == b.tensor_rank && a.spatial_dimension == b.spatial_dimension &&
        ta.kind == tb.kind && ta.derivative_order == tb.derivative_order && clock_equal && a.units.exponents == b.units.exponents
end

function _g1_migration_ref_key(ref::QualifiedRefV1)
    (ref.id, ref.version)
end

function _g1_migration_completion_wire(x::G1LegacyEdgeCompletionV1)
    effects = sort(String[invoke(_mimo_closed_effect, Tuple{PortAccountEffectV1}, y) for y in x.account_effects])
    pairs = sort(String[invoke(_mimo_closed_pair, Tuple{InterfaceFluxPairV1}, y) for y in x.interface_flux_pairs])
    "{\"effects\":[" * join(effects, ",") * "],\"pairs\":[" * join(pairs, ",") * "]}"
end

function _g1_migration_gene_wire(x::Any)
    typeof(x) === StateGeneV1 && return invoke(canonical_json, Tuple{StateGeneV1}, x)
    typeof(x) === InvariantV1 && return invoke(canonical_json, Tuple{InvariantV1}, x)
    typeof(x) === ParameterGeneV1 && return invoke(canonical_json, Tuple{ParameterGeneV1}, x)
    typeof(x) === SymmetryGeneV1 && return invoke(canonical_json, Tuple{SymmetryGeneV1}, x)
    typeof(x) === ObservableGeneV1 && return invoke(_g1_observable_canonical_bytes, Tuple{ObservableGeneV1}, x)
    typeof(x) === TypedOperatorHoleV1 && return invoke(canonical_json, Tuple{TypedOperatorHoleV1}, x)
    throw(ArgumentError("legacy mapping contains an unsealed gene"))
end

function _g1_migration_declaration_content_hash(source_hash::Digest256, target::GenomeContractRef,
                                    states::Tuple, invariants::Tuple, parameters::Tuple,
                                    symmetries::Tuple, observables::Tuple, holes::Tuple,
                                    completions::Tuple)
    genes = String[]
    for values in (states, invariants, parameters, symmetries, observables, holes)
        append!(genes, String[invoke(_g1_migration_gene_wire, Tuple{Any}, x) for x in values])
    end
    sort!(genes)
    # Completion source ids are local locators and are not serialized.  Their
    # deterministic ordinal is retained so reassigning two ledgers to two
    # source edges cannot collapse to one mapping hash.
    completion_records = Tuple{String,String}[(x.source_edge_id,
        invoke(_g1_migration_completion_wire, Tuple{G1LegacyEdgeCompletionV1}, x)) for x in completions]
    sort!(completion_records, by=x -> x[1])
    edge_wires = String["{\"slot\":" * string(i) * ",\"completion\":" * x[2] * "}" for (i, x) in enumerate(completion_records)]
    payload = "{\"source_mechanism_hash\":" * _g1_layer_digest(source_hash) * ",\"target_contract\":" *
        invoke(_g1_transport_contract, Tuple{GenomeContractRef}, target) * ",\"genes\":[" * join(genes, ",") *
        "],\"edge_completions\":[" * join(edge_wires, ",") * "]}"
    Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits("fusionconceptai:v4:g1-legacy-declaration-content:v1|" * payload)))))
end

struct G1LegacyMigrationDeclarationV1
    mapping_ref::QualifiedRefV1
    source_mechanism_hash::Digest256
    target_contract_ref::GenomeContractRef
    states::Tuple{Vararg{StateGeneV1}}
    invariants::Tuple{Vararg{InvariantV1}}
    parameters::Tuple{Vararg{ParameterGeneV1}}
    symmetries::Tuple{Vararg{SymmetryGeneV1}}
    observables::Tuple{Vararg{ObservableGeneV1}}
    operator_holes::Tuple{Vararg{TypedOperatorHoleV1}}
    edge_completions::Tuple{Vararg{G1LegacyEdgeCompletionV1}}
    declaration_content_hash::Digest256
    function G1LegacyMigrationDeclarationV1(mapping_ref::QualifiedRefV1, source_mechanism_hash::Digest256,
            target_contract_ref::GenomeContractRef, states, invariants, parameters, symmetries, observables,
            operator_holes, edge_completions)
        mapping_ref isa QualifiedRefV1 || throw(ArgumentError("mapping_ref must be QualifiedRefV1"))
        source_mechanism_hash isa Digest256 || throw(ArgumentError("source_mechanism_hash must be Digest256"))
        target_contract_ref isa GenomeContractRef || throw(ArgumentError("target_contract_ref must be GenomeContractRef"))
        st = invoke(_g1_migration_tuple, Tuple{Any,Type,String}, states, StateGeneV1, "legacy states")
        iv = invoke(_g1_migration_tuple, Tuple{Any,Type,String}, invariants, InvariantV1, "legacy invariants")
        pa = invoke(_g1_migration_tuple, Tuple{Any,Type,String}, parameters, ParameterGeneV1, "legacy parameters")
        sy = invoke(_g1_migration_tuple, Tuple{Any,Type,String}, symmetries, SymmetryGeneV1, "legacy symmetries")
        ob = invoke(_g1_migration_tuple, Tuple{Any,Type,String}, observables, ObservableGeneV1, "legacy observables")
        ho = invoke(_g1_migration_tuple, Tuple{Any,Type,String}, operator_holes, TypedOperatorHoleV1, "legacy operator holes")
        ec = invoke(_g1_migration_tuple, Tuple{Any,Type,String}, edge_completions, G1LegacyEdgeCompletionV1, "legacy edge completions")
        invoke(_g1_migration_unique, Tuple{Tuple,Function,String}, st, x -> x.state_ref.value, "legacy states")
        invoke(_g1_migration_unique, Tuple{Tuple,Function,String}, iv, x -> x.invariant_ref.value, "legacy invariants")
        invoke(_g1_migration_unique, Tuple{Tuple,Function,String}, pa, x -> x.ref.value, "legacy parameters")
        invoke(_g1_migration_unique, Tuple{Tuple,Function,String}, sy, x -> x.ref.value, "legacy symmetries")
        invoke(_g1_migration_unique, Tuple{Tuple,Function,String}, ob, x -> x.observable_ref.value, "legacy observables")
        invoke(_g1_migration_unique, Tuple{Tuple,Function,String}, ho, x -> x.hole_ref.value, "legacy operator holes")
        invoke(_g1_migration_unique, Tuple{Tuple,Function,String}, ec, x -> x.source_edge_id, "legacy edge completions")
        hash = invoke(_g1_migration_declaration_content_hash, Tuple{Digest256,GenomeContractRef,Tuple,Tuple,Tuple,Tuple,Tuple,Tuple,Tuple},
            source_mechanism_hash, target_contract_ref, st, iv, pa, sy, ob, ho, ec)
        new(mapping_ref, source_mechanism_hash, target_contract_ref, st, iv, pa, sy, ob, ho, ec, hash)
    end
end

struct G1LegacyMigrationResultV1
    resolution::ResolutionStatus
    genome::Union{Nothing,MechanismGenomeV4}
    source_mechanism_hash::Union{Nothing,Digest256}
    mapping_ref::Union{Nothing,QualifiedRefV1}
    mapping_hash::Union{Nothing,Digest256}
    declaration_content_hash::Union{Nothing,Digest256}
    reason::G1LegacyMigrationReasonV1
    function G1LegacyMigrationResultV1(source::LegacyMechanismGenomeV4,
                                       declaration::Union{Nothing,G1LegacyMigrationDeclarationV1},
                                       context::MechanismCanonicalizationContextV1,
                                       registry::OperatorRegistryV1)
        outcome = invoke(_g1_migration_evaluate,
            Tuple{LegacyMechanismGenomeV4,Union{Nothing,G1LegacyMigrationDeclarationV1},MechanismCanonicalizationContextV1,OperatorRegistryV1},
            source, declaration, context, registry)
        resolution = outcome.resolution
        payload = outcome.payload
        canonical = outcome.canonical
        source_hash = outcome.source_mechanism_hash
        mapping_ref = outcome.mapping_ref
        mapping_hash = outcome.mapping_hash
        declaration_content_hash = outcome.declaration_content_hash
        reason = outcome.reason
        resolution === resolved && (reason === migration_lossless && payload isa MechanismGenomePayloadV1 &&
            canonical isa CanonicalMechanismV1 && source_hash isa Digest256 && mapping_ref isa QualifiedRefV1 &&
            mapping_hash isa Digest256 && declaration_content_hash isa Digest256 ||
            throw(ArgumentError("resolved legacy result is incomplete or not lossless")))
        resolution === terminal_deferred && (reason !== migration_lossless && payload === nothing && canonical === nothing && mapping_hash === nothing ||
            throw(ArgumentError("deferred legacy result is not a proven gap")))
        genome = resolution === resolved ? MechanismGenomeV4(source.seed, context.contract_ref, payload;
            profile=context.profile) : nothing
        resolution === resolved && (genome.canonical.hashes == canonical.hashes ||
            throw(ArgumentError("resolved legacy genome hashes do not match migration outcome")))
        new(resolution, genome, source_hash, mapping_ref, mapping_hash, declaration_content_hash, reason)
    end
    function G1LegacyMigrationResultV1(args...)
        throw(ArgumentError("legacy migration result is sealed; use migrate_legacy_g1"))
    end
end

function _g1_migration_outcome(resolution::ResolutionStatus, payload,
                               canonical, source_hash::Union{Nothing,Digest256},
                               mapping_ref, mapping_hash, declaration_content_hash,
                               reason::G1LegacyMigrationReasonV1)
    (resolution=resolution, payload=payload, canonical=canonical,
     source_mechanism_hash=source_hash, mapping_ref=mapping_ref,
     mapping_hash=mapping_hash, declaration_content_hash=declaration_content_hash, reason=reason)
end

function _g1_migration_deferred(source_hash::Union{Nothing,Digest256},
                                decl::Union{Nothing,G1LegacyMigrationDeclarationV1},
                                reason::G1LegacyMigrationReasonV1)
    invoke(_g1_migration_outcome,
        Tuple{ResolutionStatus,Any,Any,Union{Nothing,Digest256},Any,Any,Any,G1LegacyMigrationReasonV1},
        terminal_deferred, nothing, nothing, source_hash,
        decl === nothing ? nothing : decl.mapping_ref,
        nothing, decl === nothing ? nothing : decl.declaration_content_hash, reason)
end

function _g1_migration_edge_completion(decl::G1LegacyMigrationDeclarationV1, id::String)
    matches = [x for x in decl.edge_completions if x.source_edge_id == id]
    length(matches) == 1 ? matches[1] : nothing
end

function _g1_migration_validate_completion_closure(source::LegacyMechanismGenomeV4,
                                                   decl::G1LegacyMigrationDeclarationV1)::Union{Nothing,Bool}
    source_ids = String[]
    for edge in source.graph.hyperedges
        (typeof(edge) === TypedHyperedge || typeof(edge) === AtomicMIMOHyperedgeV1) ||
            return nothing
        push!(source_ids, edge.edge_id)
    end
    declared_ids = String[x.source_edge_id for x in decl.edge_completions]
    # The declaration constructor already rejects duplicate declared ids.  An
    # extra id is malformed; a missing id is a declared, deferred gap.
    all(id -> id in source_ids, declared_ids) || throw(ArgumentError("legacy completion references an unknown source edge"))
    all(id -> id in declared_ids, source_ids)
end

function _g1_migration_legacy_ast_supported(source::LegacyMechanismGenomeV4)::Bool
    for edge in source.graph.hyperedges
        typeof(edge) === TypedHyperedge || continue
        invoke(_g1_migration_check_legacy_ast, Tuple{TypedAST}, edge.ast) || return false
    end
    true
end

function _g1_migration_gene_set_equal(source_values::Tuple, target_values::Tuple,
                                      T::Type)::Bool
    isempty(source_values) && return true
    all(typeof(x) === T for x in source_values) || return false
    length(source_values) == length(target_values) || return false
    source_wire = sort(String[invoke(_g1_migration_gene_wire, Tuple{Any}, x) for x in source_values])
    target_wire = sort(String[invoke(_g1_migration_gene_wire, Tuple{Any}, x) for x in target_values])
    source_wire == target_wire
end

function _g1_migration_check_legacy_ast(ast::TypedAST)
    for n in ast.nodes
        if n.opcode === :parameter
            hasproperty(n.parameters, :name) && typeof(getproperty(n.parameters, :name)) === Symbol || return false
        elseif n.opcode === :constant
            hasproperty(n.parameters, :value) || return false
        end
    end
    true
end

function _g1_migration_convert_edge(edge::TypedHyperedge,
                                    decl::G1LegacyMigrationDeclarationV1,
                                    registry::OperatorRegistryV1)
    completion = invoke(_g1_migration_edge_completion, Tuple{G1LegacyMigrationDeclarationV1,String}, decl, edge.edge_id)
    completion === nothing && return nothing
    role = if edge.role === :governing
        governing
    elseif edge.role === :additive
        additive
    elseif edge.role === :constraint
        constraint
    elseif edge.role === :interface
        interface
    else
        return nothing
    end
    role === interface && isempty(completion.interface_flux_pairs) && return nothing
    role !== interface && !isempty(completion.interface_flux_pairs) &&
        throw(ArgumentError("non-interface legacy edge cannot carry an interface pair"))
    program = try
        invoke(TypedASTProgramV1, Tuple{TypedAST}, edge.ast; registry=registry)
    catch e
        e isa ArgumentError && throw(_G1LegacyASTUnrepresentable())
        rethrow()
    end
    old_bindings = String["$(b[1].qualified.id)\u001f$(b[1].qualified.version)\u001f$(b[2].value)" for b in edge.ast.manifest_bindings]
    new_bindings = String["$(b[1].qualified.id)\u001f$(b[1].qualified.version)\u001f$(b[2].value)" for b in program.used_manifest_bindings]
    sort!(old_bindings); sort!(new_bindings); old_bindings == new_bindings || throw(_G1LegacyASTUnrepresentable())
    inputs = Tuple(MIMOInputBindingV1(i, node_ref) for (i, node_ref) in enumerate(edge.inputs))
    outputs = (MIMOOutputBindingV1(1, edge.outputs[1]),)
    AtomicMIMOHyperedgeV1(edge.edge_id, inputs, outputs, program, role;
        account_effects=completion.account_effects, interface_flux_pairs=completion.interface_flux_pairs, registry=registry)
end

function _g1_migration_convert_graph(source::LegacyMechanismGenomeV4,
                                     decl::G1LegacyMigrationDeclarationV1,
                                     registry::OperatorRegistryV1)
    edges = AtomicMIMOHyperedgeV1[]
    for edge in source.graph.hyperedges
        if typeof(edge) === TypedHyperedge
            converted = invoke(_g1_migration_convert_edge, Tuple{TypedHyperedge,G1LegacyMigrationDeclarationV1,OperatorRegistryV1}, edge, decl, registry)
            converted === nothing && return nothing
            push!(edges, converted)
        elseif typeof(edge) === AtomicMIMOHyperedgeV1
            completion = invoke(_g1_migration_edge_completion, Tuple{G1LegacyMigrationDeclarationV1,String}, decl, edge.edge_id)
            completion === nothing && return nothing
            edge.role === interface && isempty(completion.interface_flux_pairs) && return nothing
            edge.role !== interface && !isempty(completion.interface_flux_pairs) &&
                throw(ArgumentError("non-interface legacy completion cannot carry an interface pair"))
            existing_effects = String[invoke(_mimo_closed_effect, Tuple{PortAccountEffectV1}, x) for x in edge.account_effects]
            declared_effects = String[invoke(_mimo_closed_effect, Tuple{PortAccountEffectV1}, x) for x in completion.account_effects]
            sort!(existing_effects); sort!(declared_effects)
            existing_effects == declared_effects || isempty(existing_effects) ||
                throw(ArgumentError("legacy completion changes an existing atomic ledger"))
            existing_pairs = String[invoke(_mimo_closed_pair, Tuple{InterfaceFluxPairV1}, x) for x in edge.interface_flux_pairs]
            declared_pairs = String[invoke(_mimo_closed_pair, Tuple{InterfaceFluxPairV1}, x) for x in completion.interface_flux_pairs]
            sort!(existing_pairs); sort!(declared_pairs)
            existing_pairs == declared_pairs || isempty(existing_pairs) ||
                throw(ArgumentError("legacy completion changes an existing interface pair"))
            push!(edges, AtomicMIMOHyperedgeV1(edge.edge_id, edge.input_bindings, edge.output_bindings, edge.program, edge.role;
                account_effects=completion.account_effects, interface_flux_pairs=completion.interface_flux_pairs, registry=registry))
        else
            return nothing
        end
    end
    TypedOperatorHypergraphV1(source.graph.nodes, Tuple(edges); registry=registry)
end

function _g1_migration_parameter_closure(programs::Vector{TypedASTProgramV1}, parameters::Tuple)
    used = falses(length(parameters))
    for program in programs, node in program.nodes
        if typeof(node) === ASTParameterV1
            name = String(node.name)
            hits = findall(x -> x.ref.value == name, parameters)
            length(hits) == 1 || throw(ArgumentError("legacy AST parameter has no unique gene"))
            gene = parameters[hits[1]]
            expected = PhysicalType(:scalar_parameter, 0, 0, TemporalTypeV1(static_time), gene.unit)
            _g1_migration_type_equal(node.output_type, expected) || throw(ArgumentError("legacy AST parameter type is not exact"))
            used[hits[1]] = true
        end
    end
    all(used) || throw(ArgumentError("legacy parameter gene is dangling"))
end

function _g1_migration_gene_closure(payload::MechanismGenomePayloadV1, source::LegacyMechanismGenomeV4,
                                    decl::G1LegacyMigrationDeclarationV1)
    node_ids = String[n.node_id for n in payload.operator_graph.nodes]
    edge_ids = String[invoke(_g1_payload_edge_id, Tuple{Any}, e) for e in payload.operator_graph.hyperedges]
    state_ids = String[x.state_ref.value for x in decl.states]
    all(x -> x in node_ids, state_ids) || throw(ArgumentError("legacy state gene is not bound to a graph node"))
    for state in decl.states
        all(r -> any(y -> y.ref.value == r.value, decl.symmetries), state.gauge_refs) || throw(ArgumentError("legacy gauge reference is dangling"))
        all(r -> r.value in edge_ids, state.constraint_refs) || throw(ArgumentError("legacy constraint reference is dangling"))
    end
    invoke(_g1_payload_parity_generator_closure, Tuple{Tuple,Tuple}, decl.states, decl.symmetries) ||
        throw(ArgumentError("legacy parity action does not bind an exact symmetry generator and state action"))
    for invariant in decl.invariants
        all(t -> t.state_ref.value in state_ids, invariant.terms) || throw(ArgumentError("legacy invariant state reference is dangling"))
        if invariant.scope !== scope_global
            invariant.scope_ref === nothing && throw(ArgumentError("legacy scoped invariant is missing scope_ref"))
            node_matches = count(==(invariant.scope_ref.id), node_ids)
            edge_matches = count(==(invariant.scope_ref.id), edge_ids)
            node_matches + edge_matches == 1 || throw(ArgumentError("legacy invariant scope_ref is ambiguous or dangling"))
        end
    end
    for observable in decl.observables
        root_edge_id = observable.expression_root.operator_site_ref.value
        root_edge_id in edge_ids || throw(ArgumentError("legacy observable root is dangling"))
        edge = only(Tuple(e for e in payload.operator_graph.hyperedges if e.edge_id == root_edge_id))
        1 <= observable.expression_root.root_position <= length(edge.output_bindings) ||
            throw(ArgumentError("legacy observable root position is dangling"))
    end
    for hole in decl.operator_holes
        all(r -> r.value in state_ids, hole.ordered_input_state_refs) || throw(ArgumentError("legacy hole state reference is dangling"))
        all(r -> any(o -> o.observable_ref.value == r.value, decl.observables), hole.observable_refs) || throw(ArgumentError("legacy hole observable reference is dangling"))
    end
end

# Legacy provenance is computed through this closed encoder rather than the
# package-wide canonical_json/canonical_hash fallback.  Unknown legacy values
# are deliberately outside the lossless migration proof boundary.
function _g1_migration_closed_pairs(items::Vector{Tuple{String,String}})::String
    names = String[x[1] for x in items]
    length(unique(names)) == length(names) || throw(ArgumentError("legacy source object has duplicate keys"))
    order = sortperm(names)
    "{" * join((_g1_migration_quote(names[i]) * ":" * items[i][2] for i in order), ",") * "}"
end

_g1_migration_quote(x::String)::String = invoke(_jsonquote, Tuple{AbstractString}, x)
function _g1_migration_array(values::Vector{String}, raw::Bool=false)::String
    encoded = raw ? values : String[_g1_migration_quote(v) for v in values]
    "{\"shape\":[" * string(length(values)) * "],\"values\":[" * join(encoded, ",") * "]}"
end

function _g1_migration_closed_value(x::Any)::String
    x === nothing && return "null"
    typeof(x) === Bool && return x ? "true" : "false"
    typeof(x) === String && return invoke(_g1_migration_quote, Tuple{String}, x)
    typeof(x) === Symbol && return invoke(_g1_migration_quote, Tuple{String}, String(x))
    typeof(x) in _P0_SAFE_INTEGER_TYPES && return string(x)
    if typeof(x) in _P0_SAFE_FLOAT_TYPES
        return invoke(_canonical_float, Tuple{AbstractFloat}, x)
    end
    if typeof(x) <: Rational
        num, den = numerator(x), denominator(x)
        typeof(num) in _P0_SAFE_INTEGER_TYPES && typeof(den) in _P0_SAFE_INTEGER_TYPES ||
            throw(CanonicalizationDeferred("legacy source has an unsafe rational"))
        return _g1_migration_closed_pairs([("denominator", string(den)), ("numerator", string(num))])
    end
    x isa Enum && return invoke(_g1_migration_quote, Tuple{String}, String(Symbol(x)))
    x isa Tuple && return "[" * join(String[invoke(_g1_migration_closed_value, Tuple{Any}, v) for v in x], ",") * "]"
    x isa NamedTuple && return invoke(_g1_migration_closed_pairs, Tuple{Vector{Tuple{String,String}}},
        Tuple{String,String}[(String(k), invoke(_g1_migration_closed_value, Tuple{Any}, getfield(x, k))) for k in keys(x)])
    if typeof(x) === Digest256
        return invoke(_g1_migration_closed_value, Tuple{Any}, (value=x.value,))
    elseif typeof(x) === UnitSignature
        return invoke(_g1_migration_closed_value, Tuple{Any}, (exponents=x.exponents,))
    elseif typeof(x) === QualifiedRefV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (id=x.id, version=x.version))
    elseif typeof(x) === ConservationLedgerIdentityV1
        return invoke(_g1_migration_closed_value, Tuple{Any},
            (account_kind_ref=x.account_kind_ref, ontology_hash=x.ontology_hash, unit=x.unit))
    elseif typeof(x) === GenomeContractRef
        return invoke(_g1_migration_closed_value, Tuple{Any}, (uri=x.uri, version=x.version, schema_hash=x.schema_hash,
            canonicalization_hash=x.canonicalization_hash, compatibility_profile=x.compatibility_profile))
    elseif typeof(x) === OperatorRefV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (qualified=x.qualified,))
    elseif typeof(x) === TemporalTypeV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (kind=x.kind, derivative_order=x.derivative_order, clock_ref=x.clock_ref))
    elseif typeof(x) === PhysicalType
        return invoke(_g1_migration_closed_value, Tuple{Any}, (value_kind=x.value_kind, tensor_rank=x.tensor_rank,
            spatial_dimension=x.spatial_dimension, temporal_type=x.temporal_type, units=x.units))
    elseif typeof(x) === TypedNode
        return invoke(_g1_migration_closed_value, Tuple{Any}, (node_kind=x.node_kind, physical_type=x.physical_type))
    elseif typeof(x) === TypedASTNode
        return invoke(_g1_migration_closed_value, Tuple{Any}, (opcode=x.opcode, inputs=x.inputs, output_type=x.output_type, parameters=x.parameters))
    elseif typeof(x) === TypedAST
        return invoke(_g1_migration_closed_value, Tuple{Any}, (nodes=x.nodes, root=x.root, input_ports=x.input_ports,
            manifest_bindings=x.manifest_bindings))
    elseif typeof(x) === TypedASTProgramV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, invoke(_ast_program_semantic_payload,
            Tuple{TypedASTProgramV1}, x))
    elseif typeof(x) === OperatorParameterSpecV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (name=x.name, type_tag=x.type_tag, required=x.required))
    elseif typeof(x) === StateGeneRefV1 || typeof(x) === InvariantRefV1 ||
           typeof(x) === ParameterRefV1 || typeof(x) === SymmetryRefV1 ||
           typeof(x) === ObservableRefV1 || typeof(x) === OperatorSiteRefV1 ||
           typeof(x) === ConstraintRefV1 || typeof(x) === HoleRefV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (value=x.value,))
    elseif typeof(x) === ExactFiniteIntervalV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (lower=x.lower, upper=x.upper, allow_equal=x.allow_equal))
    elseif typeof(x) === QuantityIntervalV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (interval=x.interval, unit=x.unit))
    elseif typeof(x) === NonnegativeQuantityV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (value=x.value, unit=x.unit))
    elseif typeof(x) === ExactRationalMatrixV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (rows=x.rows,))
    elseif typeof(x) === ParityActionV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (generator_ref=x.generator_ref, sign=x.sign))
    elseif typeof(x) === StateGeneV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (state_ref=x.state_ref, physical_type=x.physical_type,
            physical_bounds=x.physical_bounds, parity_actions=x.parity_actions,
            gauge_refs=x.gauge_refs, constraint_refs=x.constraint_refs, epistemic_state=x.epistemic_state))
    elseif typeof(x) === InvariantTermV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (state_ref=x.state_ref, coefficient=x.coefficient))
    elseif typeof(x) === InvariantV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (invariant_ref=x.invariant_ref, ledger_identity=x.ledger_identity,
            scope=x.scope, scope_ref=x.scope_ref, terms=x.terms, allowed_source_refs=x.allowed_source_refs,
            allowed_sink_refs=x.allowed_sink_refs, boundary_flux_refs=x.boundary_flux_refs,
            tolerance_log10=x.tolerance_log10, entropy_direction=x.entropy_direction))
    elseif typeof(x) === ParameterTransformSpecV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (kind=x.kind, scale=x.scale))
    elseif typeof(x) === ParameterGeneV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (ref=x.ref, unit=x.unit, transform=x.transform,
            bounds=x.bounds, normalized_gene=x.normalized_gene))
    elseif typeof(x) === StateSymmetryActionV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (state_ref=x.state_ref, matrix=x.matrix))
    elseif typeof(x) === SymmetryGeneV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (ref=x.ref, group_kind=x.group_kind,
            generator_ref=x.generator_ref, coordinate_generator_matrix=x.coordinate_generator_matrix, state_actions=x.state_actions,
            group_order=x.group_order, behavior=x.behavior, tolerance=x.tolerance))
    elseif typeof(x) === ProgramRootRefV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (operator_site_ref=x.operator_site_ref,
            root_position=x.root_position, declared_type=x.declared_type))
    elseif typeof(x) === ObservableGeneV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (observable_ref=x.observable_ref, expression_root=x.expression_root,
            intervention_ref=x.intervention_ref, sampling_program=x.sampling_program,
            expected_effect_interval=x.expected_effect_interval, noise_model_ref=x.noise_model_ref,
            noise_floor=x.noise_floor, numerical_floor=x.numerical_floor,
            minimum_effect_size=x.minimum_effect_size, competing_prediction_refs=x.competing_prediction_refs))
    elseif typeof(x) === HoleComplexityBudgetV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (max_ast_nodes=x.max_ast_nodes,
            max_derivative_order=x.max_derivative_order, max_memory_length=x.max_memory_length,
            max_free_parameters=x.max_free_parameters, max_free_functions=x.max_free_functions,
            max_suboperators=x.max_suboperators))
    elseif typeof(x) === IdentifiabilityConditionV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (intervention_ref=x.intervention_ref,
            observable_ref=x.observable_ref, minimum_effect=x.minimum_effect,
            noise_and_numerical_floor=x.noise_and_numerical_floor))
    elseif typeof(x) === TypedOperatorHoleV1
        return invoke(_g1_migration_closed_value, Tuple{Any}, (hole_ref=x.hole_ref, ordered_input_state_refs=x.ordered_input_state_refs,
            ordered_output_types=x.ordered_output_types, causal_direction_ref=x.causal_direction_ref,
            allowed_effects=x.allowed_effects, forbidden_effects=x.forbidden_effects,
            complexity_budget=x.complexity_budget, null_model_ref=x.null_model_ref,
            alternative_model_refs=x.alternative_model_refs, identifiability_conditions=x.identifiability_conditions,
            observable_refs=x.observable_refs, out_of_sample_prediction_refs=x.out_of_sample_prediction_refs))
    end
    throw(CanonicalizationDeferred("legacy source value has no closed identity encoder"))
end

function _g1_migration_closed_graph_encoding(graph::TypedOperatorHypergraphV1,
                                             order::Tuple)::String
    rank = zeros(Int, length(graph.nodes))
    for (j, old) in enumerate(order); rank[old] = j; end
    nodes = String[invoke(_g1_migration_closed_value, Tuple{Any}, (node_kind=graph.nodes[i].node_kind,
        physical_type=graph.nodes[i].physical_type)) for i in order]
    edges = String[]
    for edge in graph.hyperedges
        if typeof(edge) === TypedHyperedge
            ins = String[string(rank[i]) for i in edge.inputs]; outs = String[string(rank[i]) for i in edge.outputs]
            push!(edges, invoke(_g1_migration_closed_pairs, Tuple{Vector{Tuple{String,String}}}, [
                ("ast", invoke(_g1_migration_closed_value, Tuple{Any}, edge.ast)),
                ("inputs", _g1_migration_array(ins, true)),
                ("outputs", _g1_migration_array(outs, true)),
                ("role", invoke(_g1_migration_closed_value, Tuple{Any}, edge.role))]))
        elseif typeof(edge) === AtomicMIMOHyperedgeV1
            ins = String["{\"graph_node\":" * string(rank[b.graph_node_index]) *
                ",\"program_position\":" * string(b.program_position) * "}" for b in edge.input_bindings]
            outs = String["{\"graph_node\":" * string(rank[b.graph_node_index]) *
                ",\"program_position\":" * string(b.program_position) * "}" for b in edge.output_bindings]
            effects = String[invoke(_mimo_closed_effect, Tuple{PortAccountEffectV1}, e) for e in edge.account_effects]
            pairs = String[invoke(_mimo_closed_pair, Tuple{InterfaceFluxPairV1}, p) for p in edge.interface_flux_pairs]
            push!(edges, invoke(_g1_migration_closed_pairs, Tuple{Vector{Tuple{String,String}}}, [
                ("account_effects", "[" * join(effects, ",") * "]"),
                ("input_bindings", "[" * join(ins, ",") * "]"),
                ("interface_flux_pairs", "[" * join(pairs, ",") * "]"),
                ("output_bindings", "[" * join(outs, ",") * "]"),
                ("program_hash", invoke(_g1_migration_quote, Tuple{String}, edge.program_hash.value)),
                ("role", invoke(_g1_migration_quote, Tuple{String}, String(Symbol(edge.role))))]))
        else
            throw(CanonicalizationDeferred("legacy source graph edge has no closed identity"))
        end
    end
    sort!(edges)
    invoke(_g1_migration_closed_pairs, Tuple{Vector{Tuple{String,String}}}, [
        ("canonicalization_version", invoke(_g1_migration_quote, Tuple{String}, "1")),
        ("domain", invoke(_g1_migration_quote, Tuple{String}, "fusionconceptai:v4:typed-operator-hypergraph:v1")),
        ("nodes", _g1_migration_array(nodes)),
        ("hyperedges", _g1_migration_array(edges))])
end

function _g1_migration_source_refinement_colors(graph::TypedOperatorHypergraphV1,
                                                max_rounds::Int)::Vector{String}
    colors = String[invoke(_g1_migration_digest, Tuple{String}, invoke(_g1_migration_closed_value, Tuple{Any},
        (node_kind=graph.nodes[i].node_kind, physical_type=graph.nodes[i].physical_type))) for i in eachindex(graph.nodes)]
    max_rounds > 0 || throw(CanonicalizationDeferred("legacy source refinement budget exhausted"))
    for _ in 1:min(12, max_rounds)
        next = String[]
        for i in eachindex(graph.nodes)
            incident = String[]
            for edge in graph.hyperedges
                inputs, outputs, role = if typeof(edge) === TypedHyperedge
                    (edge.inputs, edge.outputs, String(edge.role))
                elseif typeof(edge) === AtomicMIMOHyperedgeV1
                    (Tuple(x.graph_node_index for x in edge.input_bindings),
                     Tuple(x.graph_node_index for x in edge.output_bindings), String(Symbol(edge.role)))
                else
                    throw(CanonicalizationDeferred("legacy source graph edge has no closed identity"))
                end
                if i in inputs || i in outputs
                    push!(incident, role * "|" * join(String[colors[j] for j in inputs], ",") * "|" *
                        join(String[colors[j] for j in outputs], ","))
                end
            end
            sort!(incident)
            push!(next, invoke(_g1_migration_digest, Tuple{String}, colors[i] * "|" * join(incident, ";")))
        end
        next == colors && return colors
        colors = next
    end
    colors
end

function _g1_migration_digest(value::String)::String
    bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(value))))
end

function _g1_migration_graph_wire(graph::TypedOperatorHypergraphV1,
                                  profile::Union{Nothing,CanonicalizationProfileV1})::String
    n = length(graph.nodes)
    n > 0 || throw(CanonicalizationDeferred("legacy source graph has no nodes"))
    if profile !== nothing
        incidence_vertices = n
        for edge in graph.hyperedges
            if typeof(edge) === TypedHyperedge
                incidence_vertices += 1 + length(edge.inputs) + length(edge.outputs)
            elseif typeof(edge) === AtomicMIMOHyperedgeV1
                incidence_vertices += 1 + length(edge.input_bindings) + length(edge.output_bindings)
            else
                throw(CanonicalizationDeferred("legacy source graph edge has no closed identity"))
            end
        end
        incidence_vertices <= profile.budget.max_vertices ||
            throw(CanonicalizationDeferred("legacy source graph vertex budget exhausted"))
    end
    max_rounds = profile === nothing ? 12 : profile.budget.max_refinement_rounds
    colors = invoke(_g1_migration_source_refinement_colors,
        Tuple{TypedOperatorHypergraphV1,Int}, graph, max_rounds)
    # The one-argument provenance helper is the compatibility identity API;
    # its caller has no execution budget.  Context-bound migration supplies
    # the real budget and is the only path that can return a budget gap.
    budget = profile === nothing ? 10_000_000 : profile.budget.max_search_nodes
    # The pre-existing legacy canonical hash uses full labeling for small
    # graphs.  Retain that exact byte grammar there; the boundary below is a
    # performance/proof budget, not an n<=8 semantic cutoff.
    if n > 8 && length(unique(colors)) == n
        result = invoke(_g1_migration_closed_graph_encoding, Tuple{TypedOperatorHypergraphV1,Tuple}, graph, Tuple(sortperm(colors)))
        profile === nothing || ncodeunits(result) <= profile.budget.max_bytes ||
            throw(CanonicalizationDeferred("legacy source graph byte budget exhausted"))
        return result
    end
    best = Ref{Union{Nothing,String}}(nothing)
    visits = Ref(0)
    order = collect(1:n)
    function visit(k)
        visits[] += 1
        visits[] <= budget || throw(CanonicalizationDeferred("legacy source graph exact search budget exhausted"))
        if k > n
            candidate = invoke(_g1_migration_closed_graph_encoding, Tuple{TypedOperatorHypergraphV1,Tuple}, graph, Tuple(order))
            best[] === nothing && (best[] = candidate)
            best[] !== nothing && candidate < best[] && (best[] = candidate)
            return
        end
        for j in k:n
            order[k], order[j] = order[j], order[k]
            visit(k + 1)
            order[k], order[j] = order[j], order[k]
        end
    end
    visit(1)
    best[] === nothing && throw(CanonicalizationDeferred("legacy source graph exact search produced no witness"))
    result = best[]::String
    profile === nothing || ncodeunits(result) <= profile.budget.max_bytes ||
        throw(CanonicalizationDeferred("legacy source graph byte budget exhausted"))
    result
end

function _g1_migration_source_wire(source::LegacyMechanismGenomeV4,
                                   profile::Union{Nothing,CanonicalizationProfileV1})::String
    graph_wire = invoke(_g1_migration_graph_wire, Tuple{TypedOperatorHypergraphV1,Union{Nothing,CanonicalizationProfileV1}}, source.graph, profile)
    result = invoke(_g1_migration_closed_pairs, Tuple{Vector{Tuple{String,String}}}, [
        ("contract_ref", invoke(_g1_migration_closed_value, Tuple{Any}, source.contract_ref)),
        ("graph", graph_wire),
        ("invariants", invoke(_g1_migration_closed_value, Tuple{Any}, source.invariants)),
        ("observables", invoke(_g1_migration_closed_value, Tuple{Any}, source.observables))])
    profile === nothing || ncodeunits(result) <= profile.budget.max_bytes ||
        throw(CanonicalizationDeferred("legacy source byte budget exhausted"))
    result
end

function _g1_migration_source_hash(source::LegacyMechanismGenomeV4)::Digest256
    # Compatibility/provenance helper only.  migrate_legacy_g1 always uses
    # the context-bound overload below so its budgets are authoritative.
    wire = invoke(_g1_migration_source_wire, Tuple{LegacyMechanismGenomeV4,Union{Nothing,CanonicalizationProfileV1}}, source, nothing)
    Digest256(invoke(_g1_migration_digest, Tuple{String}, wire))
end

function _g1_migration_source_hash(source::LegacyMechanismGenomeV4,
                                   profile::CanonicalizationProfileV1)::Digest256
    wire = invoke(_g1_migration_source_wire, Tuple{LegacyMechanismGenomeV4,Union{Nothing,CanonicalizationProfileV1}}, source, profile)
    Digest256(invoke(_g1_migration_digest, Tuple{String}, wire))
end

function _g1_migration_source_graph_hash(source::LegacyMechanismGenomeV4,
                                          profile::Union{Nothing,CanonicalizationProfileV1})::Digest256
    wire = invoke(_g1_migration_graph_wire, Tuple{TypedOperatorHypergraphV1,Union{Nothing,CanonicalizationProfileV1}}, source.graph, profile)
    Digest256(invoke(_g1_migration_digest, Tuple{String}, "fusionconceptai:v4:g1-legacy-source-graph:v1|" * wire))
end

function _g1_migration_final_mapping_hash(source::LegacyMechanismGenomeV4,
                                          canonical::CanonicalMechanismV1)::Digest256
    profile = canonical.transport.context.profile
    graph_hash = invoke(_g1_migration_source_graph_hash,
        Tuple{LegacyMechanismGenomeV4,Union{Nothing,CanonicalizationProfileV1}}, source, profile)
    layers = canonical.hashes
    body = "{\"source_graph_identity\":" * _g1_layer_digest(graph_hash) *
        ",\"contract_hash\":" * _g1_layer_digest(layers.contract_hash) *
        ",\"canonicalization_profile_hash\":" * _g1_layer_digest(layers.canonicalization_profile_hash) *
        ",\"operator_registry_hash\":" * _g1_layer_digest(layers.operator_registry_hash) *
        ",\"candidate_subject_hash\":" * _g1_layer_digest(layers.candidate_subject_hash) * "}"
    Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits("fusionconceptai:v4:g1-legacy-bound-mapping:v1|" * body)))))
end

function _g1_migration_evaluate(source::LegacyMechanismGenomeV4,
                                declaration::Union{Nothing,G1LegacyMigrationDeclarationV1},
                                context::MechanismCanonicalizationContextV1,
                                registry::OperatorRegistryV1)
    source_hash = try
        invoke(_g1_migration_source_hash, Tuple{LegacyMechanismGenomeV4,CanonicalizationProfileV1}, source, context.profile)
    catch e
        e isa CanonicalizationDeferred || rethrow()
        return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            nothing, declaration, canonicalization_budget_exhausted)
    end
    declaration === nothing && return invoke(_g1_migration_deferred,
        Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
        source_hash, nothing, missing_mapping_resource)
    source_hash.value == declaration.source_mechanism_hash.value || return invoke(_g1_migration_deferred,
        Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
        source_hash, declaration, mapping_not_applicable)
    invoke(_g1_migration_contract_equal, Tuple{GenomeContractRef,GenomeContractRef}, source.contract_ref, context.contract_ref) &&
        invoke(_g1_migration_contract_equal, Tuple{GenomeContractRef,GenomeContractRef}, source.contract_ref, declaration.target_contract_ref) ||
        return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, contract_incompatible)
    completion_closure = invoke(_g1_migration_validate_completion_closure,
        Tuple{LegacyMechanismGenomeV4,G1LegacyMigrationDeclarationV1}, source, declaration)
    completion_closure === nothing && return invoke(_g1_migration_deferred,
        Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
        source_hash, declaration, legacy_edge_completion_missing)
    completion_closure || return invoke(_g1_migration_deferred,
        Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
        source_hash, declaration, legacy_edge_completion_missing)
    invoke(_g1_migration_legacy_ast_supported, Tuple{LegacyMechanismGenomeV4}, source) ||
        return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, legacy_ast_unrepresentable)
    invoke(_g1_migration_gene_set_equal, Tuple{Tuple,Tuple,Type}, source.invariants, declaration.invariants, InvariantV1) ||
        return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, legacy_gene_semantics_unrepresentable)
    invoke(_g1_migration_gene_set_equal, Tuple{Tuple,Tuple,Type}, source.observables, declaration.observables, ObservableGeneV1) ||
        return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, legacy_gene_semantics_unrepresentable)
    invoke(_g1_payload_parity_generator_closure, Tuple{Tuple,Tuple}, declaration.states, declaration.symmetries) ||
        return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, legacy_gene_semantics_unrepresentable)
    converted_graph = try
        invoke(_g1_migration_convert_graph,
            Tuple{LegacyMechanismGenomeV4,G1LegacyMigrationDeclarationV1,OperatorRegistryV1}, source, declaration, registry)
    catch e
        e isa _G1LegacyASTUnrepresentable &&
            return invoke(_g1_migration_deferred,
                Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
                source_hash, declaration, legacy_ast_unrepresentable)
        rethrow()
    end
    converted_graph === nothing && return invoke(_g1_migration_deferred,
        Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
        source_hash, declaration, legacy_edge_completion_missing)
    invoke(_g1_payload_ledger_closure, Tuple{Tuple,TypedOperatorHypergraphV1}, declaration.invariants, converted_graph) ||
        return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, legacy_gene_semantics_unrepresentable)
    payload = invoke(MechanismGenomePayloadV1,
        Tuple{Any,Any,Any,Any,Any,Any,Any}, declaration.states, declaration.invariants,
        converted_graph, declaration.parameters, declaration.symmetries, declaration.observables,
        declaration.operator_holes)
    programs = TypedASTProgramV1[]
    append!(programs, (e.program for e in converted_graph.hyperedges))
    append!(programs, (o.sampling_program for o in declaration.observables))
    invoke(_g1_migration_parameter_closure, Tuple{Vector{TypedASTProgramV1},Tuple}, programs, declaration.parameters)
    invoke(_g1_migration_gene_closure, Tuple{MechanismGenomePayloadV1,LegacyMechanismGenomeV4,G1LegacyMigrationDeclarationV1}, payload, source, declaration)
    canonical = try invoke(canonicalize_mechanism, Tuple{MechanismGenomePayloadV1,MechanismCanonicalizationContextV1}, payload, context) catch e
        e isa CanonicalizationDeferred && return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, canonicalization_budget_exhausted)
        rethrow()
    end
    mapping_hash = try
        invoke(_g1_migration_final_mapping_hash,
            Tuple{LegacyMechanismGenomeV4,CanonicalMechanismV1}, source, canonical)
    catch e
        e isa CanonicalizationDeferred && return invoke(_g1_migration_deferred,
            Tuple{Union{Nothing,Digest256},Union{Nothing,G1LegacyMigrationDeclarationV1},G1LegacyMigrationReasonV1},
            source_hash, declaration, canonicalization_budget_exhausted)
        rethrow()
    end
    invoke(_g1_migration_outcome,
        Tuple{ResolutionStatus,Any,Any,Union{Nothing,Digest256},Any,Any,Any,G1LegacyMigrationReasonV1},
        resolved, payload, canonical, source_hash, declaration.mapping_ref, mapping_hash,
        declaration.declaration_content_hash, migration_lossless)
end

function migrate_legacy_g1(source::LegacyMechanismGenomeV4,
                           declaration::Union{Nothing,G1LegacyMigrationDeclarationV1},
                           context::MechanismCanonicalizationContextV1,
                           registry::OperatorRegistryV1)::G1LegacyMigrationResultV1
    invoke(G1LegacyMigrationResultV1,
        Tuple{LegacyMechanismGenomeV4,Union{Nothing,G1LegacyMigrationDeclarationV1},MechanismCanonicalizationContextV1,OperatorRegistryV1},
        source, declaration, context, registry)
end

semantic_view(x::G1LegacyEdgeCompletionV1) = (source_edge_id=x.source_edge_id, account_effects=x.account_effects, interface_flux_pairs=x.interface_flux_pairs)
semantic_view(x::G1LegacyMigrationDeclarationV1) = (mapping_ref=x.mapping_ref, source_mechanism_hash=x.source_mechanism_hash, target_contract_ref=x.target_contract_ref,
    states=x.states, invariants=x.invariants, parameters=x.parameters, symmetries=x.symmetries, observables=x.observables, operator_holes=x.operator_holes,
    edge_completions=x.edge_completions, declaration_content_hash=x.declaration_content_hash)
semantic_view(x::G1LegacyMigrationResultV1) = (resolution=x.resolution,
    mechanism_subject_hash=x.genome === nothing ? nothing : mechanism_subject_hash(x.genome),
    source_mechanism_hash=x.source_mechanism_hash, mapping_ref=x.mapping_ref,
    mapping_hash=x.mapping_hash, declaration_content_hash=x.declaration_content_hash, reason=x.reason)
