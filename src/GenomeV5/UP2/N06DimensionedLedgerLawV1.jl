"""AD-27 H0-A candidate-owned dimensioned-law contract.

The low-level constructor is a schema-only construction control.  Source-backed
admission is separate and recomputes the complete CandidateStatePackageV5 and
E0 identity before a present law can be accepted.
"""

const _N06_H0A_SCHEMA_SOURCE_V1 = """
schema_id=GenomeV5/UP2/N06DimensionedLedgerLawV1
version=v1
status=present|typed_absent
binding=CandidateStatePackageV5,E0,refs,component_hashes,version_axes
endpoints=exact_four_G1_occurrences,G2_region_interface,G3_port_account_entry_closure_link_feedback
law=variables,unit_equation,scale,efficiency,calibration_provenance,direction,sign,closure,closure_relation,owner_scope,role_contract
provenance=typed_source_ref,source_hash,source_path,source_type at every endpoint/law input
classification=missing:terminal_deferred; contradiction:fail_closed; exception:program_exception
execution=compile=0;provider=0;solver=0
"""
const _N06_H0A_CANONICAL_SOURCE_V1 = """
canonicalization_id=GenomeV5/UP2/n06-dimensioned-ledger-law/canonicalization/v2
encoding=UTF-8; line_endings=LF; tuples=declared order
identity=binding,endpoints,law,typed_provenance,absence
"""
const _N06_H0A_PROFILE_SOURCE_V1 = """
profile_id=GenomeV5/UP2/n06-dimensioned-ledger-law/applicability/v2
scope=contract_only; physical_resolution=unknown
missing_authority=terminal_deferred; contradictory_typed_values=fail_closed
schema_only_present=never_source_backed
"""
n06_h0a_schema_hash() = digest256_text(_N06_H0A_SCHEMA_SOURCE_V1)
n06_h0a_canonicalization_hash() = digest256_text(_N06_H0A_CANONICAL_SOURCE_V1)
n06_h0a_profile_hash() = digest256_text(_N06_H0A_PROFILE_SOURCE_V1)

abstract type N06H0ADeclarationV1 end

struct N06H0ASourceProvenanceV1
    source_ref::QualifiedRefV1
    source_hash::Digest256
    source_path::String
    source_type::Symbol
    function N06H0ASourceProvenanceV1(source_ref::QualifiedRefV1,
                                      source_hash::Digest256,
                                      source_path::AbstractString,
                                      source_type)
        isempty(source_ref.id) && throw(ArgumentError("H0-A source ref is required"))
        isempty(String(source_path)) && throw(ArgumentError("H0-A source path is required"))
        st = source_type isa Symbol ? source_type : Symbol(source_type)
        isempty(String(st)) && throw(ArgumentError("H0-A source type is required"))
        new(source_ref, source_hash, String(source_path), st)
    end
end
semantic_view(x::N06H0ASourceProvenanceV1) =
    (source_ref=x.source_ref, source_hash=x.source_hash,
     source_path=x.source_path, source_type=x.source_type)

struct N06H0AInputBindingV1
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    e0_schema_hash::Digest256
    e0_canonicalization_hash::Digest256
    e0_profile_hash::Digest256
    e0_binding_hash::Digest256
    e0_bound_input_hash::Digest256
    g1_ref::GenomeContractRef
    g2_ref::GenomeContractRef
    g3_ref::GenomeContractRef
    g1_component_hash::Digest256
    g2_component_hash::Digest256
    g3_component_hash::Digest256
    version_axes::NamedTuple
    function N06H0AInputBindingV1(candidate_ref::QualifiedRefV1,
            package_hash::Digest256, e0_schema_hash::Digest256,
            e0_canonicalization_hash::Digest256, e0_profile_hash::Digest256,
            e0_binding_hash::Digest256, e0_bound_input_hash::Digest256,
            g1_ref::GenomeContractRef, g2_ref::GenomeContractRef,
            g3_ref::GenomeContractRef, g1_component_hash::Digest256,
            g2_component_hash::Digest256, g3_component_hash::Digest256,
            version_axes::NamedTuple)
        candidate_ref.version == "v5" || throw(ArgumentError("H0-A candidate ref must use v5"))
        all(r -> r.version == "v5" && !isempty(r.uri) && !isempty(r.compatibility_profile),
            (g1_ref, g2_ref, g3_ref)) || throw(ArgumentError("H0-A public refs are incomplete"))
        all(hasproperty(version_axes, x) for x in (:g1, :g2, :g3)) ||
            throw(ArgumentError("H0-A version axes must contain g1,g2,g3"))
        new(candidate_ref, package_hash, e0_schema_hash, e0_canonicalization_hash,
            e0_profile_hash, e0_binding_hash, e0_bound_input_hash, g1_ref, g2_ref, g3_ref,
            g1_component_hash, g2_component_hash, g3_component_hash, version_axes)
    end
end

_n06_h0a_source_complete(x) = hasproperty(x, :provenance) &&
    getproperty(x, :provenance) isa N06H0ASourceProvenanceV1

struct N06H0AEndpointSetV1
    g1_occurrences::Tuple{Vararg{NamedTuple}}
    g2::NamedTuple
    g3::NamedTuple
    provenance::NamedTuple
    function N06H0AEndpointSetV1(g1_occurrences, g2::NamedTuple, g3::NamedTuple)
        occ = Tuple(g1_occurrences)
        length(occ) == 4 || throw(ArgumentError("H0-A requires exactly four G1 occurrences"))
        all(hasproperty(x, :selector) && hasproperty(x, :ledger_id) &&
            hasproperty(x, :equation_id) && hasproperty(x, :closure_id) &&
            hasproperty(x, :unit) && hasproperty(x, :effect) &&
            hasproperty(x, :coefficient) for x in occ) ||
            throw(ArgumentError("H0-A G1 occurrence identity is incomplete"))
        selectors = Tuple(x.selector for x in occ)
        length(unique(selectors)) == 4 || throw(ArgumentError("H0-A G1 occurrence selectors are not unique"))
        for field in (:region_id, :interface_ref, :left_region_id, :right_region_id,
                      :interface_side, :boundary_face, :boundary_locator)
            hasproperty(g2, field) || throw(ArgumentError("H0-A G2 endpoint is missing $field"))
        end
        for field in (:selected_flow_link_id, :ports, :accounts, :entries, :closures, :links, :feedback)
            hasproperty(g3, field) || throw(ArgumentError("H0-A G3 endpoint is missing $field"))
        end
        source_bound = all(_n06_h0a_source_complete(x) for x in occ) &&
            _n06_h0a_source_complete(g2) &&
            all(_n06_h0a_source_complete(x) for field in (:ports, :accounts, :entries, :closures, :links, :feedback)
                for x in getproperty(g3, field))
        new(occ, g2, g3, (source_bound=source_bound, schema_only=!source_bound))
    end
end

