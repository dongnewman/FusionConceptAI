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

function _v5_contract_ref(x)
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
end

function _v5_check_authoritative_content!(ref, role::Symbol, errors)
    ref isa GenomeContractRef || return
    if role === :G1 && isdefined(@__MODULE__, :g1_schema_hash)
        ref.schema_hash == g1_schema_hash() || push!(errors, "G1_schema_hash_not_authoritative")
        ref.canonicalization_hash == g1_canonicalization_hash() ||
            push!(errors, "G1_canonicalization_hash_not_authoritative")
    elseif role === :G2 && isdefined(@__MODULE__, :g2_schema_hash)
        ref.schema_hash == g2_schema_hash() || push!(errors, "G2_schema_hash_not_authoritative")
        ref.canonicalization_hash == g2_canonicalization_hash() ||
            push!(errors, "G2_canonicalization_hash_not_authoritative")
    elseif role === :G3 && isdefined(@__MODULE__, :g3_contract_ref)
        ref == g3_contract_ref(:bundle) || push!(errors, "G3_bundle_ref_not_authoritative")
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
    expected = role === :G1 ? :MechanismGenomeV5 :
               role === :G2 ? :FieldGeometryGenomeV5 :
               role === :G3 ? :RealizationControlGenomeV5 : nothing
    expected === nothing && return false
    isdefined(@__MODULE__, expected) || return false
    x isa getfield(@__MODULE__, expected)
end

function _v5_component_hash(x, role::Symbol, errors)
    _v5_component_type_valid(x, role) || push!(errors, "$(role)_concrete_v5_type_missing")
    value = _v5_get(x, :candidate_hash)
    value isa Digest256 || push!(errors, "$(role)_component_canonical_hash_missing")
    value isa Digest256 ? value : nothing
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
    g2_binding.genome_hash == _v5_get(g2, :candidate_hash) || return false
    _v5_contract_ref(g1) isa GenomeContractRef || return false
    _v5_contract_ref(g2) isa GenomeContractRef || return false
    _v5_contract_ref(g3) isa GenomeContractRef || return false
    ref_errors = String[]
    for (role, genome) in ((:G1, g1), (:G2, g2), (:G3, g3))
        ref = _v5_contract_ref(genome)
        _v5_check_contract_ref(ref, role, ref_errors, String[])
        _v5_check_authoritative_content!(ref, role, ref_errors)
    end
    require_candidate && !isempty(ref_errors) && return false
    identity.candidate_ref == candidate_ref || return false
    identity.g1_ref == _v5_ref_identity(_v5_contract_ref(g1)) || return false
    identity.g2_ref == _v5_ref_identity(_v5_contract_ref(g2)) || return false
    identity.g3_ref == _v5_ref_identity(_v5_contract_ref(g3)) || return false
    identity.g1_genome_hash == _v5_get(g1, :candidate_hash) || return false
    identity.g2_genome_hash == _v5_get(g2, :candidate_hash) || return false
    identity.g2_candidate_binding == semantic_view(g2_binding) || return false
    identity.g3_genome_hash == _v5_get(g3, :candidate_hash) || return false
    identity.g3_child_refs == _v5_g3_child_refs(g3) || return false
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
                             legacy_refs=())
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
    g1_ref, g2_ref, g3_ref = _v5_contract_ref(g1), _v5_contract_ref(g2), _v5_contract_ref(g3)
    for (role, ref) in ((:G1, g1_ref), (:G2, g2_ref), (:G3, g3_ref))
        ref isa GenomeContractRef || push!(errors, "$(role)_public_contract_ref_missing")
        ref isa GenomeContractRef && ref.version == "v5" ||
            (ref isa GenomeContractRef && push!(errors, "$(role)_contract_ref_version_not_v5"))
        _v5_check_contract_ref(ref, role, errors, gaps)
        _v5_check_authoritative_content!(ref, role, errors)
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
    identity_hash = canonical_hash((candidate_ref=candidate_ref, identity=identity, axes=axes))
    receipt = GenomeV5MigrationReceipt(receipt.receipt_id, receipt.candidate_ref,
        receipt.records, receipt.status, receipt.candidate_identity_before,
        identity_hash.value, receipt.scope)
    structural_status = isempty(errors) ? :valid : :fail_closed
    resolution = isempty(errors) && isempty(gaps) ? resolved : terminal_deferred
    CandidateStatePackageV5(candidate_ref, g1, g2, g2_binding, g3, axes, receipt, identity,
                            structural_status, resolution, Tuple(errors), Tuple(gaps), none)
end
