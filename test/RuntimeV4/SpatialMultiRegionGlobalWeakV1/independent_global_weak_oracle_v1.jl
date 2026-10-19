"""Independent shared-node Q1 oracle for the manufactured circular torus.

This file intentionally does not call the SpatialMultiRegion cell-row assembly,
its local-row offsets, or production basis/field helpers. It builds a physical
shared-node graph from integer mesh coordinates and assembles global Galerkin
rows from direct chart geometry and independent Gauss rules.
"""
module SpatialMultiRegionGlobalWeakOracleV1

using LinearAlgebra

const _GL3_X = (-sqrt(3 / 5), 0.0, sqrt(3 / 5))
const _GL3_W = (5 / 9, 8 / 9, 5 / 9)
const _GL5_X = (-sqrt(5 + 2sqrt(10 / 7)) / 3,
    -sqrt(5 - 2sqrt(10 / 7)) / 3, 0.0,
     sqrt(5 - 2sqrt(10 / 7)) / 3,
     sqrt(5 + 2sqrt(10 / 7)) / 3)
const _GL5_W = ((322 - 13sqrt(70)) / 900,
    (322 + 13sqrt(70)) / 900, 128 / 225,
    (322 + 13sqrt(70)) / 900,
    (322 - 13sqrt(70)) / 900)

function _neumaier_add3!(sum::Vector{Float64}, correction::Vector{Float64}, term)
    for i in eachindex(sum)
        value = Float64(term[i])
        updated = sum[i] + value
        correction[i] += abs(sum[i]) >= abs(value) ?
            (sum[i] - updated) + value : (value - updated) + sum[i]
        sum[i] = updated
    end
    nothing
end

struct Grid
    rhos::Vector{Float64}
    nt::Int
    nz::Int
    node_order::Vector{NTuple{3,Float64}}
    node_keys::Vector{NTuple{3,Int}}
    node_ids::Dict{NTuple{3,Int},Int}
    cell_keys::Vector{NTuple{3,Int}}
    element_nodes::Vector{Vector{Int}}
    element_corners::Vector{NTuple{8,Int}}
    cell_ids::Dict{NTuple{3,Int},Int}
end

function grid(rhos, nt::Integer, nz::Integer)
    rr = Float64.(collect(rhos))
    length(rr) >= 2 && first(rr) == 0.0 && last(rr) == 1.0 &&
        all(diff(rr) .> 0.0) || throw(ArgumentError("invalid radial partition"))
    nt > 0 && nz > 0 || throw(ArgumentError("angular partitions must be positive"))
    node_order = NTuple{3,Float64}[]
    node_keys = NTuple{3,Int}[]
    node_ids = Dict{NTuple{3,Int},Int}()
    nr = length(rr) - 1
    for iz in 0:Int(nz)-1, ir in 0:nr, it in 0:(ir == 0 ? 0 : Int(nt)-1)
        key = (ir, it, iz)
        node_ids[key] = length(node_order) + 1
        push!(node_keys, key)
        push!(node_order, (rr[ir+1], 2pi * it / nt, 2pi * iz / nz))
    end
    cell_keys = NTuple{3,Int}[]
    cell_ids = Dict{NTuple{3,Int},Int}()
    element_nodes = Vector{Int}[]
    element_corners = NTuple{8,Int}[]
    for iz in 0:Int(nz)-1, ir in 0:nr-1, it in 0:Int(nt)-1
        key = (ir, it, iz)
        cell_ids[key] = length(cell_keys) + 1
        push!(cell_keys, key)
        corners = ntuple(8) do k1
            k = k1 - 1
            br = k % 2
            bt = div(k, 2) % 2
            bz = div(k, 4)
            ri = ir + br
            ti = ri == 0 ? 0 : mod(it + bt, nt)
            zi = mod(iz + bz, nz)
            node_ids[(ri, ti, zi)]
        end
        local_ids = Int[]
        for node in corners
            node in local_ids || push!(local_ids, node)
        end
        push!(element_nodes, local_ids)
        push!(element_corners, corners)
    end
    Grid(rr, Int(nt), Int(nz), node_order, node_keys, node_ids,
         cell_keys, element_nodes, element_corners, cell_ids)
end

function _gauss(order::Integer)
    order == 3 && return (_GL3_X, _GL3_W)
    order == 5 && return (_GL5_X, _GL5_W)
    throw(ArgumentError("oracle supports only frozen GL3/GL5 rules"))
end

function _basis(g::Grid, cell::Int, xi::NTuple{3,Float64})
    ir, it, iz = g.cell_keys[cell]
    h = (g.rhos[ir+2] - g.rhos[ir+1], 2pi / g.nt, 2pi / g.nz)
    N = zeros(8)
    dN = zeros(3, 8)
    for k in 0:7
        bits = (k % 2, div(k, 2) % 2, div(k, 4))
        factors = ntuple(a -> bits[a] == 0 ? 1 - xi[a] : xi[a], 3)
        N[k+1] = prod(factors)
        for a in 1:3
            sign = bits[a] == 0 ? -1.0 : 1.0
            dN[a, k+1] = sign / h[a] * prod(factors[b] for b in 1:3 if b != a)
        end
    end
    N, dN
end

function _q_at(g::Grid, cell::Int, xi::NTuple{3,Float64})
    ir, it, iz = g.cell_keys[cell]
    (g.rhos[ir+1] + xi[1] * (g.rhos[ir+2] - g.rhos[ir+1]),
     2pi * (it + xi[2]) / g.nt,
     2pi * (iz + xi[3]) / g.nz)
end

function _geometry(input, q::NTuple{3,<:Real})
    rho, theta, zeta = Float64.(q)
    a = Float64(input.geometry.minor_radius_m)
    r0 = Float64(input.geometry.R0_m)
    if input.geometry.model === :circular_torus
        c, s = cos(theta), sin(theta)
        E = [a*c  -a*rho*s  0.0;
             0.0    0.0      r0+a*rho*c;
             a*s    a*rho*c  0.0]
        R = r0 + a*rho*c
        Z = a*rho*s
    elseif input.geometry.model === :m1n1_ripple_torus
        eps = Float64(input.geometry.ripple_amplitude)
        phase = theta - zeta
        c = cos(theta) + eps*cos(phase)
        s = sin(theta) + eps*sin(phase)
        R = r0 + a*rho*c
        Z = a*rho*s
        E = [a*c  -a*rho*s  a*rho*eps*sin(phase);
             0.0    0.0      R;
             a*s    a*rho*c  -a*rho*eps*cos(phase)]
    else
        throw(ArgumentError("oracle does not support this interior map"))
    end
    xyz = (R*cos(zeta), R*sin(zeta), Z)
    rotation = [cos(zeta) -sin(zeta) 0.0;
                sin(zeta)  cos(zeta) 0.0;
                0.0        0.0       1.0]
    xyz, E, rotation
