using Test
using FusionConceptAI

const _UP2_ENTRY_PATH = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2", "UP2ModuleEntryV1.jl")
const _UP2_ENTRY_TEXT = read(_UP2_ENTRY_PATH, String)

@testset "UP2 additive module entry" begin
    @test FusionConceptAI.up2_module_dependency_order() ==
        (:genome_v5_components, :precompiler_counter, :precompiler_contract,
         :precompiler_validator, :e0_bound_input, :n03_time_authority,
         :n04_ledger_authority, :n05_flux_authority, :n06_source_field_ledger,
         :n07_n08_geometry, :n09_provider_gap, :n10_identity_receipt)
    @test FusionConceptAI.up2_module_load_state() == :loaded
    @test occursin("genome_v5_component_layer_order() == (:G1, :G2, :G3)", _UP2_ENTRY_TEXT)
    @test occursin("load_genome_v5_components!()", _UP2_ENTRY_TEXT)
    @test occursin("_UP2_MODULE_LOAD_STATE[] === :loaded && return nothing", _UP2_ENTRY_TEXT)
    @test occursin("_UP2_MODULE_LOAD_STATE[] === :failed &&", _UP2_ENTRY_TEXT)
    @test occursin("use a fresh process", _UP2_ENTRY_TEXT)
    @test occursin("PrecompilerInvocationCounterV1.jl", _UP2_ENTRY_TEXT)
    @test occursin("UP2CandidatePhysicalBindingV1.jl", _UP2_ENTRY_TEXT)
    @test occursin("N05FluxAuthorityProjectionV1.jl", _UP2_ENTRY_TEXT)
    @test occursin("N06SourceFieldLedgerMappingV1.jl", _UP2_ENTRY_TEXT)
    @test !occursin("up2_provider!", _UP2_ENTRY_TEXT)
    @test !occursin("integrate_genome_v5", _UP2_ENTRY_TEXT)
    for symbol in (:UP2InvocationCounterV1, :UP2PrecompilerInputV1,
                   :UP2CandidatePhysicalBindingV1, :N03TimeAuthorityProjectionV1,
                   :N04LedgerProjectionV1, :UP2N05AuthorityV1,
                   :N06SourceFieldLedgerMappingV1, :N07N08ProjectionV1,
                   :N09ProviderGapProjectionV1, :N10IdentityProjectionV1)
        @test isdefined(FusionConceptAI, symbol)
    end
    # This is a constructor/static wiring check only. It is not a downstream
    # spy and cannot be used as runtime evidence that another stage ran zero
    # calls; that stronger gate belongs to a later integrated runner.
    counter = FusionConceptAI.UP2InvocationCounterV1()
    @test counter.compile_calls == 0
    @test counter.provider_calls == 0
    @test counter.solver_calls == 0
end
