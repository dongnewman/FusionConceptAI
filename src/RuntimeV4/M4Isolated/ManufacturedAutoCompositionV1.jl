"""Isolated M5 manufactured auto-composition fixture.

This file is deliberately an additive, declaration-only lane.  It consumes
the accepted-limited M4-A through M4-D values, checks their identities, and
maps them to the existing typed AST and typed hypergraph representations.
It does not register an operator, resolve a provider, create a candidate,
invoke a solver, or make a physical/engineering claim.
"""

using SHA

# Keep this file usable from a small isolated test module as well as from the
# package entry point.  These includes only load the existing IR/M4 sources;
# none of them is modified by this fixture.
if !isdefined(@__MODULE__, :PhysicalType)
    include(joinpath(@__DIR__, "../../IR/PhysicalTypes.jl"))
end
if !isdefined(@__MODULE__, :ConservationLedgerIdentityV1)
    include(joinpath(@__DIR__, "../../IR/ConservationLedger.jl"))
end
if !isdefined(@__MODULE__, :OperatorRegistryV1)
    include(joinpath(@__DIR__, "../../IR/OperatorRegistry.jl"))
end
if !isdefined(@__MODULE__, :TypedASTProgramV1)
    include(joinpath(@__DIR__, "../../IR/TypedAST.jl"))
end
if !isdefined(@__MODULE__, :TypedOperatorHypergraphV1)
    include(joinpath(@__DIR__, "../../IR/OperatorHypergraph.jl"))
end
if !isdefined(@__MODULE__, :ManufacturedEquationIRV1)
    include(joinpath(@__DIR__, "ManufacturedEquationIRV1.jl"))
end
if !isdefined(@__MODULE__, :ManufacturedResidualDeclarationV1)
    include(joinpath(@__DIR__, "ManufacturedResidualLoweringV1.jl"))
end
if !isdefined(@__MODULE__, :ManufacturedDiscreteControlV1)
    include(joinpath(@__DIR__, "ManufacturedDiscreteControlV1.jl"))
end
if !isdefined(@__MODULE__, :ManufacturedCoupledSolveControlV1)
    include(joinpath(@__DIR__, "ManufacturedCoupledSolveControlV1.jl"))
end

const M5A_AUTOCOMPOSITION_SCHEMA_V1 = "M5-A-MANUFACTURED-AUTO-COMPOSITION-V1"
const M5A_CLAIM_CEILING_V1 = :manufactured_auto_composition
const M5A_EVIDENCE_SCOPE_V1 = :screen_only
const M5A_STAGES_V1 = (:A, :B, :C, :D)

# These are source-file identities frozen by the M5 scope decision.  They are
# deliberately constants rather than values inferred from a mutable checkout.
const M5A_SOURCE_SHA256_V1 = (
    A=Digest256("0b456dcc0df3bd13a1941aa502a9cc5347912b2fa86cda6c65900449299b8e57"),
    B=Digest256("0445ec58f35ebbf5e34ae032611befab7050a0a65d2a376ccd37b71a0e9a936c"),
    C=Digest256("20804bafb5d42152d220a1d25897f6b460c7056b0c695dbaa5153c0d113710fa"),
    D=Digest256("ec7e82e282f1d1292ddd4b7902e4ced641d926af82119298267011d304a55785"),
)
const M5A_D_TEST_SHA256_V1 = Digest256("1eb0e26e79b9899cc5a3cb2742545cbaa811fa6683fdcfa1ee4dd31dff081686")
const M5A_D_ORACLE_SHA256_V1 = Digest256("9ca3c1c012690c7c06579d0ab5ffd274666e340c900c59e49f7a93408a0fcbe3")
const M5A_FROZEN_A_SOURCE_SHA256_V1 = M5A_SOURCE_SHA256_V1.A
const M5A_FROZEN_B_SOURCE_SHA256_V1 = M5A_SOURCE_SHA256_V1.B
const M5A_FROZEN_C_SOURCE_SHA256_V1 = M5A_SOURCE_SHA256_V1.C
const M5A_FROZEN_D_SOURCE_SHA256_V1 = M5A_SOURCE_SHA256_V1.D

"""A stable typed M5 rejection; no untyped best-effort graph is published."""
struct ManufacturedAutoCompositionFailureV1
    code::Symbol
    path::String
    detail::String
end

