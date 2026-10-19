# Target: factory -> T0 transport/authority recheck -> V1/V2 -> T1 V2 -> V3.
# Next gate: one 240s / 2 GiB local software source-admission run, with no solver.
# Status: unvalidated_design_input; include once inside FusionConceptAI after native schemas.
const UP4_R2_IDENTITY = (
    candidate_id = "local-authored-up4-g123-20260928-r2",
    candidate_ref = QualifiedRefV1("fusionconceptai://candidate-design/local-authored-up4-g123-20260928-r2", "v5"),
    scenario_id = "scenario-local-authored-up4-g123-20260928-r2",
    scenario_ref = QualifiedRefV1("fusionconceptai://scenario-design/scenario-local-authored-up4-g123-20260928-r2", "v1"),
    design_status = :unvalidated_design_input,
)