"""Explicit, idempotent definition loader for the native-source T2 path.

Loading registers constructors and consumers only. Actual source admission,
formal evidence validation, and receipt production remain explicit operations.
"""

const _VNEXT_T2_MODULE_LOAD_STATE_V2 = Ref{Symbol}(:unloaded)
const _VNEXT_T2_MODULE_DEFINITIONS_V2 = (
    ("GenomeV5/G1/DiffusionDeclarationV1.jl", :G1DiffusionDeclarationV1),
    ("GenomeV5/G1/G1SourceAuthorityFactoryV1.jl", :G1SourceFactoryConstructionResultV1),
    ("GenomeV5/G2/MetricBoundaryDeclarationV1.jl", :G2MBDeclarationV1),
    ("GenomeV5/G2/G2SourceAuthorityFactoryV1.jl", :G2SourceFactoryConstructionResultV1),
    ("GenomeV5/G3/G3SourceFeedbackLawV1.jl", :G3SFDeclarationV1),
    ("GenomeV5/G3/G3SourceAuthorityFactoryV1.jl", :G3FactoryConstructionResultV1),
    ("GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl", :VNextT0LocalTransportV1),
    ("GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl", :VNextAuthorityRecheckLocalResultV1),
    ("GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl", :T0LocalParentBaselineBindResultV1),
    ("GenomeV5/G3/G3RealizationChildEditabilityV1.jl", :G3RealizationSourceStateV1),
    ("GenomeV5/G3/G3ControlChildEditabilityV1.jl", :G3ControlStateV1),
    ("GenomeV5/G3/G3BindingChildEditabilityV1.jl", :G3BindingStateV1),
    ("GenomeV5/G3/G3BindingChildEditabilityV2.jl", :G3BindingStateV2),
    ("GenomeV5/Integration/VNextG3BindingAuthorityBridgeLocalV1.jl", :VNextG3BindingAuthorityExpectedCommitmentV1),
    ("GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl", :VNextT2ConcreteSourceWitnessV3),
    ("Contracts/VNextT1CanonicalBytesV2.jl", :VNextT1CanonicalBytesV2),
    ("Contracts/VNextT1CandidateBindingV2.jl", :VNextT1CandidateBindingInputV2),
    ("GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl", :VNextAuthorityRecheckLocalV2Input),
    ("Contracts/CandidateStatePackageV5NextV2.jl", :CandidateStatePackageV5NextV2),
    ("GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl", :VNextT1AdmissionInputV2),
    ("Contracts/VNextT1PackageBindingAdapterV2.jl", :VNextT1PackageBindingAdapterResultV2),
    ("GenomeV5/UP2/VNextT2UP2AdapterV2.jl", :VNextT2UP2BoundInputV2),
    ("GenomeV5/UP2/VNextT2IdentityReceiptProjectionV2.jl", :VNextT2IdentityProjectionV2),
    ("GenomeV5/Integration/VNextT2IdentityReceiptIntegrationV2.jl", :VNextT2ReceiptLedgerV2),
    ("GenomeV5/Integration/VNextCurrentSourceT0T1EntryV1.jl", :vnext_current_source_t0_t1_local_v1),
    ("GenomeV5/Integration/VNextUP3ThermalQueueChildV1.jl", :VNextUP3ThermalQueueChildV1),
)

vnext_t2_module_load_state_v2() = _VNEXT_T2_MODULE_LOAD_STATE_V2[]
vnext_t2_module_dependency_order_v2() = _VNEXT_T2_MODULE_DEFINITIONS_V2

if !isdefined(@__MODULE__, :NativeGitReadCompatibilityV1)
    Base.include(@__MODULE__, joinpath(@__DIR__, "NativeGitReadCompatibilityV1.jl"))
end

"""Load the actual native T2 definitions once after the concrete Genome layers."""
function load_vnext_t2_components_v2!()
    state = _VNEXT_T2_MODULE_LOAD_STATE_V2[]
    state === :loaded && return nothing
    state === :failed && throw(ArgumentError("T2 definition load previously failed; use a fresh process"))
    state === :loading && throw(ArgumentError("recursive T2 definition loading"))
    _VNEXT_T2_MODULE_LOAD_STATE_V2[] = :loading
    try
        genome_v5_component_layer_order() == (:G1, :G2, :G3) ||
            throw(ArgumentError("unexpected GenomeV5 component dependency order"))
        load_genome_v5_components!()
        source_root = normpath(joinpath(@__DIR__, "..", ".."))
        for (relative_path, sentinel) in _VNEXT_T2_MODULE_DEFINITIONS_V2
            isdefined(@__MODULE__, sentinel) ||
                Base.include(@__MODULE__, joinpath(source_root, relative_path))
            isdefined(@__MODULE__, sentinel) ||
                throw(ArgumentError("T2 definition did not register sentinel $sentinel"))
        end
        isdefined(@__MODULE__, :vnext_t2_rebind_identity_receipts_v2) ||
            throw(ArgumentError("T2 receipt consumer did not register"))
        _VNEXT_T2_MODULE_LOAD_STATE_V2[] = :loaded
    catch
        _VNEXT_T2_MODULE_LOAD_STATE_V2[] = :failed
        rethrow()
    end
    nothing
end

function __init__()
    NativeGitReadCompatibilityV1.initialize_frozen_runtime!(; required=false)
    nothing
end
