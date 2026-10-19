using SHA
using Serialization
using FusionConceptAI

const T2_TEST_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))

# Reuse only the producer-owned source constructors and chain builder.  The
# formal T2 package, reload adapter, gate, and receipts are rebuilt below.
include(joinpath(@__DIR__, "..", "VNextT2ConcreteSourceWitnessV3",
    "fixture_helpers.jl"))
const T2_G = FusionConceptAI

function _t2_include_if_missing(path, sentinel::Symbol)
    isdefined(T2_G, sentinel) || Base.include(T2_G, path)
end

_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "Contracts",
    "VNextT1CanonicalBytesV2.jl"), :VNextT1CanonicalBytesV2)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "Contracts",
    "VNextT1CandidateBindingV2.jl"), :VNextT1CandidateBindingInputV2)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "GenomeV5", "Integration",
    "VNextDeclarationAuthorityRecheckLocalV2.jl"),
    :VNextAuthorityRecheckLocalV2Input)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "Contracts",
    "CandidateStatePackageV5NextV2.jl"), :CandidateStatePackageV5NextV2)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "GenomeV5", "Integration",
    "VNextGenomeV5IntegrationV2.jl"), :VNextT1AdmissionInputV2)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "Contracts",
    "VNextT1PackageBindingAdapterV2.jl"),
    :VNextT1PackageBindingAdapterResultV2)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "GenomeV5", "UP2",
    "VNextT2UP2AdapterV2.jl"), :VNextT2UP2BoundInputV2)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "GenomeV5", "UP2",
    "VNextT2IdentityReceiptProjectionV2.jl"),
    :VNextT2IdentityProjectionV2)
_t2_include_if_missing(joinpath(T2_TEST_ROOT, "src", "GenomeV5", "Integration",
    "VNextT2IdentityReceiptIntegrationV2.jl"),
    :VNextT2ReceiptLedgerV2)

function t2_serialize_reload(value)
    io = IOBuffer()
    Serialization.serialize(io, value)
    bytes = take!(io)
    (value=Serialization.deserialize(IOBuffer(bytes)), bytes=bytes)
end

function t2_t1_admission_fixture(; coherent_g3_child=true,
        edited_realization=false, parent_commitments=nothing,
        transport_override=:use_source, recheck_override=:use_source)
    source = v3_chain(coherent_g3_child=coherent_g3_child,
        edited_realization=edited_realization)
    source.built.source_ready || error((:source_witness_not_ready,
        source.built.status, source.built.errors, source.built.gaps))
    source_recheck = T2_G.vnext_declaration_authority_recheck_local_v2(
        T2_G.VNextAuthorityRecheckLocalV2Input(
            source.transport.candidate_ref, source.transport))
    source_recheck.status === :local_checked_present ||
        error((:v2_recheck_not_present, source_recheck.status,
            source_recheck.errors))
    t1_parents = ntuple(i -> T2_G.vnext_t1_parent_commitment_v2(
        source.transport.candidate_ref, source.transport.declarations[i]), 2)
    supplied_parents = parent_commitments === nothing ?
        t1_parents : parent_commitments
    authority = (status=source.bridge.status,
        resolution=source.bridge.resolution,
        authority_verified=source.bridge.authority_verified,
        expected_commitment=source.expected,
        binding_state=source.bridge.binding_state,
        commitment_hash=source.expected.commitment_hash)
    transport = transport_override === :use_source ?
        source.transport : transport_override
    recheck = recheck_override === :use_source ?
        source_recheck : recheck_override
    admission_input = T2_G.VNextT1AdmissionInputV2(
        source.transport.candidate_ref, transport, recheck,
        supplied_parents, source.expected.commitment_hash, authority)
    admission = T2_G.vnext_t1_admit_v2(admission_input)
    (source=source, source_recheck=source_recheck, recheck=recheck,
        t1_parents=t1_parents, supplied_parents=supplied_parents,
        authority=authority, admission_input=admission_input,
        admission=admission)
end

