"""Contract-only source/hardware inverse-realization request.

This slice is deliberately an admission contract.  It does not resolve a
provider, construct a hardware object, call a derivative, run an inverse
solver, or emit a source/return implementation.  A complete declaration can
only reach `:prepared` with `claim_ceiling == :contract_only` and
`provider_calls == 0`.
"""

import FusionConceptAI: Digest256, digest256_text, canonical_hash, semantic_view

const _IRV1_REVISION = "inverse-realization-request-contract-v1"
const _IRV1_CLAIM_CEILING = :contract_only
const _IRV1_PORT_QUANTITIES = (:power, :current, :voltage, :material, :geometry)
const _IRV1_PORT_ROLES = (:source, :target, :return)
const _IRV1_FUNCTION_SPACES = (:scalar, :field, :geometry_map)
const _IRV1_EMF_POLICIES = (:required, :optional, :forbidden)
const _IRV1_BOUND_KINDS = (:power, :current, :voltage, :density, :conductivity, :extent)

"""Sealed error channel for malformed data at the external request boundary.

Only this exact exception type is normalized by the admission seam.  Ordinary
`ArgumentError`, `MethodError`, and `ErrorException` values remain ordinary
program errors and are rethrown.
"""
struct InverseExternalInputError <: Exception
    code::Symbol
    detail::String
end

Base.showerror(io::IO, error::InverseExternalInputError) =
    print(io, "inverse external input [", error.code, "]: ", error.detail)

_irv1_input_error(message) = InverseExternalInputError(:malformed_input, String(message))

function _irv1_checked_conversion(converter, value, label)
    try
        converter(value)
    catch error
        (error isa MethodError || error isa InexactError ||
            error isa OverflowError || error isa TypeError) || rethrow()
        throw(InverseExternalInputError(:conversion, "$label conversion failed"))
    end
end

_irv1_checked_float(x, label) = _irv1_checked_conversion(Float64, x, label)
_irv1_checked_int(x, label) = _irv1_checked_conversion(Int, x, label)
_irv1_checked_symbol(x, label) = _irv1_checked_conversion(Symbol, x, label)
_irv1_checked_tuple(x, label) = _irv1_checked_conversion(Tuple, x, label)

_irv1_text(x, label) = begin
    x isa AbstractString || throw(_irv1_input_error("$label must be a string"))
    value = _irv1_checked_conversion(String, x, label)
    isempty(strip(value)) && throw(_irv1_input_error("$label must be non-empty"))
    isvalid(value) || throw(_irv1_input_error("$label must be valid UTF-8"))
    value
end

_irv1_symbol(x, allowed, label) = begin
    x isa Symbol && x in allowed || throw(_irv1_input_error("invalid $label"))
    x
end

function _irv1_float(x, label)
    value = _irv1_checked_float(x, label)
    isfinite(value) || throw(_irv1_input_error("$label must be finite"))
    value
end

function _irv1_sorted_symbols(values, allowed, label)
    xs = _irv1_checked_tuple(values, label)
    all(x -> x isa Symbol && x in allowed, xs) || throw(_irv1_input_error("invalid $label"))
    length(unique(xs)) == length(xs) || throw(_irv1_input_error("duplicate $label"))
    Tuple(sort!(collect(xs), by=String))
end

function _irv1_sorted_strings(values, label)
    raw = _irv1_checked_tuple(values, label)
    xs = Tuple(_irv1_text(x, label) for x in raw)
    length(unique(xs)) == length(xs) || throw(_irv1_input_error("duplicate $label"))
    Tuple(sort!(collect(xs)))
end

struct InverseRealizationBoundV1
    kind::Symbol
    unit::Symbol
    lower::Float64
    upper::Float64
    function InverseRealizationBoundV1(kind, unit, lower, upper)
        k = _irv1_symbol(kind, _IRV1_BOUND_KINDS, "bound kind")
        u = unit isa Symbol ? unit : _irv1_checked_symbol(unit, "bound unit")
        expected = k === :power ? :W : k === :current ? :A :
            k === :voltage ? :V : k === :density ? :kg_m3 :
            k === :conductivity ? :S_m : :m
        u === expected || throw(_irv1_input_error("unit does not match bound kind"))
        lo, hi = _irv1_float(lower, "bound lower"), _irv1_float(upper, "bound upper")
        lo <= hi || throw(_irv1_input_error("bound lower exceeds upper"))
        new(k, u, lo, hi)
    end
