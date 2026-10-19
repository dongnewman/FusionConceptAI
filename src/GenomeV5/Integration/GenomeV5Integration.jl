"""Shared additive v5 entry point.

The integration boundary consumes the public projections owned by G1/G2/G3.  It
does not load their component files and it never infers a legacy mapping.  Concrete
layer constructors remain responsible for their own admission rules.
"""

"""Load the concrete GenomeV5 layer types in their dependency order.

The loader is explicit because the existing layer focused tests intentionally
include their files manually after `using FusionConceptAI`.  Calling it once from
an integration runner makes the parameterized shared package hold the real types;
the idempotence guard keeps repeated runner setup harmless.
"""
function load_genome_v5_components!()
    layers = ((:MechanismGenomeV5, ("GrammarProfileV2.jl", "EquationPlanV2.jl",
                                    "MechanismGenomePayloadV2.jl", "MechanismGenomeV5.jl"), "G1"),
              (:FieldGeometryGenomeV5, ("SpatialGrammarProfileV2.jl", "RegionInterfaceContractV2.jl",
                                        "FieldSpacePlanV2.jl", "FieldGeometryGenomeV5.jl"), "G2"),
              (:RealizationControlGenomeV5, ("RealizationGenomeV5.jl", "ControlGenomeV5.jl",
                                             "CoupledRealizationControlBindingV2.jl", "RealizationControlGenomeV5.jl"), "G3"))
    for (root_type, files, layer) in layers
        isdefined(@__MODULE__, root_type) && continue
        root = joinpath(@__DIR__, "..", layer)
        for file in files
            Base.include(@__MODULE__, joinpath(root, file))
        end
    end
    nothing
end

"""Canonical dependency order consumed by additive GenomeV5 entry points."""
genome_v5_component_layer_order() = (:G1, :G2, :G3)

_v5_has(x, name::Symbol) = x !== nothing && hasproperty(x, name)
_v5_get(x, name::Symbol, default=nothing) = _v5_has(x, name) ? getproperty(x, name) : default

function _v5_g2_source_projection(x)
    isdefined(@__MODULE__, :G2V5SourceProjectionV1) || return nothing
    T = getfield(@__MODULE__, :G2V5SourceProjectionV1)
    x isa T ? x : nothing
end

_v5_g2_component(x) = begin
    projection = _v5_g2_source_projection(x)
    projection === nothing ? x : projection.genome
end

