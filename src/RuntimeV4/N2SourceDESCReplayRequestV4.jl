# Candidate-bound, source-basis DESC replay request; no solver/evidence credit.
# Include after N2SourceGeometryCandidateBindingV4.jl. This additive capability
# does not alter the old monomial DESC certificate or default registry.
using SHA
using JSON3
import FusionConceptAI: canonical_hash, semantic_view

const _N2SR_SCHEMA = "fusionconceptai:runtime-v4-n2-source-desc-replay-request"
const _N2SR_REVISION = "v1"
const _N2SR_CODE_SHA = Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))
struct _N2SRToken end
const _N2SR_TOKEN = _N2SRToken()
_n2sr_sha(path::AbstractString) = Digest256(bytes2hex(SHA.sha256(read(path))))

struct N2SourceDESCReplayControlsV4
    maxiter::Int
    ftol::Float64
    xtol::Float64
    gtol::Float64
    function N2SourceDESCReplayControlsV4(maxiter, ftol, xtol, gtol)
        maxiter isa Integer && !(maxiter isa Bool) && 1 <= maxiter <= 1000 ||
            throw(ArgumentError("DESC replay maxiter must be in 1:1000"))
        tolerances = (ftol, xtol, gtol)
        all(x -> x isa Real && !(x isa Bool) && isfinite(Float64(x)) &&
            Float64(x) > 0, tolerances) ||
            throw(ArgumentError("DESC replay tolerances must be finite and positive"))
        new(Int(maxiter), Float64(ftol), Float64(xtol), Float64(gtol))
    end
end
semantic_view(x::N2SourceDESCReplayControlsV4) = (
    optimizer="lsq-exact", objective="force", maxiter=x.maxiter,
    ftol=x.ftol, xtol=x.xtol, gtol=x.gtol)

struct N2SourceDESCReplayRequestV4
    payload::NamedTuple
    request_hash::Digest256
    function N2SourceDESCReplayRequestV4(::_N2SRToken, payload::NamedTuple)
        new(payload, canonical_hash(payload))
    end
end
semantic_view(request::N2SourceDESCReplayRequestV4) = request.payload
function canonical_hash(request::N2SourceDESCReplayRequestV4)
    request.payload.schema_version == _N2SR_SCHEMA &&
        request.payload.revision == _N2SR_REVISION &&
        request.payload.request_builder_sha256 == _N2SR_CODE_SHA.value &&
        request.payload.authority == (
            claim_ceiling="screen_only", geometry_proved=false,
            provider_executed=false, physical_validation="unsupported",
            credible_device_count=0) &&
        canonical_hash(request.payload) == request.request_hash ||
        throw(ArgumentError("source DESC replay request identity or authority changed"))
    request.request_hash
end

function _n2sr_member_receipt(path::AbstractString, expected_sha::Digest256,
        source_binding, reference_binding)
    isfile(path) && _n2sr_sha(path) == expected_sha ||
        throw(ArgumentError("source member-join receipt bytes differ"))
    receipt = JSON3.read(read(path, String))
    validator_path = normpath(joinpath(@__DIR__, "..", "..", "benchmarks",
        "desc_heliotron_v0173", "validate_member_join.py"))
    isfile(validator_path) &&
        receipt.validator_script_sha256 == _n2sr_sha(validator_path).value &&
        receipt.status == "screen_only_raw_member_join_verified" &&
        receipt.source_artifact_sha256 ==
            source_binding.program.interior.source_artifact_sha256.value &&
        receipt.normalized_result_sha256 ==
            reference_binding.normalized_result_sha256.value &&
        receipt.interior_result_sha256 ==
            source_binding.program.interior.result_sha256.value &&
        receipt.selected_equilibrium_index == 3 &&
        receipt.equilibrium_count == 4 &&
        receipt.resolution.L == 24 && receipt.resolution.M == 12 &&
        receipt.resolution.N == 3 && receipt.resolution.NFP == 19 &&
        Set(String.(keys(receipt.authority))) == Set((
            "claim_ceiling", "credible_device_count", "geometry_proved",
            "inverse_ready", "measurement", "physical_validation")) &&
        receipt.authority.claim_ceiling == "screen_only" &&
        receipt.authority.physical_validation == "unsupported" &&
        receipt.authority.geometry_proved == false &&
        receipt.authority.measurement == false &&
        receipt.authority.inverse_ready == false &&
        receipt.authority.credible_device_count == 0 ||
        throw(ArgumentError("source member-join receipt does not cover this input"))
    tolerance = Float64(receipt.numerical_join_tolerance_m)
    isfinite(tolerance) && tolerance >= 0 &&
        all(value -> value isa Real && isfinite(Float64(value)) &&
            0 <= Float64(value) <= tolerance,
            values(receipt.numeric_maxima_m)) ||
        throw(ArgumentError("source member-join numerical bounds are invalid"))
    receipt
end

