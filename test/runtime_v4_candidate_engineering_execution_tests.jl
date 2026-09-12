using Test
using LinearAlgebra
using FusionConceptAI

# No DESC process is started by this focused model/admission test.
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_desc_geometry_program_interpreter.jl"))
const CEET = DGPI
Base.include(CEET, joinpath(@__DIR__, "..", "src", "RuntimeV4", "CandidateEngineeringExecutionV4.jl"))

@testset "plasma momentum-flux analytic invariants" begin
    # Use mu0=2 for exact rational model cases; these are not device observations.
    hydro = CEET.candidate_plasma_momentum_flux(3.0, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0), 2.0)
    @test hydro.momentum_flux_xyz_Pa == ((3.0, 0.0, 0.0), (0.0, 3.0, 0.0), (0.0, 0.0, 3.0))
    @test hydro.traction_xyz_Pa == (3.0, 0.0, 0.0)
    @test hydro.magnetic_energy_density_J_m3 == 0.0
    parallel = CEET.candidate_plasma_momentum_flux(3.0, (2.0, 0.0, 0.0), (1.0, 0.0, 0.0), 2.0)
    transverse = CEET.candidate_plasma_momentum_flux(3.0, (2.0, 0.0, 0.0), (0.0, 1.0, 0.0), 2.0)
    @test parallel.traction_xyz_Pa == (2.0, 0.0, 0.0)
    @test transverse.traction_xyz_Pa == (0.0, 4.0, 0.0)
    @test parallel.magnetic_energy_density_J_m3 == 1.0
    # Oblique field has nonzero shear; magnetic normal sign and tensor symmetry matter.
    oblique = CEET.candidate_plasma_momentum_flux(2.0, (1.0, 2.0, 2.0), (1.0, 0.0, 0.0), 2.0)
    matrix = [oblique.momentum_flux_xyz_Pa[i][j] for i in 1:3, j in 1:3]
    @test issymmetric(matrix)
    @test eigvals(Symmetric(matrix)) ≈ [-0.25, 4.25, 4.25]
    @test oblique.traction_xyz_Pa == (3.75, -1.0, -1.0)
    @test oblique.normal_traction_Pa == 3.75
    @test oblique.tangential_traction_xyz_Pa == (0.0, -1.0, -1.0)
    Q = [0.0 -1.0 0.0; 1.0 0.0 0.0; 0.0 0.0 1.0]
    rotated = CEET.candidate_plasma_momentum_flux(2.0, Tuple(Q*[1.0, 2.0, 2.0]), Tuple(Q*[1.0, 0.0, 0.0]), 2.0)
    @test collect(rotated.traction_xyz_Pa) ≈ Q*collect(oblique.traction_xyz_Pa)
    @test rotated.magnetic_energy_density_J_m3 == oblique.magnetic_energy_density_J_m3
    @test_throws ArgumentError CEET.candidate_plasma_momentum_flux(-1.0, (1, 0, 0), (1, 0, 0), 2.0)
    @test_throws ArgumentError CEET.candidate_plasma_momentum_flux(1.0, (1, 0, 0), (0, 0, 0), 2.0)
    @test_throws ArgumentError CEET.candidate_plasma_momentum_flux(1.0, (1, 0, 0), (1, 0, 0), 0.0)
    @test_throws ArgumentError CEET.candidate_plasma_momentum_flux(1.0, (NaN, 0, 0), (1, 0, 0), 2.0)
end

@testset "same current candidate G3 absence is explicit" begin
    audit = CEET.candidate_engineering_declaration_audit(dgpi_context)
    @test audit.g3_hash == canonical_hash(dgpi_candidate.realization_control_genome_ref)
    @test audit.realization_payload_count == audit.control_payload_count == 0
    @test audit.realization_operator_count == audit.control_operator_count == 0
    gaps = CEET._cee_gaps(audit)
    @test length(gaps) == 8
    @test length(unique(g.code for g in gaps)) == 8
    @test Set(g.domain for g in gaps) == Set((:engineering, :control, :fault))
    @test all(g -> g.status === :unsupported && g.recoverable && g.g3_hash == audit.g3_hash, gaps)
    @test all(g -> canonical_hash(g) == g.gap_hash, gaps)
    @test all(g -> !isempty(g.required_inputs), gaps)
    @test_throws ArgumentError CEET.execute_candidate_engineering(dgpi_context, (), nothing, nothing)
    # Gaps cannot be promoted merely by recomputing their hash.
    forged = merge(semantic_view(first(gaps)), (status=:pass,))
    forged_gap = CEET.CandidateEngineeringGapV4(CEET._CEE_TOKEN, values(forged)..., canonical_hash(forged))
    @test_throws ArgumentError canonical_hash(forged_gap)
end
println("CANDIDATE_ENGINEERING_MODEL_FOCUSED_EXIT_CODE=0")
