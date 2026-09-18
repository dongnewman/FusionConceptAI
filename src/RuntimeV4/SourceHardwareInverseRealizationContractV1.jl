"""Contract-only source/hardware inverse-realization admission seam.

This additive V1 slice binds a source/coil/driver realization alternative to
one candidate and its G1/G2/G3 declarations.  It records material,
manufacturing, cooling, support, control-fault, provider, solver, and checker
requirements, but deliberately performs no provider, solver, checker,
external backend, or hardware operation.  A complete request can reach only
`status=:prepared`, `claim_ceiling=:contract_only`, with all invocation
counters equal to zero.
"""

import FusionConceptAI: Digest256, digest256_text, canonical_hash, semantic_view

const _SHIR_REVISION = "source-hardware-inverse-realization-contract-v1"
const _SHIR_SCHEMA = "fusionconceptai:source-hardware-inverse-realization-v1"
const _SHIR_CLAIM_CEILING = :contract_only
const _SHIR_REF_STATUSES = (:present, :typed_absent, :unknown)
const _SHIR_RESULT_STATUSES = (:prepared, :fail_closed, :typed_absent,
    :unknown, :terminal_deferred, :not_executed, :numerical_fail, :physical_fail)
const _SHIR_PROVIDER_MATCHES = (:not_checked, :no_match, :ambiguous,
    :out_of_domain, :invalid_signature, :matched)
const _SHIR_PHYSICAL_STATES = (:not_checked, :unknown, :pass, :fail)
const _SHIR_UNITS = (:W, :A, :V, :T, :Pa, :kg_m3, :S_m, :m, :unspecified)
const _SHIR_PORTS = (:target, :source, :coil, :driver, :return, :none)

struct SourceHardwareExternalInputError <: Exception
    code::Symbol
    detail::String
end

Base.showerror(io::IO, error::SourceHardwareExternalInputError) =
    print(io, "source/hardware inverse input [", error.code, "]: ", error.detail)

_shir_error(message) = SourceHardwareExternalInputError(:malformed_input, String(message))

function _shir_text(value, label)
    value isa AbstractString || throw(_shir_error("$label must be a string"))
    result = String(value)
    isempty(strip(result)) && throw(_shir_error("$label must be non-empty"))
    isvalid(result) || throw(_shir_error("$label must be valid UTF-8"))
    result
end

function _shir_symbol(value, allowed, label)
    value isa Symbol && value in allowed || throw(_shir_error("invalid $label"))
    value
end

function _shir_digest(value, label)
    value isa Digest256 || throw(_shir_error("$label must be Digest256"))
    value
end

function _shir_tuple(value, label)
    value isa Tuple || throw(_shir_error("$label must be an immutable tuple"))
    value
end

function _shir_unique_refs(values, label)
    xs = _shir_tuple(values, label)
    all(x -> x isa SourceHardwareRefV1, xs) || throw(_shir_error("$label contains an untyped reference"))
    hashes = Tuple(x.ref_hash for x in xs)
    length(unique(hashes)) == length(hashes) || throw(_shir_error("$label contains duplicate references"))
    xs
end