function _v5_g2_source_projection_valid(x)
    projection = _v5_g2_source_projection(x)
    projection === nothing && return false
    try
        all(name -> isdefined(@__MODULE__, name),
            (:FieldGeometryGenomeV5, :PresentG2SourceDeclarationV1,
             :PresentG2SourceFactoryIdentityV1, :PresentG2SourceConstructionReceiptV1)) || return false
        projection.genome isa getfield(@__MODULE__, :FieldGeometryGenomeV5) || return false
        declaration_record = projection.source_declaration
        identity = projection.source_factory_identity
        receipt = projection.source_factory_receipt
        declaration_record isa getfield(@__MODULE__, :PresentG2SourceDeclarationV1) || return false
        identity isa getfield(@__MODULE__, :PresentG2SourceFactoryIdentityV1) || return false
        receipt isa getfield(@__MODULE__, :PresentG2SourceConstructionReceiptV1) || return false
        source = declaration_record.source_payload
        declaration = declaration_record.declaration
        binding = declaration_record.binding
        projection.source_map_retained && projection.resolution === :terminal_deferred &&
            projection.claim_ceiling === :contract_only || return false
        source.source_hash == canonical_hash(_g2mb_source_body(source.source_ref,
            source.source_version, source.candidate_ref, source.chart_map, source.mesh,
            source.faces, source.profile, source.units, source.authority;
            field_space=source.field_space, q1_interpretation=source.q1_interpretation,
            boundary_coverage=source.boundary_coverage,
            region_interface=source.region_interface,
            region_exterior_owners=source.region_exterior_owners)) || return false
        declaration.contract_ref == source.candidate_ref && declaration.source === source &&
            declaration.declaration_hash == g2mb_declaration_hash_v1(declaration) || return false
        binding.common_binding_handle == declaration_record.common_binding_handle &&
            binding.common_binding_envelope_sha256 == G2_AD45_ENVELOPE_SHA256_V1 &&
            binding.contract_ref == declaration_record.public_contract_ref &&
            binding.version_axes == declaration_record.version_axes &&
            binding.binding_role === :temporary_common_candidate_binding_handle_only &&
            !binding.candidate_identity_created || return false
        binding_body = (common_binding_handle=binding.common_binding_handle,
            common_binding_envelope_sha256=binding.common_binding_envelope_sha256,
            contract_ref=binding.contract_ref, version_axes=binding.version_axes,
            binding_role=binding.binding_role, candidate_identity_created=false)
        binding.binding_hash == canonical_hash(binding_body) || return false
        declaration_body = (public_contract_ref=declaration_record.public_contract_ref,
            common_binding_handle=declaration_record.common_binding_handle,
            version_axes=declaration_record.version_axes, locator=declaration_record.locator,
            source_payload=source, declaration=declaration, binding=binding,
            source_content_hash=declaration_record.source_content_hash,
            local_declaration_hash=declaration_record.local_declaration_hash,
            synthetic_test_only=declaration_record.synthetic_test_only,
            candidate_identity_created=false, final_candidate_or_package_hash_created=false)
        declaration_record.local_declaration_hash == declaration.declaration_hash &&
            !declaration_record.candidate_identity_created &&
            !declaration_record.final_candidate_or_package_hash_created &&
            declaration_record.declaration_hash == canonical_hash(declaration_body) || return false
        identity.factory_ref == receipt.factory_ref == G2_SOURCE_AUTHORITY_FACTORY_REF_V1 &&
            identity.factory_version == G2_SOURCE_AUTHORITY_FACTORY_VERSION_V1 &&
            identity.locator == declaration_record.locator == receipt.output_source_declaration.locator &&
            identity.common_binding_handle == declaration_record.common_binding_handle ==
                receipt.common_binding_handle &&
            identity.contract_ref == declaration_record.public_contract_ref ==
                binding.contract_ref == receipt.contract_ref &&
            identity.version_axes == declaration_record.version_axes == binding.version_axes ==
                receipt.version_axes &&
            declaration_record.source_content_hash == identity.source_content_hash ==
                receipt.source_content_hash == projection.source_content_hash &&
            declaration_record.local_declaration_hash == identity.declaration_hash ==
                receipt.local_declaration_hash == declaration.declaration_hash &&
            declaration_record.declaration_hash == receipt.declaration_hash ==
                projection.declaration_hash &&
            identity.source_payload_hash == source.source_hash == receipt.source_payload_hash ==
                projection.source_payload_hash &&
            receipt.local_declaration_hash == declaration_record.local_declaration_hash &&
            receipt.locator_digest == canonical_hash(declaration_record.locator) || return false
        identity.registry_not_used && receipt.registry_not_used && !receipt.trusted &&
            receipt.replayable && !receipt.candidate_identity_created && !receipt.final_hash_created &&
            !identity.candidate_identity_created &&
            !identity.final_candidate_or_package_hash_created || return false
        identity_body = (factory_ref=identity.factory_ref, factory_version=identity.factory_version,
            locator=identity.locator, common_binding_handle=identity.common_binding_handle,
            contract_ref=identity.contract_ref, version_axes=identity.version_axes,
            source_payload_hash=identity.source_payload_hash,
            source_content_hash=identity.source_content_hash,
            declaration_hash=identity.declaration_hash, registry_not_used=true,
            candidate_identity_created=false, final_candidate_or_package_hash_created=false)
        identity.factory_identity_hash == canonical_hash(identity_body) || return false
        receipt_body = (status=receipt.status, factory_ref=receipt.factory_ref,
            locator_digest=receipt.locator_digest, source_payload_hash=receipt.source_payload_hash,
            source_content_hash=receipt.source_content_hash,
            local_declaration_hash=receipt.local_declaration_hash,
            declaration_hash=receipt.declaration_hash,
            common_binding_handle=receipt.common_binding_handle,
            contract_ref=receipt.contract_ref, version_axes=receipt.version_axes,
            output_source_declaration=receipt.output_source_declaration,
            registry_not_used=true, trusted=false, candidate_identity_created=false,
            final_hash_created=false, replayable=true)
        receipt.status === :present && receipt.output_source_declaration === declaration_record &&
            receipt.receipt_hash == canonical_hash(receipt_body) || return false
        locator = identity.locator
        locator.provenance === :current_source &&
            identity.common_binding_handle == QualifiedRefV1(
                G2_AD45_COMMON_BINDING_HANDLE_ID_V1,
                G2_AD45_COMMON_BINDING_HANDLE_VERSION_V1) &&
            identity.contract_ref == _g2sf_expected_contract(source) &&
            source.candidate_ref == identity.contract_ref &&
            _g2sf_axes_ok(identity.version_axes) &&
            _g2sf_validate_handle(locator.repository_root, identity.common_binding_handle,
                locator.repository_root) === nothing &&
            _g2sf_validate_locator(locator, locator.repository_root) === nothing || return false
        source_content_body = (factory_ref=G2_SOURCE_AUTHORITY_FACTORY_REF_V1,
            locator=locator, common_binding_handle=identity.common_binding_handle,
            contract_ref=identity.contract_ref, version_axes=identity.version_axes,
            source_payload=source, source_payload_hash=source.source_hash,
            binding=binding, binding_hash=binding.binding_hash,
            declaration_hash=declaration.declaration_hash,
            synthetic_test_only=declaration_record.synthetic_test_only)
        declaration_record.synthetic_test_only === false &&
            identity.source_content_hash == canonical_hash(source_content_body) || return false
        canonical_genome = _g2v5_source_order_canonical_genome(projection.genome)
        canonical_genome.candidate_hash == projection.genome.candidate_hash || return false
        body = (genome=canonical_genome, source_factory_identity=identity,
            source_declaration=declaration_record,
            source_payload_hash=projection.source_payload_hash,
            source_content_hash=projection.source_content_hash,
            declaration_hash=projection.declaration_hash,
            source_map_retained=true, resolution=:terminal_deferred,
            claim_ceiling=:contract_only)
        canonical_hash(body) == projection.projection_hash || return false
        all(name -> isdefined(@__MODULE__, name),
            (:G2SourceFactoryConstructionResultV1, :g2_v5_source_projection_v1)) || return false
        factory_result = getfield(@__MODULE__, :G2SourceFactoryConstructionResultV1)(
            identity, declaration_record, receipt)
        rebuilt = getfield(@__MODULE__, :g2_v5_source_projection_v1)(factory_result;
            canonicalization_profile_ref=projection.genome.grammar_profile.canonicalization_profile_ref)
        rebuilt.projection_hash == projection.projection_hash &&
            _g2v5_source_projection_rebuild_matches(rebuilt.genome, canonical_genome)
    catch
        false
    end
