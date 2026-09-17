"""Isolated M4-D manufactured two-region coupled-solve control.

This file is deliberately independent of the shared RuntimeV4 entry point.
It consumes two valid M4-C controls with an explicit identity cell mapping and
performs only the frozen, exact 2x2 algebraic solve
`[2 -1; -1 2] * [a,b] = [1,0]`.  It does not iterate a PDE solver, transfer a
topology, bind a candidate, call a provider, or emit physics or engineering
evidence.
"""

if !isdefined(@__MODULE__, :ManufacturedDiscreteControlV1)
    include(joinpath(@__DIR__, "ManufacturedDiscreteControlV1.jl"))
end

const M4D_SCHEMA_V1 = "M4-D-MANUFACTURED-COUPLED-SOLVE-CONTROL-V1"
const M4D_CLAIM_CEILING_V1 = :manufactured_coupled_solve_control
const M4D_EVIDENCE_SCOPE_V1 = :screen_only
const M4D_LEFT_REGION_V1 = "region-A"
const M4D_RIGHT_REGION_V1 = "region-B"
const M4D_BLOCK_V1 = (M4RationalV1(2, 1), M4RationalV1(-1, 1),
                      M4RationalV1(-1, 1), M4RationalV1(2, 1))
const M4D_RHS_V1 = (M4RationalV1(1, 1), M4RationalV1(0, 1))
const M4D_SOLUTION_V1 = (M4RationalV1(2, 3), M4RationalV1(1, 3))

struct ManufacturedCoupledSolveControlFailureV1
    code::Symbol
    path::String
    detail::String
end

_m4d_failure(code::Symbol, path::AbstractString, detail::AbstractString) =
    ManufacturedCoupledSolveControlFailureV1(code, String(path), String(detail))

"""One explicit pair in the region-interface correspondence."""
struct M4DCellPairV1
    left_index::NTuple{3,Int}
    right_index::NTuple{3,Int}
end

M4DCellPairV1(left, right) = M4DCellPairV1(
    ntuple(i -> Int(Tuple(left)[i]), 3), ntuple(i -> Int(Tuple(right)[i]), 3))

"""Typed interface binding; pairs are ordered and must form a bijection."""
struct M4DInterfaceBindingV1
    left_region_id::String
    right_region_id::String
    left_grid_counts::NTuple{3,Int}
    right_grid_counts::NTuple{3,Int}
    pairs::Tuple{Vararg{M4DCellPairV1}}
    identity::Bool
    bijective::Bool
    conservation_owner::String
end

function M4DInterfaceBindingV1(left_region_id::AbstractString,
        right_region_id::AbstractString, left_grid_counts, right_grid_counts,
        pairs, identity::Bool, bijective::Bool, conservation_owner::AbstractString)
    lp = ntuple(i -> Int(Tuple(left_grid_counts)[i]), 3)
    rp = ntuple(i -> Int(Tuple(right_grid_counts)[i]), 3)
    typed_pairs = Tuple(p isa M4DCellPairV1 ? p : M4DCellPairV1(p[1], p[2]) for p in pairs)
    M4DInterfaceBindingV1(String(left_region_id), String(right_region_id), lp, rp,
        typed_pairs, identity, bijective, String(conservation_owner))
end

"""One exact solution and its two block-equation residuals."""
struct M4DCoupledCellSolutionV1
    left_index::NTuple{3,Int}
    right_index::NTuple{3,Int}
    left_value::M4RationalV1
    right_value::M4RationalV1
    residual::NTuple{2,M4RationalV1}
    equation_id::String
    source_id::String
    conservation_owner::String
end

