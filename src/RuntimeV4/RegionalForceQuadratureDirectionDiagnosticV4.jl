using FusionConceptAI
using LinearAlgebra
using SHA

import FusionConceptAI: Digest256, ClaimCeiling, canonical_hash, semantic_view,
    screen_only

const _RFDD_SOURCE = abspath(@__FILE__)
const _RFDD_CONFIGS = (
    (:radial2_angular4, 2, 4),
    (:radial3_angular4, 3, 4),
    (:radial4_angular2, 4, 2),
    (:radial4_angular3, 4, 3),
)
const _RFDD_LABELS = (
    :radial2_angular4,
    :radial3_angular4,
    :radial4_angular2,
    :radial4_angular3,
    :q4_shared,
)

_rfdd_sha(path) = Digest256(bytes2hex(SHA.sha256(read(path))))
_rfdd_sum(values) = ntuple(k -> sum(value[k] for value in values), 3)
_rfdd_delta(a, b) = norm(collect(b) .- collect(a))
function _rfdd_output_text(configs, differences)
    config_lines = ("CONFIG\t$(c.label)\t$(c.radial_order)\t$(c.angular_order)\t" *
        join(c.total_force, '\t') for c in configs)
    difference_lines = ("DIFF\t$(d.axis)\t$(d.from_order)\t$(d.to_order)\t" *
        string(d.absolute_difference_N) for d in differences)
    join((config_lines..., difference_lines...), "\n") * "\n"
end

struct RegionalForceDirectionConfigV4
    label::Symbol
    radial_order::Int
    angular_order::Int
    region_ids::Tuple
    region_force::Tuple
    total_force::NTuple{3,Float64}
    field_request_hash::Digest256
    field_result_hash::Digest256
    field_receipt_hash::Digest256
    basis_request_hash::Digest256
    basis_result_hash::Digest256
    basis_receipt_hash::Digest256
end

semantic_view(config::RegionalForceDirectionConfigV4) =
    NamedTuple{fieldnames(typeof(config))}(
        ntuple(i -> getfield(config, i), fieldcount(typeof(config))))

struct RegionalForceQuadratureDirectionDiagnosticV4
    q4_comparison_hash::Digest256
    candidate_hash::Digest256
    context_hash::Digest256
    partition_request_hash::Digest256
    partition_result_hash::Digest256
    region_ids::Tuple
    output_path::String
    output_sha256::Digest256
    configs::Tuple
    adjacent_differences::Tuple
    missing_capabilities::Tuple
    status::Symbol
    claim_ceiling::ClaimCeiling
    evidence_credit::Int
    source_path::String
    source_sha256::Digest256
    diagnostic_hash::Digest256
    function RegionalForceQuadratureDirectionDiagnosticV4(
            token::Val{:rfdd_private}, fields...)
        token === Val(:rfdd_private) ||
            throw(ArgumentError("private diagnostic constructor"))
        new(fields...)
    end
end

semantic_view(diagnostic::RegionalForceQuadratureDirectionDiagnosticV4) =
    NamedTuple{fieldnames(typeof(diagnostic))[1:end-1]}(
        ntuple(i -> getfield(diagnostic, i), fieldcount(typeof(diagnostic)) - 1))

function canonical_hash(diagnostic::RegionalForceQuadratureDirectionDiagnosticV4)
    !isempty(diagnostic.region_ids) && length(unique(diagnostic.region_ids)) == length(diagnostic.region_ids) ||
        throw(ArgumentError("invalid diagnostic region identity"))
    length(diagnostic.configs) == length(_RFDD_LABELS) &&
        Tuple(config.label for config in diagnostic.configs) == _RFDD_LABELS &&
        Tuple((config.radial_order, config.angular_order)
            for config in diagnostic.configs) ==
            ((2, 4), (3, 4), (4, 2), (4, 3), (4, 4)) ||
        throw(ArgumentError("invalid direction diagnostic configuration set"))
    all(config -> config isa RegionalForceDirectionConfigV4 &&
        config.region_ids == diagnostic.region_ids &&
        !isempty(config.region_force) &&
        all(value -> length(value) == 3 && all(isfinite, value),
            config.region_force) &&
        config.total_force == _rfdd_sum(config.region_force),
        diagnostic.configs) ||
        throw(ArgumentError("invalid direction diagnostic force values"))
    radial2, radial3, angular2, angular3, shared = diagnostic.configs
    expected_differences = (
        (axis=:radial, from_order=2, to_order=3,
            absolute_difference_N=_rfdd_delta(radial2.total_force,
                radial3.total_force)),
        (axis=:radial, from_order=3, to_order=4,
            absolute_difference_N=_rfdd_delta(radial3.total_force,
                shared.total_force)),
        (axis=:angular, from_order=2, to_order=3,
            absolute_difference_N=_rfdd_delta(angular2.total_force,
                angular3.total_force)),
        (axis=:angular, from_order=3, to_order=4,
            absolute_difference_N=_rfdd_delta(angular3.total_force,
                shared.total_force)),
    )
    diagnostic.adjacent_differences == expected_differences ||
        throw(ArgumentError("direction diagnostic difference mismatch"))
    diagnostic.status === :diagnostic_only &&
        diagnostic.claim_ceiling == screen_only &&
        diagnostic.evidence_credit == 0 &&
        diagnostic.missing_capabilities ==
            (:anisotropic_convergence, :independent_formulation) &&
        isfile(diagnostic.source_path) &&
        _rfdd_sha(diagnostic.source_path) == diagnostic.source_sha256 ||
        throw(ArgumentError("invalid direction diagnostic authority"))
    isfile(diagnostic.output_path) &&
        _rfdd_sha(diagnostic.output_path) == diagnostic.output_sha256 &&
        read(diagnostic.output_path, String) == _rfdd_output_text(
            diagnostic.configs, diagnostic.adjacent_differences) ||
        throw(ArgumentError("diagnostic output sealing mismatch"))
    expected = canonical_hash(semantic_view(diagnostic))
    expected == diagnostic.diagnostic_hash ||
        throw(ArgumentError("diagnostic hash mismatch"))
    expected
