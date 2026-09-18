using Test
using JSON3
using FusionConceptAI

const _SHIR_SOURCE = normpath(joinpath(@__DIR__, "../../src/RuntimeV4/SourceHardwareInverseRealizationContractV1.jl"))
@assert isfile(_SHIR_SOURCE)
include(_SHIR_SOURCE)

function _shir_test_ref(kind; status=:present, suffix=String(kind), reason="",
        unit=nothing, port=nothing, domain="hardware-domain")
    port = port === nothing ? kind === :target ? :target : kind === :source ? :source :
        kind === :coil ? :coil : kind === :driver ? :driver :
        kind === :return_path ? :return : :none : port
    unit = unit === nothing ? kind === :target || kind === :return_path ? :W :
        kind === :source || kind === :driver ? :V : kind === :coil ? :A : :unspecified : unit
    domain = kind === :axis || kind === :candidate || kind === :genome ||
        kind === :parent || kind === :mission || kind === :scenario ||
        kind === :physical_subject || kind === :design_alternative ? "identity" : domain
    body = (revision=_SHIR_REVISION, ref="fixture.$suffix", kind=kind,
        version="v1", schema_hash=digest256_text("schema:$suffix"),
        canonicalization_hash=digest256_text("canonical:$suffix"),
        content_hash=digest256_text("content:$suffix"), unit=unit, port=port,
        domain=domain, status=status,
        reason=status === :present ? "" : (isempty(reason) ? "fixture absent" : reason))
    SourceHardwareRefV1(body.ref, body.kind, body.version, body.schema_hash,
        body.canonicalization_hash, body.content_hash, body.unit, body.port,
        body.domain, body.status, body.reason,
        canonical_hash(body))
end

function _shir_test_axes()
    axes = (_shir_test_ref(:axis; suffix="contract"),
        _shir_test_ref(:axis; suffix="schema"),
        _shir_test_ref(:axis; suffix="canonicalization"),
        _shir_test_ref(:axis; suffix="compatibility"))
    body = (revision=_SHIR_REVISION, contract_axis=axes[1], schema_axis=axes[2],
        canonicalization_axis=axes[3], compatibility_axis=axes[4])
    SourceHardwareVersionAxesV1(axes[1], axes[2], axes[3], axes[4], canonical_hash(body))
end

function _shir_test_binding()
    refs = (_shir_test_ref(:candidate), _shir_test_ref(:genome; suffix="g1"),
        _shir_test_ref(:genome; suffix="g2"), _shir_test_ref(:genome; suffix="g3"),
        _shir_test_ref(:parent), _shir_test_ref(:mission), _shir_test_ref(:scenario),
        _shir_test_ref(:physical_subject), _shir_test_ref(:design_alternative))
    axes = _shir_test_axes()
    body = (revision=_SHIR_REVISION, candidate=refs[1], g1=refs[2], g2=refs[3],
        g3=refs[4], parent=refs[5], mission=refs[6], scenario=refs[7],
        physical_subject=refs[8], design_alternative=refs[9], axes=axes)
    SourceHardwareCandidateBindingV1(refs[1], refs[2], refs[3], refs[4], refs[5],
        refs[6], refs[7], refs[8], refs[9], axes, canonical_hash(body))
end

