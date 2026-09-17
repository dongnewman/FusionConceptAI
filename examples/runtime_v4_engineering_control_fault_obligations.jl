include(joinpath(@__DIR__, "runtime_v4_forward_chain_context.jl"))
const CapabilitySignatureV4 = ForwardChainContextRuntime.CapabilitySignatureV4
const validate_forward_chain_context = ForwardChainContextRuntime.validate_forward_chain_context
const forward_graph_binding = ForwardChainContextRuntime.forward_graph_binding
import FusionConceptAI: canonical_hash, semantic_view
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "EngineeringControlFaultObligationsV4.jl"))
const eco_scenario = ControlFaultCaseV4("startup fault", "startup", (current=(0.0,10.0), temperature=(0.0,80.0)); delay_ms=2.0, dropout_probability=0.01, fault_mode=:sensor_dropout, recovery="hold safe state")
const eco_capability = first(forward_context.obligations)
const eco_site = first(ForwardChainContextRuntime.forward_graph_binding(forward_context, :control).node_identity_hashes)
const eco_obligations = (EngineeringControlFaultObligationV4("controller observation", :control, :control, eco_site, eco_capability, :manufactured_control), EngineeringControlFaultObligationV4("fault recovery", :fault, :control, eco_site, eco_capability, :fault_recovery; recovery=RecoveryRequirementV4("recover", :dropout, "hold", 100.0, eco_capability, :fault_recovery)))
const eco_request = build_engineering_control_fault_request(forward_context, eco_scenario, eco_obligations)
