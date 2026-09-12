using FusionConceptAI
using LinearAlgebra
using SHA

const _RFQ4_REVISION = "regional-force-observation-q4-comparison-v2"
const _RFQ4_SOURCE = abspath(@__FILE__)
const _RFQ4_TOKEN = Val(:regional_force_q4_private)
_rfq4_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))
_rfq4_sum(values) = ntuple(k -> sum(value[k] for value in values), 3)
_rfq4_diff(a, b) = norm(collect(ntuple(k -> b[k] - a[k], 3)))
_rfq4_relative(a, b) = _rfq4_diff(a, b) / max(norm(collect(a)), eps())
_rfq4_vectors_isapprox(a, b; rtol, atol) = length(a) == length(b) &&
    all(length(x) == length(y) && all(isapprox(x[i], y[i]; rtol=rtol, atol=atol)
        for i in eachindex(x)) for (x, y) in zip(a, b))

function _rfq4_nodes(region_ids, region_hashes, support_hashes, bounds, nfp)
    length(region_ids) == length(region_hashes) == length(support_hashes) == length(bounds) ||
        throw(ArgumentError("q4 partition metadata length mismatch"))
    nfp > 0 || throw(ArgumentError("q4 nfp must be positive"))
    a = sqrt((3 + 2sqrt(6 / 5)) / 7)
    b = sqrt((3 - 2sqrt(6 / 5)) / 7)
    xi = (-a, -b, b, a)
    wa = (18 - sqrt(30)) / 36
    wb = (18 + sqrt(30)) / 36
    radial_weights = (wa, wb, wb, wa)
    theta_weight = 2pi / 4
    zeta_weight = 2pi / (4nfp)
    nodes = NamedTuple[]
    for region_index in eachindex(region_ids)
        bound = bounds[region_index]
        lower = Float64(bound.rho_lower)
        upper = Float64(bound.rho_upper)
        isfinite(lower) && isfinite(upper) && 0 <= lower < upper <= 1 ||
            throw(ArgumentError("invalid q4 rho bounds"))
        midpoint = (lower + upper) / 2
        halfwidth = (upper - lower) / 2
        for radial_index in 1:4, theta_index in 1:4, zeta_index in 1:4
            point = DESCFieldSamplePointV4(
                midpoint + halfwidth * xi[radial_index],
                (theta_index - 0.5) * theta_weight,
                (zeta_index - 0.5) * zeta_weight)
            push!(nodes, (
                region_id=region_ids[region_index],
                region_hash=region_hashes[region_index],
                region_support_hash=support_hashes[region_index],
                local_index=(radial_index, theta_index, zeta_index),
                point=point,
                weight=halfwidth * radial_weights[radial_index] *
                    theta_weight * zeta_weight * nfp))
        end
    end
    Tuple(nodes)
end

struct RegionalForceQ4RequestV4
    revision::String
    candidate_hash::Digest256
    context_hash::Digest256
    q3_comparison_hash::Digest256
    partition_request_hash::Digest256
    partition_result_hash::Digest256
    execution_request_hash::Digest256
    execution_result_hash::Digest256
    execution_receipt_hash::Digest256
    physical_support_hash::Digest256
    partition_region_ids::Tuple
    partition_region_hashes::Tuple
    partition_support_hashes::Tuple
    partition_region_bounds::Tuple
    partition_interface_hashes::Tuple
    nfp::Int
    nodes::Tuple
    quadrature::Symbol
    field_request_hash::Digest256
    basis_request_hash::Digest256
    source_path::String
    source_sha256::Digest256
    request_hash::Digest256
    function RegionalForceQ4RequestV4(token::Val{:regional_force_q4_private}, fields...)
        token === _RFQ4_TOKEN || throw(ArgumentError("private q4 request constructor"))
        new(fields...)
    end
end

struct RegionalForceQ4ReceiptV4
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
    runtime_path::String
    runtime_sha256::Digest256
    receipt_hash::Digest256
    function RegionalForceQ4ReceiptV4(token::Val{:regional_force_q4_private}, fields...)
        token === _RFQ4_TOKEN || throw(ArgumentError("private q4 receipt constructor"))
        new(fields...)
    end
end

struct RegionalForceQ4ResultV4
    request_hash::Digest256
    receipt_hash::Digest256
    region_force::Tuple
    total_force::NTuple{3,Float64}
    result_hash::Digest256
    function RegionalForceQ4ResultV4(token::Val{:regional_force_q4_private}, fields...)
        token === _RFQ4_TOKEN || throw(ArgumentError("private q4 result constructor"))
        new(fields...)
    end