end

function _rfdd_nodes(q4_comparison, radial_order, angular_order)
    request = q4_comparison.q4_request
    radial_nodes, radial_weights = radial_order == 4 ? (
        (-sqrt((3 + 2sqrt(6 / 5)) / 7),
            -sqrt((3 - 2sqrt(6 / 5)) / 7),
            sqrt((3 - 2sqrt(6 / 5)) / 7),
            sqrt((3 + 2sqrt(6 / 5)) / 7)),
        ((18 - sqrt(30)) / 36, (18 + sqrt(30)) / 36,
            (18 + sqrt(30)) / 36, (18 - sqrt(30)) / 36)) :
        radial_order == 3 ? ((-sqrt(3 / 5), 0.0, sqrt(3 / 5)),
            (5 / 9, 8 / 9, 5 / 9)) :
        radial_order == 2 ? ((-1 / sqrt(3), 1 / sqrt(3)), (1.0, 1.0)) :
        throw(ArgumentError("unsupported radial order"))
    angular_order in (2, 3, 4) ||
        throw(ArgumentError("unsupported angular order"))
    nodes = NamedTuple[]
    for j in eachindex(request.partition_region_ids)
        lower = request.partition_region_bounds[j].rho_lower
        upper = request.partition_region_bounds[j].rho_upper
        for ir in eachindex(radial_nodes), it in 1:angular_order,
                iz in 1:angular_order
            push!(nodes, (
                region_id=request.partition_region_ids[j],
                region_hash=request.partition_region_hashes[j],
                region_support_hash=request.partition_support_hashes[j],
                local_index=(ir, it, iz),
                point=DESCFieldSamplePointV4(
                    (lower + upper) / 2 +
                        (upper - lower) / 2 * radial_nodes[ir],
                    (it - 0.5) * 2pi / angular_order,
                    (iz - 0.5) * 2pi /
                        (angular_order * request.nfp)),
                weight=(upper - lower) / 2 * radial_weights[ir] *
                    2pi / angular_order *
                    2pi / (angular_order * request.nfp) * request.nfp,
            ))
        end
    end
    Tuple(nodes)
end

function _rfdd_execute_config(label, radial_order, angular_order,
        q4_comparison, context, execution_request, execution_result,
        execution_receipt, geometry_bridge, geometry_evaluation,
        geometry_proof, run_dir)
    nodes = _rfdd_nodes(q4_comparison, radial_order, angular_order)
    points = Tuple(node.point for node in nodes)
    field_request = make_desc_field_provider_request(context, execution_request,
        execution_result, execution_receipt, points)
    field_result = execute_desc_field_provider(context, execution_request,
        execution_result, execution_receipt, field_request;
        run_dir=joinpath(run_dir, String(label), "field"))
    basis_request = make_desc_field_basis_bridge_request(context,
        geometry_bridge, geometry_evaluation, geometry_proof, execution_request,
        execution_result, execution_receipt, field_request, field_result)
    basis_result = execute_desc_field_basis_bridge(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result, basis_request;
        run_dir=joinpath(run_dir, String(label), "basis"))
    validate_desc_field_provider_result(context, execution_request,
        execution_result, execution_receipt, field_request, field_result)
    validate_desc_field_basis_bridge_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request, execution_result,
        execution_receipt, field_request, field_result, basis_request, basis_result)
    region_force = Tuple(ntuple(k -> sum(
        basis_result.samples[i].F_cartesian_xyz_N_m3[k] *
            basis_result.samples[i].sqrt_g_m3 * nodes[i].weight
        for i in eachindex(nodes) if nodes[i].region_id == region_id), 3)
        for region_id in q4_comparison.q4_request.partition_region_ids)
    RegionalForceDirectionConfigV4(label, radial_order, angular_order,
        q4_comparison.q4_request.partition_region_ids, region_force, _rfdd_sum(region_force), canonical_hash(field_request),
        canonical_hash(field_result), canonical_hash(field_result.receipt),
        canonical_hash(basis_request), canonical_hash(basis_result),
        canonical_hash(basis_result.receipt))
