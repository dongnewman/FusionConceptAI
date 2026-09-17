"""Independent checks for the serialized E1 N05 receipt envelope."""

using JSON3

_n05c_get(x, name::Symbol) = getproperty(x, name)
_n05c_hash(x) = Digest256(String(x))

function _n05c_value(row, field::Symbol)
    value = _n05c_get(row, field)
    digest256_text(String(value.canonical)) == _n05c_hash(value.hash) ||
        throw(ArgumentError("N05 receipt value hash mismatch: $field"))
    value
end

function _n05c_row(row, envelope, mode::String)
    String(row.mode) == mode || throw(ArgumentError("N05 receipt mode mismatch"))
    row.candidate_ref.id == envelope.candidate_ref.id &&
        row.candidate_ref.version == envelope.candidate_ref.version ||
        throw(ArgumentError("N05 receipt candidate ref mismatch"))
    String(row.package_hash) == String(envelope.package_hash) ||
        throw(ArgumentError("N05 receipt package hash mismatch"))
    String(row.e0_binding_hash) == String(envelope.e0.binding_hash) ||
        throw(ArgumentError("N05 receipt E0 binding hash mismatch"))
    String(row.e0_bound_input_hash) == String(envelope.e0.bound_input_hash) ||
        throw(ArgumentError("N05 receipt E0 bound-input hash mismatch"))
    mode == "authored_typed" && String(row.declaration_hash) == String(envelope.declaration.authored_hash) ||
        mode == "absent_authority" && String(row.declaration_hash) == repeat("0", 64) ||
        throw(ArgumentError("N05 receipt declaration hash mismatch"))
    source = row.source_locator
    _n05c_hash(source.source_hash)
    !isempty(String(source.path)) && !isempty(String(source.source_type)) ||
        throw(ArgumentError("N05 receipt source locator incomplete"))
    original = _n05c_value(row, :original_value)
    attempted = _n05c_value(row, :attempted_value)
    String(row.original_value_hash) == String(original.hash) ||
        throw(ArgumentError("N05 original value receipt hash mismatch"))
    String(row.attempted_value_hash) == String(attempted.hash) ||
        throw(ArgumentError("N05 attempted value receipt hash mismatch"))
    digest256_text(String(row.mutation_canonical)) == _n05c_hash(row.mutation_hash) ||
        throw(ArgumentError("N05 mutation hash mismatch"))
    row.compile_calls == 0 && row.provider_calls == 0 && row.solver_calls == 0 ||
        throw(ArgumentError("N05 receipt downstream counter is nonzero"))
    String(row.error_path) == String(row.field_path) ||
        throw(ArgumentError("N05 receipt error path is not the changed field"))
    row
end

"""Validate an in-memory JSON3/NamedTuple envelope and return a small audit."""
function n05_check_receipt_envelope(envelope)
    String(envelope.schema_version) == "UP2-00E1-N05-receipt-envelope-v1" ||
        throw(ArgumentError("N05 receipt schema version mismatch"))
    String(envelope.contract_scope) == "schema_validation_only" ||
        throw(ArgumentError("N05 receipt scope is too broad"))
    length(envelope.authored_receipts) == 5 ||
        throw(ArgumentError("N05 authored receipt count is not five"))
    length(envelope.absent_authority_receipts) == 5 ||
        throw(ArgumentError("N05 absent receipt count is not five"))
    authored = [_n05c_row(row, envelope, "authored_typed") for row in envelope.authored_receipts]
    absent = [_n05c_row(row, envelope, "absent_authority") for row in envelope.absent_authority_receipts]
    all(String(row.resolution) == "fail_closed" &&
        String(row.error_code) in ("invalid_closure", "invalid_type") for row in authored) ||
        throw(ArgumentError("N05 authored rows are not five fail-closed mutations"))
    all(String(row.resolution) == "terminal_deferred" &&
        String(row.error_code) == "authority_gap" &&
        String(row.original_value_hash) == String(row.attempted_value_hash) for row in absent) ||
        throw(ArgumentError("N05 absent rows are not five deferred receipts"))
    fields = String.(getproperty.(authored, :field_path))
    length(unique(fields)) == 5 || throw(ArgumentError("N05 receipt field paths are not unique"))
    sort(fields) == sort(["/n05/left_endpoint/endpoint_ref",
        "/n05/right_endpoint/endpoint_ref", "/n05/left_endpoint/sign",
        "/n05/right_endpoint/sign", "/n05/right_endpoint/unit"]) ||
        throw(ArgumentError("N05 receipt mutation field set is incomplete"))
    envelope.claims.B00 == false && envelope.claims.B04 == false &&
        envelope.claims.provider == false && envelope.claims.mesh == false &&
        envelope.claims.physical == false || throw(ArgumentError("N05 claim ceiling exceeded"))
    (status=:valid, authored_count=length(authored), absent_count=length(absent),
     compile_calls=0, provider_calls=0, solver_calls=0)
