"""Candidate-bound tensor-quadrature observation of DESC's static-MHD force.

This edge executes the accepted DESC field and Cartesian-basis providers at
two radial Gauss nodes and two midpoint nodes in each angular coordinate for
every declared rho region. It integrates `F * sqrt(g)` over the full torus.
The result is an observation only: it has no test function, boundary term,
weak form, residual/Jacobian, conservation, convergence, or closure authority.
"""

using FusionConceptAI
using SHA
using LinearAlgebra
import FusionConceptAI: ClaimCeiling, Digest256, canonical_hash, semantic_view

const _DRIFO_REVISION = "runtime-v4-desc-regional-integrated-force-observation-v1"
const _DRIFO_SCHEMA = "fusionconceptai:runtime-v4-desc-regional-integrated-force-observation"
const _DRIFO_OUTPUT_SCHEMA = "fusionconceptai:runtime-v4-desc-regional-integrated-force-observation-output"
const _DRIFO_TOKEN = Val(:desc_regional_integrated_force_observation_private)
const _DRIFO_SOURCE_PATH = abspath(@__FILE__)

_drifo_sha256(path::AbstractString) =
    Digest256(bytes2hex(SHA.sha256(read(path))))

struct DESCRegionalForceQuadratureNodeV4
    region_id::String
    region_hash::Digest256
    region_support_hash::Digest256
    local_index::NTuple{3,Int}
    point::DESCFieldSamplePointV4
    rho_weight::Float64
    theta_weight::Float64
    zeta_weight::Float64
    nfp_multiplier::Int
    full_torus_weight::Float64
    node_hash::Digest256
    function DESCRegionalForceQuadratureNodeV4(
            token::Val{:desc_regional_integrated_force_observation_private}, fields...)
        token === _DRIFO_TOKEN || throw(ArgumentError("private quadrature node constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCRegionalForceQuadratureNodeV4) = (
    region_id=x.region_id, region_hash=x.region_hash,
    region_support_hash=x.region_support_hash, local_index=x.local_index,
    point=x.point, rho_weight=x.rho_weight, theta_weight=x.theta_weight,
    zeta_weight=x.zeta_weight, nfp_multiplier=x.nfp_multiplier,
    full_torus_weight=x.full_torus_weight)

function canonical_hash(x::DESCRegionalForceQuadratureNodeV4)
    !isempty(x.region_id) && all(i -> i in 1:2, x.local_index) ||
        throw(ArgumentError("invalid regional quadrature ownership/index"))
    canonical_hash(x.point)
    0.0 < x.point.rho <= 1.0 &&
        0.0 <= x.point.theta_rad < 2pi &&
        0.0 <= x.point.zeta_rad < 2pi / x.nfp_multiplier ||
        throw(ArgumentError("quadrature point is outside the interior field-period domain"))
    all(isfinite, (x.rho_weight, x.theta_weight, x.zeta_weight,
        x.full_torus_weight)) && x.rho_weight > 0.0 &&
        x.theta_weight > 0.0 && x.zeta_weight > 0.0 &&
        x.nfp_multiplier > 0 && x.full_torus_weight ==
            x.rho_weight * x.theta_weight * x.zeta_weight * x.nfp_multiplier ||
        throw(ArgumentError("invalid full-torus quadrature weight"))
    expected = canonical_hash(semantic_view(x))
    expected == x.node_hash || throw(ArgumentError("quadrature node hash mismatch"))
    expected
end

function _drifo_nodes(regions, nfp::Int)
    nfp > 0 || throw(ArgumentError("NFP must be positive"))
    nodes = DESCRegionalForceQuadratureNodeV4[]
    xi = (-inv(sqrt(3.0)), inv(sqrt(3.0)))
    theta_weight = Float64(pi)
    zeta_weight = Float64(pi) / nfp
    for region in regions
        canonical_hash(region)
        rho_mid = (region.rho_lower + region.rho_upper) / 2
        rho_half_width = (region.rho_upper - region.rho_lower) / 2
        for ir in 1:2, itheta in 1:2, izeta in 1:2
            rho = rho_mid + rho_half_width * xi[ir]
            theta = (itheta - 0.5) * theta_weight
            zeta = (izeta - 0.5) * zeta_weight
            point = DESCFieldSamplePointV4(rho, theta, zeta)
            body = (region_id=region.region_id,
                region_hash=canonical_hash(region),
                region_support_hash=region.region_support_hash,
                local_index=(ir, itheta, izeta), point=point,
                rho_weight=rho_half_width, theta_weight=theta_weight,
                zeta_weight=zeta_weight, nfp_multiplier=nfp,
                full_torus_weight=rho_half_width * theta_weight *
                    zeta_weight * nfp)
            push!(nodes, DESCRegionalForceQuadratureNodeV4(_DRIFO_TOKEN,
                values(body)..., canonical_hash(body)))
        end
    end
    Tuple(nodes)
end

struct DESCRegionalIntegratedForceObservationRequestV4
    context_hash::Digest256
    candidate_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    partition_request_hash::Digest256
    partition_result_hash::Digest256
    partition_receipt_hash::Digest256
    surface_request_hash::Digest256
    surface_result_hash::Digest256
    surface_receipt_hash::Digest256
    traction_request_hash::Digest256
    traction_result_hash::Digest256
    pressure_request_hash::Digest256
    pressure_result_hash::Digest256
    pressure_receipt_hash::Digest256
    equilibrium_output_sha256::Digest256
    desc_version::String
    nfp::Int
    region_ids::Tuple{Vararg{String}}
    region_hashes::Tuple{Vararg{Digest256}}
    nodes::Tuple{Vararg{DESCRegionalForceQuadratureNodeV4}}
    quadrature_rule::Symbol
    source_path::String
    source_sha256::Digest256
    observation_only::Bool
    claim_ceiling::ClaimCeiling
    request_hash::Digest256
    function DESCRegionalIntegratedForceObservationRequestV4(
            token::Val{:desc_regional_integrated_force_observation_private}, fields...)
        token === _DRIFO_TOKEN || throw(ArgumentError("private observation request constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCRegionalIntegratedForceObservationRequestV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::DESCRegionalIntegratedForceObservationRequestV4)
    x.nfp > 0 && !isempty(x.desc_version) && !isempty(x.region_ids) &&
        length(x.region_ids) == length(x.region_hashes) &&
        length(x.nodes) == 8 * length(x.region_ids) &&
        length(unique(x.region_ids)) == length(x.region_ids) &&
        length(unique(canonical_hash.(x.nodes))) == length(x.nodes) &&
        x.quadrature_rule === :rho_gauss2_theta_midpoint2_zeta_field_period_midpoint2 &&
        x.observation_only && x.claim_ceiling == screen_only &&
        isfile(x.source_path) && _drifo_sha256(x.source_path) == x.source_sha256 ||
        throw(ArgumentError("invalid regional force observation request"))
    expected = canonical_hash(semantic_view(x))
    expected == x.request_hash || throw(ArgumentError("observation request hash mismatch"))
    expected
end

function _drifo_validate_upstream(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        pressure_request, pressure_result, traction_request, traction_result)
    validate_ideal_mhd_interface_traction_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result,
        basis_request, basis_result, partition_request, partition_result,
        surface_request, surface_result, pressure_request, pressure_result,
        traction_request, traction_result)
    true
end

function make_desc_regional_integrated_force_observation_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result)
    _drifo_validate_upstream(context, geometry_bridge, geometry_evaluation,
        geometry_proof, execution_request, execution_result, execution_receipt,
        field_request, field_result, basis_request, basis_result,
        partition_request, partition_result, surface_request, surface_result,
        pressure_request, pressure_result, traction_request, traction_result)
    nfp = Int(execution_request.runner_payload.nfp)
    regions = partition_request.regions
    nodes = _drifo_nodes(regions, nfp)
    body = (context_hash=context.context_hash,
        candidate_hash=context.candidate_hash,
        execution_request_hash=canonical_hash(execution_request),
        execution_result_hash=canonical_hash(execution_result),
        execution_receipt_hash=canonical_hash(execution_receipt),
        partition_request_hash=canonical_hash(partition_request),
        partition_result_hash=canonical_hash(partition_result),
        partition_receipt_hash=canonical_hash(partition_result.receipt),
        surface_request_hash=canonical_hash(surface_request),
        surface_result_hash=canonical_hash(surface_result),
        surface_receipt_hash=canonical_hash(surface_result.receipt),
        traction_request_hash=canonical_hash(traction_request),
        traction_result_hash=canonical_hash(traction_result),
        pressure_request_hash=canonical_hash(pressure_request),
        pressure_result_hash=canonical_hash(pressure_result),
        pressure_receipt_hash=canonical_hash(pressure_result.receipt),
        equilibrium_output_sha256=execution_receipt.output_sha256,
        desc_version=surface_result.desc_version, nfp=nfp,
        region_ids=Tuple(region.region_id for region in regions),
        region_hashes=Tuple(canonical_hash(region) for region in regions),
        nodes=nodes,
        quadrature_rule=:rho_gauss2_theta_midpoint2_zeta_field_period_midpoint2,
        source_path=_DRIFO_SOURCE_PATH,
        source_sha256=_drifo_sha256(_DRIFO_SOURCE_PATH),
        observation_only=true, claim_ceiling=screen_only)
    request = DESCRegionalIntegratedForceObservationRequestV4(_DRIFO_TOKEN,
        values(body)..., canonical_hash(body))
    canonical_hash(request)
    request
end

function validate_desc_regional_integrated_force_observation_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result,
        request::DESCRegionalIntegratedForceObservationRequestV4)
    rebuilt = make_desc_regional_integrated_force_observation_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result)
    semantic_view(rebuilt) == semantic_view(request) ||
        throw(ArgumentError("observation request is not the current full-chain reconstruction"))
    request.request_hash