end

function _analytic(input, xyz::NTuple{3,<:Real})
    X, Y, Z = Float64.(xyz)
    R = hypot(X, Y)
    R > 0.0 || throw(ArgumentError("analytic torus field is singular at R=0"))
    beta = Float64(input.fields.beta_T_m)
    alpha = Float64(input.fields.alpha_Pa_m2)
    r0 = Float64(input.geometry.R0_m)
    mu0 = Float64(input.fields.mu0_N_A2)
    B = (-beta*Y, beta*X, 0.0)
    p = Float64(input.fields.p0_Pa) + alpha*((R-r0)^2 + Z^2)
    radial = -2beta^2*R/mu0 - 2alpha*(R-r0)
    source = (radial*X/R, radial*Y/R, -2alpha*Z)
    T = collect(B) * transpose(collect(B)) / mu0 -
        (sum(abs2, B)/(2mu0) + p) * Matrix{Float64}(I, 3, 3)
    (B=B, p=p, source=source, stress=T)
end

function _normal(E, rotation, axis::Int, sign::Float64=1.0)
    inverse = inv(E)
    n = sign .* (rotation * collect(inverse[axis, :]))
    n ./ norm(n)
end

function _face_weight(E, axis::Int, lengths::NTuple{2,Float64})
    other = filter(!=(axis), 1:3)
    norm(cross(E[:, other[1]], E[:, other[2]])) * lengths[1] * lengths[2]
end

function _evaluate(g::Grid, input, state::AbstractVector{<:Real}, cell::Int,
                   xi::NTuple{3,Float64}, q::NTuple{3,Float64},
                   basis_data=nothing, geometry_data=nothing)
    length(state) == 4length(g.node_order) || throw(ArgumentError("oracle state length mismatch"))
    N, dN = basis_data === nothing ? _basis(g, cell, xi) : basis_data
    ids = g.element_corners[cell]
    bcyl = zeros(3)
    dBcyl_dq = zeros(3, 3)
    pressure = 0.0
    dp_dq = zeros(3)
    for a in 1:8
        node = ids[a]
        base = 4(node - 1)
        Bnode = Float64[state[base+1], state[base+2], state[base+3]]
        pnode = Float64(state[base+4])
        bcyl .+= N[a] .* Bnode
        dBcyl_dq .+= Bnode * transpose(dN[:, a])
        pressure += N[a] * pnode
        dp_dq .+= dN[:, a] .* pnode
    end
    xyz, E, rotation = geometry_data === nothing ? _geometry(input, q) : geometry_data
    inverse = inv(E)
    R = hypot(xyz[1], xyz[2])
    # Cylindrical basis vectors rotate with zeta. This term is independent of
    # the production derivative implementation and is needed for div(B).
    basis_term = [-bcyl[2], bcyl[1], 0.0] * transpose(E[2, :] ./ R)
    grad_cyl = (dBcyl_dq + basis_term) * inverse
    Bxyz = rotation * bcyl
    gradN_xyz = rotation * transpose(inverse) * dN
    gradp_xyz = rotation * transpose(inverse) * dp_dq
    mu0 = Float64(input.fields.mu0_N_A2)
    stress = Bxyz * transpose(Bxyz) / mu0 -
        (dot(Bxyz, Bxyz)/(2mu0) + pressure) * Matrix{Float64}(I, 3, 3)
    (N=N, gradN_xyz=gradN_xyz, Bxyz=Bxyz, pressure=pressure,
     stress=stress, divB=tr(grad_cyl), gradp_xyz=gradp_xyz,
     gradB_xyz=rotation * grad_cyl * transpose(rotation), xyz=xyz, E=E,
     rotation=rotation, q=q)
end

function exact_nodal_state(input, g::Grid)
    state = zeros(4length(g.node_order))
    beta = Float64(input.fields.beta_T_m)
    p0 = Float64(input.fields.p0_Pa)
    alpha = Float64(input.fields.alpha_Pa_m2)
    r0 = Float64(input.geometry.R0_m)
    a = Float64(input.geometry.minor_radius_m)
    for (node, (rho, theta, zeta)) in enumerate(g.node_order)
        _, _, _, R, Z = _independent_map_terms(input, rho, theta, zeta)
        state[4(node-1)+2] = beta*R
        pressure = input.geometry.model === :circular_torus ?
            p0 + alpha*(a*rho)^2 : p0 + alpha*((R-r0)^2+Z^2)
        state[4(node-1)+4] = pressure
    end
    state
end

function _independent_map_terms(input, rho, theta, zeta)
    a = Float64(input.geometry.minor_radius_m)
    r0 = Float64(input.geometry.R0_m)
    if input.geometry.model === :circular_torus
        c, s = cos(theta), sin(theta)
    elseif input.geometry.model === :m1n1_ripple_torus
        eps = Float64(input.geometry.ripple_amplitude)
        c = cos(theta) + eps*cos(theta-zeta)
        s = sin(theta) + eps*sin(theta-zeta)
    else
        throw(ArgumentError("oracle does not support this interior map"))
    end
    D = c*c+s*s
    R = r0+a*rho*c
    Z = a*rho*s
    (c, s, D, R, Z)
end

function _m1n1_inverse(input, q::NTuple{3,<:Real})
    rho, theta, zeta = Float64.(q)
    eps = Float64(input.geometry.ripple_amplitude)
    a = Float64(input.geometry.minor_radius_m)
    _, _, D, R, _ = _independent_map_terms(input, rho, theta, zeta)
    D > 0.0 && rho > 0.0 && R > 0.0 ||
        throw(ArgumentError("m1n1 inverse is singular on the merged axis"))
    # Invert the chart differential by solving its two meridional rows and
    # then the toroidal row; this is independent of `inv(E)` in production.
    c, s, _, _, _ = _independent_map_terms(input, rho, theta, zeta)
    [c/(a*D)        rho*eps*sin(zeta)/(D*R)   s/(a*D);
     -s/(a*rho*D)   eps*(cos(zeta)+eps)/(D*R) c/(a*rho*D);
     0.0            1.0/R                     0.0]