end

for type_name in (:RegionalForceQ4RequestV4, :RegionalForceQ4ReceiptV4,
        :RegionalForceQ4ResultV4)
    @eval semantic_view(x::$type_name) =
        NamedTuple{fieldnames(typeof(x))[1:end-1]}(
            ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))
end

function canonical_hash(request::RegionalForceQ4RequestV4)
    expected_nodes = _rfq4_nodes(request.partition_region_ids,
        request.partition_region_hashes, request.partition_support_hashes,
        request.partition_region_bounds, request.nfp)
    request.revision == _RFQ4_REVISION &&
        request.quadrature === :rho_gauss4_theta_midpoint4_zeta_midpoint4 &&
        !isempty(request.partition_region_ids) &&
        length(unique(request.partition_region_ids)) == length(request.partition_region_ids) &&
        request.nodes == expected_nodes &&
        length(request.nodes) == 64 * length(request.partition_region_ids) &&
        all(node -> canonical_hash(node.point) == node.point.point_hash &&
            isfinite(node.weight) && node.weight > 0, request.nodes) &&
        isfile(request.source_path) && _rfq4_sha(request.source_path) == request.source_sha256 ||
        throw(ArgumentError("invalid q4 request"))
    expected = canonical_hash(semantic_view(request))
    expected == request.request_hash || throw(ArgumentError("q4 request hash mismatch"))
    expected
end

function canonical_hash(receipt::RegionalForceQ4ReceiptV4)
    isfile(receipt.source_path) && _rfq4_sha(receipt.source_path) == receipt.source_sha256 &&
        isfile(receipt.runtime_path) && _rfq4_sha(receipt.runtime_path) == receipt.runtime_sha256 ||
        throw(ArgumentError("invalid q4 receipt source/runtime"))
    expected = canonical_hash(semantic_view(receipt))
    expected == receipt.receipt_hash || throw(ArgumentError("q4 receipt hash mismatch"))
    expected
end

function canonical_hash(result::RegionalForceQ4ResultV4)
    !isempty(result.region_force) &&
        all(value -> length(value) == 3 && all(isfinite, value), result.region_force) &&
        all(isfinite, result.total_force) && _rfq4_sum(result.region_force) == result.total_force ||
        throw(ArgumentError("invalid q4 force values"))
    expected = canonical_hash(semantic_view(result))
    expected == result.result_hash || throw(ArgumentError("q4 result hash mismatch"))
    expected
end

function _rfq4_output_text(region_ids, values, total)
    join(("REGION|$(region_ids[i])|$(values[i][1])|$(values[i][2])|$(values[i][3])"
        for i in eachindex(values)), "\n") *
        "\nTOTAL|$(total[1])|$(total[2])|$(total[3])\n"
end

function validate_regional_force_q4_receipt(receipt, request, field_request,
        field_result, basis_request, basis_result, values, total)
    canonical_hash(receipt)
    canonical_hash(request)
    canonical_hash(field_request)
    canonical_hash(field_result)
    canonical_hash(basis_request)
    canonical_hash(basis_result)
    receipt.request_hash == request.request_hash &&
        receipt.field_request_hash == request.field_request_hash &&
        receipt.basis_request_hash == request.basis_request_hash &&
        receipt.field_request_hash == canonical_hash(field_request) &&
        receipt.field_result_hash == canonical_hash(field_result) &&
        receipt.field_receipt_hash == canonical_hash(field_result.receipt) &&
        receipt.basis_request_hash == canonical_hash(basis_request) &&
        receipt.basis_result_hash == canonical_hash(basis_result) &&
        receipt.basis_receipt_hash == canonical_hash(basis_result.receipt) &&
        isfile(receipt.output_path) && _rfq4_sha(receipt.output_path) == receipt.output_sha256 &&
        read(receipt.output_path, String) ==
            _rfq4_output_text(request.partition_region_ids, values, total) ||
        throw(ArgumentError("q4 receipt artifact or upstream identity mismatch"))
    receipt.receipt_hash
end

