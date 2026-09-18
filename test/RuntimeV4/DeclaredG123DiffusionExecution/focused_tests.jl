"""Focused contract tests for the declared G1/G2/G3 execution seam.

This command is intentionally supplied but not run in the R4 handoff.  It is
the independent Julia command for a later serialized lane; the current R2
verification is Python-only.
"""

using Test
using FusionConceptAI

const _DGD_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _DGD = FusionConceptAI
_DGD.load_genome_v5_components!()
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "GenomeV5", "G1", "DiffusionDeclarationV1.jl"))
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "GenomeV5", "G1", "G1SourceAuthorityFactoryV1.jl"))
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "GenomeV5", "G2", "MetricBoundaryDeclarationV1.jl"))
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "GenomeV5", "G2", "G2SourceAuthorityFactoryV1.jl"))
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "GenomeV5", "G3", "G3SourceFeedbackLawV1.jl"))
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "GenomeV5", "G3", "G3SourceAuthorityFactoryV1.jl"))
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "GenomeV5", "Integration", "VNextDeclarationTransportLocalV1.jl"))
Base.include(_DGD, joinpath(_DGD_ROOT, "src", "RuntimeV4", "DeclaredG123DiffusionExecutionV1.jl"))
include(joinpath(@__DIR__, "fixture.jl"))

# Reuse only the existing typed declaration/receipt fixture helpers.  The
# helper file is definition-only when included from this focused runner.
include(joinpath(_DGD_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))