struct N06H0AUnitEquationV1
    variables::Tuple{Vararg{String}}
    equation::String
    input_units::Tuple{Vararg{UnitSignature}}
    output_units::Tuple{Vararg{UnitSignature}}
    scale::Rational{Int64}
    efficiency::Union{Nothing,Rational{Int64}}
    calibration_provenance::Any
    direction::Symbol
    sign::Int8
    closure_equation::String
    closure_relation::Any
    owner_scope::String
    owner_account_ids::Tuple{Vararg{String}}
    calibration_source::Union{Nothing,N06H0ASourceProvenanceV1}
    closure_source::Union{Nothing,N06H0ASourceProvenanceV1}
    law_source::Union{Nothing,N06H0ASourceProvenanceV1}
    calibration_payload::Any
    closure_payload::Any
    law_payload::Any
    role_coefficients::NamedTuple
    role_directions::NamedTuple
    function N06H0AUnitEquationV1(::Val{:base}, variables, equation, input_units, output_units,
            scale, efficiency, calibration_provenance, direction, sign,
            closure_equation, owner_scope, owner_account_ids)
        vars = Tuple(String(x) for x in variables)
        !isempty(vars) && all(!isempty, vars) || throw(ArgumentError("H0-A variables are required"))
        !isempty(String(equation)) || throw(ArgumentError("H0-A unit equation is required"))
        ins = Tuple(input_units); outs = Tuple(output_units)
        all(x -> x isa UnitSignature, ins) && all(x -> x isa UnitSignature, outs) ||
            throw(ArgumentError("H0-A unit equation units must be UnitSignature"))
        sc = Rational{Int64}(scale); sc != 0 // 1 || throw(ArgumentError("H0-A scale cannot be zero"))
        eff = efficiency === nothing ? nothing : Rational{Int64}(efficiency)
        eff === nothing || (0 // 1 < eff <= 1 // 1) || throw(ArgumentError("H0-A efficiency is invalid"))
        cal = calibration_provenance isa N06H0ASourceProvenanceV1 ? calibration_provenance : String(calibration_provenance)
        !isempty(String(cal)) || throw(ArgumentError("H0-A calibration provenance is required"))
        direction in (:in, :out, :bidirectional) || throw(ArgumentError("H0-A direction is invalid"))
        sign in (-1, 1) || throw(ArgumentError("H0-A sign must be -1 or 1"))
        !isempty(String(closure_equation)) || throw(ArgumentError("H0-A closure equation is required"))
        ids = Tuple(String(x) for x in owner_account_ids)
        !isempty(String(owner_scope)) && !isempty(ids) || throw(ArgumentError("H0-A owner scope is incomplete"))
        new(vars, String(equation), ins, outs, sc, eff, cal, direction, Int8(sign),
            String(closure_equation), nothing, String(owner_scope), ids, nothing, nothing, nothing,
            nothing, nothing, nothing, NamedTuple{(),Tuple{}}(()), NamedTuple{(),Tuple{}}(()))
    end

    function N06H0AUnitEquationV1(::Val{:full}, variables, equation, input_units, output_units,
            scale, efficiency, calibration_provenance, direction, sign, closure_equation,
            closure_relation, owner_scope, owner_account_ids, calibration_source,
            closure_source, law_source, calibration_payload, closure_payload, law_payload,
            role_coefficients, role_directions)
        new(variables, equation, input_units, output_units, scale, efficiency,
            calibration_provenance, direction, sign, closure_equation, closure_relation,
            owner_scope, owner_account_ids, calibration_source, closure_source, law_source,
            calibration_payload, closure_payload, law_payload, role_coefficients,
            role_directions)
    end
end

function N06H0AUnitEquationV1(variables, equation, input_units, output_units,
        scale, efficiency, calibration_provenance, direction, sign, closure_equation,
        owner_scope, owner_account_ids;
        calibration_source=nothing, closure_source=nothing, law_source=nothing,
        calibration_payload=nothing, closure_payload=nothing, law_payload=nothing,
        role_coefficients=NamedTuple{(),Tuple{}}(()), role_directions=NamedTuple{(),Tuple{}}(()),
        closure_relation=nothing)
    base = N06H0AUnitEquationV1(Val(:base), variables, equation, input_units, output_units, scale,
        efficiency, calibration_provenance, direction, sign, closure_equation,
        owner_scope, owner_account_ids)
    all(x -> x === nothing || x isa N06H0ASourceProvenanceV1,
        (calibration_source, closure_source, law_source)) ||
        throw(ArgumentError("H0-A equation provenance must be typed"))
    N06H0AUnitEquationV1(Val(:full), base.variables, base.equation, base.input_units, base.output_units,
        base.scale, base.efficiency, base.calibration_provenance, base.direction, base.sign,
        base.closure_equation, closure_relation, base.owner_scope, base.owner_account_ids,
        calibration_source, closure_source, law_source, calibration_payload,
        closure_payload, law_payload, role_coefficients, role_directions)
end

struct N06H0APresentV1 <: N06H0ADeclarationV1
    binding::N06H0AInputBindingV1
    endpoints::N06H0AEndpointSetV1
    law_id::QualifiedRefV1
    equation::N06H0AUnitEquationV1
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    content_hash::Digest256
end
struct N06H0ATypedAbsentV1 <: N06H0ADeclarationV1
    binding::N06H0AInputBindingV1
    endpoints::Union{Nothing,N06H0AEndpointSetV1}
    reason::String
    gap_code::Symbol
    schema_hash::Digest256
    canonicalization_hash::Digest256
    profile_hash::Digest256
    absence_content_hash::Digest256
end
struct N06H0AResultV1
    status::Symbol
    declaration::Union{Nothing,N06H0APresentV1,N06H0ATypedAbsentV1}
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    compile_calls::Int
    provider_calls::Int
    solver_calls::Int
end

struct N06H0AKnownGapError <: Exception
    code::Symbol
    detail::String
end
struct N06H0AConflictError <: Exception
    code::Symbol
    detail::String
end
struct N06H0AProgramError <: Exception
    code::Symbol
    detail::String
end
Base.showerror(io::IO, e::N06H0AKnownGapError) = print(io, "N06 H0-A known gap [", e.code, "]: ", e.detail)
Base.showerror(io::IO, e::N06H0AConflictError) = print(io, "N06 H0-A contradiction [", e.code, "]: ", e.detail)
Base.showerror(io::IO, e::N06H0AProgramError) = print(io, "N06 H0-A program exception [", e.code, "]: ", e.detail)

_n06_h0a_sign(x) = x < 0 ? Int8(-1) : Int8(1)
_n06_h0a_unit_add(a::UnitSignature, b::UnitSignature) =
    UnitSignature(ntuple(i -> a.exponents[i] + b.exponents[i], 7))
_n06_h0a_unit_same(a::UnitSignature, b::UnitSignature) = a.exponents == b.exponents
function _n06_h0a_source_ref(role, path)
    token = replace(String(path), r"[^A-Za-z0-9]+" => "-")
    QualifiedRefV1("fusionconceptai://GenomeV5/UP2/N06H0A/$(role)/$(token)", "v1")
end
_n06_h0a_provenance(role, payload, path, source_type) =
    N06H0ASourceProvenanceV1(_n06_h0a_source_ref(role, path), canonical_hash(payload), path, source_type)

semantic_view(x::N06H0AInputBindingV1) =
    (candidate_ref=x.candidate_ref, package_hash=x.package_hash,
     e0_schema_hash=x.e0_schema_hash, e0_canonicalization_hash=x.e0_canonicalization_hash,
     e0_profile_hash=x.e0_profile_hash, e0_binding_hash=x.e0_binding_hash,
     e0_bound_input_hash=x.e0_bound_input_hash, g1_ref=x.g1_ref, g2_ref=x.g2_ref,
     g3_ref=x.g3_ref, g1_component_hash=x.g1_component_hash,
     g2_component_hash=x.g2_component_hash, g3_component_hash=x.g3_component_hash,
     version_axes=x.version_axes)
semantic_view(x::N06H0AEndpointSetV1) =
    (g1_occurrences=x.g1_occurrences, g2=x.g2, g3=x.g3, provenance=x.provenance)
semantic_view(x::N06H0AUnitEquationV1) =
    (variables=x.variables, equation=x.equation, input_units=x.input_units,
     output_units=x.output_units, scale=x.scale, efficiency=x.efficiency,
     calibration_provenance=x.calibration_provenance, direction=x.direction,
     sign=x.sign, closure_equation=x.closure_equation, closure_relation=x.closure_relation,
     owner_scope=x.owner_scope,
     owner_account_ids=x.owner_account_ids, calibration_source=x.calibration_source,
     closure_source=x.closure_source, law_source=x.law_source,
     calibration_payload=x.calibration_payload, closure_payload=x.closure_payload,
     law_payload=x.law_payload, role_coefficients=x.role_coefficients,
     role_directions=x.role_directions)
semantic_view(x::N06H0APresentV1) =
    (kind=:present, binding=x.binding, endpoints=x.endpoints, law_id=x.law_id,
     equation=x.equation, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash)
semantic_view(x::N06H0ATypedAbsentV1) =
    (kind=:typed_absent, binding=x.binding, endpoints=x.endpoints, reason=x.reason,
     gap_code=x.gap_code, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash)

function _n06_h0a_present_hash(binding, endpoints, law_id, equation, schema_hash, canonicalization_hash, profile_hash)
    canonical_hash((binding=binding, endpoints=endpoints, law_id=law_id, equation=equation,
        schema_hash=schema_hash, canonicalization_hash=canonicalization_hash, profile_hash=profile_hash))
end
function _n06_h0a_absence_hash(binding, endpoints, reason, gap_code, schema_hash, canonicalization_hash, profile_hash)
    canonical_hash((binding=binding, endpoints=endpoints, reason=reason, gap_code=gap_code,
        schema_hash=schema_hash, canonicalization_hash=canonicalization_hash, profile_hash=profile_hash))
end
function n06_h0a_present(binding::N06H0AInputBindingV1, endpoints::N06H0AEndpointSetV1,
                         law_id::QualifiedRefV1, equation::N06H0AUnitEquationV1)
    law_id.version == "v1" || throw(ArgumentError("H0-A law id must use v1"))
    sh=n06_h0a_schema_hash(); ch=n06_h0a_canonicalization_hash(); ph=n06_h0a_profile_hash()
    N06H0APresentV1(binding, endpoints, law_id, equation, sh, ch, ph,
        _n06_h0a_present_hash(binding, endpoints, law_id, equation, sh, ch, ph))
end

const _N06_H0A_GAP_CODES = (:dimensioned_law_missing, :source_binding_missing,
    :e0_binding_missing, :external_ref_required, :calibration_missing, :program_exception)
function n06_h0a_absent(binding::N06H0AInputBindingV1, endpoints::Union{Nothing,N06H0AEndpointSetV1},
                        reason::AbstractString, gap_code::Symbol=:dimensioned_law_missing)
    isempty(String(reason)) && throw(ArgumentError("H0-A absence reason is required"))
    gap_code in _N06_H0A_GAP_CODES || throw(ArgumentError("H0-A absence gap code is invalid"))
    sh=n06_h0a_schema_hash(); ch=n06_h0a_canonicalization_hash(); ph=n06_h0a_profile_hash(); why=String(reason)
    N06H0ATypedAbsentV1(binding, endpoints, why, gap_code, sh, ch, ph,
        _n06_h0a_absence_hash(binding, endpoints, why, gap_code, sh, ch, ph))
end
function n06_h0a_edit(declaration::N06H0APresentV1, equation::N06H0AUnitEquationV1)
    n06_h0a_present(declaration.binding, declaration.endpoints, declaration.law_id, equation)
end

function _n06_h0a_schema_validation_errors(declaration::N06H0APresentV1)
    errors=String[]
    declaration.schema_hash == n06_h0a_schema_hash() || push!(errors,"schema_hash_mismatch")
    declaration.canonicalization_hash == n06_h0a_canonicalization_hash() || push!(errors,"canonicalization_hash_mismatch")
    declaration.profile_hash == n06_h0a_profile_hash() || push!(errors,"profile_hash_mismatch")
    declaration.content_hash == _n06_h0a_present_hash(declaration.binding,declaration.endpoints,
        declaration.law_id,declaration.equation,declaration.schema_hash,
        declaration.canonicalization_hash,declaration.profile_hash) || push!(errors,"content_hash_mismatch")
    errors
end
function n06_h0a_validate(declaration::N06H0APresentV1)
    errors=_n06_h0a_schema_validation_errors(declaration)
    isempty(errors) || return (status=:fail_closed,errors=Tuple(unique(errors)),gaps=(),authority=:none,compile_calls=0,provider_calls=0,solver_calls=0)
    source = declaration.endpoints.provenance.source_bound && declaration.equation.calibration_source !== nothing &&
        declaration.equation.closure_source !== nothing && declaration.equation.law_source !== nothing
    source ? (status=:declared_consistent,errors=(),gaps=(),authority=:source_backed,compile_calls=0,provider_calls=0,solver_calls=0) :
        (status=:schema_validation_only,errors=(),gaps=("source_provenance_not_bound",),authority=:schema_only,compile_calls=0,provider_calls=0,solver_calls=0)
end
function n06_h0a_validate(declaration::N06H0ATypedAbsentV1)
    expected=_n06_h0a_absence_hash(declaration.binding,declaration.endpoints,declaration.reason,declaration.gap_code,
        declaration.schema_hash,declaration.canonicalization_hash,declaration.profile_hash)
    declaration.absence_content_hash == expected || return (status=:fail_closed,errors=("absence_content_hash_mismatch",),gaps=(),authority=:none,compile_calls=0,provider_calls=0,solver_calls=0)
    declaration.gap_code == :program_exception ?
        (status=:program_exception,errors=(declaration.reason,),gaps=(),authority=:none,compile_calls=0,provider_calls=0,solver_calls=0) :
        (status=:terminal_deferred,errors=(),gaps=(declaration.reason,),authority=:none,compile_calls=0,provider_calls=0,solver_calls=0)
end

function _n06_h0a_binding(package::CandidateStatePackageV5, e0::UP2CandidatePhysicalBindingV1)
    N06H0AInputBindingV1(package.candidate_ref, package.candidate_hash,
        e0.schema_hash,e0.canonicalization_hash,e0.profile_hash,e0.binding_hash,e0.bound_input_hash,
        package.g1.contract_ref,package.g2.contract_ref,package.g3.contract_binding.contract_ref,
        package.g1.candidate_hash,package.g2.candidate_hash,package.g3.candidate_hash,package.version_axes)
end
function _n06_h0a_expected_selectors()
    isdefined(@__MODULE__, :_N06_G1_ROLE_SELECTORS) || throw(N06H0AKnownGapError(:source_binding_missing,"N06 G1 selector registry is not loaded"))
    selectors=getfield(@__MODULE__, :_N06_G1_ROLE_SELECTORS)
    Tuple(selectors[r] for r in (:source,:field,:return,:heat))
end

function _n06_h0a_endpoint_set(package::CandidateStatePackageV5, projection)
    equations=package.g1.payload.equation_plan.equations; selectors=Tuple(projection.g1_occurrence_keys)
    length(selectors)==4 || throw(N06H0AConflictError(:g1_selector_cardinality,"exactly four G1 selectors are required"))
    Set(selectors)==Set(_n06_h0a_expected_selectors()) || throw(N06H0AConflictError(:g1_selector_set_mismatch,"authored four-role G1 selector set is not resolved"))
    occurrences=NamedTuple[]
    for selector in selectors
        matches=Tuple((equation=e,occurrence=o,equation_index=ei,occurrence_index=oi) for (ei,e) in enumerate(equations) for (oi,o) in enumerate(e.occurrences)
            if (ledger_id=o.ledger_id,equation_id=o.equation_id,port_side=o.port_side,port_index=o.port_index)==selector)
        isempty(matches) && throw(N06H0AKnownGapError(:source_binding_missing,"G1 occurrence selector has no source match: $(selector)"))
        length(matches)==1 || throw(N06H0AConflictError(:g1_occurrence_ambiguous,"G1 occurrence selector has multiple source matches: $(selector)"))
        match=only(matches); equation=match.equation; occurrence=match.occurrence
        cms=Tuple((closure=c,closure_index=ci) for (ci,c) in enumerate(package.g1.payload.grammar_profile.closures) if c.closure_id==equation.closure_ref)
        isempty(cms) && throw(N06H0AKnownGapError(:source_binding_missing,"G1 closure source is missing for $(equation.equation_id)"))
        length(cms)==1 || throw(N06H0AConflictError(:g1_closure_ambiguous,"G1 closure source is ambiguous for $(equation.equation_id)"))
        cm=only(cms); closure=cm.closure; eq_path="/g1/payload/equation_plan/equations/$(match.equation_index-1)"; occ_path=eq_path*"/occurrences/$(match.occurrence_index-1)"; cl_path="/g1/payload/grammar_profile/closures/$(cm.closure_index-1)"
        push!(occurrences,(selector=selector,ledger_id=occurrence.ledger_id,equation_id=occurrence.equation_id,closure_id=closure.closure_id,unit=occurrence.unit,effect=occurrence.effect,coefficient=occurrence.coefficient,equation=equation,closure=closure,provenance=_n06_h0a_provenance(:G1,occurrence,occ_path,:G1LedgerOccurrenceV2),equation_provenance=_n06_h0a_provenance(:G1,equation,eq_path,:G1EquationV2),closure_provenance=_n06_h0a_provenance(:G1,closure,cl_path,:G1ClosureRuleV2)))
    end
    regions=Tuple(r for r in package.g2.region_interface.regions if r.region_id==projection.g2_region_id)
    isempty(regions) && throw(N06H0AKnownGapError(:source_binding_missing,"G2 region source is missing")); length(regions)==1 || throw(N06H0AConflictError(:g2_region_ambiguous,"G2 region source is ambiguous")); region=only(regions)
    interfaces=Tuple(i for i in package.g2.region_interface.interfaces if i.left_region_id==region.region_id || i.right_region_id==region.region_id)
    isempty(interfaces) && throw(N06H0AKnownGapError(:source_binding_missing,"G2 interface source is missing")); length(interfaces)==1 || throw(N06H0AConflictError(:g2_interface_ambiguous,"G2 interface source is ambiguous")); interface=only(interfaces)
    side=interface.left_region_id==region.region_id ? :left : :right; ii=findfirst(==(interface),package.g2.region_interface.interfaces); ri=findfirst(==(region),package.g2.region_interface.regions)
    patches=Tuple(p for p in package.g2.plan.exterior.boundary_patches if
        p.region_id==region.region_id && p.face===projection.g2_boundary_face)
    isempty(patches) && throw(N06H0AKnownGapError(:source_binding_missing,"G2 boundary patch source is missing"))
    length(patches)==1 || throw(N06H0AConflictError(:g2_boundary_ambiguous,"G2 boundary patch source is ambiguous"))
    patch=only(patches); pi=findfirst(==(patch),package.g2.plan.exterior.boundary_patches)
    boundary_path="/g2/plan/exterior/boundary_patches/$(pi-1)"
    g2=(region_id=region.region_id,interface_ref=interface.interface_ref,left_region_id=interface.left_region_id,right_region_id=interface.right_region_id,interface_side=side,axis=interface.axis,coordinate=interface.coordinate,normal=interface.normal,continuity=interface.continuity,transfer_kind=interface.transfer_kind,boundary_face=projection.g2_boundary_face,boundary_locator=projection.g2_boundary_locator,region_payload=region,interface_payload=interface,boundary_payload=patch,region_provenance=_n06_h0a_provenance(:G2,region,"/g2/region_interface/regions/$(ri-1)",:G2RegionV5),provenance=_n06_h0a_provenance(:G2,interface,"/g2/region_interface/interfaces/$(ii-1)",:G2InterfaceV5),boundary_provenance=_n06_h0a_provenance(:G2,patch,boundary_path,:G2BoundaryPatchV2))
    network=projection.network; links=package.g3.binding.links; feedback=package.g3.binding.feedback
    ports=Tuple((port_id=x.port_id,kind=x.kind,direction=x.direction,unit=x.unit,account_id=x.account_id,provenance=_n06_h0a_provenance(:G3,x,"/g3/realization/network/resource_ports/$(i-1)",:G3ResourcePortV2)) for (i,x) in enumerate(network.resource_ports))
    accounts=Tuple((account_id=x.account_id,domain=x.domain,unit=x.unit,owner=x.owner,provenance=_n06_h0a_provenance(:G3,x,"/g3/realization/network/accounts/$(i-1)",:G3LedgerAccountV2)) for (i,x) in enumerate(network.accounts))
    entries=Tuple((entry_id=x.entry_id,account_id=x.account_id,port_id=x.port_id,component_id=x.component_id,coefficient=x.coefficient,unit=x.unit,effect=x.effect,provenance=_n06_h0a_provenance(:G3,x,"/g3/realization/network/entries/$(i-1)",:G3LedgerEntryV2)) for (i,x) in enumerate(network.entries))
    closures=Tuple((closure_id=x.closure_id,domain=x.domain,account_ids=x.account_ids,expected_balance=x.expected_balance,provenance=_n06_h0a_provenance(:G3,x,"/g3/realization/network/closures/$(i-1)",:G3LedgerClosureV2)) for (i,x) in enumerate(network.closures))
    link_view=Tuple((link_id=x.link_id,controller_id=x.controller_id,sensor_port_id=x.sensor_port_id,actuator_port_id=x.actuator_port_id,resource_port_id=x.resource_port_id,fault_id=x.fault_id,provenance=_n06_h0a_provenance(:G3,x,"/g3/binding/links/$(i-1)",:G3ControlResourceLinkV2)) for (i,x) in enumerate(links))
    feedback_view=Tuple((feedback_id=x.feedback_id,target_layer=x.target_layer,target_contract_ref=x.target_contract_ref,channel=x.channel,unit=x.unit,kind=x.kind,source_id=x.source_id,provenance=_n06_h0a_provenance(:G3,x,"/g3/binding/feedback/$(i-1)",:G3FeedbackChannelV2)) for (i,x) in enumerate(feedback))
    g3=(selected_flow_link_id=projection.g3_selected_flow_link_id,ports=ports,accounts=accounts,entries=entries,closures=closures,links=link_view,feedback=feedback_view)
    N06H0AEndpointSetV1(Tuple(occurrences),g2,g3)
end

function _n06_h0a_validate_endpoint_semantics(package,endpoints)
    errors=String[]; gaps=String[]
    all(_n06_h0a_source_complete(x)&&_n06_h0a_source_complete(x.equation_provenance)&&_n06_h0a_source_complete(x.closure_provenance) for x in endpoints.g1_occurrences) || push!(gaps,"g1_endpoint_provenance_missing")
    for x in endpoints.g1_occurrences
        if _n06_h0a_source_complete(x)
            expected = canonical_hash((equation_id=x.equation_id, port_side=x.selector.port_side,
                port_index=x.selector.port_index, coefficient=x.coefficient,
                ledger_id=x.ledger_id, unit=x.unit, effect=x.effect))
            x.provenance.source_hash == expected || push!(errors,"g1_occurrence_source_hash_mismatch:$(x.equation_id)")
        end
        if _n06_h0a_source_complete(x.equation_provenance)
            x.equation_provenance.source_hash == canonical_hash(x.equation) || push!(errors,"g1_equation_source_hash_mismatch:$(x.equation_id)")
        end
        if _n06_h0a_source_complete(x.closure_provenance)
            x.closure_provenance.source_hash == canonical_hash(x.closure) || push!(errors,"g1_closure_source_hash_mismatch:$(x.closure_id)")
        end
    end
    for field in (:provenance, :region_provenance, :boundary_provenance)
        hasproperty(endpoints.g2, field) && getproperty(endpoints.g2, field) isa N06H0ASourceProvenanceV1 || push!(gaps,"g2_$(field)_provenance_missing")
    end
    for field in (:region_payload, :interface_payload, :boundary_payload)
        hasproperty(endpoints.g2, field) || push!(gaps,"g2_$(field)_missing")
    end
    if hasproperty(endpoints.g2, :region_payload) && hasproperty(endpoints.g2, :interface_payload) && hasproperty(endpoints.g2, :boundary_payload)
        regions=Tuple(r for r in package.g2.region_interface.regions if r.region_id==endpoints.g2.region_id)
        interfaces=Tuple(i for i in package.g2.region_interface.interfaces if i.interface_ref==endpoints.g2.interface_ref)
        patches=Tuple(p for p in package.g2.plan.exterior.boundary_patches if
            p.region_id==endpoints.g2.region_id && p.face===endpoints.g2.boundary_face)
        length(regions)==1 || push!(errors,"g2_region_source_join_invalid")
        length(interfaces)==1 || push!(errors,"g2_interface_source_join_invalid")
        length(patches)==1 || push!(errors,"g2_boundary_source_join_invalid")
        length(regions)==1 && canonical_hash(endpoints.g2.region_payload)==canonical_hash(only(regions)) || push!(errors,"g2_region_payload_mismatch")
        length(interfaces)==1 && canonical_hash(endpoints.g2.interface_payload)==canonical_hash(only(interfaces)) || push!(errors,"g2_interface_payload_mismatch")
        length(patches)==1 && canonical_hash(endpoints.g2.boundary_payload)==canonical_hash(only(patches)) || push!(errors,"g2_boundary_payload_mismatch")
        endpoints.g2.region_provenance.source_hash==canonical_hash(endpoints.g2.region_payload) || push!(errors,"g2_region_source_hash_mismatch")
        endpoints.g2.provenance.source_hash==canonical_hash(endpoints.g2.interface_payload) || push!(errors,"g2_interface_source_hash_mismatch")
        endpoints.g2.boundary_provenance.source_hash==canonical_hash(endpoints.g2.boundary_payload) || push!(errors,"g2_boundary_source_hash_mismatch")
    end
    g3=endpoints.g3; isempty(g3.ports)&&push!(gaps,"g3_resource_ports_missing"); isempty(g3.accounts)&&push!(gaps,"g3_accounts_missing"); isempty(g3.entries)&&push!(gaps,"g3_entries_missing"); isempty(g3.closures)&&push!(gaps,"g3_closures_missing"); isempty(g3.links)&&push!(gaps,"g3_links_missing")
    for p in g3.ports
        _n06_h0a_source_complete(p) || push!(gaps,"g3_port_provenance_missing:$(p.port_id)")
        _n06_h0a_source_complete(p) && p.provenance.source_hash != canonical_hash((port_id=p.port_id,kind=p.kind,direction=p.direction,unit=p.unit,account_id=p.account_id)) && push!(errors,"g3_port_source_hash_mismatch:$(p.port_id)")
    end
    for a in g3.accounts
        _n06_h0a_source_complete(a) || push!(gaps,"g3_account_provenance_missing:$(a.account_id)")
        _n06_h0a_source_complete(a) && a.provenance.source_hash != canonical_hash((account_id=a.account_id,domain=a.domain,unit=a.unit,owner=a.owner)) && push!(errors,"g3_account_source_hash_mismatch:$(a.account_id)")
    end
    for e in g3.entries
        _n06_h0a_source_complete(e) || push!(gaps,"g3_entry_provenance_missing:$(e.entry_id)")
        _n06_h0a_source_complete(e) && e.provenance.source_hash != canonical_hash((entry_id=e.entry_id,account_id=e.account_id,port_id=e.port_id,component_id=e.component_id,coefficient=e.coefficient,unit=e.unit,effect=e.effect)) && push!(errors,"g3_entry_source_hash_mismatch:$(e.entry_id)")
    end
    for c in g3.closures
        _n06_h0a_source_complete(c) || push!(gaps,"g3_closure_provenance_missing:$(c.closure_id)")
        _n06_h0a_source_complete(c) && c.provenance.source_hash != canonical_hash((closure_id=c.closure_id,domain=c.domain,account_ids=c.account_ids,expected_balance=c.expected_balance)) && push!(errors,"g3_closure_source_hash_mismatch:$(c.closure_id)")
    end
    for l in g3.links
        _n06_h0a_source_complete(l) || push!(gaps,"g3_link_provenance_missing:$(l.link_id)")
        _n06_h0a_source_complete(l) && l.provenance.source_hash != canonical_hash((link_id=l.link_id,controller_id=l.controller_id,sensor_port_id=l.sensor_port_id,actuator_port_id=l.actuator_port_id,resource_port_id=l.resource_port_id,fault_id=l.fault_id)) && push!(errors,"g3_link_source_hash_mismatch:$(l.link_id)")
    end
    for f in g3.feedback
        _n06_h0a_source_complete(f) || push!(gaps,"g3_feedback_provenance_missing:$(f.feedback_id)")
        _n06_h0a_source_complete(f) && f.provenance.source_hash != canonical_hash((feedback_id=f.feedback_id,target_layer=f.target_layer,target_contract_ref=f.target_contract_ref,channel=f.channel,unit=f.unit,kind=f.kind,source_id=f.source_id)) && push!(errors,"g3_feedback_source_hash_mismatch:$(f.feedback_id)")
    end
    pmap=Dict(x.port_id=>x for x in g3.ports); amap=Dict(x.account_id=>x for x in g3.accounts); emap=Dict(x.entry_id=>x for x in g3.entries); cmap=Dict(x.closure_id=>x for x in g3.closures); lmap=Dict(x.link_id=>x for x in g3.links)
    length(pmap)==length(g3.ports)||push!(errors,"g3_port_identity_ambiguous"); length(amap)==length(g3.accounts)||push!(errors,"g3_account_identity_ambiguous"); length(emap)==length(g3.entries)||push!(errors,"g3_entry_identity_ambiguous"); length(cmap)==length(g3.closures)||push!(errors,"g3_closure_identity_ambiguous"); length(lmap)==length(g3.links)||push!(errors,"g3_link_identity_ambiguous")
    for p in g3.ports
        # Effort/flow ports are separately typed factors of a power entry, so
        # their units need not equal the account's power unit.  The account
        # and entry units must agree; the effort×flow algebra is checked below.
        haskey(amap,p.account_id)||push!(errors,"g3_port_account_join_missing:$(p.port_id)")
    end
    for e in g3.entries
        haskey(pmap,e.port_id)||push!(errors,"g3_entry_port_join_missing:$(e.entry_id)"); haskey(amap,e.account_id)||push!(errors,"g3_entry_account_join_missing:$(e.entry_id)"); haskey(amap,e.account_id)&&e.unit==amap[e.account_id].unit||push!(errors,"g3_entry_account_unit_mismatch:$(e.entry_id)")
    end
    for c in g3.closures
        all(haskey(amap,a) for a in c.account_ids)||push!(errors,"g3_closure_account_join_missing:$(c.closure_id)")
        sum((e.coefficient for e in g3.entries if e.account_id in c.account_ids);init=0//1)==c.expected_balance||push!(errors,"g3_closure_expected_balance_mismatch:$(c.closure_id)")
    end
    haskey(lmap,g3.selected_flow_link_id)||push!(errors,"g3_selected_flow_link_missing")
    if haskey(lmap,g3.selected_flow_link_id)
        link=lmap[g3.selected_flow_link_id]; haskey(pmap,link.resource_port_id)||push!(errors,"g3_selected_flow_link_port_missing"); haskey(pmap,link.resource_port_id)&&pmap[link.resource_port_id].kind==:flow||push!(errors,"g3_selected_flow_port_kind_mismatch")
    end
    effort=Tuple(p for p in g3.ports if p.kind==:effort); flow=Tuple(p for p in g3.ports if p.kind==:flow)
    if isempty(effort)||isempty(flow)
        push!(gaps,"power_effort_flow_source_missing")
    else
        flow_entries=Tuple(e for e in g3.entries if e.port_id==first(flow).port_id)
        flow_match,flow_entry=_n06_h0a_exact_match(flow_entries)
        flow_match===:missing && push!(gaps,"power_flow_entry_missing")
        flow_match===:ambiguous && push!(errors,"power_flow_entry_ambiguous")
        if flow_match===:single && !_n06_h0a_unit_same(_n06_h0a_unit_add(first(effort).unit,first(flow).unit),flow_entry.unit)
            push!(errors,"power_effort_flow_unit_algebra_mismatch")
        end
    end
    for f in g3.feedback
        authority=_n06_h0a_feedback_authority(package,f)
        authority===:external_ref_required&&push!(gaps,"external_ref_required:$(f.feedback_id):$(f.target_layer)")
        authority===:foreign&&push!(errors,"g3_feedback_target_authority_mismatch:$(f.feedback_id)")
        (haskey(pmap,f.source_id)||haskey(emap,f.source_id)||any(x->x.link_id==f.source_id,g3.links))||push!(errors,"g3_feedback_source_join_missing:$(f.feedback_id)")
    end
    unique!(errors); unique!(gaps); (errors=Tuple(errors),gaps=Tuple(gaps))
end

function _n06_h0a_feedback_authority(package, feedback)
    expected = feedback.target_layer===:G1 ? package.g1.contract_ref :
        feedback.target_layer===:G2 ? package.g2.contract_ref : nothing
    expected===nothing && return :foreign
    feedback.target_contract_ref==expected || return :foreign
    token="feedback_authority_gap:$(feedback.feedback_id):$(feedback.target_layer)"
    admission=hasproperty(package.g3,:admission) ? package.g3.admission : nothing
    metadata=admission===nothing ? () : hasproperty(admission,:gaps) ? admission.gaps : ()
    token in metadata && return :external_ref_required
    token in (hasproperty(package,:gaps) ? package.gaps : ()) && return :external_ref_required
    :candidate_bound
end

function _n06_h0a_map_value(map::NamedTuple, key::Symbol)
    hasproperty(map,key) ? getproperty(map,key) : nothing
end
function _n06_h0a_exact_match(items)
    length(items)==0 && return (:missing,nothing)
    length(items)==1 && return (:single,only(items))
    (:ambiguous,nothing)
end
const _N06_H0A_SELECTOR_FIELDS = (:ledger_id,:equation_id,:port_side,:port_index)
function _n06_h0a_selector_key(selector)
    selector===nothing && return nothing
    all(hasproperty(selector,field) for field in _N06_H0A_SELECTOR_FIELDS) || return nothing
    NamedTuple{_N06_H0A_SELECTOR_FIELDS}(
        Tuple(getproperty(selector,field) for field in _N06_H0A_SELECTOR_FIELDS))
end
function _n06_h0a_source_selector(registry)
    registry isa AbstractDict || return nothing
    _n06_h0a_selector_key(get(registry,:source,nothing))
end
function _n06_h0a_source_selector()
    registry=isdefined(@__MODULE__, :_N06_G1_ROLE_SELECTORS) ?
        getfield(@__MODULE__, :_N06_G1_ROLE_SELECTORS) : nothing
    _n06_h0a_source_selector(registry)
end
function _n06_h0a_source_role_match(occurrences, registry)
    expected=_n06_h0a_source_selector(registry)
    expected===nothing && return (:registry_missing,nothing)
    matches=Tuple(x for x in occurrences if hasproperty(x,:selector) &&
        _n06_h0a_selector_key(x.selector)==expected)
    _n06_h0a_exact_match(matches)
end
function _n06_h0a_source_role_match(occurrences)
    registry=isdefined(@__MODULE__, :_N06_G1_ROLE_SELECTORS) ?
        getfield(@__MODULE__, :_N06_G1_ROLE_SELECTORS) : nothing
    _n06_h0a_source_role_match(occurrences, registry)
end
function _n06_h0a_payload_value(payload, key::Symbol)
    payload===nothing && return nothing
    payload isa NamedTuple && return hasproperty(payload,key) ? getproperty(payload,key) : nothing
    payload isa AbstractDict && return haskey(payload,key) ? payload[key] : haskey(payload,String(key)) ? payload[String(key)] : nothing
    nothing
end
function _n06_h0a_expected_role_contract(g3)
    effects=NamedTuple{(:source,:load,:return,:heat)}((:source,:load,:return,:heat_rejection))
    result=Dict{Symbol,NamedTuple}()
    for role in (:source,:load,:return,:heat)
        effect=getproperty(effects,role)
        rows=Tuple(x for x in g3.entries if x.effect===effect &&
            !(effect===:source && any(p->p.port_id==x.port_id && p.kind===:effort,g3.ports)))
        if length(rows)==1
            port_match,port=_n06_h0a_exact_match(Tuple(p for p in g3.ports if p.port_id==first(rows).port_id))
            result[role]=(direction=port_match===:single ? port.direction : :unknown,
                sign=role===:source ? Int8(1) : Int8(-1))
        else
            result[role]=(direction=:unknown,sign=Int8(0))
        end
    end
    NamedTuple{(:source,:load,:return,:heat)}((result[:source],result[:load],result[:return],result[:heat]))
end
function _n06_h0a_validate_law(equation::N06H0AUnitEquationV1,endpoints;
                               law_id=nothing, source_registry=:default)
    errors=String[]; gaps=String[]
    equation.calibration_source===nothing&&push!(gaps,"calibration_provenance_missing")
    equation.closure_source===nothing&&push!(gaps,"closure_provenance_missing")
    equation.law_source===nothing&&push!(gaps,"law_source_missing")
    equation.calibration_payload===nothing&&push!(gaps,"calibration_source_payload_missing")
    equation.closure_payload===nothing&&push!(gaps,"closure_source_payload_missing")
    equation.law_payload===nothing&&push!(gaps,"law_source_payload_missing")
    equation.calibration_source!==nothing && equation.calibration_payload!==nothing &&
        equation.calibration_source.source_hash==canonical_hash(equation.calibration_payload) ||
        equation.calibration_source===nothing || equation.calibration_payload===nothing || push!(errors,"calibration_source_hash_mismatch")
    equation.closure_source!==nothing && equation.closure_payload!==nothing &&
        equation.closure_source.source_hash==canonical_hash(equation.closure_payload) ||
        equation.closure_source===nothing || equation.closure_payload===nothing || push!(errors,"closure_source_hash_mismatch")
    equation.law_source!==nothing && equation.law_payload!==nothing &&
        equation.law_source.source_hash==canonical_hash(equation.law_payload) ||
        equation.law_source===nothing || equation.law_payload===nothing || push!(errors,"law_source_hash_mismatch")
    length(unique(equation.variables))==length(equation.variables)||push!(errors,"law_variables_duplicate")
    g3=endpoints.g3; effort=Tuple(p for p in g3.ports if p.kind==:effort); flow=Tuple(p for p in g3.ports if p.kind==:flow)
    if isempty(effort)||isempty(flow)
        push!(gaps,"power_effort_flow_source_missing")
    elseif length(equation.input_units)!=2 || equation.input_units != (first(effort).unit,first(flow).unit)
        push!(errors,"law_input_unit_equation_mismatch")
    elseif isempty(equation.output_units) || equation.output_units[1]!=_n06_h0a_unit_add(first(effort).unit,first(flow).unit)
        push!(errors,"law_power_output_unit_mismatch")
    end
    equation.efficiency===nothing&&push!(gaps,"efficiency_missing")
    equation.efficiency===nothing || equation.scale*equation.efficiency<=0//1 && push!(errors,"law_scale_efficiency_invalid")
    cscale=_n06_h0a_payload_value(equation.calibration_payload,:scale)
    ceff=_n06_h0a_payload_value(equation.calibration_payload,:efficiency)
    cscale===nothing&&equation.calibration_payload!==nothing&&push!(errors,"calibration_scale_missing")
    ceff===nothing&&equation.calibration_payload!==nothing&&push!(errors,"calibration_efficiency_missing")
    if cscale!==nothing
        (cscale isa Integer || cscale isa Rational) || throw(N06H0AProgramError(:calibration_payload_malformed,"scale is not numeric"))
        Rational{Int64}(cscale)==equation.scale || push!(errors,"calibration_scale_mismatch")
    end
    if ceff!==nothing
        (ceff isa Integer || ceff isa Rational) || throw(N06H0AProgramError(:calibration_payload_malformed,"efficiency is not numeric"))
        Rational{Int64}(ceff)==equation.efficiency || push!(errors,"calibration_efficiency_mismatch")
    end
    closure_eq=_n06_h0a_payload_value(equation.closure_payload,:equation)
    closure_eq===nothing&&equation.closure_payload!==nothing&&push!(errors,"closure_equation_payload_missing")
    if closure_eq!==nothing
        closure_eq isa AbstractString || throw(N06H0AProgramError(:closure_payload_malformed,"equation is not text"))
        String(closure_eq)==equation.closure_equation || push!(errors,"closure_equation_mismatch")
    end
    relation=equation.closure_relation
    relation===nothing&&push!(gaps,"closure_relation_missing")
    if relation!==nothing
        relation isa NamedTuple || push!(errors,"closure_relation_malformed")
        if relation isa NamedTuple
            for domain in (:energy,:thermal)
                item=_n06_h0a_payload_value(relation,domain)
                if !(item isa NamedTuple)
                    push!(errors,"closure_relation_$(domain)_malformed")
                    continue
                end
                cid=_n06_h0a_payload_value(item,:closure_id); expected=_n06_h0a_payload_value(item,:expected_balance)
                ids=_n06_h0a_payload_value(item,:account_ids)
                cid===nothing&&push!(errors,"closure_relation_$(domain)_id_missing")
                expected===nothing&&push!(errors,"closure_relation_$(domain)_balance_missing")
                ids===nothing&&push!(errors,"closure_relation_$(domain)_accounts_missing")
                ids===nothing || ids isa Tuple || throw(N06H0AProgramError(:closure_relation_malformed,"account_ids must be a tuple"))
                expected===nothing || expected isa Number || throw(N06H0AProgramError(:closure_relation_malformed,"expected_balance must be numeric"))
                matches=Tuple(c for c in endpoints.g3.closures if c.domain===domain && c.closure_id==cid)
                length(matches)==1 || push!(errors,"closure_relation_$(domain)_source_join_invalid")
                if length(matches)==1
                    c=only(matches)
                    c.expected_balance==expected || push!(errors,"closure_relation_$(domain)_balance_mismatch")
                    Tuple(c.account_ids)==Tuple(ids) || push!(errors,"closure_relation_$(domain)_accounts_mismatch")
                end
            end
        end
    end
    payload_law_id=_n06_h0a_payload_value(equation.law_payload,:law_id)
    law_id===nothing || payload_law_id===nothing || payload_law_id==law_id || push!(errors,"law_source_identity_mismatch")
    registry=source_registry===:default ?
        (isdefined(@__MODULE__, :_N06_G1_ROLE_SELECTORS) ?
            getfield(@__MODULE__, :_N06_G1_ROLE_SELECTORS) : nothing) : source_registry
    source_match,source=_n06_h0a_source_role_match(endpoints.g1_occurrences, registry)
    source_match===:registry_missing && push!(gaps,"source_binding_missing")
    source_match===:missing && push!(gaps,"g1_occurrence_source_missing")
    source_match===:ambiguous && push!(errors,"g1_occurrence_source_ambiguous")
    source_match===:single && equation.sign!=_n06_h0a_sign(source.coefficient)&&push!(errors,"law_sign_source_mismatch")
    equation.direction in (:in,:out,:bidirectional)||push!(errors,"law_direction_invalid")
    source_entries=Tuple(x for x in g3.entries if x.effect===:source &&
        !(any(p->p.port_id==x.port_id && p.kind===:effort,g3.ports)))
    if length(source_entries)==1
        source_port_match,source_port=_n06_h0a_exact_match(Tuple(p for p in g3.ports if p.port_id==first(source_entries).port_id))
        source_port_match===:missing&&push!(gaps,"law_direction_source_port_missing")
        source_port_match===:ambiguous&&push!(errors,"law_direction_source_port_ambiguous")
        if source_port_match===:single && equation.direction!==:bidirectional &&
            equation.direction!=source_port.direction
            push!(errors,"law_direction_source_mismatch")
        end
    end
    owner_ids=Set(x.account_id for x in g3.accounts)
    all(x->x in owner_ids,equation.owner_account_ids)||push!(errors,"law_owner_scope_account_missing")
    expected_scope=join(sort!(collect(Set(equation.owner_account_ids))),"|")
    equation.owner_scope==expected_scope||push!(errors,"law_owner_scope_mismatch")
    role_effects=NamedTuple{(:source,:load,:return,:heat)}((:source,:load,:return,:heat_rejection))
    role_rules=_n06_h0a_expected_role_contract(g3)
    for role in (:source,:load,:return,:heat)
        effect=getproperty(role_effects,role)
        rows=Tuple(x for x in g3.entries if x.effect===effect &&
            !(effect===:source && any(p->p.port_id==x.port_id && p.kind===:effort,g3.ports)))
        isempty(rows)&&push!(gaps,"g3_role_entry_missing:$(role)")
        length(rows)==1||isempty(rows)||push!(errors,"g3_role_entry_ambiguous:$(role)")
        if length(rows)==1
            row=first(rows); coeff=_n06_h0a_map_value(equation.role_coefficients,role); dir=_n06_h0a_map_value(equation.role_directions,role)
            coeff===nothing&&push!(gaps,"role_coefficient_missing:$(role)")
            dir===nothing&&push!(gaps,"role_direction_missing:$(role)")
            expected_rule=getproperty(role_rules,role)
            coeff===nothing || coeff==row.coefficient || push!(errors,"role_coefficient_mismatch:$(role)")
            _n06_h0a_sign(row.coefficient)==expected_rule.sign || push!(errors,"role_sign_mismatch:$(role)")
            port_match,port=_n06_h0a_exact_match(Tuple(p for p in g3.ports if p.port_id==row.port_id))
            port_match===:missing&&push!(gaps,"role_port_missing:$(role)")
            port_match===:ambiguous&&push!(errors,"role_port_ambiguous:$(role)")
            port_match===:single && port.direction!=expected_rule.direction&&push!(errors,"role_contract_direction_mismatch:$(role)")
            port_match===:single && dir!==nothing && dir!=port.direction&&push!(errors,"role_direction_mismatch:$(role)")
            row.coefficient==0//1&&push!(errors,"role_sign_zero:$(role)")
        end
    end
    energy=Tuple(c for c in g3.closures if c.domain===:energy); thermal=Tuple(c for c in g3.closures if c.domain===:thermal)
    isempty(energy)&&push!(gaps,"energy_closure_missing"); isempty(thermal)&&push!(gaps,"thermal_closure_missing")
    any(c->c.closure_id=="energy-balance" && c.expected_balance==0//1,energy)||push!(errors,"energy_closure_balance_mismatch")
    any(c->c.domain===:thermal && c.expected_balance!=0//1,thermal)||push!(errors,"thermal_closure_balance_mismatch")
    unique!(errors); unique!(gaps); (errors=Tuple(errors),gaps=Tuple(gaps))
end
_n06_h0a_classify_error(e::N06H0AKnownGapError)=:terminal_deferred
_n06_h0a_classify_error(e::N06H0AConflictError)=:fail_closed
_n06_h0a_classify_error(e::N06H0AProgramError)=:program_exception
_n06_h0a_classify_error(e)=:program_exception
function _n06_h0a_translate_upstream(e, phase::Symbol)
    (e isa N06H0AKnownGapError || e isa N06H0AConflictError || e isa N06H0AProgramError) && return e
    N06H0AProgramError(:source_projection_exception, "$(phase): " * sprint(showerror,e))
end
function _n06_h0a_source_preflight(package::CandidateStatePackageV5,
                                    e0::UP2CandidatePhysicalBindingV1)
    package.structural_status===:valid || throw(N06H0AConflictError(:source_package_contradiction,"package structural status is not valid"))
    e0_check=up2e0_validate_binding(e0,package)
    e0_check.status===:valid || (e0_check.status===:program_exception ?
        throw(N06H0AProgramError(:e0_validation_exception,join(e0_check.errors,","))) :
        throw(N06H0AConflictError(:e0_binding_invalid,join(e0_check.errors,","))))
    package_check=up2e0_check_package(package)
    package_check.status===:valid || (package_check.status===:program_exception ?
        throw(N06H0AProgramError(:source_package_exception,join(package_check.errors,","))) :
        throw(N06H0AConflictError(:source_package_contradiction,join(package_check.errors,","))))
    equations=package.g1.payload.equation_plan.equations
    isempty(equations)&&throw(N06H0AKnownGapError(:source_binding_missing,"G1 equation source is absent"))
    length(unique(x.equation_id for x in equations))==length(equations) ||
        throw(N06H0AConflictError(:g1_equation_ambiguous,"G1 equation source identity is contradictory"))
    isempty(package.g2.region_interface.regions)&&throw(N06H0AKnownGapError(:source_binding_missing,"G2 region source is absent"))
    isempty(package.g2.plan.exterior.boundary_patches)&&throw(N06H0AKnownGapError(:source_binding_missing,"G2 boundary source is absent"))
    network=package.g3.realization.network
    isempty(network.resource_ports)&&throw(N06H0AKnownGapError(:source_binding_missing,"G3 port source is absent"))
    isempty(network.entries)&&throw(N06H0AKnownGapError(:source_binding_missing,"G3 entry source is absent"))
    isempty(network.closures)&&throw(N06H0AKnownGapError(:source_binding_missing,"G3 closure source is absent"))
    isempty(package.g3.binding.links)&&throw(N06H0AKnownGapError(:source_binding_missing,"G3 link source is absent"))
    nothing
end
function _n06_h0a_project(package::CandidateStatePackageV5,e0::UP2CandidatePhysicalBindingV1)
    try
        _n06_h0a_source_preflight(package,e0)
        n06_projection_from_a(package,e0)
    catch e
        throw(_n06_h0a_translate_upstream(e,:projection))
    end
end
function _n06_h0a_result(status,declaration,errors=(),gaps=())
    N06H0AResultV1(status,declaration,Tuple(String(x) for x in errors),Tuple(String(x) for x in gaps),0,0,0)
end

function n06_h0a_validate(declaration::N06H0APresentV1,package::CandidateStatePackageV5,e0::UP2CandidatePhysicalBindingV1)
    base=n06_h0a_validate(declaration); base.status==:fail_closed&&return _n06_h0a_result(:fail_closed,nothing,base.errors)
    declaration.law_id.version=="v1" || return _n06_h0a_result(:fail_closed,nothing,("law_id_version_mismatch",))
    binding=try _n06_h0a_binding(package,e0) catch e; typed=_n06_h0a_translate_upstream(e,:binding); return _n06_h0a_result(_n06_h0a_classify_error(typed),nothing,(sprint(showerror,typed),)) end
    errors=String[]; gaps=String[]; canonical_hash(declaration.binding)==canonical_hash(binding)||push!(errors,"source_binding_identity_mismatch")
    projection=try _n06_h0a_project(package,e0) catch e; typed=_n06_h0a_translate_upstream(e,:projection); return _n06_h0a_result(_n06_h0a_classify_error(typed),nothing,(sprint(showerror,typed),)) end
    expected=try _n06_h0a_endpoint_set(package,projection) catch e; typed=_n06_h0a_translate_upstream(e,:endpoint); return _n06_h0a_result(_n06_h0a_classify_error(typed),nothing,(sprint(showerror,typed),)) end
    canonical_hash(declaration.endpoints)==canonical_hash(expected)||push!(errors,"source_endpoint_identity_mismatch")
    ec=try
        _n06_h0a_validate_endpoint_semantics(package,expected)
    catch e
        typed=_n06_h0a_translate_upstream(e,:endpoint_semantics)
        status=_n06_h0a_classify_error(typed)
        return _n06_h0a_result(status,status===:terminal_deferred ? declaration : nothing,(sprint(showerror,typed),))
    end
    append!(errors,ec.errors); append!(gaps,ec.gaps)
    lc=try
        _n06_h0a_validate_law(declaration.equation,expected; law_id=declaration.law_id)
    catch e
        typed=_n06_h0a_translate_upstream(e,:law_semantics)
        status=_n06_h0a_classify_error(typed)
        return _n06_h0a_result(status,status===:terminal_deferred ? declaration : nothing,(sprint(showerror,typed),))
    end
    append!(errors,lc.errors); append!(gaps,lc.gaps)
    isempty(errors)||return _n06_h0a_result(:fail_closed,nothing,Tuple(unique(errors)))
    isempty(gaps)||return _n06_h0a_result(:terminal_deferred,declaration,(),Tuple(unique(gaps)))
    _n06_h0a_result(:declared_consistent,declaration)
end

function n06_h0a_admit_present(package::CandidateStatePackageV5,e0::UP2CandidatePhysicalBindingV1,law_id::QualifiedRefV1,equation::N06H0AUnitEquationV1)
    binding=nothing
    try
        binding=_n06_h0a_binding(package,e0)
        check=up2e0_validate_binding(e0,package)
        check.status==:valid || throw(N06H0AConflictError(:e0_binding_invalid,join(check.errors,",")))
        projection=_n06_h0a_project(package,e0); endpoints=_n06_h0a_endpoint_set(package,projection)
        ec=_n06_h0a_validate_endpoint_semantics(package,endpoints)
        isempty(ec.errors)||throw(N06H0AConflictError(:endpoint_semantics_invalid,join(ec.errors,",")))
        isempty(ec.gaps)||throw(N06H0AKnownGapError(:external_ref_required,join(ec.gaps,",")))
        lc=_n06_h0a_validate_law(equation,endpoints; law_id=law_id)
        isempty(lc.errors)||throw(N06H0AConflictError(:law_semantics_invalid,join(lc.errors,",")))
        isempty(lc.gaps)||throw(N06H0AKnownGapError(:dimensioned_law_missing,join(lc.gaps,",")))
        declaration=n06_h0a_present(binding,endpoints,law_id,equation)
        check_result=n06_h0a_validate(declaration,package,e0)
        check_result.status===:declared_consistent || throw(N06H0AConflictError(:source_identity_mismatch,"present law did not reproduce source identity"))
        _n06_h0a_result(:declared_consistent,declaration)
    catch e
        typed=_n06_h0a_translate_upstream(e,:admit)
        status=_n06_h0a_classify_error(typed); reason=sprint(showerror,typed)
        if status===:terminal_deferred && binding!==nothing
            code=typed isa N06H0AKnownGapError ? typed.code : :dimensioned_law_missing
            return _n06_h0a_result(:terminal_deferred,n06_h0a_absent(binding,nothing,reason,code),(),(reason,))
        end
        _n06_h0a_result(status,nothing,(reason,))
    end
end
n06_h0a_admit_present(declaration::N06H0APresentV1,
    package::CandidateStatePackageV5,e0::UP2CandidatePhysicalBindingV1) = begin
    try
        checked=n06_h0a_validate(declaration,package,e0)
        checked.status===:declared_consistent ? checked :
            checked.status===:terminal_deferred ?
                _n06_h0a_result(:terminal_deferred,declaration,checked.errors,checked.gaps) :
                _n06_h0a_result(checked.status,nothing,checked.errors,checked.gaps)
    catch e
        typed=_n06_h0a_translate_upstream(e,:admit_declaration)
        _n06_h0a_result(_n06_h0a_classify_error(typed),nothing,(sprint(showerror,typed),))
    end
end
n06_h0a_present(package::CandidateStatePackageV5,e0::UP2CandidatePhysicalBindingV1,law_id::QualifiedRefV1,equation::N06H0AUnitEquationV1)=n06_h0a_admit_present(package,e0,law_id,equation)

function n06_h0a_bind_actual_a(package::CandidateStatePackageV5,e0::UP2CandidatePhysicalBindingV1)
    binding=try _n06_h0a_binding(package,e0) catch e; return _n06_h0a_result(:program_exception,nothing,("binding_exception:"*sprint(showerror,e),)) end
    e0_check=try up2e0_validate_binding(e0,package) catch e; return _n06_h0a_result(:program_exception,nothing,("e0_exception:"*sprint(showerror,e),)) end
    e0_check.status==:valid||return _n06_h0a_result(e0_check.status,nothing,e0_check.errors)
    isdefined(@__MODULE__,:n06_projection_from_a)||return _n06_h0a_result(:terminal_deferred,n06_h0a_absent(binding,nothing,"N06 source projection is not loaded",:source_binding_missing),(),("N06 source projection is not loaded",))
    try
        projection=_n06_h0a_project(package,e0); endpoints=_n06_h0a_endpoint_set(package,projection); ec=_n06_h0a_validate_endpoint_semantics(package,endpoints)
        isempty(ec.errors)||throw(N06H0AConflictError(:endpoint_semantics_invalid,join(ec.errors,",")))
        if !isempty(ec.gaps)
            code=any(startswith(x,"external_ref_required") for x in ec.gaps) ? :external_ref_required : :source_binding_missing; reason=join(ec.gaps,","); absent=n06_h0a_absent(binding,endpoints,reason,code); return _n06_h0a_result(:terminal_deferred,absent,(),ec.gaps)
        end
        absent=n06_h0a_absent(binding,endpoints,"actual A has no candidate-owned dimensioned G1-to-G3 law, scale, efficiency, calibration, and conservation provenance",:dimensioned_law_missing); _n06_h0a_result(:terminal_deferred,absent,(),(absent.reason,))
    catch e
        typed=_n06_h0a_translate_upstream(e,:bind_actual_a); status=_n06_h0a_classify_error(typed); reason=sprint(showerror,typed)
        status==:terminal_deferred&&return _n06_h0a_result(:terminal_deferred,n06_h0a_absent(binding,nothing,reason,typed isa N06H0AKnownGapError ? typed.code : :source_binding_missing),(),(reason,))
        _n06_h0a_result(status,nothing,(reason,))
    end
end
function n06_h0a_bind_actual_a(package,e0)
    _n06_h0a_result(:program_exception,nothing,("H0-A requires typed CandidateStatePackageV5 and UP2CandidatePhysicalBindingV1",))
end