end

function initial_nodal_state(input,g::Grid)
    state=exact_nodal_state(input,g)
    perturbation=Float64.(collect(input.initialization.perturbation))
    length(perturbation)==4 || throw(ArgumentError("oracle initial perturbation must have four nodal components"))
    state .+= repeat(perturbation,length(g.node_order))
    state
end

function _selected_volume_cell(row_mask, ids)
    row_mask === nothing && return true
    for node in ids, component in 1:4
        row_mask[4(node-1)+component] && return true
    end
    false
end

function _selected_boundary_trace(row_mask, outer_index, ids, node_order,
                                  trace_first)
    row_mask === nothing && return true
    for node in ids
        node_order[node][1] == 1.0 || continue
        firstrow = trace_first + 4(outer_index[node]-1)
        any(@view row_mask[firstrow:firstrow+3]) && return true
    end
    false
end

function _add_weak_point!(rows, g, input, state, cell, xi, q, weight, sign,
                          row_mask=nothing, basis_data=nothing, geometry_data=nothing)
    f = _evaluate(g, input, state, cell, xi, q, basis_data, geometry_data)
    source = _analytic(input, f.xyz).source
    ids = g.element_corners[cell]
    for a in 1:8
        row = 4(ids[a]-1)
        row_mask !== nothing && !any(@view row_mask[row+1:row+4]) && continue
        grad = view(f.gradN_xyz, :, a)
        for k in 1:3
            row_mask !== nothing && !row_mask[row+k] && continue
            rows[row+k] += sign * weight *
                (sum(f.stress[k, j] * grad[j] for j in 1:3) + f.N[a]*source[k])
        end
        (row_mask === nothing || row_mask[row+4]) &&
            (rows[row+4] += sign * weight * dot(grad, f.Bxyz))
    end
    f
end

function _volume_weak_rows(g, input, state, order, row_mask=nothing)
    n = 4length(g.node_order)
    rows = zeros(n)
    source_integral = zeros(3)
    source_correction = zeros(3)
    div2 = 0.0
    div_inf = 0.0
    total_volume = 0.0
    x, w = _gauss(order)
    for (cell, (ir, it, iz)) in enumerate(g.cell_keys)
        _selected_volume_cell(row_mask, g.element_corners[cell]) || continue
        hr = g.rhos[ir+2] - g.rhos[ir+1]
        ht = 2pi / g.nt
        hz = 2pi / g.nz
        for k in eachindex(x), j in eachindex(x), i in eachindex(x)
            xi = ((x[i]+1)/2, (x[j]+1)/2, (x[k]+1)/2)
            q = _q_at(g, cell, xi)
            basis_data = _basis(g, cell, xi)
            geometry_data = _geometry(input, q)
            xyz, E, _rotation = geometry_data
            weight = w[i]*w[j]*w[k] * hr*ht*hz/8 * abs(det(E))
            f = _add_weak_point!(rows, g, input, state, cell, xi, q, weight, -1.0,
                                 row_mask, basis_data, geometry_data)
            if row_mask === nothing
                _neumaier_add3!(source_integral, source_correction,
                    weight .* _analytic(input, xyz).source)
                div2 += weight * f.divB^2
                div_inf = max(div_inf, abs(f.divB))
                total_volume += weight
            end
        end
    end
    if row_mask === nothing
        source_integral .+= source_correction
    end
    (rows=rows, source_integral=source_integral, volume=total_volume,
     divB_L2=sqrt(div2), divB_Linf=div_inf)
end

function _cell_at(g::Grid, ir, it, iz)
    g.cell_ids[(ir, it, iz)]
end