end

Base.:(==)(a::InverseRealizationBoundV1, b::InverseRealizationBoundV1) =
    a.kind === b.kind && a.unit === b.unit && a.lower == b.lower && a.upper == b.upper
Base.isequal(a::InverseRealizationBoundV1, b::InverseRealizationBoundV1) =
    a.kind === b.kind && a.unit === b.unit && isequal(a.lower, b.lower) && isequal(a.upper, b.upper)

semantic_view(x::InverseRealizationBoundV1) =
    (revision=_IRV1_REVISION, kind=x.kind, unit=x.unit, lower=x.lower, upper=x.upper)

struct InverseRealizationPortV1
    ref::String
    role::Symbol
    quantity::Symbol
    unit::Symbol
    function_space::Symbol
    domain::String
    bound::InverseRealizationBoundV1
    function InverseRealizationPortV1(ref, role, quantity, unit, function_space,
            domain, bound::InverseRealizationBoundV1)
        r = _irv1_text(ref, "port ref")
        ro = _irv1_symbol(role, _IRV1_PORT_ROLES, "port role")
        q = _irv1_symbol(quantity, _IRV1_PORT_QUANTITIES, "port quantity")
        u = unit isa Symbol ? unit : _irv1_checked_symbol(unit, "port unit")
        expected_unit = q === :power ? :W : q === :current ? :A :
            q === :voltage ? :V : q === :material ? :material : :geometry
        u === expected_unit || throw(_irv1_input_error("unit does not match port quantity"))
        fs = _irv1_symbol(function_space, _IRV1_FUNCTION_SPACES, "function space")
        expected_fs = q in (:power, :current, :voltage) ? :scalar :
            q === :material ? :field : :geometry_map
        fs === expected_fs || throw(_irv1_input_error("function space does not match port quantity"))
        d = _irv1_text(domain, "port domain")
        expected_kind = q === :power ? :power : q === :current ? :current :
            q === :voltage ? :voltage : q === :material ? :density : :extent
        bound.kind === expected_kind || throw(_irv1_input_error("port bound kind mismatch"))
        new(r, ro, q, u, fs, d, bound)
    end
end

semantic_view(x::InverseRealizationPortV1) =
    (revision=_IRV1_REVISION, ref=x.ref, role=x.role, quantity=x.quantity,
        unit=x.unit, function_space=x.function_space, domain=x.domain, bound=x.bound)

struct InverseRealizationElectricalV1
    power::Union{Nothing,InverseRealizationBoundV1}
    current::Union{Nothing,InverseRealizationBoundV1}
    voltage::Union{Nothing,InverseRealizationBoundV1}
    emf_policy::Symbol
    function InverseRealizationElectricalV1(; power=nothing, current=nothing,
            voltage=nothing, emf_policy=:optional)
        for (value, kind) in ((power, :power), (current, :current), (voltage, :voltage))
            value === nothing || (value isa InverseRealizationBoundV1 && value.kind === kind) ||
                throw(_irv1_input_error("electrical bound kind mismatch"))
        end
        policy = _irv1_symbol(emf_policy, _IRV1_EMF_POLICIES, "EMF policy")
        new(power, current, voltage, policy)
    end
end

semantic_view(x::InverseRealizationElectricalV1) =
    (revision=_IRV1_REVISION, power=x.power, current=x.current, voltage=x.voltage,
        emf_policy=x.emf_policy)

struct InverseRealizationMaterialV1
    material_ref::String
    model_ref::String
    density::InverseRealizationBoundV1
    conductivity::InverseRealizationBoundV1
    function InverseRealizationMaterialV1(material_ref, model_ref, density::InverseRealizationBoundV1,
            conductivity::InverseRealizationBoundV1)
        density.kind === :density || throw(_irv1_input_error("material density bound required"))
        conductivity.kind === :conductivity || throw(_irv1_input_error("material conductivity bound required"))
        new(_irv1_text(material_ref, "material ref"), _irv1_text(model_ref, "material model"),
            density, conductivity)
    end
end

semantic_view(x::InverseRealizationMaterialV1) =
    (revision=_IRV1_REVISION, material_ref=x.material_ref, model_ref=x.model_ref,
        density=x.density, conductivity=x.conductivity)

