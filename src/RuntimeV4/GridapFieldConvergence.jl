"""B2 additive, candidate-bound Gridap spatial convergence study.

This layer deliberately consumes only the typed B1 compilation and its public
solve entry point.  It owns the convergence receipt and never changes B1.
"""

using LinearAlgebra
using Gridap
using SHA

const _GRIDAP_B2_TOKEN = Ref{Nothing}(nothing)
const _GRIDAP_B2_REVISION = "b2-convergence-v1"
const _GRIDAP_B2_INTERVALS = (l2=(1.5,2.5), h1=(0.7,1.3))

gridap_field_convergence_source_hash() =
    Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))

struct GridapFieldConvergenceCaseV4
    grid_hash::Digest256
    plan_hash::Digest256
    g2_u_result_hash::Digest256
    g2_f_result_hash::Digest256
    nodes_per_axis::Int
    cells::Int
    dofs::Int
    runtime_seconds::Float64
    memory_bytes::Int
    solution_l2::Float64
    solution_h1_seminorm::Float64
    source_cell_center_rms::Float64
    boundary_face_center_linf::Float64
    residual::Float64
    status::Symbol
    case_hash::Digest256
    function GridapFieldConvergenceCaseV4(token::typeof(_GRIDAP_B2_TOKEN), args...)
        token === _GRIDAP_B2_TOKEN || throw(ArgumentError("sealed B2 case")); new(args...)
    end
end
GridapFieldConvergenceCaseV4(args...) = throw(ArgumentError("B2 case is sealed"))

struct GridapFieldConvergenceReceiptV4
    candidate_hash::Digest256
    scenario_hash::Digest256
    cases::Tuple
    observed_l2_orders::Tuple
    observed_h1_orders::Tuple
    acceptance_intervals::NamedTuple
    status::Symbol
    evidence_class::Symbol
    claim_ceiling::ClaimCeiling
    rejection_reasons::Tuple
    source_hash::Digest256
    receipt_hash::Digest256
    function GridapFieldConvergenceReceiptV4(token::typeof(_GRIDAP_B2_TOKEN), args...)
        token === _GRIDAP_B2_TOKEN || throw(ArgumentError("sealed B2 receipt")); new(args...)
    end
end
GridapFieldConvergenceReceiptV4(args...) = throw(ArgumentError("B2 receipt is sealed"))
semantic_view(x::GridapFieldConvergenceReceiptV4) = (candidate_hash=x.candidate_hash,
    scenario_hash=x.scenario_hash, cases=Tuple(canonical_hash(c) for c in x.cases),
    observed_l2_orders=x.observed_l2_orders, observed_h1_orders=x.observed_h1_orders,
    acceptance_intervals=x.acceptance_intervals, status=x.status,
    evidence_class=x.evidence_class, claim_ceiling=x.claim_ceiling,
    rejection_reasons=x.rejection_reasons, source_hash=x.source_hash,
    receipt_hash=x.receipt_hash)
canonical_hash(x::GridapFieldConvergenceReceiptV4) = x.receipt_hash

_b2_case_body(x...) = (grid_hash=x[1], plan_hash=x[2], g2_u_result_hash=x[3],
    g2_f_result_hash=x[4], nodes_per_axis=x[5], cells=x[6], dofs=x[7],
    # performance observations are intentionally not part of the deterministic case identity
    runtime_seconds=:observed, memory_bytes=:observed, solution_l2=x[10],
    solution_h1_seminorm=x[11], source_cell_center_rms=x[12],
    boundary_face_center_linf=x[13], residual=x[14], status=x[15])
semantic_view(x::GridapFieldConvergenceCaseV4) = merge(_b2_case_body(
    x.grid_hash,x.plan_hash,x.g2_u_result_hash,x.g2_f_result_hash,
    x.nodes_per_axis,x.cells,x.dofs,x.runtime_seconds,x.memory_bytes,
    x.solution_l2,x.solution_h1_seminorm,x.source_cell_center_rms,
    x.boundary_face_center_linf,x.residual,x.status), (case_hash=x.case_hash,))
canonical_hash(x::GridapFieldConvergenceCaseV4) = x.case_hash

