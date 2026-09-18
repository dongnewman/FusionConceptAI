"""Fixture constructors/documentation for the declared G1/G2/G3 R21 slice.

The focused Julia test is an independent command supplied for a controlled
lane.  This file keeps the numeric fixture in one place without creating a
provider, mesh backend or solver process.
"""

const DGD_FIXTURE_CANDIDATE_V1 = "local://candidate/up1-04a"
const DGD_FIXTURE_EXPRESSION_SUBSET_V1 = :diagonal_affine_static

function dgd_fixture_numeric_v1()
    (candidate=DGD_FIXTURE_CANDIDATE_V1,
     expression_subset=DGD_FIXTURE_EXPRESSION_SUBSET_V1,
     g2_cells=(2, 3, 4),
     g2_mesh_execution_status=:not_executed,
     old_state=(0.25, 0.75),
     overlap=(0.5, 2.5), transfer_weights=(1.0, 1.0),
     transferred_state=(0.25, 0.75), conservation_residual=0.0,
     k_faces=(2.0, 2.05, 2.1),
     k_evaluation_api=:diagonal_matrix_tuple_scalar_extraction,
     source=(1.0, 1.0),
     boundary=(0.0, 1.0),
     matrix=((9.1125, -4.6125), (-4.6125, 9.3375)),
     rhs=(1.1666666666666667, 2.666666666666667),
     solution=(0.36346540908222763, 0.4651299454948799),
     residual_norm=8.005932084973442e-16, residual_tolerance=1.0e-13,
     source_power=120.0, field_power=90.0, return_power=15.0, heat_power=15.0,
     provider_calls=0, mesh_calls=0, solver_calls=1,
     compile_status=:ready, g2_admission_status=:terminal_deferred,
     g2_resolution=:terminal_deferred, g3_admission_status=:proposal,
     g3_resolution=:terminal_deferred, composition_status=:terminal_deferred,
     numerical_status=:ready, aggregate_status=:terminal_deferred,
     claim_ceiling=:screen_only, accepted=false,
     formal_up_credit=false, formal_r_credit=false)
end

"""Exact name/status/code map observed by the focused product dispatch.

The independent oracle repeats this map as data.  The Julia test constructs
each receipt from the real dispatch and compares that observation to this
fixture, so the negative set cannot pass by comparing two literals.
"""
function dgd_fixture_negative_gates_v1()
    Dict{String,Tuple{String,String}}(
        "candidate_mismatch" => ("fail_closed", "candidate_mismatch"),
        "body_hash_mismatch" => ("fail_closed", "bundle_body_hash_mismatch"),
        "bundle_hash_mismatch" => ("fail_closed", "bundle_hash_mismatch"),
        "unsupported_expression_subset" => ("terminal_deferred", "unsupported_expression_subset"),
        "missing_mesh_authority" => ("terminal_deferred", "g2_admission_terminal_deferred"),
        "missing_feedback_authority" => ("terminal_deferred", "g3_admission_terminal_deferred"),
        "invalid_overlap" => ("terminal_deferred", "invalid_overlap"),
        "singular_sparse_system" => ("numerical_fail", "singular_or_nonfinite_sparse_system"),
        "nonfinite_derived" => ("numerical_fail", "singular_or_nonfinite_sparse_system"),
        "ledger_contradiction" => ("fail_closed", "ledger_contradiction"))
end