function _add_interior_faces!(rows, g, input, state, order, row_mask=nothing)
    x, w = _gauss(order)
    n = 4length(g.node_order)
    interface_B = 0.0
    interface_Tn = 0.0
    interface_Bn = 0.0
    interface_action = zeros(3)
    interface_normal_balance = 0.0
    nr = length(g.rhos)-1
    for fixed in 1:nr-1, iz in 0:g.nz-1, it in 0:g.nt-1
        left = _cell_at(g, fixed-1, it, iz)
        right = _cell_at(g, fixed, it, iz)
        if row_mask !== nothing &&
           !_selected_volume_cell(row_mask, g.element_corners[left]) &&
           !_selected_volume_cell(row_mask, g.element_corners[right])
            continue
        end
        q = (g.rhos[fixed+1], 0.0, 0.0)
        for k in eachindex(x), j in eachindex(x)
            ut = (x[j]+1)/2
            uz = (x[k]+1)/2
            q = (g.rhos[fixed+1], 2pi*(it+ut)/g.nt, 2pi*(iz+uz)/g.nz)
            xi_l = (1.0, ut, uz); xi_r = (0.0, ut, uz)
            _, E, rot = _geometry(input, q)
            weight = w[j]*w[k]*(2pi/g.nt)*(2pi/g.nz)/4 *
                _face_weight(E, 1, (1.0, 1.0))
            nvec = _normal(E, rot, 1)
            fl = _evaluate(g, input, state, left, xi_l, q)
            fr = _evaluate(g, input, state, right, xi_r, q)
            for (cell, xi, f, sign) in ((left, xi_l, fl, 1.0),
                                         (right, xi_r, fr, -1.0))
                N, _dN = _basis(g, cell, xi)
                ids = g.element_corners[cell]
                traction = f.stress * nvec
                normalB = dot(f.Bxyz, nvec)
                for a in 1:8
                    row = 4(ids[a]-1)
                    row_mask !== nothing && !any(@view row_mask[row+1:row+4]) && continue
                    for c in 1:3
                        row_mask !== nothing && !row_mask[row+c] && continue
                        rows[row+c] += sign*weight*N[a]*traction[c]
                    end
                    (row_mask === nothing || row_mask[row+4]) &&
                        (rows[row+4] += sign*weight*N[a]*normalB)
                end
            end
            if fixed == nr÷2
                interface_B = max(interface_B, norm(fl.Bxyz-fr.Bxyz))
                interface_Tn = max(interface_Tn, norm((fl.stress-fr.stress)*nvec))
                interface_Bn = max(interface_Bn, abs(dot(fl.Bxyz-fr.Bxyz,nvec)))
                interface_action .+= weight .* ((fl.stress-fr.stress)*nvec)
                interface_normal_balance += weight *
                    (dot(fl.Bxyz,nvec)-dot(fr.Bxyz,nvec))
            end
        end
    end
    # Angular-periodic two-sided traces, one per physical face.
    for fixed in 0:g.nt-1, iz in 0:g.nz-1, ir in 0:nr-1
        left = _cell_at(g,ir,mod(fixed-1,g.nt),iz)
        right = _cell_at(g,ir,fixed,iz)
        if row_mask !== nothing &&
           !_selected_volume_cell(row_mask, g.element_corners[left]) &&
           !_selected_volume_cell(row_mask, g.element_corners[right])
            continue
        end
        hr=g.rhos[ir+2]-g.rhos[ir+1]
        for k in eachindex(x), j in eachindex(x)
            ur=(x[j]+1)/2;uz=(x[k]+1)/2
            q=(g.rhos[ir+1]+ur*hr,2pi*fixed/g.nt,2pi*(iz+uz)/g.nz)
            xi_l=(ur,1.0,uz);xi_r=(ur,0.0,uz)
            _,E,rot=_geometry(input,q)
            weight=w[j]*w[k]*hr*(2pi/g.nz)/4*_face_weight(E,2,(1.0,1.0))
            nvec=_normal(E,rot,2)
            fl=_evaluate(g,input,state,left,xi_l,q)
            fr=_evaluate(g,input,state,right,xi_r,q)
            for (cell,xi,f,sign) in ((left,xi_l,fl,1.0),(right,xi_r,fr,-1.0))
                N,_dN=_basis(g,cell,xi);ids=g.element_corners[cell]
                traction=f.stress*nvec;normalB=dot(f.Bxyz,nvec)
                for a in 1:8
                    row=4(ids[a]-1)
                    row_mask !== nothing && !any(@view row_mask[row+1:row+4]) && continue
                    for c in 1:3
                        row_mask !== nothing && !row_mask[row+c] && continue
                        rows[row+c]+=sign*weight*N[a]*traction[c]
                    end
                    (row_mask === nothing || row_mask[row+4]) &&
                        (rows[row+4]+=sign*weight*N[a]*normalB)
                end
            end
        end
    end
    # Toroidal periodic two-sided traces, retaining every poloidal sector.
    for fixed in 0:g.nz-1, ir in 0:nr-1, it in 0:g.nt-1
        left = _cell_at(g,ir,it,mod(fixed-1,g.nz))
        right = _cell_at(g,ir,it,fixed)
        if row_mask !== nothing &&
           !_selected_volume_cell(row_mask, g.element_corners[left]) &&
           !_selected_volume_cell(row_mask, g.element_corners[right])
            continue
        end
        hr=g.rhos[ir+2]-g.rhos[ir+1]
        for k in eachindex(x), j in eachindex(x)
            ur=(x[j]+1)/2;ut=(x[k]+1)/2
            q=(g.rhos[ir+1]+ur*hr,2pi*(it+ut)/g.nt,2pi*fixed/g.nz)
            xi_l=(ur,ut,1.0);xi_r=(ur,ut,0.0)
            _,E,rot=_geometry(input,q)
            weight=w[j]*w[k]*hr*(2pi/g.nt)/4*_face_weight(E,3,(1.0,1.0))
            nvec=_normal(E,rot,3)
            fl=_evaluate(g,input,state,left,xi_l,q)
            fr=_evaluate(g,input,state,right,xi_r,q)
            for (cell,xi,f,sign) in ((left,xi_l,fl,1.0),(right,xi_r,fr,-1.0))
                N,_dN=_basis(g,cell,xi);ids=g.element_corners[cell]
                traction=f.stress*nvec;normalB=dot(f.Bxyz,nvec)
                for a in 1:8
                    row=4(ids[a]-1)
                    row_mask !== nothing && !any(@view row_mask[row+1:row+4]) && continue
                    for c in 1:3
                        row_mask !== nothing && !row_mask[row+c] && continue
                        rows[row+c]+=sign*weight*N[a]*traction[c]
                    end
                    (row_mask === nothing || row_mask[row+4]) &&
                        (rows[row+4]+=sign*weight*N[a]*normalB)
                end
            end
        end
    end
    (rows=rows,interface_B_jump=interface_B,interface_traction_jump=interface_Tn,
     interface_normal_B_jump=interface_Bn,interface_action_reaction=interface_action,
     interface_normal_balance=interface_normal_balance)
end