"""A public, content-addressed ref; `typed_absent` is explicit, not `nothing`."""
struct SourceHardwareRefV1
    ref::String
    kind::Symbol
    version::String
    schema_hash::Digest256
    canonicalization_hash::Digest256
    content_hash::Digest256
    unit::Symbol
    port::Symbol
    domain::String
    status::Symbol
    reason::String
    ref_hash::Digest256
    function SourceHardwareRefV1(ref, kind, version, schema_hash,
            canonicalization_hash, content_hash, unit, port, domain, status,
            reason, ref_hash)
        r = _shir_text(ref, "ref")
        k = _shir_symbol(kind, (:candidate, :genome, :axis, :parent, :mission,
            :scenario, :physical_subject, :design_alternative, :target, :source,
            :coil, :driver, :return_path, :material, :manufacturing, :cooling,
            :support, :control_fault, :provider, :solver, :checker), "ref kind")
        v = _shir_text(version, "ref version")
        sh = _shir_digest(schema_hash, "schema hash")
        ch = _shir_digest(canonicalization_hash, "canonicalization hash")
        content = _shir_digest(content_hash, "content hash")
        u = _shir_symbol(unit, _SHIR_UNITS, "ref unit")
        p = _shir_symbol(port, _SHIR_PORTS, "ref port")
        d = _shir_text(domain, "ref domain")
        k in (:target, :source, :coil, :driver, :return_path) &&
            (u !== :unspecified && p !== :none) ||
            !(k in (:target, :source, :coil, :driver, :return_path)) &&
            (u === :unspecified && p === :none) ||
            throw(_shir_error("port unit/role must be explicit or absent"))
        st = _shir_symbol(status, _SHIR_REF_STATUSES, "ref status")
        why = String(reason)
        st === :present && isempty(strip(why)) || st !== :present && !isempty(strip(why)) ||
            throw(_shir_error("present/absent ref reason mismatch"))
        rh = _shir_digest(ref_hash, "ref hash")
        new(r, k, v, sh, ch, content, u, p, d, st, why, rh)
    end
end

function _shir_ref_body(x::SourceHardwareRefV1)
    (revision=_SHIR_REVISION, ref=x.ref, kind=x.kind, version=x.version,
        schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash,
        content_hash=x.content_hash, unit=x.unit, port=x.port, domain=x.domain,
        status=x.status, reason=x.reason)
end

semantic_view(x::SourceHardwareRefV1) = merge(_shir_ref_body(x), (ref_hash=x.ref_hash,))
canonical_hash(x::SourceHardwareRefV1) = begin
    expected = canonical_hash(_shir_ref_body(x))
    expected == x.ref_hash || throw(ArgumentError("source/hardware ref hash mismatch"))
    expected
end

struct SourceHardwareVersionAxesV1
    contract_axis::SourceHardwareRefV1
    schema_axis::SourceHardwareRefV1
    canonicalization_axis::SourceHardwareRefV1
    compatibility_axis::SourceHardwareRefV1
    axes_hash::Digest256
    function SourceHardwareVersionAxesV1(contract_axis, schema_axis,
            canonicalization_axis, compatibility_axis, axes_hash)
        axes = (contract_axis, schema_axis, canonicalization_axis, compatibility_axis)
        all(x -> x isa SourceHardwareRefV1 && x.kind === :axis, axes) ||
            throw(_shir_error("four version axes must be typed axis refs"))
        length(unique(x.ref_hash for x in axes)) == 4 ||
            throw(_shir_error("four version axes must be distinct"))
        new(axes[1], axes[2], axes[3], axes[4],
            _shir_digest(axes_hash, "version axes hash"))
    end
end

function _shir_axes_body(x::SourceHardwareVersionAxesV1)
    (revision=_SHIR_REVISION, contract_axis=x.contract_axis,
        schema_axis=x.schema_axis, canonicalization_axis=x.canonicalization_axis,
        compatibility_axis=x.compatibility_axis)
end

semantic_view(x::SourceHardwareVersionAxesV1) = merge(_shir_axes_body(x), (axes_hash=x.axes_hash,))
canonical_hash(x::SourceHardwareVersionAxesV1) = begin
    foreach(canonical_hash, (x.contract_axis, x.schema_axis,
        x.canonicalization_axis, x.compatibility_axis))
    expected = canonical_hash(_shir_axes_body(x))
    expected == x.axes_hash || throw(ArgumentError("four version axes hash mismatch"))
    expected
end