end

function execute_regional_force_quadrature_direction_diagnostic(q4_execution,
        q4_comparison, q3_upstream, traction_request, traction_result,
        q2_request, q2_result, q2_execution, q3_execution;
        run_dir)
    (context, geometry_bridge, geometry_evaluation, geometry_proof,
        execution_request, execution_result, execution_receipt, _, _, _, _,
        partition_request, partition_result, _, _, _, _) = q3_upstream
    validate_regional_force_q4_execution(q3_upstream, traction_request,
        traction_result, q2_request, q2_result, q2_execution, q3_execution,
        q4_execution)
    canonical_hash(q4_comparison)
    q4_execution.comparison.comparison_hash == q4_comparison.comparison_hash &&
        q4_comparison.q4_request.candidate_hash == context.candidate_hash &&
        q4_comparison.q4_request.context_hash == context.context_hash &&
        q4_comparison.q4_request.field_request_hash ==
            canonical_hash(q4_execution.fq) &&
        q4_comparison.q4_request.basis_request_hash ==
            canonical_hash(q4_execution.bq) &&
        q4_comparison.q4_receipt.field_result_hash ==
            canonical_hash(q4_execution.fr) &&
        q4_comparison.q4_receipt.field_receipt_hash ==
            canonical_hash(q4_execution.fr.receipt) &&
        q4_comparison.q4_receipt.basis_result_hash ==
            canonical_hash(q4_execution.br) &&
        q4_comparison.q4_receipt.basis_receipt_hash ==
            canonical_hash(q4_execution.br.receipt) ||
        throw(ArgumentError("q4 execution identity mismatch"))
    validate_desc_field_provider_result(context, execution_request,
        execution_result, execution_receipt, q4_execution.fq, q4_execution.fr)
    validate_desc_field_basis_bridge_result(context, geometry_bridge,
        geometry_evaluation, geometry_proof, execution_request, execution_result,
        execution_receipt, q4_execution.fq, q4_execution.fr,
        q4_execution.bq, q4_execution.br)

    root = abspath(String(run_dir))
    mkpath(root)
    fresh_configs = Tuple(_rfdd_execute_config(config...,
        q4_comparison, context, execution_request, execution_result,
        execution_receipt, geometry_bridge, geometry_evaluation,
        geometry_proof, root) for config in _RFDD_CONFIGS)
    shared = RegionalForceDirectionConfigV4(:q4_shared, 4, 4,
        q4_comparison.q4_request.partition_region_ids,
        q4_comparison.q4_region_force, q4_comparison.q4_total_force,
        canonical_hash(q4_execution.fq), canonical_hash(q4_execution.fr),
        canonical_hash(q4_execution.fr.receipt), canonical_hash(q4_execution.bq),
        canonical_hash(q4_execution.br), canonical_hash(q4_execution.br.receipt))
    configs = (fresh_configs..., shared)
    radial2, radial3, angular2, angular3, q4 = configs
    differences = (
        (axis=:radial, from_order=2, to_order=3,
            absolute_difference_N=_rfdd_delta(radial2.total_force,
                radial3.total_force)),
        (axis=:radial, from_order=3, to_order=4,
            absolute_difference_N=_rfdd_delta(radial3.total_force,
                q4.total_force)),
        (axis=:angular, from_order=2, to_order=3,
            absolute_difference_N=_rfdd_delta(angular2.total_force,
                angular3.total_force)),
        (axis=:angular, from_order=3, to_order=4,
            absolute_difference_N=_rfdd_delta(angular3.total_force,
                q4.total_force)),
    )
    output_path = joinpath(root, "regional_force_direction_diagnostic.tsv")
    write(output_path, _rfdd_output_text(configs, differences))
    body = (
        q4_comparison_hash=canonical_hash(q4_comparison),
        candidate_hash=context.candidate_hash,
        context_hash=context.context_hash,
        partition_request_hash=q4_comparison.q4_request.partition_request_hash,
        partition_result_hash=q4_comparison.q4_request.partition_result_hash,
        region_ids=q4_comparison.q4_request.partition_region_ids,
        output_path=output_path,
        output_sha256=_rfdd_sha(output_path),
        configs=configs,
        adjacent_differences=differences,
        missing_capabilities=(:anisotropic_convergence, :independent_formulation),
        status=:diagnostic_only,
        claim_ceiling=screen_only,
        evidence_credit=0,
        source_path=_RFDD_SOURCE,
        source_sha256=_rfdd_sha(_RFDD_SOURCE),
    )
    diagnostic = RegionalForceQuadratureDirectionDiagnosticV4(
        Val(:rfdd_private), values(body)..., canonical_hash(body))
    canonical_hash(diagnostic)
    diagnostic
end

validate_regional_force_quadrature_direction_diagnostic(
    diagnostic::RegionalForceQuadratureDirectionDiagnosticV4) =
    canonical_hash(diagnostic)
