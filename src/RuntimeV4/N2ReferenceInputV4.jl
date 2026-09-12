"""Hash-bound, screen-only N2 external-reference input binding.

The binding joins a frozen source artifact, a normalized-result artifact, its
declared subject hash, and an exactly matching typed boundary/profile
declaration in the current G2 candidate. It deliberately retains the missing
interior-coordinate and provider-compatibility gaps. It does not select or
execute a provider and cannot emit physical evidence.
"""
module N2ReferenceInputRuntime
using SHA
using JSON3
using FusionConceptAI
import FusionConceptAI: Digest256, canonical_hash, semantic_view, screen_only

const _N2R_REVISION = "runtime-v4-n2-reference-input-v2"
const _N2R_SCHEMA = "fusionconceptai:runtime-v4-n2-reference-input"

_n2r_sha(path::AbstractString) = Digest256(bytes2hex(SHA.sha256(read(path))))
function _n2r_hash(value)
    try
        canonical_hash(value)
    catch
        owner = parentmodule(typeof(value))
        isdefined(owner, :canonical_hash) || rethrow()
        getproperty(owner, :canonical_hash)(value)
    end
end
function _n2r_require(value, key::Symbol)
    hasproperty(value, key) || throw(ArgumentError("N2 normalized subject missing $(key)"))
    getproperty(value, key)
end
_n2r_tuple(value, field::String) = value isa Tuple && !(value isa NamedTuple) ?
    value : throw(ArgumentError("$field must be an immutable tuple"))

function _n2r_subject_payload(subject)
    keys = (:schema_version, :source_class, :source_artifact_sha256,
        :provenance, :field_periods, :stellarator_symmetric, :boundary,
        :pressure_profile, :rotational_or_current_profile, :toroidal_flux,
        :source_resolution)
    all(hasproperty(subject, key) for key in keys) ||
        throw(ArgumentError("N2 normalized subject is incomplete"))
    NamedTuple{keys}(Tuple(getproperty(subject, key) for key in keys))
end
_n2r_subject_hash(subject) = canonical_hash(_n2r_subject_payload(subject))

function _n2r_modes_from_json(rows)
    Tuple((m=Int(row.m), n=Int(row.n),
        coefficient_m=Float64(row.coefficient_m)) for row in rows)
end

function _n2r_profile_from_json(profile)
    (quantity=String(profile.quantity), unit=String(profile.unit),
     basis=String(profile.basis),
     radial_domain=Tuple(Float64(value) for value in profile.radial_domain),
     coefficients_by_power=Tuple(Float64(value) for value in
        profile.coefficients_by_power),
     uniform_pointwise_error_bound=Float64(
        profile.uniform_pointwise_error_bound))
end

function _n2r_subject_from_json(source)
    provenance = source.provenance
    boundary = source.boundary
    resolution = source.source_resolution
    (schema_version=String(source.schema_version),
     source_class=String(source.source_class),
     source_artifact_sha256=String(source.source_artifact_sha256),
     provenance=(
        distributed_in_release_tag=String(provenance.distributed_in_release_tag),
        distribution_tag_commit=String(provenance.distribution_tag_commit),
        embedded_producer_version=String(provenance.embedded_producer_version),
        loader_runtime_version=String(provenance.loader_runtime_version),
        equilibrium_count=Int(provenance.equilibrium_count),
        selected_equilibrium_index=Int(provenance.selected_equilibrium_index)),
     field_periods=Int(source.field_periods),
     stellarator_symmetric=Bool(source.stellarator_symmetric),
     boundary=(coordinate_system=String(boundary.coordinate_system),
        coefficient_unit=String(boundary.coefficient_unit),
        radial_modes=_n2r_modes_from_json(boundary.radial_modes),
        vertical_modes=_n2r_modes_from_json(boundary.vertical_modes),
        uniform_pointwise_error_bound_m=(
            R=Float64(boundary.uniform_pointwise_error_bound_m.R),
            Z=Float64(boundary.uniform_pointwise_error_bound_m.Z),
            RZ_euclidean=Float64(
                boundary.uniform_pointwise_error_bound_m.RZ_euclidean))),
     pressure_profile=_n2r_profile_from_json(source.pressure_profile),
     rotational_or_current_profile=_n2r_profile_from_json(
        source.rotational_or_current_profile),
     toroidal_flux=(value=Float64(source.toroidal_flux.value),
        unit=String(source.toroidal_flux.unit)),
     source_resolution=(L=Int(resolution.L), M=Int(resolution.M),
        N=Int(resolution.N), L_grid=Int(resolution.L_grid),
        M_grid=Int(resolution.M_grid), N_grid=Int(resolution.N_grid)))