function _boundary_and_flux_rows(g, input, state, order, row_mask=nothing)
    n = 4length(g.node_order)
    outer_nodes = findall(q -> q[1] == 1.0, g.node_order)
    outer_index = Dict(node => j for (j,node) in enumerate(outer_nodes))
    boundary = zeros(4length(outer_nodes))
    volume_load = zeros(n)
    source_integral = zeros(3)
    imposed_integral = zeros(3)
    state_integral = zeros(3)
    imposed_normal_integral = 0.0
    state_normal_integral = 0.0
    normal_max = 0.0
    traction_max = 0.0
    pressure_min = minimum(Float64.(state[4:4:end]))
    x,w = _gauss(order)
    nr = length(g.rhos)-1
    volume_rows = 4length(g.node_order)
    trace_first = volume_rows + 1
    flux_row = trace_first + 4length(outer_nodes)
    for iz in 0:g.nz-1, it in 0:g.nt-1
        cell=_cell_at(g,nr-1,it,iz)
        ids=g.element_corners[cell]
        selected_volume = _selected_volume_cell(row_mask, ids)
        selected_trace = _selected_boundary_trace(row_mask, outer_index, ids,
                                                  g.node_order, trace_first)
        (selected_volume || selected_trace) || continue
        for k in eachindex(x),j in eachindex(x)
            ut=(x[j]+1)/2;uz=(x[k]+1)/2
            xi=(1.0,ut,uz);q=_q_at(g,cell,xi)
            _,E,rot=_geometry(input,q);normal=_normal(E,rot,1)
            weight=w[j]*w[k]*(2pi/g.nt)*(2pi/g.nz)/4 *
                _face_weight(E,1,(1.0,1.0))
            f=_evaluate(g,input,state,cell,xi,q)
            truth=_analytic(input,f.xyz)
            traction_ref=truth.stress*normal
            normal_ref=dot(collect(truth.B),normal)
            traction_state=f.stress*normal
            normal_state=dot(f.Bxyz,normal)
            traction_max=max(traction_max,norm(traction_state-traction_ref))
            normal_max=max(normal_max,abs(normal_state-normal_ref))
            imposed_integral .+= weight .* traction_ref
            state_integral .+= weight .* traction_state
            imposed_normal_integral += weight*normal_ref
            state_normal_integral += weight*normal_state
            N=f.N
            for a in 1:8
                node=ids[a]
                row=4(node-1)
                for c in 1:3
                    row_mask !== nothing && !row_mask[row+c] && continue
                    # The analytic natural traction enters the global weak
                    # volume rows; the state mismatch is retained separately.
                    volume_load[row+c] += weight*N[a]*traction_ref[c]
                end
                (row_mask === nothing || row_mask[row+4]) &&
                    (volume_load[row+4] += weight*N[a]*normal_ref)
                if haskey(outer_index,node)
                    brow=4(outer_index[node]-1)
                    for c in 1:3
                        row_mask !== nothing && !row_mask[trace_first+brow+c-1] && continue
                        boundary[brow+c] += weight*N[a]*(traction_state[c]-traction_ref[c])
                    end
                    (row_mask === nothing || row_mask[trace_first+brow+3]) &&
                        (boundary[brow+4] += weight*N[a]*(normal_state-normal_ref))
                end
            end
        end
    end
    # Independent cut-flux integral over phi=0, using the first toroidal cell
    # trace and physical cross-sectional area dA = |x_rho x x_theta| d rho d theta.
    cut_flux=0.0
    if row_mask === nothing || row_mask[flux_row]
        for ir in 0:nr-1, it in 0:g.nt-1
            cell=_cell_at(g,ir,it,0)
            hr=g.rhos[ir+2]-g.rhos[ir+1];ht=2pi/g.nt
            for k in eachindex(x),j in eachindex(x)
                ur=(x[j]+1)/2;ut=(x[k]+1)/2
                xi=(ur,ut,0.0);q=_q_at(g,cell,xi)
                _,E,rot=_geometry(input,q);normal=_normal(E,rot,3)
                weight=w[j]*w[k]*hr*ht/4*_face_weight(E,3,(1.0,1.0))
                f=_evaluate(g,input,state,cell,xi,q)
                cut_flux += weight*dot(f.Bxyz,normal)
            end
        end
    end
    (boundary_rows=boundary,volume_load=volume_load,outer_nodes=outer_nodes,
     outer_normal_B_Linf=normal_max,outer_traction_Linf=traction_max,
     imposed_traction_integral=imposed_integral,
     state_traction_integral=state_integral,
     imposed_normal_integral=imposed_normal_integral,
     state_normal_integral=state_normal_integral,cut_flux=cut_flux,
     pressure_min=pressure_min)
end

function _row_structure_and_scales(g, input, d; order::Integer=3)
    nnode=length(g.node_order);nr=length(g.rhos)-1
    outer_nodes=findall(q->q[1]==1.0,g.node_order)
    outer_index=Dict(node=>i for (i,node) in enumerate(outer_nodes))
    cut_nodes=findall(q->q[3]==0.0,g.node_order)
    volume_last=4nnode;trace_first=volume_last+1
    trace_last=volume_last+4length(outer_nodes);flux_row=trace_last+1
    blocks=Vector{Symbol}(undef,flux_row);supports=[Int[] for _ in 1:flux_row]
    incident=[Int[] for _ in 1:nnode]
    for (cell,ids) in enumerate(g.element_nodes),node in ids
        push!(incident[node],cell)
    end
    dofs(ids)=sort!(unique!(Int[4(node-1)+component for node in ids for component in 1:4]))
    for node in 1:nnode
        firstrow=4(node-1)+1
        blocks[firstrow:firstrow+3].=(:momentum_N,:momentum_N,:momentum_N,:divB_Wb)
        support=sort!(unique!(reduce(vcat,(dofs(g.element_nodes[cell]) for cell in incident[node]);init=Int[])))
        for row in firstrow:firstrow+3;supports[row]=copy(support);end
    end
    trace_supports=[Int[] for _ in outer_nodes]
    for iz in 0:g.nz-1,it in 0:g.nt-1
        cell=_cell_at(g,nr-1,it,iz)
        trace=filter(node->g.node_order[node][1]==1.0,g.element_nodes[cell])
        local_support=dofs(trace)
        for node in trace;append!(trace_supports[outer_index[node]],local_support);end
    end
    for (i,node) in enumerate(outer_nodes)
        firstrow=trace_first+4(i-1)
        blocks[firstrow:firstrow+3].=(:traction_N,:traction_N,:traction_N,:normal_B_Wb)
        support=sort!(unique!(trace_supports[i]))
        for row in firstrow:firstrow+3;supports[row]=copy(support);end
    end
    blocks[flux_row]=:total_flux_Wb
    supports[flux_row]=Int[4(node-1)+component for node in cut_nodes for component in 1:3]

    volume_lump=zeros(nnode);trace_lump=zeros(length(outer_nodes))
    x,w=_gauss(order)
    for (cell,(ir,_it,_iz)) in enumerate(g.cell_keys)
        hr=g.rhos[ir+2]-g.rhos[ir+1];ht=2pi/g.nt;hz=2pi/g.nz
        ids=g.element_corners[cell]
        for k in eachindex(x),j in eachindex(x),i in eachindex(x)
            xi=((x[i]+1)/2,(x[j]+1)/2,(x[k]+1)/2)
            q=_q_at(g,cell,xi);N,_dN=_basis(g,cell,xi)
            _,E,_=_geometry(input,q)
            weight=w[i]*w[j]*w[k]*hr*ht*hz/8*abs(det(E))
            for a in 1:8;volume_lump[ids[a]]+=weight*N[a];end
        end
    end
    for iz in 0:g.nz-1,it in 0:g.nt-1
        cell=_cell_at(g,nr-1,it,iz);ids=g.element_corners[cell]
        for k in eachindex(x),j in eachindex(x)
            ut=(x[j]+1)/2;uz=(x[k]+1)/2
            xi=(1.0,ut,uz);q=_q_at(g,cell,xi);N,_dN=_basis(g,cell,xi)
            _,E,_=_geometry(input,q)
            weight=w[j]*w[k]*(2pi/g.nt)*(2pi/g.nz)/4*_face_weight(E,1,(1.0,1.0))
            for a in 1:8
                node=ids[a]
                g.node_order[node][1]==1.0 || continue
                trace_lump[outer_index[node]]+=weight*N[a]
            end
        end
    end
    stress_scale=d.scaling.B_T^2/Float64(input.fields.mu0_N_A2)+d.scaling.p_Pa
    row_scales=zeros(flux_row)
    for node in 1:nnode
        area=volume_lump[node]^(2/3);firstrow=4(node-1)+1
        row_scales[firstrow:firstrow+2].=stress_scale*area
        row_scales[firstrow+3]=d.scaling.B_T*area
    end
    for i in eachindex(outer_nodes)
        measure=trace_lump[i];firstrow=trace_first+4(i-1)
        row_scales[firstrow:firstrow+2].=stress_scale*measure
        row_scales[firstrow+3]=d.scaling.B_T*measure
    end
    row_scales[flux_row]=d.flux.nominal_Wb
    layout=(volume_rows=(first=1,last=volume_last,
             per_node=(:momentum_x,:momentum_y,:momentum_z,:divB)),
        boundary_trace_rows=(first=trace_first,last=trace_last,
             per_node=(:traction_x,:traction_y,:traction_z,:normal_B),
             projection=:Q1_face_mass_projection),
        total_flux_row=flux_row,total_rows=flux_row,
        outer_nodes=Tuple(outer_nodes),
        outer_node_rows=Tuple((node=node,first=trace_first+4(i-1),
            last=trace_first+4i-1) for (i,node) in enumerate(outer_nodes)),
        cut_nodes=Tuple(cut_nodes))
    (row_layout=layout,row_blocks=Tuple(blocks),row_supports=Tuple(Tuple(s) for s in supports),
     row_scales=row_scales,volume_lump=volume_lump,trace_lump=trace_lump)
