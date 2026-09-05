"""Machine-readable contract manifest for the G1 occurrence-ownership revision."""

const _G1_OCCURRENCE_OWNERSHIP_SCHEMA_BYTES = codeunits(
    "{\"domain\":\"fusionconceptai:v4:g1-occurrence-ownership\",\"revision\":\"v2\",\"invariant_fields\":[\"invariant_ref\",\"ledger_identity\",\"scope\",\"terms\",\"owned_ledger_occurrence_refs\",\"tolerance_log10\",\"entropy_direction\"],\"occurrence_fields\":[\"operator_site_ref\",\"port_side\",\"port_index\",\"direction\",\"occurrence_kind\",\"ledger_identity\"],\"occurrence_kinds\":[\"occurrence_internal_effect\",\"occurrence_source_effect\",\"occurrence_sink_effect\",\"occurrence_boundary_effect\",\"occurrence_interface_minus\",\"occurrence_interface_plus\"],\"owner_key\":[\"operator_site_ref\",\"port_side\",\"port_index\",\"direction\",\"occurrence_kind\",\"ledger_identity\"],\"coefficient_in_owner_key\":false,\"scope_rules\":{\"global\":\"complete_ledger_occurrence_set_in_graph\",\"domain\":\"only_ledger_occurrences_whose_endpoint_node_is_in_typed_scope_state_refs\",\"interface\":\"only_interface_minus_plus_occurrences_at_scope_operator_site_ref\"},\"closure\":\"declared_and_expected_sets_must_be_bijective\",\"owner_uniqueness\":\"(full_ledger_identity,exact_typed_scope)\",\"ledger_sets\":\"invariant_ledger_set_equals_graph_occurrence_ledger_set\",\"overlapping_scopes\":\"allowed\"}")
const _G1_OCCURRENCE_OWNERSHIP_CANONICAL_BYTES = codeunits(
    "{\"domain\":\"fusionconceptai:v4:g1-occurrence-ownership-canonical\",\"revision\":\"v2\",\"sorting\":\"lexical-owner-key\",\"normalized_coefficient\":true,\"coefficient_placement\":\"decorated_layer_only\",\"wire_domains\":[\"fusionconceptai:v4:g1-invariant:v2\",\"fusionconceptai:v4:g1-mechanism-payload:v2\",\"fusionconceptai:v4:g1-canonical-transport:v2\",\"fusionconceptai:v4:g1-hash:contract:v2\",\"fusionconceptai:v4:g1-hash:canonicalization-profile:v2\",\"fusionconceptai:v4:g1-hash:operator-registry:v2\",\"fusionconceptai:v4:g1-hash:topology:v2\",\"fusionconceptai:v4:g1-hash:operator-program:v2\",\"fusionconceptai:v4:g1-hash:mechanism-structure:v2\",\"fusionconceptai:v4:g1-hash:decorated-mechanism:v2\",\"fusionconceptai:v4:g1-hash:candidate-subject:v2\"],\"layer_canonicalization_version\":\"2\",\"dependency_chain\":[\"contract_profile\",\"topology\",\"operator_program\",\"mechanism_structure\",\"decorated\",\"candidate\"],\"profile_version\":\"1\"}")

const G1_OCCURRENCE_OWNERSHIP_SCHEMA_HASH = Digest256(bytes2hex(SHA.sha256(_G1_OCCURRENCE_OWNERSHIP_SCHEMA_BYTES)))
const G1_OCCURRENCE_OWNERSHIP_CANONICALIZATION_HASH = Digest256(bytes2hex(SHA.sha256(_G1_OCCURRENCE_OWNERSHIP_CANONICAL_BYTES)))

function g1_occurrence_ownership_contract_ref(uri::AbstractString)
    id = strip(String(uri))
    !isempty(id) && isvalid(id) || throw(ArgumentError("G1 occurrence ownership contract URI must be non-empty valid UTF-8"))
    GenomeContractRef(id, "v2", G1_OCCURRENCE_OWNERSHIP_SCHEMA_HASH,
        G1_OCCURRENCE_OWNERSHIP_CANONICALIZATION_HASH,
        "g1-exact-occurrence-ownership-v2")
end

function _g1_is_occurrence_ownership_contract(ref::GenomeContractRef)
    ref.version == "v2" && ref.schema_hash == G1_OCCURRENCE_OWNERSHIP_SCHEMA_HASH &&
        ref.canonicalization_hash == G1_OCCURRENCE_OWNERSHIP_CANONICALIZATION_HASH &&
        ref.compatibility_profile == "g1-exact-occurrence-ownership-v2"
end