struct RegionalForceQ4ComparisonV4
    candidate_hash::Digest256
    context_hash::Digest256
    q2_request_hash::Digest256
    q2_result_hash::Digest256
    q2_receipt_hash::Digest256
    q3_comparison_hash::Digest256
    q3_request_hash::Digest256
    q3_result_hash::Digest256
    q3_receipt_hash::Digest256
    q4_request::RegionalForceQ4RequestV4
    q4_result::RegionalForceQ4ResultV4
    q4_receipt::RegionalForceQ4ReceiptV4
    q2_region_force::Tuple
    q3_region_force::Tuple
    q4_region_force::Tuple
    q2_total_force::NTuple{3,Float64}
    q3_total_force::NTuple{3,Float64}
    q4_total_force::NTuple{3,Float64}
    q2_q3_absolute_difference_N::Float64
    q2_q3_relative_difference::Float64
    q3_q4_absolute_difference_N::Float64
    q3_q4_relative_difference::Float64
    relative_tolerance::Float64
    absolute_tolerance_N::Float64
    convergence_status::Symbol
    convergence_protocol::Symbol
    numerical_convergence_assessed::Bool
    fresh_q4_executed::Bool
    independent_replay_required::Bool
    independent_code_validation::Bool
    physical_validation::Bool
    validation_uq::Bool
    promotion_authority::Bool
    terminal_authority::Bool
    credible_device_count::Int
    evidence_credit::Int
    claim_ceiling::ClaimCeiling
    source_path::String
    source_sha256::Digest256
    comparison_hash::Digest256
    function RegionalForceQ4ComparisonV4(token::Val{:regional_force_q4_private}, fields...)
        token === _RFQ4_TOKEN || throw(ArgumentError("private q4 comparison constructor"))
        new(fields...)
    end
end

semantic_view(x::RegionalForceQ4ComparisonV4) =
    NamedTuple{fieldnames(typeof(x))[1:end-1]}(
        ntuple(i -> getfield(x, i), fieldcount(typeof(x)) - 1))

function canonical_hash(comparison::RegionalForceQ4ComparisonV4)
    canonical_hash(comparison.q4_request)
    canonical_hash(comparison.q4_result)
    canonical_hash(comparison.q4_receipt)
    comparison.q4_result.request_hash == comparison.q4_request.request_hash &&
        comparison.q4_result.receipt_hash == comparison.q4_receipt.receipt_hash &&
        comparison.q4_request.candidate_hash == comparison.candidate_hash &&
        comparison.q4_request.context_hash == comparison.context_hash ||
        throw(ArgumentError("q4 comparison identity mismatch"))
    all(values -> !isempty(values) && all(value -> length(value) == 3 &&
        all(isfinite, value), values),
        (comparison.q2_region_force, comparison.q3_region_force,
            comparison.q4_region_force)) &&
        length(comparison.q2_region_force) == length(comparison.q3_region_force) ==
            length(comparison.q4_region_force) ==
            length(comparison.q4_request.partition_region_ids) &&
        _rfq4_sum(comparison.q2_region_force) == comparison.q2_total_force &&
        _rfq4_sum(comparison.q3_region_force) == comparison.q3_total_force &&
        _rfq4_sum(comparison.q4_region_force) == comparison.q4_total_force &&
        comparison.q4_region_force == comparison.q4_result.region_force &&
        comparison.q4_total_force == comparison.q4_result.total_force ||
        throw(ArgumentError("q4 comparison force copy mismatch"))
    q2_q3_absolute = _rfq4_diff(comparison.q2_total_force,
        comparison.q3_total_force)
    q2_q3_relative = _rfq4_relative(comparison.q2_total_force,
        comparison.q3_total_force)
    q3_q4_absolute = _rfq4_diff(comparison.q3_total_force,
        comparison.q4_total_force)
    q3_q4_relative = _rfq4_relative(comparison.q3_total_force,
        comparison.q4_total_force)
    all(isfinite, (comparison.relative_tolerance, comparison.absolute_tolerance_N,
        q2_q3_absolute, q2_q3_relative, q3_q4_absolute, q3_q4_relative)) &&
        comparison.relative_tolerance > 0 && comparison.absolute_tolerance_N > 0 &&
        comparison.q2_q3_absolute_difference_N == q2_q3_absolute &&
        comparison.q2_q3_relative_difference == q2_q3_relative &&
        comparison.q3_q4_absolute_difference_N == q3_q4_absolute &&
        comparison.q3_q4_relative_difference == q3_q4_relative ||
        throw(ArgumentError("q4 ladder difference mismatch"))
    latest_within_tolerance = q3_q4_absolute <= comparison.absolute_tolerance_N ||
        q3_q4_relative <= comparison.relative_tolerance
    reduced = q3_q4_absolute < q2_q3_absolute
    expected_status = latest_within_tolerance && reduced ? :pass : :fail
    comparison.convergence_status === expected_status &&
        comparison.convergence_protocol ===
            :successive_q2_q3_q4_latest_pair_with_reduction &&
        comparison.numerical_convergence_assessed && comparison.fresh_q4_executed &&
        comparison.independent_replay_required &&
        !comparison.independent_code_validation && !comparison.physical_validation &&
        !comparison.validation_uq && !comparison.promotion_authority &&
        !comparison.terminal_authority && comparison.credible_device_count == 0 &&
        comparison.evidence_credit == 0 && comparison.claim_ceiling == screen_only &&
        isfile(comparison.source_path) &&
        _rfq4_sha(comparison.source_path) == comparison.source_sha256 ||
        throw(ArgumentError("invalid q4 comparison authority or status"))
    expected = canonical_hash(semantic_view(comparison))
    expected == comparison.comparison_hash ||
        throw(ArgumentError("q4 comparison hash mismatch"))
    expected