"""Exact same-candidate G1/G2/G3 and four-axis binding."""
struct SourceHardwareCandidateBindingV1
    candidate::SourceHardwareRefV1
    g1::SourceHardwareRefV1
    g2::SourceHardwareRefV1
    g3::SourceHardwareRefV1
    parent::SourceHardwareRefV1
    mission::SourceHardwareRefV1
    scenario::SourceHardwareRefV1
    physical_subject::SourceHardwareRefV1
    design_alternative::SourceHardwareRefV1
    axes::SourceHardwareVersionAxesV1
    binding_hash::Digest256
    function SourceHardwareCandidateBindingV1(candidate, g1, g2, g3, parent,
            mission, scenario, physical_subject, design_alternative, axes,
            binding_hash)
        refs = (candidate, g1, g2, g3, parent, mission, scenario,
            physical_subject, design_alternative)
        all(x -> x isa SourceHardwareRefV1, refs) ||
            throw(_shir_error("candidate binding refs must be typed"))
        candidate.kind === :candidate && g1.kind === :genome &&
            g2.kind === :genome && g3.kind === :genome &&
            parent.kind === :parent && mission.kind === :mission &&
            scenario.kind === :scenario && physical_subject.kind === :physical_subject &&
            design_alternative.kind === :design_alternative ||
            throw(_shir_error("candidate binding ref kinds are inconsistent"))
        axes isa SourceHardwareVersionAxesV1 || throw(_shir_error("version axes are untyped"))
        new(refs[1], refs[2], refs[3], refs[4], refs[5], refs[6], refs[7],
            refs[8], refs[9], axes, _shir_digest(binding_hash, "candidate binding hash"))
    end
end

function _shir_binding_body(x::SourceHardwareCandidateBindingV1)
    (revision=_SHIR_REVISION, candidate=x.candidate, g1=x.g1, g2=x.g2, g3=x.g3,
        parent=x.parent, mission=x.mission, scenario=x.scenario,
        physical_subject=x.physical_subject, design_alternative=x.design_alternative,
        axes=x.axes)
end

semantic_view(x::SourceHardwareCandidateBindingV1) =
    merge(_shir_binding_body(x), (binding_hash=x.binding_hash,))
canonical_hash(x::SourceHardwareCandidateBindingV1) = begin
    foreach(canonical_hash, (x.candidate, x.g1, x.g2, x.g3, x.parent,
        x.mission, x.scenario, x.physical_subject, x.design_alternative))
    canonical_hash(x.axes)
    expected = canonical_hash(_shir_binding_body(x))
    expected == x.binding_hash || throw(ArgumentError("candidate binding hash mismatch"))
    expected
end

