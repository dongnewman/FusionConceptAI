"""Declared diffusion compile/lower/compose/execute vertical slice (V1).

This is an additive adapter between the already submitted
`DeclaredG123DiffusionExecutionV1` and `DeclaredSpatialCompositionExecutionV1`
seams.  It does not modify a registry or compiler.  The adapter validates a
candidate-bound G1/G2/G3 bundle, lowers only the closed one-dimensional
structured scalar `diagonal_affine_static` subset, builds the existing typed
port plan, and dispatches the existing finite-volume assembly and linear
solve.  Every result is screen-only evidence.
"""

using SHA

const DCCE_SCHEMA_V1 = "fusionconceptai:runtime-v4:declared-diffusion-compile-execute-v1"
const DCCE_REVISION_V1 = "up2-declared-diffusion-compile-execute-v1-r1"
const DCCE_CLAIM_CEILING_V1 = :screen_only
const DCCE_STATUSES_V1 = (:ready, :fail_closed, :terminal_deferred, :numerical_fail)
const DCCE_EXPRESSION_SUBSET_V1 = :diagonal_affine_static

_dcce_hash(x) = bytes2hex(sha256(codeunits(repr(x))))
_dcce_text(x, field) = begin
    s = strip(String(x)); isempty(s) && throw(ArgumentError("$field cannot be empty")); s
end

"The hash receipt is rebuilt from bundle records; it is not a display label."
struct DCCEHashReceiptV1
    candidate_ref::Any
    g1_body_hash::Any
    g2_body_hash::Any
    g3_body_hash::Any
    source_hashes::Tuple
    declaration_hashes::Tuple
    bundle_hash::Any
    receipt_hash::String
end

struct DCCETypedLoweringV1
    status::Symbol
    code::Symbol
    candidate_ref::Any
    expression_subset::Symbol
    dimension::Int
    field_count::Int
    temporal::Symbol
    coefficient_kind::Symbol
    k_cells::Tuple
    source::Tuple
    boundary::Any
    declaration_hash::String
    receipt_hash::String
end

struct DCCECompositionPlanV1
    status::Symbol
    code::Symbol
    candidate_ref::Any
    plan::Any
    edges::Tuple
    semantic_hash::String
    receipt_hash::String
end

struct DeclaredDiffusionCompileExecuteInputV1
    candidate_ref::Any
    g1::Any
    g2::Any
    g3::Any
    bundle::Any
    spatial_case::DeclaredSpatialCaseV1
    hashes::DCCEHashReceiptV1
end

struct DCCEOutcomeV1
    status::Symbol
    code::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    compile::Any
    lowering::Any
    composition::Any
    numerical::Any
    aggregate::Any
    hashes::Any
    receipt_hash::String
end

_dcce_phase(status, code; kwargs...) =
    merge((status=status, code=code, accepted=false,
        claim_ceiling=DCCE_CLAIM_CEILING_V1, provider_calls=0,
        mesh_calls=0, solver_calls=0), kwargs)

function _dcce_hash_receipt(candidate, ghashes, bundle)
    records = Tuple(sort([r for r in bundle.declarations if
        r isa VNextT0LocalPresentDeclarationV1], by=r -> String(r.layer)))
    length(records) == 3 || throw(ArgumentError("bundle must contain exactly G1/G2/G3 records"))
    source_hashes = Tuple(r.source_bytes.sha256 for r in records)
    declaration_hashes = Tuple(r.declaration_bytes.sha256 for r in records)
    body = (candidate_ref=candidate, g1_body_hash=ghashes.g1_body_hash,
        g2_body_hash=ghashes.g2_body_hash, g3_body_hash=ghashes.g3_body_hash,
        source_hashes=source_hashes, declaration_hashes=declaration_hashes,
        bundle_hash=ghashes.bundle_hash)
    DCCEHashReceiptV1(candidate, ghashes.g1_body_hash, ghashes.g2_body_hash,
        ghashes.g3_body_hash, source_hashes, declaration_hashes, ghashes.bundle_hash,
        _dcce_hash(body))
end

"Strict constructor: the existing DGD input validator performs byte-level
 candidate/source/declaration/body/bundle validation before this adapter runs."