end

function execute_regional_force_q4(upstream, traction_request, traction_result,
        q2_request, q2_result, q2_execution, q3_execution;
        run_dir, relative_tolerance=1e-3, absolute_tolerance_N=1e-6)
    isfinite(relative_tolerance) && relative_tolerance > 0 &&
        isfinite(absolute_tolerance_N) && absolute_tolerance_N > 0 ||
        throw(ArgumentError("q4 tolerances must be finite and positive"))
    validate_regional_force_q3_execution(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, q3_execution)
    length(upstream) == 17 || throw(ArgumentError("full chain tuple must have 17 typed entries"))
    (context, geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, _, _, _, _,
        partition_request, partition_result, _, _, _, _) = upstream
    comparison3 = q3_execution.comparison
    region_ids = Tuple(region.region_id for region in partition_request.regions)
    region_hashes = Tuple(region.region_hash for region in partition_request.regions)
    support_hashes = Tuple(region.region_support_hash for region in partition_request.regions)
    bounds = Tuple((rho_lower=Float64(region.rho_lower),
        rho_upper=Float64(region.rho_upper)) for region in partition_request.regions)
    nfp = Int(execution_request.runner_payload.nfp)
    nodes = _rfq4_nodes(region_ids, region_hashes, support_hashes, bounds, nfp)
    points = Tuple(node.point for node in nodes)
    root = abspath(String(run_dir))
    mkpath(root)
    field_request = make_desc_field_provider_request(context, execution_request,
        execution_result, execution_receipt, points)
    field_result = execute_desc_field_provider(context, execution_request,
        execution_result, execution_receipt, field_request;
        run_dir=joinpath(root, "field"))
    basis_request = make_desc_field_basis_bridge_request(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result)
    basis_result = execute_desc_field_basis_bridge(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result, basis_request;
        run_dir=joinpath(root, "basis"))
    request_body = (
        revision=_RFQ4_REVISION,
        candidate_hash=context.candidate_hash,
        context_hash=context.context_hash,
        q3_comparison_hash=comparison3.comparison_hash,
        partition_request_hash=canonical_hash(partition_request),
        partition_result_hash=canonical_hash(partition_result),
        execution_request_hash=canonical_hash(execution_request),
        execution_result_hash=canonical_hash(execution_result),
        execution_receipt_hash=canonical_hash(execution_receipt),
        physical_support_hash=partition_request.physical_support_hash,
        partition_region_ids=region_ids,
        partition_region_hashes=region_hashes,
        partition_support_hashes=support_hashes,
        partition_region_bounds=bounds,
        partition_interface_hashes=Tuple(canonical_hash(interface)
            for interface in partition_request.interfaces),
        nfp=nfp,
        nodes=nodes,
        quadrature=:rho_gauss4_theta_midpoint4_zeta_midpoint4,
        field_request_hash=canonical_hash(field_request),
        basis_request_hash=canonical_hash(basis_request),
        source_path=_RFQ4_SOURCE,
        source_sha256=_rfq4_sha(_RFQ4_SOURCE))
    request = RegionalForceQ4RequestV4(_RFQ4_TOKEN, values(request_body)...,
        canonical_hash(request_body))
    region_force = Tuple(ntuple(k -> sum(
        basis_result.samples[i].F_cartesian_xyz_N_m3[k] *
            basis_result.samples[i].sqrt_g_m3 * nodes[i].weight
        for i in eachindex(nodes) if nodes[i].region_id == region_id), 3)
        for region_id in region_ids)
    total_force = _rfq4_sum(region_force)
    output_path = joinpath(root, "regional_force_q4_result.tsv")
    write(output_path, _rfq4_output_text(region_ids, region_force, total_force))
    receipt_body = (
        request_hash=request.request_hash,
        field_request_hash=canonical_hash(field_request),
        field_result_hash=canonical_hash(field_result),
        field_receipt_hash=canonical_hash(field_result.receipt),
        basis_request_hash=canonical_hash(basis_request),
        basis_result_hash=canonical_hash(basis_result),
        basis_receipt_hash=canonical_hash(basis_result.receipt),
        output_path=output_path,
        output_sha256=_rfq4_sha(output_path),
        source_path=_RFQ4_SOURCE,
        source_sha256=_rfq4_sha(_RFQ4_SOURCE),
        runtime_path=execution_receipt.python_executable,
        runtime_sha256=_rfq4_sha(execution_receipt.python_executable))
    receipt = RegionalForceQ4ReceiptV4(_RFQ4_TOKEN, values(receipt_body)...,
        canonical_hash(receipt_body))
    result_body = (request_hash=request.request_hash,
        receipt_hash=receipt.receipt_hash, region_force=region_force,
        total_force=total_force)
    result = RegionalForceQ4ResultV4(_RFQ4_TOKEN, values(result_body)...,
        canonical_hash(result_body))
    validate_regional_force_q4_receipt(receipt, request, field_request,
        field_result, basis_request, basis_result, region_force, total_force)
    q2 = q2_result.observed_total_force_xyz_N
    q3 = comparison3.q3_total_force
    q2_q3_absolute = _rfq4_diff(q2, q3)
    q2_q3_relative = _rfq4_relative(q2, q3)
    q3_q4_absolute = _rfq4_diff(q3, total_force)
    q3_q4_relative = _rfq4_relative(q3, total_force)
    status = ((q3_q4_absolute <= absolute_tolerance_N ||
        q3_q4_relative <= relative_tolerance) &&
        q3_q4_absolute < q2_q3_absolute) ? :pass : :fail
    comparison_body = (
        candidate_hash=context.candidate_hash,
        context_hash=context.context_hash,
        q2_request_hash=comparison3.q2_request_hash,
        q2_result_hash=comparison3.q2_result_hash,
        q2_receipt_hash=comparison3.q2_receipt_hash,
        q3_comparison_hash=comparison3.comparison_hash,
        q3_request_hash=comparison3.q3_request.request_hash,
        q3_result_hash=comparison3.q3_result.result_hash,
        q3_receipt_hash=comparison3.q3_receipt.receipt_hash,
        q4_request=request,
        q4_result=result,
        q4_receipt=receipt,
        q2_region_force=comparison3.q2_region_force,
        q3_region_force=comparison3.q3_region_force,
        q4_region_force=region_force,
        q2_total_force=q2,
        q3_total_force=q3,
        q4_total_force=total_force,
        q2_q3_absolute_difference_N=q2_q3_absolute,
        q2_q3_relative_difference=q2_q3_relative,
        q3_q4_absolute_difference_N=q3_q4_absolute,
        q3_q4_relative_difference=q3_q4_relative,
        relative_tolerance=Float64(relative_tolerance),
        absolute_tolerance_N=Float64(absolute_tolerance_N),
        convergence_status=status,
        convergence_protocol=:successive_q2_q3_q4_latest_pair_with_reduction,
        numerical_convergence_assessed=true,
        fresh_q4_executed=true,
        independent_replay_required=true,
        independent_code_validation=false,
        physical_validation=false,
        validation_uq=false,
        promotion_authority=false,
        terminal_authority=false,
        credible_device_count=0,
        evidence_credit=0,
        claim_ceiling=screen_only,
        source_path=_RFQ4_SOURCE,
        source_sha256=_rfq4_sha(_RFQ4_SOURCE))
    comparison = RegionalForceQ4ComparisonV4(_RFQ4_TOKEN,
        values(comparison_body)..., canonical_hash(comparison_body))
    canonical_hash(comparison)
    (comparison=comparison, fq=field_request, fr=field_result,
        bq=basis_request, br=basis_result)
