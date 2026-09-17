using Test
using SHA

# M5-A is an isolated manufactured lane.  Keep all inputs local to the M4
# declarations and do not load the RuntimeV4 package entry point.
const ROOT = normpath(joinpath(@__DIR__, "../../.."))
const SOURCE_A = joinpath(ROOT, "src", "RuntimeV4", "M4Isolated", "ManufacturedEquationIRV1.jl")
const SOURCE_B = joinpath(ROOT, "src", "RuntimeV4", "M4Isolated", "ManufacturedResidualLoweringV1.jl")
const SOURCE_C = joinpath(ROOT, "src", "RuntimeV4", "M4Isolated", "ManufacturedDiscreteControlV1.jl")
const SOURCE_D = joinpath(ROOT, "src", "RuntimeV4", "M4Isolated", "ManufacturedCoupledSolveControlV1.jl")
const SOURCE_M5 = joinpath(ROOT, "src", "RuntimeV4", "M4Isolated", "ManufacturedAutoCompositionV1.jl")
for path in (SOURCE_A, SOURCE_B, SOURCE_C, SOURCE_D, SOURCE_M5)
    @assert isfile(path) "M5-A source path is missing: $path"
end
include(SOURCE_A)
include(SOURCE_B)
include(SOURCE_C)
include(SOURCE_D)
include(SOURCE_M5)
# TypedASTProgramV1's constructor delegates CSE keys to the package's closed
# canonical helper when the full package is loaded.  The isolated lane keeps a
# small local key adapter so the test remains independent of package loading
# and cannot accidentally exercise a production canonicalization path.
function _typed_ast_cse_key(n::ASTApplyV1, inputs::Tuple,
        nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    repr((operator=n.operator_ref.qualified, manifest_hash=manifest_hash,
        inputs=Tuple(repr(nodes[i]) for i in inputs), parameters=n.parameters,
        output_type=n.output_type))
end
stable_bytes(x) = sprint(show, x)
# M5's payload hash is intentionally usable without the package CanonicalJSON
# dispatcher.  Keep the isolated fallback explicit and deterministic here.
canonical_hash(x) = digest256_text(stable_bytes(x))

failure_codes(r) = Set(f.code for f in r.failures)
failure_signature(r) = [(f.code, f.path, f.detail) for f in r.failures]

function upstream_fixture()
    a = manufactured_equation_ir_v1()
    @assert validate_manufactured_equation_ir(a).valid
    b_result = lower_manufactured_residual(a)
    @assert b_result.valid && b_result.declaration !== nothing
    b = b_result.declaration::ManufacturedResidualDeclarationV1
    c_result = build_manufactured_discrete_control(b, 2, 2, 2)
    @assert c_result.valid && c_result.control !== nothing
    c = c_result.control::ManufacturedDiscreteControlV1
    d_result = build_manufactured_coupled_solve_control(c, c)
    @assert d_result.valid && d_result.control !== nothing
    d = d_result.control::ManufacturedCoupledSolveControlV1
    a, b, c, d
end

function clone_port(p::ManufacturedAutoPortV1; kwargs...)
    vals = (stage=p.stage, port_id=p.port_id, side=p.side, index=p.index,
        physical_type=p.physical_type, unit=p.unit, domain_id=p.domain_id,
        equation_id=p.equation_id, source_id=p.source_id,
        conservation_owner=p.conservation_owner, interface_owner=p.interface_owner,
        source_owner=p.source_owner)
    v = merge(vals, (; kwargs...))
    ManufacturedAutoPortV1(v...)
end

function clone_product(x::ManufacturedAutoCompositionV1; kwargs...)
    vals = (schema=x.schema, canonical_program=x.canonical_program,
        canonical_graph=x.canonical_graph, stage_programs=x.stage_programs,
        stages=x.stages, ports=x.ports, provenance=x.provenance,
        source_hashes=x.source_hashes, typed_identities=x.typed_identities,
        equation_id=x.equation_id, source_id=x.source_id, domain_id=x.domain_id,
        conservation_owner=x.conservation_owner, interface_owner=x.interface_owner,
        source_owner=x.source_owner, d_test_sha256=x.d_test_sha256,
        d_oracle_sha256=x.d_oracle_sha256, claim_ceiling=x.claim_ceiling,
        evidence_scope=x.evidence_scope)
    v = merge(vals, (; kwargs...))
    ManufacturedAutoCompositionV1(v...)
end

function expect_typed(thunk, code::Symbol; status=:typed_failure)
    result = try
        thunk()
    catch err
        println(stderr, "unexpected unclassified exception: $(typeof(err)): $(sprint(showerror, err))")
        @test false
        return nothing
    end
    @test result isa ManufacturedAutoCompositionResultV1
    if result isa ManufacturedAutoCompositionResultV1
        @test !result.valid
        @test result.status == status
        @test code in failure_codes(result)
    end
    result
end

@testset "M5-A manufactured auto-composition v1" begin
    a, b, c, d = upstream_fixture()
    result = build_manufactured_auto_composition(a, b, c, d)
    @test result.valid
    @test result.status == :valid
    @test isempty(result.failures)
    @test result.composition !== nothing
    product = result.composition::ManufacturedAutoCompositionV1
    @test validate_manufactured_auto_composition(product).valid
    @test is_valid_manufactured_auto_composition_v1(product)
    @test product.claim_ceiling == :manufactured_auto_composition
    @test product.evidence_scope == :screen_only

    @testset "typed canonical AST/hypergraph and owner-interface ledger joins" begin
        @test product.canonical_program isa TypedASTProgramV1
        @test product.canonical_graph isa TypedOperatorHypergraphV1
        @test length(product.canonical_program.nodes) == 8
        @test product.canonical_program.roots == (5, 6, 7, 8)
        @test product.canonical_program.input_ports == (1, 2, 3)
        @test length(product.canonical_graph.nodes) == 7
        @test length(product.canonical_graph.hyperedges) == 4
        @test Tuple(e.edge_id for e in product.canonical_graph.hyperedges) ==
            ("M5-A", "M5-B", "M5-C", "M5-D")
        @test Tuple(p.port_id for p in product.ports) ==
            ("A.u", "A.K", "A.f", "A.residual", "B.residual", "C.control", "D.solution")
        @test Tuple(s.stage for s in product.stages) == (:A, :B, :C, :D)
        @test product.stages[2].input_port_ids == ("A.residual",)
        @test product.stages[3].input_port_ids == ("B.residual",)
        @test product.stages[4].input_port_ids == ("C.control",)
        @test all(p -> p.domain_id == product.domain_id && p.equation_id == product.equation_id &&
            p.source_id == product.source_id, product.ports)
        @test all(p -> p.conservation_owner == product.conservation_owner &&
            p.interface_owner == product.interface_owner && p.source_owner == product.source_owner,
            product.ports)
        @test Tuple(p.stage for p in product.provenance) == (:A, :B, :C, :D)
        @test all(p -> p.claim_ceiling == :manufactured_auto_composition &&
            p.evidence_scope == :screen_only, product.provenance)
        @test product.source_hashes == M5A_SOURCE_SHA256_V1
        @test product.d_test_sha256 == M5A_D_TEST_SHA256_V1
        @test product.d_oracle_sha256 == M5A_D_ORACLE_SHA256_V1
        @test product.typed_identities ==
            (A=_m5_stage_identity(:A, M5A_SOURCE_SHA256_V1.A),
             B=_m5_stage_identity(:B, M5A_SOURCE_SHA256_V1.B),
             C=_m5_stage_identity(:C, M5A_SOURCE_SHA256_V1.C),
             D=_m5_stage_identity(:D, M5A_SOURCE_SHA256_V1.D))
    end

    @testset "payload and hash determinism; supported permutation normalization" begin
        payload_1 = stable_bytes(manufactured_auto_composition_payload(product))
        payload_2 = stable_bytes(manufactured_auto_composition_payload(
            build_manufactured_auto_composition(a, b, c, d).composition))
        @test payload_1 == payload_2
        @test manufactured_auto_composition_hash(product) ==
            manufactured_auto_composition_hash(build_manufactured_auto_composition(a, b, c, d).composition)

        # The public payload/hash API sorts the three metadata collections by
        # their frozen identities.  This is the permutation range it exposes;
        # graph/node order remains a validated contract.
        permuted = clone_product(product;
            stages=(product.stages[4], product.stages[2], product.stages[1], product.stages[3]),
            ports=(product.ports[7], product.ports[2], product.ports[4], product.ports[1],
                   product.ports[6], product.ports[3], product.ports[5]),
            provenance=(product.provenance[3], product.provenance[1], product.provenance[4], product.provenance[2]))
        @test manufactured_auto_composition_hash(permuted) == manufactured_auto_composition_hash(product)
        @test manufactured_auto_composition_payload(permuted) == manufactured_auto_composition_payload(product)
        @test !validate_manufactured_auto_composition(permuted).valid
        @test :ordering_mismatch in failure_codes(validate_manufactured_auto_composition(permuted))
    end

    @testset "typed rejection controls" begin
        bad_unit = clone_port(product.ports[1]; unit=_m5_unit(M4_AREA_V1))
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; ports=(bad_unit, product.ports[2:end]...))), :unit_mismatch)
        bad_type = PhysicalType(:scalar_field, 1, 3, TemporalTypeV1(static_time), product.ports[1].unit)
        bad_rank = clone_port(product.ports[1]; physical_type=bad_type)
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; ports=(bad_rank, product.ports[2:end]...))), :rank_mismatch)
        bad_port = clone_port(product.ports[1]; port_id="A.foreign")
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; ports=(bad_port, product.ports[2:end]...))), :port_mismatch)
        bad_domain = clone_port(product.ports[1]; domain_id="FOREIGN-DOMAIN")
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; ports=(bad_domain, product.ports[2:end]...))), :owner_mismatch)
        bad_owner = clone_port(product.ports[1]; conservation_owner="FOREIGN-OWNER")
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; ports=(bad_owner, product.ports[2:end]...))), :owner_mismatch)
        bad_interface = clone_port(product.ports[1]; interface_owner="FOREIGN-INTERFACE")
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; ports=(bad_interface, product.ports[2:end]...))), :owner_mismatch)

        expect_typed(() -> build_manufactured_auto_composition(a, b, c, d;
            provider_drop=:manufactured_provider), :provider_drop; status=:terminal_deferred)
        expect_typed(() -> build_manufactured_auto_composition(a, b, c, d; registry=(:missing,)),
            :missing_capability)
        expect_typed(() -> build_manufactured_auto_composition(:A, b, c, d), :invalid_a)
        expect_typed(() -> build_manufactured_auto_composition(a, a, c, d), :invalid_b)
        expect_typed(() -> build_manufactured_auto_composition(a, b, b, d), :invalid_c)
        expect_typed(() -> build_manufactured_auto_composition(a, b, c, c), :invalid_d)
        expect_typed(() -> build_manufactured_auto_composition(a, b, c), :foreign_input)

        foreign_hashes = merge(product.source_hashes, (A=digest256_text("foreign-A"),))
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; source_hashes=foreign_hashes)), :foreign_hash)
        foreign_ids = merge(product.typed_identities, (A=digest256_text("foreign-identity"),))
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; typed_identities=foreign_ids)), :foreign_identity)
        bad_label = (ManufacturedAutoStageV1(:A, "FOREIGN LABEL", product.stages[1].edge_id,
            product.stages[1].input_port_ids, product.stages[1].output_port_ids,
            product.stages[1].graph_input_nodes, product.stages[1].graph_output_nodes,
            product.stages[1].domain_id, product.stages[1].equation_id, product.stages[1].source_id,
            product.stages[1].conservation_owner, product.stages[1].interface_owner,
            product.stages[1].source_owner, product.stages[1].units, product.stages[1].provenance),
            product.stages[2:end]...)
        expect_typed(() -> validate_manufactured_auto_composition(
            clone_product(product; stages=bad_label)), :label_mismatch)
    end

    @testset "failure determinism and screen-only boundary" begin
        bad = clone_product(product; source_owner="FOREIGN-SOURCE-OWNER")
        @test failure_signature(validate_manufactured_auto_composition(bad)) ==
            failure_signature(validate_manufactured_auto_composition(bad))
        @test !isdefined(@__MODULE__, :CandidateStatePackageV5)
        @test !isdefined(@__MODULE__, :RuntimeEvidenceV4)
        @test !isdefined(@__MODULE__, :ForwardChainContextV4)
        @test !isdefined(@__MODULE__, :iterative_solver)
        @test !isdefined(@__MODULE__, :solve_pde)
        @test !isdefined(@__MODULE__, :production_provider)
        @test !isdefined(@__MODULE__, :invoke_provider)
        @test !occursin("default_operator_registry() =", read(SOURCE_M5, String))
        @test !occursin("CandidateStatePackage", read(SOURCE_M5, String))
        @test !occursin("solve_pde", read(SOURCE_M5, String))
    end
end

println("M5-A-TESTS PASS manufactured_auto_composition/screen_only")