function _shir_test_design(binding; absent=Symbol[], unknown=Symbol[],
        return_unit=nothing, driver_port=nothing, source_domain=nothing)
    function ref(kind; unit=nothing, port=nothing, domain="hardware-domain")
        status = kind in unknown ? :unknown : kind in absent ? :typed_absent : :present
        _shir_test_ref(kind; status, suffix=String(kind), unit, port, domain)
    end
    refs = (ref(:target), ref(:source;
        domain=source_domain === nothing ? "hardware-domain" : source_domain),
        ref(:coil), ref(:driver; port=driver_port === nothing ? :driver : driver_port),
        ref(:return_path; unit=return_unit),
        ref(:material), ref(:manufacturing), ref(:cooling), ref(:support),
        ref(:control_fault), ref(:provider), ref(:solver), ref(:checker))
    hashes = (binding.candidate.ref_hash, binding.g1.ref_hash, binding.g2.ref_hash,
        binding.g3.ref_hash, binding.axes.axes_hash, binding.parent.ref_hash,
        binding.mission.ref_hash, binding.scenario.ref_hash,
        binding.physical_subject.ref_hash)
    candidate_binding_hash = binding.binding_hash
    candidate_provenance_hash = _shir_candidate_provenance_hash(
        candidate_binding_hash, refs)
    body = (revision=_SHIR_REVISION, alternative=binding.design_alternative,
        candidate_hash=hashes[1], candidate_binding_hash=candidate_binding_hash,
        candidate_provenance_hash=candidate_provenance_hash,
        g1_hash=hashes[2], g2_hash=hashes[3],
        g3_hash=hashes[4], axes_hash=hashes[5], parent_hash=hashes[6],
        mission_hash=hashes[7], scenario_hash=hashes[8],
        physical_subject_hash=hashes[9], target=refs[1], source=refs[2],
        coil=refs[3], driver=refs[4], return_ref=refs[5], material=refs[6],
        manufacturing=refs[7], cooling=refs[8], support=refs[9],
        control_fault=refs[10], provider=refs[11], solver=refs[12], checker=refs[13])
    SourceHardwareDesignAlternativeV1(binding.design_alternative, hashes[1],
        candidate_binding_hash, candidate_provenance_hash, hashes[2], hashes[3],
        hashes[4], hashes[5], hashes[6], hashes[7], hashes[8], hashes[9],
        refs[1], refs[2], refs[3], refs[4], refs[5], refs[6], refs[7], refs[8],
        refs[9], refs[10], refs[11], refs[12], refs[13], canonical_hash(body))
end

function _shir_design_with_alternative(d, alternative)
    SourceHardwareDesignAlternativeV1(alternative, d.candidate_hash,
        d.candidate_binding_hash, d.candidate_provenance_hash, d.g1_hash,
        d.g2_hash, d.g3_hash, d.axes_hash, d.parent_hash, d.mission_hash,
        d.scenario_hash, d.physical_subject_hash, d.target, d.source, d.coil,
        d.driver, d.return_ref, d.material, d.manufacturing, d.cooling,
        d.support, d.control_fault, d.provider, d.solver, d.checker,
        d.design_hash)
end

function _shir_test_request(; absent=Symbol[], unknown=Symbol[], return_unit=nothing,
        driver_port=nothing, source_domain=nothing)
    binding = _shir_test_binding()
    design = _shir_test_design(binding; absent, unknown, return_unit, driver_port,
        source_domain)
    bytes = "{\"schema\":\"source-hardware-inverse-realization-v1\",\"fixture\":true}"
    body = (schema=_SHIR_SCHEMA, revision=_SHIR_REVISION,
        request_ref="fixture.request", binding=binding, design=design,
        canonical_bytes_hash=digest256_text(bytes))
    SourceHardwareInverseRealizationContractV1(_SHIR_SCHEMA, _SHIR_REVISION,
        "fixture.request", binding, design, bytes, body.canonical_bytes_hash,
        canonical_hash(body))
end