_b2_zero_gradient() = (0.0, 0.0, 0.0)
_b2_identity_jacobian() = ((1.0,0.0,0.0), (0.0,1.0,0.0), (0.0,0.0,1.0))
_b2_scalar(v, g=_b2_zero_gradient()) =
    (kind=:scalar, value=Float64(v), gradient=Tuple(Float64.(g)))
_b2_vector(v, j=_b2_identity_jacobian()) =
    (kind=:vector, value=Tuple(Float64.(v)), jacobian=Tuple(Tuple(Float64.(r)) for r in j))

function _b2_assert_finite(x)
    values = x.kind === :scalar ? (x.value, x.gradient...) :
        (x.value..., (v for row in x.jacobian for v in row)...)
    all(isfinite, values) || throw(ArgumentError("exact AST evaluator produced a non-finite value"))
    x
end

function _b2_plan_parameter_map(plan::FieldEvaluationPlanV4)
    result = Dict{Int,Float64}()
    for binding in plan.program.parameter_bindings
        matches = Tuple(p for p in plan.parameters if p.ref == binding.parameter_ref)
        length(matches) == 1 || throw(ArgumentError("exact AST parameter binding is not unique"))
        haskey(result, binding.parameter_node_position) &&
            throw(ArgumentError("duplicate exact AST parameter node binding"))
        result[binding.parameter_node_position] = Float64(field_parameter_value(only(matches)))
    end
    result
end


function _b2_operator_id(plan::FieldEvaluationPlanV4, node::ASTApplyV1)
    id = node.operator_ref.qualified.id
    id in plan.allowed_opcodes || throw(ArgumentError("exact AST operator is outside the compiled plan"))
    matches = Tuple(binding for binding in plan.used_manifest_bindings if binding[1] == node.operator_ref)
    length(matches) == 1 || throw(ArgumentError("exact AST operator binding is not unique"))
    matches[1] in plan.program.program.used_manifest_bindings ||
        throw(ArgumentError("exact AST operator binding is outside the typed program"))
    id
end

function _b2_add(a, b, sign=1.0)
    a.kind === b.kind || throw(ArgumentError("exact AST ADD/SUB kind mismatch"))
    if a.kind === :scalar
        return _b2_scalar(a.value + sign*b.value,
            ntuple(i -> a.gradient[i] + sign*b.gradient[i], 3))
    end
    _b2_vector(ntuple(i -> a.value[i] + sign*b.value[i], 3),
        ntuple(i -> ntuple(j -> a.jacobian[i][j] + sign*b.jacobian[i][j], 3), 3))
end

function _b2_mul(a, b)
    if a.kind === :scalar && b.kind === :scalar
        return _b2_scalar(a.value*b.value,
            ntuple(i -> a.gradient[i]*b.value + b.gradient[i]*a.value, 3))
    elseif a.kind === :scalar && b.kind === :vector
        return _b2_vector(ntuple(i -> a.value*b.value[i], 3),
            ntuple(i -> ntuple(j -> a.gradient[j]*b.value[i] + a.value*b.jacobian[i][j], 3), 3))
    elseif a.kind === :vector && b.kind === :scalar
        return _b2_mul(b, a)
    end
    throw(ArgumentError("exact AST SCALAR_MUL requires at least one scalar"))
end