end

_v5_g2_identity_fields(x) = begin
    projection = _v5_g2_source_projection(x)
    projection === nothing ? NamedTuple() : (g2_source_projection=projection,)
end

function _v5_contract_ref(x)
    x = _v5_g2_component(x)
    ref = _v5_get(x, :contract_ref)
    ref isa GenomeContractRef && return ref
    binding = _v5_get(x, :contract_binding)
    ref = _v5_get(binding, :contract_ref)
    ref isa GenomeContractRef && return ref
    nothing
end

function _v5_g1_candidate(g1)
    payload = _v5_get(g1, :payload)
    ref = _v5_get(payload, :contract_ref)
    value = _v5_get(ref, :candidate_binding)
    value === nothing && (value = _v5_get(payload, :candidate_binding))
    value === nothing ? nothing : String(value)
end

function _v5_g3_candidate(g3)
    binding = _v5_get(g3, :contract_binding)
    candidate = _v5_get(binding, :candidate_ref)
    candidate isa QualifiedRefV1 && return candidate
    child = _v5_get(g3, :realization)
    binding = _v5_get(child, :contract_binding)
    candidate = _v5_get(binding, :candidate_ref)
    candidate isa QualifiedRefV1 ? candidate : nothing
end

function _v5_g3_child_refs(g3)
    realization = _v5_get(g3, :realization)
    control = _v5_get(g3, :control)
    binding = _v5_get(g3, :binding)
    (realization=_v5_ref_identity(_v5_contract_ref(realization)),
     control=_v5_ref_identity(_v5_contract_ref(control)),
     binding=_v5_ref_identity(_v5_contract_ref(binding)))
end

function _v5_axes(x)
    x = _v5_g2_component(x)
    axes = _v5_get(x, :version_axes)
    axes === nothing && begin
        binding = _v5_get(x, :contract_binding)
        axes = _v5_get(binding, :version_axes)
    end
    axes
end

function _v5_ref_identity(ref)
    ref isa GenomeContractRef || return nothing
    (uri=ref.uri, version=ref.version, schema_hash=ref.schema_hash,
     canonicalization_hash=ref.canonicalization_hash,
     compatibility_profile=ref.compatibility_profile)
end

function _v5_check_contract_ref(ref, role, errors, gaps)
    ref isa GenomeContractRef || return
    (ref.schema_hash == Digest256(repeat("0", 64)) ||
     ref.canonicalization_hash == Digest256(repeat("0", 64))) &&
        push!(errors, "$(role)_placeholder_contract_hash")
    startswith(ref.uri, "pending://") &&
        push!(errors, "$(role)_contract_authority_pending")
    role === :G1 && !startswith(ref.uri, "fusionconceptai://GenomeV5/G1/") &&
        push!(errors, "G1_public_uri_namespace_not_authoritative")
    role === :G2 && !startswith(ref.uri, "fusionconceptai://GenomeV5/G2/") &&
        push!(errors, "G2_public_uri_namespace_not_authoritative")
    role === :G3 && !startswith(ref.uri, "fusionconceptai://GenomeV5/G3/") &&
        push!(errors, "G3_public_uri_namespace_not_authoritative")
end

