# Typed static ideal-MHD jump ledger; finite-offset diagnostics only.
using FusionConceptAI
using SHA
import FusionConceptAI: ClaimCeiling, Digest256, canonical_hash, semantic_view

const _SMJL_REVISION = "runtime-v4-static-mhd-interface-jump-ledger-v1"
const _SMJL_SCHEMA = "fusionconceptai:runtime-v4-static-mhd-interface-jump-ledger"
const _SMJL_TOKEN = Val(:static_mhd_interface_jump_ledger_private)
const _SMJL_STATIC = (:momentum_traction_continuity,
    :normal_magnetic_flux_continuity)
const _SMJL_DYNAMIC = (:mass_flux_continuity,
    :tangential_electric_field_continuity, :total_energy_flux_continuity)
const _SMJL_SOURCE_PATH = abspath(@__FILE__)
_smjl_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))

function _smjl_owner_function(value, name::Symbol)
    owner = parentmodule(typeof(value))
    isdefined(owner, name) ||
        throw(ArgumentError("authoritative $(name) unavailable for upstream type"))
    getfield(owner, name)
end

struct StaticMHDJumpConditionRecordV4
    condition_id::Symbol
    scope::Symbol
    unit::String
    component_labels::Tuple{Vararg{Symbol}}
    proxy_values::Tuple{Vararg{Float64}}
    required_for_static_contract::Bool
    input_available::Bool
    proxy_evaluated::Bool
    boundary_limit_required::Bool
    boundary_limit_validated::Bool
    condition_validated::Bool
    reason::Symbol
    record_hash::Digest256
    function StaticMHDJumpConditionRecordV4(
            token::Val{:static_mhd_interface_jump_ledger_private}, fields...)
        token === _SMJL_TOKEN || throw(ArgumentError("private condition constructor"))
        new(fields...)
    end
end

semantic_view(x::StaticMHDJumpConditionRecordV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::StaticMHDJumpConditionRecordV4)
    if x.required_for_static_contract
        x.condition_id in _SMJL_STATIC &&
            x.scope === :declared_static_ideal_mhd && x.input_available &&
            x.proxy_evaluated && x.boundary_limit_required &&
            !x.boundary_limit_validated && !x.condition_validated &&
            !isempty(x.component_labels) &&
            length(x.component_labels) == length(x.proxy_values) &&
            all(isfinite, x.proxy_values) &&
            x.reason === :finite_offset_proxy_not_boundary_limit ||
            throw(ArgumentError("invalid required static condition"))
    else
        x.condition_id in _SMJL_DYNAMIC &&
            x.scope === :dynamic_rankine_hugoniot_out_of_scope &&
            !x.input_available && !x.proxy_evaluated &&
            !x.boundary_limit_required && !x.boundary_limit_validated &&
            !x.condition_validated && isempty(x.component_labels) &&
            isempty(x.proxy_values) &&
            x.reason === :velocity_density_energy_state_not_in_static_contract ||
            throw(ArgumentError("invalid out-of-scope dynamic condition"))
    end
    expected = canonical_hash(semantic_view(x))
    expected == x.record_hash || throw(ArgumentError("condition hash mismatch"))
    expected
end

function _smjl_static(id, unit, labels, values_)
    body = (condition_id=id, scope=:declared_static_ideal_mhd,
        unit=String(unit), component_labels=Tuple(labels),
        proxy_values=Tuple(Float64.(values_)),
        required_for_static_contract=true, input_available=true,
        proxy_evaluated=true, boundary_limit_required=true,
        boundary_limit_validated=false, condition_validated=false,
        reason=:finite_offset_proxy_not_boundary_limit)
    StaticMHDJumpConditionRecordV4(_SMJL_TOKEN, values(body)...,
        canonical_hash(body))
end

function _smjl_dynamic(id, unit)
    body = (condition_id=id,
        scope=:dynamic_rankine_hugoniot_out_of_scope, unit=String(unit),
        component_labels=(), proxy_values=(),
        required_for_static_contract=false, input_available=false,
        proxy_evaluated=false, boundary_limit_required=false,
        boundary_limit_validated=false, condition_validated=false,
        reason=:velocity_density_energy_state_not_in_static_contract)
    StaticMHDJumpConditionRecordV4(_SMJL_TOKEN, values(body)...,
        canonical_hash(body))
