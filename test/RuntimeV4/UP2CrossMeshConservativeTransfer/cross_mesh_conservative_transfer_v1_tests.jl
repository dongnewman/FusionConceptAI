"""Executable tests for the additive UP2 cross-mesh transfer slice.

The nominal assertions call the transfer and diffusion functions themselves;
no expected result is manufactured by the test.  This file is a supplied
Julia lane and is intentionally not run by the Python-only handoff.
"""

using Test
using FusionConceptAI

const _CM_ROOT = normpath(joinpath(@__DIR__, "../../.."))
FusionConceptAI.load_genome_v5_components!()
include(joinpath(_CM_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(FusionConceptAI, joinpath(_CM_ROOT, "src", "RuntimeV4",
    "DeclaredG123DiffusionExecutionV1.jl"))
Base.include(FusionConceptAI, joinpath(_CM_ROOT, "src", "RuntimeV4",
    "DeclaredCrossMeshConservativeTransferExecutionV1.jl"))

function _cm_input()
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
    dgd_input_v1(_T0L_CANDIDATE, g1, g2, g3, admission.transport)
end

function _cm_case()
    input = _cm_input()
    identity = declared_cross_mesh_identity_v1(input)
    source = declared_cross_mesh_v1(identity, :source, "mesh:source-2", "space:up2",
        (0.0, 0.5, 1.0); owners=("owner:s1", "owner:s2"))
    target = declared_cross_mesh_v1(identity, :target, "mesh:target-4", "space:up2",
        (0.0, 0.25, 0.5, 0.75, 1.0);
        owners=("owner:t1", "owner:t2", "owner:t3", "owner:t4"))
    unit = DeclaredCrossMeshUnitV1("field-SI")
    accounts = DeclaredCrossMeshAccountsV1(
        DeclaredCrossMeshAccountV1("account:source", :source, unit, :minus, "owner:s1"),
        DeclaredCrossMeshAccountV1("account:target", :target, unit, :plus, "owner:t1"),
        DeclaredCrossMeshAccountV1("account:external", :external, unit, :plus, "owner:external"),
        DeclaredCrossMeshAccountV1("account:return", :target, unit, :plus, "owner:t1"))
    (input=input, identity=identity, source=source, target=target, accounts=accounts)
end

@testset "UP2 candidate-bound two-to-four cross-mesh conservation" begin
    c = _cm_case()
    transfer = declared_cross_mesh_transfer_v1(c.input, c.identity, c.source, c.target,
        (0.25, 0.75); accounts=c.accounts)
    @test transfer.status === :ready
    out = execute_declared_cross_mesh_v1(c.input, c.identity, c.source, c.target,
        (0.25, 0.75); accounts=c.accounts, left_boundary=0.0, right_boundary=1.0)
    @test out.status === :ready
    @test out.code === :one_dimensional_diffusion_solved
    @test out.accepted === false
    @test out.claim_ceiling === :screen_only
    @test out.screen_only
    @test out.formal_up2_credit === false && out.formal_up_credit === false
    @test out.formal_r_credit === false && out.no_up2
    @test out.provider_calls == 0 && out.mesh_calls == 0
    @test out.solver_invocations == 1
    @test length(out.transfer.transferred_state) == 4
    @test out.source_mesh_hash != out.target_mesh_hash
    @test out.transfer.source_integrated_total ≈ 0.5 atol=1e-12
    @test out.transfer.target_integrated_total ≈ 0.5 atol=1e-12
    @test out.transfer.transferred_state == (0.25, 0.25, 0.75, 0.75)
    @test out.transfer.overlap_lengths == [0.25 0.25 0.0 0.0; 0.0 0.0 0.25 0.25]
    @test out.transfer.overlap_proportions == [1.0 1.0 0.0 0.0; 0.0 0.0 1.0 1.0]
    @test abs(out.transfer.global_defect) ≤ 1e-12
    @test out.transfer.source_overlap_coverage ≈ 1.0 atol=1e-12
    @test out.transfer.target_overlap_coverage ≈ 1.0 atol=1e-12
    @test all(abs(x) ≤ 1e-12 for x in out.transfer.local_defects)
    @test length(out.transfer.interface_defects) == 1
    @test all(abs(x) ≤ 1e-12 for x in out.transfer.interface_defects)
    @test out.transfer.interface_faces[1] == "0.5:owner:s1->owner:s2"
    @test out.diffusion.matrix == [8.0 -4.0 0.0 0.0; -4.0 8.0 -4.0 0.0;
        0.0 -4.0 8.0 -4.0; 0.0 0.0 -4.0 8.0]
    @test out.diffusion.rhs == [0.25, 0.25, 0.75, 4.75]
    @test all(isapprox.(out.diffusion.solution, [0.4, 0.7375, 1.0125, 1.1]; atol=1e-12))
    @test out.diffusion.residual_norm ≤ 1e-12
    @test out.diffusion.solver_invocations == 1
end

@testset "UP2 cross-mesh typed negative dispatch" begin
    c = _cm_case()
    negatives = Dict{String,Tuple{Symbol,Symbol}}()
    wrong_candidate = QualifiedRefV1("foreign://candidate", "v5")
    bad_identity = DeclaredCrossMeshIdentityV1(wrong_candidate, c.identity.source_hash,
        c.identity.body_hash, c.identity.bundle_hash, c.identity.axis_hashes)
    x = execute_declared_cross_mesh_v1(c.input, bad_identity, c.source, c.target, (0.25,0.75); accounts=c.accounts)
    negatives["wrong_candidate"] = (x.status,x.code)
    @test x.status === :fail_closed && x.code === :candidate_mismatch

    bad_body = DeclaredCrossMeshIdentityV1(c.identity.candidate_ref, c.identity.source_hash,
        "forged-body-hash", c.identity.bundle_hash, c.identity.axis_hashes)
    x = execute_declared_cross_mesh_v1(c.input, bad_body, c.source, c.target, (0.25,0.75); accounts=c.accounts)
    negatives["wrong_body"] = (x.status,x.code)
    @test x.status === :fail_closed && x.code === :body_hash_mismatch

    outside = declared_cross_mesh_v1(c.identity, :target, "mesh:target-outside", "space:up2",
        (2.0, 2.5, 3.0, 3.5, 4.0); owners=("owner:t1","owner:t2","owner:t3","owner:t4"))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,outside,(0.25,0.75);accounts=c.accounts)
    negatives["noncovering_overlap"] = (x.status,x.code)
    @test x.status === :terminal_deferred

    bad_orientation = DeclaredCrossMeshAccountsV1(
        c.accounts.source, DeclaredCrossMeshAccountV1("account:target", :target,
            c.accounts.target.unit, :minus, "owner:t1"), c.accounts.external, c.accounts.return_account)
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=bad_orientation)
    negatives["orientation"] = (x.status,x.code)
    @test x.status === :fail_closed

    bad_unit = DeclaredCrossMeshAccountsV1(c.accounts.source,
        DeclaredCrossMeshAccountV1("account:target", :target, DeclaredCrossMeshUnitV1("seconds",(0,0,1,0,0,0,0)), :plus, "owner:t1"),
        c.accounts.external,c.accounts.return_account)
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=bad_unit)
    negatives["unit"] = (x.status,x.code)
    @test x.status === :fail_closed

    missing = DeclaredCrossMeshAccountsV1(c.accounts.source,c.accounts.target,nothing,c.accounts.return_account)
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=missing)
    negatives["missing_external"] = (x.status,x.code)
    @test x.status === :terminal_deferred

    zero_measure = declared_cross_mesh_v1(c.identity,:target,"mesh:zero","space:up2",
        (0.0,0.25,0.5,0.75,1.0);owners=("owner:t1","owner:t2","owner:t3","owner:t4"),
        cell_measures=(0.25,0.25,0.25,0.0))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,zero_measure,(0.25,0.75);accounts=c.accounts)
    negatives["zero_measure"] = (x.status,x.code)
    @test x.status === :numerical_fail

    mismatched_measure = declared_cross_mesh_v1(c.identity,:target,"mesh:mismatched","space:up2",
        (0.0,0.25,0.5,0.75,1.0);owners=("owner:t1","owner:t2","owner:t3","owner:t4"),
        cell_measures=(0.25,0.25,0.25,0.2501))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,mismatched_measure,(0.25,0.75);accounts=c.accounts)
    negatives["mismatched_measure"] = (x.status,x.code)
    @test x.status === :fail_closed && x.code === :mismatched_measure

    nonfinite = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(NaN,0.75);accounts=c.accounts)
    @test nonfinite.status === :numerical_fail
    shape = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,);accounts=c.accounts)
    @test shape.status === :fail_closed
    wrong_owner = DeclaredCrossMeshAccountsV1(c.accounts.source,
        DeclaredCrossMeshAccountV1("account:target",:target,c.accounts.target.unit,:plus,"owner:foreign"),
        c.accounts.external,c.accounts.return_account)
    owner = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,c.target,(0.25,0.75);accounts=wrong_owner)
    @test owner.status === :fail_closed && owner.code === :owner_mismatch
    forged_mesh = DeclaredCrossMeshV1(c.target.side,c.target.mesh_ref,c.target.space_ref,c.target.cells,
        c.target.dof_ownership,c.target.identity,"forged-mesh-hash")
    mesh_hash = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,forged_mesh,(0.25,0.75);accounts=c.accounts)
    @test mesh_hash.status === :fail_closed && mesh_hash.code === :mesh_hash_mismatch
    wrong_side = DeclaredCrossMeshV1(:source,c.target.mesh_ref,c.target.space_ref,c.target.cells,
        c.target.dof_ownership,c.target.identity,c.target.mesh_hash)
    side = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,wrong_side,(0.25,0.75);accounts=c.accounts)
    @test side.status === :fail_closed && side.code === :mesh_side_mismatch
    axis_bad = DeclaredCrossMeshIdentityV1(c.identity.candidate_ref,c.identity.source_hash,
        c.identity.body_hash,c.identity.bundle_hash,("wrong-axis",c.identity.axis_hashes[2],c.identity.axis_hashes[3]))
    axis = execute_declared_cross_mesh_v1(c.input,axis_bad,c.source,c.target,(0.25,0.75);accounts=c.accounts)
    @test axis.status === :fail_closed && axis.code === :axis_hash_mismatch

    @test_throws ArgumentError DeclaredCrossMeshUnitV1("nan-scale"; scale_to_si=NaN)
    @test_throws ArgumentError DeclaredCrossMeshUnitV1("zero-scale"; scale_to_si=0.0)
    @test_throws ArgumentError DeclaredCrossMeshUnitV1("negative-scale"; scale_to_si=-1.0)

    # A deliberately overlapping target mesh has exact per-cell geometry but
    # source coverage above one; coverage must be an equality gate, not a
    # lower-bound gate.  The explicit hash keeps this negative on the executor.
    overlap_cells = (DeclaredCrossMeshCellV1("cell:target:1", 0.0, 0.75; owner_ref="owner:t1"),
        DeclaredCrossMeshCellV1("cell:target:2", 0.25, 1.0; owner_ref="owner:t2"))
    overlap_mesh_0 = DeclaredCrossMeshV1(:target, "mesh:overcoverage", "space:up2",
        overlap_cells, ("owner:t1", "owner:t2"), c.identity, "")
    overlap_mesh = DeclaredCrossMeshV1(overlap_mesh_0.side, overlap_mesh_0.mesh_ref,
        overlap_mesh_0.space_ref, overlap_mesh_0.cells, overlap_mesh_0.dof_ownership,
        overlap_mesh_0.identity, FusionConceptAI._dcm_hash(FusionConceptAI._dcm_mesh_body(overlap_mesh_0)))
    x = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,overlap_mesh,(0.25,0.75);accounts=c.accounts)
    negatives["overcoverage"] = (x.status,x.code)
    @test x.status === :terminal_deferred && x.code === :overcovering_overlap

    # Finite arithmetic conservation defects are fail-closed, not numerical
    # failures.  This payload is intentionally large enough to expose a
    # reproducible floating-point defect above the 1e-12 gate.
    defect_mesh = declared_cross_mesh_v1(c.identity,:target,"mesh:defect","space:up2",
        (0.0,0.2,0.4,0.6,0.8,1.0);
        owners=("owner:t1","owner:t2","owner:t3","owner:t4","owner:t5"))
    defect = execute_declared_cross_mesh_v1(c.input,c.identity,c.source,defect_mesh,
        (1.0e15,-999999999999999.0);accounts=c.accounts)
    negatives["nonzero_defect"] = (defect.status,defect.code)
    @test defect.status === :fail_closed && defect.code === :conservation_defect
    # Identity is checked before numeric state, so a foreign candidate cannot
    # be masked by a NaN numerical payload.
    priority = execute_declared_cross_mesh_v1(c.input,bad_identity,c.source,c.target,(NaN,0.75);accounts=c.accounts)
    @test priority.status === :fail_closed && priority.code === :candidate_mismatch
    @test !isempty(negatives)
end

println("DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_JULIA_COMMAND_DEFINED=true")
println("DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_JULIA_OR_DESC_EXECUTED=false")
