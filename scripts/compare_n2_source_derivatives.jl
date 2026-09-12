# Bounded same-source geometry-derivative comparison; never physical validation.
using FusionConceptAI
using JSON3
using SHA
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2SourceFourierZernikeV4.jl"))
const N2 = N2SourceFourierZernikeRuntime

function main(output_path::AbstractString)
    isfile(output_path) && error("refusing to overwrite an existing comparison")
    root = normpath(joinpath(@__DIR__, ".."))
    source = joinpath(root, "benchmarks", "desc_heliotron_v0173",
        "HELIOTRON_output.h5")
    interior_result = joinpath(root, "runs",
        "goal_recovery_20260913_012528_cst",
        "n2_desc_heliotron_interior_r1", "result.json")
    receipt_path = joinpath(root, "runs",
        "goal_recovery_20260913_012528_cst",
        "n2_desc_heliotron_derivative_receipt_r1", "result.json")
    expected_receipt_sha = Digest256(
        "ae81285b05ef1ea84101b106e25c53c8dcb8570056bcad047954ddc785a31223")
    N2._n2z_sha(receipt_path) == expected_receipt_sha ||
        error("frozen DESC derivative receipt bytes changed")
    receipt = JSON3.read(read(receipt_path, String))
    receipt.schema_version == "n2-source-interior-derivative-receipt-v1" &&
        receipt.authority.claim_ceiling == "screen_only" &&
        receipt.authority.physical_validation == "unsupported" &&
        receipt.authority.metric_positivity_certified == false &&
        receipt.selected_equilibrium_index == 3 ||
        error("derivative receipt schema or authority mismatch")
    Tuple(Tuple(Int(v) for v in order) for order in receipt.derivative_order) ==
        ((0,0,0), (1,0,0), (0,1,0), (0,0,1)) ||
        error("derivative order changed")
    interior = N2.load_n2_source_interior(source, interior_result, Digest256(
        "fe6258bd0e1368dbc4d0eafef092588e3a95d76842d3c48e4f29c14987d7fcb8"))
    receipt.source_artifact_sha256 == interior.source_artifact_sha256.value &&
        receipt.interior_result_sha256 == interior.result_sha256.value &&
        receipt.interior_subject_sha256 == interior.subject_sha256.value ||
        error("derivative receipt source identity mismatch")
    derivative_tol = Float64(receipt.predeclared_absolute_derivative_tolerance_m)
    gram_tol = Float64(receipt.predeclared_absolute_gram_tolerance_m2)
    derivative_tol == 1e-8 && gram_tol == 1e-7 &&
        length(receipt.rows) == 5 || error("derivative comparison plan changed")
    seen = Set{NTuple{3,Float64}}()
    rows = []
    for row in receipt.rows
        point = Tuple(Float64(v) for v in row.node_rho_theta_zeta_radians)
        length(point) == 3 && all(isfinite, point) && 0 <= point[1] <= 1 &&
            point ∉ seen || error("invalid or duplicate derivative node")
        push!(seen, point)
        value = N2.evaluate_n2_source_gram(interior, point...)
        radial = (value.chart.R_m, value.chart.dR.rho,
            value.chart.dR.theta, value.chart.dR.zeta)
        vertical = (value.chart.Z_m, value.chart.dZ.rho,
            value.chart.dZ.theta, value.chart.dZ.zeta)
        errors = [abs(actual[i] - Float64(expected[i]))
            for (actual, expected) in ((radial, row.desc_R_and_derivatives_m),
                (vertical, row.desc_Z_and_derivatives_m)) for i in 1:4]
        gram_errors = [abs(value.gram[i][j] -
            Float64(row.desc_cartesian_gram_m2[i][j]))
            for i in 1:3 for j in 1:3]
        push!(rows, (node_rho_theta_zeta_radians=point,
            maximum_absolute_RZ_derivative_error_m=maximum(errors),
            maximum_absolute_gram_error_m2=maximum(gram_errors),
            pass=maximum(errors) <= derivative_tol &&
                maximum(gram_errors) <= gram_tol))
    end
    all_pass = all(row.pass for row in rows)
    result = (schema_version="n2-Julia-source-derivative-comparison-v1",
        source_artifact_sha256=interior.source_artifact_sha256.value,
        source_manifest_sha256=N2._n2z_sha(joinpath(dirname(source), "source.json")).value,
        interior_result_sha256=interior.result_sha256.value,
        interior_subject_sha256=interior.subject_sha256.value,
        desc_derivative_receipt_sha256=expected_receipt_sha.value,
        julia_program_sha256=N2._n2z_sha(joinpath(root, "src", "RuntimeV4",
            "N2SourceFourierZernikeV4.jl")).value,
        derivative_tolerance_m=derivative_tol,
        gram_tolerance_m2=gram_tol, rows=rows,
        maximum_absolute_RZ_derivative_error_m=maximum(
            row.maximum_absolute_RZ_derivative_error_m for row in rows),
        maximum_absolute_gram_error_m2=maximum(
            row.maximum_absolute_gram_error_m2 for row in rows),
        all_nodes_pass=all_pass,
        authority=(scope="same_DESC_family_analytic_geometry_comparison_only",
            claim_ceiling="screen_only", metric_positivity_certified=false,
            provider_executed=false, independent_physical_solver=false,
            physical_validation="unsupported", credible_device_count=0))
    mkpath(dirname(output_path))
    isfile(output_path) && error("refusing to overwrite an existing comparison")
    open(output_path, "w") do stream
        JSON3.pretty(stream, result)
        println(stream)
    end
    println("N2_JULIA_DERIVATIVE_COMPARISON_OUTPUT=", abspath(output_path))
    println("N2_JULIA_DERIVATIVE_COMPARISON_PASS=", Int(all_pass))
    println("N2_PHYSICAL_VALIDATION=unsupported")
    all_pass ? 0 : 4
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("usage: compare_n2_source_derivatives.jl NEW_RESULT_JSON")
    exit(main(ARGS[1]))
end