function dcce_input_v1(candidate, g1, g2, g3, bundle, spatial_case)
    spatial_case isa DeclaredSpatialCaseV1 || throw(ArgumentError("spatial_case must be typed"))
    dgd = dgd_input_v1(candidate, g1, g2, g3, bundle)
    hashes = _dcce_hash_receipt(candidate, dgd.hashes, bundle)
    DeclaredDiffusionCompileExecuteInputV1(candidate, g1, g2, g3, bundle, spatial_case, hashes)
end

function _dcce_failure(candidate, code; status=:fail_closed, hashes=nothing,
                       compile=nothing, lowering=nothing, composition=nothing,
                       numerical=nothing, detail=String(code))
    aggregate = _dcce_phase(status, code; resolution=status, detail=detail,
        accepted=false, formal_up_credit=false, formal_r_credit=false,
        screen_only=true, hashes=hashes)
    body = (candidate=candidate, status=status, code=code,
        compile=compile, lowering=lowering, composition=composition,
        numerical=numerical, hashes=hashes)
    DCCEOutcomeV1(status, code, false, DCCE_CLAIM_CEILING_V1, compile, lowering,
        composition, numerical, aggregate, hashes, _dcce_hash(body))
end

function _dcce_public_candidate(candidate)
    try
        (id=getproperty(candidate, :id), version=getproperty(candidate, :version))
    catch
        (id=String(candidate), version="unknown")
    end
end

"Lower the closed declaration subset into the existing spatial FV field.
The spatial field values remain explicit numerical inputs, while G1's
candidate-owned K/source types and hashes are retained in the lowering receipt."
function dcce_typed_lower_v1(input::DeclaredDiffusionCompileExecuteInputV1)
    try
        g1_status, g1_errors = g1_diffusion_validate(input.g1)
        g1_status === :valid || return _dcce_phase(:fail_closed, :g1_declaration_invalid;
            detail=g1_errors)
        k = input.g1.K.expression
        k isa G1DiffusionDiagonalAffineKFieldV1 ||
            return _dcce_phase(:terminal_deferred, :unsupported_anisotropic;
                detail="only diagonal affine K is executable")
        uexpr = input.g1.u.source_expression
        fexpr = input.g1.f.source_expression
        uexpr in DGD_ALLOWED_U_EXPRESSIONS_V1 ||
            return _dcce_phase(:terminal_deferred,
                occursin("sin", fexpr) || occursin("exp", fexpr) ?
                    :unsupported_nonlinear : :unsupported_expression;
                detail="u expression is outside the static scalar subset")
        fexpr in DGD_ALLOWED_F_EXPRESSIONS_V1 ||
            return _dcce_phase(:terminal_deferred,
                occursin("t", fexpr) ? :unsupported_time : :unsupported_nonlinear;
                detail="f expression is outside the static affine subset")
        field = input.spatial_case.field
        n = length(field.k_cells)
        n >= 2 && length(field.source) == n ||
            return _dcce_phase(:fail_closed, :multifield_or_size_mismatch;
                detail="structured scalar lowering requires one K/source value per cell")
        vf = validate_declared_field_hashes(field)
        vf.valid || return _dcce_phase(vf.status, vf.code; detail=vf.detail)
        boundary = input.spatial_case.boundary
        vb = validate_declared_boundary(boundary)
        vb.valid || return _dcce_phase(vb.status, vb.code; detail=vb.detail)
        # G1 physical types are the unit/dimension gate.  Constructors upstream
        # guarantee the full tensor algebra; repeat the scalar/rank checks here
        # so this execution boundary cannot silently widen to multifield/time.
        up = input.g1.u.physical_type; fp = input.g1.f.physical_type
        kp = input.g1.K.physical_type
        up.tensor_rank == 0 && fp.tensor_rank == 0 && kp.tensor_rank == 2 ||
            return _dcce_phase(:fail_closed, :units_dimension_mismatch;
                detail="u/f must be scalar and K rank-2")
        up.spatial_dimension == 3 && fp.spatial_dimension == 3 && kp.spatial_dimension == 3 ||
            return _dcce_phase(:fail_closed, :units_dimension_mismatch;
                detail="declaration spatial dimension is not three")
        temporal = up.temporal_type == TemporalTypeV1(static_time) ? :static : :unsupported
        temporal === :static || return _dcce_phase(:terminal_deferred, :unsupported_time;
            detail="only static declarations are executable")
        ktuple = Tuple(Float64.(field.k_cells)); ftuple = Tuple(Float64.(field.source))
        all(isfinite, ktuple) && all(>(0.0), ktuple) && all(isfinite, ftuple) ||
            return _dcce_phase(:numerical_fail, :nonfinite_derived;
                detail="lowered K/source is nonfinite or nonpositive")
        body = (candidate=input.candidate_ref, expression_subset=DCCE_EXPRESSION_SUBSET_V1,
            dimension=1, field_count=1, temporal=temporal,
            coefficient_kind=:diagonal, k_cells=ktuple, source=ftuple,
            boundary=semantic_view(boundary),
            g1_body_hash=input.hashes.g1_body_hash,
            g2_body_hash=input.hashes.g2_body_hash,
            g3_body_hash=input.hashes.g3_body_hash,
            bundle_hash=input.hashes.bundle_hash)
        DCCETypedLoweringV1(:ready, :typed_lowering_ready, input.candidate_ref,
            DCCE_EXPRESSION_SUBSET_V1, 1, 1, temporal, :diagonal, ktuple, ftuple,
            boundary, _dcce_hash((g1=input.hashes.g1_body_hash,
                g2=input.hashes.g2_body_hash, g3=input.hashes.g3_body_hash)),
            _dcce_hash(body))
    catch err
        _dcce_phase(:fail_closed, :program_exception; detail=sprint(showerror, err))
    end