function _dgd_actual_input_v1()
    g1, g2, g3 = _t0l_g1(), _t0l_g2(), _t0l_g3()
    declarations = (_t0l_present(:G1, g1),
        _t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        _t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (_t0l_child(:realization), _t0l_child(:control), _t0l_child(:binding))
    feedback = (_t0l_feedback("g1-residual", declarations[1].declaration_ref),
        _t0l_feedback("g2-thermal", declarations[2].declaration_ref))
    admission = vnext_declaration_transport_local_v1(_T0L_CANDIDATE,
        declarations, children, feedback)
    admission.status === :valid || error("fixture transport did not validate")
    input = dgd_input_v1(_T0L_CANDIDATE, g1, g2, g3, admission.transport)
    (input=input, g1=g1, g2=g2, g3=g3, bundle=admission.transport)
end

@testset "declared G123 R4 executes every product stage" begin
    spec = dgd_fixture_numeric_v1()
    @test spec.claim_ceiling === :screen_only
    @test spec.accepted === false
    @test spec.formal_up_credit === false
    @test spec.formal_r_credit === false
    @test spec.provider_calls == 0
    @test spec.mesh_calls == 0
    @test spec.solver_calls == 1
    @test spec.transferred_state == (0.25, 0.75)
    actual = _dgd_actual_input_v1()
    compile = dgd_compile_v1(actual.input)
    mesh = dgd_local_mesh_v1(actual.input)
    transfer = dgd_transfer_v1(mesh, mesh, spec.old_state)
    composition = dgd_composition_admit_v1(actual.input)
    numerical = dgd_numerical_solve_v1(actual.input, mesh, transfer)
    aggregate = dgd_execute_v1(actual.input; old_state=spec.old_state)
    @test compile.status === :ready
    @test transfer.status === :ready
    @test composition.status === :terminal_deferred
    @test numerical !== nothing && numerical.status === :ready
    @test aggregate.status === :terminal_deferred
    @test aggregate.numerical !== nothing && aggregate.numerical.status === :ready
    @test aggregate.solver_calls == 1
    @test aggregate.provider_calls == 0 && aggregate.mesh_calls == 0
end

@testset "declared G123 R4 observed negative result set" begin
    @test :terminal_deferred in DGD_STATUSES_V1
    @test DGD_CLAIM_CEILING_V1 === :screen_only
    actual = _dgd_actual_input_v1()
    mesh = dgd_local_mesh_v1(actual.input)
    malformed = dgd_transfer_v1(mesh, mesh, (0.1,))
    invalid = dgd_transfer_v1(mesh, mesh, (0.1, 0.9); overlap=(3.0, 4.0))
    @test malformed.status === :fail_closed
    @test malformed.code === :malformed_state_shape
    @test invalid.status === :terminal_deferred
    @test invalid.code === :invalid_overlap

    observed = Dict{String,Tuple{Symbol,Symbol}}()
    observed["invalid_overlap"] = (invalid.status, invalid.code)

    # Public identity boundary: the strict input constructor may throw, while
    # product dispatch returns a typed fail-closed aggregate.
    candidate_bad = dgd_execute_declared_v1(
        QualifiedRefV1("foreign://candidate", "v5"), actual.g1, actual.g2,
        actual.g3, actual.bundle)
    observed["candidate_mismatch"] = (candidate_bad.status, candidate_bad.compile.code)
    @test candidate_bad.status === :fail_closed

    tampered = VNextT0LocalTransportV1(actual.bundle.candidate_ref,
        actual.bundle.declarations, actual.bundle.children, actual.bundle.feedback,
        digest256_text("tampered-bundle"), actual.bundle.status,
        actual.bundle.errors, actual.bundle.gaps)
    @test_throws ArgumentError dgd_input_v1(_T0L_CANDIDATE, actual.g1,
        actual.g2, actual.g3, tampered)
    bundle_bad = dgd_execute_declared_v1(_T0L_CANDIDATE, actual.g1, actual.g2,
        actual.g3, tampered)
    observed["bundle_hash_mismatch"] = (bundle_bad.status, bundle_bad.compile.code)

    # Altering only a typed G1 expression is an explicit unsupported subset,
    # therefore it is terminal_deferred rather than fail_closed.
    bad_f = G1DiffusionScalarFieldV1(actual.g1.f.field_id, actual.g1.f.physical_type,
        actual.g1.f.source_ref; source_expression="f_candidate(x)=sin(x)")
    bad_g1 = g1_diffusion_edit_source(actual.g1, :f, bad_f)
    bad_compile = dgd_compile_v1(DeclaredG123InputV1(actual.input.candidate_ref,
        bad_g1, actual.g2, actual.g3, actual.bundle, actual.input.hashes))
    observed["unsupported_expression_subset"] = (bad_compile.status, bad_compile.code)

    # G2 is intentionally unresolved in the fixture.  Both admission cases
    # call the product dispatch directly; no illegal :executed mesh status is
    # invented to reach G3.
    g2_admission = dgd_admission_dispatch_v1(actual.input, :G2)
    g3_admission = dgd_admission_dispatch_v1(actual.input, :G3)
    observed["missing_mesh_authority"] = (g2_admission.status, g2_admission.code)
    observed["missing_feedback_authority"] = (g3_admission.status, g3_admission.code)
    @test actual.g2.source.mesh.execution_status in (:declared, :not_executed)

    singular_mesh = DGDLocalMeshV1(mesh.chart_ref, mesh.mesh_ref, mesh.cells,
        mesh.basis, mesh.quadrature_points, mesh.quadrature_weights, mesh.faces,
        mesh.execution_status, mesh.bounds, mesh.reference_nodes, mesh.physical_nodes,
        0.0, mesh.mesh_hash)
    nonfinite_mesh = DGDLocalMeshV1(mesh.chart_ref, mesh.mesh_ref, mesh.cells,
        mesh.basis, mesh.quadrature_points, mesh.quadrature_weights, mesh.faces,
        mesh.execution_status, mesh.bounds, mesh.reference_nodes, mesh.physical_nodes,
        NaN, mesh.mesh_hash)
    singular = dgd_numerical_solve_v1(actual.input, singular_mesh,
        dgd_transfer_v1(singular_mesh, singular_mesh, (0.1, 0.9)))
    nonfinite = dgd_numerical_solve_v1(actual.input, nonfinite_mesh,
        dgd_transfer_v1(nonfinite_mesh, nonfinite_mesh, (0.1, 0.9)))
    observed["singular_sparse_system"] = (singular.status, singular.code)
    observed["nonfinite_derived"] = (nonfinite.status, nonfinite.code)

    # Deliberately contradict one typed ledger coefficient.  Composition
    # validates G3 before authority gates, so this is an observed contradiction.
    e = actual.g3.ledger_entries[2]
    bad_entry = G3SFLedgerEntryV1(e.entry_id, e.endpoint_id, e.unit, e.direction,
        e.sign, e.effect, e.coefficient + 1 // 1, e.owner_scope)
    bad_entries = (actual.g3.ledger_entries[1], bad_entry,
        actual.g3.ledger_entries[3], actual.g3.ledger_entries[4])
    bad_g3 = G3SFDeclarationV1(actual.g3.candidate_ref, actual.g3.source_id,
        actual.g3.owner_scope, actual.g3.endpoints, actual.g3.law, bad_entries,
        actual.g3.ledger_closure, actual.g3.feedback_targets,
        actual.g3.upstream_authority, actual.g3.declaration_hash)
    ledger_input = DeclaredG123InputV1(actual.input.candidate_ref, actual.g1,
        actual.g2, bad_g3, actual.bundle, actual.input.hashes)
    ledger_bad = dgd_composition_admit_v1(ledger_input)
    observed["ledger_contradiction"] = (ledger_bad.status, ledger_bad.code)

    # A semantic body tamper with a recomputed outer bundle hash still fails
    # against the reconstructed typed declaration body.
    old_record = actual.bundle.declarations[1]
    tampered_body = merge(old_record.semantic_body.body,
        (candidate_ref=QualifiedRefV1("foreign://body", "v5"),))
    tampered_semantic = VNextT0LocalSemanticBodyV1(tampered_body,
        _t0l_bytes(canonical_json(tampered_body)), old_record.semantic_body.labels)
    tampered_record = VNextT0LocalPresentDeclarationV1(old_record.layer,
        old_record.candidate_ref, old_record.source_ref, old_record.declaration_ref,
        old_record.source_identity_hash, old_record.declaration_identity_hash,
        old_record.axes, old_record.source_bytes, old_record.declaration_bytes,
        tampered_semantic, old_record.source_locator, old_record.factory_receipt,
        old_record.declaration_receipt)
    tampered_declarations = (tampered_record, actual.bundle.declarations[2],
        actual.bundle.declarations[3])
    tampered_body_bundle = VNextT0LocalTransportV1(actual.bundle.candidate_ref,
        tampered_declarations, actual.bundle.children, actual.bundle.feedback,
        vnext_t0_local_bundle_hash_recompute_v1(VNextT0LocalTransportV1(
            actual.bundle.candidate_ref, tampered_declarations, actual.bundle.children,
            actual.bundle.feedback, actual.bundle.bundle_hash, actual.bundle.status,
            actual.bundle.errors, actual.bundle.gaps)), actual.bundle.status,
        actual.bundle.errors, actual.bundle.gaps)
    body_bad = dgd_execute_declared_v1(_T0L_CANDIDATE, actual.g1, actual.g2,
        actual.g3, tampered_body_bundle)
    observed["body_hash_mismatch"] = (body_bad.status, body_bad.compile.code)

    expected = Dict{String,Tuple{Symbol,Symbol}}(
        key => (Symbol(value[1]), Symbol(value[2]))
        for (key, value) in dgd_fixture_negative_gates_v1())
    @test observed == expected
    @test Set(keys(observed)) == Set(keys(expected))
end

println("DGD_DECLARED_G123_R4_JULIA_COMMAND_DEFINED=true")
println("DGD_DECLARED_G123_R4_JULIA_OR_DESC_EXECUTED=false")