end

function assemble(input, g::Grid, state::AbstractVector{<:Real}; order::Integer=3,
                  scaling=(B_T=5.0,p_Pa=1.0e5), residual_only::Bool=false,
                  row_mask=nothing)
    if row_mask !== nothing
        residual_only || throw(ArgumentError("oracle row_mask requires residual_only=true"))
        row_mask isa AbstractVector{Bool} ||
            throw(ArgumentError("oracle row_mask must be a Boolean vector"))
        nnode=length(g.node_order)
        nouter=count(q -> q[1] == 1.0, g.node_order)
        length(row_mask) == 4nnode+4nouter+1 ||
            throw(ArgumentError("oracle row_mask length mismatch"))
        any(row_mask) || throw(ArgumentError("oracle row_mask must select at least one row"))
    end
    volume=_volume_weak_rows(g,input,state,order,row_mask)
    interior=_add_interior_faces!(volume.rows,g,input,state,order,row_mask)
    boundary=_boundary_and_flux_rows(g,input,state,order,row_mask)
    volume.rows .+= boundary.volume_load
    flux_residual = row_mask === nothing || row_mask[end] ?
        boundary.cut_flux-Float64(input.flux.nominal_Wb) : 0.0
    rows=vcat(volume.rows, boundary.boundary_rows,
              [flux_residual])
    residual_only && return rows
    structure=_row_structure_and_scales(g,input,
        (scaling=scaling,flux=(nominal_Wb=input.flux.nominal_Wb,));order)
    nnode=length(g.node_order);volume_last=4nnode
    momentum_sum=ntuple(k->sum(rows[4(node-1)+k] for node in 1:nnode),3)
    div_sum=sum(rows[4node] for node in 1:nnode)
    source=volume.source_integral
    prescribed=boundary.imposed_traction_integral
    interface_action=interior.interface_action_reaction
    expected_momentum=prescribed-source+interface_action
    momentum_defect=collect(momentum_sum)-expected_momentum
    div_defect=div_sum-boundary.imposed_normal_integral-interior.interface_normal_balance
    interface_checks=(B_jump_peak_T=interior.interface_B_jump,
        traction_jump_peak_Pa=interior.interface_traction_jump,
        normal_B_jump_peak_T=interior.interface_normal_B_jump,
        action_reaction_integral_N=Tuple(interface_action))
    boundary_momentum_rows=Int[structure.row_layout.boundary_trace_rows.first+4(i-1)+k
        for i in eachindex(structure.row_layout.outer_nodes) for k in 0:2]
    boundary_normal_rows=Int[structure.row_layout.boundary_trace_rows.first+4(i-1)+3
        for i in eachindex(structure.row_layout.outer_nodes)]
    boundary_checks=(traction_projection_residual_N=Tuple(rows[boundary_momentum_rows]),
        normal_B_projection_residual_Wb=Tuple(rows[boundary_normal_rows]),
        pointwise_traction_mismatch_peak_Pa=boundary.outer_traction_Linf,
        pointwise_normal_B_mismatch_peak_T=boundary.outer_normal_B_Linf,
        prescribed_traction_integral_N=Tuple(prescribed),
        prescribed_normal_B_integral_Wb=boundary.imposed_normal_integral)
    conservation_checks=(source_integral_N=Tuple(source),
        prescribed_boundary_traction_integral_N=Tuple(prescribed),
        assembled_constant_momentum_test_N=Tuple(momentum_sum),
        global_momentum_balance_defect_N=Tuple(momentum_defect),
        assembled_constant_divergence_test_Wb=div_sum,
        prescribed_boundary_normal_integral_Wb=boundary.imposed_normal_integral,
        interface_normal_balance_Wb=interior.interface_normal_balance,
        global_divergence_balance_defect_Wb=div_defect,
        cut_flux_Wb=boundary.cut_flux,prescribed_flux_Wb=input.flux.nominal_Wb,
        cut_flux_defect_Wb=boundary.cut_flux-input.flux.nominal_Wb,
        flux_constraint_residual_Wb=rows[end])
    checks=(volume=volume.volume,source_integral=volume.source_integral,
        divB_L2=volume.divB_L2,interface_B_jump=interior.interface_B_jump,
        interface_traction_jump=interior.interface_traction_jump,
        interface_normal_B_jump=interior.interface_normal_B_jump,
        interface_action_reaction=interior.interface_action_reaction,
        imposed_traction_integral=boundary.imposed_traction_integral,
        state_traction_integral=boundary.state_traction_integral,
        imposed_normal_integral=boundary.imposed_normal_integral,
        state_normal_integral=boundary.state_normal_integral,
        outer_normal_B_Linf=boundary.outer_normal_B_Linf,
        outer_traction_Linf=boundary.outer_traction_Linf,
        cut_flux=boundary.cut_flux,pressure_min=boundary.pressure_min)
    (schema="independent-global-shared-q1-oracle-v1",residual=rows,
     row_scales=structure.row_scales,row_blocks=structure.row_blocks,
     row_supports=structure.row_supports,row_layout=structure.row_layout,
     node_order=Tuple(g.node_order),element_nodes=Tuple(Tuple(ids) for ids in g.element_nodes),
     interface_checks=interface_checks,boundary_checks=boundary_checks,
     conservation_checks=conservation_checks,checks=checks,grid=g)