function _shir_rebuild_design(d; candidate_hash=d.candidate_hash,
        candidate_binding_hash=d.candidate_binding_hash,
        candidate_provenance_hash=nothing, g1_hash=d.g1_hash,
        g2_hash=d.g2_hash, g3_hash=d.g3_hash, axes_hash=d.axes_hash,
        parent_hash=d.parent_hash, mission_hash=d.mission_hash,
        scenario_hash=d.scenario_hash, physical_subject_hash=d.physical_subject_hash,
        target=d.target, source=d.source, coil=d.coil, driver=d.driver,
        return_ref=d.return_ref, material=d.material, manufacturing=d.manufacturing,
        cooling=d.cooling, support=d.support, control_fault=d.control_fault,
        provider=d.provider, solver=d.solver, checker=d.checker)
    refs = (target, source, coil, driver, return_ref, material, manufacturing,
        cooling, support, control_fault, provider, solver, checker)
    candidate_provenance_hash = candidate_provenance_hash === nothing ?
        _shir_candidate_provenance_hash(candidate_binding_hash, refs) :
        candidate_provenance_hash
    body = (revision=_SHIR_REVISION, alternative=d.alternative,
        candidate_hash, candidate_binding_hash, candidate_provenance_hash,
        g1_hash, g2_hash, g3_hash, axes_hash, parent_hash,
        mission_hash, scenario_hash, physical_subject_hash, target, source, coil,
        driver, return_ref, material, manufacturing, cooling, support, control_fault,
        provider, solver, checker)
    SourceHardwareDesignAlternativeV1(d.alternative, candidate_hash,
        candidate_binding_hash, candidate_provenance_hash, g1_hash, g2_hash,
        g3_hash, axes_hash, parent_hash, mission_hash, scenario_hash,
        physical_subject_hash, target, source, coil, driver, return_ref, material,
        manufacturing, cooling, support, control_fault, provider, solver, checker,
        canonical_hash(body))
end

function _shir_rebuild_request(binding, design; request_ref="fixture.request",
        bytes="{\"schema\":\"source-hardware-inverse-realization-v1\",\"fixture\":true}")
    body = (schema=_SHIR_SCHEMA, revision=_SHIR_REVISION, request_ref=request_ref,
        binding=binding, design=design, canonical_bytes_hash=digest256_text(bytes))
    SourceHardwareInverseRealizationContractV1(_SHIR_SCHEMA, _SHIR_REVISION,
        request_ref, binding, design, bytes, body.canonical_bytes_hash,
        canonical_hash(body))
end

function _shir_assert_rebuilt_hashes(design, request)
    @test canonical_hash(design) == design.design_hash
    @test canonical_hash(request) == request.request_hash
end

function _shir_record_request_case!(coverage, label, design, request, result,
        expected_status, expected_reason=nothing)
    _shir_assert_rebuilt_hashes(design, request)
    @test result.status == expected_status
    expected_reason === nothing || (@test expected_reason in result.reasons)
    @test result.provider_calls == result.solver_calls == result.checker_calls == 0
    coverage[label] = (status=String(result.status),
        reason=expected_reason === nothing ? nothing : String(expected_reason),
        provider_calls=result.provider_calls, solver_calls=result.solver_calls,
        checker_calls=result.checker_calls)
    result
end

function _shir_record_symbol_case!(coverage, label, status)
    coverage[label] = (status=String(status), reason=nothing,
        provider_calls=0, solver_calls=0, checker_calls=0)
    status
end

function _shir_identity_mutation(d, mutation::Symbol)
    mutation === :candidate && return _shir_rebuild_design(d;
        candidate_hash=digest256_text("bad-candidate"))
    mutation === :g1 && return _shir_rebuild_design(d; g1_hash=digest256_text("bad-g1"))
    mutation === :g2 && return _shir_rebuild_design(d; g2_hash=digest256_text("bad-g2"))
    mutation === :g3 && return _shir_rebuild_design(d; g3_hash=digest256_text("bad-g3"))
    mutation === :axes && return _shir_rebuild_design(d;
        axes_hash=digest256_text("bad-axes"))
    mutation === :parent && return _shir_rebuild_design(d;
        parent_hash=digest256_text("bad-parent"))
    mutation === :mission && return _shir_rebuild_design(d;
        mission_hash=digest256_text("bad-mission"))
    mutation === :scenario && return _shir_rebuild_design(d;
        scenario_hash=digest256_text("bad-scenario"))
    mutation === :physical_subject && return _shir_rebuild_design(d;
        physical_subject_hash=digest256_text("bad-physical-subject"))
    error("unknown identity mutation: $mutation")
end