struct InverseRealizationGeometryV1
    geometry_ref::String
    model_ref::String
    function_space::Symbol
    domain::String
    dimension::Int
    extent::InverseRealizationBoundV1
    function InverseRealizationGeometryV1(geometry_ref, model_ref, function_space,
            domain, dimension, extent::InverseRealizationBoundV1)
        fs = _irv1_symbol(function_space, _IRV1_FUNCTION_SPACES, "geometry function space")
        fs === :geometry_map || throw(_irv1_input_error("geometry must use geometry_map function space"))
        d = _irv1_checked_int(dimension, "geometry dimension")
        1 <= d <= 3 || throw(_irv1_input_error("geometry dimension must be 1..3"))
        extent.kind === :extent || throw(_irv1_input_error("geometry extent bound required"))
        new(_irv1_text(geometry_ref, "geometry ref"), _irv1_text(model_ref, "geometry model"),
            fs, _irv1_text(domain, "geometry domain"), d, extent)
    end
end

semantic_view(x::InverseRealizationGeometryV1) =
    (revision=_IRV1_REVISION, geometry_ref=x.geometry_ref, model_ref=x.model_ref,
        function_space=x.function_space, domain=x.domain, dimension=x.dimension, extent=x.extent)

struct InverseRealizationProviderCapabilityV1
    provider_ref::String
    quantities::Tuple
    units::Tuple
    function_spaces::Tuple
    domains::Tuple
    derivative_orders::Tuple
    emf_policies::Tuple
    material_models::Tuple
    geometry_models::Tuple
    function InverseRealizationProviderCapabilityV1(provider_ref; quantities=(), units=(),
            function_spaces=(), domains=(), derivative_orders=(), emf_policies=(),
            material_models=(), geometry_models=())
        qs = _irv1_sorted_symbols(quantities, _IRV1_PORT_QUANTITIES, "provider quantities")
        us = _irv1_sorted_symbols(units, (:W, :A, :V, :material, :geometry), "provider units")
        fs = _irv1_sorted_symbols(function_spaces, _IRV1_FUNCTION_SPACES, "provider function spaces")
        ds = _irv1_sorted_strings(domains, "provider domains")
        raw_derivative_orders = _irv1_checked_tuple(derivative_orders, "provider derivative orders")
        deriv = Tuple(_irv1_checked_int(x, "provider derivative order") for x in raw_derivative_orders)
        all(x -> x >= 0 && x <= 8, deriv) && length(unique(deriv)) == length(deriv) ||
            throw(_irv1_input_error("provider derivative orders must be finite integer levels 0..8"))
        policies = _irv1_sorted_symbols(emf_policies, _IRV1_EMF_POLICIES, "provider EMF policies")
        mm = _irv1_sorted_strings(material_models, "provider material models")
        gm = _irv1_sorted_strings(geometry_models, "provider geometry models")
        new(_irv1_text(provider_ref, "provider ref"), qs, us, fs, ds,
            Tuple(sort!(collect(deriv))), policies, mm, gm)
    end
end

semantic_view(x::InverseRealizationProviderCapabilityV1) =
    (revision=_IRV1_REVISION, provider_ref=x.provider_ref, quantities=x.quantities,
        units=x.units, function_spaces=x.function_spaces, domains=x.domains,
        derivative_orders=x.derivative_orders, emf_policies=x.emf_policies,
        material_models=x.material_models, geometry_models=x.geometry_models)