function _v5_check_authoritative_content!(ref, role::Symbol, errors;
        genome=nothing, g3_source_verified=false)
    ref isa GenomeContractRef || return
    if role === :G1 && isdefined(@__MODULE__, :g1_schema_hash)
        ref.schema_hash == g1_schema_hash() || push!(errors, "G1_schema_hash_not_authoritative")
        ref.canonicalization_hash == g1_canonicalization_hash() ||
            push!(errors, "G1_canonicalization_hash_not_authoritative")
    elseif role === :G2 && isdefined(@__MODULE__, :g2_schema_hash)
        ref.schema_hash == g2_schema_hash() || push!(errors, "G2_schema_hash_not_authoritative")
        g2_component = _v5_g2_component(genome)
        profile = _v5_get(g2_component, :grammar_profile)
        authoritative_canon = profile isa SpatialGrammarProfileV2 ?
            g2_canonicalization_hash(profile) : g2_canonicalization_hash()
        ref.canonicalization_hash == authoritative_canon ||
            push!(errors, "G2_canonicalization_hash_not_authoritative")
    elseif role === :G3 && isdefined(@__MODULE__, :g3_contract_ref)
        authored_ref = isdefined(@__MODULE__, :g3_authored_source_design_contract_ref_v1) ?
            g3_authored_source_design_contract_ref_v1() : nothing
        is_authored_aggregate = isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
            genome isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1)
        authored_ok = is_authored_aggregate && g3_source_verified && ref == authored_ref
        (ref == g3_contract_ref(:bundle) || authored_ok) ||
            push!(errors, "G3_public_ref_not_authoritative")
    end
end

function _v5_axis_identity(axes)
    axes === nothing && return nothing
    try
        semantic_view(axes)
    catch
        axes isa NamedTuple ? axes : nothing
    end
end

function _v5_candidate_matches(candidate_ref::QualifiedRefV1, binding)
    binding === nothing && return false
    candidate_ref.version == "v5" || return false
    String(binding) == candidate_ref.id
end

function _v5_component_type_valid(x, role::Symbol)
    if role === :G2
        projection = _v5_g2_source_projection(x)
        projection === nothing || return _v5_g2_source_projection_valid(projection)
    end
    expected = role === :G1 ? :MechanismGenomeV5 :
               role === :G2 ? :FieldGeometryGenomeV5 :
               role === :G3 ? :RealizationControlGenomeV5 : nothing
    expected === nothing && return false
    isdefined(@__MODULE__, expected) || return false
    x isa getfield(@__MODULE__, expected) && return true
    role === :G3 && isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
        x isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1)
end

"""Optional identity extension for the exact candidate-authored G3 source aggregate."""
function _v5_g3_identity_fields(g3)
    isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
        g3 isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) || return NamedTuple()
    payload = g3.authored_payload
    (g3_authored_source_design=(contract_ref=_v5_ref_identity(_v5_contract_ref(g3)),
        candidate_ref=g3.contract_binding.candidate_ref,
        source_ref=payload.source_ref, source_path=payload.source_path,
        source_sha256=payload.source_sha256,
        builder_source_ref=payload.builder_source_ref,
        builder_source_sha256=payload.builder_source_sha256,
        payload_hash=payload.payload_hash,
        source_admission_hash=canonical_hash(payload.source_admission),
        effort_waiver=payload.effort_ports_without_ledger,
        power_law_hash=canonical_hash(payload.power_laws),
        control_resource_links_hash=canonical_hash((payload.control_source,
            payload.control_resource_links, payload.command_to_current_map,
            payload.command_to_power_map, payload.power_status_signal_id)),
        feedback_basis_map_hash=canonical_hash((payload.feedback_source_maps,
            g3.binding.feedback)),
        authored_heat_lift_hash=canonical_hash(payload.authored_heat_lift),
        design_identity_hash=canonical_hash(semantic_view(g3))),)
end

function _v5_component_hash(x, role::Symbol, errors)
    _v5_component_type_valid(x, role) || push!(errors, "$(role)_concrete_v5_type_missing")
    component = role === :G2 ? _v5_g2_component(x) : x
    value = _v5_get(component, :candidate_hash)
    value isa Digest256 || push!(errors, "$(role)_component_canonical_hash_missing")
    value isa Digest256 ? value : nothing
end

function _v5_g3_source_verification_fields(g3)
    isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
        g3 isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) || return NamedTuple()
    payload = g3.authored_payload
    (g3_source_verification=(route=:vnext_t2_materialize_g3_v1,
        result=:source_rebuilt, payload_hash=payload.payload_hash,
        source_admission_hash=canonical_hash(payload.source_admission),
        source_context_identity=payload.source_admission.source_context_identity,
        child_identity_hashes=payload.source_admission.child_identity_hashes),)
end

