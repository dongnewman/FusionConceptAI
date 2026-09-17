"""Additive pre-T0 structural lowering boundary for `TypedCompilerIRV1`.

The returned object is a typed plan and receipt, not an executable program.
No provider, mesh, solver, numerical, physical, engineering, or search call is
permitted in this file.  Every output remains `contract_only` and
`not_measured`; `terminal_deferred` and `fail_closed` are propagated without
execution.
"""

using SHA

struct TypedCompilerLoweringV1
    ir::TypedCompilerIRV1
    validation::TypedCompilerValidationV1
    status::Symbol
    claim_ceiling::Symbol
    evidence_scope::Symbol
    measured::Bool
    lowered_operations::Tuple{Vararg{String}}
    reason::String
    lowering_hash::String
    function TypedCompilerLoweringV1(::_TypedCompilerSealV1,
                                     ir::TypedCompilerIRV1,
                                     validation::TypedCompilerValidationV1,
                                     lowered_operations::Tuple{Vararg{String}})
        validation.status in (_TCIR_READY_V1, _TCIR_TERMINAL_DEFERRED_V1,
                              _TCIR_FAIL_CLOSED_V1) ||
            throw(ArgumentError("invalid lowering status"))
        all(op -> op in ir.operations, lowered_operations) ||
            throw(ArgumentError("lowered operation is not in source IR"))
        body = (ir=typed_compiler_payload_v1(ir), status=validation.status,
                failures=validation.failures, lowered_operations=lowered_operations,
                claim_ceiling=_TCIR_CONTRACT_ONLY_V1,
                evidence_scope=_TCIR_NOT_MEASURED_V1, measured=false)
        digest = bytes2hex(sha256(codeunits(repr(body))))
        reason = isempty(validation.failures) ? "structural_contract_ready" :
            join((string(f.code, ":", f.path) for f in validation.failures), ";")
        new(ir, validation, validation.status, _TCIR_CONTRACT_ONLY_V1,
            _TCIR_NOT_MEASURED_V1, false, lowered_operations, reason, digest)
    end
end
TypedCompilerLoweringV1(args...) =
    throw(ArgumentError("TypedCompilerLoweringV1 is sealed; use lower_typed_compiler_ir"))

function _tc_new_lowering_v1(ir::TypedCompilerIRV1,
                             validation::TypedCompilerValidationV1,
                             lowered_operations::Tuple{Vararg{String}})
    invoke(TypedCompilerLoweringV1,
        Tuple{_TypedCompilerSealV1,TypedCompilerIRV1,TypedCompilerValidationV1,Tuple{Vararg{String}}},
        _TCIR_SEAL_V1, ir, validation, lowered_operations)
end

"""Produce a declaration-only lowering plan after strict binding validation."""
function lower_typed_compiler_ir(ir::TypedCompilerIRV1,
                                  expected::TypedCompilerBindingV1)
    validation = validate_typed_compiler_ir(ir, expected)
    operations = validation.status == _TCIR_READY_V1 ? ir.operations : ()
    _tc_new_lowering_v1(ir, validation, operations)
end

lower_typed_compiler_ir(ir::TypedCompilerIRV1) =
    lower_typed_compiler_ir(ir, typed_compiler_binding_v1())

function validate_typed_compiler_lowering(lowered::TypedCompilerLoweringV1,
                                          expected::TypedCompilerBindingV1)
    current = validate_typed_compiler_ir(lowered.ir, expected)
    current.status == lowered.status ||
        throw(ArgumentError("lowering status changed after validation"))
    current.failures == lowered.validation.failures ||
        throw(ArgumentError("lowering failure receipt changed"))
    lowered.claim_ceiling == _TCIR_CONTRACT_ONLY_V1 ||
        throw(ArgumentError("lowering claim ceiling is not contract_only"))
    lowered.evidence_scope == _TCIR_NOT_MEASURED_V1 ||
        throw(ArgumentError("lowering evidence scope is not not_measured"))
    !lowered.measured || throw(ArgumentError("lowering cannot claim measured evidence"))
    lowered
end

validate_typed_compiler_lowering(lowered::TypedCompilerLoweringV1) =
    validate_typed_compiler_lowering(lowered, typed_compiler_binding_v1())