end

function _fd_column_rows(row_supports, ncolumns::Int)
    all(support -> !isempty(support), row_supports) ||
        throw(ArgumentError("oracle FD row support must be nonempty"))
    column_rows = [Int[] for _ in 1:ncolumns]
    for (row, support) in enumerate(row_supports), column in support
        1 <= column <= ncolumns || throw(ArgumentError("oracle FD support column is out of range"))
        push!(column_rows[column], row)
    end
    all(support -> !isempty(support), column_rows) ||
        throw(ArgumentError("oracle FD column support must be nonempty"))
    column_rows
end

function _fd_structural_colors(column_rows)
    ncolumns = length(column_rows)
    order = sortperm(1:ncolumns; by=column -> (-length(column_rows[column]), column))
    color_rows = BitSet[]
    color_columns = Vector{Int}[]
    colors = zeros(Int, ncolumns)
    for column in order
        rows = column_rows[column]
        color = findfirst(used -> all(row -> !(row in used), rows), color_rows)
        if color === nothing
            push!(color_rows, BitSet(rows))
            push!(color_columns, Int[column])
            colors[column] = length(color_rows)
        else
            union!(color_rows[color], rows)
            push!(color_columns[color], column)
            colors[column] = color
        end
    end
    # Keep the proof obligation explicit: a row can depend on at most one
    # perturbed column in each simultaneous plus/minus evaluation.
    for columns in color_columns
        for a in eachindex(columns), b in (a+1):length(columns)
            isempty(intersect(column_rows[columns[a]], column_rows[columns[b]])) ||
                error("oracle FD structural coloring has overlapping row support")
        end
    end
    (columns=color_columns, colors=colors)
end

function finite_difference_jacobian(input, g::Grid, state; order::Integer=3,
                                    row_masked::Bool=true, column_scales=nothing)
    baseline=Float64.(state)
    if column_scales!==nothing
        column_scales isa AbstractVector{<:Real} && length(column_scales)==length(baseline) ||
            throw(ArgumentError("oracle FD column scales must match the state columns"))
        all(value->isfinite(value) && value>0.0,column_scales) ||
            throw(ArgumentError("oracle FD column scales must be positive and finite"))
    end
    reference=assemble(input,g,baseline;order)
    m=length(reference.residual)
    J=zeros(m,length(baseline))
    scale=sqrt(eps(Float64))
    column_rows=_fd_column_rows(reference.row_supports,length(baseline))
    coloring=_fd_structural_colors(column_rows)
    steps=Vector{Float64}(undef,length(baseline))
    for j in eachindex(baseline)
        steps[j]=column_scales===nothing ? scale*max(1.0,abs(baseline[j])) :
            scale*max(1.0,Float64(column_scales[j]),abs(baseline[j]))
    end
    for columns in coloring.columns
        plus=copy(baseline);minus=copy(baseline)
        for j in columns
            plus[j]+=steps[j]
            minus[j]-=steps[j]
        end
        selected_rows = if row_masked
            mask = falses(m)
            for j in columns, row in column_rows[j]
                mask[row] = true
            end
            mask
        else
            nothing
        end
        plus_rows=assemble(input,g,plus;order,residual_only=true,row_mask=selected_rows)
        minus_rows=assemble(input,g,minus;order,residual_only=true,row_mask=selected_rows)
        for j in columns, row in column_rows[j]
            J[row,j]=(plus_rows[row]-minus_rows[row])/(2steps[j])
        end
    end
    J
end

function physical_checks(input,g::Grid,state;order::Integer=3)
    x,w=_gauss(order)
    volume=0.0;source_integral=zeros(3);strong_integral=zeros(3)
    source_correction=zeros(3)
    defect_sq=0.0;defect_peak=0.0;div_sq=0.0;div_peak=0.0
    for (cell,(ir,_it,_iz)) in enumerate(g.cell_keys)
        hr=g.rhos[ir+2]-g.rhos[ir+1];ht=2pi/g.nt;hz=2pi/g.nz
        for k in eachindex(x),j in eachindex(x),i in eachindex(x)
            xi=((x[i]+1)/2,(x[j]+1)/2,(x[k]+1)/2);q=_q_at(g,cell,xi)
            _,E,_=_geometry(input,q)
            weight=w[i]*w[j]*w[k]*hr*ht*hz/8*abs(det(E))
            f=_evaluate(g,input,state,cell,xi,q);truth=_analytic(input,f.xyz)
            current=Float64[(f.gradB_xyz[3,2]-f.gradB_xyz[2,3]),
                     (f.gradB_xyz[1,3]-f.gradB_xyz[3,1]),
                     (f.gradB_xyz[2,1]-f.gradB_xyz[1,2])]./Float64(input.fields.mu0_N_A2)
            divstress=cross(collect(current),collect(f.Bxyz))-f.gradp_xyz+
                collect(f.Bxyz).*(f.divB/Float64(input.fields.mu0_N_A2))
            defect=divstress-collect(truth.source)
            _neumaier_add3!(source_integral,source_correction,weight.*truth.source)
            strong_integral .+= weight.*divstress
            defect_sq+=weight*dot(defect,defect);defect_peak=max(defect_peak,norm(defect))
            div_sq+=weight*f.divB^2;div_peak=max(div_peak,abs(f.divB));volume+=weight
        end
    end
    source_integral .+= source_correction
    assembled=assemble(input,g,state;order)
    c=assembled.checks
    (volume_m3=volume,source_integral_N=Tuple(source_integral),
     strong_momentum_integral_N=Tuple(strong_integral),
     integrated_momentum_balance_N=Tuple(strong_integral-source_integral),
     strong_momentum_defect_L2=sqrt(defect_sq),
     strong_momentum_defect_peak_N_m3=defect_peak,
     divB_RMS_T=sqrt(div_sq/volume),divB_peak_T=div_peak,
     interface_B_jump_peak_T=c.interface_B_jump,
     interface_traction_jump_peak_Pa=c.interface_traction_jump,
     interface_normal_B_jump_peak_T=c.interface_normal_B_jump,
     interface_action_reaction_integral_N=Tuple(c.interface_action_reaction),
     outer_traction_mismatch_peak_Pa=c.outer_traction_Linf,
     outer_normal_B_mismatch_peak_T=c.outer_normal_B_Linf,
     outer_traction_mismatch_integral_N=Tuple(c.state_traction_integral-c.imposed_traction_integral),
     outer_normal_B_mismatch_integral_Wb=c.state_normal_integral-c.imposed_normal_integral,
     toroidal_cut_flux_Wb=c.cut_flux,prescribed_flux_Wb=input.flux.nominal_Wb,
     toroidal_flux_defect_Wb=c.cut_flux-input.flux.nominal_Wb,
     authority=:no_publish,physical_validation=:unsupported)