end

struct StaticMHDInterfaceJumpLedgerEntryV4
    interface_id::String
    interface_hash::Digest256
    minus_region_id::String
    plus_region_id::String
    minus_region_support_hash::Digest256
    plus_region_support_hash::Digest256
    traction_spec_hash::Digest256
    traction_sample_hash::Digest256
    residual_hash::Digest256
    epsilon_rho::Float64
    static_conditions::Tuple{Vararg{StaticMHDJumpConditionRecordV4}}
    dynamic_conditions::Tuple{Vararg{StaticMHDJumpConditionRecordV4}}
    finite_offset_proxy::Bool
    entry_hash::Digest256
    function StaticMHDInterfaceJumpLedgerEntryV4(
            token::Val{:static_mhd_interface_jump_ledger_private}, fields...)
        token === _SMJL_TOKEN || throw(ArgumentError("private entry constructor"))
        new(fields...)
    end
end

semantic_view(x::StaticMHDInterfaceJumpLedgerEntryV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::StaticMHDInterfaceJumpLedgerEntryV4)
    !isempty(x.interface_id) && x.minus_region_id != x.plus_region_id &&
        isfinite(x.epsilon_rho) && x.epsilon_rho > 0.0 &&
        x.finite_offset_proxy &&
        Tuple(c.condition_id for c in x.static_conditions) == _SMJL_STATIC &&
        Tuple(c.condition_id for c in x.dynamic_conditions) == _SMJL_DYNAMIC ||
        throw(ArgumentError("invalid jump-ledger entry"))
    foreach(canonical_hash, x.static_conditions)
    foreach(canonical_hash, x.dynamic_conditions)
    expected = canonical_hash(semantic_view(x))
    expected == x.entry_hash || throw(ArgumentError("entry hash mismatch"))
    expected
end

struct StaticMHDInterfaceJumpLedgerRequestV4
    revision::String
    schema::String
    context_hash::Digest256
    candidate_hash::Digest256
    surface_result_hash::Digest256
    traction_request_hash::Digest256
    traction_result_hash::Digest256
    residual_request_hash::Digest256
    residual_result_hash::Digest256
    interface_ids::Tuple{Vararg{String}}
    traction_spec_hashes::Tuple{Vararg{Digest256}}
    traction_sample_hashes::Tuple{Vararg{Digest256}}
    residual_hashes::Tuple{Vararg{Digest256}}
    static_required_conditions::Tuple{Vararg{Symbol}}
    dynamic_out_of_scope_conditions::Tuple{Vararg{Symbol}}
    finite_offset_proxy::Bool
    source_path::String
    source_sha256::Digest256
    claim_ceiling::ClaimCeiling
    jump_conditions_validated::Bool
    regional_residual_assembled::Bool
    global_residual_assembled::Bool
    multiregion_closure::Bool
    emits_evidence::Bool
    promotion_authority::Bool
    request_hash::Digest256
end

semantic_view(x::StaticMHDInterfaceJumpLedgerRequestV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::StaticMHDInterfaceJumpLedgerRequestV4)
    n = length(x.interface_ids)
    x.revision == _SMJL_REVISION && x.schema == _SMJL_SCHEMA && n > 0 &&
        n == length(x.traction_spec_hashes) == length(x.traction_sample_hashes) ==
            length(x.residual_hashes) && length(unique(x.interface_ids)) == n &&
        x.static_required_conditions == _SMJL_STATIC &&
        x.dynamic_out_of_scope_conditions == _SMJL_DYNAMIC &&
        x.finite_offset_proxy && isfile(x.source_path) &&
        _smjl_sha(x.source_path) == x.source_sha256 &&
        x.claim_ceiling == screen_only && !x.jump_conditions_validated &&
        !x.regional_residual_assembled && !x.global_residual_assembled &&
        !x.multiregion_closure && !x.emits_evidence && !x.promotion_authority ||
        throw(ArgumentError("invalid jump-ledger request"))
    expected = canonical_hash(semantic_view(x))
    expected == x.request_hash || throw(ArgumentError("request hash mismatch"))
    expected
end