end

function _n2r_load_normalized_result(path::AbstractString,
        expected_sha256::Digest256)
    isfile(path) || throw(ArgumentError("N2 normalized result is missing"))
    _n2r_sha(path) == expected_sha256 ||
        throw(ArgumentError("N2 normalized result hash mismatch"))
    record = try
        JSON3.read(read(path, String))
    catch error
        throw(ArgumentError("N2 normalized result JSON is invalid: $(error)"))
    end
    hasproperty(record, :schema_version) &&
        record.schema_version == "n2-normalized-reference-v2" ||
        throw(ArgumentError("N2 normalized result schema mismatch"))
    hasproperty(record, :status) &&
        record.status == "normalized_external_simulation_input" ||
        throw(ArgumentError("N2 normalized result status mismatch"))
    hasproperty(record, :subject_canonical_json) &&
        hasproperty(record, :subject_hash) && hasproperty(record, :subject) ||
        throw(ArgumentError("N2 normalized result subject receipt is incomplete"))
    wire = String(record.subject_canonical_json)
    wire_sha256 = Digest256(bytes2hex(SHA.sha256(codeunits(wire))))
    wire_sha256 == Digest256(String(record.subject_hash)) ||
        throw(ArgumentError("N2 normalized result declared subject hash mismatch"))
    parsed_subject = try
        JSON3.read(wire)
    catch error
        throw(ArgumentError("N2 canonical subject JSON is invalid: $(error)"))
    end
    parsed_subject == record.subject ||
        throw(ArgumentError("N2 normalized result subject/canonical wire mismatch"))
    authority = hasproperty(record, :authority) ? record.authority : nothing
    authority !== nothing &&
        authority.physical_validation == "unsupported" &&
        authority.independent_solver == false && authority.measurement == false &&
        authority.inversion_ready == false &&
        authority.held_out_prediction_ready == false &&
        authority.credible_device_count == 0 ||
        throw(ArgumentError("N2 normalized result authority ceiling exceeded"))
    _n2r_subject_from_json(parsed_subject), wire_sha256
end

function _n2r_finite_nonnegative(value, field::String)
    value isa Real && !(value isa Bool) && isfinite(Float64(value)) && value >= 0 ||
        throw(ArgumentError("$field must be finite and nonnegative"))
    Float64(value)
end

function _n2r_validate_provenance(subject)
    provenance = _n2r_require(subject, :provenance)
    for key in (:distributed_in_release_tag, :distribution_tag_commit,
            :embedded_producer_version, :loader_runtime_version,
            :equilibrium_count, :selected_equilibrium_index)
        _n2r_require(provenance, key)
    end
    count = provenance.equilibrium_count
    selected = provenance.selected_equilibrium_index
    count isa Int && selected isa Int && count > 0 && 0 <= selected < count ||
        throw(ArgumentError("N2 selected equilibrium provenance is invalid"))
    nothing
end

function _n2r_subject_modes(boundary, component::Symbol)
    rows = _n2r_tuple(_n2r_require(boundary, component),
        "N2 boundary $(component)")
    Tuple(begin
        m = _n2r_require(row, :m)
        n = _n2r_require(row, :n)
        coefficient = _n2r_require(row, :coefficient_m)
        m isa Int && n isa Int || throw(ArgumentError("N2 Fourier modes must be Int"))
        coefficient isa Real && !(coefficient isa Bool) && isfinite(Float64(coefficient)) ||
            throw(ArgumentError("N2 Fourier coefficients must be finite"))
        (m=m, n=n, coefficient_m=Float64(coefficient))
    end for row in rows)