"""All source/hardware declarations remain explicit fields, never family defaults."""
struct SourceHardwareDesignAlternativeV1
    alternative::SourceHardwareRefV1
    candidate_hash::Digest256
    candidate_binding_hash::Digest256
    candidate_provenance_hash::Digest256
    g1_hash::Digest256
    g2_hash::Digest256
    g3_hash::Digest256
    axes_hash::Digest256
    parent_hash::Digest256
    mission_hash::Digest256
    scenario_hash::Digest256
    physical_subject_hash::Digest256
    target::SourceHardwareRefV1
    source::SourceHardwareRefV1
    coil::SourceHardwareRefV1
    driver::SourceHardwareRefV1
    return_ref::SourceHardwareRefV1
    material::SourceHardwareRefV1
    manufacturing::SourceHardwareRefV1
    cooling::SourceHardwareRefV1
    support::SourceHardwareRefV1
    control_fault::SourceHardwareRefV1
    provider::SourceHardwareRefV1
    solver::SourceHardwareRefV1
    checker::SourceHardwareRefV1
    design_hash::Digest256
    function SourceHardwareDesignAlternativeV1(alternative, candidate_hash,
            candidate_binding_hash, candidate_provenance_hash, g1_hash, g2_hash,
            g3_hash, axes_hash, parent_hash, mission_hash, scenario_hash,
            physical_subject_hash, target, source, coil, driver, return_ref,
            material, manufacturing, cooling, support, control_fault, provider,
            solver, checker, design_hash)
        alternative isa SourceHardwareRefV1 && alternative.kind === :design_alternative ||
            throw(_shir_error("design alternative ref is invalid"))
        refs = (target, source, coil, driver, return_ref, material, manufacturing,
            cooling, support, control_fault, provider, solver, checker)
        all(x -> x isa SourceHardwareRefV1, refs) ||
            throw(_shir_error("source/hardware declaration is untyped"))
        kinds = Tuple(x.kind for x in refs)
        kinds == (:target, :source, :coil, :driver, :return_path, :material,
            :manufacturing, :cooling, :support, :control_fault, :provider,
            :solver, :checker) || throw(_shir_error("source/hardware declaration order or kinds mismatch"))
        new(alternative, _shir_digest(candidate_hash, "design candidate hash"),
            _shir_digest(candidate_binding_hash, "candidate binding hash"),
            _shir_digest(candidate_provenance_hash, "candidate provenance hash"),
            _shir_digest(g1_hash, "design G1 hash"), _shir_digest(g2_hash, "design G2 hash"),
            _shir_digest(g3_hash, "design G3 hash"), _shir_digest(axes_hash, "design axes hash"),
            _shir_digest(parent_hash, "design parent hash"), _shir_digest(mission_hash, "design mission hash"),
            _shir_digest(scenario_hash, "design scenario hash"),
            _shir_digest(physical_subject_hash, "design physical-subject hash"),
            refs[1], refs[2], refs[3], refs[4], refs[5], refs[6], refs[7], refs[8],
            refs[9], refs[10], refs[11], refs[12], refs[13],
            _shir_digest(design_hash, "design hash"))
    end
end

function _shir_design_declaration_refs(x::SourceHardwareDesignAlternativeV1)
    (x.target, x.source, x.coil, x.driver, x.return_ref, x.material,
        x.manufacturing, x.cooling, x.support, x.control_fault, x.provider,
        x.solver, x.checker)
end

function _shir_candidate_provenance_hash(binding_hash::Digest256,
        refs::Tuple)
    canonical_hash((revision=_SHIR_REVISION, candidate_binding_hash=binding_hash,
        declaration_hashes=Tuple(x.ref_hash for x in refs)))
end

function _shir_design_body(x::SourceHardwareDesignAlternativeV1)
    (revision=_SHIR_REVISION, alternative=x.alternative,
        candidate_hash=x.candidate_hash,
        candidate_binding_hash=x.candidate_binding_hash,
        candidate_provenance_hash=x.candidate_provenance_hash,
        g1_hash=x.g1_hash, g2_hash=x.g2_hash,
        g3_hash=x.g3_hash, axes_hash=x.axes_hash, parent_hash=x.parent_hash,
        mission_hash=x.mission_hash, scenario_hash=x.scenario_hash,
        physical_subject_hash=x.physical_subject_hash, target=x.target,
        source=x.source, coil=x.coil, driver=x.driver, return_ref=x.return_ref,
        material=x.material, manufacturing=x.manufacturing, cooling=x.cooling,
        support=x.support, control_fault=x.control_fault, provider=x.provider,
        solver=x.solver, checker=x.checker)
end

semantic_view(x::SourceHardwareDesignAlternativeV1) =
    merge(_shir_design_body(x), (design_hash=x.design_hash,))
canonical_hash(x::SourceHardwareDesignAlternativeV1) = begin
    canonical_hash(x.alternative)
    foreach(canonical_hash, _shir_design_declaration_refs(x))
    expected = canonical_hash(_shir_design_body(x))
    expected == x.design_hash || throw(ArgumentError("design alternative hash mismatch"))
    expected
end