end

"Build the existing typed port plan.  Component/port labels are diagnostic;
the upstream matcher hashes only semantic direction/account/quantity/unit and
sorts its edge payloads."
function dcce_composition_plan_v1(input::DeclaredDiffusionCompileExecuteInputV1)
    try
        # The existing matcher is deliberately authoritative for all of these
        # negative gates: duplicate_producer/ambiguous producers, unit mismatch,
        # missing_boundary, missing_return, and ledger_contradiction.
        matched = auto_typed_port_edges(input.spatial_case.composition)
        matched.valid || return _dcce_phase(matched.status, matched.code; detail=matched.detail)
        edges = Tuple(matched.edges)
        semantic_edges = Tuple(sort([(_dsc_port_key(e.producer), _dsc_port_key(e.consumer))
            for e in edges], by=repr))
        plan_hash = _dcce_hash(semantic_edges)
        plan = DCCECompositionPlanV1(:ready, :typed_composition_plan_ready,
            input.candidate_ref, input.spatial_case.composition, edges, plan_hash,
            _dcce_hash((candidate=input.candidate_ref, plan_hash=plan_hash)))
        (status=:ready, code=:typed_composition_plan_ready, valid=true,
            plan=plan, edges=edges, semantic_hash=plan_hash,
            ledger_residual=matched.residual, receipt_hash=plan.receipt_hash,
            provider_calls=0, mesh_calls=0, solver_calls=0)
    catch err
        _dcce_phase(:fail_closed, :composition_plan_exception; detail=sprint(showerror, err))
    end
end

