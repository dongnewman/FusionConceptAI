using SHA
using FusionConceptAI

const CLEAN_LOAD_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))

length(ARGS) == 1 || error("expected one output receipt path")
const CLEAN_LOAD_OUTPUT = abspath(ARGS[1])
isfile(CLEAN_LOAD_OUTPUT) && error(:clean_load_output_already_exists)
mkpath(dirname(CLEAN_LOAD_OUTPUT))

isdefined(FusionConceptAI, :load_vnext_t2_components_v2!) ||
    error(:vnext_t2_shared_loader_not_connected)
isdefined(FusionConceptAI, :vnext_t2_module_load_state_v2) ||
    error(:vnext_t2_shared_loader_state_not_connected)
isdefined(FusionConceptAI, :vnext_t2_module_dependency_order_v2) ||
    error(:vnext_t2_shared_loader_manifest_not_connected)

state_before = FusionConceptAI.vnext_t2_module_load_state_v2()
state_before === :unloaded ||
    error((:vnext_t2_clean_load_initial_state_invalid, state_before))
registry_before = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
dependencies = FusionConceptAI.vnext_t2_module_dependency_order_v2()
length(dependencies) == 24 ||
    error((:vnext_t2_dependency_count_invalid, length(dependencies)))

FusionConceptAI.load_vnext_t2_components_v2!()
state_after_first = FusionConceptAI.vnext_t2_module_load_state_v2()
state_after_first === :loaded ||
    error((:vnext_t2_first_load_state_invalid, state_after_first))
missing_after_first = Tuple(String(sentinel) for (_, sentinel) in dependencies
    if !isdefined(FusionConceptAI, sentinel))
isempty(missing_after_first) ||
    error((:vnext_t2_first_load_missing_sentinels, missing_after_first))

FusionConceptAI.load_vnext_t2_components_v2!()
state_after_second = FusionConceptAI.vnext_t2_module_load_state_v2()
state_after_second === :loaded ||
    error((:vnext_t2_second_load_state_invalid, state_after_second))
missing_after_second = Tuple(String(sentinel) for (_, sentinel) in dependencies
    if !isdefined(FusionConceptAI, sentinel))
isempty(missing_after_second) ||
    error((:vnext_t2_second_load_missing_sentinels, missing_after_second))
registry_after = FusionConceptAI.canonical_hash(
    FusionConceptAI.default_operator_registry())
registry_after == registry_before ||
    error(:vnext_t2_clean_load_changed_default_registry)

receipt = (
    schema="vnext-t2-shared-module-clean-load-receipt-r1",
    repository_root=CLEAN_LOAD_ROOT,
    process_id=getpid(),
    julia_threads=Threads.nthreads(),
    state_before=state_before,
    state_after_first=state_after_first,
    state_after_second=state_after_second,
    load_invocation_count=2,
    dependency_count=length(dependencies),
    dependencies=Tuple((path=path, sentinel=sentinel) for
        (path, sentinel) in dependencies),
    all_sentinels_present=true,
    registry_before=registry_before,
    registry_after=registry_after,
    registry_unchanged=true,
    fixture_loaded=false,
    shared_loader_clean_load_verified=true,
    formal_t2_accepted=false,
    physical_acceptance=false,
    scientific_acceptance=false,
    actual_model_attestation="unavailable")
bytes = Vector{UInt8}(codeunits(
    FusionConceptAI.canonical_json(receipt) * "\n"))
open(CLEAN_LOAD_OUTPUT, "w") do io
    write(io, bytes)
    flush(io)
end

println(FusionConceptAI.canonical_json(receipt))
println("VNEXT_T2_SHARED_MODULE_CLEAN_LOAD=PASS")
println("VNEXT_T2_SHARED_MODULE_CLEAN_LOAD_SHA256=" *
    bytes2hex(SHA.sha256(bytes)))
println("VNEXT_T2_FORMAL_ACCEPTANCE=false")
