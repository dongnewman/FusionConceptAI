"""Source-bound scalar Fourier-Zernike geometry reconstruction, screen-only.

This is not a G2 coordinate/metric AST, physical solver, or provider adapter.
It preserves the exact selected DESC HDF5 interior subject and evaluates the
stored basis without converting the radial degree to a monomial power.
"""
module N2SourceFourierZernikeRuntime
using SHA
using JSON3
using FusionConceptAI: Digest256, screen_only

const _N2Z_SCHEMA = "n2-source-owned-interior-result-v1"
const _N2Z_SUBJECT_SCHEMA = "n2-source-owned-interior-subject-v1"
_n2z_sha(path::AbstractString) = Digest256(bytes2hex(SHA.sha256(read(path))))

struct N2ZernikeTermV4
    l::Int
    m::Int
    n::Int
    coefficient_m::Float64
    function N2ZernikeTermV4(l, m, n, coefficient_m)
        l isa Int && m isa Int && n isa Int && 0 <= l <= 24 &&
            abs(m) <= 12 && abs(n) <= 3 && l >= abs(m) &&
            iseven(l - abs(m)) ||
            throw(ArgumentError("N2 Fourier-Zernike mode is outside source basis"))
        coefficient_m isa Real && !(coefficient_m isa Bool) &&
            isfinite(Float64(coefficient_m)) ||
            throw(ArgumentError("N2 Fourier-Zernike coefficient is not finite"))
        new(l, m, n, Float64(coefficient_m))
    end
end

struct N2SourceInteriorV4
    source_artifact_sha256::Digest256
    result_sha256::Digest256
    subject_sha256::Digest256
    selected_equilibrium_index::Int
    field_periods::Int
    radial_modes::Tuple{Vararg{N2ZernikeTermV4}}
    vertical_modes::Tuple{Vararg{N2ZernikeTermV4}}
    claim_ceiling::typeof(screen_only)
    physical_validation::Bool
    provider_selected::Bool
    solver_executed::Bool
    credible_device_count::Int
end

function _n2z_modes(component, expected_count::Int, symmetry::String)
    component.basis_class == "desc.basis.FourierZernikeBasis" &&
        component.spectral_indexing == "fringe" &&
        component.symmetry == symmetry && component.coefficient_unit == "m" &&
        component.coefficient_count == expected_count &&
        length(component.terms) == expected_count ||
        throw(ArgumentError("N2 source Fourier-Zernike basis identity mismatch"))
    modes = Tuple(N2ZernikeTermV4(Int(term.l), Int(term.m),
        Int(term.n), Float64(term.coefficient_m)) for term in component.terms)
    length(Set((term.l, term.m, term.n) for term in modes)) == expected_count ||
        throw(ArgumentError("N2 source Fourier-Zernike modes are duplicated"))
    modes
end