function t2_chain(; coherent_g3_child=true, edited_realization=false,
        scenario="vnext-t2-native-source-synthetic-local-r1",
        evidence_kind=:synthetic_local, formal_t1_accepted=true,
        software_acceptance_receipt_hash=nothing,
        candidate_admission_receipt_hash=nothing)
    t1 = t2_t1_admission_fixture(
        coherent_g3_child=coherent_g3_child,
        edited_realization=edited_realization)
    source = t1.source
    recheck = t1.recheck
    t1_parents = t1.t1_parents
    admission_input = t1.admission_input
    admission = t1.admission
    admission.status === :prepared_not_executed ||
        error((:v2_t1_admission_not_prepared, admission.status,
            admission.errors, admission.gaps, admission.trace))
    admission.resolution === :terminal_deferred ||
        error((:v2_t1_admission_resolution_invalid, admission.resolution))
    admission.accepted === false ||
        error(:v2_t1_admission_accepted_invalid)
    admission.claim_ceiling === :contract_only ||
        error(:v2_t1_admission_claim_ceiling_invalid)
    admission.package isa T2_G.CandidateStatePackageV5NextV2 ||
        error(:v2_t1_admission_package_absent)
    package = admission.package
    reload = t2_serialize_reload(package)
    base_adapter = T2_G.vnext_t1_package_binding_adapter_v2(reload.value)
    base_adapter.input === nothing &&
        error((:reload_adapter_input_absent, base_adapter.reason))
    adapter = T2_G.vnext_t1_package_binding_adapter_v2(reload.value,
        (base_adapter.input,))
    adapter.binding === nothing &&
        error((:reload_binding_absent, adapter.reason))
    synthetic_software_acceptance_receipt_hash = T2_G.canonical_hash((
        domain="vnext-t2-synthetic-local-t1-software-acceptance-fixture",
        evidence_kind=:synthetic_local,
        formal_gate_verified=false,
        producer_version="fixture-r2",
        candidate_specific=false,
        scenario=scenario))
    synthetic_candidate_admission_receipt_hash = T2_G.canonical_hash((
        domain="vnext-t2-synthetic-local-candidate-t1-admission-fixture",
        evidence_kind=:synthetic_local,
        formal_gate_verified=false,
        producer_version="fixture-r2",
        witness_hash=source.witness.witness_hash,
        candidate_ref=reload.value.candidate_ref,
        package_hash=reload.value.package_hash,
        semantic_identity=reload.value.semantic_identity,
        bundle_hash=reload.value.bundle_hash,
        wire_hash=reload.value.wire.sha256,
        parent_commitments=t1_parents,
        g3_expected_commitment=source.expected.commitment_hash,
        t1_admission_invocation_count=2,
        t1_admission_validation_mode=:initial_plus_handoff_recompute,
        admission_material_hash=T2_G.canonical_hash(
            T2_G._vnext_t2_t1_admission_handoff_body_v2(source.witness,
                admission_input, admission, reload.value, adapter, nothing,
                scenario, T2_G.VNEXT_T2_UP2_PROFILE_V2)),
        adapter_hash=T2_G.canonical_hash(T2_G.semantic_view(adapter)),
        binding_receipt_hash=adapter.binding.receipt_hash,
        scenario=scenario))
    supplied_software_acceptance_receipt_hash =
        software_acceptance_receipt_hash === nothing ?
        synthetic_software_acceptance_receipt_hash :
        software_acceptance_receipt_hash
    supplied_candidate_admission_receipt_hash =
        candidate_admission_receipt_hash === nothing ?
        synthetic_candidate_admission_receipt_hash :
        candidate_admission_receipt_hash
    gate = T2_G.vnext_t2_formal_gate_identity_v2(
        reload.value.candidate_ref, scenario, source.witness.witness_hash,
        reload.value.package_hash, reload.value.semantic_identity,
        reload.value.bundle_hash, reload.value.wire.sha256,
        T2_G.canonical_hash(T2_G.semantic_view(adapter)),
        adapter.binding.receipt_hash, t1_parents,
        source.expected.commitment_hash,
        supplied_software_acceptance_receipt_hash,
        supplied_candidate_admission_receipt_hash,
        evidence_kind=evidence_kind,
        formal_t1_accepted=formal_t1_accepted)
    build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(source.witness,
        admission_input, admission, reload.value, adapter, gate,
        scenario=scenario)
    (source=source, recheck=recheck, admission_input=admission_input,
        admission=admission, package=package, t1_parents=t1_parents,
        serialized_package=reload.bytes, reloaded_package=reload.value,
        adapter=adapter, gate=gate, build=build,
        synthetic_software_acceptance_receipt_hash=
            synthetic_software_acceptance_receipt_hash,
        synthetic_candidate_admission_receipt_hash=
            synthetic_candidate_admission_receipt_hash,
        supplied_software_acceptance_receipt_hash=
            supplied_software_acceptance_receipt_hash,
        supplied_candidate_admission_receipt_hash=
            supplied_candidate_admission_receipt_hash,
        t1_admission_invocation_count=2,
        formal_gate_verified=false)
