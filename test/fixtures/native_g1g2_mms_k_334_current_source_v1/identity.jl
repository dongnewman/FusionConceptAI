# Target: factory -> T0 transport/authority recheck -> V1/V2 -> T1 V2 -> V3.
# Next gate: one 240s / 2 GiB local software source-admission run, with no solver.
# Status: unvalidated_design_input; include once inside FusionConceptAI after native schemas.
const UP4_R2_IDENTITY = (
    candidate_id = "native-g1g2-diffusion-mms-current-source-v1",
    candidate_ref = QualifiedRefV1("fusionconceptai://candidate/native-g1g2-diffusion-mms-v1", "v5"),
    scenario_id = "scenario-native-g1g2-diffusion-mms-current-source-v1",
    scenario_ref = QualifiedRefV1("fusionconceptai://scenario-design/scenario-native-g1g2-diffusion-mms-current-source-v1", "v1"),
    design_status = :unvalidated_design_input,
)