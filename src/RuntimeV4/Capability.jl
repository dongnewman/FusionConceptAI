"""Capability closure, exact provider matching, and physical materialization."""

function _runtime_bindings(bindings)
    pairs = if bindings isa NamedTuple
        [(String(k), getfield(bindings, k)) for k in keys(bindings)]
    elseif bindings isa AbstractDict
        [(String(k), v) for (k, v) in bindings]
    else
        try
            [(String(first(p)), last(p)) for p in Tuple(bindings)]
        catch
            throw(ArgumentError("bindings must be a NamedTuple, dictionary, or tuple of pairs"))
        end
    end
    names = sort!(String[first(p) for p in pairs])
    length(unique(names)) == length(names) || throw(ArgumentError("duplicate binding names"))
    out = Tuple((name, only(p[2] for p in pairs if p[1] == name)) for name in names)
    is_canonical_value(out) || throw(ArgumentError("bindings must be immutable and canonicalizable"))
    out
end

function _runtime_scenarios(scenarios)
    if scenarios isa NamedTuple
        xs = (scenarios,)
    elseif scenarios isa AbstractDict
        xs = (scenarios,)
    else
        xs = try Tuple(scenarios) catch; (scenarios,) end
    end
    isempty(xs) && throw(ArgumentError("materialize requires at least one declared scenario"))
    ys = Tuple(is_canonical_value(x) ? x : throw(ArgumentError("scenario is not canonicalizable")) for x in xs)
    ys
end

function _runtime_capability_equal(a::CapabilitySignatureV4, b::CapabilitySignatureV4)
    a.schema == b.schema && a.revision == b.revision && a.kind == b.kind && a.operator == b.operator &&
    a.states == b.states && a.source_space == b.source_space && a.target_space == b.target_space &&
    a.dimension == b.dimension && a.coordinates == b.coordinates && a.coordinate_system == b.coordinate_system &&
    a.boundary_relation == b.boundary_relation && a.interface_relation == b.interface_relation && a.time_semantics == b.time_semantics &&
    a.required_output == b.required_output && a.evidence_level == b.evidence_level &&
    a.applicability_bounds == b.applicability_bounds && a.input_schema_hash == b.input_schema_hash
end

function _runtime_provider_domain_matches(provider::ProviderManifestV4, obligation::CapabilitySignatureV4)
    # Domain metadata can further restrict a signature, but it may never widen
    # one.  A declared bounds_hash is therefore required to agree exactly.
    d = provider.domain
    if d isa NamedTuple && (:bounds_hash in keys(d))
        return getfield(d, :bounds_hash) == obligation.applicability_bounds
    elseif d isa AbstractDict && haskey(d, "bounds_hash")
        return _runtime_digest(d["bounds_hash"]) == obligation.applicability_bounds
    end
    false
end

function _runtime_matches(obligation::CapabilitySignatureV4, provider::ProviderManifestV4)
    provider.kind == obligation.kind && provider.schema == obligation.schema && provider.revision == obligation.revision &&
    _runtime_capability_equal(provider.capability, obligation) &&
    provider.input_schema_hash == obligation.input_schema_hash &&
    _runtime_ceiling_rank(provider.claim_ceiling) >= _runtime_ceiling_rank(obligation.evidence_level) &&
    _runtime_provider_domain_matches(provider, obligation)
end

function match_provider(obligation::CapabilitySignatureV4, manifests)
    ps = manifests isa ProviderManifestV4 ? (manifests,) : Tuple(manifests)
    all(p -> p isa ProviderManifestV4, ps) || throw(ArgumentError("provider manifests must be typed ProviderManifestV4"))
    valid_signature = [p for p in ps if p.schema == obligation.schema && p.revision == obligation.revision && p.kind == obligation.kind &&
        p.capability.input_schema_hash == obligation.input_schema_hash]
    matches = [p for p in valid_signature if _runtime_matches(obligation, p)]
    oh = canonical_hash(obligation)
    if length(matches) == 1
        return ProviderMatchResultV4(unique_match, only(matches), obligation, "exact full capability signature match")
    elseif length(matches) > 1
        return ProviderMatchResultV4(ambiguous, nothing, obligation, "more than one exact provider manifest matched")
    elseif !isempty(valid_signature)
        return ProviderMatchResultV4(out_of_domain, nothing, obligation, "signature matched but provider domain or ceiling did not")
    else
        return ProviderMatchResultV4(no_match, nothing, obligation, "no provider matched the complete capability signature")
    end
end

match_provider(obligation::CapabilitySignatureV4, manifest::ProviderManifestV4) = match_provider(obligation, (manifest,))

function materialize(compiled::CompiledCandidatePrefixV4, bindings, scenarios)
    isempty(compiled.unresolved_nonterminals) || throw(ArgumentError("cannot materialize a compiled prefix with unresolved obligations"))
    bs = _runtime_bindings(bindings)
    ss = _runtime_scenarios(scenarios)
    payload = (mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        field_geometry_hash=field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        realization_control_hash=realization_control_hash(compiled.candidate.realization_control_genome_ref),
        genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        mechanism_graph=compiled.mechanism_graph,
        field_geometry_graph=compiled.field_geometry_graph, realization_graph=compiled.realization_graph,
        control_graph=compiled.control_graph, normalized_regions=compiled.normalized_regions,
        normalized_interfaces=compiled.normalized_interfaces, normalized_boundaries=compiled.normalized_boundaries,
        bindings=bs, scenarios=ss)
    is_canonical_value(payload) || throw(ArgumentError("materialized subject payload is not canonicalizable"))
    body = (compiled_prefix_hash=compiled.prefix_hash, genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        mission_hash=compiled.minimality_scope.mission_hash, bounds_hash=compiled.minimality_scope.bounds_hash,
        bindings=bs, scenarios=ss, materialized_payload=payload,
        operator_obligations=compiled.capability_obligations)
    ph = canonical_hash(body)
    ExecutablePhysicalSubjectV4(compiled.prefix_hash, compiled.candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash, compiled.minimality_scope.bounds_hash, bs, ss,
        payload, compiled.capability_obligations)
end
