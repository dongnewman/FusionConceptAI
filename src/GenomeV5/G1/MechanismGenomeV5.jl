"""Versioned G1 outer Genome identity and candidate-bound editing."""

struct MechanismGenomeV5
    contract_ref::GenomeContractRef
    payload::MechanismGenomePayloadV2
    version_axes::G1VersionAxesV2
    admission::G1AdmissionResultV2
    candidate_hash::Digest256
    function MechanismGenomeV5(contract_ref::Any, payload::Any, version_axes::Any)
        ref = contract_ref isa GenomeContractRef ? contract_ref : throw(ArgumentError("G1 V5 outer contract_ref must be public GenomeContractRef"))
        payload isa MechanismGenomePayloadV2 || throw(ArgumentError("G1 V5 requires MechanismGenomePayloadV2; legacy payload is read-only"))
        materialized = g1_materialize_contract_ref(payload.contract_ref, payload.grammar_profile)
        materialized == ref || throw(ArgumentError("G1 V5 public contract ref does not match internal binding"))
        version_axes isa G1VersionAxesV2 || throw(ArgumentError("G1 V5 requires four explicit version axes"))
        version_axes == payload.contract_ref.version_axes || throw(ArgumentError("G1 V5 outer version_axes do not match internal contract binding"))
        admission = g1_admission(payload)
        isempty(admission.errors) || throw(ArgumentError("G1 V5 admission failed closed: " * join(admission.errors, ",")))
        candidate_hash = canonical_hash((contract_ref=ref, payload=payload, version_axes=version_axes))
        new(ref, payload, version_axes, admission, candidate_hash)
    end
end

function MechanismGenomeV5(old::MechanismGenomeV4)
    throw(ArgumentError("V4 Genome is read-only and requires an explicit migration receipt; it is not reinterpreted as V5"))
end

g1_genome_hash(genome::MechanismGenomeV5) = genome.candidate_hash
g1_provider_resolution(genome::MechanismGenomeV5) = genome.admission.resolution

function g1_edit_expression(genome::MechanismGenomeV5, equation_id::AbstractString, expression::G1TypedExpressionV2)
    id = String(equation_id)
    found = false
    rebuilt = G1EquationV2[]
    for equation in genome.payload.equation_plan.equations
        if equation.equation_id == id
            found = true
            push!(rebuilt, G1EquationV2(equation.equation_id, equation.role, equation.operator_ref,
                equation.input_state_refs, equation.output_state_refs, equation.input_units,
                equation.output_units, equation.temporal_kind, equation.derivative_order,
                equation.effects, equation.occurrences, equation.closure_ref, expression;
                input_ranks=equation.input_ranks, output_ranks=equation.output_ranks,
                mimo=length(equation.input_state_refs) > 1 || length(equation.output_state_refs) > 1))
        else
            push!(rebuilt, equation)
        end
    end
    found || throw(ArgumentError("cannot edit unknown G1 equation id"))
    plan = G1EquationPlanV2(genome.payload.equation_plan.plan_ref, Tuple(rebuilt))
    payload = MechanismGenomePayloadV2(genome.payload.contract_ref, genome.payload.states, plan, genome.payload.grammar_profile)
    MechanismGenomeV5(genome.contract_ref, payload, genome.version_axes)
end

g1_edit_expression(::MechanismGenomeV5, ::AbstractString, ::AbstractString) =
    throw(ArgumentError("string-only expression edits are rejected; supply G1TypedExpressionV2"))

semantic_view(x::G1VersionAxesV2) =
    (payload_schema_version=x.payload_schema_version,
     canonicalization_profile_version=x.canonicalization_profile_version,
     applicability_profile_version=x.applicability_profile_version,
     evidence_receipt_version=x.evidence_receipt_version)
semantic_view(x::MechanismGenomeV5) =
    (contract_ref=x.contract_ref, payload=x.payload, version_axes=x.version_axes,
     admission=x.admission, candidate_hash=x.candidate_hash)
canonical_json(x::G1VersionAxesV2) = canonical_json(semantic_view(x))
canonical_json(x::MechanismGenomeV5) = canonical_json(semantic_view(x))