function _smjl_validate_chain(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        pressure_request, pressure_result, traction_request, traction_result,
        residual_request, residual_result)
    _smjl_owner_function(traction_request,
        :validate_ideal_mhd_interface_traction_result)(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        traction_request, traction_result)
    validate_ideal_mhd_interface_residual_jacobian_result(residual_request,
        traction_request, traction_result, residual_result)
    residual_request.interface_subset ==
        Tuple(spec.spec_hash for spec in traction_request.specs) &&
        length(surface_result.samples) == length(traction_result.samples) ==
            length(residual_result.residuals) ||
        throw(ArgumentError("jump-ledger upstream coverage mismatch"))
    true
end

function make_static_mhd_interface_jump_ledger_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, residual_request,
        residual_result)
    _smjl_validate_chain(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        pressure_request, pressure_result, traction_request, traction_result,
        residual_request, residual_result)
    body = (revision=_SMJL_REVISION, schema=_SMJL_SCHEMA,
        context_hash=context.context_hash, candidate_hash=context.candidate_hash,
        surface_result_hash=canonical_hash(surface_result),
        traction_request_hash=canonical_hash(traction_request),
        traction_result_hash=canonical_hash(traction_result),
        residual_request_hash=canonical_hash(residual_request),
        residual_result_hash=canonical_hash(residual_result),
        interface_ids=Tuple(spec.interface_id for spec in traction_request.specs),
        traction_spec_hashes=Tuple(spec.spec_hash for spec in traction_request.specs),
        traction_sample_hashes=Tuple(canonical_hash(s) for s in traction_result.samples),
        residual_hashes=Tuple(canonical_hash(r) for r in residual_result.residuals),
        static_required_conditions=_SMJL_STATIC,
        dynamic_out_of_scope_conditions=_SMJL_DYNAMIC,
        finite_offset_proxy=true, source_path=_SMJL_SOURCE_PATH,
        source_sha256=_smjl_sha(_SMJL_SOURCE_PATH), claim_ceiling=screen_only,
        jump_conditions_validated=false, regional_residual_assembled=false,
        global_residual_assembled=false, multiregion_closure=false,
        emits_evidence=false, promotion_authority=false)
    request = StaticMHDInterfaceJumpLedgerRequestV4(values(body)...,
        canonical_hash(body))
    canonical_hash(request)
    request
end

struct StaticMHDInterfaceJumpLedgerResultV4
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    request_hash::Digest256
    entries::Tuple{Vararg{StaticMHDInterfaceJumpLedgerEntryV4}}
    static_required_proxies_evaluated::Bool
    dynamic_conditions_out_of_scope::Bool
    boundary_limits_validated::Bool
    jump_conditions_validated::Bool
    regional_residual_assembled::Bool
    global_residual_assembled::Bool
    solver_convergence_validated::Bool
    multiregion_closure::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    claim_ceiling::ClaimCeiling
    result_hash::Digest256
end

semantic_view(x::StaticMHDInterfaceJumpLedgerResultV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::StaticMHDInterfaceJumpLedgerResultV4)
    foreach(canonical_hash, x.entries)
    x.status === :finite_offset_static_jump_proxies_recorded &&
        !isempty(x.entries) && x.static_required_proxies_evaluated &&
        x.dynamic_conditions_out_of_scope && !x.boundary_limits_validated &&
        !x.jump_conditions_validated && !x.regional_residual_assembled &&
        !x.global_residual_assembled && !x.solver_convergence_validated &&
        !x.multiregion_closure && !x.physical_validation &&
        !x.engineering_validation && !x.emits_evidence && !x.grants_pass &&
        !x.promotion_authority && !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 && x.claim_ceiling == screen_only ||
        throw(ArgumentError("jump-ledger result exceeds diagnostic authority"))
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash || throw(ArgumentError("result hash mismatch"))
    expected
end