function _b2_typed_ast_value_gradient(q, plan::FieldEvaluationPlanV4)
    length(q) == 3 || throw(ArgumentError("exact AST coordinate must be 3-D"))
    program = plan.program.program
    root_index = findfirst(r -> r.root_position == plan.root.root_position, plan.program.root_refs)
    root_index === nothing && throw(ArgumentError("exact AST root is absent"))
    root = program.roots[root_index]
    parameters = _b2_plan_parameter_map(plan)
    cache = Dict{Int,Any}()
    function evaluate(position::Int)
        haskey(cache, position) && return cache[position]
        1 <= position <= length(program.nodes) || throw(ArgumentError("exact AST node position is out of range"))
        node = program.nodes[position]
        value = if node isa ASTInputV1
            node.port == 1 || throw(ArgumentError("unsupported exact AST input port"))
            _b2_vector(q)
        elseif node isa ASTParameterV1
            haskey(parameters, position) || throw(ArgumentError("unbound exact AST parameter"))
            _b2_scalar(parameters[position])
        elseif node isa ASTConstantV1
            node.value isa Real || throw(ArgumentError("exact AST constant must be scalar"))
            _b2_scalar(node.value)
        elseif node isa ASTApplyV1
            id = _b2_operator_id(plan, node)
            args = Tuple(evaluate(i) for i in node.inputs)
            if id == "IDENTITY"
                length(args) == 1 || throw(ArgumentError("IDENTITY arity mismatch")); args[1]
            elseif id == "ADD"
                length(args) == 2 || throw(ArgumentError("ADD arity mismatch")); _b2_add(args[1], args[2])
            elseif id == "SUB"
                length(args) == 2 || throw(ArgumentError("SUB arity mismatch")); _b2_add(args[1], args[2], -1.0)
            elseif id == "NEG"
                length(args) == 1 || throw(ArgumentError("NEG arity mismatch"))
                args[1].kind === :scalar ? _b2_scalar(-args[1].value,
                    ntuple(i -> -args[1].gradient[i], 3)) :
                    _b2_vector(ntuple(i -> -args[1].value[i], 3),
                        ntuple(i -> ntuple(j -> -args[1].jacobian[i][j], 3), 3))
            elseif id == "SCALAR_MUL"
                length(args) == 2 || throw(ArgumentError("SCALAR_MUL arity mismatch")); _b2_mul(args[1], args[2])
            elseif id == "DOT"
                length(args) == 2 || throw(ArgumentError("DOT arity mismatch"))
                all(a -> a.kind === :vector, args) || throw(ArgumentError("DOT requires vectors"))
                _b2_scalar(sum(args[1].value[i]*args[2].value[i] for i in 1:3),
                    ntuple(j -> sum(args[1].jacobian[i][j]*args[2].value[i] +
                        args[1].value[i]*args[2].jacobian[i][j] for i in 1:3), 3))
            elseif id == "SCALAR_DIV"
                length(args) == 2 || throw(ArgumentError("SCALAR_DIV arity mismatch"))
                a, b = args
                a.kind === :scalar && b.kind === :scalar || throw(ArgumentError("SCALAR_DIV requires scalars"))
                b.value != 0.0 || throw(ArgumentError("exact AST division by zero"))
                _b2_scalar(a.value/b.value, ntuple(i ->
                    (a.gradient[i]*b.value-a.value*b.gradient[i])/b.value^2, 3))
            else
                throw(ArgumentError("unsupported exact AST operator $id"))
            end
        else
            throw(ArgumentError("unsupported exact AST node"))
        end
        cache[position] = _b2_assert_finite(value)
    end
    result = evaluate(root)
    result.kind === :scalar || throw(ArgumentError("exact AST root must be scalar"))
    (result.value, result.gradient)
end

function _b2_exact_plan_integrity(plan::FieldEvaluationPlanV4,
        compilation::GridapFieldResidualCompilationV4, which::Symbol)
    expected_hash = which === :u ? compilation.plan.u_plan_hash :
        which === :f ? compilation.plan.f_plan_hash : throw(ArgumentError("unknown exact-plan role"))
    plan.status === :ready && plan.plan_hash == expected_hash &&
    plan.candidate_hash == compilation.plan.candidate_hash && plan.prefix_hash == compilation.plan.prefix_hash &&
    plan.scenario_hash == compilation.plan.scenario_hash && plan.grid.grid_hash == compilation.plan.grid_hash &&
    canonical_hash(plan.program) == plan.program_hash && canonical_hash(plan.root) == plan.root_ref_hash &&
    Tuple(canonical_hash(p) for p in plan.parameters) == plan.parameter_hashes &&
    Tuple(plan.program.program.used_manifest_bindings) == plan.used_manifest_bindings
end

function _b2_series_identity(c::GridapFieldResidualCompilationV4)
    p=c.plan; n=p.native_plan; g=n.geometry
    (candidate_hash=p.candidate_hash, prefix_hash=p.prefix_hash,
        registry_hash=p.registry_hash, mission_hash=p.mission_hash,
        scenario_hash=p.scenario_hash, constraint_edge_hash=p.constraint_edge_hash,
        form_hash=p.form_hash, support_hash=canonical_hash(g.support),
        chart_ref=g.chart_ref, factors=g.factors, offsets=g.offsets,
        scale=g.scale, jhat=g.jhat, ghat=g.ghat,
        laplace_weights=g.laplace_weights, protocol_hash=p.protocol.protocol_hash,
        dependency_hash=p.dependency_identity.dependency_hash,
        adapter_code_hash=p.adapter_code_hash)