struct SourceHardwareInverseRealizationContractV1
    schema::String
    revision::String
    request_ref::String
    binding::SourceHardwareCandidateBindingV1
    design::SourceHardwareDesignAlternativeV1
    canonical_bytes::String
    canonical_bytes_hash::Digest256
    request_hash::Digest256
    function SourceHardwareInverseRealizationContractV1(schema, revision, request_ref,
            binding::SourceHardwareCandidateBindingV1,
            design::SourceHardwareDesignAlternativeV1, canonical_bytes,
            canonical_bytes_hash, request_hash)
        String(schema) == _SHIR_SCHEMA || throw(_shir_error("schema mismatch"))
        String(revision) == _SHIR_REVISION || throw(_shir_error("revision mismatch"))
        bytes = String(canonical_bytes)
        isempty(bytes) && throw(_shir_error("canonical bytes cannot be empty"))
        new(_SHIR_SCHEMA, _SHIR_REVISION, _shir_text(request_ref, "request ref"),
            binding, design, bytes, _shir_digest(canonical_bytes_hash, "canonical bytes hash"),
            _shir_digest(request_hash, "request hash"))
    end
end

function _shir_request_body(x::SourceHardwareInverseRealizationContractV1)
    (schema=_SHIR_SCHEMA, revision=_SHIR_REVISION, request_ref=x.request_ref,
        binding=x.binding, design=x.design, canonical_bytes_hash=x.canonical_bytes_hash)
end

semantic_view(x::SourceHardwareInverseRealizationContractV1) =
    merge(_shir_request_body(x), (request_hash=x.request_hash,))
canonical_hash(x::SourceHardwareInverseRealizationContractV1) = begin
    expected_bytes = digest256_text(x.canonical_bytes)
    expected_bytes == x.canonical_bytes_hash || throw(ArgumentError("canonical bytes hash mismatch"))
    canonical_hash(x.binding); canonical_hash(x.design)
    expected = canonical_hash(_shir_request_body(x))
    expected == x.request_hash || throw(ArgumentError("inverse realization request hash mismatch"))
    expected
end

struct SourceHardwareInverseResolutionV1
    status::Symbol
    valid::Bool
    claim_ceiling::Symbol
    request_hash::Digest256
    reasons::Tuple{Vararg{String}}
    provider_calls::Int
    solver_calls::Int
    checker_calls::Int
    evidence_status::Symbol
    resolution_hash::Digest256
    function SourceHardwareInverseResolutionV1(token::Val{:source_hardware_inverse_resolution},
            status, valid, claim_ceiling, request_hash, reasons, provider_calls,
            solver_calls, checker_calls, evidence_status, resolution_hash)
        token === Val(:source_hardware_inverse_resolution) || throw(ArgumentError("private resolution constructor"))
        status in _SHIR_RESULT_STATUSES || throw(ArgumentError("invalid inverse resolution status"))
        valid === (status === :prepared) || throw(ArgumentError("resolution status/valid mismatch"))
        claim_ceiling === _SHIR_CLAIM_CEILING || throw(ArgumentError("invalid inverse claim ceiling"))
        provider_calls == solver_calls == checker_calls == 0 ||
            throw(ArgumentError("contract-only resolution invoked an execution counter"))
        evidence_status in (:contract_only, :not_measured) ||
            throw(ArgumentError("invalid contract evidence status"))
        new(status, Bool(valid), claim_ceiling, request_hash,
            Tuple(String.(reasons)), Int(provider_calls), Int(solver_calls),
            Int(checker_calls), evidence_status, resolution_hash)
    end
end

function _shir_resolution_body(x::SourceHardwareInverseResolutionV1)
    (revision=_SHIR_REVISION, status=x.status, valid=x.valid,
        claim_ceiling=x.claim_ceiling, request_hash=x.request_hash,
        reasons=x.reasons, provider_calls=x.provider_calls,
        solver_calls=x.solver_calls, checker_calls=x.checker_calls,
        evidence_status=x.evidence_status)
end

semantic_view(x::SourceHardwareInverseResolutionV1) =
    merge(_shir_resolution_body(x), (resolution_hash=x.resolution_hash,))