function _v5_g3_source_proof_valid(g3, proof)
    isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
        g3 isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) ||
        return true
    proof isa NamedTuple || return false
    isdefined(@__MODULE__, :g3_authored_source_design_payload_valid_v1) || return false
    if propertynames(proof) == (:record, :children, :rebuilt_child, :frozen_context)
        return g3_authored_source_design_payload_valid_v1(g3, proof.record,
            proof.children, proof.rebuilt_child; frozen_context=proof.frozen_context)
    end
    propertynames(proof) == (:record, :children, :rebuilt_child, :frozen_context,
        :g3_factory_invocation) || return false
    g3_authored_source_design_payload_valid_v1(g3, proof.record, proof.children,
        proof.rebuilt_child; frozen_context=proof.frozen_context,
        g3_factory_invocation=proof.g3_factory_invocation)
end

function _v5_g1_source_projection_valid(g1, candidate_ref, projection)
    projection === nothing && return true
    projection isa NamedTuple || return false
    required = (:candidate_ref, :source_declaration_ref, :source_bytes_sha256,
        :declaration_identity_hash, :unknown_source_expression_sha256,
        :source_expression_sha256, :g1_candidate_hash, :source_projection_hash,
        :source_record, :frozen_context)
    all(key -> hasproperty(projection, key), required) || return false
    projection.candidate_ref == candidate_ref || return false
    projection.source_declaration_ref isa QualifiedRefV1 || return false
    all(x -> x isa Digest256, (projection.source_bytes_sha256,
        projection.declaration_identity_hash,
        projection.unknown_source_expression_sha256,
        projection.source_expression_sha256,
        projection.g1_candidate_hash,
        projection.source_projection_hash)) || return false
    isdefined(@__MODULE__, :VNextT0LocalPresentDeclarationV1) || return false
    record = projection.source_record
    record isa getfield(@__MODULE__, :VNextT0LocalPresentDeclarationV1) || return false
    record.layer === :G1 && record.candidate_ref == candidate_ref || return false
    record.semantic_body.body !== nothing || return false
    isempty(_vnl_t0_errors(record, candidate_ref;
        frozen_context=projection.frozen_context)) || return false
    projection.source_declaration_ref == record.declaration_ref || return false
    projection.source_bytes_sha256 == record.source_bytes.sha256 || return false
    projection.declaration_identity_hash == record.declaration_identity_hash || return false
    projection.g1_candidate_hash == _v5_get(g1, :candidate_hash) || return false
    try
        source_payload = record.semantic_body.body.source_payload
        source_payload isa G1DiffusionSourcePayloadV1 || return false
        source_payload.candidate_ref == candidate_ref || return false
        for field in (source_payload.u, source_payload.K, source_payload.f)
            matches = Tuple(state for state in g1.payload.states if state.state_id == field.field_id)
            length(matches) == 1 || return false
            only(matches).physical_type == field.physical_type || return false
        end
        equations = g1.payload.equation_plan.equations
        gradient = only(Tuple(x for x in equations if x.equation_id == "r2-grad-constraint"))
        constitutive = only(Tuple(x for x in equations if x.equation_id == "r2-flux-constitutive-constraint"))
        profile = only(Tuple(x for x in equations if x.equation_id == "r2-k-affine-profile-constraint"))
        source = only(Tuple(x for x in equations if x.equation_id == "r2-negative-source-additive"))
        gradient_apply = only(Tuple(x for x in gradient.expression.nodes if x isa G1OperatorApplyV2))
        constitutive_apply = only(Tuple(x for x in constitutive.expression.nodes if x isa G1OperatorApplyV2))
        profile_apply = only(Tuple(x for x in profile.expression.nodes if x isa G1OperatorApplyV2))
        source_apply = only(Tuple(x for x in source.expression.nodes if x isa G1OperatorApplyV2))
        unknown_expression = source_payload.u.source_expression
        source_expression = source_payload.f.source_expression
        gradient_apply.parameters.unknown_source_expression == unknown_expression || return false
        source_apply.parameters.source_expression == source_expression || return false
        k = source_payload.K.expression
        for parameters in (constitutive_apply.parameters, profile_apply.parameters)
            parameters.coefficient_base == k.base_diag || return false
            parameters.coefficient_slope == k.slope_diag || return false
            parameters.coefficient_domain_min == k.domain_min || return false
            parameters.coefficient_domain_max == k.domain_max || return false
        end
        unknown_hash = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(unknown_expression)))))
        source_hash = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(source_expression)))))
        unknown_hash == projection.unknown_source_expression_sha256 || return false
        source_hash == projection.source_expression_sha256 || return false
    catch
        return false
    end
    body = (domain="up4-r2-g1-v5-source-projection-v1",
        candidate_ref=projection.candidate_ref,
        source_declaration_ref=projection.source_declaration_ref,
        source_bytes_sha256=projection.source_bytes_sha256,
        declaration_identity_hash=projection.declaration_identity_hash,
        unknown_source_expression_sha256=projection.unknown_source_expression_sha256,
        source_expression_sha256=projection.source_expression_sha256,
        g1_candidate_hash=projection.g1_candidate_hash)
    projection.source_projection_hash == canonical_hash(body)