function _dcce_execute_input(input::DeclaredDiffusionCompileExecuteInputV1)
    compile = dgd_compile_v1(DeclaredG123InputV1(input.candidate_ref, input.g1,
        input.g2, input.g3, input.bundle,
        DeclaredG123HashSetV1(input.candidate_ref, input.hashes.g1_body_hash,
            input.hashes.g2_body_hash, input.hashes.g3_body_hash,
            input.hashes.bundle_hash)))
    compile.status === :ready || return _dcce_failure(input.candidate_ref,
        compile.code; status=compile.status, hashes=input.hashes, compile=compile)
    lowering = dcce_typed_lower_v1(input)
    lowering.status === :ready || return _dcce_failure(input.candidate_ref,
        lowering.code; status=lowering.status, hashes=input.hashes,
        compile=compile, lowering=lowering)
    plan = dcce_composition_plan_v1(input)
    plan.status === :ready || return _dcce_failure(input.candidate_ref,
        plan.code; status=plan.status, hashes=input.hashes,
        compile=compile, lowering=lowering, composition=plan)
    authority = dgd_composition_admit_v1(DeclaredG123InputV1(input.candidate_ref,
        input.g1, input.g2, input.g3, input.bundle,
        DeclaredG123HashSetV1(input.candidate_ref, input.hashes.g1_body_hash,
            input.hashes.g2_body_hash, input.hashes.g3_body_hash,
            input.hashes.bundle_hash)))
    authority.status === :fail_closed && return _dcce_failure(input.candidate_ref,
        authority.code; status=:fail_closed, hashes=input.hashes, compile=compile,
        lowering=lowering, composition=merge(plan, (authority=authority,)))
    # Keep the submitted G123 2-DOF numerical lane separate from the spatial
    # composition lane.  Their matrices have different discretization
    # identities and must never be placed in one receipt or compared as if
    # they were the same numerical system.
    dgd_input = DeclaredG123InputV1(input.candidate_ref, input.g1, input.g2,
        input.g3, input.bundle,
        DeclaredG123HashSetV1(input.candidate_ref, input.hashes.g1_body_hash,
            input.hashes.g2_body_hash, input.hashes.g3_body_hash,
            input.hashes.bundle_hash))
    dgd_mesh = dgd_local_mesh_v1(dgd_input)
    dgd_transfer = dgd_transfer_v1(dgd_mesh, dgd_mesh, input.spatial_case.old_state)
    dgd_transfer.status === :ready || return _dcce_failure(input.candidate_ref,
        dgd_transfer.code; status=dgd_transfer.status, hashes=input.hashes,
        compile=compile, lowering=lowering, composition=merge(plan,
            (authority=authority, dgd_transfer=dgd_transfer)))
    dgd_numerical = dgd_numerical_solve_v1(dgd_input, dgd_mesh, dgd_transfer)
    dgd_numerical.status === :ready || return _dcce_failure(input.candidate_ref,
        dgd_numerical.code; status=:numerical_fail, hashes=input.hashes,
        compile=compile, lowering=lowering, composition=merge(plan,
            (authority=authority, dgd_transfer=dgd_transfer)),
        numerical=_dcce_phase(:numerical_fail, dgd_numerical.code;
            dgd=dgd_numerical))
    transfer = measure_overlap_transfer(input.spatial_case.old_geometry,
        input.spatial_case.new_geometry, input.spatial_case.old_state)
    transfer.valid || return _dcce_failure(input.candidate_ref, transfer.code;
        status=transfer.status, hashes=input.hashes, compile=compile, lowering=lowering,
        composition=merge(plan, (authority=authority, transfer=transfer)))
    assembled = assemble_declared_spatial_fv(input.spatial_case.new_geometry,
        input.spatial_case.field, input.spatial_case.boundary; edges=plan.edges)
    assembled.valid || return _dcce_failure(input.candidate_ref, assembled.code;
        status=assembled.status, hashes=input.hashes, compile=compile, lowering=lowering,
        composition=merge(plan, (authority=authority, transfer=transfer,
            assembly=assembled)))
    b = input.spatial_case.boundary
    b.left_kind === :neumann && b.right_kind === :neumann &&
        return _dcce_failure(input.candidate_ref, :pure_neumann_singular;
            status=:numerical_fail, hashes=input.hashes, compile=compile,
            lowering=lowering, composition=merge(plan, (authority=authority,
                transfer=transfer, assembly=assembled)))
    solution, residual, solve_code = _dsc_solve(assembled.assembly.matrix,
        assembled.assembly.rhs)
    solve_code === :singular_matrix && return _dcce_failure(input.candidate_ref,
        :singular_matrix; status=:numerical_fail, hashes=input.hashes,
        compile=compile, lowering=lowering, composition=merge(plan, (authority=authority,
            transfer=transfer, assembly=assembled)),
        numerical=_dcce_phase(:numerical_fail, :singular_matrix;
            residual_norm=residual))
    solve_code === :joint_linear_solved || return _dcce_failure(input.candidate_ref,
        solve_code; status=:numerical_fail, hashes=input.hashes, compile=compile,
        lowering=lowering, composition=merge(plan, (authority=authority,
            transfer=transfer, assembly=assembled)),
        numerical=_dcce_phase(:numerical_fail, solve_code; residual_norm=residual))
    isfinite(residual) && residual <= 1.0e-12 || return _dcce_failure(
        input.candidate_ref, :residual_failure; status=:numerical_fail,
        hashes=input.hashes, compile=compile, lowering=lowering,
        composition=merge(plan, (authority=authority, transfer=transfer,
            assembly=assembled)), numerical=_dcce_phase(:numerical_fail,
            :residual_failure; residual_norm=residual))
    numerical = _dcce_phase(:ready, :finite_volume_solved; accepted=false,
        # `dgd` is the submitted 2x2 lane; `fv` is the independent spatial
        # composition holdout.  Both are retained so their receipts cannot be
        # accidentally conflated.
        dgd=dgd_numerical, dgd_transfer=dgd_transfer,
        matrix=dgd_numerical.matrix, rhs=dgd_numerical.rhs,
        solution=dgd_numerical.solution,
        residual_norm=dgd_numerical.residual_norm,
        fv=(matrix=Tuple(Tuple(row) for row in eachrow(assembled.assembly.matrix)),
            rhs=Tuple(assembled.assembly.rhs), solution=Tuple(solution),
            residual_norm=residual, assembly_hash=assembled.assembly.assembly_hash),
        solver_calls=1, receipt_hash=_dcce_hash((dgd=dgd_numerical.receipt_hash,
            fv_assembly=assembled.assembly.assembly_hash,
            fv_solution=Tuple(solution), fv_residual_norm=residual)))
    composition_status = authority.status === :ready && authority.resolution === :resolved ?
        :ready : :terminal_deferred
    composition = merge(plan, (status=composition_status, authority=authority,
        transfer=transfer, assembly=assembled, accepted=false,
        claim_ceiling=DCCE_CLAIM_CEILING_V1,
        receipt_hash=_dcce_hash((plan=plan.receipt_hash,
            authority=canonical_json(authority), assembly=assembled.assembly.assembly_hash))))
    aggregate_status = composition_status === :ready ? :ready : :terminal_deferred
    aggregate = _dcce_phase(aggregate_status, aggregate_status === :ready ?
        :screen_ready_authority_deferred; resolution=aggregate_status,
        accepted=false, formal_up_credit=false, formal_r_credit=false,
        screen_only=true, provider_calls=0, mesh_calls=0, solver_calls=2,
        dgd_solver_calls=1, fv_solver_calls=1,
        candidate_ref=input.candidate_ref, hashes=input.hashes,
        residual_norm=residual, solution=Tuple(solution))
    body = (candidate=input.candidate_ref, hashes=input.hashes.receipt_hash,
        compile=compile.receipt_hash, lowering=lowering.receipt_hash,
        composition=composition.receipt_hash, numerical=numerical.receipt_hash,
        aggregate=aggregate)
    DCCEOutcomeV1(aggregate_status, aggregate.code, false, DCCE_CLAIM_CEILING_V1,
        compile, lowering, composition, numerical, aggregate, input.hashes,
        _dcce_hash(body))
end

"Public boundary: strict identity errors become a typed fail-closed outcome."
function dcce_compile_execute_v1(candidate, g1, g2, g3, bundle, spatial_case)
    try
        input = dcce_input_v1(candidate, g1, g2, g3, bundle, spatial_case)
        _dcce_execute_input(input)
    catch err
        msg = lowercase(sprint(showerror, err))
        code = occursin("candidate", msg) ? :candidate_mismatch :
            occursin("bundle_hash", msg) ? :bundle_hash_mismatch :
            occursin("body", msg) || occursin("semantic", msg) ?
                :body_hash_mismatch : occursin("source", msg) ?
                :source_hash_mismatch : occursin("declaration", msg) ?
                :declaration_hash_mismatch : :hash_or_declaration_mismatch
        _dcce_failure(_dcce_public_candidate(candidate), code;
            status=:fail_closed, detail=sprint(showerror, err))
    end
end

const declared_diffusion_compile_execute_v1 = dcce_compile_execute_v1
const execute_declared_diffusion_compile_execute_v1 = dcce_compile_execute_v1
