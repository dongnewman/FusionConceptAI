"""Append-only JSON receipts for the E1 N05 contract mutations.

This exporter consumes already source-validated A/E0/ N05 objects.  It does not
construct a candidate, infer a declaration, or call any compiler/provider/
solver.  The serialized canonical strings let the checker recompute value and
mutation hashes without treating fixture labels as classifications.
"""

using JSON3

const N05_RECEIPT_EXPORT_SCHEMA_V1 = "UP2-00E1-N05-receipt-envelope-v1"

_n05e_hash(x::Digest256) = x.value
_n05e_hash(x) = String(x)

function _n05e_ref(x)
    x isa GenomeContractRef && return (kind="GenomeContractRef", uri=x.uri,
        version=x.version, schema_hash=x.schema_hash.value,
        canonicalization_hash=x.canonicalization_hash.value,
        compatibility_profile=x.compatibility_profile)
    x isa QualifiedRefV1 && return (kind="QualifiedRefV1", id=x.id, version=x.version)
    throw(ArgumentError("N05 receipt source ref has an unsupported type"))
end

function _n05e_value(x)
    canonical = canonical_json(x)
    (type=string(nameof(typeof(x))), canonical=canonical,
     hash=canonical_hash(x).value)
end

function _n05e_locator(x::UP2N05SourceLocatorV1)
    (layer=String(x.layer), path=x.path, source_ref=_n05e_ref(x.source_ref),
     source_hash=x.source_hash.value, source_type=String(x.source_type))
end

function _n05e_row(receipt::UP2N05MutationReceiptV1, package, e0,
                   declaration_mode::Symbol, field_path::AbstractString,
                   mutation_kind::Symbol)
    mutation_canonical = declaration_mode === :authored_typed ?
        canonical_json((id=receipt.id, baseline=receipt.declaration_hash,
                        mutated=receipt.mutated_value)) :
        canonical_json((id=receipt.id, original=receipt.original_value,
                        mutated=receipt.mutated_value))
    (id=receipt.id, mode=String(declaration_mode), field_path=String(field_path),
     mutation_kind=String(mutation_kind),
     candidate_ref=_n05e_ref(package.candidate_ref),
     package_hash=package.candidate_hash.value,
     e0_binding_hash=e0.binding_hash.value,
     e0_bound_input_hash=e0.bound_input_hash.value,
     declaration_hash=receipt.declaration_hash.value,
     source_locator=_n05e_locator(receipt.source_locator),
     source_type=String(receipt.source_type),
     original_value=_n05e_value(receipt.original_value),
     attempted_value=_n05e_value(receipt.mutated_value),
     original_value_hash=receipt.original_value_hash.value,
     attempted_value_hash=receipt.mutated_value_hash.value,
     mutation_canonical=mutation_canonical,
     mutation_hash=receipt.mutation_hash.value,
     error_code=String(receipt.error_code), error_path=receipt.error_path,
     resolution=String(receipt.resolution),
     compile_calls=receipt.compile_calls, provider_calls=receipt.provider_calls,
     solver_calls=receipt.solver_calls)
end

"""Write one new envelope; an existing output path is never replaced."""
function n05_export_receipt_envelope(package::CandidateStatePackageV5,
        e0::UP2CandidatePhysicalBindingV1,
        authored::UP2N05AuthorityV1, absent::UP2N05AuthorityV1,
        specs::Tuple; output_path::AbstractString)
    isfile(output_path) && throw(ArgumentError("N05 receipt output already exists"))
    length(specs) == 5 || throw(ArgumentError("N05 receipt export requires five specs"))
    authored_check = up2n05_validate(authored, package, e0)
    authored_check.status === :valid ||
        throw(ArgumentError("authored N05 baseline is not valid: $(authored_check.status)"))
    absent_check = up2n05_validate(absent, package, e0)
    absent_check.status === :terminal_deferred ||
        throw(ArgumentError("absent N05 baseline is not deferred"))
    authored_rows = Tuple(_n05e_row(up2n05_validate_mutation(authored, package, e0, spec),
        package, e0, :authored_typed, spec.field_path, spec.mutation_kind) for spec in specs)
    absent_rows = Tuple(_n05e_row(up2n05_validate_mutation(absent, package, e0, spec),
        package, e0, :absent_authority, spec.field_path, spec.mutation_kind) for spec in specs)
    envelope = (schema_version=N05_RECEIPT_EXPORT_SCHEMA_V1,
        contract_scope="schema_validation_only",
        candidate_ref=_n05e_ref(package.candidate_ref),
        package_hash=package.candidate_hash.value,
        e0=(binding_hash=e0.binding_hash.value, bound_input_hash=e0.bound_input_hash.value,
            schema_hash=e0.schema_hash.value, canonicalization_hash=e0.canonicalization_hash.value,
            profile_hash=e0.profile_hash.value),
        declaration=(authored_hash=authored.declaration.declaration_hash.value,
                     absent="none"),
        authored_receipts=authored_rows, absent_authority_receipts=absent_rows,
        claims=(authored_count=5, absent_count=5, compile_calls=0,
                provider_calls=0, solver_calls=0,
                B00=false, B04=false, provider=false, mesh=false, physical=false))
    open(output_path, "w") do io
        JSON3.write(io, envelope)
    end
    envelope
end