end

function _v5_package_identity_valid(candidate_ref, g1, g2, g2_binding, g3, axes, identity, receipt;
                                    require_candidate=true)
    all(hasproperty(identity, key) for key in
        (:candidate_ref, :g1_ref, :g2_ref, :g3_ref,
         :g1_genome_hash, :g2_genome_hash, :g3_genome_hash, :g2_candidate_binding,
         :g3_child_refs,
         :feedback)) || return false
    g2_binding isa G2CandidateBindingV5 || return false
    g2_binding.candidate_ref == candidate_ref || return false
    g2_projection = _v5_get(identity, :g2_source_projection)
    g2_component = _v5_g2_component(g2)
    g2_hash = _v5_get(g2_component, :candidate_hash)
    g2_projection === nothing ||
        (_v5_g2_source_projection_valid(g2_projection) &&
         _g2v5_source_projection_component_matches(g2_projection.genome, g2_component)) || return false
    g2_binding.genome_hash == g2_hash || return false
    _v5_contract_ref(g1) isa GenomeContractRef || return false
    _v5_contract_ref(g2) isa GenomeContractRef || return false
    _v5_contract_ref(g3) isa GenomeContractRef || return false
    ref_errors = String[]
    g3_source_verified = false
    for (role, genome) in ((:G1, g1), (:G2, g2), (:G3, g3))
        ref = _v5_contract_ref(genome)
        _v5_check_contract_ref(ref, role, ref_errors, String[])
        authenticated_g3 = role === :G3 && isdefined(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
            genome isa getfield(@__MODULE__, :G3AuthoredSourceDesignAggregateV1) &&
            isdefined(@__MODULE__, :g3_authored_source_design_payload_valid_v1) &&
            (g3_source_verified = g3_authored_source_design_payload_valid_v1(genome))
        _v5_check_authoritative_content!(ref, role, ref_errors;
            genome=genome, g3_source_verified=authenticated_g3)
    end
    require_candidate && !isempty(ref_errors) && return false
    identity.candidate_ref == candidate_ref || return false
    identity.g1_ref == _v5_ref_identity(_v5_contract_ref(g1)) || return false
    identity.g2_ref == _v5_ref_identity(_v5_contract_ref(g2)) || return false
    identity.g3_ref == _v5_ref_identity(_v5_contract_ref(g3)) || return false
    identity.g1_genome_hash == _v5_get(g1, :candidate_hash) || return false
    identity.g2_genome_hash == g2_hash || return false
    identity.g2_candidate_binding == semantic_view(g2_binding) || return false
    identity.g3_genome_hash == _v5_get(g3, :candidate_hash) || return false
    identity.g3_child_refs == _v5_g3_child_refs(g3) || return false
    g3_source_fields = _v5_g3_identity_fields(g3)
    if isempty(g3_source_fields)
        (hasproperty(identity, :g3_authored_source_design) ||
         hasproperty(identity, :g3_source_verification)) && return false
    else
        hasproperty(identity, :g3_authored_source_design) || return false
        identity.g3_authored_source_design == g3_source_fields.g3_authored_source_design || return false
        proof_fields = _v5_g3_source_verification_fields(g3)
        hasproperty(identity, :g3_source_verification) || return false
        identity.g3_source_verification == proof_fields.g3_source_verification || return false
        isdefined(@__MODULE__, :g3_authored_source_design_payload_valid_v1) || return false
        g3_source_verified || return false
    end
    if hasproperty(identity, :g1_source_projection)
        _v5_g1_source_projection_valid(g1, candidate_ref,
            identity.g1_source_projection) || return false
    end
    require_candidate && _v5_g1_candidate(g1) != candidate_ref.id && return false
    require_candidate && _v5_g3_candidate(g3) != candidate_ref && return false
    identity.g1_candidate_binding == _v5_g1_candidate(g1) || return false
    identity.g3_candidate_ref == _v5_g3_candidate(g3) || return false
    feedback_errors = String[]
    actual_feedback = _v5_feedback_identity(g3, _v5_contract_ref(g1), _v5_contract_ref(g2), feedback_errors)
    require_candidate && !isempty(feedback_errors) && return false
    identity.feedback == actual_feedback || return false
    axes.g1 == _v5_axis_identity(_v5_axes(g1)) || return false
    axes.g2 == _v5_axis_identity(_v5_axes(g2)) || return false
    axes.g3 == _v5_axis_identity(_v5_axes(g3)) || return false
    receipt.candidate_ref == candidate_ref || return false
    identity_hash = canonical_hash((candidate_ref=candidate_ref, identity=identity, axes=axes))
    receipt.candidate_identity_after == identity_hash.value || return false
    true
end

function _v5_feedback(g3)
    binding = _v5_get(g3, :binding)
    feedback = _v5_get(binding, :feedback)
    feedback === nothing && (feedback = _v5_get(g3, :feedback))
    feedback === nothing ? () : feedback
end

function _v5_feedback_identity(g3, g1_ref, g2_ref, errors)
    rows = NamedTuple[]
    for channel in _v5_feedback(g3)
        layer = _v5_get(channel, :target_layer)
        target = _v5_get(channel, :target_contract_ref)
        expected = layer === :G1 ? g1_ref : layer === :G2 ? g2_ref : nothing
        if expected === nothing
            push!(errors, "feedback_target_layer_invalid:" * String(layer))
        elseif !(target isa GenomeContractRef) || target != expected
            push!(errors, "feedback_target_ref_mismatch:" * String(_v5_get(channel, :feedback_id, "unknown")))
        end
        push!(rows, (feedback_id=String(_v5_get(channel, :feedback_id, "unknown")),
                     target_layer=layer,
                     target_contract_ref=_v5_ref_identity(target)))
    end
    Tuple(rows)
end

function _v5_collect_admission!(genome, role::Symbol, errors, gaps)
    role === :G2 && (genome = _v5_g2_component(genome))
    admission = _v5_get(genome, :admission)
    admission === nothing && begin
        push!(errors, "$(role)_admission_missing")
        return
    end
    structural = _v5_get(admission, :structural_status)
    if structural === :fail_closed
        for item in _v5_get(admission, :errors, ())
            push!(errors, "$(role)_structural:" * String(item))
        end
    end
    for status_name in (:geometry_status, :mesh_status, :physical_status)
        status = _v5_get(admission, status_name)
        status === nothing && continue
        if status_name === :geometry_status && status === :fail_closed
            push!(errors, "$(role)_geometry:fail_closed")
        elseif status !== :valid && status !== :resolved && status !== :executable
            push!(gaps, "$(role)_$(status_name)=" * String(status))
        end
    end
    provider = _v5_get(admission, :provider_match)
    provider === nothing || provider === :unique_match ||
        push!(gaps, "$(role)_provider_match=" * String(provider))
    resolution = _v5_get(admission, :resolution)
    resolution === nothing || resolution === :resolved ||
        push!(gaps, "$(role)_resolution=" * String(resolution))
    for gap in _v5_get(admission, :gaps, ())
        text = String(gap)
        # UP1-04 closes only this G3 authority relation after exact comparison.
        startswith(text, "feedback_authority_gap:") && role === :G3 && continue
        push!(gaps, "$(role)_gap=" * text)
    end
end

function _v5_fresh_receipt_valid(receipt, candidate_ref)
    receipt isa GenomeV5MigrationReceipt || return false
    receipt == v5_fresh_migration_receipt(candidate_ref)
end

function _v5_valid_package_gap_contract(g1, g2, g3, receipt, gaps)
    expected_errors = String[]
    expected_gaps = ["feedback_provenance_gap:typed_refs_without_external_receipt"]
    _v5_collect_admission!(g1, :G1, expected_errors, expected_gaps)
    _v5_collect_admission!(g2, :G2, expected_errors, expected_gaps)
    _v5_collect_admission!(g3, :G3, expected_errors, expected_gaps)
    any(!r.lossless for r in receipt.records) && push!(expected_gaps, "legacy_mapping_terminal_deferred")
    isempty(expected_errors) && length(gaps) == length(unique(gaps)) &&
        Tuple(gaps) == Tuple(expected_gaps)
end

"""Integrate three layer objects into one candidate-owned, structural v5 package.

`candidate_ref` must be supplied by the caller.  The result is `terminal_deferred`
when a structural mismatch, provider gap, or explicit legacy migration gap remains;
this function grants no engineering or physical credit.
"""
function integrate_genome_v5(g1, g2, g3;
                             candidate_ref::QualifiedRefV1,
                             migration_receipt=nothing,
                             legacy_refs=(),
                             g3_source_proof=nothing,
                             g1_source_projection=nothing)
    g2_component = _v5_g2_component(g2)
    supplied_receipt = migration_receipt
    receipt = supplied_receipt === nothing ? v5_fresh_migration_receipt(candidate_ref) : supplied_receipt
    _v5_fresh_receipt_valid(receipt, candidate_ref) ||
        throw(ArgumentError("UP1-04A accepts only the fresh factory migration receipt"))
    errors = String[]
    gaps = String[]
    candidate_ref.version == "v5" || push!(errors, "candidate_ref_version_not_v5")

    g1_hash = _v5_component_hash(g1, :G1, errors)
    g2_hash = _v5_component_hash(g2, :G2, errors)
    g3_hash = _v5_component_hash(g3, :G3, errors)
    g3_source_verified = _v5_g3_source_proof_valid(g3, g3_source_proof)
    !g3_source_verified && push!(errors, "G3_authored_source_rebuild_or_T1_T2_proof_failed")
    !_v5_g1_source_projection_valid(g1, candidate_ref, g1_source_projection) &&
        push!(errors, "G1_source_expression_projection_mismatch")
    g1_ref, g2_ref, g3_ref = _v5_contract_ref(g1), _v5_contract_ref(g2), _v5_contract_ref(g3)
    for (role, genome, ref) in ((:G1, g1, g1_ref), (:G2, g2, g2_ref), (:G3, g3, g3_ref))
        ref isa GenomeContractRef || push!(errors, "$(role)_public_contract_ref_missing")
        ref isa GenomeContractRef && ref.version == "v5" ||
            (ref isa GenomeContractRef && push!(errors, "$(role)_contract_ref_version_not_v5"))
        _v5_check_contract_ref(ref, role, errors, gaps)
        _v5_check_authoritative_content!(ref, role, errors; genome=genome,
            g3_source_verified=(role === :G3 && g3_source_verified))
    end

    g1_binding = _v5_g1_candidate(g1)
    g1_binding === nothing && push!(errors, "G1_candidate_binding_missing")
    g1_binding !== nothing && !_v5_candidate_matches(candidate_ref, g1_binding) &&
        push!(errors, "G1_candidate_binding_mismatch")
    g3_candidate = _v5_g3_candidate(g3)
    g3_candidate isa QualifiedRefV1 || push!(errors, "G3_candidate_ref_missing")
    g3_candidate isa QualifiedRefV1 && g3_candidate != candidate_ref &&
        push!(errors, "G3_candidate_ref_mismatch")

    axes = (g1=_v5_axis_identity(_v5_axes(g1)),
            g2=_v5_axis_identity(_v5_axes(g2)),
            g3=_v5_axis_identity(_v5_axes(g3)))
    any(x === nothing for x in values(axes)) && push!(errors, "version_axes_missing")
    feedback = _v5_feedback_identity(g3, g1_ref, g2_ref, errors)
    push!(gaps, "feedback_provenance_gap:typed_refs_without_external_receipt")
    _v5_collect_admission!(g1, :G1, errors, gaps)
    _v5_collect_admission!(g2, :G2, errors, gaps)
    _v5_collect_admission!(g3, :G3, errors, gaps)

    g2_binding = G2CandidateBindingV5(candidate_ref, g2_hash)
    receipt = isempty(legacy_refs) ? receipt :
        v5_deferred_migration_receipt(candidate_ref; legacy_refs=legacy_refs)
    receipt.candidate_ref == candidate_ref || push!(errors, "migration_receipt_candidate_mismatch")
    any(!r.lossless for r in receipt.records) && push!(gaps, "legacy_mapping_terminal_deferred")

    identity = (g1_ref=_v5_ref_identity(g1_ref), g2_ref=_v5_ref_identity(g2_ref),
                g3_ref=_v5_ref_identity(g3_ref), g1_candidate_binding=g1_binding,
                g3_candidate_ref=g3_candidate, feedback=feedback,
                candidate_ref=candidate_ref, g1_genome_hash=g1_hash,
                g2_genome_hash=g2_hash, g3_genome_hash=g3_hash,
                g2_candidate_binding=semantic_view(g2_binding),
                g3_child_refs=_v5_g3_child_refs(g3))
    g1_source_projection === nothing ||
        (identity = merge(identity, (g1_source_projection=g1_source_projection,)))
    identity = merge(identity, _v5_g2_identity_fields(g2))
    identity = merge(identity, _v5_g3_identity_fields(g3))
    g3_source_verified &&
        (identity = merge(identity, _v5_g3_source_verification_fields(g3)))
    identity_hash = canonical_hash((candidate_ref=candidate_ref, identity=identity, axes=axes))
    receipt = GenomeV5MigrationReceipt(receipt.receipt_id, receipt.candidate_ref,
        receipt.records, receipt.status, receipt.candidate_identity_before,
        identity_hash.value, receipt.scope)
    structural_status = isempty(errors) ? :valid : :fail_closed
    resolution = isempty(errors) && isempty(gaps) ? resolved : terminal_deferred
    CandidateStatePackageV5(candidate_ref, g1, g2_component, g2_binding, g3, axes, receipt, identity,
                            structural_status, resolution, Tuple(errors), Tuple(gaps), none)
end