struct InverseRealizationRequestV1
    request_ref::String
    candidate_ref::String
    target::InverseRealizationPortV1
    source::InverseRealizationPortV1
    return_port::Union{Nothing,InverseRealizationPortV1}
    electrical::InverseRealizationElectricalV1
    material::InverseRealizationMaterialV1
    geometry::InverseRealizationGeometryV1
    provider::Union{Nothing,InverseRealizationProviderCapabilityV1}
    request_hash::Digest256
    function InverseRealizationRequestV1(request_ref, candidate_ref,
            target::InverseRealizationPortV1, source::InverseRealizationPortV1,
            return_port::Union{Nothing,InverseRealizationPortV1},
            electrical::InverseRealizationElectricalV1,
            material::InverseRealizationMaterialV1,
            geometry::InverseRealizationGeometryV1,
            provider::Union{Nothing,InverseRealizationProviderCapabilityV1})
        target.role === :target || throw(_irv1_input_error("target port must have target role"))
        source.role === :source || throw(_irv1_input_error("source port must have source role"))
        return_port === nothing || return_port.role === :return ||
            throw(_irv1_input_error("return port must have return role"))
        body = (revision=_IRV1_REVISION, request_ref=_irv1_text(request_ref, "request ref"),
            candidate_ref=_irv1_text(candidate_ref, "candidate ref"), target=target,
            source=source, return_port=return_port, electrical=electrical,
            material=material, geometry=geometry, provider=provider)
        new(body.request_ref, body.candidate_ref, target, source, return_port,
            electrical, material, geometry, provider, canonical_hash(body))
    end
end

function _irv1_request_body(x::InverseRealizationRequestV1)
    (revision=_IRV1_REVISION, request_ref=x.request_ref, candidate_ref=x.candidate_ref,
        target=x.target, source=x.source, return_port=x.return_port,
        electrical=x.electrical, material=x.material, geometry=x.geometry,
        provider=x.provider)
end

semantic_view(x::InverseRealizationRequestV1) = _irv1_request_body(x)
canonical_hash(x::InverseRealizationRequestV1) = begin
    expected = canonical_hash(_irv1_request_body(x))
    expected == x.request_hash || throw(ArgumentError("inverse request identity mismatch"))
    expected
end

struct InverseRealizationContractResultV1
    status::Symbol
    valid::Bool
    claim_ceiling::Symbol
    request_hash::Digest256
    reasons::Tuple
    provider_calls::Int
    result_hash::Digest256
    function InverseRealizationContractResultV1(token::Val{:inverse_realization_contract},
            status, valid, claim_ceiling, request_hash::Digest256, reasons, provider_calls,
            result_hash::Digest256)
        token === Val(:inverse_realization_contract) || throw(ArgumentError("private result constructor"))
        status in (:contract_only, :prepared, :fail_closed, :terminal_deferred) ||
            throw(ArgumentError("invalid inverse contract status"))
        valid === (status in (:contract_only, :prepared)) || throw(ArgumentError("status/valid mismatch"))
        claim_ceiling === _IRV1_CLAIM_CEILING || throw(ArgumentError("invalid claim ceiling"))
        provider_calls === 0 || throw(ArgumentError("provider invocation is forbidden in contract slice"))
        new(status, Bool(valid), claim_ceiling, request_hash, Tuple(String.(reasons)),
            Int(provider_calls), result_hash)
    end
end

function _irv1_result_body(x::InverseRealizationContractResultV1)
    (revision=_IRV1_REVISION, status=x.status, valid=x.valid,
        claim_ceiling=x.claim_ceiling, request_hash=x.request_hash,
        reasons=x.reasons, provider_calls=x.provider_calls)
end

semantic_view(x::InverseRealizationContractResultV1) = _irv1_result_body(x)
canonical_hash(x::InverseRealizationContractResultV1) = begin
    expected = canonical_hash(_irv1_result_body(x))
    expected == x.result_hash || throw(ArgumentError("inverse result identity mismatch"))
    expected
end

function _irv1_result(status, valid, request_hash, reasons)
    body = (revision=_IRV1_REVISION, status=status, valid=valid,
        claim_ceiling=_IRV1_CLAIM_CEILING, request_hash=request_hash,
        reasons=Tuple(String.(reasons)), provider_calls=0)
    InverseRealizationContractResultV1(Val(:inverse_realization_contract), status,
        valid, _IRV1_CLAIM_CEILING, request_hash, body.reasons, 0, canonical_hash(body))
end