function _smjl_compute(request, surface_result, traction_request,
        traction_result, residual_result)
    entries = StaticMHDInterfaceJumpLedgerEntryV4[]
    for index in eachindex(traction_request.specs)
        spec = traction_request.specs[index]
        traction = traction_result.samples[index]
        surface = surface_result.samples[index]
        residual = residual_result.residuals[index]
        spec.spec_hash == traction.spec_hash &&
            spec.surface_sample_hash == canonical_hash(surface) &&
            Tuple(residual[1:3]) == traction.traction_jump_residual_xyz_Pa ||
            throw(ArgumentError("jump-ledger sample identity/value mismatch"))
        static_conditions = (
            _smjl_static(:momentum_traction_continuity, "Pa", (:x, :y, :z),
                residual[1:3]),
            _smjl_static(:normal_magnetic_flux_continuity, "T", (:normal,),
                (residual[4],)))
        dynamic_conditions = (
            _smjl_dynamic(:mass_flux_continuity, "kg m^-2 s^-1"),
            _smjl_dynamic(:tangential_electric_field_continuity, "V m^-1"),
            _smjl_dynamic(:total_energy_flux_continuity, "W m^-2"))
        body = (interface_id=spec.interface_id,
            interface_hash=spec.interface_hash,
            minus_region_id=spec.minus_region_id,
            plus_region_id=spec.plus_region_id,
            minus_region_support_hash=spec.minus_region_support_hash,
            plus_region_support_hash=spec.plus_region_support_hash,
            traction_spec_hash=spec.spec_hash,
            traction_sample_hash=canonical_hash(traction),
            residual_hash=canonical_hash(residual),
            epsilon_rho=surface.epsilon_rho,
            static_conditions=static_conditions,
            dynamic_conditions=dynamic_conditions, finite_offset_proxy=true)
        push!(entries, StaticMHDInterfaceJumpLedgerEntryV4(_SMJL_TOKEN,
            values(body)..., canonical_hash(body)))
    end
    body = (status=:finite_offset_static_jump_proxies_recorded,
        context_hash=request.context_hash, candidate_hash=request.candidate_hash,
        request_hash=request.request_hash, entries=Tuple(entries),
        static_required_proxies_evaluated=true,
        dynamic_conditions_out_of_scope=true,
        boundary_limits_validated=false, jump_conditions_validated=false,
        regional_residual_assembled=false, global_residual_assembled=false,
        solver_convergence_validated=false, multiregion_closure=false,
        physical_validation=false, engineering_validation=false,
        emits_evidence=false, grants_pass=false, promotion_authority=false,
        p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0, claim_ceiling=screen_only)
    StaticMHDInterfaceJumpLedgerResultV4(values(body)..., canonical_hash(body))
end

function execute_static_mhd_interface_jump_ledger(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, residual_request,
        residual_result)
    request = make_static_mhd_interface_jump_ledger_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, residual_request,
        residual_result)
    result = _smjl_compute(request, surface_result, traction_request,
        traction_result, residual_result)
    validate_static_mhd_interface_jump_ledger(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        traction_request, traction_result, residual_request, residual_result,
        request, result)
    (request=request, result=result)
end

function validate_static_mhd_interface_jump_ledger(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, residual_request,
        residual_result, request::StaticMHDInterfaceJumpLedgerRequestV4,
        result::StaticMHDInterfaceJumpLedgerResultV4)
    rebuilt_request = make_static_mhd_interface_jump_ledger_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, residual_request,
        residual_result)
    semantic_view(rebuilt_request) == semantic_view(request) ||
        throw(ArgumentError("jump-ledger request differs from full-chain reconstruction"))
    canonical_hash(result)
    rebuilt_result = _smjl_compute(request, surface_result, traction_request,
        traction_result, residual_result)
    semantic_view(rebuilt_result) == semantic_view(result) ||
        throw(ArgumentError("jump-ledger result differs from independent recomputation"))
    result.result_hash
end

static_mhd_interface_jump_ledger_manifest() = (
    schema=_SMJL_SCHEMA, revision=_SMJL_REVISION,
    static_required_conditions=_SMJL_STATIC,
    dynamic_out_of_scope_conditions=_SMJL_DYNAMIC,
    finite_offset_proxy=true, static_required_proxies_evaluated=true,
    boundary_limits_validated=false, jump_conditions_validated=false,
    regional_residual_assembled=false, global_residual_assembled=false,
    solver_convergence_validated=false, multiregion_closure=false,
    physical_validation=false, engineering_validation=false,
    emits_evidence=false, grants_pass=false, promotion_authority=false,
    p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0, claim_ceiling=screen_only)