canonical_hash(x::SourceHardwareInverseResolutionV1) = begin
    expected = canonical_hash(_shir_resolution_body(x))
    expected == x.resolution_hash || throw(ArgumentError("inverse resolution hash mismatch"))
    expected
end

function _shir_resolution(status, request_hash, reasons)
    body = (revision=_SHIR_REVISION, status=status, valid=status === :prepared,
        claim_ceiling=_SHIR_CLAIM_CEILING, request_hash=request_hash,
        reasons=Tuple(String.(reasons)), provider_calls=0, solver_calls=0,
        checker_calls=0, evidence_status=:contract_only)
    SourceHardwareInverseResolutionV1(Val(:source_hardware_inverse_resolution),
        status, body.valid, _SHIR_CLAIM_CEILING, request_hash, body.reasons,
        0, 0, 0, :contract_only, canonical_hash(body))
end

_shir_ref_present(x::SourceHardwareRefV1) = x.status === :present

function validate_source_hardware_inverse_contract(
        request::SourceHardwareInverseRealizationContractV1)
    request_hash = canonical_hash(request)
    fail_closed = String[]
    typed_absent = Symbol[]
    unknown = Symbol[]
    deferred = String[]
    b, d = request.binding, request.design

    all_refs = (b.candidate, b.g1, b.g2, b.g3, b.parent, b.mission, b.scenario,
        b.physical_subject, b.design_alternative, b.axes.contract_axis,
        b.axes.schema_axis, b.axes.canonicalization_axis, b.axes.compatibility_axis,
        d.alternative, d.target, d.source, d.coil, d.driver, d.return_ref,
        d.material, d.manufacturing, d.cooling, d.support, d.control_fault,
        d.provider, d.solver, d.checker)
    foreach(canonical_hash, all_refs)
    foreach(x -> x.status === :typed_absent && x.kind !== :provider &&
        push!(typed_absent, x.kind), all_refs)
    foreach(x -> x.status === :unknown && push!(unknown, x.kind), all_refs)

    b.candidate.status === :present || push!(fail_closed, "candidate_authority_absent")
    d.candidate_hash == b.candidate.ref_hash || push!(fail_closed, "candidate_hash_mismatch")
    d.g1_hash == b.g1.ref_hash || push!(fail_closed, "g1_hash_mismatch")
    d.g2_hash == b.g2.ref_hash || push!(fail_closed, "g2_hash_mismatch")
    d.g3_hash == b.g3.ref_hash || push!(fail_closed, "g3_hash_mismatch")
    d.axes_hash == b.axes.axes_hash || push!(fail_closed, "version_axes_hash_mismatch")
    d.parent_hash == b.parent.ref_hash || push!(fail_closed, "parent_hash_mismatch")
    d.mission_hash == b.mission.ref_hash || push!(fail_closed, "mission_hash_mismatch")
    d.scenario_hash == b.scenario.ref_hash || push!(fail_closed, "scenario_hash_mismatch")
    d.physical_subject_hash == b.physical_subject.ref_hash ||
        push!(fail_closed, "physical_subject_hash_mismatch")
    d.alternative.ref_hash == b.design_alternative.ref_hash ||
        push!(fail_closed, "design_alternative_hash_mismatch")

    for (ref, label) in ((d.target, "target"), (d.source, "source"),
            (d.coil, "coil"), (d.driver, "driver"), (d.return_ref, "return"),
            (d.material, "material"), (d.manufacturing, "manufacturing"),
            (d.cooling, "cooling"), (d.support, "support"),
            (d.control_fault, "control_fault"), (d.solver, "solver"),
            (d.checker, "checker"))
        ref.status === :present || push!(typed_absent, Symbol(label))
    end
    d.target.port === :target || push!(fail_closed, "target_port_mismatch")
    d.source.port === :source || push!(fail_closed, "source_port_mismatch")
    d.coil.port === :coil || push!(fail_closed, "coil_port_mismatch")
    d.driver.port === :driver || push!(fail_closed, "driver_port_mismatch")
    d.return_ref.port === :return || push!(fail_closed, "return_port_mismatch")
    d.target.unit === :W || push!(fail_closed, "target_unit_mismatch")
    d.source.unit === :V || push!(fail_closed, "source_unit_mismatch")
    d.coil.unit === :A || push!(fail_closed, "coil_unit_mismatch")
    d.driver.unit === :V || push!(fail_closed, "driver_unit_mismatch")
    d.return_ref.unit === :W || push!(fail_closed, "return_unit_mismatch")
    d.target.unit == d.return_ref.unit || push!(fail_closed, "target_return_unit_mismatch")
    d.target.domain == d.return_ref.domain || push!(fail_closed, "target_return_domain_mismatch")
    d.source.domain == d.target.domain || push!(fail_closed, "source_target_domain_mismatch")
    d.coil.domain == d.target.domain || push!(fail_closed, "coil_target_domain_mismatch")
    d.driver.domain == d.target.domain || push!(fail_closed, "driver_target_domain_mismatch")
    d.candidate_binding_hash == b.binding_hash ||
        push!(fail_closed, "candidate_binding_hash_mismatch")
    expected_provenance = _shir_candidate_provenance_hash(
        b.binding_hash, _shir_design_declaration_refs(d))
    d.candidate_provenance_hash == expected_provenance ||
        push!(fail_closed, "candidate_provenance_hash_mismatch")

    d.provider.status === :present || push!(deferred, "provider_capability_gap")
    d.provider.status === :unknown && push!(unknown, :provider)

    !isempty(fail_closed) && return _shir_resolution(:fail_closed, request_hash,
        fail_closed)
    !isempty(unknown) && return _shir_resolution(:unknown, request_hash, unknown)
    !isempty(typed_absent) && return _shir_resolution(:typed_absent, request_hash,
        Tuple(unique(typed_absent)))
    !isempty(deferred) && return _shir_resolution(:terminal_deferred, request_hash,
        deferred)
    _shir_resolution(:prepared, request_hash,
        ("contract_only_no_provider_solver_checker_invocation",))