function validate_inverse_realization_request(request::InverseRealizationRequestV1)
    request_hash = canonical_hash(request)
    fail_closed = String[]
    deferred = String[]
    target, source, ret = request.target, request.source, request.return_port

    if ret === nothing
        push!(deferred, "return_port_missing")
    else
        target.quantity == ret.quantity || push!(fail_closed, "target_return_quantity_mismatch")
        target.unit == ret.unit || push!(fail_closed, "target_return_unit_mismatch")
        target.function_space == ret.function_space || push!(fail_closed, "target_return_function_space_mismatch")
        target.domain == ret.domain || push!(fail_closed, "target_return_domain_mismatch")
        target.bound == ret.bound || push!(fail_closed, "target_return_bound_mismatch")
    end
    source.domain == request.geometry.domain || push!(fail_closed, "source_geometry_domain_mismatch")
    target.domain == request.geometry.domain || push!(fail_closed, "target_geometry_domain_mismatch")
    request.geometry.function_space === :geometry_map || push!(fail_closed, "geometry_function_space_mismatch")
    request.geometry.domain == target.domain || push!(fail_closed, "geometry_domain_mismatch")

    target.quantity === :voltage && request.electrical.emf_policy === :forbidden &&
        push!(fail_closed, "voltage_requires_nonforbidden_emf_policy")
    electrical_bound = target.quantity === :power ? request.electrical.power :
        target.quantity === :current ? request.electrical.current :
        target.quantity === :voltage ? request.electrical.voltage : nothing
    target.quantity in (:power, :current, :voltage) &&
        (electrical_bound === nothing || electrical_bound != target.bound) &&
        push!(fail_closed, "target_electrical_bound_mismatch")
    request.material.density.lower <= request.material.density.upper ||
        push!(fail_closed, "material_density_bound_inverted")
    request.geometry.extent.lower <= request.geometry.extent.upper ||
        push!(fail_closed, "geometry_extent_bound_inverted")

    provider = request.provider
    provider === nothing && push!(deferred, "provider_capability_missing")
    if provider !== nothing
        target.quantity in provider.quantities || push!(deferred, "target_provider_capability_missing")
        target.unit in provider.units || push!(deferred, "unit_provider_capability_missing")
        target.function_space in provider.function_spaces || push!(deferred, "function_space_provider_capability_missing")
        target.domain in provider.domains || push!(deferred, "target_domain_provider_capability_missing")
        source.quantity in provider.quantities || push!(deferred, "source_provider_capability_missing")
        source.unit in provider.units || push!(deferred, "source_unit_provider_capability_missing")
        source.function_space in provider.function_spaces || push!(deferred, "source_function_space_provider_capability_missing")
        source.domain in provider.domains || push!(deferred, "source_domain_provider_capability_missing")
        ret !== nothing && (ret.quantity in provider.quantities || push!(deferred, "return_provider_capability_missing"))
        ret !== nothing && (ret.unit in provider.units || push!(deferred, "return_unit_provider_capability_missing"))
        ret !== nothing && (ret.function_space in provider.function_spaces || push!(deferred, "return_function_space_provider_capability_missing"))
        ret !== nothing && (ret.domain in provider.domains || push!(deferred, "return_domain_provider_capability_missing"))
        1 in provider.derivative_orders || push!(deferred, "derivative_capability_missing")
        request.electrical.emf_policy in provider.emf_policies || push!(deferred, "emf_policy_capability_missing")
        request.material.model_ref in provider.material_models || push!(deferred, "material_provider_capability_missing")
        request.geometry.model_ref in provider.geometry_models || push!(deferred, "geometry_provider_capability_missing")
    end

    !isempty(fail_closed) && return _irv1_result(:fail_closed, false, request_hash, fail_closed)
    !isempty(deferred) && return _irv1_result(:terminal_deferred, false, request_hash, deferred)
    _irv1_result(:prepared, true, request_hash,
        ("contract_validated_no_provider_or_solver_invocation",))
end

"""Normalize only typed external-input failures at the admission boundary.

The builder is the untrusted-input seam.  Once it returns a typed request,
validation runs outside the catch so identity corruption, invariant violations,
and other internal program defects cannot be silently converted to a contract
result.
"""
function admit_inverse_realization_request(builder::Function)
    request = try
        builder()
    catch error
        typeof(error) === InverseExternalInputError || rethrow()
        detail = sprint(showerror, error)
        return _irv1_result(:fail_closed, false,
            digest256_text("invalid-request:" * detail),
            ("constructor_fail_closed", detail))
    end
    request isa InverseRealizationRequestV1 ||
        return _irv1_result(:fail_closed, false,
            digest256_text("invalid-request:wrong-request-type"),
            ("request_type_mismatch",))
    validate_inverse_realization_request(request)
end

const validate_inverse_realization_request_v1 = validate_inverse_realization_request