end

function _n05c_row_key(row)
    (String(row.field_path), String(row.mutation_kind))
end

function _n05c_same_row(actual, expected)
    for field in (:candidate_ref, :package_hash, :e0_binding_hash, :e0_bound_input_hash,
                  :declaration_hash, :source_locator, :source_type,
                  :original_value, :attempted_value, :original_value_hash,
                  :attempted_value_hash, :mutation_canonical, :mutation_hash,
                  :error_code, :error_path, :resolution, :compile_calls,
                  :provider_calls, :solver_calls, :field_path, :mutation_kind)
        JSON3.write(getproperty(actual, field)) == JSON3.write(getproperty(expected, field)) ||
            return false
    end
    true
end

"""Rebuild every receipt from trusted actual-A/E0 authorities and compare it."""
function n05_check_receipt_envelope(envelope, package::CandidateStatePackageV5,
        e0::UP2CandidatePhysicalBindingV1, authored::UP2N05AuthorityV1,
        absent::UP2N05AuthorityV1, specs::Tuple)
    n05_check_receipt_envelope(envelope)
    length(specs) == 5 || throw(ArgumentError("N05 trusted checker requires five specs"))
    expected_authored = Tuple(_n05e_row(up2n05_validate_mutation(authored, package, e0, spec),
        package, e0, :authored_typed, spec.field_path, spec.mutation_kind) for spec in specs)
    expected_absent = Tuple(_n05e_row(up2n05_validate_mutation(absent, package, e0, spec),
        package, e0, :absent_authority, spec.field_path, spec.mutation_kind) for spec in specs)
    actual_authored = Dict(_n05c_row_key(row) => row for row in envelope.authored_receipts)
    actual_absent = Dict(_n05c_row_key(row) => row for row in envelope.absent_authority_receipts)
    expected_authored_keys = Set(_n05c_row_key(row) for row in expected_authored)
    expected_absent_keys = Set(_n05c_row_key(row) for row in expected_absent)
    Set(keys(actual_authored)) == expected_authored_keys ||
        throw(ArgumentError("N05 authored receipt keys do not match typed fields"))
    Set(keys(actual_absent)) == expected_absent_keys ||
        throw(ArgumentError("N05 absent receipt keys do not match typed fields"))
    all(_n05c_same_row(actual_authored[_n05c_row_key(row)], row) for row in expected_authored) ||
        throw(ArgumentError("N05 authored receipt differs from actual source recomputation"))
    all(_n05c_same_row(actual_absent[_n05c_row_key(row)], row) for row in expected_absent) ||
        throw(ArgumentError("N05 absent receipt differs from actual source recomputation"))
    (status=:source_bound_valid, authored_count=5, absent_count=5,
     compile_calls=0, provider_calls=0, solver_calls=0)
end

function n05_check_receipt_file(path::AbstractString)
    n05_check_receipt_envelope(JSON3.read(read(path, String)))
end

"""Read a serialized envelope and apply the trusted actual-A/E0 checker."""
function n05_check_receipt_file(path::AbstractString,
        package::CandidateStatePackageV5, e0::UP2CandidatePhysicalBindingV1,
        authored::UP2N05AuthorityV1, absent::UP2N05AuthorityV1,
        specs::Tuple)
    envelope = JSON3.read(read(path, String))
    n05_check_receipt_envelope(envelope, package, e0, authored, absent, specs)
end