end

function _b2_exact_program_identity(plan::FieldEvaluationPlanV4)
    (program_hash=plan.program_hash, root_ref_hash=plan.root_ref_hash,
        parameter_hashes=plan.parameter_hashes, chart_hash=plan.chart_hash,
        coordinate_map_hash=plan.coordinate_map_hash, metric_hash=plan.metric_hash,
        allowed_opcodes=plan.allowed_opcodes,
        used_manifest_bindings=plan.used_manifest_bindings, code_hash=plan.code_hash)
end

function _b2_refinement_integrity(compilations)
    axes=Tuple(x[1].source.coordinates for x in compilations)
    Tuple(Tuple(length(a) for a in grid) for grid in axes) ==
        ((5,5,5),(9,9,9),(17,17,17)) || return false
    all(axes[2][d][1:2:end] == axes[1][d] &&
        axes[3][d][1:2:end] == axes[2][d] for d in 1:3)
end

function _b2_reassemble(c)
    p=c.plan.native_plan; f=p.form; xy=c.source.coordinates
    model=CartesianDiscreteModel(_gridap_physical_domain(p.geometry,xy), ntuple(i->length(xy[i])-1,3))
    reffe=ReferenceFE(lagrangian,Float64,1); V0=TestFESpace(model,reffe;conformity=:H1,dirichlet_tags="boundary")
    Ug=TrialFESpace(V0,x->_gridap_payload_value(c.boundary,p.geometry,x)); Ω=Triangulation(model); dΩ=Measure(Ω,c.plan.protocol.quadrature_degree)
    source(x)=f.source_coefficients[1]*_gridap_payload_value(c.source,p.geometry,x)+f.constant
    a(u,v)=∫(f.alpha*(∇(v)⋅∇(u))-f.beta*v*u)*dΩ; b(v)=∫(v*source)*dΩ
    op=AffineFEOperator(a,b,Ug,V0); uh=solve(LinearFESolver(LUSolver()),op)
    A=get_matrix(op); rhs=Float64.(get_vector(op)); free_values=Tuple(Float64.(get_free_values(uh)))
    (uh=uh, Ω=Ω, dΩ=dΩ, A=A, rhs=rhs, free_values=free_values,
        matrix_hash=_gridap_matrix_hash(A), rhs_hash=canonical_hash(Tuple(rhs)))
end

"""Measure nodal and cell-centre errors against the sealed quartic control."""
function _b2_metrics(compilation, b1report, assembled, uplan, fplan)
    p = compilation.plan.native_plan; coords = compilation.source.coordinates
    geom = p.geometry; n = length(coords[1])
    # The exact evaluator is evaluated in physical coordinates; gradients are
    # transformed by the signed affine chart Jacobian.
    src = 0.0; bnd = 0.0
    # Source/boundary interpolation discrepancies are measured at cell centres.
    for i in 1:n-1, j in 1:n-1, k in 1:n-1
        q=((coords[1][i]+coords[1][i+1])/2,(coords[2][j]+coords[2][j+1])/2,(coords[3][k]+coords[3][k+1])/2)
        interp = _gridap_trilinear(compilation.source.values, coords, q)
        src += (interp - _b2_typed_ast_value_gradient(q, fplan)[1])^2
        # Boundary interpolation is an input discrepancy, independent of the solve.
        for qb in ((-1.0,q[2],q[3]), (1.0,q[2],q[3]), (q[1],-1.0,q[3]),
                   (q[1],1.0,q[3]), (q[1],q[2],-1.0), (q[1],q[2],1.0))
            bnd = max(bnd, abs(_gridap_trilinear(compilation.boundary.values, coords, qb)-_b2_typed_ast_value_gradient(qb, uplan)[1]))
        end
    end
    exact_u(x) = begin q=_gridap_physical_to_chart(geom,x); _b2_typed_ast_value_gradient(q,uplan)[1] end
    exact_gradient(x) = begin q=_gridap_physical_to_chart(geom,x); g=_b2_typed_ast_value_gradient(q,uplan)[2]; VectorValue(ntuple(i->g[i]/(geom.scale*geom.factors[i]),3)) end
    value_error=CellField(exact_u,assembled.Ω)-assembled.uh
    gradient_error=CellField(exact_gradient,assembled.Ω)-∇(assembled.uh)
    eL2=sqrt(sum(∫(value_error*value_error)*assembled.dΩ))
    eH1=sqrt(sum(∫(gradient_error⋅gradient_error)*assembled.dΩ))
    (eL2, eH1, sqrt(src/max((n-1)^3,1)), bnd)
