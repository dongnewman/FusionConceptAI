"""Trusted-registry adapter for the candidate-bound FreeGS screen.

This file adds no new FreeGS scientific semantics.  It derives a provider
capability and immutable dispatch input from the exact, externally revalidated
`AxisymmetricEquilibriumBindingV4`, then wraps the existing screen execution
and receipt without increasing its authority.
"""

const _TRUSTED_FREEGS_CAPABILITY_SCHEMA =
    "fusionconceptai:runtime-v4-freegs-axisymmetric-capability"
const _TRUSTED_FREEGS_INPUT_SCHEMA =
    "fusionconceptai:runtime-v4-trusted-freegs-axisymmetric-input"
const _TRUSTED_FREEGS_REVISION = "trusted-freegs-axisymmetric-provider-v1"

struct _TrustedFreeGSProviderToken end
const _TRUSTED_FREEGS_TOKEN = _TrustedFreeGSProviderToken()

function _trusted_freegs_input_schema_body(context::ForwardChainContextV4,
        binding::AxisymmetricEquilibriumBindingV4)
    (schema=_TRUSTED_FREEGS_INPUT_SCHEMA, revision=_TRUSTED_FREEGS_REVISION,
     context_hash=context.context_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     scenario_hash=context.scenario_hash, binding_hash=binding.binding_hash,
     declaration_hash=canonical_hash(binding.declaration),
     field_geometry_genome_hash=binding.field_geometry_genome_hash,
     field_geometry_graph_hash=binding.field_geometry_graph_hash,
     field_geometry_graph_binding_hash=binding.field_geometry_graph_binding_hash)
end