_m5_failure(code::Symbol, path::AbstractString, detail::AbstractString) =
    ManufacturedAutoCompositionFailureV1(code, String(path), String(detail))

"""Frozen identity/provenance binding for one consumed M4 stage."""
struct ManufacturedAutoStageProvenanceV1
    stage::Symbol
    source_sha256::Digest256
    typed_identity::Digest256
    schema::String
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

"""An explicit typed port retained alongside the canonical IR port."""
struct ManufacturedAutoPortV1
    stage::Symbol
    port_id::String
    side::Symbol
    index::Int
    physical_type::PhysicalType
    unit::UnitSignature
    domain_id::String
    equation_id::String
    source_id::String
    conservation_owner::String
    interface_owner::String
    source_owner::String
end

"""Stage mapping metadata; ordering and labels are part of the contract."""
struct ManufacturedAutoStageV1
    stage::Symbol
    label::String
    edge_id::String
    input_port_ids::Tuple{Vararg{String}}
    output_port_ids::Tuple{Vararg{String}}
    graph_input_nodes::Tuple{Vararg{Int}}
    graph_output_nodes::Tuple{Vararg{Int}}
    domain_id::String
    equation_id::String
    source_id::String
    conservation_owner::String
    interface_owner::String
    source_owner::String
    units::Tuple{Vararg{UnitSignature}}
    provenance::ManufacturedAutoStageProvenanceV1
end

"""The immutable, isolated manufactured composition product."""
struct ManufacturedAutoCompositionV1
    schema::String
    canonical_program::TypedASTProgramV1
    canonical_graph::TypedOperatorHypergraphV1
    stage_programs::Tuple
    stages::Tuple{Vararg{ManufacturedAutoStageV1}}
    ports::Tuple{Vararg{ManufacturedAutoPortV1}}
    provenance::Tuple{Vararg{ManufacturedAutoStageProvenanceV1}}
    source_hashes::NamedTuple
    typed_identities::NamedTuple
    equation_id::String
    source_id::String
    domain_id::String
    conservation_owner::String
    interface_owner::String
    source_owner::String
    d_test_sha256::Digest256
    d_oracle_sha256::Digest256
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