end

function run_gridap_field_convergence(compilations::Tuple)
    length(compilations)==3 || throw(ArgumentError("B2 requires exactly 5/9/17 cases"))
    ns = (5,9,17)
    all(x -> x isa Tuple && length(x)==3 && x[1] isa GridapFieldResidualCompilationV4, compilations) || throw(ArgumentError("typed B1 compilation plus exact plans required"))
    all(x -> x[2] isa FieldEvaluationPlanV4 && x[3] isa FieldEvaluationPlanV4, compilations) ||
        throw(ArgumentError("exact typed G2 plans required"))
    cs=Tuple(x[1] for x in compilations); candidate = cs[1].plan.candidate_hash; scenario = cs[1].plan.scenario_hash
    all(c -> c.plan.candidate_hash==candidate && c.plan.scenario_hash==scenario, cs) || throw(ArgumentError("mixed candidate or scenario"))
    all(_b2_series_identity(c)==_b2_series_identity(cs[1]) for c in cs) ||
        throw(ArgumentError("mixed form, geometry, mission, or adapter identity"))
    length(unique(c.plan.grid_hash for c in cs)) == 3 || throw(ArgumentError("repeated grid hash"))
    length(unique(c.plan.protocol.protocol_hash for c in cs)) == 1 || throw(ArgumentError("mixed protocol"))
    _b2_refinement_integrity(compilations) || throw(ArgumentError("grids are not a nested 5/9/17 series"))
    all(_b2_exact_program_identity(x[2])==_b2_exact_program_identity(compilations[1][2]) &&
        _b2_exact_program_identity(x[3])==_b2_exact_program_identity(compilations[1][3])
        for x in compilations) || throw(ArgumentError("mixed exact typed program series"))
    cases = ntuple(i -> begin
        c=cs[i]; uplan=compilations[i][2]; fplan=compilations[i][3]; length(c.source.coordinates[1])==ns[i] || throw(ArgumentError("non-refining grid"))
        _b2_exact_plan_integrity(uplan,c,:u) || throw(ArgumentError("u exact-plan binding mismatch"))
        _b2_exact_plan_integrity(fplan,c,:f) || throw(ArgumentError("f exact-plan binding mismatch"))
        t=time_ns(); m0=Base.gc_live_bytes(); r=run_gridap_field_residual(c); assembled=_b2_reassemble(c); dt=(time_ns()-t)/1e9; m=max(0,Base.gc_live_bytes()-m0)
        assembled.matrix_hash == r.receipt.matrix_hash || throw(ArgumentError("B2/B1 matrix identity mismatch"))
        assembled.rhs_hash == r.receipt.rhs_hash || throw(ArgumentError("B2/B1 right-hand-side identity mismatch"))
        assembled.free_values == r.result.free_dof_values || throw(ArgumentError("B2/B1 solution identity mismatch"))
        r.status===:pass || throw(ArgumentError("failed numerical result")); metrics=_b2_metrics(c,r,assembled,uplan,fplan)
        body=_b2_case_body(c.plan.grid_hash,c.plan.plan_hash,c.plan.u_result_hash,c.plan.f_result_hash,ns[i],r.receipt.cells,r.receipt.free_dofs,dt,m,metrics...,r.result.residual_abs,:pass)
        GridapFieldConvergenceCaseV4(_GRIDAP_B2_TOKEN,c.plan.grid_hash,c.plan.plan_hash,c.plan.u_result_hash,c.plan.f_result_hash,ns[i],r.receipt.cells,r.receipt.free_dofs,dt,m,metrics...,r.result.residual_abs, :pass, canonical_hash(body))
    end,3)
    all(c->isfinite(c.solution_l2)&&isfinite(c.solution_h1_seminorm)&&c.solution_l2>0&&c.solution_h1_seminorm>0,cases) || throw(ArgumentError("non-finite numerical metrics"))
    l2o=ntuple(i->log(cases[i].solution_l2/cases[i+1].solution_l2)/log(2),2); h1o=ntuple(i->log(cases[i].solution_h1_seminorm/cases[i+1].solution_h1_seminorm)/log(2),2)
    all(isfinite,l2o)&&all(isfinite,h1o)&&all(cases[i].solution_l2>cases[i+1].solution_l2 for i=1:2) || throw(ArgumentError("non-refining convergence"))
    # Conservative bands preregistered from the observed 5/9/17 control:
    # the run must remain in the second-order finite-element window.
    intervals=_GRIDAP_B2_INTERVALS
    all(intervals.l2[1] <= o <= intervals.l2[2] for o in l2o) &&
        all(intervals.h1[1] <= o <= intervals.h1[2] for o in h1o) ||
        throw(ArgumentError("observed orders outside frozen acceptance bands"))
    source_hash=gridap_field_convergence_source_hash()
    body=(candidate_hash=candidate,scenario_hash=scenario,cases=Tuple(c.case_hash for c in cases),observed_l2_orders=l2o,observed_h1_orders=h1o,acceptance_intervals=intervals,status=:pass,evidence_class=:manufactured_control,claim_ceiling=screen_only,rejection_reasons=(),source_hash=source_hash)
    GridapFieldConvergenceReceiptV4(_GRIDAP_B2_TOKEN,candidate,scenario,cases,l2o,h1o,intervals,:pass,:manufactured_control,screen_only,(),source_hash,canonical_hash(body))