"""Build exact candidate-owned source replay input without proof promotion."""
function make_n2_source_desc_replay_request(
        context::ForwardChainContextV4,
        binding::N2SourceCandidateGeometryBindingV4,
        source_binding::N2SourceGeometryProgramRuntime.N2SourceGeometryBindingV4,
        reference_binding::N2ReferenceInputRuntime.N2ReferenceInputBindingV4,
        bridge::ThreeDNormalizedPhysicalRootBridgeResolutionV4,
        source_path::AbstractString, interior_result_path::AbstractString,
        member_receipt_path::AbstractString, member_receipt_sha::Digest256,
        controls::N2SourceDESCReplayControlsV4)
    canonical_hash(binding)
    fresh = bind_n2_source_candidate_geometry(context, source_binding,
        reference_binding, bridge, source_path, interior_result_path)
    canonical_hash(fresh) == binding.binding_hash &&
        semantic_view(fresh) == semantic_view(binding) ||
        throw(ArgumentError("source DESC replay candidate binding changed"))
    _n2sr_member_receipt(member_receipt_path, member_receipt_sha,
        source_binding, reference_binding)
    subject, subject_hash = N2ReferenceInputRuntime._n2r_load_normalized_result(
        reference_binding.normalized_result_path,
        reference_binding.normalized_result_sha256)
    subject_hash == reference_binding.normalized_result_subject_sha256 &&
        _n2gc_same_source_resolution(subject, source_binding.program.interior) &&
        subject.rotational_or_current_profile.quantity == "iota" &&
        subject.stellarator_symmetric == true &&
        subject.toroidal_flux.unit == "Wb" ||
        throw(ArgumentError("source DESC replay physical subject is not admitted"))
    resolution = subject.source_resolution
    resolution.L_grid >= resolution.L &&
        resolution.M_grid >= resolution.M &&
        resolution.N_grid >= resolution.N ||
        throw(ArgumentError("source DESC replay grid underresolves stored basis"))
    boundary = subject.boundary
    R_modes = Tuple((m=Int(row.m), n=Int(row.n),
        coefficient_m=Float64(row.coefficient_m)) for row in boundary.radial_modes)
    Z_modes = Tuple((m=Int(row.m), n=Int(row.n),
        coefficient_m=Float64(row.coefficient_m)) for row in boundary.vertical_modes)
    pressure = Tuple(Float64(x) for x in
        subject.pressure_profile.coefficients_by_power)
    iota = Tuple(Float64(x) for x in
        subject.rotational_or_current_profile.coefficients_by_power)
    all(iszero(pressure[i]) for i in 2:2:length(pressure)) &&
        all(iszero(iota[i]) for i in 2:2:length(iota)) ||
        throw(ArgumentError("source DESC replay requires even radial profiles"))
    payload = (
        schema_version=_N2SR_SCHEMA, revision=_N2SR_REVISION,
        request_builder_sha256=_N2SR_CODE_SHA.value,
        candidate_hash=context.candidate_hash.value,
        context_hash=context.context_hash.value,
        physical_subject_hash=context.subject.physical_subject_hash.value,
        candidate_geometry_binding_hash=binding.binding_hash.value,
        source_geometry_program_hash=canonical_hash(source_binding.program).value,
        source_artifact_path=abspath(source_path),
        source_artifact_sha256=source_binding.program.interior.source_artifact_sha256.value,
        source_manifest_path=abspath(joinpath(dirname(source_path), "source.json")),
        interior_result_path=abspath(interior_result_path),
        interior_result_sha256=source_binding.program.interior.result_sha256.value,
        normalized_result_path=abspath(reference_binding.normalized_result_path),
        normalized_result_sha256=reference_binding.normalized_result_sha256.value,
        member_join_receipt_path=abspath(member_receipt_path),
        member_join_receipt_sha256=member_receipt_sha.value,
        selected_equilibrium_index=source_binding.program.interior.selected_equilibrium_index,
        source_basis=(class="desc.basis.FourierZernikeBasis",
            indexing="fringe", R_symmetry="cos", Z_symmetry="sin"),
        surface_basis=(class="desc.basis.DoubleFourierSeries",
            indexing="linear", R_symmetry="cos", Z_symmetry="sin"),
        profile_basis=(class="desc.profiles.PowerSeriesProfile",
            symmetry="even", coordinate="rho", pressure_unit="Pa",
            iota_unit="1"),
        field_periods=Int(subject.field_periods),
        resolution=(L=Int(resolution.L), M=Int(resolution.M),
            N=Int(resolution.N), L_grid=Int(resolution.L_grid),
            M_grid=Int(resolution.M_grid), N_grid=Int(resolution.N_grid)),
        boundary=(R_modes=R_modes, Z_modes=Z_modes),
        pressure_coefficients=pressure,
        iota_coefficients=iota,
        toroidal_flux_wb=Float64(subject.toroidal_flux.value),
        controls=semantic_view(controls),
        authority=(claim_ceiling="screen_only", geometry_proved=false,
            provider_executed=false, physical_validation="unsupported",
            credible_device_count=0))
    request = N2SourceDESCReplayRequestV4(_N2SR_TOKEN, payload)
    canonical_hash(request)
    request
end

function write_n2_source_desc_replay_request(request::N2SourceDESCReplayRequestV4,
        output_path::AbstractString)
    canonical_hash(request)
    isfile(output_path) && throw(ArgumentError("refusing to overwrite source replay request"))
    mkpath(dirname(output_path))
    isfile(output_path) && throw(ArgumentError("refusing to overwrite source replay request"))
    open(output_path, "w") do io
        JSON3.pretty(io, merge(request.payload,
            (request_hash=request.request_hash.value,)))
        println(io)
    end
    _n2sr_sha(output_path)
end