end

function t2_replace_struct_field(value, field::Symbol, replacement)
    names = fieldnames(typeof(value))
    index = findfirst(==(field), names)
    index === nothing && error((:unknown_fixture_field, field, names))
    values = ntuple(i -> i == index ? replacement : getfield(value, i),
        fieldcount(typeof(value)))
    typeof(value)(values...)
end

function t2_witness_with_t1_commitments_as_source_parent(chain)
    witness = chain.source.witness
    source_parent = witness.parent_bundle
    g1 = t2_replace_struct_field(source_parent.g1, :authority_commitment,
        chain.t1_parents[1])
    g2 = t2_replace_struct_field(source_parent.g2, :authority_commitment,
        chain.t1_parents[2])
    parent_draft = T2_G.PresentT0LocalParentBaselineBundleV1(
        source_parent.candidate_ref, g1, g2, source_parent.bundle_hash)
    parent = t2_replace_struct_field(parent_draft, :bundle_hash,
        T2_G.canonical_hash((candidate_ref=parent_draft.candidate_ref,
            g1=parent_draft.g1, g2=parent_draft.g2)))
    manifest_draft = t2_replace_struct_field(witness.manifest,
        :parent_bundle_hash, parent.bundle_hash)
    manifest = t2_replace_struct_field(manifest_draft, :manifest_hash,
        T2_G.canonical_hash(T2_G._vnext_t2_v3_manifest_body(manifest_draft)))
    witness_draft = t2_replace_struct_field(
        t2_replace_struct_field(witness, :parent_bundle, parent),
        :manifest, manifest)
    t2_replace_struct_field(witness_draft, :witness_hash,
        T2_G.canonical_hash(T2_G._vnext_t2_v3_witness_body(witness_draft)))
end

function t2_gate_for_witness(chain, witness)
    gate = chain.gate
    T2_G.vnext_t2_formal_gate_identity_v2(gate.candidate_ref,
        gate.scenario, witness.witness_hash, gate.package_hash,
        gate.semantic_identity, gate.bundle_hash, gate.wire_hash,
        gate.reload_adapter_receipt_hash, gate.binding_receipt_hash,
        gate.parent_commitments, gate.g3_authority_commitment,
        gate.formal_t1_software_acceptance_receipt_hash,
        gate.candidate_t1_admission_receipt_hash,
        evidence_kind=gate.evidence_kind,
        formal_t1_accepted=gate.formal_t1_accepted,
        profile=gate.profile)
end

function t2_bound_input_with(input::T2_G.VNextT2UP2BoundInputV2;
        witness=input.witness, package=input.package, adapter=input.adapter,
        formal_gate=input.formal_gate, scenario=input.scenario,
        profile=input.profile, input_hash=input.input_hash)
    T2_G.VNextT2UP2BoundInputV2(witness, package, adapter, formal_gate,
        scenario, profile, input_hash)
end