end

function _b2_case_integrity(c::GridapFieldConvergenceCaseV4)
    body=_b2_case_body(c.grid_hash,c.plan_hash,c.g2_u_result_hash,c.g2_f_result_hash,
        c.nodes_per_axis,c.cells,c.dofs,c.runtime_seconds,c.memory_bytes,c.solution_l2,
        c.solution_h1_seminorm,c.source_cell_center_rms,c.boundary_face_center_linf,
        c.residual,c.status)
    c.status === :pass && c.cells > 0 && c.dofs > 0 && c.runtime_seconds >= 0.0 &&
    c.memory_bytes >= 0 && all(isfinite,(c.solution_l2,c.solution_h1_seminorm,
        c.source_cell_center_rms,c.boundary_face_center_linf,c.residual)) &&
    c.solution_l2 > 0.0 && c.solution_h1_seminorm > 0.0 &&
    c.source_cell_center_rms >= 0.0 && c.boundary_face_center_linf >= 0.0 &&
    c.residual >= 0.0 && canonical_hash(body) == c.case_hash
end

function validate_gridap_field_convergence_receipt(r::GridapFieldConvergenceReceiptV4)
    length(r.cases)==3 || return false
    body=(candidate_hash=r.candidate_hash,scenario_hash=r.scenario_hash,cases=Tuple(c.case_hash for c in r.cases),observed_l2_orders=r.observed_l2_orders,observed_h1_orders=r.observed_h1_orders,acceptance_intervals=r.acceptance_intervals,status=r.status,evidence_class=r.evidence_class,claim_ceiling=r.claim_ceiling,rejection_reasons=r.rejection_reasons,source_hash=r.source_hash)
    l2o=ntuple(i->log(r.cases[i].solution_l2/r.cases[i+1].solution_l2)/log(2),2)
    h1o=ntuple(i->log(r.cases[i].solution_h1_seminorm/r.cases[i+1].solution_h1_seminorm)/log(2),2)
    r.status===:pass && r.evidence_class===:manufactured_control && r.claim_ceiling===screen_only &&
    isempty(r.rejection_reasons) && r.acceptance_intervals == _GRIDAP_B2_INTERVALS &&
    r.source_hash == gridap_field_convergence_source_hash() &&
    Tuple(c.nodes_per_axis for c in r.cases) == (5,9,17) &&
    length(unique(c.grid_hash for c in r.cases)) == 3 && all(_b2_case_integrity,r.cases) &&
    all(r.cases[i].solution_l2 > r.cases[i+1].solution_l2 for i=1:2) &&
    r.observed_l2_orders == l2o && r.observed_h1_orders == h1o &&
    all(r.acceptance_intervals.l2[1] <= o <= r.acceptance_intervals.l2[2] for o in l2o) &&
    all(r.acceptance_intervals.h1[1] <= o <= r.acceptance_intervals.h1[2] for o in h1o) &&
    canonical_hash(body)==r.receipt_hash
end