"""Load only the exact source/member/wire/authority-bounded interior subject."""
function load_n2_source_interior(source_path::AbstractString,
        result_path::AbstractString, expected_result_sha256::Digest256)
    isfile(source_path) || throw(ArgumentError("N2 source HDF5 is missing"))
    isfile(result_path) || throw(ArgumentError("N2 source interior result is missing"))
    actual_result_sha = _n2z_sha(result_path)
    actual_result_sha == expected_result_sha256 ||
        throw(ArgumentError("N2 source interior result hash mismatch"))
    record = try
        JSON3.read(read(result_path, String))
    catch error
        throw(ArgumentError("N2 source interior JSON is invalid: $(error)"))
    end
    record.schema_version == _N2Z_SCHEMA &&
        record.status == "source_interior_spectral_representation_only" ||
        throw(ArgumentError("N2 source interior result schema/status mismatch"))
    wire = String(record.subject_canonical_json)
    wire_hash = Digest256(bytes2hex(SHA.sha256(codeunits(wire))))
    wire_hash == Digest256(String(record.subject_hash)) ||
        throw(ArgumentError("N2 source interior declared hash mismatch"))
    parsed = try
        JSON3.read(wire)
    catch error
        throw(ArgumentError("N2 source interior canonical wire is invalid: $(error)"))
    end
    parsed == record.subject ||
        throw(ArgumentError("N2 source interior wire/subject mismatch"))
    source_sha = _n2z_sha(source_path)
    subject = parsed
    subject.schema_version == _N2Z_SUBJECT_SCHEMA &&
        subject.source_class == "external_simulation" &&
        subject.source_artifact_sha256 == source_sha.value &&
        subject.selected_equilibrium_index == 3 &&
        subject.equilibrium_count == 4 &&
        subject.embedded_producer_version == "0.17.1+38.g53ea59ef0.dirty" &&
        subject.distribution_tag == "v0.17.3" ||
        throw(ArgumentError("N2 source member/provenance identity mismatch"))
    resolution = subject.source_resolution
    resolution.L == 24 && resolution.M == 12 && resolution.N == 3 &&
        resolution.NFP == 19 ||
        throw(ArgumentError("N2 source interior resolution mismatch"))
    authority = record.authority
    authority.evidence_authority == "external_simulation_input_only" &&
        authority.physical_validation == "unsupported" &&
        authority.independent_solver == false &&
        authority.measurement == false && authority.inverse_ready == false &&
        authority.held_out_prediction_ready == false &&
        authority.credible_device_count == 0 ||
        throw(ArgumentError("N2 source interior authority ceiling exceeded"))
    radial = _n2z_modes(subject.R, 598, "cos")
    vertical = _n2z_modes(subject.Z, 585, "sin")
    N2SourceInteriorV4(source_sha, actual_result_sha, wire_hash, 3, 19,
        radial, vertical, screen_only, false, false, false, 0)
end

function _n2z_jacobi(order::Int, alpha::Int, x::Float64)
    order == 0 && return 1.0
    previous = 1.0
    current = 0.5 * (alpha + (alpha + 2) * x)
    order == 1 && return current
    for k in 1:(order - 1)
        a1 = 2.0 * (k + 1) * (k + alpha + 1) * (2k + alpha)
        a2 = (2k + alpha + 1) * alpha^2
        a3 = (2k + alpha) * (2k + alpha + 1) * (2k + alpha + 2)
        a4 = 2.0 * (k + alpha) * k * (2k + alpha + 2)
        next = ((a2 + a3 * x) * current - a4 * previous) / a1
        previous, current = current, next
    end
    current
end

function _n2z_radial(term::N2ZernikeTermV4, rho::Float64)
    m = abs(term.m)
    order = (term.l - m) ÷ 2
    isodd(order) ? -rho^m * _n2z_jacobi(order, m, 1 - 2rho^2) :
        rho^m * _n2z_jacobi(order, m, 1 - 2rho^2)
end
_n2z_fourier(angle::Float64, mode::Int, nfp::Int=1) =
    mode >= 0 ? cos(abs(mode) * nfp * angle) :
        sin(abs(mode) * nfp * angle)

function _n2z_eval(modes, rho::Float64, theta::Float64,
        zeta::Float64, nfp::Int)
    sum(term.coefficient_m * _n2z_radial(term, rho) *
        _n2z_fourier(theta, term.m) * _n2z_fourier(zeta, term.n, nfp)
        for term in modes)
end

"""Evaluate source R/Z at physical DESC radians; no metric or derivative claim."""
function evaluate_n2_source_rz(interior::N2SourceInteriorV4,
        rho::Real, theta::Real, zeta::Real)
    all(value -> !(value isa Bool) && isfinite(Float64(value)),
        (rho, theta, zeta)) && 0 <= rho <= 1 ||
        throw(ArgumentError("N2 source chart requires finite angles and rho in [0,1]"))
    r = Float64(rho); t = Float64(theta); z = Float64(zeta)
    (_n2z_eval(interior.radial_modes, r, t, z, interior.field_periods),
     _n2z_eval(interior.vertical_modes, r, t, z, interior.field_periods))
end

n2_source_interior_manifest() = (
    source_class=:external_simulation,
    representation=:source_owned_fourier_zernike,
    claim_ceiling=screen_only,
    typed_G2_coordinate_metric_program=false,
    derivative_or_metric_proof=false,
    provider_selected=false,
    solver_executed=false,
    physical_validation=false,
    credible_device_count=0)
end