"""Derive the only capability accepted by the trusted FreeGS descriptor."""
function trusted_freegs_axisymmetric_capability(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    binding = _freegs_context_binding(context)
    schema_hash = canonical_hash(_trusted_freegs_input_schema_body(context, binding))
    CapabilitySignatureV4(_TRUSTED_FREEGS_CAPABILITY_SCHEMA,
        _TRUSTED_FREEGS_REVISION, :axisymmetric_equilibrium_screen,
        "freegs_axisymmetric_free_boundary_grad_shafranov",
        (binding.declaration.declaration_id,),
        "typed_g2_axisymmetric_equilibrium_binding",
        "freegs_axisymmetric_screen_receipt", 2, ("R", "Z"),
        "free_boundary_hagenow", "single_axisymmetric_domain",
        "static_equilibrium",
        ("physical_model_screen", "freegs_receipt_hash", "freegs_output_hash"),
        screen_only, context.compiled.minimality_scope.bounds_hash;
        input_schema_hash=schema_hash,
        coordinate_system="axisymmetric_cylindrical")
end

function validate_trusted_freegs_axisymmetric_capability(
        capability::CapabilitySignatureV4, context::ForwardChainContextV4)
    expected = trusted_freegs_axisymmetric_capability(context)
    canonical_hash(capability) == canonical_hash(expected) ||
        throw(ArgumentError("FreeGS capability is not derived from the current typed binding/context"))
    canonical_hash(expected)
end

function _trusted_freegs_input_body(context_hash, physical_subject_hash,
        scenario_hash, binding_hash, declaration_hash, capability_hash,
        solver_input_hash)
    (schema=_TRUSTED_FREEGS_INPUT_SCHEMA, revision=_TRUSTED_FREEGS_REVISION,
     context_hash=context_hash, physical_subject_hash=physical_subject_hash,
     scenario_hash=scenario_hash, binding_hash=binding_hash,
     declaration_hash=declaration_hash, capability_hash=capability_hash,
     solver_input_hash=solver_input_hash)
end

struct TrustedFreeGSAxisymmetricInputV4
    context_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    declaration_hash::Digest256
    capability_hash::Digest256
    solver_input_hash::Digest256
    input_hash::Digest256
    function TrustedFreeGSAxisymmetricInputV4(token::_TrustedFreeGSProviderToken,
            context_hash::Digest256, physical_subject_hash::Digest256,
            scenario_hash::Digest256, binding_hash::Digest256,
            declaration_hash::Digest256, capability_hash::Digest256,
            solver_input_hash::Digest256, input_hash::Digest256)
        token === _TRUSTED_FREEGS_TOKEN || throw(ArgumentError("private constructor"))
        new(context_hash, physical_subject_hash, scenario_hash, binding_hash,
            declaration_hash, capability_hash, solver_input_hash, input_hash)
    end
end

semantic_view(x::TrustedFreeGSAxisymmetricInputV4) = merge(
    _trusted_freegs_input_body(x.context_hash, x.physical_subject_hash,
        x.scenario_hash, x.binding_hash, x.declaration_hash,
        x.capability_hash, x.solver_input_hash),
    (input_hash=x.input_hash,))

function make_trusted_freegs_axisymmetric_input(context::ForwardChainContextV4,
        capability::CapabilitySignatureV4=trusted_freegs_axisymmetric_capability(context))
    validate_forward_chain_context(context)
    binding = _freegs_context_binding(context)
    capability_hash = validate_trusted_freegs_axisymmetric_capability(capability, context)
    solver_input = freegs_axisymmetric_solver_input(context)
    solver_input_hash = _freegs_sha256_text(canonical_json(solver_input) * "\n")
    body = _trusted_freegs_input_body(context.context_hash,
        context.subject.physical_subject_hash, context.scenario_hash,
        binding.binding_hash, canonical_hash(binding.declaration),
        capability_hash, solver_input_hash)
    TrustedFreeGSAxisymmetricInputV4(_TRUSTED_FREEGS_TOKEN,
        context.context_hash, context.subject.physical_subject_hash,
        context.scenario_hash, binding.binding_hash,
        canonical_hash(binding.declaration), capability_hash,
        solver_input_hash, canonical_hash(body))
end

function validate_trusted_freegs_axisymmetric_input(
        input::TrustedFreeGSAxisymmetricInputV4,
        context::ForwardChainContextV4,
        capability::CapabilitySignatureV4=trusted_freegs_axisymmetric_capability(context))
    expected = make_trusted_freegs_axisymmetric_input(context, capability)
    input.context_hash == expected.context_hash || throw(ArgumentError("FreeGS input context mismatch"))
    input.physical_subject_hash == expected.physical_subject_hash || throw(ArgumentError("FreeGS input subject mismatch"))
    input.scenario_hash == expected.scenario_hash || throw(ArgumentError("FreeGS input scenario mismatch"))
    input.binding_hash == expected.binding_hash || throw(ArgumentError("FreeGS input binding mismatch"))
    input.declaration_hash == expected.declaration_hash || throw(ArgumentError("FreeGS input declaration mismatch"))
    input.capability_hash == expected.capability_hash || throw(ArgumentError("FreeGS input capability mismatch"))
    input.solver_input_hash == expected.solver_input_hash || throw(ArgumentError("FreeGS solver-input hash mismatch"))
    input.input_hash == expected.input_hash || throw(ArgumentError("FreeGS trusted input hash mismatch"))
    expected.input_hash
end

canonical_hash(x::TrustedFreeGSAxisymmetricInputV4) = x.input_hash

struct TrustedFreeGSAxisymmetricOutputV4
    freegs_receipt::FreeGSAxisymmetricExecutionReceiptV4
    freegs_receipt_hash::Digest256
    freegs_output_hash::Digest256
    output_json::String
end

semantic_view(x::TrustedFreeGSAxisymmetricOutputV4) = (
    freegs_receipt=x.freegs_receipt,
    freegs_receipt_hash=x.freegs_receipt_hash,
    freegs_output_hash=x.freegs_output_hash,
    output_json=x.output_json)

function validate_trusted_freegs_axisymmetric_output(
        output::TrustedFreeGSAxisymmetricOutputV4,
        context::ForwardChainContextV4,
        input::TrustedFreeGSAxisymmetricInputV4,
        capability::CapabilitySignatureV4=trusted_freegs_axisymmetric_capability(context))
    validate_trusted_freegs_axisymmetric_input(input, context, capability)
    receipt = output.freegs_receipt
    validate_freegs_axisymmetric_receipt(context, receipt)
    output.freegs_receipt_hash == receipt.receipt_hash || throw(ArgumentError("trusted FreeGS receipt hash mismatch"))
    receipt.input_hash == input.solver_input_hash ||
        throw(ArgumentError("trusted FreeGS input hash mismatch"))
    expected_output_hash = isempty(output.output_json) ? _FREEGS_UNKNOWN_HASH :
        _freegs_sha256_text(output.output_json)
    output.freegs_output_hash == receipt.output_hash == expected_output_hash ||
        throw(ArgumentError("trusted FreeGS output hash mismatch"))
    canonical_hash(output)
end

"""Repository-owned entrypoint.  The registry supplies context, not the manifest."""
function _trusted_freegs_axisymmetric_executor(context::ForwardChainContextV4,
        input::TrustedFreeGSAxisymmetricInputV4)
    capability = trusted_freegs_axisymmetric_capability(context)
    validate_trusted_freegs_axisymmetric_input(input, context, capability)
    artifacts = execute_freegs_axisymmetric_screen(context)
    receipt = artifacts.receipt
    validate_freegs_axisymmetric_receipt(context, receipt)
    output = TrustedFreeGSAxisymmetricOutputV4(receipt, receipt.receipt_hash,
        receipt.output_hash, artifacts.output_json)
    validate_trusted_freegs_axisymmetric_output(output, context, input, capability)
    output
end

trusted_freegs_axisymmetric_provider_manifest() = (
    schema="fusionconceptai:runtime-v4-trusted-freegs-axisymmetric-provider",
    revision=_TRUSTED_FREEGS_REVISION,
    provider_id=_TPR_FREEGS_PROVIDER,
    source_paths=_TPR_FREEGS_ATTESTED_SOURCES,
    capability_source=:exact_typed_axisymmetric_binding_and_context,
    operational_statuses=(:physical_model_screen, :recoverable_gap_unknown),
    claim_ceiling=screen_only, emits_evidence=false,
    physical_validation=false, engineering_validation=false,
    p5_ready=false, terminal_authority=false)
