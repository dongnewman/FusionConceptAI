"""G-I1B-A candidate-bound source mutation envelope precursor.

This module materializes the fifty-row local accessor envelope from one trusted
CandidateStatePackageV5, one source-validated E0 binding, and one accepted
GI1AuthorityContextV1.  It is contract software only: it never invokes a
compiler, provider, solver, mesh, or physical model.  Missing source authority
is retained as a typed absence/deferred gap; fixture labels are metadata only.
"""

const _GI1B_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/GI1BSourceMutationEnvelopeV1
version=v1
fields=context_identity,candidate_ref,package_hash,e0_bound_input_hash,outer_refs,component_hashes,version_axes,slots,rows,status,gaps,errors,counters,envelope_hash
row=group,id,field_path,mutation_kind,source_locator,source_type,source_ref,source_hash,original_typed_value,attempted_typed_value,original_hash,attempted_hash,error_code,error_path,resolution,authority_gap,counters,mutation_hash
constraints=exactly five rows per N01..N10; unique id and field_path; trusted package+E0+GI1 context; source-derived values; no fixture-driven error routing; no compiler/provider/solver
"""
const _GI1B_CANONICAL_SOURCE_V1 = """
canonicalization_id=GenomeV5/UP2/gi1b-source-envelope/canonicalization/v1
encoding=UTF-8; line_endings=LF; ordered groups/rows; typed value semantic view; hashes include candidate/context/E0/slot identity
"""
const _GI1B_PROFILE_SOURCE_V1 = """
profile_id=GenomeV5/UP2/gi1b-source-envelope/applicability/v1
scope=local source-bound mutation-envelope precursor; missing authority=terminal_deferred; structural contradiction=fail_closed; unexpected checker fault=program_exception; physical_resolution=terminal_deferred; compile/provider/solver=0; formal B04=false
"""
gi1b_schema_hash() = digest256_text(_GI1B_SCHEMA_SOURCE_V1)
gi1b_canonicalization_hash() = digest256_text(_GI1B_CANONICAL_SOURCE_V1)
gi1b_profile_hash() = digest256_text(_GI1B_PROFILE_SOURCE_V1)

struct GI1BRowSpecV1
    group::Symbol
    id::String
    field_path::String
    source_type::Symbol
    source_locator::String
    mutation_kind::Symbol
    authority_gap::String
    source_kind::Symbol
    eligible::Bool
    function GI1BRowSpecV1(group::Symbol, id::AbstractString, field_path::AbstractString,
                            source_type::Symbol, source_locator::AbstractString,
                            mutation_kind::Symbol, authority_gap::AbstractString,
                            source_kind::Symbol, eligible::Bool=true)
        group in (:N01,:N02,:N03,:N04,:N05,:N06,:N07,:N08,:N09,:N10) ||
            throw(ArgumentError("GI1B row group is not registered"))
        startswith(String(id), String(group) * "-") || throw(ArgumentError("GI1B row id/group mismatch"))
        !isempty(String(field_path)) || throw(ArgumentError("GI1B field path is empty"))
        !isempty(String(source_locator)) || throw(ArgumentError("GI1B source locator is empty"))
        new(group,String(id),String(field_path),source_type,String(source_locator),mutation_kind,
            String(authority_gap),source_kind,eligible)
    end
end
semantic_view(x::GI1BRowSpecV1) = (group=x.group,id=x.id,field_path=x.field_path,
    source_type=x.source_type,source_locator=x.source_locator,mutation_kind=x.mutation_kind,
    authority_gap=x.authority_gap,source_kind=x.source_kind,eligible=x.eligible)

struct GI1BTypedValueV1{T}
    source_type::Symbol
    value::T
end
semantic_view(x::GI1BTypedValueV1) = (source_type=x.source_type,value=x.value)

struct GI1BAbsentSourceIdentityV1
    slot::Symbol
    reason::Symbol
    content_hash::Digest256
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    compatibility_profile_hash::Digest256
    function GI1BAbsentSourceIdentityV1(slot::Symbol, reason::Symbol,
                                        content_hash::Digest256,
                                        schema_hash::Digest256,
                                        canonicalization_hash::Digest256,
                                        profile_hash::Digest256,
                                        compatibility_profile_hash::Digest256)
        slot === :E1 || throw(ArgumentError("GI1B absent source identity must be E1"))
        new(slot, reason, content_hash, schema_hash, canonicalization_hash,
            profile_hash, compatibility_profile_hash)
    end
end
semantic_view(x::GI1BAbsentSourceIdentityV1) =
    (slot=x.slot, reason=x.reason, content_hash=x.content_hash,
     schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash,
     profile_hash=x.profile_hash,
     compatibility_profile_hash=x.compatibility_profile_hash)

struct GI1BUnavailableSourceIdentityV1
    layer::Symbol
    reason::Symbol
    marker_hash::Digest256
    function GI1BUnavailableSourceIdentityV1(layer::Symbol, reason::Symbol,
                                             marker_hash::Digest256)
        layer in (:G1,:G2,:G3,:N05,:PACKAGE) ||
            throw(ArgumentError("GI1B unavailable identity layer is not registered"))
        new(layer, reason, marker_hash)
    end
end
semantic_view(x::GI1BUnavailableSourceIdentityV1) =
    (layer=x.layer, reason=x.reason, marker_hash=x.marker_hash)

struct GI1BSourceBindingV1
    layer::Symbol
    source_ref::Union{GenomeContractRef,QualifiedRefV1,GI1BAbsentSourceIdentityV1,
                      GI1BUnavailableSourceIdentityV1}
    source_hash::Digest256
    source_locator::String
    source_type::Symbol
    original::GI1BTypedValueV1
    authority::Symbol
    gap::String
end
semantic_view(x::GI1BSourceBindingV1) = (layer=x.layer,source_ref=x.source_ref,
    source_hash=x.source_hash,source_locator=x.source_locator,source_type=x.source_type,
    original=x.original,authority=x.authority,gap=x.gap)

struct GI1BMutationEnvelopeRowV1
    group::Symbol
    id::String
    field_path::String
    mutation_kind::Symbol
    binding::GI1BSourceBindingV1
    attempted::GI1BTypedValueV1
    original_hash::Digest256
    attempted_hash::Digest256
    error_code::Symbol
    error_path::String
    resolution::Symbol
    authority_gap::String
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    mutation_hash::Digest256
end
semantic_view(x::GI1BMutationEnvelopeRowV1) = (group=x.group,id=x.id,field_path=x.field_path,
    mutation_kind=x.mutation_kind,binding=x.binding,attempted=x.attempted,
    original_hash=x.original_hash,attempted_hash=x.attempted_hash,error_code=x.error_code,
    error_path=x.error_path,resolution=x.resolution,authority_gap=x.authority_gap,
    compile_calls=x.compile_calls,provider_calls=x.provider_calls,solver_calls=x.solver_calls,
    mutation_hash=x.mutation_hash)

struct GI1BSourceMutationEnvelopeV1
    envelope_version::String
    schema_hash::Digest256
    canonicalization_hash::Digest256
    compatibility_profile_hash::Digest256
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    context_hash::Digest256
    e0_bound_input_hash::Digest256
    outer_refs::NamedTuple
    component_hashes::NamedTuple
    version_axes::NamedTuple
    slot_metadata::NamedTuple
    rows::Tuple{Vararg{GI1BMutationEnvelopeRowV1}}
    status::Symbol
    gaps::Tuple{Vararg{String}}
    errors::Tuple{Vararg{String}}
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
    envelope_hash::Digest256
    function GI1BSourceMutationEnvelopeV1(envelope_version::AbstractString,
                                          schema_hash::Digest256, canonicalization_hash::Digest256,
                                          compatibility_profile_hash::Digest256,
                                          candidate_ref::QualifiedRefV1, package_hash::Digest256,
                                          context_hash::Digest256, e0_bound_input_hash::Digest256,
                                          outer_refs::NamedTuple, component_hashes::NamedTuple,
                                          version_axes::NamedTuple, slot_metadata::NamedTuple,
                                          rows::Tuple{Vararg{GI1BMutationEnvelopeRowV1}},
                                          status::Symbol, gaps::Tuple{Vararg{String}},
                                          errors::Tuple{Vararg{String}}, compile_calls::Integer,
                                          provider_calls::Integer, solver_calls::Integer,
                                          envelope_hash::Digest256)
        String(envelope_version)=="v1" || throw(ArgumentError("GI1B envelope version must be v1"))
        schema_hash==gi1b_schema_hash() || throw(ArgumentError("GI1B schema hash mismatch"))
        canonicalization_hash==gi1b_canonicalization_hash() || throw(ArgumentError("GI1B canonicalization hash mismatch"))
        compatibility_profile_hash==gi1b_profile_hash() || throw(ArgumentError("GI1B profile hash mismatch"))
        candidate_ref.version=="v5" || throw(ArgumentError("GI1B candidate ref must be v5"))
        length(rows)==50 || throw(ArgumentError("GI1B requires exactly 50 rows"))
        ids=String[x.id for x in rows]; paths=String[x.field_path for x in rows]
        length(unique(ids))==50 || throw(ArgumentError("GI1B row ids are not unique"))
        length(unique(paths))==50 || throw(ArgumentError("GI1B field paths are not unique"))
        all(count(==(g), x.group for x in rows)==5 for g in (:N01,:N02,:N03,:N04,:N05,:N06,:N07,:N08,:N09,:N10)) ||
            throw(ArgumentError("GI1B requires five rows per group"))
        status in (:declared_consistent,:terminal_deferred,:fail_closed,:program_exception) ||
            throw(ArgumentError("GI1B status taxonomy invalid"))
        status==:fail_closed && isempty(errors) && throw(ArgumentError("GI1B fail_closed requires errors"))
        status==:declared_consistent && !isempty(errors) && throw(ArgumentError("GI1B declared_consistent cannot contain errors"))
        compile_calls==0 && provider_calls==0 && solver_calls==0 ||
            throw(ArgumentError("GI1B downstream counters must be zero"))
        new(String(envelope_version),schema_hash,canonicalization_hash,compatibility_profile_hash,
            candidate_ref,package_hash,context_hash,e0_bound_input_hash,outer_refs,component_hashes,
            version_axes,slot_metadata,rows,status,gaps,errors,Int(compile_calls),Int(provider_calls),
            Int(solver_calls),envelope_hash)
    end
end
semantic_view(x::GI1BSourceMutationEnvelopeV1) = (envelope_version=x.envelope_version,
    schema_hash=x.schema_hash,canonicalization_hash=x.canonicalization_hash,
    compatibility_profile_hash=x.compatibility_profile_hash,candidate_ref=x.candidate_ref,
    package_hash=x.package_hash,context_hash=x.context_hash,e0_bound_input_hash=x.e0_bound_input_hash,
    outer_refs=x.outer_refs,component_hashes=x.component_hashes,version_axes=x.version_axes,
    slot_metadata=x.slot_metadata,rows=x.rows,status=x.status,gaps=x.gaps,errors=x.errors,
    compile_calls=x.compile_calls,provider_calls=x.provider_calls,solver_calls=x.solver_calls)

const _GI1B_ROW_TABLE = (
    GI1BRowSpecV1(:N01, "N01-01", "/g1/equation_plan/equations/0/input_ranks/0", :Int, "eq.input_ranks[1]", :integer_rank_mutation, "N01 rank/typed-expression invariant is local; no compiler/provider/solver", :actual_A, true),
    GI1BRowSpecV1(:N01, "N01-02", "/g1/equation_plan/equations/0/output_ranks/0", :Int, "eq.output_ranks[1]", :integer_rank_mutation, "N01 rank/typed-expression invariant is local; no compiler/provider/solver", :actual_A, true),
    GI1BRowSpecV1(:N01, "N01-03", "/g1/states/0/physical_type/tensor_rank", :Int, "input_state selected by eq.input_state_refs[1]; physical_type.tensor_rank", :integer_rank_mutation, "state/typed-expression rank join is local; formal cross-layer lowering remains open", :actual_A, true),
    GI1BRowSpecV1(:N01, "N01-04", "/g2/plan/embedding/ambient_dimension", :Int, "package.g2.plan.embedding.ambient_dimension", :integer_dimension_mutation, "G2 structural dimension only; no mesh/physical proof", :actual_A, true),
    GI1BRowSpecV1(:N01, "N01-05", "/g2/plan/field_space/value_shape", :Symbol, "package.g2.plan.field_space.value_shape", :enum_shape_mutation, "G2 field-space shape only; no lowering/provider credit", :actual_A, true),
    GI1BRowSpecV1(:N02, "N02-01", "/g1/equation_plan/equations/0/input_units/0", :UnitSignature, "eq.input_units[1]", :unitsignature_mutation, "G1 unit consistency local; not a G1-to-G3 physical conversion law", :actual_A, true),
    GI1BRowSpecV1(:N02, "N02-02", "/g1/equation_plan/equations/0/output_units/0", :UnitSignature, "eq.output_units[1]", :unitsignature_mutation, "G1 unit consistency local", :actual_A, true),
    GI1BRowSpecV1(:N02, "N02-03", "/g2/plan/field_space/state_unit", :String, "package.g2.plan.field_space.state_unit", :text_unit_mutation, "G2 field-space declaration only", :actual_A, true),
    GI1BRowSpecV1(:N02, "N02-04", "/g3/realization/network/resource_ports/0/unit", :UnitSignature, "selected G3 effort resource port unit", :unitsignature_mutation, "G3 local unit value; no dimensioned G1-to-G3 law", :actual_A, true),
    GI1BRowSpecV1(:N02, "N02-05", "/g3/realization/network/entries/0/unit", :UnitSignature, "selected G3 effort entry unit", :unitsignature_mutation, "G3 ledger unit value; no source/field/return/heat authority", :actual_A, true),
    GI1BRowSpecV1(:N03, "N03-01", "/g1/payload/equation_plan/equations/0/temporal_kind", :TimeKindV1, "equation.temporal_kind", :timekindv1_replacement, "none locally for G1 row", :actual_A, true),
    GI1BRowSpecV1(:N03, "N03-02", "/g1/payload/equation_plan/equations/0/derivative_order", :Int, "equation.derivative_order", :integer_order_mutation, "operator bound is local", :actual_A, true),
    GI1BRowSpecV1(:N03, "N03-03", "/g1/payload/grammar_profile/operators/0/temporal_kinds", :TupleTimeKindV1, "matched operator.temporal_kinds", :tuple_membership_mutation, "operator temporal whitelist is local", :actual_A, true),
    GI1BRowSpecV1(:N03, "N03-04", "/g3/control/controllers/0/events/0/trigger", :Symbol, "event_value.trigger", :enum_trigger_mutation, "missing_candidate_bound_g3_event_time_basis_policy", :actual_A, true),
    GI1BRowSpecV1(:N03, "N03-05", "/g3/control/controllers/0/events/0/time", :RationalInt64, "event_value.time", :rational_event_time_mutation, "missing_candidate_bound_g3_event_time_basis_policy", :actual_A, true),
    GI1BRowSpecV1(:N04, "N04-01", "/g3/realization/network/accounts/0/owner", :String, "network.accounts[1].owner", :owner_mutation, "owner_uniqueness_scope_missing_shared_owner_is_legal", :actual_A, true),
    GI1BRowSpecV1(:N04, "N04-02", "/g3/realization/network/closures/0/account_ids", :Tuple_String, "network.closures[1].account_ids", :duplicate_account_mutation, "G3 local closure rule; G1 occurrence-to-G3 account join absent", :actual_A, true),
    GI1BRowSpecV1(:N04, "N04-03", "/g3/realization/network/entries/0/account_id", :String, "network.entries[1].account_id", :wrong_account_mutation, "G1 occurrence-to-G3 account exact join missing", :actual_A, true),
    GI1BRowSpecV1(:N04, "N04-04", "/g3/realization/network/entries/0/component_id", :String, "network.entries[1].component_id", :passive_component_reference_mutation, "G3 local component/account closure only", :actual_A, true),
    GI1BRowSpecV1(:N04, "N04-05", "/g3/realization/network/entries/1/coefficient", :RationalInt64, "network.entries[2].coefficient", :capacity_exceeding_rational_mutation, "capacity is local; cross-layer energy boundary join missing", :actual_A, true),
    GI1BRowSpecV1(:N05, "N05-01", "/n05/left_endpoint/endpoint_ref", :QualifiedRefV1, "authored E1 declaration left_endpoint.endpoint_ref", :foreign_qualifiedrefv1, "A has no authored endpoint authority; absent declaration is terminal_deferred", :authored_E1_over_actual_A, true),
    GI1BRowSpecV1(:N05, "N05-02", "/n05/right_endpoint/endpoint_ref", :QualifiedRefV1, "authored E1 declaration right_endpoint.endpoint_ref", :foreign_qualifiedrefv1, "A has no authored endpoint authority; absent declaration is terminal_deferred", :authored_E1_over_actual_A, true),
    GI1BRowSpecV1(:N05, "N05-03", "/n05/left_endpoint/sign", :Int8, "authored law left_sign", :zero_semantic_sign_mutation, "requires authored typed law relation; G2 normal is not flux authority", :authored_E1_over_actual_A, true),
    GI1BRowSpecV1(:N05, "N05-04", "/n05/right_endpoint/sign", :Int8, "authored law right_sign", :same_sign_mutation, "requires authored typed law relation", :authored_E1_over_actual_A, true),
    GI1BRowSpecV1(:N05, "N05-05", "/n05/right_endpoint/unit", :UnitSignature, "declaration.right_endpoint.unit.source.source_ref", :dimensionally_mismatched_unitsignature, "G1 eq.input_units and G2 normal cannot supply flux-unit authority; absent branch terminal_deferred", :authored_E1_over_actual_A, true),
    GI1BRowSpecV1(:N06, "N06-01", "/g3/realization/network/resource_ports/<selected-index>/port_id", :String, "selected unique G3 effort port.port_id", :wrong_resource_port_ref, "g1_source_field_to_g3_return_heat_ledger_join_missing", :actual_A, true),
    GI1BRowSpecV1(:N06, "N06-02", "/g3/realization/network/entries/<selected-index>/account_id", :String, "entry selected by port_id; entry.account_id", :wrong_entry_account, "dimensioned source/field/return/heat law absent", :actual_A, true),
    GI1BRowSpecV1(:N06, "N06-03", "/g3/binding/links/<selected-index>/resource_port_id", :String, "selected flow link.resource_port_id", :missing_wrong_control_link, "selected-flow link local; cross-layer law absent", :actual_A, true),
    GI1BRowSpecV1(:N06, "N06-04", "/g3/realization/network/closures/<selected-index>/expected_balance", :RationalInt64, "closure containing selected effort account; expected_balance", :balance_mutation, "owner/energy boundary mapping absent", :actual_A, true),
    GI1BRowSpecV1(:N06, "N06-05", "/g3/realization/network/resource_ports/<selected-index>/kind", :Symbol, "selected effort port.kind", :wrong_resource_kind, "G1 dimensionless-to-G3 power law absent", :actual_A, true),
    GI1BRowSpecV1(:N07, "N07-01", "/g2/contract/regions/0/lower", :NTuple3_RationalInt64, "g2.region_interface.regions[1].lower", :lower_out_of_envelope, "current G2 admitted structural envelope only", :actual_A, true),
    GI1BRowSpecV1(:N07, "N07-02", "/g2/contract/regions/0/upper", :NTuple3_RationalInt64, "g2.region_interface.regions[1].upper", :upper_out_of_envelope, "current G2 admitted structural envelope only", :actual_A, true),
    GI1BRowSpecV1(:N07, "N07-03", "/g2/plan/exterior/boundary_faces", :TupleSymbol, "g2.plan.exterior.boundary_faces", :drop_required_face, "no universal geometry/mesh proof", :actual_A, true),
    GI1BRowSpecV1(:N07, "N07-04", "/g2/plan/exterior/boundary_patches/0/lower", :NTuple2_RationalInt64, "patch selected by face/region; patch.lower", :tangent_patch_bounds_out_of_domain, "face-to-tangent mapping is current limited rule", :actual_A, true),
    GI1BRowSpecV1(:N07, "N07-05", "/g2/plan/exterior/boundary_condition", :Symbol, "g2.plan.exterior.boundary_condition", :none_declared_condition, "current G2 admission rule only", :actual_A, true),
    GI1BRowSpecV1(:N08, "N08-01", "/g2/plan/chart/axes", :TupleSymbol, "g2.plan.chart.axes", :invalid_axis_tuple, "chart structural rule only", :actual_A, true),
    GI1BRowSpecV1(:N08, "N08-02", "/g2/plan/chart/map_kind", :Symbol, "g2.plan.chart.map_kind", :invalid_map_kind, "chart structural rule only", :actual_A, true),
    GI1BRowSpecV1(:N08, "N08-03", "/g2/plan/mesh/cells_per_region", :NTuple3_Int, "g2.plan.mesh.cells_per_region", :nonpositive_cells, "mesh plan declaration only; no mesh execution", :actual_A, true),
    GI1BRowSpecV1(:N08, "N08-04", "/g2/plan/mesh/basis", :Symbol, "g2.plan.mesh.basis", :invalid_basis, "mesh basis declaration only", :actual_A, true),
    GI1BRowSpecV1(:N08, "N08-05", "/g2/contract/interfaces", :Tuple_QualifiedRefV1, "g2.region_interface.interfaces[*].interface_ref", :duplicate_interface_ref, "regions-1 is only current G2 admission scope, not universal topology theorem", :actual_A, true),
    GI1BRowSpecV1(:N09, "N09-01", "/g1/grammar_profile/operators/0/provider_match", :Symbol, "g1 matched operator.provider_match", :no_match_out_of_domain_invalid_signature, "provider capability absent; provider is never invoked", :actual_A, true),
    GI1BRowSpecV1(:N09, "N09-02", "/g2/grammar_profile/provider_match", :Symbol, "g2.grammar_profile.provider_match", :no_match_out_of_domain_invalid_signature, "provider capability absent; provider is never invoked", :actual_A, true),
    GI1BRowSpecV1(:N09, "N09-03", "/g2/plan/exterior/provider_match", :Symbol, "g2.plan.exterior.provider_match", :no_match_out_of_domain_invalid_signature, "provider capability absent; provider is never invoked", :actual_A, true),
    GI1BRowSpecV1(:N09, "N09-04", "/g3/realization/provider_match", :Symbol, "g3.realization.provider_match", :no_match_out_of_domain_invalid_signature, "provider capability absent; provider is never invoked", :actual_A, true),
    GI1BRowSpecV1(:N09, "N09-05", "/g3/control/provider_match", :Symbol, "g3.control.provider_match", :no_match_out_of_domain_invalid_signature, "provider capability absent; provider is never invoked", :actual_A, true),
    GI1BRowSpecV1(:N10, "N10-01", "/candidate/component_identity/g1_ref/schema_hash", :Digest256, "package.component_identity.g1_ref.schema_hash", :foreign_g1_schema_hash, "none for present structural mismatch", :actual_A, true),
    GI1BRowSpecV1(:N10, "N10-02", "/candidate/component_identity/g2_ref/canonicalization_hash", :Digest256, "package.component_identity.g2_ref.canonicalization_hash", :foreign_g2_canonicalization_hash, "none for present structural mismatch", :actual_A, true),
    GI1BRowSpecV1(:N10, "N10-03", "/g3/binding/contract_binding/contract_ref", :GenomeContractRef, "actual typed G3 child contract_ref compared field-by-field to component_identity.g3_child_refs.binding", :wrong_layer_ref, "V4 legacy provenance remains separate terminal_deferred", :actual_A, true),
    GI1BRowSpecV1(:N10, "N10-04", "/candidate/candidate_hash", :Digest256, "package.candidate_hash vs canonical package identity formula", :attempted_candidate_hash, "fresh identity formula is present; no legacy proof", :actual_A, true),
    GI1BRowSpecV1(:N10, "N10-05", "/migration_receipt/candidate_identity_after", :String, "package.migration_receipt.candidate_identity_after vs canonical identity formula", :attempted_fresh_receipt_identity_after, "fresh receipt is pending/empty; V4 legacy receipt mapping/provenance absent => terminal_deferred", :actual_A, true),
)

const GI1B_ROW_SPECS_V1 = _GI1B_ROW_TABLE

_gi1b_prop(x, s::Symbol) = x !== nothing && hasproperty(x,s) ? getproperty(x,s) : nothing
function _gi1b_index(x, i::Int)
    x isa Tuple || x isa AbstractVector || return nothing
    1 <= i <= length(x) ? x[i] : nothing
end
function _gi1b_walk(root, path::AbstractString)
    current=root
    for token in split(strip(String(path), ['/']), '/')
        isempty(token) && continue
        startswith(token,"<") && return nothing
        if all(isdigit, token)
            current=_gi1b_index(current,parse(Int,token)+1)
        else
            current=_gi1b_prop(current,Symbol(token))
            if current === nothing && root !== nothing && hasproperty(root,:payload)
                payload=getproperty(root,:payload)
                current=_gi1b_prop(payload,Symbol(token))
            end
        end
        current === nothing && return nothing
    end
    current
end

function _gi1b_root_for(package, context, path::String)
    seg=split(strip(path,['/']),'/')
    isempty(seg) && return nothing,""
    head=first(seg); rest=join(seg[2:end],"/")
    head=="g1" && return package.g1,rest
    head=="g2" && return package.g2,rest
    head=="g3" && return package.g3,rest
    head=="candidate" && return package,rest
    head=="migration_receipt" && return package.migration_receipt,rest
    if head == "n05"
        if context.e1 isa GI1N05PresentAuthoritySlotV1
            return context.e1.authority.declaration, join(seg[2:end], "/")
        end
        return nothing, rest
    end
    nothing,rest
end

function _gi1b_layer(path::String)
    head=first(split(strip(path,['/']),'/'))
    head in ("g1","g2","g3") ? Symbol(uppercase(head)) :
        startswith(path,"/n05") ? :N05 : :PACKAGE
end

function _gi1b_ref(package, context, layer::Symbol)
    layer===:G1 && return context.g1_ref
    layer===:G2 && return context.g2_ref
    layer===:G3 && return context.g3_ref
    layer===:N05 && context.e1 isa GI1N05PresentAuthoritySlotV1 && return context.e1.authority.g3_ref
    layer===:N05 && return context.g3_ref
    context.g1_ref
end
function _gi1b_component_hash(package, context, layer::Symbol)
    layer===:G1 && return context.g1_component_hash
    layer===:G2 && return context.g2_component_hash
    layer===:G3 && return context.g3_component_hash
    layer===:N05 && return context.g3_component_hash
    context.package_hash
end

function _gi1b_unavailable_source_identity(package, context, spec::GI1BRowSpecV1)
    layer = _gi1b_layer(spec.field_path)
    marker = digest256_text("gi1b-unavailable-source-identity/v1/$(layer)/$(spec.id)/$(spec.field_path)")
    identity = GI1BUnavailableSourceIdentityV1(layer, :source_identity_unavailable, marker)
    identity, marker
end

function _gi1b_selected_g3(package, spec::GI1BRowSpecV1)
    realization = package.g3.realization
    network = realization.network
    ports = Tuple(x for x in network.resource_ports if x.kind === :effort)
    length(ports) == 1 || return nothing
    port = only(ports)
    entries = Tuple(x for x in network.entries if x.port_id == port.port_id)
    # Select the closure from the actual effort entry; no guessed index is
    # admitted when the local source is ambiguous.
    entry = length(entries) == 1 ? only(entries) : nothing
    entry === nothing && return nothing
    closures = Tuple(x for x in network.closures if entry.account_id in x.account_ids)
    closure = length(closures) == 1 ? only(closures) : nothing
    links = Tuple(x for x in package.g3.binding.links if
                  x.resource_port_id in Tuple(p.port_id for p in network.resource_ports if p.kind === :flow))
    link = length(links) == 1 ? only(links) : nothing
    spec.id == "N06-01" && return port.port_id
    spec.id == "N06-02" && return entry.account_id
    spec.id == "N06-03" && link !== nothing && return link.resource_port_id
    spec.id == "N06-04" && closure !== nothing && return closure.expected_balance
    spec.id == "N06-05" && return port.kind
    nothing
end

function _gi1b_actual_value(package, context, spec::GI1BRowSpecV1)
    # Some matrix locators are deliberately semantic aliases.  Resolve them
    # from the same actual A objects used by the N03/N06 projections.
    if startswith(spec.id, "N05-")
        context.e1 isa GI1N05PresentAuthoritySlotV1 || return nothing
        declaration = context.e1.authority.declaration
        spec.id == "N05-01" && return declaration.left_endpoint.endpoint_ref
        spec.id == "N05-02" && return declaration.right_endpoint.endpoint_ref
        spec.id == "N05-03" && return declaration.left_endpoint.sign
        spec.id == "N05-04" && return declaration.right_endpoint.sign
        spec.id == "N05-05" && return declaration.right_endpoint.unit.unit
        return nothing
    elseif spec.id == "N01-03"
        eq = first(package.g1.payload.equation_plan.equations)
        state_id = first(eq.input_state_refs)
        states = Tuple(x for x in package.g1.payload.states if x.state_id == state_id)
        return length(states) == 1 ? states[1].physical_type.tensor_rank : nothing
    elseif spec.id == "N02-04"
        ports = Tuple(x for x in package.g3.realization.network.resource_ports if x.kind === :effort)
        return length(ports) == 1 ? only(ports).unit : nothing
    elseif spec.id == "N02-05"
        ports = Tuple(x for x in package.g3.realization.network.resource_ports if x.kind === :effort)
        length(ports) == 1 || return nothing
        entries = Tuple(x for x in package.g3.realization.network.entries if x.port_id == only(ports).port_id)
        return length(entries) == 1 ? only(entries).unit : nothing
    elseif spec.id == "N03-03" || spec.id == "N09-01"
        eq = first(package.g1.payload.equation_plan.equations)
        ops = Tuple(x for x in package.g1.payload.grammar_profile.operators if x.ref == eq.operator_ref)
        return length(ops) == 1 ? (spec.id == "N03-03" ? only(ops).temporal_kinds : only(ops).provider_match) : nothing
    elseif startswith(spec.id, "N06-")
        return _gi1b_selected_g3(package, spec)
    elseif spec.id == "N07-01" || spec.id == "N07-02"
        regions = package.g2.region_interface.regions
        length(regions) >= 1 || return nothing
        region = first(regions)
        return spec.id == "N07-01" ? region.lower : region.upper
    elseif spec.id == "N07-04"
        regions = package.g2.region_interface.regions
        isempty(regions) && return nothing
        candidates = Tuple(x for x in package.g2.plan.exterior.boundary_patches if
                           x.region_id == first(regions).region_id && x.face === :x_min)
        return length(candidates) == 1 ? only(candidates).lower : nothing
    elseif spec.id == "N08-05"
        return Tuple(x.interface_ref for x in package.g2.region_interface.interfaces)
    end
    root,rest=_gi1b_root_for(package,context,spec.field_path)
    root === nothing ? nothing : _gi1b_walk(root,rest)
end

function _gi1b_source_identity(package, context, spec::GI1BRowSpecV1)
    if spec.group === :N05 && context.e1 isa GI1N05PresentAuthoritySlotV1
        declaration = context.e1.authority.declaration
        if spec.id == "N05-01"
            return declaration.left_endpoint.endpoint_ref, declaration.declaration_hash
        elseif spec.id == "N05-02"
            return declaration.right_endpoint.endpoint_ref, declaration.declaration_hash
        elseif spec.id == "N05-03" || spec.id == "N05-04"
            return declaration.law.law_ref, declaration.law.law_hash
        elseif spec.id == "N05-05"
            return declaration.right_endpoint.unit.source.source_ref,
                   declaration.right_endpoint.unit.source.source_hash
        end
    elseif spec.group === :N05 && context.e1 isa GI1AbsentAuthoritySlotV1
        absent = context.e1
        identity = GI1BAbsentSourceIdentityV1(absent.slot, absent.reason,
            absent.content_hash, absent.schema_hash, absent.canonicalization_hash,
            absent.profile_hash, absent.compatibility_profile_hash)
        return identity, absent.content_hash
    elseif spec.id == "N10-01"
        return context.g1_ref, context.g1_component_hash
    elseif spec.id == "N10-02"
        return context.g2_ref, context.g2_component_hash
    elseif spec.id == "N10-03"
        return context.g3_ref, context.g3_component_hash
    elseif spec.id == "N10-04" || spec.id == "N10-05"
        return package.candidate_ref, package.candidate_hash
    end
    layer=_gi1b_layer(spec.field_path)
    return _gi1b_ref(package,context,layer), _gi1b_component_hash(package,context,layer)
end

function _gi1b_read(package, context, spec::GI1BRowSpecV1)
    layer=_gi1b_layer(spec.field_path)
    value = _gi1b_actual_value(package,context,spec)
    # E2 is absent in the current A context.  Preserve any uniquely selected
    # G3 typed value, but keep the cross-layer authority classification deferred.
    if spec.group===:N06 && !(context.e2 isa GI1N06PresentAuthoritySlotV1)
        value === nothing && return nothing, layer, :typed_absent, "N06 dimensioned G1-to-G3 authority is absent in current A/E0"
        return value, layer, :typed_absent, "N06 dimensioned G1-to-G3 authority is absent in current A/E0"
    end
    value === nothing && return nothing, layer, :terminal_deferred, "source locator did not resolve on actual A typed object"
    value, layer, :source_bound, ""
end

function _gi1b_typed(value, spec::GI1BRowSpecV1)
    GI1BTypedValueV1{typeof(value)}(spec.source_type,value)
end

function _gi1b_type_matches(value, source_type::Symbol)
    source_type === :Int && return value isa Int
    source_type === :Int8 && return value isa Int8
    source_type === :String && return value isa String
    source_type === :Symbol && return value isa Symbol
    source_type === :TimeKindV1 && return value isa TimeKindV1
    source_type === :QualifiedRefV1 && return value isa QualifiedRefV1
    source_type === :GenomeContractRef && return value isa GenomeContractRef
    source_type === :Digest256 && return value isa Digest256
    source_type === :UnitSignature && return value isa UnitSignature
    source_type === :RationalInt64 && return value isa Rational{Int64}
    source_type === :TupleTimeKindV1 &&
        return value isa Tuple && all(x -> x isa TimeKindV1, value)
    source_type === :Tuple_String &&
        return value isa Tuple && all(x -> x isa String, value)
    source_type === :TupleSymbol &&
        return value isa Tuple && all(x -> x isa Symbol, value)
    source_type === :Tuple_QualifiedRefV1 &&
        return value isa Tuple && all(x -> x isa QualifiedRefV1, value)
    source_type === :NTuple3_RationalInt64 &&
        return value isa Tuple && length(value) == 3 && all(x -> x isa Rational{Int64}, value)
    source_type === :NTuple2_RationalInt64 &&
        return value isa Tuple && length(value) == 2 && all(x -> x isa Rational{Int64}, value)
    source_type === :NTuple3_Int &&
        return value isa Tuple && length(value) == 3 && all(x -> x isa Int, value)
    false
end
function _gi1b_absent(spec::GI1BRowSpecV1)
    GI1BTypedValueV1{Nothing}(spec.source_type,nothing)
end
function _gi1b_attempt(value, spec::GI1BRowSpecV1)
    value===nothing && return GI1BTypedValueV1{NamedTuple}(spec.source_type,(absent=true,mutation=spec.mutation_kind))
    mutated=try
        value isa Bool ? !value : value isa Integer ? value+one(value) :
        value isa Rational ? value+one(value) : value isa AbstractString ? value*"__gi1b_mutated" :
        value isa Symbol ? Symbol("gi1b_invalid_",value) : value isa TimeKindV1 ?
            (value == static_time ? event_time : static_time) :
        value isa QualifiedRefV1 ? QualifiedRefV1(value.id * "/gi1b-foreign", value.version) :
        value isa GenomeContractRef ? GenomeContractRef(value.uri * "/gi1b-foreign", value.version,
            value.schema_hash, value.canonicalization_hash, value.compatibility_profile) :
        value isa UnitSignature ? UnitSignature((1,0,0,0,0,0,0)) :
        value isa Digest256 ? digest256_text(string(value)*":gi1b") :
        value isa Tuple ? (value..., :gi1b_mutated) :
        (mutation=spec.mutation_kind,original=semantic_view(value))
    catch
        (mutation=spec.mutation_kind,original=repr(value))
    end
    GI1BTypedValueV1{typeof(mutated)}(spec.source_type,mutated)
end
function _gi1b_hash_typed(value::GI1BTypedValueV1)
    canonical_hash((source_type=value.source_type,value=value.value))
end
function _gi1b_status(spec::GI1BRowSpecV1, authority::Symbol, attempted)
    authority in (:typed_absent,:terminal_deferred) && return (:terminal_deferred,:authority_gap,"$(spec.field_path):authority_gap")
    spec.group===:N06 && return (:terminal_deferred,:authority_gap,"N06 dimensioned authority remains absent")
    spec.group===:N09 && return (:terminal_deferred,:provider_gap,"provider is not invoked")
    spec.id=="N10-05" && return (:terminal_deferred,:legacy_provenance_gap,"fresh receipt only; legacy V4 provenance absent")
    spec.id in ("N03-04","N03-05","N04-01") &&
        return (:terminal_deferred,:authority_gap,"$(spec.field_path):cross_layer_authority_gap")
    attempted === nothing && return (:terminal_deferred,:authority_gap,"attempted source value unavailable")
    code = spec.group in (:N04,:N05) ?
        (spec.id in ("N05-01","N05-02","N05-03","N05-04") ? :invalid_closure :
         spec.group === :N04 ? :invalid_closure : :invalid_type) :
        spec.group in (:N07,:N08) ? :invalid_boundary : :invalid_type
    (:fail_closed,code,"$(spec.field_path):source_invariant")
end

function _gi1b_check_trusted(package, e0, context)
    isdefined(@__MODULE__,:gi1_validate_authority_context) || return true
    n05 = context.e1 isa GI1N05PresentAuthoritySlotV1 ? context.e1.authority : nothing
    n06 = context.e2 isa GI1N06PresentAuthoritySlotV1 ? context.e2.mapping : nothing
    result=gi1_validate_authority_context(context,package,e0; n05=n05,n06=n06)
    details = join(String.(result.errors), ";")
    result.status===:program_exception && throw(GI1ProgramException(
        "GI1B trusted context program_exception: $details"))
    result.status===:valid || throw(ArgumentError("GI1B trusted context validation failed: $details"))
    true
end

function _gi1b_exception_row(package, context, spec::GI1BRowSpecV1, err)
    layer = _gi1b_layer(spec.field_path)
    original = _gi1b_absent(spec)
    attempted = _gi1b_attempt(nothing, spec)
    oh = _gi1b_hash_typed(original); ah = _gi1b_hash_typed(attempted)
    ref, sh = if spec.group === :N05 && context.e1 isa GI1AbsentAuthoritySlotV1
        absent = context.e1
        (GI1BAbsentSourceIdentityV1(absent.slot, absent.reason, absent.content_hash,
            absent.schema_hash, absent.canonicalization_hash, absent.profile_hash,
            absent.compatibility_profile_hash), absent.content_hash)
    else
        try
            _gi1b_source_identity(package, context, spec)
        catch
            _gi1b_unavailable_source_identity(package, context, spec)
        end
    end
    detail = "$(spec.field_path):$(sprint(showerror, err))"
    binding = GI1BSourceBindingV1(layer, ref, sh, spec.source_locator,
        spec.source_type, original, :program_exception, detail)
    mh = canonical_hash((id=spec.id, field_path=spec.field_path,
        mutation_kind=spec.mutation_kind, binding=binding, original=oh,
        attempted=ah, error_code=:program_exception, error_path=spec.field_path,
        resolution=:program_exception))
    GI1BMutationEnvelopeRowV1(spec.group, spec.id, spec.field_path,
        spec.mutation_kind, binding, attempted, oh, ah, :program_exception,
        spec.field_path, :program_exception, spec.authority_gap, 0, 0, 0, mh)
end
function _gi1b_row(package, context, spec::GI1BRowSpecV1)
    value,layer,authority,gap=_gi1b_read(package,context,spec)
    original=value===nothing ? _gi1b_absent(spec) : _gi1b_typed(value,spec)
    attempted=_gi1b_attempt(value,spec)
    oh=_gi1b_hash_typed(original); ah=_gi1b_hash_typed(attempted)
    if value !== nothing && !_gi1b_type_matches(value, spec.source_type)
        resolution,code,reason=:fail_closed,:invalid_type,
            "$(spec.field_path):declared_source_type_mismatch"
    else
        resolution,code,reason=_gi1b_status(spec,authority,attempted.value)
    end
    ref,sh=_gi1b_source_identity(package,context,spec)
    runtime_gap = isempty(gap) && resolution === :terminal_deferred ? reason : gap
    binding=GI1BSourceBindingV1(layer,ref,sh,spec.source_locator,spec.source_type,original,authority,
        runtime_gap)
    mh=canonical_hash((id=spec.id,field_path=spec.field_path,mutation_kind=spec.mutation_kind,
        binding=binding,original=oh,attempted=ah,error_code=code,error_path=spec.field_path,
        resolution=resolution))
    GI1BMutationEnvelopeRowV1(spec.group,spec.id,spec.field_path,spec.mutation_kind,binding,attempted,
        oh,ah,code,spec.field_path,resolution,spec.authority_gap,0,0,0,mh)
end

function _gi1b_aggregate_status(rows)
    resolutions = Tuple(r isa Symbol ? r : r.resolution for r in rows)
    if :program_exception in resolutions
        return :program_exception
    elseif :fail_closed in resolutions
        return :fail_closed
    elseif :terminal_deferred in resolutions
        return :terminal_deferred
    end
    :declared_consistent
end

function _gi1b_build_rows(package, context, specs, row_builder::Function)
    Tuple(try
        row_builder(package,context,s)
    catch err
        _gi1b_exception_row(package,context,s,err)
    end for s in specs)
end

function _gi1b_assemble_envelope(package, e0, context, rows)
    gaps=Tuple(unique(String[r.binding.gap for r in rows if !isempty(r.binding.gap)]))
    status=_gi1b_aggregate_status(rows)
    errors=Tuple(unique(String[r.error_path * ":" * String(r.error_code) for r in rows
                              if r.resolution in (:fail_closed,:program_exception)]))
    outer_refs=(g1=context.g1_ref,g2=context.g2_ref,g3=context.g3_ref)
    hashes=(g1=context.g1_component_hash,g2=context.g2_component_hash,g3=context.g3_component_hash)
    slots=(e1=context.e1 isa GI1N05PresentAuthoritySlotV1 ? :present : :absent,
           e2=context.e2 isa GI1N06PresentAuthoritySlotV1 ? :present : :typed_absent,
           e1_content_hash=hasproperty(context.e1,:content_hash) ? context.e1.content_hash : nothing,
           e2_content_hash=hasproperty(context.e2,:content_hash) ? context.e2.content_hash : nothing)
    body=(envelope_version="v1",schema_hash=gi1b_schema_hash(),canonicalization_hash=gi1b_canonicalization_hash(),
        compatibility_profile_hash=gi1b_profile_hash(),candidate_ref=package.candidate_ref,
        package_hash=package.candidate_hash,context_hash=context.context_hash,e0_bound_input_hash=e0.bound_input_hash,
        outer_refs=outer_refs,component_hashes=hashes,version_axes=package.version_axes,slot_metadata=slots,
        rows=rows,status=status,gaps=gaps,errors=errors,compile_calls=0,provider_calls=0,solver_calls=0)
    GI1BSourceMutationEnvelopeV1("v1",gi1b_schema_hash(),gi1b_canonicalization_hash(),gi1b_profile_hash(),
        package.candidate_ref,package.candidate_hash,context.context_hash,e0.bound_input_hash,outer_refs,hashes,
        package.version_axes,slots,rows,status,gaps,errors,0,0,0,canonical_hash(body))
end

function _gi1b_source_mutation_envelope_with_row_builder(package::CandidateStatePackageV5,
                                                         e0::UP2CandidatePhysicalBindingV1,
                                                         context::GI1AuthorityContextV1,
                                                         row_builder::Function;
                                                         specs::Tuple{Vararg{GI1BRowSpecV1}}=GI1B_ROW_SPECS_V1)
    _gi1b_check_trusted(package,e0,context)
    length(specs)==50 || throw(ArgumentError("GI1B requires the frozen 50-row matrix"))
    rows = _gi1b_build_rows(package,context,specs,row_builder)
    _gi1b_assemble_envelope(package,e0,context,rows)
end

function gi1b_source_mutation_envelope(package::CandidateStatePackageV5,
                                       e0::UP2CandidatePhysicalBindingV1,
                                       context::GI1AuthorityContextV1;
                                       specs::Tuple{Vararg{GI1BRowSpecV1}}=GI1B_ROW_SPECS_V1)
    _gi1b_source_mutation_envelope_with_row_builder(package,e0,context,_gi1b_row;
        specs=specs)
end