end

"""Classify a future execution without executing any provider or solver."""
function classify_source_hardware_inverse_outcome(; provider_match=:not_checked,
        solver_exit=nothing, physical_status=:not_checked,
        checker_status=:not_checked)
    provider_match in _SHIR_PROVIDER_MATCHES || throw(_shir_error("invalid provider match"))
    physical_status in _SHIR_PHYSICAL_STATES || throw(_shir_error("invalid physical status"))
    checker_status in (:not_checked, :pass, :fail, :unknown) ||
        throw(_shir_error("invalid checker status"))
    provider_match in (:no_match, :ambiguous, :out_of_domain, :invalid_signature) &&
        return :terminal_deferred
    solver_exit === nothing && return :not_executed
    solver_exit isa Integer || throw(_shir_error("solver exit must be an integer"))
    solver_exit != 0 && return :numerical_fail
    physical_status === :fail && return :physical_fail
    physical_status === :unknown || checker_status === :unknown ? :unknown :
        checker_status === :fail ? :numerical_fail : :not_executed
end

function admit_source_hardware_inverse_contract(builder::Function)
    request = try
        builder()
    catch error
        typeof(error) === SourceHardwareExternalInputError || rethrow()
        return _shir_resolution(:fail_closed,
            digest256_text("invalid-source-hardware-request"),
            ("constructor_fail_closed", sprint(showerror, error)))
    end
    request isa SourceHardwareInverseRealizationContractV1 ||
        return _shir_resolution(:fail_closed,
            digest256_text("wrong-source-hardware-request-type"),
            ("request_type_mismatch",))
    validate_source_hardware_inverse_contract(request)
end

const validate_source_hardware_inverse_realization_v1 =
    validate_source_hardware_inverse_contract