end

function validate_regional_force_q4_execution(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, q3_execution,
        q4_execution)
    validate_regional_force_q3_execution(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, q3_execution)
    (context, geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, _, _, _, _,
        partition_request, partition_result, _, _, _, _) = upstream
    comparison3 = q3_execution.comparison
    comparison4 = q4_execution.comparison
    request = comparison4.q4_request
    request.q3_comparison_hash == comparison3.comparison_hash &&
        request.candidate_hash == comparison3.candidate_hash &&
        request.context_hash == comparison3.context_hash &&
        request.partition_request_hash == canonical_hash(partition_request) &&
        request.partition_result_hash == canonical_hash(partition_result) &&
        request.execution_request_hash == canonical_hash(execution_request) &&
        request.execution_result_hash == canonical_hash(execution_result) &&
        request.execution_receipt_hash == canonical_hash(execution_receipt) &&
        request.physical_support_hash == partition_request.physical_support_hash &&
        request.partition_region_ids ==
            Tuple(region.region_id for region in partition_request.regions) &&
        request.partition_region_hashes ==
            Tuple(region.region_hash for region in partition_request.regions) &&
        request.partition_support_hashes ==
            Tuple(region.region_support_hash for region in partition_request.regions) &&
        request.partition_region_bounds == Tuple((
            rho_lower=Float64(region.rho_lower),
            rho_upper=Float64(region.rho_upper))
            for region in partition_request.regions) &&
        request.partition_interface_hashes ==
            Tuple(canonical_hash(interface) for interface in partition_request.interfaces) &&
        request.nfp == Int(execution_request.runner_payload.nfp) &&
        request.field_request_hash == canonical_hash(q4_execution.fq) &&
        request.basis_request_hash == canonical_hash(q4_execution.bq) ||
        throw(ArgumentError("q4 request upstream identity mismatch"))
    comparison4.q2_request_hash == comparison3.q2_request_hash &&
        comparison4.q2_result_hash == comparison3.q2_result_hash &&
        comparison4.q2_receipt_hash == comparison3.q2_receipt_hash &&
        comparison4.q3_request_hash == comparison3.q3_request.request_hash &&
        comparison4.q3_result_hash == comparison3.q3_result.result_hash &&
        comparison4.q3_receipt_hash == comparison3.q3_receipt.receipt_hash &&
        comparison4.q2_region_force == comparison3.q2_region_force &&
        comparison4.q3_region_force == comparison3.q3_region_force ||
        throw(ArgumentError("q4 comparison q2/q3 identity mismatch"))
    validate_desc_field_provider_result(context, execution_request,
        execution_result, execution_receipt, q4_execution.fq, q4_execution.fr)
    validate_desc_field_basis_bridge_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request, execution_result,
        execution_receipt, q4_execution.fq, q4_execution.fr,
        q4_execution.bq, q4_execution.br)
    validate_regional_force_q4_receipt(comparison4.q4_receipt, request,
        q4_execution.fq, q4_execution.fr, q4_execution.bq, q4_execution.br,
        comparison4.q4_region_force, comparison4.q4_total_force)
    canonical_hash(comparison4)