end

function _n2r_input_modes(boundary, component::Symbol)
    coefficients = component === :radial_modes ? boundary.radial_coefficients :
        boundary.vertical_coefficients
    Tuple((m=value.poloidal_mode, n=value.toroidal_mode,
        coefficient_m=value.coefficient_m) for value in coefficients)
end

function _n2r_validate_subject_and_input(subject, input,
        artifact_sha256::Digest256)
    _n2r_require(subject, :schema_version) ==
        "n2-label-neutral-equilibrium-subject-v1" ||
        throw(ArgumentError("N2 normalized subject schema mismatch"))
    _n2r_require(subject, :source_class) == "external_simulation" ||
        throw(ArgumentError("N2 source must remain external_simulation"))
    _n2r_require(subject, :source_artifact_sha256) == artifact_sha256.value ||
        throw(ArgumentError("N2 subject/source artifact hash mismatch"))
    _n2r_validate_provenance(subject)

    boundary = _n2r_require(subject, :boundary)
    pressure = _n2r_require(subject, :pressure_profile)
    rotational = _n2r_require(subject, :rotational_or_current_profile)
    flux = _n2r_require(subject, :toroidal_flux)
    source_resolution = _n2r_require(subject, :source_resolution)
    radial = _n2r_subject_modes(boundary, :radial_modes)
    vertical = _n2r_subject_modes(boundary, :vertical_modes)
    boundary.coordinate_system == "cylindrical_R_phi_Z" &&
        boundary.coefficient_unit == "m" ||
        throw(ArgumentError("N2 boundary coordinate system or unit mismatch"))
    length(unique((row.m, row.n) for row in radial)) == length(radial) &&
        length(unique((row.m, row.n) for row in vertical)) == length(vertical) ||
        throw(ArgumentError("N2 Fourier modes must be unique per component"))
    pressure_coefficients = _n2r_tuple(
        _n2r_require(pressure, :coefficients_by_power),
        "N2 pressure coefficients")
    rotational_coefficients = _n2r_tuple(
        _n2r_require(rotational, :coefficients_by_power),
        "N2 rotational/current coefficients")
    all(value -> value isa Real && !(value isa Bool) && isfinite(Float64(value)),
        pressure_coefficients) || throw(ArgumentError("N2 pressure coefficients must be finite"))
    all(value -> value isa Real && !(value isa Bool) && isfinite(Float64(value)),
        rotational_coefficients) || throw(ArgumentError("N2 rotational/current coefficients must be finite"))
    pressure.quantity == "pressure" && pressure.unit == "Pa" ||
        throw(ArgumentError("N2 pressure ownership or unit mismatch"))
    rotational.quantity in ("iota", "current") ||
        throw(ArgumentError("N2 requires exactly one iota/current profile"))
    rotational.unit == (rotational.quantity == "iota" ? "1" : "A") ||
        throw(ArgumentError("N2 rotational/current unit mismatch"))
    pressure.basis == "power_series_in_rho" &&
        rotational.basis == "power_series_in_rho" &&
        pressure.radial_domain == (0.0, 1.0) &&
        rotational.radial_domain == (0.0, 1.0) ||
        throw(ArgumentError("N2 profile basis or radial domain mismatch"))
    flux.unit == "Wb" && flux.value isa Real && !(flux.value isa Bool) &&
        isfinite(Float64(flux.value)) && flux.value != 0 ||
        throw(ArgumentError("N2 toroidal flux is invalid"))
    _n2r_finite_nonnegative(pressure.uniform_pointwise_error_bound,
        "N2 pressure truncation bound")
    _n2r_finite_nonnegative(rotational.uniform_pointwise_error_bound,
        "N2 rotational/current truncation bound")
    bounds = _n2r_require(boundary, :uniform_pointwise_error_bound_m)
    for key in (:R, :Z, :RZ_euclidean)
        _n2r_finite_nonnegative(_n2r_require(bounds, key),
            "N2 boundary truncation bound $(key)")
    end

    hasproperty(input, :fourier_boundary) && hasproperty(input, :profiles_flux) ||
        throw(ArgumentError("N2 input is not a typed 3-D physical input"))
    typed_boundary = input.fourier_boundary
    typed_profiles = input.profiles_flux
    typed_boundary.field_periods == subject.field_periods &&
        typed_boundary.stellarator_symmetric == subject.stellarator_symmetric ||
        throw(ArgumentError("N2 typed boundary period/symmetry mismatch"))
    _n2r_input_modes(typed_boundary, :radial_modes) == radial &&
        _n2r_input_modes(typed_boundary, :vertical_modes) == vertical ||
        throw(ArgumentError("N2 typed Fourier boundary mismatch"))
    typed_profiles.pressure.coefficients == Tuple(Float64(x) for x in pressure_coefficients) ||
        throw(ArgumentError("N2 typed pressure profile mismatch"))
    typed_profiles.rotational_or_current.quantity == Symbol(rotational.quantity) &&
        typed_profiles.rotational_or_current.coefficients ==
            Tuple(Float64(x) for x in rotational_coefficients) ||
        throw(ArgumentError("N2 typed rotational/current profile mismatch"))
    typed_profiles.toroidal_flux_wb == Float64(flux.value) ||
        throw(ArgumentError("N2 typed toroidal flux mismatch"))

    gaps = String[
        "source_owned_fourier_zernike_interior_not_normalized_or_bound",
        "current_single_power_geometry_program_cannot_represent_source_fourier_zernike_basis",
        "candidate_coordinate_metric_program_not_bound_to_source_interior",
    ]
    subject.field_periods in 2:8 ||
        push!(gaps, "desc_interpreter_field_periods_outside_2_to_8")
    radial_base = Tuple(row for row in radial if row.m == 1 && row.n == 0)
    vertical_base = Tuple(row for row in vertical if row.n == 0)
    (length(radial_base) == 1 && only(radial_base).coefficient_m > 0) ||
        push!(gaps, "desc_radial_base_orientation_proof_mismatch")
    (length(vertical_base) == 1 &&
        only(vertical_base).m * only(vertical_base).coefficient_m > 0) ||
        push!(gaps, "desc_vertical_base_orientation_proof_mismatch")
    _n2r_require(source_resolution, :L) <= 12 ||
        push!(gaps, "desc_fixed_boundary_L_outside_0_to_12")
    rotational.quantity == "iota" ||
        push!(gaps, "desc_current_profile_capability_missing")
    Tuple(gaps), Symbol(rotational.quantity)
