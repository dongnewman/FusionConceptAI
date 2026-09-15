"""Idempotent additive loader for the UP2 contract-only components.

The entry point loads the existing G1/G2/G3 layers first, then registers the
UP2 definitions in a stable dependency order.  It includes definitions only:
no provider, compiler, solver, mesh, or physical execution is started here.
Focused runners may continue to include an individual UP2 file; the sentinel
checks below make a later shared load a no-op for definitions already present.
"""

const _UP2_MODULE_LOAD_STATE = Ref{Symbol}(:unloaded)
const _UP2_MODULE_LOAD_ORDER = (
    :genome_v5_components,
    :precompiler_counter,
    :precompiler_contract,
    :precompiler_validator,
    :e0_bound_input,
    :n03_time_authority,
    :n04_ledger_authority,
    :n05_flux_authority,
    :n06_source_field_ledger,
    :n07_n08_geometry,
    :n09_provider_gap,
    :n10_identity_receipt,
)

up2_module_load_state() = _UP2_MODULE_LOAD_STATE[]
up2_module_dependency_order() = _UP2_MODULE_LOAD_ORDER

function _up2_include_definition_once!(file::AbstractString, sentinel::Symbol)
    isdefined(@__MODULE__, sentinel) ||
        Base.include(@__MODULE__, joinpath(@__DIR__, file))
    isdefined(@__MODULE__, sentinel) ||
        throw(ArgumentError("UP2 definition did not register sentinel $sentinel"))
    nothing
end

"""Load all UP2 definitions once, after the concrete G1/G2/G3 layers."""
function load_genome_v5_up2_components!()
    _UP2_MODULE_LOAD_STATE[] === :loaded && return nothing
    _UP2_MODULE_LOAD_STATE[] === :failed &&
        throw(ArgumentError("UP2 module load previously failed; use a fresh process"))
    _UP2_MODULE_LOAD_STATE[] === :loading &&
        throw(ArgumentError("recursive UP2 module loading"))
    _UP2_MODULE_LOAD_STATE[] = :loading
    try
        genome_v5_component_layer_order() == (:G1, :G2, :G3) ||
            throw(ArgumentError("unexpected GenomeV5 component dependency order"))
        load_genome_v5_components!()
        _up2_include_definition_once!("PrecompilerInvocationCounterV1.jl", :UP2InvocationCounterV1)
        _up2_include_definition_once!("TypedPrecompilerContractV1.jl", :UP2PrecompilerInputV1)
        _up2_include_definition_once!("TypedPrecompilerValidatorV1.jl", :up2_validate_input)
        _up2_include_definition_once!("UP2CandidatePhysicalBindingV1.jl", :UP2CandidatePhysicalBindingV1)
        _up2_include_definition_once!("N03TimeAuthorityProjectionV1.jl", :N03TimeAuthorityProjectionV1)
        _up2_include_definition_once!("N04LedgerAuthorityProjectionV1.jl", :N04LedgerProjectionV1)
        _up2_include_definition_once!("N05FluxAuthorityProjectionV1.jl", :UP2N05AuthorityV1)
        _up2_include_definition_once!("N06SourceFieldLedgerMappingV1.jl", :N06SourceFieldLedgerMappingV1)
        _up2_include_definition_once!("N07N08GeometryProjectionV1.jl", :N07N08ProjectionV1)
        _up2_include_definition_once!("N09ProviderGapProjectionV1.jl", :N09ProviderGapProjectionV1)
        _up2_include_definition_once!("N10IdentityReceiptProjectionV1.jl", :N10IdentityProjectionV1)
        _UP2_MODULE_LOAD_STATE[] = :loaded
    catch
        _UP2_MODULE_LOAD_STATE[] = :failed
        rethrow()
    end
    nothing
end
