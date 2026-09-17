"""Isolated M4-C manufactured conservative finite-volume control.

This lane consumes only the accepted M4-B manufactured residual declaration. It
constructs a deterministic, exact (integer-rational) local balance on a
cell-centred uniform Cartesian mesh. It intentionally does not create a
matrix, solve a system, couple fields, bind a candidate, call a provider, or
emit physics/engineering evidence.
"""

if !isdefined(@__MODULE__, :ManufacturedResidualDeclarationV1)
    include(joinpath(@__DIR__, "ManufacturedResidualLoweringV1.jl"))
end

const M4C_SCHEMA_V1 = "M4-C-MANUFACTURED-DISCRETE-CONTROL-V1"
const M4C_CLAIM_CEILING_V1 = :manufactured_discrete_control
const M4C_EVIDENCE_SCOPE_V1 = :screen_only
const M4C_TOPOLOGY_ID_V1 = "M4-C-uniform-cartesian-cell-centered-v1"
const M4C_BOUNDARY_ID_V1 = "M4-C-manufactured-six-face-closure-v1"
const M4C_MESH_UNIT_V1 = M4_LENGTH_V1
const M4C_VOLUME_UNIT_V1 = M4UnitV1("m^3", (3, 0, 0, 0, 0, 0, 0), 1.0)

struct ManufacturedDiscreteControlFailureV1
    code::Symbol
    path::String
    detail::String
end

_m4c_failure(code::Symbol, path::AbstractString, detail::AbstractString) =
    ManufacturedDiscreteControlFailureV1(code, String(path), String(detail))

struct M4CGridV1
    domain_id::String
    dimension::Int
    counts::NTuple{3,Int}
    spacing::NTuple{3,M4RationalV1}
    cell_volume::M4RationalV1
    cell_centered::Bool
    uniform::Bool
    mesh_unit::M4UnitV1
    volume_unit::M4UnitV1
end

struct M4CTopologyV1
    id::String
    dimension::Int
    grid_counts::NTuple{3,Int}
    cell_count::Int
    cell_centered::Bool
    cartesian::Bool
    uniform::Bool
    face_count_per_cell::Int
    conservation_owner::String
end

struct M4CBoundaryClosureV1
    id::String
    equation_id::String
    domain_id::String
    face_ids::NTuple{6,String}
    complete::Bool
    kind::Symbol
    owner::String
    conservation_owner::String
end

struct M4CUnitBindingV1
    coordinate_unit::M4UnitV1
    mesh_unit::M4UnitV1
    face_area_unit::M4UnitV1
    cell_volume_unit::M4UnitV1
    coefficient_unit::M4UnitV1
    field_unit::M4UnitV1
    source_unit::M4UnitV1
    divergence_unit::M4UnitV1
    residual_unit::M4UnitV1
end

struct M4CFaceFluxV1
    cell_index::NTuple{3,Int}
    face_id::String
    axis::Symbol
    side::Symbol
    coordinate::M4RationalV1
    coefficient_component::M4RationalV1
    field_gradient::M4RationalV1
    normal_flux::M4RationalV1
    face_area::M4RationalV1
    divergence_contribution::M4RationalV1
    equation_id::String
    source_id::String
    conservation_owner::String
    boundary_id::String
end

struct M4CCellBalanceV1
    cell_index::NTuple{3,Int}
    cell_center::NTuple{3,M4RationalV1}
    faces::NTuple{6,M4CFaceFluxV1}
    directional_divergence::NTuple{3,M4RationalV1}
    divergence_total::M4RationalV1
    source_value::M4RationalV1
    residual_value::M4RationalV1
    equation_id::String
    source_id::String
    source_owner::String
    conservation_owner::String
end