end

struct N2ReferenceInputBindingV4
    source_artifact_path::String
    source_artifact_sha256::Digest256
    normalized_result_path::String
    normalized_result_sha256::Digest256
    normalized_result_subject_sha256::Digest256
    typed_subject_projection_hash::Digest256
    candidate_hash::Digest256
    context_hash::Digest256
    declaration_hash::Digest256
    profile_quantity::Symbol
    desc_compatibility::Symbol
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    measurement::Bool
    inverse_ready::Bool
    held_out_prediction_ready::Bool
    physical_validation::Bool
    p5_ready::Bool
    credible_physical_device_count::Int
    binding_hash::Digest256
end

function _n2r_body(value)
    (revision=_N2R_REVISION, schema=_N2R_SCHEMA,
     source_artifact_sha256=value.source_artifact_sha256,
     normalized_result_sha256=value.normalized_result_sha256,
     normalized_result_subject_sha256=value.normalized_result_subject_sha256,
     typed_subject_projection_hash=value.typed_subject_projection_hash,
     candidate_hash=value.candidate_hash, context_hash=value.context_hash,
     declaration_hash=value.declaration_hash,
     profile_quantity=value.profile_quantity,
     desc_compatibility=:recoverable_gap,
     recoverable_gaps=value.recoverable_gaps, claim_ceiling=screen_only,
     measurement=false, inverse_ready=false, held_out_prediction_ready=false,
     physical_validation=false, p5_ready=false,
     credible_physical_device_count=0)