struct ManufacturedAutoCompositionResultV1
    valid::Bool
    status::Symbol
    composition::Union{Nothing,ManufacturedAutoCompositionV1}
    failures::Tuple{Vararg{ManufacturedAutoCompositionFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

const ManufacturedAutoCompositionValidationV1 = ManufacturedAutoCompositionResultV1

semantic_view(x::ManufacturedAutoStageProvenanceV1) =
    (stage=x.stage, source_sha256=x.source_sha256, typed_identity=x.typed_identity,
     schema=x.schema, claim_ceiling=x.claim_ceiling, evidence_scope=x.evidence_scope)
semantic_view(x::ManufacturedAutoPortV1) =
    (stage=x.stage, port_id=x.port_id, side=x.side, index=x.index,
     physical_type=x.physical_type, unit=x.unit, domain_id=x.domain_id,
     equation_id=x.equation_id, source_id=x.source_id,
     conservation_owner=x.conservation_owner, interface_owner=x.interface_owner,
     source_owner=x.source_owner)
semantic_view(x::ManufacturedAutoStageV1) =
    (stage=x.stage, label=x.label, edge_id=x.edge_id,
     input_port_ids=x.input_port_ids, output_port_ids=x.output_port_ids,
     graph_input_nodes=x.graph_input_nodes, graph_output_nodes=x.graph_output_nodes,
     domain_id=x.domain_id, equation_id=x.equation_id, source_id=x.source_id,
     conservation_owner=x.conservation_owner, interface_owner=x.interface_owner,
     source_owner=x.source_owner, units=x.units, provenance=x.provenance)

_m5_failure_tuple(fs) = Tuple(ManufacturedAutoCompositionFailureV1[f for f in fs])

function _m5_invalid(fs; status::Symbol=:typed_failure)
    ManufacturedAutoCompositionResultV1(false, status, nothing, _m5_failure_tuple(fs),
        M5A_CLAIM_CEILING_V1, M5A_EVIDENCE_SCOPE_V1)
end

function _m5_stage_identity(stage::Symbol, source::Digest256)
    digest256_text(string("M5A|", stage, "|", source.value))
end

_m5_unit(u::M4UnitV1) = UnitSignature(Tuple(Rational{Int64}(x) for x in u.exponents))
_m5_pt(unit::UnitSignature=UnitSignature()) =
    PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)

function _m5_unwrap_a(x)
    x isa ManufacturedEquationIRV1 && return x
    nothing
end
function _m5_unwrap_b(x)
    x isa ManufacturedResidualDeclarationV1 && return x
    x isa ManufacturedResidualLoweringResultV1 && x.valid && x.declaration !== nothing && return x.declaration
    nothing
end
function _m5_unwrap_c(x)
    x isa ManufacturedDiscreteControlV1 && return x
    x isa ManufacturedDiscreteControlResultV1 && x.valid && x.control !== nothing && return x.control
    nothing
end
function _m5_unwrap_d(x)
    x isa ManufacturedCoupledSolveControlV1 && return x
    x isa ManufacturedCoupledSolveControlResultV1 && x.valid && x.control !== nothing && return x.control
    nothing
end

function _m5_check_upstream!(fs, a, b, c, d)
    a === nothing && push!(fs, _m5_failure(:invalid_a, "A", "input is not a ManufacturedEquationIRV1"))
    b === nothing && push!(fs, _m5_failure(:invalid_b, "B", "input is not a valid manufactured residual declaration"))
    c === nothing && push!(fs, _m5_failure(:invalid_c, "C", "input is not a valid manufactured discrete control"))
    d === nothing && push!(fs, _m5_failure(:invalid_d, "D", "input is not a valid manufactured coupled-solve control"))
    a === nothing || begin
        r = validate_manufactured_equation_ir(a)
        r.valid || foreach(f -> push!(fs, _m5_failure(:invalid_a, string("A.", f.path), f.detail)), r.failures)
    end
    b === nothing || begin
        r = a === nothing ? validate_manufactured_residual(b) : validate_manufactured_residual(b, a)
        r.valid || foreach(f -> push!(fs, _m5_failure(:invalid_b, string("B.", f.path), f.detail)), r.failures)
        a === nothing || (b.equation_id == a.equation_id && b.domain == a.domain ||
            push!(fs, _m5_failure(:foreign_hash, "B.input", "B is not bound to the supplied A identity")))
    end
    c === nothing || begin
        r = validate_manufactured_discrete_control(c)
        r.valid || foreach(f -> push!(fs, _m5_failure(:invalid_c, string("C.", f.path), f.detail)), r.failures)
        b === nothing || (c.residual == b ||
            push!(fs, _m5_failure(:foreign_hash, "C.input", "C is not bound to the supplied B identity")))
    end
    d === nothing || begin
        r = validate_manufactured_coupled_solve_control(d)
        r.valid || foreach(f -> push!(fs, _m5_failure(:invalid_d, string("D.", f.path), f.detail)), r.failures)
        c === nothing || (d.left == c || d.right == c ||
            push!(fs, _m5_failure(:foreign_hash, "D.input", "D does not contain the supplied C identity")))
        b === nothing || (d.left.residual == b && d.right.residual == b ||
            push!(fs, _m5_failure(:foreign_hash, "D.B-input", "D nested controls are not bound to the supplied B identity")))
    end
    nothing
end

function _m5_canonical_program(pt::PhysicalType; registry::OperatorRegistryV1)
    i1, i2, i3 = ASTInputV1(1, pt), ASTInputV1(2, pt), ASTInputV1(3, pt)
    add = OperatorRefV1("ADD", "v1")
    ident = OperatorRefV1("IDENTITY", "v1")
    n4 = ASTApplyV1(add, (1, 2), (;); registry=registry, input_types=(pt, pt))
    n5 = ASTApplyV1(add, (4, 3), (;); registry=registry, input_types=(pt, pt))
    n6 = ASTApplyV1(ident, (5,), (;); registry=registry, input_types=(pt,))
    n7 = ASTApplyV1(ident, (6,), (;); registry=registry, input_types=(pt,))
    n8 = ASTApplyV1(ident, (7,), (;); registry=registry, input_types=(pt,))
    TypedASTProgramV1((i1, i2, i3, n4, n5, n6, n7, n8), (5, 6, 7, 8), (1, 2, 3); registry=registry)
end

function _m5_stage_ast(ninputs::Int, pt::PhysicalType; registry::OperatorRegistryV1)
    ninputs == 1 && return TypedAST((TypedASTNode(:state, (), pt),
        TypedASTNode(:identity, (1,), pt)), 2, (1,))
    ninputs == 3 || throw(ArgumentError("M5 stage AST arity is not supported"))
    TypedAST((TypedASTNode(:state, (), pt), TypedASTNode(:state, (), pt),
        TypedASTNode(:state, (), pt), TypedASTNode(:add, (1, 2), pt),
        TypedASTNode(:add, (4, 3), pt)), 5, (1, 2, 3); registry=registry)
end

function _m5_expected_ports(a, d, pt)
    u = _m5_unit(a.scalar_field.units)
    k = _m5_unit(a.coefficient.units)
    f = _m5_unit(a.source.units)
    # The canonical AST is dimensionally closed under the existing registry;
    # the original M4 units remain explicit here and are validated separately.
    common = (a.domain.id, a.equation_id, a.source.id, d.conservation_owner,
              d.interface.conservation_owner, d.source_owner)
    p = ManufacturedAutoPortV1[]
    push!(p, ManufacturedAutoPortV1(:A, "A.u", :input, 1, pt, u, common...))
    push!(p, ManufacturedAutoPortV1(:A, "A.K", :input, 2, pt, k, common...))
    push!(p, ManufacturedAutoPortV1(:A, "A.f", :input, 3, pt, f, common...))
    for (stage, id, unit, index) in ((:A, "A.residual", u, 1), (:B, "B.residual", u, 1),
                                     (:C, "C.control", f, 1), (:D, "D.solution", u, 1))
        push!(p, ManufacturedAutoPortV1(stage, id, :output, index, pt, unit, common...))
    end
    Tuple(p)
end

function _m5_build_product(a, b, c, d; registry=nothing)
    registry_obj = registry === nothing ? default_operator_registry() : registry
    registry_obj isa OperatorRegistryV1 || throw(ArgumentError("registry must be OperatorRegistryV1"))
    pt = _m5_pt(_m5_unit(a.scalar_field.units))
    program = _m5_canonical_program(pt; registry=registry_obj)
    stage_programs = (_m5_stage_ast(3, pt; registry=registry_obj),
                      _m5_stage_ast(1, pt; registry=registry_obj),
                      _m5_stage_ast(1, pt; registry=registry_obj),
                      _m5_stage_ast(1, pt; registry=registry_obj))
    nodes = (node(:input, pt; id="M5-A-input-u", label="M5 A input u"),
             node(:input, pt; id="M5-A-input-K", label="M5 A input K"),
             node(:input, pt; id="M5-A-input-f", label="M5 A input f"),
             node(:stage_output, pt; id="M5-A-output-residual", label="M5 A residual"),
             node(:stage_output, pt; id="M5-B-output-residual", label="M5 B residual"),
             node(:stage_output, pt; id="M5-C-output-control", label="M5 C discrete control"),
             node(:stage_output, pt; id="M5-D-output-solution", label="M5 D coupled solution"))
    edges = (TypedHyperedge("M5-A", (1, 2, 3), (4,), stage_programs[1], :governing),
             TypedHyperedge("M5-B", (4,), (5,), stage_programs[2], :additive),
             TypedHyperedge("M5-C", (5,), (6,), stage_programs[3], :additive),
             TypedHyperedge("M5-D", (6,), (7,), stage_programs[4], :additive))
    graph = TypedOperatorHypergraphV1(nodes, edges; registry=registry_obj)
    hashes = M5A_SOURCE_SHA256_V1
    identities = (A=_m5_stage_identity(:A, hashes.A), B=_m5_stage_identity(:B, hashes.B),
                  C=_m5_stage_identity(:C, hashes.C), D=_m5_stage_identity(:D, hashes.D))
    provenance = Tuple(ManufacturedAutoStageProvenanceV1(stage, hashes[stage], identities[stage],
        stage === :A ? "M4-A" : stage === :B ? "M4-B" : stage === :C ? "M4-C" : "M4-D",
        M5A_CLAIM_CEILING_V1, M5A_EVIDENCE_SCOPE_V1) for stage in M5A_STAGES_V1)
    ports = _m5_expected_ports(a, d, pt)
    stages = (
        ManufacturedAutoStageV1(:A, "M5 A manufactured equation", "M5-A", ("A.u", "A.K", "A.f"), ("A.residual",), (1, 2, 3), (4,), a.domain.id, a.equation_id, a.source.id, d.conservation_owner, d.interface.conservation_owner, d.source_owner, (ports[1].unit, ports[2].unit, ports[3].unit, ports[4].unit), provenance[1]),
        ManufacturedAutoStageV1(:B, "M5 B manufactured residual lowering", "M5-B", ("A.residual",), ("B.residual",), (4,), (5,), a.domain.id, a.equation_id, a.source.id, d.conservation_owner, d.interface.conservation_owner, d.source_owner, (ports[4].unit, ports[5].unit), provenance[2]),
        ManufacturedAutoStageV1(:C, "M5 C manufactured discrete control", "M5-C", ("B.residual",), ("C.control",), (5,), (6,), a.domain.id, a.equation_id, a.source.id, d.conservation_owner, d.interface.conservation_owner, d.source_owner, (ports[5].unit, ports[6].unit), provenance[3]),
        ManufacturedAutoStageV1(:D, "M5 D manufactured coupled solve", "M5-D", ("C.control",), ("D.solution",), (6,), (7,), a.domain.id, a.equation_id, a.source.id, d.conservation_owner, d.interface.conservation_owner, d.source_owner, (ports[6].unit, ports[7].unit), provenance[4]))
    ManufacturedAutoCompositionV1(M5A_AUTOCOMPOSITION_SCHEMA_V1, program, graph,
        stage_programs, stages, ports, provenance, hashes, identities,
        a.equation_id, a.source.id, a.domain.id, d.conservation_owner,
        d.interface.conservation_owner, d.source_owner,
        M5A_D_TEST_SHA256_V1, M5A_D_ORACLE_SHA256_V1,
        M5A_CLAIM_CEILING_V1, M5A_EVIDENCE_SCOPE_V1)
end

function build_manufactured_auto_composition(a_input, b_input, c_input, d_input;
        provider_drop=(), registry=nothing)
    failures = ManufacturedAutoCompositionFailureV1[]
    a, b, c, d = _m5_unwrap_a(a_input), _m5_unwrap_b(b_input), _m5_unwrap_c(c_input), _m5_unwrap_d(d_input)
    drops = provider_drop isa Symbol || provider_drop isa AbstractString ?
        (provider_drop,) : (try Tuple(provider_drop) catch; (:invalid_provider_drop,) end)
    isempty(drops) || push!(failures, _m5_failure(:provider_drop, "provider_drop",
        "provider capability is absent; composition is terminal_deferred and no provider was constructed"))
    _m5_check_upstream!(failures, a, b, c, d)
    isempty(failures) || return _m5_invalid(failures; status=any(f -> f.code === :provider_drop, failures) ? :terminal_deferred : :typed_failure)
    product = try
        _m5_build_product(a, b, c, d; registry=registry)
    catch err
        return _m5_invalid([_m5_failure(:missing_capability, "canonical_ir", sprint(showerror, err))])
    end
    validation = validate_manufactured_auto_composition(product)
    validation.valid ? validation : ManufacturedAutoCompositionResultV1(false, validation.status,
        product, validation.failures, validation.claim_ceiling, validation.evidence_scope)
end

function build_manufactured_auto_composition(args...; kwargs...)
    _m5_invalid([_m5_failure(:foreign_input, "input", "expected one A, B, C and D manufactured value each")])
end

function validate_manufactured_auto_composition(x::ManufacturedAutoCompositionV1)
    fs = ManufacturedAutoCompositionFailureV1[]
    x.schema == M5A_AUTOCOMPOSITION_SCHEMA_V1 || push!(fs, _m5_failure(:foreign_identity, "schema", "schema is not frozen M5-A"))
    x.claim_ceiling == M5A_CLAIM_CEILING_V1 && x.evidence_scope == M5A_EVIDENCE_SCOPE_V1 || push!(fs, _m5_failure(:provenance_mismatch, "claim_ceiling", "M5 remains manufactured/screen_only"))
    x.source_hashes == M5A_SOURCE_SHA256_V1 || push!(fs, _m5_failure(:foreign_hash, "source_hashes", "A-D source hashes are not the frozen scope identities"))
    x.d_test_sha256 == M5A_D_TEST_SHA256_V1 || push!(fs, _m5_failure(:foreign_hash, "D.test_sha256", "D test hash is not the frozen scope identity"))
    x.d_oracle_sha256 == M5A_D_ORACLE_SHA256_V1 || push!(fs, _m5_failure(:foreign_hash, "D.oracle_sha256", "D oracle hash is not the frozen scope identity"))
    for stage in M5A_STAGES_V1
        expected = _m5_stage_identity(stage, M5A_SOURCE_SHA256_V1[stage])
        getproperty(x.typed_identities, stage) == expected || push!(fs, _m5_failure(:foreign_identity, string(stage, ".typed_identity"), "typed identity does not match frozen source hash"))
    end
    length(x.provenance) == 4 || push!(fs, _m5_failure(:provenance_mismatch, "provenance", "one provenance binding per A-D stage is required"))
    length(x.stages) == 4 && length(x.ports) == 7 || push!(fs, _m5_failure(:port_mismatch, "ports", "frozen composition requires four stages and seven ports"))
    labels = ("M5 A manufactured equation", "M5 B manufactured residual lowering", "M5 C manufactured discrete control", "M5 D manufactured coupled solve")
    ids = ("M5-A", "M5-B", "M5-C", "M5-D")
    if length(x.stages) == 4
        for i in 1:4
            s = x.stages[i]
            s.stage == M5A_STAGES_V1[i] || push!(fs, _m5_failure(:ordering_mismatch, "stages", "stage order is not A,B,C,D"))
            s.label == labels[i] && s.edge_id == ids[i] || push!(fs, _m5_failure(:label_mismatch, string("stages[", i, "]"), "stage label or edge identity is not frozen"))
            s.provenance == x.provenance[i] || push!(fs, _m5_failure(:provenance_mismatch, string("stages[", i, "].provenance"), "stage provenance join is foreign"))
        end
    end
    expected_port_ids = ("A.u", "A.K", "A.f", "A.residual", "B.residual", "C.control", "D.solution")
    length(x.ports) == 7 && Tuple(p.port_id for p in x.ports) == expected_port_ids || push!(fs, _m5_failure(:port_mismatch, "ports.order", "port order or identity is not frozen"))
    expected_units = (_m5_unit(M4_DIMENSIONLESS_V1), _m5_unit(M4_AREA_V1), _m5_unit(M4_DIMENSIONLESS_V1),
                      _m5_unit(M4_DIMENSIONLESS_V1), _m5_unit(M4_DIMENSIONLESS_V1), _m5_unit(M4_DIMENSIONLESS_V1), _m5_unit(M4_DIMENSIONLESS_V1))
    if length(x.ports) == 7
        for i in 1:7
            p = x.ports[i]
            p.unit == expected_units[i] || push!(fs, _m5_failure(:unit_mismatch, string("ports[", i, "].unit"), "port unit is not bound to the frozen M4 unit"))
            p.physical_type.value_kind == :scalar_field && p.physical_type.tensor_rank == 0 && p.physical_type.spatial_dimension == 3 ||
                push!(fs, _m5_failure(:rank_mismatch, string("ports[", i, "].physical_type"), "port rank/value kind/dimension is not scalar 3-D"))
            p.domain_id == x.domain_id && p.equation_id == x.equation_id && p.source_id == x.source_id &&
                p.conservation_owner == x.conservation_owner && p.interface_owner == x.interface_owner && p.source_owner == x.source_owner ||
                push!(fs, _m5_failure(:owner_mismatch, string("ports[", i, "].binding"), "port domain/equation/source/owner join is foreign"))
        end
    end
    try
        length(x.canonical_graph.nodes) == 7 && length(x.canonical_graph.hyperedges) == 4 || push!(fs, _m5_failure(:graph_mismatch, "canonical_graph", "graph must contain seven nodes and four edges"))
        Tuple(e.edge_id for e in x.canonical_graph.hyperedges) == ids || push!(fs, _m5_failure(:ordering_mismatch, "canonical_graph.hyperedges", "edge ordering is not A,B,C,D"))
        Tuple(n.node_id for n in x.canonical_graph.nodes) == ("M5-A-input-u", "M5-A-input-K", "M5-A-input-f", "M5-A-output-residual", "M5-B-output-residual", "M5-C-output-control", "M5-D-output-solution") || push!(fs, _m5_failure(:label_mismatch, "canonical_graph.nodes", "node labels/IDs are not frozen"))
    catch err
        push!(fs, _m5_failure(:graph_mismatch, "canonical_graph", sprint(showerror, err)))
    end
    try
        x.canonical_graph isa TypedOperatorHypergraphV1 || push!(fs, _m5_failure(:graph_mismatch, "canonical_graph", "graph is not typed"))
        x.canonical_program isa TypedASTProgramV1 || push!(fs, _m5_failure(:program_mismatch, "canonical_program", "program is not typed"))
    catch err
        push!(fs, _m5_failure(:canonical_ir_failure, "canonical_ir", sprint(showerror, err)))
    end
    ManufacturedAutoCompositionResultV1(isempty(fs), isempty(fs) ? :valid : :typed_failure,
        x, _m5_failure_tuple(fs), x.claim_ceiling, x.evidence_scope)
end

function validate_manufactured_auto_composition(x)
    _m5_invalid([_m5_failure(:foreign_input, "input", "input must be ManufacturedAutoCompositionV1")])
end
function validate_manufactured_auto_composition(r::ManufacturedAutoCompositionResultV1)
    r.composition === nothing ? r : validate_manufactured_auto_composition(r.composition)
end

function _m5_program_payload(p::TypedASTProgramV1)
    # Keep the payload bytes independent of ambient canonical method loading.
    # This explicit projection is the pre-existing isolated representation.
    (nodes=Tuple(semantic_view(n) for n in p.nodes), roots=p.roots,
     input_ports=p.input_ports, used_manifest_bindings=p.used_manifest_bindings)
end

function manufactured_auto_composition_payload(x::ManufacturedAutoCompositionV1)
    ordered_stages = Tuple(sort(collect(x.stages), by=s -> String(s.stage)))
    ordered_ports = Tuple(sort(collect(x.ports), by=p -> p.port_id))
    ordered_provenance = Tuple(sort(collect(x.provenance), by=p -> String(p.stage)))
    (schema=x.schema, canonical_program=_m5_program_payload(x.canonical_program),
     canonical_graph=semantic_view(x.canonical_graph),
     stages=Tuple((stage=s.stage, label=s.label, edge_id=s.edge_id,
                   inputs=s.input_port_ids, outputs=s.output_port_ids,
                   graph_inputs=s.graph_input_nodes, graph_outputs=s.graph_output_nodes,
                   domain_id=s.domain_id, equation_id=s.equation_id, source_id=s.source_id,
                   conservation_owner=s.conservation_owner,
                   interface_owner=s.interface_owner, source_owner=s.source_owner,
                   units=s.units, provenance=semantic_view(s.provenance)) for s in ordered_stages),
     ports=Tuple((stage=p.stage, id=p.port_id, side=p.side, index=p.index,
                  physical_type=semantic_view(p.physical_type), unit=p.unit,
                  domain_id=p.domain_id, equation_id=p.equation_id, source_id=p.source_id,
                  conservation_owner=p.conservation_owner,
                  interface_owner=p.interface_owner, source_owner=p.source_owner) for p in ordered_ports),
     provenance=Tuple(semantic_view(p) for p in ordered_provenance),
     source_hashes=x.source_hashes, typed_identities=x.typed_identities,
     d_test_sha256=x.d_test_sha256, d_oracle_sha256=x.d_oracle_sha256,
     equation_id=x.equation_id, source_id=x.source_id, domain_id=x.domain_id,
     conservation_owner=x.conservation_owner, interface_owner=x.interface_owner,
     source_owner=x.source_owner, claim_ceiling=x.claim_ceiling,
     evidence_scope=x.evidence_scope)
end

manufactured_auto_composition_payload(x) = (schema=M5A_AUTOCOMPOSITION_SCHEMA_V1,
    status=:typed_failure, input_type=typeof(x))

is_valid_manufactured_auto_composition(x::ManufacturedAutoCompositionV1) =
    validate_manufactured_auto_composition(x).valid
is_valid_manufactured_auto_composition(x::ManufacturedAutoCompositionResultV1) = x.valid
is_valid_manufactured_auto_composition(x) = false

const manufactured_auto_composition_v1 = build_manufactured_auto_composition
const manufactured_auto_composition = build_manufactured_auto_composition
const validate_manufactured_auto_composition_v1 = validate_manufactured_auto_composition
const manufactured_auto_composition_payload_v1 = manufactured_auto_composition_payload
const is_valid_manufactured_auto_composition_v1 = is_valid_manufactured_auto_composition

function manufactured_auto_composition_hash(x::ManufacturedAutoCompositionV1)
    payload = manufactured_auto_composition_payload(x)
    digest256_text(string(payload))
end
const manufactured_auto_composition_hash_v1 = manufactured_auto_composition_hash