end

function interpolation_errors(input, g::Grid; order::Integer=5)
    state=exact_nodal_state(input,g)
    x,w=_gauss(order)
    volume=0.0;B_error=0.0;B_exact2=0.0;p_error=0.0;p_exact2=0.0
    B_grad_error=0.0;B_grad_exact2=0.0;p_grad_error=0.0;p_grad_exact2=0.0
    pmin=Inf
    gradB_exact=[0.0 -Float64(input.fields.beta_T_m) 0.0;
                 Float64(input.fields.beta_T_m) 0.0 0.0;0.0 0.0 0.0]
    alpha=Float64(input.fields.alpha_Pa_m2);r0=Float64(input.geometry.R0_m)
    for (cell,(ir,it,iz)) in enumerate(g.cell_keys)
        hr=g.rhos[ir+2]-g.rhos[ir+1];ht=2pi/g.nt;hz=2pi/g.nz
        for k in eachindex(x),j in eachindex(x),i in eachindex(x)
            xi=((x[i]+1)/2,(x[j]+1)/2,(x[k]+1)/2)
            q=_q_at(g,cell,xi);_,E,_=_geometry(input,q)
            weight=w[i]*w[j]*w[k]*hr*ht*hz/8*abs(det(E))
            f=_evaluate(g,input,state,cell,xi,q);truth=_analytic(input,f.xyz)
            dB=f.Bxyz-collect(truth.B);dp=f.pressure-truth.p
            R=hypot(f.xyz[1],f.xyz[2]);X,Y,Z=f.xyz
            gradp_exact=(2alpha*(R-r0)*X/R,2alpha*(R-r0)*Y/R,2alpha*Z)
            volume+=weight;B_error+=weight*dot(dB,dB)
            B_exact2+=weight*sum(abs2,truth.B);p_error+=weight*dp^2
            p_exact2+=weight*truth.p^2
            B_grad_error+=weight*sum(abs2,f.gradB_xyz-gradB_exact)
            B_grad_exact2+=weight*sum(abs2,gradB_exact)
            p_grad_error+=weight*sum(abs2,f.gradp_xyz-collect(gradp_exact))
            p_grad_exact2+=weight*sum(abs2,gradp_exact)
            pmin=min(pmin,f.pressure)
        end
    end
    (volume=volume,B_relative_L2=sqrt(B_error/B_exact2),
     pressure_relative_L2=sqrt(p_error/p_exact2),
     B_relative_H1=sqrt(B_grad_error/B_grad_exact2),
     pressure_relative_H1=sqrt(p_grad_error/p_grad_exact2),
     pressure_min=pmin,scope=:exact_Q1_interpolant_diagnostic_only)
end

"""Three-level analytic interpolation/conservation diagnostics; never a solve gate."""
function multilevel_diagnostics(input; scaling=(B_T=5.0,p_Pa=1.0e5),order::Integer=3)
    specs=((level=:q1_2,nr=2,nt=2,nz=2),
           (level=:q1_4,nr=4,nt=4,nz=4),
           (level=:q1_8,nr=8,nt=8,nz=8))
    rows=NamedTuple[]
    for spec in specs
        g=grid(collect(range(0.0,1.0;length=spec.nr+1)),spec.nt,spec.nz)
        state=exact_nodal_state(input,g)
        a=assemble(input,g,state;order,scaling)
        p=physical_checks(input,g,state;order)
        e=interpolation_errors(input,g;order=5)
        momentum_defect=norm(collect(a.conservation_checks.global_momentum_balance_defect_N),Inf)
        divergence_defect=abs(a.conservation_checks.global_divergence_balance_defect_Wb)
        push!(rows,(level=spec.level,nr=spec.nr,nt=spec.nt,nz=spec.nz,
            node_count=length(g.node_order),dof_count=4length(g.node_order),
            row_count=length(a.residual),row_layout=a.row_layout,
            volume_m3=p.volume_m3,source_integral_N=p.source_integral_N,
            global_momentum_balance_defect_N=a.conservation_checks.global_momentum_balance_defect_N,
            global_divergence_balance_defect_Wb=a.conservation_checks.global_divergence_balance_defect_Wb,
            cut_flux_Wb=a.checks.cut_flux,prescribed_flux_Wb=input.flux.nominal_Wb,
            cut_flux_error_Wb=a.checks.cut_flux-input.flux.nominal_Wb,
            interface_action_reaction_N=a.interface_checks.action_reaction_integral_N,
            divB_RMS_T=p.divB_RMS_T,divB_peak_T=p.divB_peak_T,
            pressure_min_Pa=e.pressure_min,B_relative_L2=e.B_relative_L2,
            pressure_relative_L2=e.pressure_relative_L2,
            B_relative_H1=e.B_relative_H1,pressure_relative_H1=e.pressure_relative_H1,
            conservation_scale=max(1.0,norm(collect(a.conservation_checks.assembled_constant_momentum_test_N),Inf),
                norm(collect(a.conservation_checks.prescribed_boundary_traction_integral_N),Inf),
                norm(collect(a.conservation_checks.source_integral_N),Inf)),
            momentum_defect_norm=momentum_defect,divergence_defect=divergence_defect,
            nonlinear_solve=:not_executed,formal_credit=false,physical_validation=:unsupported,
            authority=:no_publish,scope=e.scope))
    end
    (schema="spatial-global-weak-multilevel-diagnostic-v1",levels=Tuple(rows),
     required_formal_levels=(:q1_2,:q1_4,:q1_8),formal_refinement_gate=:outstanding,
     solver_runs=(),claim_ceiling=:diagnostic_only,physical_validation=:unsupported,
     authority=:no_publish)
end

end # module