end
semantic_view(value::N2ReferenceInputBindingV4) = _n2r_body(value)
function canonical_hash(value::N2ReferenceInputBindingV4)
    value.desc_compatibility === :recoverable_gap &&
        !isempty(value.recoverable_gaps) &&
        value.claim_ceiling === screen_only && !value.measurement &&
        !value.inverse_ready && !value.held_out_prediction_ready &&
        !value.physical_validation && !value.p5_ready &&
        value.credible_physical_device_count == 0 ||
        throw(ArgumentError("N2 authority or compatibility ceiling exceeded"))
    expected = canonical_hash(_n2r_body(value))
    expected == value.binding_hash || throw(ArgumentError("N2 binding hash mismatch"))
    expected
end

"""Bind exact external boundary/profile fields while preserving every known gap."""
function bind_n2_reference_input(context, input,
        source_artifact_path::AbstractString,
        source_artifact_sha256::Digest256,
        normalized_result_path::AbstractString,
        normalized_result_sha256::Digest256; validator=nothing)
    validator === nothing || validator(context)
    isfile(source_artifact_path) || throw(ArgumentError("N2 source artifact is missing"))
    _n2r_sha(source_artifact_path) == source_artifact_sha256 ||
        throw(ArgumentError("N2 source artifact hash mismatch"))
    normalized_subject, normalized_result_subject_sha256 =
        _n2r_load_normalized_result(normalized_result_path,
            normalized_result_sha256)
    gaps, profile_quantity = _n2r_validate_subject_and_input(
        normalized_subject, input, source_artifact_sha256)
    typed_subject_hash = _n2r_subject_hash(normalized_subject)
    declaration_hash = _n2r_hash(input)
    fields = context.candidate.field_geometry_genome_ref.fields
    matches = Tuple(value for value in fields
        if nameof(typeof(value)) === :ThreeDPhysicalProviderInputV4 &&
           _n2r_hash(value) == declaration_hash)
    length(matches) == 1 ||
        throw(ArgumentError("N2 declaration is absent or ambiguous in current context"))
    body = (revision=_N2R_REVISION, schema=_N2R_SCHEMA,
        source_artifact_sha256=source_artifact_sha256,
        normalized_result_sha256=normalized_result_sha256,
        normalized_result_subject_sha256=normalized_result_subject_sha256,
        typed_subject_projection_hash=typed_subject_hash,
        candidate_hash=context.candidate_hash, context_hash=context.context_hash,
        declaration_hash=declaration_hash, profile_quantity=profile_quantity,
        desc_compatibility=:recoverable_gap, recoverable_gaps=gaps,
        claim_ceiling=screen_only, measurement=false, inverse_ready=false,
        held_out_prediction_ready=false, physical_validation=false,
        p5_ready=false, credible_physical_device_count=0)
    N2ReferenceInputBindingV4(String(source_artifact_path),
        source_artifact_sha256, String(normalized_result_path),
        normalized_result_sha256, normalized_result_subject_sha256,
        typed_subject_hash, context.candidate_hash, context.context_hash,
        declaration_hash, profile_quantity, :recoverable_gap, gaps,
        screen_only, false, false, false, false, false, 0,
        canonical_hash(body))
end

n2_reference_input_manifest() = (
    revision=_N2R_REVISION, schema=_N2R_SCHEMA, claim_ceiling=screen_only,
    implemented_status=:recoverable_gap, provider_selected=false,
    provider_executed=false, solver_executed=false, emits_evidence=false,
    measurement=false, inverse_ready=false, held_out_prediction_ready=false,
    physical_validation=false, p5_ready=false,
    credible_physical_device_count=0)
end