end

struct DESCRegionalForceNodeObservationV4
    node_hash::Digest256
    field_sample_hash::Digest256
    basis_sample_hash::Digest256
    region_id::String
    local_index::NTuple{3,Int}
    point_hash::Digest256
    F_cartesian_xyz_N_m3::NTuple{3,Float64}
    sqrt_g_m3::Float64
    full_torus_weight::Float64
    weighted_force_xyz_N::NTuple{3,Float64}
    observation_hash::Digest256
    function DESCRegionalForceNodeObservationV4(
            token::Val{:desc_regional_integrated_force_observation_private}, fields...)
        token === _DRIFO_TOKEN || throw(ArgumentError("private node observation constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCRegionalForceNodeObservationV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::DESCRegionalForceNodeObservationV4)
    !isempty(x.region_id) && all(i -> i in 1:2, x.local_index) &&
        all(isfinite, (x.F_cartesian_xyz_N_m3..., x.sqrt_g_m3,
            x.full_torus_weight, x.weighted_force_xyz_N...)) &&
        x.sqrt_g_m3 > 0.0 && x.full_torus_weight > 0.0 &&
        x.weighted_force_xyz_N == ntuple(i ->
            x.F_cartesian_xyz_N_m3[i] * x.sqrt_g_m3 * x.full_torus_weight, 3) ||
        throw(ArgumentError("invalid regional force node observation"))
    expected = canonical_hash(semantic_view(x))
    expected == x.observation_hash || throw(ArgumentError("node observation hash mismatch"))
    expected
end

struct DESCRegionIntegratedForceObservationV4
    region_id::String
    region_hash::Digest256
    region_support_hash::Digest256
    node_observation_hashes::Tuple{Vararg{Digest256}}
    quadrature_volume_m3::Float64
    integrated_force_xyz_N::NTuple{3,Float64}
    integrated_force_norm_N::Float64
    observation_hash::Digest256
    function DESCRegionIntegratedForceObservationV4(
            token::Val{:desc_regional_integrated_force_observation_private}, fields...)
        token === _DRIFO_TOKEN || throw(ArgumentError("private region observation constructor"))
        new(fields...)
    end
end

semantic_view(x::DESCRegionIntegratedForceObservationV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::DESCRegionIntegratedForceObservationV4)
    !isempty(x.region_id) && length(x.node_observation_hashes) == 8 &&
        length(unique(x.node_observation_hashes)) == 8 &&
        isfinite(x.quadrature_volume_m3) && x.quadrature_volume_m3 > 0.0 &&
        all(isfinite, x.integrated_force_xyz_N) &&
        x.integrated_force_norm_N == norm(collect(x.integrated_force_xyz_N)) ||
        throw(ArgumentError("invalid region integrated-force observation"))
    expected = canonical_hash(semantic_view(x))
    expected == x.observation_hash || throw(ArgumentError("region observation hash mismatch"))
    expected
end

struct DESCRegionalIntegratedForceObservationReceiptV4
    request_hash::Digest256
    field_request_hash::Digest256
    field_result_hash::Digest256
    field_receipt_hash::Digest256
    basis_request_hash::Digest256
    basis_result_hash::Digest256
    basis_receipt_hash::Digest256
    output_path::String
    output_sha256::Digest256
    source_path::String
    source_sha256::Digest256
    output_schema_validated::Bool
    receipt_hash::Digest256
end

semantic_view(x::DESCRegionalIntegratedForceObservationReceiptV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(x::DESCRegionalIntegratedForceObservationReceiptV4)
    x.output_schema_validated && isfile(x.output_path) &&
        _drifo_sha256(x.output_path) == x.output_sha256 &&
        isfile(x.source_path) && _drifo_sha256(x.source_path) == x.source_sha256 ||
        throw(ArgumentError("observation receipt artifact missing or tampered"))
    expected = canonical_hash(semantic_view(x))
    expected == x.receipt_hash || throw(ArgumentError("observation receipt hash mismatch"))
    expected
end

struct DESCRegionalIntegratedForceObservationResultV4
    status::Symbol
    context_hash::Digest256
    candidate_hash::Digest256
    request_hash::Digest256
    field_request_hash::Digest256
    field_result_hash::Digest256
    basis_request_hash::Digest256
    basis_result_hash::Digest256
    node_observations::Tuple{Vararg{DESCRegionalForceNodeObservationV4}}
    region_observations::Tuple{Vararg{DESCRegionIntegratedForceObservationV4}}
    observed_total_force_xyz_N::NTuple{3,Float64}
    observed_total_force_norm_N::Float64
    tensor_quadrature_executed::Bool
    regional_force_integrals_observed::Bool
    test_function_applied::Bool
    boundary_terms_available::Bool
    weak_form_assembled::Bool
    regional_residual_assembled::Bool
    jacobian_executed::Bool
    global_conservation_validated::Bool
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
    receipt::DESCRegionalIntegratedForceObservationReceiptV4
    result_hash::Digest256
end

function semantic_view(x::DESCRegionalIntegratedForceObservationResultV4)
    names = fieldnames(typeof(x))[1:end-2]
    body = NamedTuple{names}(ntuple(i -> getfield(x, i), length(names)))
    merge(body, (receipt_hash=canonical_hash(x.receipt),))
end

function canonical_hash(x::DESCRegionalIntegratedForceObservationResultV4)
    canonical_hash(x.receipt)
    foreach(canonical_hash, x.node_observations)
    foreach(canonical_hash, x.region_observations)
    x.status === :regional_integrated_force_observed &&
        !isempty(x.node_observations) && !isempty(x.region_observations) &&
        x.tensor_quadrature_executed && x.regional_force_integrals_observed &&
        !x.test_function_applied && !x.boundary_terms_available &&
        !x.weak_form_assembled && !x.regional_residual_assembled &&
        !x.jacobian_executed && !x.global_conservation_validated &&
        !x.solver_convergence_validated && !x.multiregion_closure &&
        !x.physical_validation && !x.engineering_validation &&
        !x.emits_evidence && !x.grants_pass && !x.promotion_authority &&
        !x.p5_ready && !x.terminal_authority &&
        x.credible_physical_device_count == 0 && x.claim_ceiling == screen_only &&
        x.observed_total_force_norm_N == norm(collect(x.observed_total_force_xyz_N)) ||
        throw(ArgumentError("regional force observation exceeds observation-only authority"))
    expected = canonical_hash(semantic_view(x))
    expected == x.result_hash || throw(ArgumentError("observation result hash mismatch"))
    expected
end

function _drifo_node_observations(request, field_result, basis_result)
    length(request.nodes) == length(field_result.samples) == length(basis_result.samples) ||
        throw(ArgumentError("observation sample coverage mismatch"))
    observations = DESCRegionalForceNodeObservationV4[]
    for (node, field_sample, basis_sample) in
            zip(request.nodes, field_result.samples, basis_result.samples)
        canonical_hash(node); canonical_hash(field_sample); canonical_hash(basis_sample)
        node.point.point_hash == canonical_hash(field_sample.point) ==
            basis_sample.point_hash || throw(ArgumentError("observation point identity mismatch"))
        field_sample.force_balance_error_desc_native_N_m3 ==
            basis_sample.F_cylindrical_R_phi_Z_N_m3 &&
            field_sample.sqrt_g_m3 == basis_sample.sqrt_g_m3 ||
            throw(ArgumentError("field/basis observation values disagree"))
        weighted = ntuple(i -> basis_sample.F_cartesian_xyz_N_m3[i] *
            basis_sample.sqrt_g_m3 * node.full_torus_weight, 3)
        body = (node_hash=node.node_hash,
            field_sample_hash=canonical_hash(field_sample),
            basis_sample_hash=canonical_hash(basis_sample),
            region_id=node.region_id, local_index=node.local_index,
            point_hash=node.point.point_hash,
            F_cartesian_xyz_N_m3=basis_sample.F_cartesian_xyz_N_m3,
            sqrt_g_m3=basis_sample.sqrt_g_m3,
            full_torus_weight=node.full_torus_weight,
            weighted_force_xyz_N=weighted)
        push!(observations, DESCRegionalForceNodeObservationV4(_DRIFO_TOKEN,
            values(body)..., canonical_hash(body)))
    end
    Tuple(observations)
end

function _drifo_region_observations(request, node_observations)
    output = DESCRegionIntegratedForceObservationV4[]
    for (region_id, region_hash) in zip(request.region_ids, request.region_hashes)
        indices = findall(x -> x.region_id == region_id, node_observations)
        length(indices) == 8 || throw(ArgumentError("region does not own exactly eight nodes"))
        nodes = node_observations[indices]
        specs = request.nodes[indices]
        force = ntuple(k -> sum(node.weighted_force_xyz_N[k] for node in nodes), 3)
        volume = sum(node.sqrt_g_m3 * node.full_torus_weight for node in nodes)
        support_hashes = unique(spec.region_support_hash for spec in specs)
        length(support_hashes) == 1 || throw(ArgumentError("region node support mismatch"))
        body = (region_id=region_id, region_hash=region_hash,
            region_support_hash=only(support_hashes),
            node_observation_hashes=Tuple(node.observation_hash for node in nodes),
            quadrature_volume_m3=volume, integrated_force_xyz_N=force,
            integrated_force_norm_N=norm(collect(force)))
        push!(output, DESCRegionIntegratedForceObservationV4(_DRIFO_TOKEN,
            values(body)..., canonical_hash(body)))
    end
    Tuple(output)
end

function _drifo_output_text(request, field_request, field_result, basis_request,
        basis_result, node_observations)
    rows = ["SCHEMA\t$_DRIFO_OUTPUT_SCHEMA",
        "REQUEST_HASH\t$(request.request_hash)",
        "FIELD_REQUEST_HASH\t$(canonical_hash(field_request))",
        "FIELD_RESULT_HASH\t$(canonical_hash(field_result))",
        "BASIS_REQUEST_HASH\t$(canonical_hash(basis_request))",
        "BASIS_RESULT_HASH\t$(canonical_hash(basis_result))",
        "NFP\t$(request.nfp)", "COUNT\t$(length(node_observations))"]
    for (index, node) in enumerate(node_observations)
        request_node = request.nodes[index]
        push!(rows, join(("NODE", index, node.node_hash, node.region_id,
            node.local_index..., repr(request_node.point.rho),
            repr(request_node.point.theta_rad), repr(request_node.point.zeta_rad),
            (repr(x) for x in node.F_cartesian_xyz_N_m3)...,
            repr(node.sqrt_g_m3), repr(node.full_torus_weight),
            (repr(x) for x in node.weighted_force_xyz_N)...), '\t'))
    end
    push!(rows, "END\t1")
    join(rows, '\n') * "\n"
end

function _drifo_parse_output(path, request, field_request, field_result,
        basis_request, basis_result)
    lines = [split(line, '\t'; keepempty=true) for line in readlines(path)]
    headers = (("SCHEMA", _DRIFO_OUTPUT_SCHEMA),
        ("REQUEST_HASH", string(request.request_hash)),
        ("FIELD_REQUEST_HASH", string(canonical_hash(field_request))),
        ("FIELD_RESULT_HASH", string(canonical_hash(field_result))),
        ("BASIS_REQUEST_HASH", string(canonical_hash(basis_request))),
        ("BASIS_RESULT_HASH", string(canonical_hash(basis_result))),
        ("NFP", string(request.nfp)), ("COUNT", string(length(request.nodes))))
    length(lines) == length(request.nodes) + 9 &&
        all(lines[i] == collect(headers[i]) for i in eachindex(headers)) &&
        lines[end] == ["END", "1"] || throw(ArgumentError("observation output framing mismatch"))
    parsed = []
    for (index, spec) in enumerate(request.nodes)
        row = lines[index + 8]
        length(row) == 18 && row[1] == "NODE" && tryparse(Int, row[2]) == index &&
            row[3] == string(spec.node_hash) && row[4] == spec.region_id ||
            throw(ArgumentError("observation output node identity mismatch"))
        local_index = ntuple(k -> something(tryparse(Int, row[4 + k]), 0), 3)
        values = ntuple(k -> something(tryparse(Float64, row[7 + k]), NaN), 11)
        all(isfinite, values) || throw(ArgumentError("observation output contains nonfinite values"))
        local_index == spec.local_index && values[1:3] ==
            (spec.point.rho, spec.point.theta_rad, spec.point.zeta_rad) ||
            throw(ArgumentError("observation output quadrature point mismatch"))
        push!(parsed, (node_hash=spec.node_hash, region_id=spec.region_id,
            local_index=local_index, point=values[1:3], F=values[4:6],
            sqrt_g=values[7], weight=values[8], weighted=values[9:11]))
    end
    Tuple(parsed)
end

function execute_desc_regional_integrated_force_observation(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result,
        request::DESCRegionalIntegratedForceObservationRequestV4; run_dir)
    validate_desc_regional_integrated_force_observation_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, request)
    dir = String(run_dir)
    mkpath(dir)
    points = Tuple(node.point for node in request.nodes)
    regional_field_request = make_desc_field_provider_request(context,
        execution_request, execution_result, execution_receipt, points)
    regional_field_result = execute_desc_field_provider(context,
        execution_request, execution_result, execution_receipt,
        regional_field_request; run_dir=joinpath(dir, "field"))
    regional_basis_request = make_desc_field_basis_bridge_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt,
        regional_field_request, regional_field_result)
    regional_basis_result = execute_desc_field_basis_bridge(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt,
        regional_field_request, regional_field_result, regional_basis_request;
        run_dir=joinpath(dir, "basis"))
    node_observations = _drifo_node_observations(request,
        regional_field_result, regional_basis_result)
    region_observations = _drifo_region_observations(request, node_observations)
    output_path = joinpath(dir, "regional_integrated_force_observation.tsv")
    write(output_path, _drifo_output_text(request, regional_field_request,
        regional_field_result, regional_basis_request, regional_basis_result,
        node_observations))
    _drifo_parse_output(output_path, request, regional_field_request,
        regional_field_result, regional_basis_request, regional_basis_result)
    receipt_body = (request_hash=request.request_hash,
        field_request_hash=canonical_hash(regional_field_request),
        field_result_hash=canonical_hash(regional_field_result),
        field_receipt_hash=canonical_hash(regional_field_result.receipt),
        basis_request_hash=canonical_hash(regional_basis_request),
        basis_result_hash=canonical_hash(regional_basis_result),
        basis_receipt_hash=canonical_hash(regional_basis_result.receipt),
        output_path=output_path, output_sha256=_drifo_sha256(output_path),
        source_path=_DRIFO_SOURCE_PATH,
        source_sha256=_drifo_sha256(_DRIFO_SOURCE_PATH),
        output_schema_validated=true)
    receipt = DESCRegionalIntegratedForceObservationReceiptV4(
        values(receipt_body)..., canonical_hash(receipt_body))
    total = ntuple(k -> sum(region.integrated_force_xyz_N[k]
        for region in region_observations), 3)
    body = (status=:regional_integrated_force_observed,
        context_hash=context.context_hash, candidate_hash=context.candidate_hash,
        request_hash=request.request_hash,
        field_request_hash=canonical_hash(regional_field_request),
        field_result_hash=canonical_hash(regional_field_result),
        basis_request_hash=canonical_hash(regional_basis_request),
        basis_result_hash=canonical_hash(regional_basis_result),
        node_observations=node_observations,
        region_observations=region_observations,
        observed_total_force_xyz_N=total,
        observed_total_force_norm_N=norm(collect(total)),
        tensor_quadrature_executed=true,
        regional_force_integrals_observed=true,
        test_function_applied=false, boundary_terms_available=false,
        weak_form_assembled=false, regional_residual_assembled=false,
        jacobian_executed=false, global_conservation_validated=false,
        solver_convergence_validated=false, multiregion_closure=false,
        physical_validation=false, engineering_validation=false,
        emits_evidence=false, grants_pass=false, promotion_authority=false,
        p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0, claim_ceiling=screen_only,
        receipt=receipt)
    hash_body = merge(Base.structdiff(body, NamedTuple{(:receipt,)}),
        (receipt_hash=canonical_hash(receipt),))
    result = DESCRegionalIntegratedForceObservationResultV4(
        values(body)..., canonical_hash(hash_body))
    validate_desc_regional_integrated_force_observation_result(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, request,
        regional_field_request, regional_field_result, regional_basis_request,
        regional_basis_result, result)
    (request=request, field_request=regional_field_request,
     field_result=regional_field_result, basis_request=regional_basis_request,
     basis_result=regional_basis_result, observation=result)
end

function validate_desc_regional_integrated_force_observation_result(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result,
        request::DESCRegionalIntegratedForceObservationRequestV4,
        regional_field_request, regional_field_result, regional_basis_request,
        regional_basis_result,
        result::DESCRegionalIntegratedForceObservationResultV4)
    validate_desc_regional_integrated_force_observation_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, field_request,
        field_result, basis_request, basis_result, partition_request,
        partition_result, surface_request, surface_result, pressure_request,
        pressure_result, traction_request, traction_result, request)
    validate_desc_field_provider_result(context, execution_request,
        execution_result, execution_receipt, regional_field_request,
        regional_field_result)
    validate_desc_field_basis_bridge_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, regional_field_request,
        regional_field_result, regional_basis_request, regional_basis_result)
    canonical_hash(result)
    result.context_hash == context.context_hash &&
        result.candidate_hash == context.candidate_hash &&
        result.request_hash == request.request_hash &&
        result.field_request_hash == canonical_hash(regional_field_request) &&
        result.field_result_hash == canonical_hash(regional_field_result) &&
        result.basis_request_hash == canonical_hash(regional_basis_request) &&
        result.basis_result_hash == canonical_hash(regional_basis_result) ||
        throw(ArgumentError("observation result upstream identity mismatch"))
    receipt = result.receipt
    canonical_hash(receipt)
    receipt.request_hash == request.request_hash &&
        receipt.field_request_hash == result.field_request_hash &&
        receipt.field_result_hash == result.field_result_hash &&
        receipt.field_receipt_hash == canonical_hash(regional_field_result.receipt) &&
        receipt.basis_request_hash == result.basis_request_hash &&
        receipt.basis_result_hash == result.basis_result_hash &&
        receipt.basis_receipt_hash == canonical_hash(regional_basis_result.receipt) ||
        throw(ArgumentError("observation receipt identity mismatch"))
    parsed = _drifo_parse_output(receipt.output_path, request,
        regional_field_request, regional_field_result, regional_basis_request,
        regional_basis_result)
    replayed_nodes = _drifo_node_observations(request, regional_field_result,
        regional_basis_result)
    length(parsed) == length(replayed_nodes) &&
        all(parsed[i].node_hash == replayed_nodes[i].node_hash &&
            parsed[i].region_id == replayed_nodes[i].region_id &&
            parsed[i].local_index == replayed_nodes[i].local_index &&
            parsed[i].F == replayed_nodes[i].F_cartesian_xyz_N_m3 &&
            parsed[i].sqrt_g == replayed_nodes[i].sqrt_g_m3 &&
            parsed[i].weight == replayed_nodes[i].full_torus_weight &&
            parsed[i].weighted == replayed_nodes[i].weighted_force_xyz_N
            for i in eachindex(parsed)) ||
        throw(ArgumentError("observation output differs from independent replay"))
    replayed_regions = _drifo_region_observations(request, replayed_nodes)
    result.node_observations == replayed_nodes &&
        result.region_observations == replayed_regions ||
        throw(ArgumentError("regional observation differs from independent recomputation"))
    total = ntuple(k -> sum(region.integrated_force_xyz_N[k]
        for region in replayed_regions), 3)
    result.observed_total_force_xyz_N == total &&
        result.observed_total_force_norm_N == norm(collect(total)) ||
        throw(ArgumentError("total observed force differs from regional sum"))
    result.result_hash
end

desc_regional_integrated_force_observation_manifest() = (
    schema=_DRIFO_SCHEMA, revision=_DRIFO_REVISION,
    quadrature=:rho_gauss2_theta_midpoint2_zeta_field_period_midpoint2,
    samples_per_region=8, integrates=:F_cartesian_times_sqrt_g,
    integration_domain=:full_torus, output_unit="N",
    tensor_quadrature_executed=true,
    regional_force_integrals_observed=true,
    test_function_applied=false, boundary_terms_available=false,
    weak_form_assembled=false, regional_residual_assembled=false,
    jacobian_executed=false, global_conservation_validated=false,
    solver_convergence_validated=false, multiregion_closure=false,
    physical_validation=false, engineering_validation=false,
    emits_evidence=false, grants_pass=false, promotion_authority=false,
    p5_ready=false, terminal_authority=false,
    credible_physical_device_count=0, claim_ceiling=screen_only)