struct ManufacturedCoupledSolveControlV1
    schema::String
    left::ManufacturedDiscreteControlV1
    right::ManufacturedDiscreteControlV1
    left_region_id::String
    right_region_id::String
    grid_counts::NTuple{3,Int}
    interface::M4DInterfaceBindingV1
    block_matrix::NTuple{4,M4RationalV1}
    rhs::NTuple{2,M4RationalV1}
    equation_id::String
    source_id::String
    source_owner::String
    conservation_owner::String
    units::M4CUnitBindingV1
    provenance::M4ProvenanceDeclarationV1
    cell_solutions::Tuple{Vararg{M4DCoupledCellSolutionV1}}
    block_residuals::Tuple{Vararg{NTuple{2,M4RationalV1}}}
    block_residual::M4RationalV1
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

struct ManufacturedCoupledSolveControlResultV1
    valid::Bool
    status::Symbol
    control::Union{Nothing,ManufacturedCoupledSolveControlV1}
    failures::Tuple{Vararg{ManufacturedCoupledSolveControlFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

const ManufacturedCoupledSolveValidationV1 = ManufacturedCoupledSolveControlResultV1

_m4d_rat(n::Integer, d::Integer) = begin
    d == 0 && return M4RationalV1(Int(n), 0)
    nn, dd = Int(n), Int(d)
    dd < 0 && ((nn, dd) = (-nn, -dd))
    g = gcd(abs(nn), abs(dd))
    M4RationalV1(nn ÷ g, dd ÷ g)
end
_m4d_rat(r::M4RationalV1) = _m4d_rat(r.numerator, r.denominator)
_m4d_add(a::M4RationalV1, b::M4RationalV1) =
    _m4d_rat(a.numerator * b.denominator + b.numerator * a.denominator,
             a.denominator * b.denominator)
_m4d_neg(a::M4RationalV1) = _m4d_rat(-a.numerator, a.denominator)
_m4d_sub(a::M4RationalV1, b::M4RationalV1) = _m4d_add(a, _m4d_neg(b))
_m4d_mul(a::M4RationalV1, b::M4RationalV1) =
    _m4d_rat(a.numerator * b.numerator, a.denominator * b.denominator)
_m4d_div(a::M4RationalV1, b::M4RationalV1) =
    _m4d_rat(a.numerator * b.denominator, a.denominator * b.numerator)
_m4d_equal(a::M4RationalV1, b::M4RationalV1) =
    a.denominator != 0 && b.denominator != 0 &&
    a.numerator * b.denominator == b.numerator * a.denominator
_m4d_positive(a::M4RationalV1) = a.denominator > 0 && a.numerator > 0

_m4d_unit_payload(u::M4UnitV1) =
    (name=u.name, exponents=u.exponents, scale_to_si=u.scale_to_si)
_m4d_rat_payload(r::M4RationalV1) =
    (numerator=r.numerator, denominator=r.denominator)
_m4d_failure_tuple(fs) = Tuple(ManufacturedCoupledSolveControlFailureV1[f for f in fs])

_m4d_scalar(x::M4RationalV1) = x
_m4d_scalar(x::Integer) = M4RationalV1(x, 1)
_m4d_scalar(x) = nothing

function _m4d_block(x)
    if x isa Tuple && length(x) == 4
        v = Tuple(_m4d_scalar(y) for y in x)
        all(y -> y isa M4RationalV1, v) && return v
    elseif x isa Tuple && length(x) == 2 && all(y -> y isa Tuple && length(y) == 2, x)
        v = Tuple(_m4d_scalar(y) for row in x for y in row)
        all(y -> y isa M4RationalV1, v) && return v
    end
    nothing
end

function _m4d_rhs(x)
    x isa Tuple && length(x) == 2 || return nothing
    v = Tuple(_m4d_scalar(y) for y in x)
    all(y -> y isa M4RationalV1, v) ? v : nothing
end

function _m4d_invalid_result(failures)
    typed = _m4d_failure_tuple(failures)
    ManufacturedCoupledSolveControlResultV1(false, :typed_failure, nothing,
        typed, M4D_CLAIM_CEILING_V1, M4D_EVIDENCE_SCOPE_V1)
end

function _m4d_default_interface(left::ManufacturedDiscreteControlV1,
        right::ManufacturedDiscreteControlV1, left_region_id::String,
        right_region_id::String, owner::String)
    counts = left.grid.counts
    pairs = Tuple(M4DCellPairV1((i, j, k), (i, j, k))
        for k in 1:counts[3], j in 1:counts[2], i in 1:counts[1])
    M4DInterfaceBindingV1(left_region_id, right_region_id, counts,
        right.grid.counts, pairs, true, true, owner)
end

function _m4d_coerce_interface(x, left_region_id::String, right_region_id::String,
        left::ManufacturedDiscreteControlV1, right::ManufacturedDiscreteControlV1,
        owner::String)
    x === nothing && return _m4d_default_interface(left, right, left_region_id,
        right_region_id, owner)
    x isa M4DInterfaceBindingV1 && return x
    _m4d_invalid_result([_m4d_failure(:nonbijective_interface, "interface",
        "interface must be an M4DInterfaceBindingV1")])
end

function _m4d_solve_pair(block::NTuple{4,M4RationalV1},
        rhs::NTuple{2,M4RationalV1})
    a, b, c, d = block
    det = _m4d_sub(_m4d_mul(a, d), _m4d_mul(b, c))
    x = _m4d_div(_m4d_sub(_m4d_mul(rhs[1], d), _m4d_mul(b, rhs[2])), det)
    y = _m4d_div(_m4d_sub(_m4d_mul(a, rhs[2]), _m4d_mul(c, rhs[1])), det)
    residual = (_m4d_sub(_m4d_add(_m4d_mul(a, x), _m4d_mul(b, y)), rhs[1]),
                _m4d_sub(_m4d_add(_m4d_mul(c, x), _m4d_mul(d, y)), rhs[2]))
    (x, y), residual, det
end

"""Build the isolated exact M4-D control from two valid M4-C controls."""
function build_manufactured_coupled_solve_control(
        left::ManufacturedDiscreteControlV1,
        right::ManufacturedDiscreteControlV1;
        left_region_id::AbstractString=M4D_LEFT_REGION_V1,
        right_region_id::AbstractString=M4D_RIGHT_REGION_V1,
        interface=nothing,
        block_matrix=M4D_BLOCK_V1,
        rhs=M4D_RHS_V1)
    failures = ManufacturedCoupledSolveControlFailureV1[]
    block = _m4d_block(block_matrix)
    right_hand = _m4d_rhs(rhs)
    block === nothing && push!(failures, _m4d_failure(:non_spd_block,
        "block_matrix", "block must be a 2x2 exact-rational tuple"))
    right_hand === nothing && push!(failures, _m4d_failure(:foreign_c_input,
        "rhs", "rhs must be a two-entry exact-rational tuple"))
    left_result = validate_manufactured_discrete_control(left)
    right_result = validate_manufactured_discrete_control(right)
    left_result.valid || push!(failures, _m4d_failure(:foreign_c_input, "left",
        "left input is not a valid M4-C control"))
    right_result.valid || push!(failures, _m4d_failure(:foreign_c_input, "right",
        "right input is not a valid M4-C control"))
    lid, rid = String(left_region_id), String(right_region_id)
    (!isempty(lid) && !isempty(rid) && lid != rid) || push!(failures,
        _m4d_failure(:owner_mismatch, "region", "region identities must be explicit and distinct"))
    left.grid == right.grid || push!(failures,
        _m4d_failure(:grid_mismatch, "grid", "the two C controls must have identical grid identity"))
    left.equation_id == right.equation_id && left.source_id == right.source_id ||
        push!(failures, _m4d_failure(:owner_mismatch, "equation_source",
            "equation and source identities must match across regions"))
    left.source_owner == right.source_owner &&
        left.conservation_owner == right.conservation_owner || push!(failures,
        _m4d_failure(:owner_mismatch, "owner", "source and conservation owners must match"))
    left.units == right.units || push!(failures,
        _m4d_failure(:unit_mismatch, "units", "M4-C unit bindings must match"))
    left.provenance == right.provenance || push!(failures,
        _m4d_failure(:provenance_mismatch, "provenance", "M4-C provenance must match"))
    if block === nothing || right_hand === nothing
        return _m4d_invalid_result(failures)
    end
    a, b, c, d = block
    det = _m4d_sub(_m4d_mul(a, d), _m4d_mul(b, c))
    det.numerator == 0 && push!(failures,
        _m4d_failure(:singular_block, "block_matrix", "2x2 block determinant is zero"))
    (a == d && b == c && _m4d_positive(a) && _m4d_positive(d) && _m4d_positive(det)) ||
        push!(failures, _m4d_failure(:non_spd_block, "block_matrix",
            "block must be symmetric positive definite"))
    iresult = _m4d_coerce_interface(interface, lid, rid, left, right,
        left.conservation_owner)
    iresult isa ManufacturedCoupledSolveControlResultV1 && return iresult
    append!(failures, _m4d_validate_interface(iresult, left, right, lid, rid,
        left.grid.counts))
    isempty(failures) || return _m4d_invalid_result(failures)

    pairs = iresult.pairs
    solutions = M4DCoupledCellSolutionV1[]
    residuals = NTuple{2,M4RationalV1}[]
    values, residual, _ = _m4d_solve_pair(block, right_hand)
    for pair in pairs
        push!(solutions, M4DCoupledCellSolutionV1(pair.left_index, pair.right_index,
            values[1], values[2], residual, left.equation_id, left.source_id,
            left.conservation_owner))
        push!(residuals, residual)
    end
    control = ManufacturedCoupledSolveControlV1(M4D_SCHEMA_V1, left, right, lid, rid,
        left.grid.counts, iresult, block, right_hand, left.equation_id,
        left.source_id, left.source_owner, left.conservation_owner, left.units,
        left.provenance, Tuple(solutions), Tuple(residuals),
        M4RationalV1(0, 1), M4D_CLAIM_CEILING_V1, M4D_EVIDENCE_SCOPE_V1)
    result = validate_manufactured_coupled_solve_control(control)
    result.valid ? result : ManufacturedCoupledSolveControlResultV1(false,
        result.status, control, result.failures, result.claim_ceiling,
        result.evidence_scope)
end

function _m4d_validate_interface(i::M4DInterfaceBindingV1,
        left::ManufacturedDiscreteControlV1, right::ManufacturedDiscreteControlV1,
        lid::String, rid::String, expected_counts::NTuple{3,Int})
    failures = ManufacturedCoupledSolveControlFailureV1[]
    i.left_region_id == lid && i.right_region_id == rid || push!(failures,
        _m4d_failure(:nonbijective_interface, "interface.region", "interface region IDs are foreign"))
    i.left_grid_counts == expected_counts && i.right_grid_counts == expected_counts &&
        i.left_grid_counts == left.grid.counts && i.right_grid_counts == right.grid.counts ||
        push!(failures, _m4d_failure(:grid_mismatch, "interface.grid_counts",
            "interface nested grid counts are not bound to c.grid_counts and both C controls"))
    n = prod(left.grid.counts)
    length(i.pairs) == n || push!(failures, _m4d_failure(:nonbijective_interface,
        "interface.pairs", "interface must contain one pair for every cell"))
    left_seen, right_seen = Set{NTuple{3,Int}}(), Set{NTuple{3,Int}}()
    for p in i.pairs
        valid_left = all(1 <= p.left_index[q] <= left.grid.counts[q] for q in 1:3)
        valid_right = all(1 <= p.right_index[q] <= right.grid.counts[q] for q in 1:3)
        valid_left && valid_right || push!(failures, _m4d_failure(
            :nonbijective_interface, "interface.pairs", "cell pair is outside its grid"))
        p.left_index == p.right_index || push!(failures,
            _m4d_failure(:nonbijective_interface, "interface.pairs", "only identity cell mapping is admitted"))
        p.left_index in left_seen || push!(left_seen, p.left_index)
        p.right_index in right_seen || push!(right_seen, p.right_index)
    end
    length(left_seen) == n && length(right_seen) == n && i.identity && i.bijective ||
        push!(failures, _m4d_failure(:nonbijective_interface, "interface.bijection",
            "interface must be an identity bijection"))
    i.conservation_owner == left.conservation_owner || push!(failures,
        _m4d_failure(:owner_mismatch, "interface.conservation_owner", "interface owner is foreign"))
    failures
end

function build_manufactured_coupled_solve_control(input, rest...; kwargs...)
    _m4d_invalid_result([_m4d_failure(:foreign_c_input, "input",
        "inputs must be two M4-C ManufacturedDiscreteControlV1 values")])
end

function build_manufactured_coupled_solve_control(
        left::ManufacturedDiscreteControlResultV1,
        right::ManufacturedDiscreteControlResultV1; kwargs...)
    left.valid && right.valid && left.control !== nothing && right.control !== nothing ||
        return _m4d_invalid_result([_m4d_failure(:foreign_c_input, "input",
            "M4-C result is invalid or has no control")])
    build_manufactured_coupled_solve_control(left.control, right.control; kwargs...)
end

const manufactured_coupled_solve_control_v1 = build_manufactured_coupled_solve_control
const manufactured_coupled_solve_control = build_manufactured_coupled_solve_control
const solve_manufactured_coupled_control_v1 = build_manufactured_coupled_solve_control
const solve_manufactured_coupled_solve_control = build_manufactured_coupled_solve_control
const solve_manufactured_coupled_solve_control_v1 = build_manufactured_coupled_solve_control

function _m4d_cell_payload(s::M4DCoupledCellSolutionV1)
    (left_index=s.left_index, right_index=s.right_index,
     left_value=_m4d_rat_payload(s.left_value),
     right_value=_m4d_rat_payload(s.right_value),
     residual=Tuple(_m4d_rat_payload(x) for x in s.residual),
     equation_id=s.equation_id, source_id=s.source_id,
     conservation_owner=s.conservation_owner)
end

function _m4d_interface_payload(i::M4DInterfaceBindingV1)
    (left_region_id=i.left_region_id, right_region_id=i.right_region_id,
     left_grid_counts=i.left_grid_counts, right_grid_counts=i.right_grid_counts,
     pairs=Tuple((left_index=p.left_index, right_index=p.right_index) for p in i.pairs),
     identity=i.identity, bijective=i.bijective,
     conservation_owner=i.conservation_owner)
end

"""Return a deterministic scalar/tuple-only payload for hashing."""
function manufactured_coupled_solve_control_payload(c::ManufacturedCoupledSolveControlV1)
    (schema=c.schema, regions=(left=c.left_region_id, right=c.right_region_id),
     grid_counts=c.grid_counts, interface=_m4d_interface_payload(c.interface),
     block_matrix=Tuple(_m4d_rat_payload(x) for x in c.block_matrix),
     rhs=Tuple(_m4d_rat_payload(x) for x in c.rhs), equation_id=c.equation_id,
     source_id=c.source_id, source_owner=c.source_owner,
     conservation_owner=c.conservation_owner,
     units=(coordinate_unit=_m4d_unit_payload(c.units.coordinate_unit),
            mesh_unit=_m4d_unit_payload(c.units.mesh_unit),
            face_area_unit=_m4d_unit_payload(c.units.face_area_unit),
            cell_volume_unit=_m4d_unit_payload(c.units.cell_volume_unit),
            coefficient_unit=_m4d_unit_payload(c.units.coefficient_unit),
            field_unit=_m4d_unit_payload(c.units.field_unit),
            source_unit=_m4d_unit_payload(c.units.source_unit),
            divergence_unit=_m4d_unit_payload(c.units.divergence_unit),
            residual_unit=_m4d_unit_payload(c.units.residual_unit)),
     provenance=c.provenance, cells=Tuple(_m4d_cell_payload(x) for x in c.cell_solutions),
     block_residuals=Tuple(Tuple(_m4d_rat_payload(x) for x in r) for r in c.block_residuals),
     block_residual=_m4d_rat_payload(c.block_residual),
     claim_ceiling=c.claim_ceiling, evidence_scope=c.evidence_scope)
end

const manufactured_coupled_solve_payload_v1 = manufactured_coupled_solve_control_payload
const manufactured_coupled_payload_v1 = manufactured_coupled_solve_control_payload

"""Validate bindings and exact algebra without executing an external solver."""
function validate_manufactured_coupled_solve_control(c::ManufacturedCoupledSolveControlV1)
    failures = ManufacturedCoupledSolveControlFailureV1[]
    left_result = validate_manufactured_discrete_control(c.left)
    right_result = validate_manufactured_discrete_control(c.right)
    for (side, result) in (("left", left_result), ("right", right_result))
        result.valid && continue
        if isempty(result.failures)
            push!(failures, _m4d_failure(:foreign_c_input, side,
                string(side, " M4-C validation failed without a detailed failure")))
        else
            for f in result.failures
                push!(failures, _m4d_failure(:foreign_c_input,
                    string(side, ".", f.path), f.detail))
            end
        end
    end
    c.schema == M4D_SCHEMA_V1 || push!(failures, _m4d_failure(:foreign_c_input,
        "schema", "control schema is not frozen M4-D"))
    c.grid_counts == c.left.grid.counts && c.grid_counts == c.right.grid.counts ||
        push!(failures, _m4d_failure(:grid_mismatch, "grid_counts",
            "control grid_counts must equal both nested C grids"))
    c.left.grid == c.right.grid || push!(failures,
        _m4d_failure(:grid_mismatch, "regions.grid", "region grids differ"))
    c.left_region_id != c.right_region_id && !isempty(c.left_region_id) &&
        !isempty(c.right_region_id) || push!(failures, _m4d_failure(:owner_mismatch,
            "regions", "region identities must be nonempty and distinct"))
    append!(failures, _m4d_validate_interface(c.interface, c.left, c.right,
        c.left_region_id, c.right_region_id, c.grid_counts))
    c.left.units == c.right.units && c.units == c.left.units || push!(failures,
        _m4d_failure(:unit_mismatch, "units", "unit binding is not shared by both regions"))
    c.left.equation_id == c.right.equation_id && c.right.equation_id == c.equation_id || push!(failures,
        _m4d_failure(:owner_mismatch, "equation_id", "equation identity is not closed"))
    c.left.source_id == c.right.source_id && c.right.source_id == c.source_id || push!(failures,
        _m4d_failure(:owner_mismatch, "source_id", "source identity is not closed"))
    c.left.source_owner == c.source_owner || push!(failures,
        _m4d_failure(:owner_mismatch, "left.source_owner", "left source owner is not bound to control"))
    c.right.source_owner == c.source_owner || push!(failures,
        _m4d_failure(:owner_mismatch, "right.source_owner", "right source owner is not bound to control"))
    c.left.conservation_owner == c.conservation_owner || push!(failures,
        _m4d_failure(:owner_mismatch, "left.conservation_owner", "left conservation owner is not bound to control"))
    c.right.conservation_owner == c.conservation_owner || push!(failures,
        _m4d_failure(:owner_mismatch, "right.conservation_owner", "right conservation owner is not bound to control"))
    c.left.provenance == c.right.provenance && c.right.provenance == c.provenance || push!(failures,
        _m4d_failure(:provenance_mismatch, "provenance", "provenance binding is not closed"))
    a, b, d, e = c.block_matrix
    det = _m4d_sub(_m4d_mul(a, e), _m4d_mul(b, d))
    det.numerator == 0 && push!(failures, _m4d_failure(:singular_block,
        "block_matrix", "block determinant is zero"))
    a == e && b == d && _m4d_positive(a) && _m4d_positive(e) && _m4d_positive(det) ||
        push!(failures, _m4d_failure(:non_spd_block, "block_matrix", "block is not SPD"))
    expected, expected_residual, _ = _m4d_solve_pair(c.block_matrix, c.rhs)
    length(c.cell_solutions) == length(c.interface.pairs) &&
        length(c.cell_solutions) == prod(c.grid_counts) || push!(failures,
        _m4d_failure(:nonbijective_interface, "cell_solutions", "one solution per matched cell is required"))
    for (solution_index, s) in enumerate(c.cell_solutions)
        solution_index <= length(c.interface.pairs) || break
        pair = c.interface.pairs[solution_index]
        s.left_index == pair.left_index && s.right_index == pair.right_index ||
            push!(failures, _m4d_failure(:nonbijective_interface,
                string("cell_solutions[", solution_index, "].index"),
                "solution index is not bound to the corresponding interface pair"))
        s.left_index == s.right_index || push!(failures,
            _m4d_failure(:nonbijective_interface,
                string("cell_solutions[", solution_index, "].index"),
                "solution cell indices must preserve the identity mapping"))
        s.equation_id == c.equation_id && s.source_id == c.source_id &&
            s.conservation_owner == c.conservation_owner || push!(failures,
            _m4d_failure(:owner_mismatch,
                string("cell_solutions[", solution_index, "].binding"),
                "solution equation/source/owner binding is foreign"))
        (_m4d_equal(s.left_value, expected[1]) && _m4d_equal(s.right_value, expected[2]) &&
         all(_m4d_equal(x, expected_residual[i]) for (i, x) in enumerate(s.residual))) ||
            push!(failures, _m4d_failure(:nonzero_residual, "cell_solutions", "solution or block residual differs"))
        all(_m4d_equal(x, M4RationalV1(0, 1)) for x in s.residual) ||
            push!(failures, _m4d_failure(:nonzero_residual, "cell_solutions.residual", "block residual is nonzero"))
    end
    all(all(_m4d_equal(x, M4RationalV1(0, 1)) for x in r) for r in c.block_residuals) ||
        push!(failures, _m4d_failure(:nonzero_residual, "block_residuals", "stored block residual is nonzero"))
    _m4d_equal(c.block_residual, M4RationalV1(0, 1)) || push!(failures,
        _m4d_failure(:nonzero_residual, "block_residual", "aggregate block residual is nonzero"))
    c.claim_ceiling == M4D_CLAIM_CEILING_V1 && c.evidence_scope == M4D_EVIDENCE_SCOPE_V1 ||
        push!(failures, _m4d_failure(:provenance_mismatch, "claim_ceiling", "D remains screen-only"))
    typed = Tuple(failures)
    ManufacturedCoupledSolveControlResultV1(isempty(typed),
        isempty(typed) ? :valid : :typed_failure, c, typed,
        c.claim_ceiling, c.evidence_scope)
end

function validate_manufactured_coupled_solve_control(input)
    _m4d_invalid_result([_m4d_failure(:foreign_c_input, "input",
        "input must be ManufacturedCoupledSolveControlV1")])
end
function validate_manufactured_coupled_solve_control(r::ManufacturedCoupledSolveControlResultV1)
    r.control === nothing ? r : validate_manufactured_coupled_solve_control(r.control)
end

is_valid_manufactured_coupled_solve_control(c::ManufacturedCoupledSolveControlV1) =
    validate_manufactured_coupled_solve_control(c).valid
is_valid_manufactured_coupled_solve_control(r::ManufacturedCoupledSolveControlResultV1) = r.valid
const validate_manufactured_coupled_solve_control_v1 = validate_manufactured_coupled_solve_control
const is_valid_manufactured_coupled_solve_control_v1 = is_valid_manufactured_coupled_solve_control