@testset "UP4-01A source/hardware inverse realization contract-only V1" begin
    fixture = JSON3.read(read(joinpath(@__DIR__, "fixtures",
        "source_hardware_inverse_realization_contract_v1.json")))
    negative_coverage = Dict{String,NamedTuple}()
    request = _shir_test_request()
    result = validate_source_hardware_inverse_contract(request)
    @test result.status == :prepared
    @test result.valid
    @test result.claim_ceiling == :contract_only
    @test result.provider_calls == result.solver_calls == result.checker_calls == 0
    @test canonical_hash(request) == request.request_hash
    @test canonical_hash(result) == result.resolution_hash
    positive = fixture.positive
    @test String(positive.id) == "complete_candidate_bound_alternative"
    @test result.status == Symbol(positive.expected_status)
    @test result.claim_ceiling == Symbol(positive.claim_ceiling)
    @test request.schema == _SHIR_SCHEMA
    @test request.revision == _SHIR_REVISION
    @test request.binding.candidate.kind === :candidate
    @test request.binding.g1.kind === :genome
    @test request.binding.g2.kind === :genome
    @test request.binding.g3.kind === :genome
    @test request.binding.axes isa SourceHardwareVersionAxesV1
    @test request.binding.parent.kind === :parent
    @test request.binding.mission.kind === :mission
    @test request.binding.scenario.kind === :scenario
    @test request.binding.physical_subject.kind === :physical_subject
    @test request.binding.design_alternative.kind === :design_alternative
    @test request.design.alternative isa SourceHardwareRefV1
    @test request.design.alternative.kind === :design_alternative
    constructor_guards = positive.constructor_guards
    @test String(constructor_guards.alternative_type) == "SourceHardwareRefV1"
    @test Symbol(constructor_guards.alternative_kind) === :design_alternative
    @test constructor_guards.rejects_bool === true
    @test constructor_guards.rejects_wrong_kind === true
    @test_throws SourceHardwareExternalInputError _shir_design_with_alternative(
        request.design, false)
    wrong_kind_alternative = _shir_test_ref(:candidate;
        suffix="wrong-alternative-kind")
    @test_throws SourceHardwareExternalInputError _shir_design_with_alternative(
        request.design, wrong_kind_alternative)
    @test request.design.candidate_hash == request.binding.candidate.ref_hash
    @test request.design.candidate_binding_hash == request.binding.binding_hash
    @test request.design.candidate_provenance_hash ==
        _shir_candidate_provenance_hash(request.binding.binding_hash,
            _shir_design_declaration_refs(request.design))
    @test request.design.target.kind === :target
    @test request.design.source.kind === :source
    @test request.design.coil.kind === :coil
    @test request.design.driver.kind === :driver
    @test request.design.return_ref.kind === :return_path
    @test request.design.material.kind === :material
    @test request.design.manufacturing.kind === :manufacturing
    @test request.design.cooling.kind === :cooling
    @test request.design.support.kind === :support
    @test request.design.control_fault.kind === :control_fault
    @test request.design.provider.kind === :provider
    @test request.design.solver.kind === :solver
    @test request.design.checker.kind === :checker
    @test request.design.target.unit === :W
    @test request.design.source.unit === :V
    @test request.design.coil.unit === :A
    @test request.design.driver.unit === :V
    @test request.design.return_ref.unit === :W
    @test request.design.target.port === :target
    @test request.design.source.port === :source
    @test request.design.coil.port === :coil
    @test request.design.driver.port === :driver
    @test request.design.return_ref.port === :return
    @test request.canonical_bytes_hash == digest256_text(request.canonical_bytes)

    @testset "deleted_return" begin
        design = _shir_test_design(_shir_test_binding(); absent=[:return_path])
        request = _shir_rebuild_request(_shir_test_binding(), design;
            request_ref="fixture.deleted_return", bytes="deleted-return")
        _shir_record_request_case!(negative_coverage, "deleted_return", design,
            request, validate_source_hardware_inverse_contract(request),
            :typed_absent, "return_path")
    end
    @testset "deleted_cooling" begin
        design = _shir_test_design(_shir_test_binding(); absent=[:cooling])
        request = _shir_rebuild_request(_shir_test_binding(), design;
            request_ref="fixture.deleted_cooling", bytes="deleted-cooling")
        _shir_record_request_case!(negative_coverage, "deleted_cooling", design,
            request, validate_source_hardware_inverse_contract(request),
            :typed_absent, "cooling")
    end
    @testset "deleted_material" begin
        design = _shir_test_design(_shir_test_binding(); absent=[:material])
        request = _shir_rebuild_request(_shir_test_binding(), design;
            request_ref="fixture.deleted_material", bytes="deleted-material")
        _shir_record_request_case!(negative_coverage, "deleted_material", design,
            request, validate_source_hardware_inverse_contract(request),
            :typed_absent, "material")
    end
    @testset "deleted_support" begin
        design = _shir_test_design(_shir_test_binding(); absent=[:support])
        request = _shir_rebuild_request(_shir_test_binding(), design;
            request_ref="fixture.deleted_support", bytes="deleted-support")
        _shir_record_request_case!(negative_coverage, "deleted_support", design,
            request, validate_source_hardware_inverse_contract(request),
            :typed_absent, "support")
    end
    provider_binding = _shir_test_binding()
    provider_design = _shir_test_design(provider_binding; absent=[:provider])
    provider_request = _shir_rebuild_request(provider_binding, provider_design;
        request_ref="fixture.provider_gap", bytes="provider-gap")
    _shir_record_request_case!(negative_coverage, "provider_gap", provider_design,
        provider_request, validate_source_hardware_inverse_contract(provider_request),
        :terminal_deferred, "provider_capability_gap")
    unknown_binding = _shir_test_binding()
    unknown_design = _shir_test_design(unknown_binding; unknown=[:material])
    unknown_request = _shir_rebuild_request(unknown_binding, unknown_design;
        request_ref="fixture.unknown_source_field", bytes="unknown-source-field")
    _shir_record_request_case!(negative_coverage, "unknown_source_field", unknown_design,
        unknown_request, validate_source_hardware_inverse_contract(unknown_request),
        :unknown, "material")

    binding = _shir_test_binding()
    valid_design = _shir_test_design(binding)
    for (label, mutation, reason) in (
            ("candidate_hash_mismatch", :candidate, "candidate_hash_mismatch"),
            ("g1_axis_mismatch", :g1, "g1_hash_mismatch"),
            ("g2_axis_mismatch", :g2, "g2_hash_mismatch"),
            ("g3_axis_mismatch", :g3, "g3_hash_mismatch"),
            ("four_axis_hash_mismatch", :axes, "version_axes_hash_mismatch"),
            ("parent_hash_mismatch", :parent, "parent_hash_mismatch"),
            ("mission_hash_mismatch", :mission, "mission_hash_mismatch"),
            ("scenario_hash_mismatch", :scenario, "scenario_hash_mismatch"),
            ("physical_subject_hash_mismatch", :physical_subject,
                "physical_subject_hash_mismatch"))
        mutation_design = _shir_identity_mutation(valid_design, mutation)
        request = _shir_rebuild_request(binding, mutation_design;
            request_ref="fixture.$label", bytes="mutated-$label")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :fail_closed
        @test reason in result.reasons
        @test result.request_hash == request.request_hash
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage, label, mutation_design, request,
            result, :fail_closed, reason)
    end

    target_bad_owner = _shir_test_ref(:target; suffix="target.bad_owner", port=:source)
    source_bad_owner = _shir_test_ref(:source; suffix="source.bad_owner", port=:target)
    coil_bad_owner = _shir_test_ref(:coil; suffix="coil.bad_owner", port=:target)
    return_bad_owner = _shir_test_ref(:return_path; suffix="return.bad_owner", port=:source)
    for (label, design, reason) in (
            ("target_port_mismatch", _shir_rebuild_design(valid_design;
                target=target_bad_owner), "target_port_mismatch"),
            ("source_port_mismatch", _shir_rebuild_design(valid_design;
                source=source_bad_owner), "source_port_mismatch"),
            ("coil_port_mismatch", _shir_rebuild_design(valid_design;
                coil=coil_bad_owner), "coil_port_mismatch"),
            ("return_port_mismatch", _shir_rebuild_design(valid_design;
                return_ref=return_bad_owner), "return_port_mismatch"),
            ("driver_port_mismatch", _shir_rebuild_design(valid_design;
                driver=_shir_test_ref(:driver; suffix="driver.bad_owner", port=:source)),
                "driver_port_mismatch"))
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.$label", bytes="mutated-$label")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :fail_closed
        @test reason in result.reasons
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage, label, design, request,
            result, :fail_closed, reason)
    end

    for (label, design, reason) in (
            ("target_unit_mismatch", _shir_rebuild_design(valid_design;
                target=_shir_test_ref(:target; suffix="target.bad_unit", unit=:A)),
                "target_unit_mismatch"),
            ("coil_unit_mismatch", _shir_rebuild_design(valid_design;
                coil=_shir_test_ref(:coil; suffix="coil.bad_unit", unit=:V)),
                "coil_unit_mismatch"),
            ("driver_unit_mismatch", _shir_rebuild_design(valid_design;
                driver=_shir_test_ref(:driver; suffix="driver.bad_unit", unit=:A)),
                "driver_unit_mismatch"),
            ("return_unit_mismatch", _shir_rebuild_design(valid_design;
                return_ref=_shir_test_ref(:return_path; suffix="return.bad_unit",
                    unit=:A)), "return_unit_mismatch"))
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.$label", bytes="mutated-$label")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :fail_closed
        @test reason in result.reasons
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage, label, design, request,
            result, :fail_closed, reason)
    end

    for (label, design, reason) in (
            ("foreign_candidate_binding", _shir_rebuild_design(valid_design;
                candidate_binding_hash=digest256_text("foreign-candidate-binding")),
                "candidate_binding_hash_mismatch"),
            ("stale_candidate_provenance", _shir_rebuild_design(valid_design;
                candidate_provenance_hash=digest256_text("stale-provenance")),
                "candidate_provenance_hash_mismatch"))
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.$label", bytes="mutated-$label")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :fail_closed
        @test reason in result.reasons
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage, label, design, request,
            result, :fail_closed, reason)
    end

    for (label, design, reason) in (
            ("port_unit_mismatch", _shir_rebuild_design(valid_design;
                return_ref=_shir_test_ref(:return_path; suffix="return.bad_port_unit", unit=:A)),
                "target_return_unit_mismatch"),
            ("port_domain_mismatch", _shir_rebuild_design(valid_design;
                return_ref=_shir_test_ref(:return_path; suffix="return.bad_port_domain",
                    domain="foreign-domain")), "target_return_domain_mismatch"),
            ("unit_mismatch", _shir_rebuild_design(valid_design;
                source=_shir_test_ref(:source; suffix="source.bad_unit", unit=:A)),
                "source_unit_mismatch"),
            ("source_domain_mismatch", _shir_rebuild_design(valid_design;
                source=_shir_test_ref(:source; suffix="source.bad_domain",
                    domain="foreign-domain")), "source_target_domain_mismatch"))
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.$label", bytes="mutated-$label")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :fail_closed
        @test reason in result.reasons
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage, label, design, request,
            result, :fail_closed, reason)
    end

    @testset "precedence_identity_over_typed_absent_and_provider_gap" begin
        design = _shir_rebuild_design(valid_design;
            candidate_hash=digest256_text("bad-precedence"),
            return_ref=_shir_test_ref(:return_path; status=:typed_absent,
                suffix="precedence.return", reason="deleted return"),
            provider=_shir_test_ref(:provider; status=:typed_absent,
                suffix="precedence.provider", reason="provider unavailable"))
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.precedence.identity", bytes="identity")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :fail_closed
        @test "candidate_hash_mismatch" in result.reasons
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage,
            "precedence_identity_over_typed_absent", design, request, result,
            :fail_closed, "candidate_hash_mismatch")
    end
    @testset "precedence_identity_over_unknown_and_provider_gap" begin
        design = _shir_rebuild_design(valid_design;
            g1_hash=digest256_text("bad-precedence-unknown"),
            material=_shir_test_ref(:material; status=:unknown,
                suffix="precedence.material", reason="material unresolved"),
            provider=_shir_test_ref(:provider; status=:typed_absent,
                suffix="precedence.provider.unknown", reason="provider unavailable"))
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.precedence.unknown", bytes="unknown")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :fail_closed
        @test "g1_hash_mismatch" in result.reasons
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage,
            "precedence_identity_over_unknown", design, request, result,
            :fail_closed, "g1_hash_mismatch")
    end
    @testset "precedence_typed_absent_over_provider_gap" begin
        binding = _shir_test_binding()
        design = _shir_test_design(binding; absent=[:return_path, :provider])
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.precedence.typed_absent", bytes="typed-absent")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :typed_absent
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage,
            "precedence_typed_absent_over_provider", design, request, result,
            :typed_absent, "return_path")
    end
    @testset "precedence_unknown_over_provider_gap" begin
        binding = _shir_test_binding()
        design = _shir_test_design(binding; unknown=[:material], absent=[:provider])
        request = _shir_rebuild_request(binding, design;
            request_ref="fixture.precedence.unknown", bytes="unknown")
        result = validate_source_hardware_inverse_contract(request)
        @test result.status == :unknown
        @test result.provider_calls == result.solver_calls == result.checker_calls == 0
        _shir_record_request_case!(negative_coverage,
            "precedence_unknown_over_provider", design, request, result,
            :unknown, "material")
    end

    provider_gap_status = classify_source_hardware_inverse_outcome(provider_match=:no_match)
    @test provider_gap_status == :terminal_deferred
    no_execution_status = classify_source_hardware_inverse_outcome(solver_exit=nothing)
    @test no_execution_status == :not_executed
    solver_exit_status = classify_source_hardware_inverse_outcome(solver_exit=4)
    @test solver_exit_status == :numerical_fail
    physical_gate_status = classify_source_hardware_inverse_outcome(solver_exit=0,
        physical_status=:fail)
    @test physical_gate_status == :physical_fail
    @test classify_source_hardware_inverse_outcome(solver_exit=0,
        physical_status=:unknown) == :unknown
    _shir_record_symbol_case!(negative_coverage, "no_execution_receipt", no_execution_status)
    _shir_record_symbol_case!(negative_coverage, "solver_exit_nonzero", solver_exit_status)
    _shir_record_symbol_case!(negative_coverage, "physical_gate_failed", physical_gate_status)

    admitted = admit_source_hardware_inverse_contract() do
        throw(SourceHardwareExternalInputError(:malformed_input, "bad fixture"))
    end
    @test admitted.status == :fail_closed
    @test admitted.provider_calls == admitted.solver_calls == admitted.checker_calls == 0

    expected_ids = Set(String(item.id) for item in fixture.negative)
    @test Set(keys(negative_coverage)) == expected_ids
    for item in fixture.negative
        label = String(item.id)
        @test haskey(negative_coverage, label)
        actual = negative_coverage[label]
        @test actual.status == String(item.expected_status)
        if item.expected_reason === nothing
            @test actual.reason === nothing
        else
            @test actual.reason == String(item.expected_reason)
        end
        @test actual.provider_calls == Int(fixture.expected_counters.provider_calls)
        @test actual.solver_calls == Int(fixture.expected_counters.solver_calls)
        @test actual.checker_calls == Int(fixture.expected_counters.checker_calls)
    end
end