end

function validate_regional_force_q4_comparison(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, q3_execution,
        q4_execution; run_dir)
    comparison = q4_execution.comparison
    validate_regional_force_q4_execution(upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, q3_execution,
        q4_execution)
    fresh = execute_regional_force_q4(upstream, traction_request, traction_result,
        q2_request, q2_result, q2_execution, q3_execution;
        run_dir=joinpath(String(run_dir), "replay"),
        relative_tolerance=comparison.relative_tolerance,
        absolute_tolerance_N=comparison.absolute_tolerance_N)
    replay = fresh.comparison
    replay.q4_request.nodes == comparison.q4_request.nodes &&
        _rfq4_vectors_isapprox(replay.q4_region_force,
            comparison.q4_region_force; rtol=1e-8, atol=1e-10) &&
        _rfq4_vectors_isapprox((replay.q4_total_force,),
            (comparison.q4_total_force,); rtol=1e-8, atol=1e-10) &&
        isapprox(replay.q3_q4_absolute_difference_N,
            comparison.q3_q4_absolute_difference_N; rtol=1e-8, atol=1e-10) &&
        isapprox(replay.q3_q4_relative_difference,
            comparison.q3_q4_relative_difference; rtol=0, atol=1e-14) &&
        replay.convergence_status === comparison.convergence_status &&
        replay.q4_receipt.output_path != comparison.q4_receipt.output_path ||
        throw(ArgumentError("q4 comparison differs from independent replay"))
    comparison.comparison_hash
end

validate_regional_force_q4_comparison(x::RegionalForceQ4ComparisonV4) =
    canonical_hash(x)