struct ManufacturedDiscreteControlV1
    schema::String
    residual::ManufacturedResidualDeclarationV1
    equation_id::String
    domain_id::String
    grid::M4CGridV1
    topology::M4CTopologyV1
    boundary::M4CBoundaryClosureV1
    units::M4CUnitBindingV1
    source_id::String
    source_owner::String
    conservation_owner::String
    provenance::M4ProvenanceDeclarationV1
    faces::Tuple{Vararg{M4CFaceFluxV1}}
    cell_balances::Tuple{Vararg{M4CCellBalanceV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

struct ManufacturedDiscreteControlResultV1
    valid::Bool
    status::Symbol
    control::Union{Nothing,ManufacturedDiscreteControlV1}
    failures::Tuple{Vararg{ManufacturedDiscreteControlFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

_m4c_gcd(a::Int, b::Int) = gcd(abs(a), abs(b))

function _m4c_rat(n::Integer, d::Integer)
    d == 0 && return M4RationalV1(Int(n), 0)
    nn, dd = Int(n), Int(d)
    dd < 0 && ((nn, dd) = (-nn, -dd))
    g = _m4c_gcd(nn, dd)
    M4RationalV1(nn ÷ g, dd ÷ g)
end

_m4c_rat(a::M4RationalV1) = _m4c_rat(a.numerator, a.denominator)
_m4c_add(a::M4RationalV1, b::M4RationalV1) =
    _m4c_rat(a.numerator * b.denominator + b.numerator * a.denominator,
             a.denominator * b.denominator)
_m4c_neg(a::M4RationalV1) = _m4c_rat(-a.numerator, a.denominator)
_m4c_sub(a::M4RationalV1, b::M4RationalV1) = _m4c_add(a, _m4c_neg(b))
_m4c_mul(a::M4RationalV1, b::M4RationalV1) =
    _m4c_rat(a.numerator * b.numerator, a.denominator * b.denominator)
_m4c_div(a::M4RationalV1, b::M4RationalV1) =
    _m4c_rat(a.numerator * b.denominator, a.denominator * b.numerator)
_m4c_equal(a::M4RationalV1, b::M4RationalV1) =
    a.denominator != 0 && b.denominator != 0 &&
    a.numerator * b.denominator == b.numerator * a.denominator

_m4c_unit_payload(u::M4UnitV1) =
    (name=u.name, exponents=u.exponents, scale_to_si=u.scale_to_si)
_m4c_rat_payload(r::M4RationalV1) =
    (numerator=r.numerator, denominator=r.denominator)

function _m4c_invalid_result(failures)
    typed = Tuple(failures)
    ManufacturedDiscreteControlResultV1(false, :typed_failure, nothing, typed,
        M4C_CLAIM_CEILING_V1, M4C_EVIDENCE_SCOPE_V1)
end

function _m4c_grid(nx, ny, nz)
    all(x -> x isa Integer, (nx, ny, nz)) || return nothing
    counts = (Int(nx), Int(ny), Int(nz))
    all(>=(2), counts) || return nothing
    h = ntuple(i -> _m4c_rat(1, counts[i]), 3)
    volume = _m4c_mul(_m4c_mul(h[1], h[2]), h[3])
    M4CGridV1("Omega", 3, counts, h, volume, true, true,
        M4C_MESH_UNIT_V1, M4C_VOLUME_UNIT_V1)
end

function _m4c_flux(index::NTuple{3,Int}, face_id::String, axis::Symbol,
        side::Symbol, coordinate::M4RationalV1, component::M4RationalV1,
        area::M4RationalV1, spacing::M4RationalV1, equation_id::String,
        source_id::String, owner::String, boundary_id::String)
    gradient = M4RationalV1(1, 1)
    unsigned_flux = _m4c_mul(component, gradient)
    normal_flux = side == :minus ? _m4c_neg(unsigned_flux) : unsigned_flux
    contribution = _m4c_div(_m4c_mul(normal_flux, area),
        _m4c_mul(spacing, area))
    M4CFaceFluxV1(index, face_id, axis, side, coordinate, component,
        gradient, normal_flux, area, contribution, equation_id, source_id,
        owner, boundary_id)
end

function _m4c_make_cell(i::Int, j::Int, k::Int, grid::M4CGridV1,
        d::ManufacturedResidualDeclarationV1,
        boundary_id::String, owner::String)
    hx, hy, hz = grid.spacing
    nx, ny, nz = grid.counts
    index = (i, j, k)
    cx = _m4c_rat(2i - 1, 2nx)
    cy = _m4c_rat(2j - 1, 2ny)
    cz = _m4c_rat(2k - 1, 2nz)
    ax = _m4c_mul(hy, hz)
    ay = _m4c_mul(hx, hz)
    az = _m4c_mul(hx, hy)
    xlo, xhi = _m4c_rat(i - 1, nx), _m4c_rat(i, nx)
    ylo, yhi = _m4c_rat(j - 1, ny), _m4c_rat(j, ny)
    zlo, zhi = _m4c_rat(k - 1, nz), _m4c_rat(k, nz)
    qxlo, qxhi = _m4c_add(M4RationalV1(2, 1), _m4c_div(xlo, M4RationalV1(10, 1))),
        _m4c_add(M4RationalV1(2, 1), _m4c_div(xhi, M4RationalV1(10, 1)))
    qylo, qyhi = _m4c_add(M4RationalV1(3, 1), _m4c_div(ylo, M4RationalV1(20, 1))),
        _m4c_add(M4RationalV1(3, 1), _m4c_div(yhi, M4RationalV1(20, 1)))
    qzlo, qzhi = _m4c_add(M4RationalV1(4, 1), _m4c_div(zlo, M4RationalV1(30, 1))),
        _m4c_add(M4RationalV1(4, 1), _m4c_div(zhi, M4RationalV1(30, 1)))
    faces = (
        _m4c_flux(index, "x_min", :x, :minus, xlo, qxlo, ax, hx, d.equation_id, d.source_id, owner, boundary_id),
        _m4c_flux(index, "x_max", :x, :plus, xhi, qxhi, ax, hx, d.equation_id, d.source_id, owner, boundary_id),
        _m4c_flux(index, "y_min", :y, :minus, ylo, qylo, ay, hy, d.equation_id, d.source_id, owner, boundary_id),
        _m4c_flux(index, "y_max", :y, :plus, yhi, qyhi, ay, hy, d.equation_id, d.source_id, owner, boundary_id),
        _m4c_flux(index, "z_min", :z, :minus, zlo, qzlo, az, hz, d.equation_id, d.source_id, owner, boundary_id),
        _m4c_flux(index, "z_max", :z, :plus, zhi, qzhi, az, hz, d.equation_id, d.source_id, owner, boundary_id))
    directional = (_m4c_add(faces[1].divergence_contribution, faces[2].divergence_contribution),
                   _m4c_add(faces[3].divergence_contribution, faces[4].divergence_contribution),
                   _m4c_add(faces[5].divergence_contribution, faces[6].divergence_contribution))
    total = foldl(_m4c_add, directional; init=M4RationalV1(0, 1))
    # B freezes R(u) = -div(K*grad(u)) - f; the outward-flux divergence is
    # positive 11/60 while the accepted source is -11/60.
    residual = _m4c_sub(_m4c_neg(total), d.source_value)
    balance = M4CCellBalanceV1(index, (cx, cy, cz), faces, directional, total,
        d.source_value, residual, d.equation_id, d.source_id, d.source_owner, owner)
    balance, faces
end

"""Build the exact M4-C control from an accepted M4-B declaration."""
function build_manufactured_discrete_control(d::ManufacturedResidualDeclarationV1,
        nx, ny, nz)
    failures = ManufacturedDiscreteControlFailureV1[]
    b = validate_manufactured_residual(d)
    if !b.valid
        for f in b.failures
            push!(failures, _m4c_failure(:foreign_input, string("residual.", f.path), f.detail))
        end
    end
    grid = _m4c_grid(nx, ny, nz)
    grid === nothing && push!(failures,
        _m4c_failure(:invalid_grid, "grid.counts", "nx, ny, and nz must be integers >= 2"))
    isempty(failures) || return _m4c_invalid_result(failures)
    owner = d.conservation_owner
    topology = M4CTopologyV1(M4C_TOPOLOGY_ID_V1, 3, grid.counts,
        prod(grid.counts), true, true, true, 6, owner)
    boundary = M4CBoundaryClosureV1(M4C_BOUNDARY_ID_V1, d.equation_id,
        d.domain.id, ("x_min", "x_max", "y_min", "y_max", "z_min", "z_max"),
        true, :manufactured_flux, d.source_owner, owner)
    units = M4CUnitBindingV1(M4_LENGTH_V1, M4C_MESH_UNIT_V1,
        M4UnitV1("m^2", (2, 0, 0, 0, 0, 0, 0), 1.0), M4C_VOLUME_UNIT_V1,
        d.coefficient_unit, d.field_unit, d.source_unit,
        M4_DIMENSIONLESS_V1, M4_DIMENSIONLESS_V1)
    balances = M4CCellBalanceV1[]
    faces = M4CFaceFluxV1[]
    for k in 1:grid.counts[3], j in 1:grid.counts[2], i in 1:grid.counts[1]
        balance, local_faces = _m4c_make_cell(i, j, k, grid, d,
            boundary.id, owner)
        push!(balances, balance)
        append!(faces, local_faces)
    end
    control = ManufacturedDiscreteControlV1(M4C_SCHEMA_V1, d, d.equation_id,
        d.domain.id, grid, topology, boundary, units, d.source_id,
        d.source_owner, owner, d.provenance, Tuple(faces), Tuple(balances),
        M4C_CLAIM_CEILING_V1, M4C_EVIDENCE_SCOPE_V1)
    result = validate_manufactured_discrete_control(control)
    result.valid ? result : ManufacturedDiscreteControlResultV1(false,
        result.status, control, result.failures, result.claim_ceiling,
        result.evidence_scope)
end

function build_manufactured_discrete_control(input, nx, ny, nz)
    _m4c_invalid_result([_m4c_failure(:foreign_input, "residual",
        "input must be an M4-B ManufacturedResidualDeclarationV1")])
end

function build_manufactured_discrete_control(input; nx, ny, nz)
    build_manufactured_discrete_control(input, nx, ny, nz)
end

const manufactured_discrete_control_v1 = build_manufactured_discrete_control
const lower_manufactured_discrete_control_v1 = build_manufactured_discrete_control
const manufactured_discrete_control = build_manufactured_discrete_control

function build_manufactured_discrete_control(r::ManufacturedResidualLoweringResultV1,
        nx, ny, nz)
    r.valid && r.declaration !== nothing || return _m4c_invalid_result([
        _m4c_failure(:foreign_input, "residual", "M4-B result is invalid or has no declaration")])
    build_manufactured_discrete_control(r.declaration, nx, ny, nz)
end

function _m4c_face_payload(f::M4CFaceFluxV1)
    (cell_index=f.cell_index, face_id=f.face_id, axis=f.axis, side=f.side,
     coordinate=_m4c_rat_payload(f.coordinate),
     coefficient_component=_m4c_rat_payload(f.coefficient_component),
     field_gradient=_m4c_rat_payload(f.field_gradient),
     normal_flux=_m4c_rat_payload(f.normal_flux),
     face_area=_m4c_rat_payload(f.face_area),
     divergence_contribution=_m4c_rat_payload(f.divergence_contribution),
     equation_id=f.equation_id, source_id=f.source_id,
     conservation_owner=f.conservation_owner, boundary_id=f.boundary_id)
end

function _m4c_balance_payload(b::M4CCellBalanceV1)
    (cell_index=b.cell_index, cell_center=Tuple(_m4c_rat_payload(x) for x in b.cell_center),
     faces=Tuple(_m4c_face_payload(f) for f in b.faces),
     directional_divergence=Tuple(_m4c_rat_payload(x) for x in b.directional_divergence),
     divergence_total=_m4c_rat_payload(b.divergence_total),
     source_value=_m4c_rat_payload(b.source_value),
     residual_value=_m4c_rat_payload(b.residual_value), equation_id=b.equation_id,
     source_id=b.source_id, source_owner=b.source_owner,
     conservation_owner=b.conservation_owner)
end

"""Return a deterministic scalar/tuple-only assembly payload."""
function manufactured_discrete_control_payload(c::ManufacturedDiscreteControlV1)
    (schema=c.schema, equation_id=c.equation_id, domain_id=c.domain_id,
     residual=manufactured_residual_payload(c.residual),
     grid=(domain_id=c.grid.domain_id, dimension=c.grid.dimension,
           counts=c.grid.counts, spacing=Tuple(_m4c_rat_payload(x) for x in c.grid.spacing),
           cell_volume=_m4c_rat_payload(c.grid.cell_volume),
           cell_centered=c.grid.cell_centered, uniform=c.grid.uniform,
           mesh_unit=_m4c_unit_payload(c.grid.mesh_unit),
           volume_unit=_m4c_unit_payload(c.grid.volume_unit)),
     topology=c.topology, boundary=c.boundary,
     units=(coordinate_unit=_m4c_unit_payload(c.units.coordinate_unit),
            mesh_unit=_m4c_unit_payload(c.units.mesh_unit),
            face_area_unit=_m4c_unit_payload(c.units.face_area_unit),
            cell_volume_unit=_m4c_unit_payload(c.units.cell_volume_unit),
            coefficient_unit=_m4c_unit_payload(c.units.coefficient_unit),
            field_unit=_m4c_unit_payload(c.units.field_unit),
            source_unit=_m4c_unit_payload(c.units.source_unit),
            divergence_unit=_m4c_unit_payload(c.units.divergence_unit),
            residual_unit=_m4c_unit_payload(c.units.residual_unit)),
     source_id=c.source_id, source_owner=c.source_owner,
     conservation_owner=c.conservation_owner, provenance=c.provenance,
     faces=Tuple(_m4c_face_payload(f) for f in c.faces),
     cell_balances=Tuple(_m4c_balance_payload(b) for b in c.cell_balances),
     claim_ceiling=c.claim_ceiling, evidence_scope=c.evidence_scope)
end

const manufactured_discrete_payload_v1 = manufactured_discrete_control_payload
const manufactured_discrete_control_payload_v1 = manufactured_discrete_control_payload

"""Validate the control without executing a solver or external process."""
function validate_manufactured_discrete_control(c::ManufacturedDiscreteControlV1)
    failures = ManufacturedDiscreteControlFailureV1[]
    g, t, b, u = c.grid, c.topology, c.boundary, c.units
    all(>=(2), g.counts) && g.dimension == 3 || push!(failures,
        _m4c_failure(:invalid_grid, "grid.counts", "grid counts must be >= 2 in three dimensions"))
    expected_h = ntuple(i -> _m4c_rat(1, g.counts[i]), 3)
    g.domain_id == "Omega" && g.cell_centered && g.uniform && g.spacing == expected_h ||
        push!(failures, _m4c_failure(:invalid_grid, "grid", "grid must be uniform cell-centred Omega with h=1/n"))
    _m4c_equal(g.cell_volume, _m4c_mul(_m4c_mul(g.spacing[1], g.spacing[2]), g.spacing[3])) ||
        push!(failures, _m4c_failure(:invalid_grid, "grid.cell_volume", "cell volume does not match spacing"))
    t.id == M4C_TOPOLOGY_ID_V1 && t.dimension == 3 && t.grid_counts == g.counts &&
        t.cell_count == prod(g.counts) && t.cell_centered && t.cartesian && t.uniform &&
        t.face_count_per_cell == 6 || push!(failures,
        _m4c_failure(:invalid_topology, "topology", "topology is not the frozen six-face Cartesian topology"))
    b.id == M4C_BOUNDARY_ID_V1 && b.equation_id == c.equation_id &&
        b.domain_id == c.domain_id && b.complete && b.kind == :manufactured_flux &&
        b.face_ids == ("x_min", "x_max", "y_min", "y_max", "z_min", "z_max") ||
        push!(failures, _m4c_failure(:invalid_boundary, "boundary", "all six faces require the frozen boundary closure"))
    c.schema == M4C_SCHEMA_V1 && c.equation_id == c.residual.equation_id &&
        c.domain_id == c.residual.domain.id && c.source_id == c.residual.source_id ||
        push!(failures, _m4c_failure(:foreign_input, "equation", "C is not bound to the accepted B declaration"))
    u.coordinate_unit == M4_LENGTH_V1 && u.mesh_unit == M4_LENGTH_V1 &&
        u.face_area_unit == M4UnitV1("m^2", (2, 0, 0, 0, 0, 0, 0), 1.0) &&
        u.cell_volume_unit == M4C_VOLUME_UNIT_V1 && u.coefficient_unit == c.residual.coefficient_unit &&
        u.field_unit == c.residual.field_unit && u.source_unit == c.residual.source_unit &&
        u.divergence_unit == M4_DIMENSIONLESS_V1 && u.residual_unit == M4_DIMENSIONLESS_V1 ||
        push!(failures, _m4c_failure(:unit_closure_failure, "units", "mesh, face, volume, coefficient, source and residual units are not closed"))
    c.source_owner == c.residual.source_owner && !isempty(c.source_owner) &&
        c.conservation_owner == c.residual.conservation_owner &&
        t.conservation_owner == c.conservation_owner &&
        b.owner == c.source_owner && b.conservation_owner == c.conservation_owner ||
        push!(failures, _m4c_failure(:owner_mismatch, "ownership", "source and conservation owners are not explicitly bound"))
    c.provenance == c.residual.provenance && c.claim_ceiling == M4C_CLAIM_CEILING_V1 &&
        c.evidence_scope == M4C_EVIDENCE_SCOPE_V1 || push!(failures,
        _m4c_failure(:provenance_mismatch, "provenance", "C provenance/claim ceiling is not bound to B"))
    expected_cells = prod(g.counts)
    length(c.cell_balances) == expected_cells && length(c.faces) == 6 * expected_cells ||
        push!(failures, _m4c_failure(:nonconservative_stencil, "assembly", "one six-face balance is required per cell"))
    for balance in c.cell_balances
        if length(balance.faces) != 6
            push!(failures, _m4c_failure(:invalid_topology, "cell_balances.faces", "cell must have the ordered six-face stencil"))
            continue
        end
        balance.faces[1].face_id == "x_min" && balance.faces[2].face_id == "x_max" &&
            balance.faces[3].face_id == "y_min" && balance.faces[4].face_id == "y_max" &&
            balance.faces[5].face_id == "z_min" && balance.faces[6].face_id == "z_max" ||
            push!(failures, _m4c_failure(:invalid_topology, "cell_balances.faces", "cell must have the ordered six-face stencil"))
        balance.directional_divergence == (M4RationalV1(1, 10), M4RationalV1(1, 20), M4RationalV1(1, 30)) ||
            push!(failures, _m4c_failure(:nonconservative_stencil, "cell_balances.directional_divergence", "directional divergence must be 1/10, 1/20, 1/30"))
        _m4c_equal(balance.divergence_total, M4RationalV1(11, 60)) ||
            push!(failures, _m4c_failure(:nonconservative_stencil, "cell_balances.divergence_total", "six-face divergence must be 11/60"))
        _m4c_equal(balance.source_value, M4RationalV1(-11, 60)) ||
            push!(failures, _m4c_failure(:foreign_input, "cell_balances.source_value", "source must be the accepted B source -11/60"))
        _m4c_equal(balance.residual_value, M4RationalV1(0, 1)) ||
            push!(failures, _m4c_failure(:nonzero_residual, "cell_balances.residual_value", "each local residual must be exactly zero"))
        balance.equation_id == c.equation_id && balance.source_id == c.source_id &&
            balance.source_owner == c.source_owner && balance.conservation_owner == c.conservation_owner ||
            push!(failures, _m4c_failure(:owner_mismatch, "cell_balances.binding", "cell balance ownership/equation binding is foreign"))
        i, j, k = balance.cell_index
        1 <= i <= g.counts[1] && 1 <= j <= g.counts[2] && 1 <= k <= g.counts[3] ||
            push!(failures, _m4c_failure(:invalid_topology, "cell_balances.cell_index", "cell index is outside the declared grid"))
        for (face_index, face) in enumerate(balance.faces)
            face.equation_id == c.equation_id && face.source_id == c.source_id &&
                face.boundary_id == b.id && face.conservation_owner == c.conservation_owner ||
                push!(failures, _m4c_failure(:foreign_input, "faces.binding", "face flux is not bound to equation/source/boundary/owner"))
            face.cell_index == balance.cell_index || push!(failures,
                _m4c_failure(:invalid_topology, "faces.cell_index", "face belongs to a different cell"))
            expected_axis = face_index <= 2 ? :x : face_index <= 4 ? :y : :z
            expected_side = isodd(face_index) ? :minus : :plus
            face.axis == expected_axis && face.side == expected_side || push!(failures,
                _m4c_failure(:invalid_topology, "faces.axis_side", "face axis/side is not the ordered six-face topology"))
            if face.axis == :x && face.side in (:minus, :plus)
                coordinate = face.side == :minus ? _m4c_rat(i - 1, g.counts[1]) : _m4c_rat(i, g.counts[1])
                component = _m4c_add(M4RationalV1(2, 1), _m4c_div(coordinate, M4RationalV1(10, 1)))
                area = _m4c_mul(g.spacing[2], g.spacing[3])
                spacing = g.spacing[1]
            elseif face.axis == :y && face.side in (:minus, :plus)
                coordinate = face.side == :minus ? _m4c_rat(j - 1, g.counts[2]) : _m4c_rat(j, g.counts[2])
                component = _m4c_add(M4RationalV1(3, 1), _m4c_div(coordinate, M4RationalV1(20, 1)))
                area = _m4c_mul(g.spacing[1], g.spacing[3])
                spacing = g.spacing[2]
            elseif face.axis == :z && face.side in (:minus, :plus)
                coordinate = face.side == :minus ? _m4c_rat(k - 1, g.counts[3]) : _m4c_rat(k, g.counts[3])
                component = _m4c_add(M4RationalV1(4, 1), _m4c_div(coordinate, M4RationalV1(30, 1)))
                area = _m4c_mul(g.spacing[1], g.spacing[2])
                spacing = g.spacing[3]
            else
                continue
            end
            expected_normal = face.side == :minus ? _m4c_neg(component) : component
            expected_contribution = _m4c_div(_m4c_mul(expected_normal, area),
                _m4c_mul(spacing, area))
            _m4c_equal(face.coordinate, coordinate) &&
                _m4c_equal(face.coefficient_component, component) &&
                _m4c_equal(face.field_gradient, M4RationalV1(1, 1)) &&
                _m4c_equal(face.normal_flux, expected_normal) &&
                _m4c_equal(face.face_area, area) &&
                _m4c_equal(face.divergence_contribution, expected_contribution) ||
                push!(failures, _m4c_failure(:nonconservative_stencil, "faces.flux", "face-centered K flux or volume normalization differs"))
        end
    end
    expected_faces = Tuple(face for balance in c.cell_balances for face in balance.faces)
    c.faces == expected_faces || push!(failures, _m4c_failure(
        :nonconservative_stencil, "faces", "assembly face list differs from local six-face balances"))
    typed = Tuple(failures)
    ManufacturedDiscreteControlResultV1(isempty(typed),
        isempty(typed) ? :valid : :typed_failure, c, typed,
        c.claim_ceiling, c.evidence_scope)
end

function validate_manufactured_discrete_control(input)
    _m4c_invalid_result([_m4c_failure(:foreign_input, "control",
        "input must be ManufacturedDiscreteControlV1")])
end

function validate_manufactured_discrete_control(r::ManufacturedDiscreteControlResultV1)
    r.control === nothing ? r : validate_manufactured_discrete_control(r.control)
end

is_valid_manufactured_discrete_control(c::ManufacturedDiscreteControlV1) =
    validate_manufactured_discrete_control(c).valid
is_valid_manufactured_discrete_control(r::ManufacturedDiscreteControlResultV1) =
    validate_manufactured_discrete_control(r).valid
const validate_manufactured_discrete_control_v1 = validate_manufactured_discrete_control
const is_valid_manufactured_discrete_control_v1 = is_valid_manufactured_discrete_control
