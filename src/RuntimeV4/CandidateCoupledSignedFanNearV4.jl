# Canonical near-field signed-fan implementation. Included by CandidateCoupledPhysicsV4.
import LinearAlgebra
import SparseArrays
include("NativeGeometryMapEnclosureV4.jl")

# Topology/geometry helper only. No Serialization, kernel, new runner, or core copy.
# Include into the existing near fixture and pass its already validated payload.
# All exact arithmetic is charged to the caller's ORIGINAL per-ray shared ledger.
Base.@noinline Base.@nospecializeinfer function near_signed_cell_fan_inventory(F,payload; interval_ops=Ref(0),
        max_interval_ops=8_000_000, full_vertex_motion_key=nothing)
    Base.@nospecialize F payload
    payload.schema in (:near_cut_q8_numeric_replay_v1,:near_signed_fan_prepared_numeric_v1) || error("unexpected payload ABI")
    max_interval_ops in (8_000_000,24_000_000) || error("authorized per-ray operation limit required")
    start_ops=interval_ops[]
    charge(n=1)=begin
        0 <= interval_ops[] <= max_interval_ops-n || error("signed-chain operation cap")
        interval_ops[] += n
    end
    rat(x)=begin charge(); isfinite(x) || error("nonfinite geometry"); rationalize(BigInt,x;tol=0) end
    plus(a,b)=(charge(); a+b)
    minus(a,b)=(charge(); a-b)
    times(a,b)=(charge(); a*b)
    cross(a,b)=minus(times(a[1],b[2]),times(a[2],b[1]))
    sub2(a,b)=(minus(a[1],b[1]),minus(a[2],b[2]))
    R2(p)=Tuple(rat(x) for x in p)
    det(P)=cross(sub2(P[2],P[1]),sub2(P[3],P[1]))
    detdot(P,V)=plus(cross(sub2(V[2],V[1]),sub2(P[3],P[1])),
                        cross(sub2(P[2],P[1]),sub2(V[3],V[1])))
    # This is the established dyadic red map, not a floating geometric merge.
    red=(((1,0,0),(1//2,1//2,0),(1//2,0,1//2)),
         ((1//2,1//2,0),(0,1,0),(0,1//2,1//2)),
         ((1//2,0,1//2),(0,1//2,1//2),(0,0,1)),
         ((1//2,1//2,0),(0,1//2,1//2),(1//2,0,1//2)))
    expected_weights=Dict()
    for i in 1:4,j in 1:4
        expected_weights[(i,j)]=ntuple(a->ntuple(b->begin
            s=0//1
            for k in 1:3;s=plus(s,times(red[j][a][k],red[i][k][b]));end
            s
        end,3),3)
    end
    prep=payload.prep
    T=R2(prep.target);Vt=R2(prep.dtarget)
    coverage_ids=hasproperty(payload,:source_coverage_ids) ? payload.source_coverage_ids : Tuple(t.coverage_id for t in payload.production_terms)
    expected_ids=Set(coverage_ids)
    length(expected_ids)==length(coverage_ids) || error("duplicate prepared source leaf")
    consumed_ids=Set();cells=NamedTuple[]
    total_parents=0;total_input_edges=0;total_cancelled=0;total_fans=0
    total_zero_fans=0;total_singular_chords=0
    for cp in prep.quadrature_partition
        cp.near_target || continue
        cell=prep.prepared_cells[cp.cell_index]
        # Edge keys include both endpoint values AND the selected velocity.
        # Optional full motion keys must come from actual sparse geometry-map rows.
        # No tolerance merge; unequal roundings are retained as distinct edges.
        edge_counts=Dict();edge_sources=Dict();vertex_values=Dict()
        parent_sum=0//1;parent_dsum=0//1;parent_count=0
        for pp in cp.pieces
            parents=Dict()
            for tri in pp.triangles
                id=(prep.target_index,cell.native_cell,pp.piece_index,tri.triangle_index,tri.child_path)
                id in expected_ids && !(id in consumed_ids) || error("leaf coverage mismatch")
                push!(consumed_ids,id)
                tri.affine_det_ratio==1/16 || error("not canonical two-level red leaf")
                tri.child_path in keys(expected_weights) || error("unexpected red path")
                tri.affine_vertex_weights==expected_weights[tri.child_path] || error("red affine weights changed")
                charge(84) # both existing 6-coordinate materializations and comparisons
                Base.invokelatest(F._ccp_q1_lcfs_red_leaf_points_match_parent_chart,
                    tri.points,tri.affine_parent_points,tri.affine_vertex_weights) &&
                Base.invokelatest(F._ccp_q1_lcfs_red_leaf_velocities_match_parent_chart,
                    tri.velocities,tri.affine_parent_velocities,tri.affine_vertex_weights) ||
                    error("captured child does not match the existing production affine map")
                entry=get!(parents,tri.triangle_index) do
                    (points=tri.affine_parent_points,velocities=tri.affine_parent_velocities,paths=Set())
                end
                entry.points==tri.affine_parent_points && entry.velocities==tri.affine_parent_velocities ||
                    error("one parent has inconsistent geometry or tangent")
                tri.child_path in entry.paths && error("duplicate red child")
                push!(entry.paths,tri.child_path)
            end
            for (parent_id,p) in parents
                length(p.paths)==16 && p.paths==Set(keys(expected_weights)) || error("incomplete parent cover")
                P=Tuple(R2(x) for x in p.points);V=Tuple(R2(x) for x in p.velocities)
                d=det(P);dd=detdot(P,V)
                d!=0 || error("degenerate original parent")
                sg=sign(d)
                parent_sum=plus(parent_sum,times(sg,d));parent_dsum=plus(parent_dsum,times(sg,dd))
                parent_count+=1
                vkeys=ntuple(i->begin
                    mk=full_vertex_motion_key===nothing ? :captured_direction_only :
                        full_vertex_motion_key(cp.cell_index,pp.piece_index,parent_id,i)
                    key=(P[i],V[i],mk)
                    vertex_values[key]=(point=p.points[i],velocity=p.velocities[i])
                    key
                end,3)
                for (i,j) in ((1,2),(2,3),(3,1))
                    # Orient the original triangles positively; the signed star
                    # determinant subsequently carries each target-fan sign.
                    a,b=sg>0 ? (vkeys[i],vkeys[j]) : (vkeys[j],vkeys[i])
                    rev=(b,a);edge=(a,b)
                    if get(edge_counts,rev,0)>0
                        edge_counts[rev]-=1;total_cancelled+=1
                        pop!(edge_sources[rev])
                    else
                        edge_counts[edge]=get(edge_counts,edge,0)+1
                        get!(edge_sources,edge,Tuple[])
                        push!(edge_sources[edge],(pp.piece_index,parent_id,i,j))
                    end
                    total_input_edges+=1
                end
            end
        end
        # Closure is an exact vector boundary identity, stronger than area alone.
        balance=Dict();fans=NamedTuple[]
        fan_sum=0//1;fan_dsum=0//1
        for ((ka,kb),multiplicity) in edge_counts
            multiplicity==0 && continue
            balance[ka]=get(balance,ka,0)-multiplicity
            balance[kb]=get(balance,kb,0)+multiplicity
            A,Va=ka[1],ka[2];B,Vb=kb[1],kb[2]
            P=(T,A,B);V=(Vt,Va,Vb)
            d=det(P);dd=detdot(P,V)
            fan_sum=plus(fan_sum,times(multiplicity,d))
            fan_dsum=plus(fan_dsum,times(multiplicity,dd))
            # Zero fans are retained: one captured zero tangent is NOT proof
            # of zero motion in all 69,447 columns.
            zero=d==0
            zero && (total_zero_fans+=1)
            chordA=sub2(A,T);chordB=sub2(B,T)
            chorddot=plus(times(chordA[1],chordB[1]),times(chordA[2],chordB[2]))
            singular_chord=zero && chorddot<=0
            singular_chord && (total_singular_chords+=1)
            push!(fans,(edge_points=(vertex_values[ka].point,vertex_values[kb].point),
                edge_velocities=(vertex_values[ka].velocity,vertex_values[kb].velocity),
                target=prep.target,target_velocity=prep.dtarget,
                multiplicity=multiplicity,signed_determinant=d,signed_determinant_direction=dd,
                zero_area=zero,zero_area_with_nonzero_captured_motion=zero && dd!=0,
                chord_contains_target=singular_chord,
                endpoint_motion_keys=(ka[3],kb[3]),source_parent_edges=Tuple(edge_sources[(ka,kb)])))
        end
        all(iszero,values(balance)) || error("remaining oriented boundary is not closed")
        fan_sum==parent_sum && fan_dsum==parent_dsum || error("signed fan area/tangent identity failed")
        slots=Tuple(findall(>(0),cell.columns))
        coefficients=ntuple(i->cell.columns[i]>0 ? prep.current[cell.columns[i]] : 0.0,4)
        dcoefficients=ntuple(i->cell.columns[i]>0 ? prep.dcurrent[cell.columns[i]] : 0.0,4)
        push!(cells,(cell_index=cp.cell_index,native_cell=cell.native_cell,bounds=cell.bounds,
            columns=cell.columns,active_slots=slots,current_coefficients=coefficients,
            current_coefficient_direction=dcoefficients,original_parent_count=parent_count,
            fans=Tuple(fans),twice_area_exact=parent_sum,twice_area_direction_exact=parent_dsum,
            exact_closed_oriented_boundary=true,exact_fan_area_and_captured_tangent=true))
        total_parents+=parent_count;total_fans+=length(fans)
    end
    consumed_ids==expected_ids || error("near source coverage not identical to original producer inventory")
    (status=:evaluated_signed_cell_fan_inventory,scope=:exact_topology_and_captured_direction_only,
     cells=Tuple(cells),original_leaf_count=length(consumed_ids),original_parent_count=total_parents,
     original_parent_edge_count=total_input_edges,cancelled_edge_pairs=total_cancelled,
     target_fan_count=total_fans,zero_area_fan_count=total_zero_fans,
     target_on_chord_fan_count=total_singular_chords,
     exact_arithmetic_operation_increment=interval_ops[]-start_ops,interval_operations=interval_ops[],
     max_interval_operations=max_interval_ops,kernel_calls=0,
     full_geometry_motion_keys_supplied=full_vertex_motion_key!==nothing,
     producer_affine_leaf_materialization_checked=true,
     equality_scope=:underlying_affine_integral_not_Float64_rule_sum,
     full_J_certified=false,integral_enclosure_produced=false,global_closure=false)
end

# Geometry-only reconstruction from the SAME actual 64-vertex LCFS polygon.
# Caller must obtain polygon from the pinned R4 source, not another solver state.
# This calls the existing triangulator/clipper and NEVER evaluates a field or GS.
using LinearAlgebra: dot
Base.@noinline Base.@nospecializeinfer function near_signed_fan_geometry_maps(F,payload,polygon)
    Base.@nospecialize F payload polygon
    prep=payload.prep
    length(polygon)==64 && all(p->length(p)==2 && all(isfinite,p),polygon) || error("actual 64-vertex polygon required")
    polygon[prep.target_index]==prep.target || error("polygon target does not match captured R4 target")
    triangulation=Base.invokelatest(F._ccp_q1_polygon_triangles,polygon)
    triangulation.status===:triangulated || error("actual polygon triangulation failed")
    targetJ=zeros(Float64,2,128)
    targetJ[1,2prep.target_index-1]=1.0;targetJ[2,2prep.target_index]=1.0
    triangle_bounds=Tuple((minimum(polygon[k][1] for k in tri),maximum(polygon[k][1] for k in tri),
        minimum(polygon[k][2] for k in tri),maximum(polygon[k][2] for k in tri)) for tri in triangulation.triangles)
    maps=Dict();parent_points=Dict();origins=Dict();cell_kinds=NamedTuple[]
    for cp in prep.quadrature_partition
        cp.near_target || continue
        cell=prep.prepared_cells[cp.cell_index];bounds=cell.bounds
        corners=((bounds[1],bounds[3]),(bounds[2],bounds[3]),(bounds[2],bounds[4]),(bounds[1],bounds[4]))
        tol=256eps(Float64)*max(1.0,maximum(abs,(prep.target...,bounds...)))
        captured_vertices=Set(v for pp in cp.pieces for tri in pp.triangles for v in tri.affine_parent_points)
        rectangle=length(cp.pieces)==1 && all(v->v==prep.target || v in corners,captured_vertices) &&
            all(v->v in captured_vertices,corners)
        pieces=NamedTuple[]
        if rectangle
            # A complete fixed native rectangle has zero boundary motion. Its
            # exact captured parent charts are checked below; no tolerance fit.
            push!(pieces,(points=corners,vertex_jacobians=ntuple(unused->zeros(2,128),4),
                lineage=ntuple(unused->:fixed_native_grid_corner,4)))
        else
            for (it,tri) in enumerate(triangulation.triangles)
                tb=triangle_bounds[it]
                (tb[2]<=bounds[1] || tb[1]>=bounds[2] || tb[4]<=bounds[3] || tb[3]>=bounds[4]) && continue
                clipped=Base.invokelatest(F._ccp_q1_clip_triangle_geometry,polygon,tri,bounds,64,
                    triangulation.orientation;include_lineage=true)
                clipped.smooth || error("actual reconstructed clip is not smooth")
                length(clipped.points)>=3 || continue
                push!(pieces,(points=clipped.points,vertex_jacobians=clipped.vertex_jacobians,
                    lineage=clipped.lineage.clipped_vertex_lineage))
            end
        end
        length(pieces)==length(cp.pieces) || error("reconstructed source piece count differs from capture")
        for pp in cp.pieces
            piece=pieces[pp.piece_index]
            singular=Base.invokelatest(F._ccp_q1_point_in_convex_polygon,prep.target,piece.points,tol)
            ids=unique(tri.triangle_index for tri in pp.triangles)
            for tid in ids
                P,J,O=if singular
                    edge=tid;next=mod1(edge+1,length(piece.points))
                    ((prep.target,piece.points[edge],piece.points[next]),
                     (targetJ,piece.vertex_jacobians[edge],piece.vertex_jacobians[next]),
                     (:inserted_target_apex,piece.lineage[edge],piece.lineage[next]))
                else
                    k=tid+1
                    ((piece.points[1],piece.points[k],piece.points[k+1]),
                     (piece.vertex_jacobians[1],piece.vertex_jacobians[k],piece.vertex_jacobians[k+1]),
                     (piece.lineage[1],piece.lineage[k],piece.lineage[k+1]))
                end
                captured=first(tri for tri in pp.triangles if tri.triangle_index==tid)
                captured.affine_parent_points==P || error("reconstructed actual affine parent points differ")
                # Production uses dot() (BLAS or generic reduction order), so
                # compare by its own operator when available through LinearAlgebra.
                production_velocity=ntuple(i->(dot(J[i][1,:],payload.coordinate_direction),
                    dot(J[i][2,:],payload.coordinate_direction)),3)
                production_velocity==captured.affine_parent_velocities || error("reconstructed full map misses captured tangent")
                for i in 1:3
                    key=(cp.cell_index,pp.piece_index,tid,i)
                    maps[key]=J[i];parent_points[key]=P[i];origins[key]=O[i]
                end
            end
        end
        push!(cell_kinds,(native_cell=cell.native_cell,kind=rectangle ? :fixed_native_rectangle : :actual_clipped_polygon,
            pieces=length(pieces)))
    end
    (status=:reconstructed_actual_signed_fan_geometry_maps,maps=maps,points=parent_points,origins=origins,
     target_jacobian=targetJ,target_index=prep.target_index,cell_kinds=Tuple(cell_kinds),
     coordinate_columns=128,full_native_chain_required=true,field_calls=0,kernel_calls=0,
     zero_fans_qualified=false,global_closure=false)
end

Base.@noinline Base.@nospecializeinfer function near_signed_fan_motion_key(geometry,cell_index,piece_index,parent_index,vertex_index)
    Base.@nospecialize geometry
    J=geometry.maps[(cell_index,piece_index,parent_index,vertex_index)]
    (Tuple(J[1,:]),Tuple(J[2,:]))
end

# Call this on the inventory REBUILT with full_vertex_motion_key. That rebuild
# verifies cancellation of complete motion rows, not merely a single tangent.
Base.@noinline Base.@nospecializeinfer function near_signed_fan_qualify_zero_aliases(geometry,inventory)
    Base.@nospecialize geometry inventory
    inventory.full_geometry_motion_keys_supplied || error("inventory has not been rebuilt with full geometry rows")
    targetkey=(Tuple(geometry.target_jacobian[1,:]),Tuple(geometry.target_jacobian[2,:]))
    results=NamedTuple[]
    for cell in inventory.cells,(fi,fan) in enumerate(cell.fans)
        fan.zero_area || continue
        aliases=Tuple(i for i in 1:2 if fan.edge_points[i]==fan.target && fan.endpoint_motion_keys[i]==targetkey)
        isempty(aliases) && error("zero fan lacks exact target endpoint/full-row alias")
        witnesses=NamedTuple[]
        for source in fan.source_parent_edges
            pp,tid,i,j=source
            keys=((cell.cell_index,pp,tid,i),(cell.cell_index,pp,tid,j))
            for key in keys
                geometry.points[key]==fan.target || continue
                geometry.maps[key]==geometry.target_jacobian || error("target-coincident source endpoint has a different full map")
                origin=geometry.origins[key]
                origin===:inserted_target_apex || origin==(:lcfs_vertex,geometry.target_index) ||
                    error("full target row equality lacks structural target provenance")
                push!(witnesses,(source_parent_vertex=key,origin=origin))
            end
        end
        isempty(witnesses) && error("zero fan structural witness absent")
        push!(results,(native_cell=cell.native_cell,fan_index=fi,aliased_endpoints=aliases,
            witnesses=Tuple(witnesses),all_128_coordinate_derivatives_zero=true,
            arbitrary_native_coordinate_map_chain_zero=true))
    end
    length(results)==inventory.zero_area_fan_count || error("zero fan coverage differs")
    (status=:qualified_identically_zero_signed_fan_aliases,zero_fan_count=length(results),
     records=Tuple(results),proof=:identical_target_endpoint_value_and_full_row_with_structural_origin,
     kernel_calls=0,field_calls=0,global_closure=false)
end

# Exact radial integration of the small-complement elliptic expansion.
# K means K(m=1-q), E means E(m=1-q), q=r^2*rho/D.
# Returns rigorous PRIMAL intervals for int_0^1 r^p K/sqrt(D) dr and E/sqrt(D).
# Does not evaluate a ring kernel or claim angular/full-J/consumer qualification.
function near_radial_ring_moments(R_input,A_input,B_input; powers=0:4,
        elliptic_order=4,radial_order=12,precision_bits=192,
        interval_ops=Ref(0),max_interval_ops=8_000_000,
        geometry_directions=(),_moment_consumer=nothing,_arithmetic_backend=nothing)
    elliptic_order isa Integer && 1<=elliptic_order<=32 &&
        radial_order isa Integer && 0<=radial_order<=64 || error("invalid integer series orders")
    precision_bits isa Integer && 128<=precision_bits<=1024 || error("invalid interval precision")
    max_interval_ops in (8_000_000,24_000_000) || error("use original 8M or explicitly authorized 24M per-ray cap")
    all(p->p isa Integer && 0<=p<=32,powers) || error("moments require integer powers in 0:32")
    all(d->length(d)==3,geometry_directions) ||
        error("each geometry lane must be a (dR,dA,dB) tuple")
    origin=interval_ops[]
    charge(n=1)=begin
        0<=interval_ops[]<=max_interval_ops-n || error("radial moment operation cap")
        interval_ops[]+=n
    end
    setprecision(BigFloat,precision_bits) do
        down(f)=(charge();setrounding(f,BigFloat,RoundDown))
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        upow(x,n)=begin
            y=BigFloat(1)
            for unused in 1:n;y=up(()->y*x);end
            y
        end
        # Cache actual converted constants within this precision/ledger only.
        # Type is part of the key: an irrational and a rounded literal must not
        # share an entry merely because mixed-type equality rounds them alike.
        exact_cache=Dict{Any,Tuple{BigFloat,BigFloat}}()
        function exact(x)
            get!(exact_cache,(typeof(x),x)) do
                (down(()->BigFloat(x)),up(()->BigFloat(x)))
            end
        end
        backend_mode=Ref(false)
        has_mr(a)=_arithmetic_backend!==nothing && _arithmetic_backend.is_midrad(a)
        use_mr(a,b)=backend_mode[] && (has_mr(a)||has_mr(b))
        toiv(a)=has_mr(a) ? _arithmetic_backend.interval(a) : a
        finite(a)=has_mr(a) ? isfinite(a.midpoint)&&isfinite(a.radius) : isfinite(a[1])&&isfinite(a[2])
        zeroiv(a)=has_mr(a) ? _arithmetic_backend.iszero(a) : iszero(a[1])&&iszero(a[2])
        oneiv(a)=has_mr(a) ? _arithmetic_backend.isone(a) : a[1]==1&&a[2]==1
        asiv(x)=has_mr(x) ? toiv(x) : x isa Tuple ? (x[1] isa BigFloat && x[2] isa BigFloat &&
            precision(x[1])<=precision_bits && precision(x[2])<=precision_bits ? x :
            (down(()->BigFloat(x[1])),up(()->BigFloat(x[2])))) : exact(x)
        add(a,b)=begin
            use_mr(a,b) && return _arithmetic_backend.add(a,b)
            finite(a) && finite(b) || error("nonfinite interval addend")
            zeroiv(a) && return b
            zeroiv(b) && return a
            (down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        end
        sub(a,b)=begin
            use_mr(a,b) && return _arithmetic_backend.sub(a,b)
            finite(a) && finite(b) || error("nonfinite interval subtrahend")
            zeroiv(b) && return a
            zeroiv(a) && return (-b[2],-b[1])
            (down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        end
        neg(a)=has_mr(a) ? _arithmetic_backend.neg(a) : (-a[2],-a[1])
        mul(a,b)=begin
            use_mr(a,b) && return _arithmetic_backend.mul(a,b)
            finite(a) && finite(b) || error("nonfinite interval factor")
            zeroiv(a) && return a
            zeroiv(b) && return b
            oneiv(a) && return b
            oneiv(b) && return a
            if a[1]>=0 && b[1]>=0
                (down(()->a[1]*b[1]),up(()->a[2]*b[2]))
            elseif a[2]<=0 && b[2]<=0
                (down(()->a[2]*b[2]),up(()->a[1]*b[1]))
            elseif a[1]>=0 && b[2]<=0
                (down(()->a[2]*b[1]),up(()->a[1]*b[2]))
            elseif a[2]<=0 && b[1]>=0
                (down(()->a[1]*b[2]),up(()->a[2]*b[1]))
            else
                lo=minimum(down(()->x*y) for x in a for y in b)
                hi=maximum(up(()->x*y) for x in a for y in b)
                (lo,hi)
            end
        end
        inviv(a)=begin
            has_mr(a) && (a=toiv(a))
            finite(a) && a[1]>0 || error("nonfinite or nonpositive denominator")
            oneiv(a) && return a
            (down(()->inv(a[2])),up(()->inv(a[1])))
        end
        diviv(a,b)=begin
            has_mr(a) && (a=toiv(a)); has_mr(b) && (b=toiv(b))
            finite(a) && finite(b) && b[1]>0 || error("invalid interval quotient")
            zeroiv(a) && return a
            oneiv(b) && return a
            mul(a,inviv(b))
        end
        sq(a)=begin
            has_mr(a) && return _arithmetic_backend.mul(a,a)
            # Each executed endpoint product is charged by its directed call.
            finite(a) || error("nonfinite interval square")
            (zeroiv(a) || oneiv(a)) && return a
            if a[1]>=0
                (down(()->a[1]*a[1]),up(()->a[2]*a[2]))
            elseif a[2]<=0
                (down(()->a[2]*a[2]),up(()->a[1]*a[1]))
            else
                (BigFloat(0),max(up(()->a[1]*a[1]),up(()->a[2]*a[2])))
            end
        end
        sqrtiv(a)=begin has_mr(a) && (a=toiv(a)); finite(a) && a[1]>0 || error("nonfinite or nonpositive square root");(down(()->sqrt(a[1])),up(()->sqrt(a[2]))) end
        logiv(a)=begin has_mr(a) && (a=toiv(a)); finite(a) && a[1]>0 || error("nonfinite or nonpositive logarithm");(down(()->log(a[1])),up(()->log(a[2]))) end
        absup(a)=has_mr(a) ? _arithmetic_backend.absupper(a) : max(abs(a[1]),abs(a[2]))
        z=exact(0);one=exact(1);two=exact(2)
        R=asiv(R_input);A=asiv(A_input);B=asiv(B_input)
        all(x->all(isfinite,x) && x[1]<=x[2],(R,A,B)) || error("bad radial geometry intervals")
        R[1]>0 || error("target radius is not positive")
        rho=add(sq(A),sq(B));rho[1]>0 || error("chord separation not proved")
        D0=mul(exact(4),sq(R));b=diviv(A,R);c=diviv(rho,D0)
        pref=inviv(mul(two,R));L0=logiv(diviv(mul(exact(8),R),sqrtiv(rho)))
        dirs=Tuple(begin
            Rd,Ad,Bd=map(asiv,d)
            all(x->all(isfinite,x) && x[1]<=x[2],(Rd,Ad,Bd)) || error("bad primitive direction")
            rhod=mul(two,add(mul(A,Ad),mul(B,Bd)))
            Rrel=diviv(Rd,R)
            bd=sub(diviv(Ad,R),mul(b,Rrel))
            cd=sub(diviv(rhod,D0),mul(two,mul(c,Rrel)))
            Ld=sub(Rrel,diviv(diviv(rhod,rho),two))
            (b=bd,c=cd,L=Ld,pref_relative=neg(Rrel),c_relative=diviv(cd,c),
             R_relative=absup(Rrel),t=add(exact(absup(bd)),exact(absup(cd)))[2])
        end for d in geometry_directions)
        nlane=length(dirs)
        # Preserve the primitive interval jets, but record exact zero structure
        # once so the dual recurrences and sums can avoid zero products in their
        # innermost loops.  In particular, the B direction has b虈=0 and the A/B
        # directions have no prefactor or R-relative derivative.
        sparse_lanes=Tuple((bdot_zero=zeroiv(v.b),
            pref_relative_zero=zeroiv(v.pref_relative),
            R_relative_zero=zeroiv(exact(v.R_relative))) for v in dirs)
        t=up(()->absup(b)+c[2])
        t<1 || error("radial binomial disk not separated from D=0")
        omt=down(()->1-t);Q=up(()->c[2]/omt)
        Q<1 || error("elliptic complement disk not inside unit circle")
        omQ=down(()->1-Q)
        N=elliptic_order;M=radial_order
        ps=Tuple(powers);isempty(ps) && error("empty radial moment request")
        # Preserve historical per-powers enclosures in the default path. The
        # midpoint/radius experiment uses one pmin tail, valid for every p in ps
        # because 0<=r<=1 and every omitted absolute majorant decreases in p.
        tail_ps=_arithmetic_backend===nothing ? ps : (minimum(ps),)
        b_bound=b; c_bound=c
        if _arithmetic_backend!==nothing
            b=_arithmetic_backend.from_interval(b); c=_arithmetic_backend.from_interval(c)
            dirs=Tuple(merge(v,(b=_arithmetic_backend.from_interval(v.b),
                c=_arithmetic_backend.from_interval(v.c))) for v in dirs)
            backend_mode[]=true
        end
        # Integral moments, shared across ALL n,p,K,E. The recurrence integrates
        # delta^m directly: H[m,k]=b*H[m-1,k+1]+c*H[m-1,k+2], likewise L.
        # This avoids forming or repeatedly contracting polynomial coefficients.
        kmax=2N+maximum(ps)
        H=Matrix{Any}(undef,M+1,kmax+2M+1);L=similar(H)
        Hd=[Matrix{Any}(undef,size(H)...) for unused in 1:nlane]
        Ld=[Matrix{Any}(undef,size(H)...) for unused in 1:nlane]
        for k in 0:kmax+2M
            if _arithmetic_backend!==nothing
                # The seed depends only on exact 1/(k+1), precision, and the
                # backend context; reuse its directed MRP enclosure across all
                # quadrature nodes. No geometry or state enters this key.
                H[1,k+1],L[1,k+1]=_arithmetic_backend.radial_seed(precision_bits,k+1,()->begin
                    inverse=inviv(exact(k+1))
                    (_arithmetic_backend.from_interval(inverse),
                     _arithmetic_backend.from_interval(sq(inverse)))
                end)
            else
                inverse=inviv(exact(k+1))
                H[1,k+1]=inverse;L[1,k+1]=sq(inverse)
            end
            for lane in 1:nlane;Hd[lane][1,k+1]=z;Ld[lane][1,k+1]=z;end
        end
        for m in 1:M,k in 0:kmax+2(M-m)
            H[m+1,k+1]=add(mul(b,H[m,k+2]),mul(c,H[m,k+3]))
            L[m+1,k+1]=add(mul(b,L[m,k+2]),mul(c,L[m,k+3]))
            miv=exact(m)
            for lane in 1:nlane
                v=dirs[lane]
                # Polynomial moment identities give the shared partials:
                # dH[m,k]/db=m*H[m-1,k+1], dH[m,k]/dc=m*H[m-1,k+2]
                # (and likewise for L). Chain each primitive lane once here
                # instead of propagating three derivative recurrences through
                # the full H/L tables. All source-basis powers reuse these.
                Hd[lane][m+1,k+1]=mul(miv,add(mul(v.b,H[m,k+2]),mul(v.c,H[m,k+3])))
                Ld[lane][m+1,k+1]=mul(miv,add(mul(v.b,L[m,k+2]),mul(v.c,L[m,k+3])))
            end
        end
        moment_zero_vector()=_arithmetic_backend===nothing ? fill(z,length(ps)) : Any[z for unused in ps]
        K=moment_zero_vector();E=moment_zero_vector()
        Kd=[moment_zero_vector() for unused in 1:nlane];Ed=[moment_zero_vector() for unused in 1:nlane]
        Kerr=fill(BigFloat(0),length(ps));Eerr=fill(BigFloat(0),length(ps))
        Kderr=[fill(BigFloat(0),length(ps)) for unused in 1:nlane]
        Ederr=[fill(BigFloat(0),length(ps)) for unused in 1:nlane]
        tail_acc=_arithmetic_backend===nothing ? nothing : (
            K=Ref(_arithmetic_backend.from_interval((BigFloat(0),BigFloat(0)))),
            E=Ref(_arithmetic_backend.from_interval((BigFloat(0),BigFloat(0)))),
            dK=[_arithmetic_backend.from_interval((BigFloat(0),BigFloat(0))) for unused in 1:nlane],
            dE=[_arithmetic_backend.from_interval((BigFloat(0),BigFloat(0))) for unused in 1:nlane])
        tmr=x->begin
            has_mr(x) && return x
            x isa Tuple && x[1]>=0 || error("negative positive-tail input")
            _arithmetic_backend.from_interval(x)
        end
        tadd=(x,y)->_arithmetic_backend.add(tmr(x),tmr(y))
        tmul=(x,y)->_arithmetic_backend.mul(tmr(x),tmr(y))
        an=one;cn=one;dn=z
        max_beta=BigFloat(0)
        for n in 0:N
            if n>0
                an=mul(an,sq(diviv(exact(2n-1),exact(2n))))
                cn=mul(cn,c)
                # d_n=2(H_(2n)-H_n), hence d_n-d_(n-1)=1/[n(2n-1)].
                dn=add(dn,diviv(one,exact(n*(2n-1))))
            end
            alpha=exact(n+1//2)
            en=n==0 ? z : sub(dn,diviv(one,exact(2n*(2n-1))))
            bn=n==0 ? z : mul(an,diviv(exact(2n),exact(2n-1)))
            kscale=mul(pref,mul(an,cn));escale=mul(pref,mul(bn,cn))
            scale_relatives=Tuple(add(v.pref_relative,mul(exact(n),v.c_relative)) for v in dirs)
            scale_relative_zeros=Tuple(zeroiv(v) for v in scale_relatives)
            scale_absolutes=Tuple(add(exact(v.R_relative),mul(exact(n),exact(absup(v.c_relative)))) for v in dirs)
            h=one;S=z
            for m in 0:M
                kconstant=sub(sub(L0,dn),diviv(S,two))
                econstant=sub(sub(L0,en),diviv(S,two))
                kh=mul(kscale,h);eh=mul(n==0 ? pref : escale,h)
                for (ip,p) in enumerate(ps)
                    hm=H[m+1,p+2n+1];lm=L[m+1,p+2n+1]
                    kbracket=add(mul(kconstant,hm),lm)
                    K[ip]=add(K[ip],mul(kh,kbracket))
                    if n==0
                        E[ip]=add(E[ip],mul(eh,hm))
                    else
                        ebracket=add(mul(econstant,hm),lm)
                        E[ip]=add(E[ip],mul(eh,ebracket))
                    end
                    for lane in 1:nlane
                        v=dirs[lane];dhm=Hd[lane][m+1,p+2n+1];dlm=Ld[lane][m+1,p+2n+1]
                        scale_relative=scale_relatives[lane]
                        dkbracket=add(add(mul(v.L,hm),mul(kconstant,dhm)),dlm)
                        dksum=scale_relative_zeros[lane] ? dkbracket :
                            add(mul(scale_relative,kbracket),dkbracket)
                        Kd[lane][ip]=add(Kd[lane][ip],mul(kh,dksum))
                        if n==0
                            desum=sparse_lanes[lane].pref_relative_zero ? dhm :
                                add(mul(v.pref_relative,hm),dhm)
                            Ed[lane][ip]=add(Ed[lane][ip],mul(eh,desum))
                        else
                            debracket=add(add(mul(v.L,hm),mul(econstant,dhm)),dlm)
                            desum=scale_relative_zeros[lane] ? debracket :
                                add(mul(scale_relative,ebracket),debracket)
                            Ed[lane][ip]=add(Ed[lane][ip],mul(eh,desum))
                        end
                    end
                end
                # End with h_(M+1),S_(M+1), used in the rigorous tail below.
                am=add(alpha,exact(m))
                h=neg(mul(h,diviv(am,exact(m+1))))
                S=add(S,inviv(am))
            end
            # |delta|<=t*r. Consecutive omitted absolute terms have ratio <=beta.
            # Compute the shared directed BigFloat ratio once for both backends,
            # preserving the original interval-operation count.
            ratio=diviv(add(alpha,exact(M+1)),exact(M+2))[2]
            beta=mul(exact(t),exact(max(BigFloat(1),ratio)))[2]
            beta<1 || error("binomial tail ratio does not contract")
            max_beta=max(max_beta,beta);ombeta=down(()->1-beta)
            if _arithmetic_backend===nothing
            tpower=upow(t,M+1)
            base=up(()->absup(h)*tpower)
            Htail=up(()->base/ombeta)
            # S_(M+1+k)<=S_(M+1)+k/(alpha+M+1).
            Stail=mul(exact(base),add(diviv(exact(S[2]),exact(ombeta)),
                diviv(exact(beta),mul(add(alpha,exact(M+1)),sq(exact(ombeta))))))[2]
            # These differentiated geometric-series factors depend on n and
            # the primitive lane, never on the requested radial power p.
            invbeta=inviv(exact(ombeta));invbeta2=sq(invbeta)
            m0=exact(M+1);a0=add(alpha,m0)
            Htail_factor=add(mul(m0,invbeta),mul(exact(beta),invbeta2))
            first=mul(mul(m0,exact(S[2])),invbeta)
            second=mul(add(diviv(m0,a0),exact(S[2])),mul(exact(beta),invbeta2))
            third=diviv(mul(exact(beta),add(one,exact(beta))),
                mul(a0,mul(exact(ombeta),sq(exact(ombeta)))))
            Stail_factor=add(add(first,second),third)
            tail_lanes=Tuple(begin
                base_direction=mul(exact(base),diviv(exact(v.t),exact(t)))
                Htaild=mul(base_direction,Htail_factor)
                Staild=mul(base_direction,Stail_factor)
                (H=Htaild,S=Staild,L=mul(exact(Htail),exact(absup(v.L))))
            end for v in dirs)
            kabs=exact(absup(sub(L0,dn)));eabs=exact(absup(sub(L0,en)))
            kscaleabs=exact(absup(kscale));escaleabs=exact(absup(escale));prefabs=exact(absup(pref))
            for (tail_index,p) in enumerate(tail_ps)
                d=exact(p+2n+M+2);di=inviv(d);di2=sq(di)
                kshape=add(mul(kabs,di),di2);eshape=add(mul(eabs,di),di2);twod=mul(two,d)
                stailpart=diviv(exact(Stail),twod)
                kterm=add(mul(exact(Htail),kshape),stailpart)
                ek=mul(kscaleabs,kterm)[2]
                eterm=add(mul(exact(Htail),eshape),stailpart)
                ee=n==0 ? mul(prefabs,mul(exact(Htail),di))[2] : mul(escaleabs,eterm)[2]
                tail_derivatives=ntuple(lane->begin
                    v=dirs[lane]
                    # Differentiate the omitted series itself, never its sampled bound.
                    Htaild=tail_lanes[lane].H;Staild=tail_lanes[lane].S
                    scalerel=scale_absolutes[lane]
                    lpart=mul(tail_lanes[lane].L,di)
                    staildpart=diviv(Staild,twod)
                    kdpart=add(add(mul(Htaild,kshape),lpart),staildpart)
                    ktaild=add(mul(scalerel,exact(ek)),mul(kscaleabs,kdpart))[2]
                    edpart=add(add(mul(Htaild,eshape),lpart),staildpart)
                    etaild=n==0 ? (sparse_lanes[lane].R_relative_zero ?
                        mul(prefabs,mul(Htaild,di))[2] :
                        add(mul(exact(v.R_relative),exact(ee)),mul(prefabs,mul(Htaild,di)))[2]) :
                        add(mul(scalerel,exact(ee)),mul(escaleabs,edpart))[2]
                    (K=ktaild,E=etaild)
                end,nlane)
                for ip in eachindex(ps)
                    (_arithmetic_backend!==nothing || ip==tail_index) || continue
                    Kerr[ip]=up(()->Kerr[ip]+ek)
                    Eerr[ip]=up(()->Eerr[ip]+ee)
                    for lane in 1:nlane
                        Kderr[lane][ip]=up(()->Kderr[lane][ip]+tail_derivatives[lane].K)
                        Ederr[lane][ip]=up(()->Ederr[lane][ip]+tail_derivatives[lane].E)
                    end
                end
            end
            else
                # Tail majorants are nonnegative sums and products. Evaluate the
                # positive graph with the shared q/W guarded RN backend, leaving
                # every inverse/denominator seed on the directed BigFloat path.
                t_mr=tmr(exact(t));tpower_mr=tmr(one)
                for unused in 1:M+1;tpower_mr=tmul(tpower_mr,t_mr);end
                base_mr=tmul(tmr(exact(absup(h))),tpower_mr)
                invbeta=inviv(exact(ombeta));invbeta2=sq(invbeta)
                Htail_mr=tmul(base_mr,invbeta)
                a0=add(alpha,exact(M+1));omt2=sq(exact(ombeta))
                Stail_mr=tmul(base_mr,tadd(diviv(exact(S[2]),exact(ombeta)),
                    diviv(exact(beta),mul(a0,omt2))))
                m0=exact(M+1)
                Htail_factor_mr=tadd(tmul(m0,invbeta),tmul(exact(beta),invbeta2))
                first_mr=tmul(tmul(m0,exact(S[2])),invbeta)
                second_mr=tmul(tadd(diviv(m0,a0),exact(S[2])),tmul(exact(beta),invbeta2))
                third=diviv(mul(exact(beta),add(one,exact(beta))),
                    mul(a0,mul(exact(ombeta),omt2)))
                Stail_factor_mr=tadd(tadd(first_mr,second_mr),third)
                tail_lanes=Tuple(begin
                    base_direction=tmul(base_mr,diviv(exact(v.t),exact(t)))
                    Htaild=tmul(base_direction,Htail_factor_mr)
                    Staild=tmul(base_direction,Stail_factor_mr)
                    (H=Htaild,S=Staild,L=tmul(Htail_mr,exact(absup(v.L))))
                end for v in dirs)
                kabs=exact(absup(sub(L0,dn)));eabs=exact(absup(sub(L0,en)))
                kscale_abs=exact(absup(kscale));escale_abs=exact(absup(escale));pref_abs=exact(absup(pref))
                kscale_mr=tmr(kscale_abs);escale_mr=n==0 ? tmr(pref_abs) : tmr(escale_abs)
                for (tail_index,p) in enumerate(tail_ps)
                    d=exact(p+2n+M+2);di=inviv(d);di2=sq(di)
                    twod=mul(two,d);twodi=inviv(twod)
                    kshape=tadd(tmul(kabs,di),di2)
                    eshape=tadd(tmul(eabs,di),di2)
                    stailpart=tmul(Stail_mr,twodi)
                    kterm=tadd(tmul(Htail_mr,kshape),stailpart)
                    ek_mr=tmul(kscale_mr,kterm)
                    eterm=tadd(tmul(Htail_mr,eshape),stailpart)
                    ee_mr=n==0 ? tmul(pref_abs,tmul(Htail_mr,di)) : tmul(escale_mr,eterm)
                    tail_derivatives=ntuple(lane->begin
                        v=dirs[lane]
                        Htaild=tail_lanes[lane].H;Staild=tail_lanes[lane].S
                        scalerel=scale_absolutes[lane]
                        lpart=tmul(tail_lanes[lane].L,di)
                        staildpart=tmul(Staild,twodi)
                        kdpart=tadd(tadd(tmul(Htaild,kshape),lpart),staildpart)
                        ktaild=tadd(tmul(scalerel,ek_mr),tmul(kscale_mr,kdpart))
                        edpart=tadd(tadd(tmul(Htaild,eshape),lpart),staildpart)
                        etaild=n==0 ? (sparse_lanes[lane].R_relative_zero ?
                            tmul(pref_abs,tmul(Htaild,di)) :
                            tadd(tmul(exact(v.R_relative),ee_mr),tmul(pref_abs,tmul(Htaild,di)))) :
                            tadd(tmul(scalerel,ee_mr),tmul(escale_mr,edpart))
                        (K=ktaild,E=etaild)
                    end,nlane)
                    tail_acc.K[]=_arithmetic_backend.add(tail_acc.K[],ek_mr)
                    tail_acc.E[]=_arithmetic_backend.add(tail_acc.E[],ee_mr)
                    for lane in 1:nlane
                        tail_acc.dK[lane]=_arithmetic_backend.add(tail_acc.dK[lane],tail_derivatives[lane].K)
                        tail_acc.dE[lane]=_arithmetic_backend.add(tail_acc.dE[lane],tail_derivatives[lane].E)
                    end
                end
            end
        end
        if _arithmetic_backend!==nothing
            Kerr[1]=_arithmetic_backend.absupper(tail_acc.K[])
            Eerr[1]=_arithmetic_backend.absupper(tail_acc.E[])
            for lane in 1:nlane
                Kderr[lane][1]=_arithmetic_backend.absupper(tail_acc.dK[lane])
                Ederr[lane][1]=_arithmetic_backend.absupper(tail_acc.dE[lane])
            end
            fill!(Kerr,Kerr[1]);fill!(Eerr,Eerr[1])
            for lane in 1:nlane
                fill!(Kderr[lane],Kderr[lane][1]);fill!(Ederr[lane],Ederr[lane][1])
            end
        end
        # Observational snapshots only: preserve the two already-computed tail
        # families separately without changing arithmetic, sums, or enclosures.
        binomial_tails=(K=Tuple(Kerr),E=Tuple(Eerr),
            dK=Tuple(Tuple(v) for v in Kderr),dE=Tuple(Tuple(v) for v in Ederr))
        elliptic_K=Vector{BigFloat}(undef,length(ps));elliptic_E=similar(elliptic_K)
        elliptic_dK=[similar(elliptic_K) for unused in 1:nlane]
        elliptic_dE=[similar(elliptic_K) for unused in 1:nlane]
        # Omitted elliptic terms: a_n<=1, b_n<=2, d_n,e_n<2.
        # q<=Q*r虏 and |L-d_n|<=C+|log r| on the complete radial interval.
        C=add(add(exact(absup(L0)),two),diviv(neg(logiv(exact(omt))),two))[2]
        prefmax=inviv(mul(mul(two,exact(R[1])),sqrtiv(exact(omt))))[2]
        S0=diviv(exact(upow(Q,N+1)),exact(omQ))
        S1=mul(exact(upow(Q,N)),add(diviv(exact(N+1),exact(omQ)),diviv(exact(Q),sq(exact(omQ)))))
        qfactor=mul(exact(prefmax),S0)[2]
        elliptic_lanes=Tuple(begin
            Qd=add(diviv(exact(absup(v.c)),exact(omt)),
                diviv(mul(exact(c_bound[2]),exact(v.t)),sq(exact(omt))))
            Prel=add(exact(v.R_relative),diviv(exact(v.t),mul(two,exact(omt))))
            Labs=add(exact(absup(v.L)),diviv(exact(v.t),mul(two,exact(omt))))
            (relative=Prel,logfactor=add(mul(Prel,exact(C)),Labs),Qfactor=mul(Qd,S1))
        end for v in dirs)
        for (tail_index,p) in enumerate(tail_ps)
            di=inviv(exact(p+2N+3));di2=sq(di)
            shape=add(mul(exact(C),di),di2)
            tail=mul(exact(qfactor),shape)[2]
            twice_tail=up(()->2tail)
            elliptic_derivatives=ntuple(lane->begin
                v=elliptic_lanes[lane]
                dpart0=mul(S0,add(mul(v.logfactor,di),mul(v.relative,di2)))
                dpart1=mul(v.Qfactor,shape)
                dtail=mul(exact(prefmax),add(dpart0,dpart1))[2]
                (K=dtail,E=up(()->2dtail))
            end,nlane)
            for ip in eachindex(ps)
                (_arithmetic_backend!==nothing || ip==tail_index) || continue
                (_arithmetic_backend===nothing || ip==1) || continue
                Kerr[ip]=up(()->Kerr[ip]+tail)
                Eerr[ip]=up(()->Eerr[ip]+twice_tail)
                elliptic_K[ip]=tail;elliptic_E[ip]=twice_tail
                for lane in 1:nlane
                    dtail=elliptic_derivatives[lane].K
                    Kderr[lane][ip]=up(()->Kderr[lane][ip]+dtail)
                    Ederr[lane][ip]=up(()->Ederr[lane][ip]+elliptic_derivatives[lane].E)
                    elliptic_dK[lane][ip]=dtail;elliptic_dE[lane][ip]=elliptic_derivatives[lane].E
                end
            end
        end
        if _arithmetic_backend!==nothing
            fill!(Kerr,Kerr[1]);fill!(Eerr,Eerr[1])
            fill!(elliptic_K,elliptic_K[1]);fill!(elliptic_E,elliptic_E[1])
            for lane in 1:nlane
                fill!(Kderr[lane],Kderr[lane][1]);fill!(Ederr[lane],Ederr[lane][1])
                fill!(elliptic_dK[lane],elliptic_dK[lane][1])
                fill!(elliptic_dE[lane],elliptic_dE[lane][1])
            end
        end
        iv=(exact=exact,asiv=asiv,add=add,sub=sub,neg=neg,mul=mul,diviv=diviv,sq=sq,
             sqrtiv=sqrtiv,logiv=logiv,down=down,up=up,absup=absup)
        fast_consumer=_arithmetic_backend!==nothing && _moment_consumer!==nothing
        moment_metadata=(K_tail_upper=Tuple(Kerr),E_tail_upper=Tuple(Eerr),elliptic_order=N,radial_order=M,
         geometry_directions=geometry_directions,dK_tail_upper=Tuple(Tuple(v) for v in Kderr),dE_tail_upper=Tuple(Tuple(v) for v in Ederr),
         binomial_tail_upper=binomial_tails,
         elliptic_tail_upper=(K=Tuple(elliptic_K),E=Tuple(elliptic_E),
            dK=Tuple(Tuple(v) for v in elliptic_dK),dE=Tuple(Tuple(v) for v in elliptic_dE)),
         delta_absolute_slope_upper=t,q_over_r2_upper=Q,max_binomial_tail_ratio=max_beta,
         interval_operation_increment=interval_ops[]-origin,interval_operations=interval_ops[],
         max_interval_operations=max_interval_ops,kernel_calls=0,
         angular_quadrature_certified=false,geometry_derivatives_certified=nlane>0,
         full_J_certified=false,global_closure=false)
        if fast_consumer
            # Keep finite moments, rigorous symmetric tail enclosures, and the
            # active consumer directions in the same backend. Only final outputs
            # are guarded; the attached certificate contains tails and metadata.
            certificate=merge((status=:evaluated_radial_ring_midrad_consumer_certificate,
                powers=ps,moment_intervals_materialized=false,
                proof=:finite_midrad_moments_plus_symmetric_positive_tail_enclosures),moment_metadata)
            tail_radius(e)=_arithmetic_backend.from_interval((-e,e))
            widen_mr(x,e)=_arithmetic_backend.add(x,tail_radius(e))
            consumer_moments=merge(certificate,(
                K_over_sqrtD=Tuple(widen_mr(K[i],Kerr[i]) for i in eachindex(ps)),
                E_over_sqrtD=Tuple(widen_mr(E[i],Eerr[i]) for i in eachindex(ps)),
                dK_over_sqrtD=Tuple(Tuple(widen_mr(Kd[l][i],Kderr[l][i]) for i in eachindex(ps)) for l in 1:nlane),
                dE_over_sqrtD=Tuple(Tuple(widen_mr(Ed[l][i],Ederr[l][i]) for i in eachindex(ps)) for l in 1:nlane)))
            backend_mode[]=true
            consumed=_moment_consumer(consumer_moments,iv)
            as_interval(x)=has_mr(x) ? _arithmetic_backend.interval(x) : x
            mapped_geometry=hasproperty(consumed,:mapped_geometry_derivative_RZ) ?
                (consumed.mapped_geometry_derivative_RZ===:typed_absent_unused_diagnostic ?
                    :typed_absent_unused_diagnostic :
                    Tuple(Tuple(as_interval(x) for x in row) for row in consumed.mapped_geometry_derivative_RZ)) : nothing
            converted=merge(consumed,(
                weighted_field_RZ=Tuple(as_interval(x) for x in consumed.weighted_field_RZ),
                primitive_geometry_derivative_RZ=consumed.primitive_geometry_derivative_RZ===:typed_absent_unused_diagnostic ?
                    :typed_absent_unused_diagnostic :
                    Tuple(Tuple(as_interval(x) for x in row) for row in consumed.primitive_geometry_derivative_RZ),
                source_basis_RZ=Tuple(Tuple(as_interval(x) for x in row) for row in consumed.source_basis_RZ),
                captured_total_direction_RZ=consumed.captured_total_direction_RZ===:typed_absent_unused_diagnostic ?
                    :typed_absent_unused_diagnostic : Tuple(as_interval(x) for x in consumed.captured_total_direction_RZ),
                radial_moment_certificate=certificate,
                interval_operation_increment=consumed.interval_operation_increment+
                    (interval_ops[]-consumed.interval_operations),
                interval_operations=interval_ops[]))
            hasproperty(consumed,:mapped_geometry_derivative_RZ) ?
                merge(converted,(mapped_geometry_derivative_RZ=mapped_geometry,)) : converted
        else
            to_bf_interval(x)=has_mr(x) ? _arithmetic_backend.interval(x) : x
            Kfull=Tuple(begin v=to_bf_interval(K[i]);(down(()->v[1]-Kerr[i]),up(()->v[2]+Kerr[i])) end for i in eachindex(ps))
            Efull=Tuple(begin v=to_bf_interval(E[i]);(down(()->v[1]-Eerr[i]),up(()->v[2]+Eerr[i])) end for i in eachindex(ps))
            Kdfull=Tuple(Tuple(begin v=to_bf_interval(Kd[l][i]);(down(()->v[1]-Kderr[l][i]),up(()->v[2]+Kderr[l][i])) end
                for i in eachindex(ps)) for l in 1:nlane)
            Edfull=Tuple(Tuple(begin v=to_bf_interval(Ed[l][i]);(down(()->v[1]-Ederr[l][i]),up(()->v[2]+Ederr[l][i])) end
                for i in eachindex(ps)) for l in 1:nlane)
            result=merge((status=:evaluated_radial_ring_primal_moments,powers=ps,
                K_over_sqrtD=Kfull,E_over_sqrtD=Efull,dK_over_sqrtD=Kdfull,dE_over_sqrtD=Edfull,
                moment_intervals_materialized=true),moment_metadata,
                (interval_operation_increment=interval_ops[]-origin,interval_operations=interval_ops[]))
            backend_mode[]=false
            _moment_consumer===nothing ? result : _moment_consumer(result,iv)
        end
    end
end
# Integrate the actual weighted-Q1 field on one signed target fan in r.
# Primitive columns are (T_R,T_Z,a_R,a_Z,b_R,b_Z), BEFORE the actual sparse
# endpoint/target geometry-map multiplication. Four source-basis responses share
# the same moment kernel. The remaining u integration is deliberately absent.
Base.@noinline Base.@nospecializeinfer function near_signed_fan_radial_current(cell,fan,mu0,u;
        elliptic_order=2,radial_order=6,precision_bits=192,
        interval_ops=Ref(0),max_interval_ops=8_000_000,_moment_arithmetic_backend=nothing,
        mapped_geometry_rows=nothing,mapped_geometry_lane_ids=(),mapped_geometry_receipt=nothing)
    fan.zero_area && error("zero-area signed fan requires a joint edge limit or full motion-zero proof")
    (u isa Float64 || u isa Integer) && 0<=u<=1 && isfinite(u) || error("angular coordinate must be a binary64 point in [0,1]")
    precision_bits isa Integer && 128<=precision_bits<=1024 || error("invalid interval precision")
    mu0>0 && isfinite(mu0) || error("invalid mu0")
    length(cell.current_coefficients)==4 && length(cell.current_coefficient_direction)==4 ||
        error("four actual Q1 source coefficients required")
    origin=interval_ops[]
    target=fan.target;pa,pb=fan.edge_points
    all(x->(x isa Float64 || x isa Rational{BigInt}) && isfinite(x),(target...,pa...,pb...)) ||
        error("captured binary64 or exact-rational endpoint geometry required")
    mapped_mode=mapped_geometry_rows!==nothing
    if mapped_mode
        length(mapped_geometry_rows)==6 && all(row->length(row)==128,mapped_geometry_rows) ||
            error("six full 128-lane primitive geometry rows required")
        length(mapped_geometry_lane_ids)==128 || error("128 native geometry lane identities required")
        mapped_geometry_receipt!==nothing || error("mapped geometry provenance receipt required")
        all(id->id isa Integer && id>0,mapped_geometry_lane_ids) || error("native geometry lane identity absent")
        length(unique(mapped_geometry_lane_ids))==128 || error("native geometry lane identities are not unique")
    end
    # The primitive inputs are enclosed from the actual endpoint arithmetic,
    # rather than freezing a rounded A or B as the exact geometric difference.
    setprecision(BigFloat,precision_bits) do
        # Reserve all exact binary input conversions and directed construction
        # of A,B. This setup uses no external ring calls.
        interval_ops[]<=max_interval_ops-64 || error("radial fan setup budget")
        interval_ops[]+=64
        down(f)=setrounding(f,BigFloat,RoundDown)
        up(f)=setrounding(f,BigFloat,RoundUp)
        uu=BigFloat(u);ou=1-uu
        lane_iv(x)=begin
            q=_moment_arithmetic_backend!==nothing && _moment_arithmetic_backend.is_midrad(x) ?
                _moment_arithmetic_backend.interval(x) : x
            q isa Tuple ? (down(()->BigFloat(q[1])),up(()->BigFloat(q[2]))) :
                (down(()->BigFloat(q)),up(()->BigFloat(q)))
        end
        lane_zero_raw(x)=x isa Tuple ? iszero(x[1]) && iszero(x[2]) :
            (hasproperty(x,:midpoint) && hasproperty(x,:radius) ? iszero(x.midpoint) && iszero(x.radius) : iszero(x))
        active_mapped=mapped_mode ? Tuple(j for j in 1:128 if any(row->!lane_zero_raw(row[j]),mapped_geometry_rows)) : ()
        nmapped=length(active_mapped)
        if mapped_mode
            # Per retained lane: six row intervals and u/1-u require 16
            # directed endpoint conversions; four subtractions, four interval
            # products (32 endpoint products), and two additions cost 44 more.
            # Round 60 up to 64 so the complete construction is reserved before
            # any proof work begins and cannot cross the per-ray cap mid-lane.
            interval_ops[]<=max_interval_ops-64nmapped || error("mapped geometry lane budget")
            interval_ops[]+=64nmapped
        end
        muliv(a,b)=(minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
        subiv(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        addiv(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        mapped_dirs=mapped_mode ? ntuple(l->begin
            j=active_mapped[l]
            dRt=lane_iv(mapped_geometry_rows[1][j]);dZt=lane_iv(mapped_geometry_rows[2][j])
            vaR=lane_iv(mapped_geometry_rows[3][j]);vaZ=lane_iv(mapped_geometry_rows[4][j])
            vbR=lane_iv(mapped_geometry_rows[5][j]);vbZ=lane_iv(mapped_geometry_rows[6][j])
            oui=lane_iv(ou);ui=lane_iv(uu)
            dA=addiv(muliv(oui,subiv(vaR,dRt)),muliv(ui,subiv(vbR,dRt)))
            dB=addiv(muliv(oui,subiv(vaZ,dZt)),muliv(ui,subiv(vbZ,dZt)))
            (dRt,dA,dB)
        end,nmapped) : ()
        primitive_dirs=((1,-1,0),(0,0,-1),(0,ou,0),(0,0,ou),(0,uu,0),(0,0,uu))
        # The radial moment engine depends on only the three scalar parameters
        # (R,A,B). Compute those signed partials once, then contract each
        # native geometry direction before taking any modulus or tail bound.
        # This preserves lane correlation (including exact common translations)
        # while avoiding a full H/L/K/E derivative recurrence per native lane.
        # Two analytically propagated partials suffice: the R partial is
        # reconstructed from homogeneity after full value/tail enclosure.
        geometry_dirs=((0,1,0),(0,0,1))
        ai=ntuple(k->(down(()->ou*(BigFloat(pa[k])-BigFloat(target[k]))+uu*(BigFloat(pb[k])-BigFloat(target[k]))),
                       up(()->ou*(BigFloat(pa[k])-BigFloat(target[k]))+uu*(BigFloat(pb[k])-BigFloat(target[k])))),2)
        consumer=function(m,iv)
            backend=_moment_arithmetic_backend
            exactpoint(x)=begin
                if backend===nothing
                    iv.asiv(x)
                elseif hasproperty(backend,:exact_float) && (x isa Float64 ||
                        (x isa Integer && -9_007_199_254_740_992<=x<=9_007_199_254_740_992))
                    backend.exact_float(x)
                else
                    backend.from_interval(iv.asiv(x))
                end
            end
            z=exactpoint(0);one=exactpoint(1)
            nlane=mapped_mode ? nmapped : 6
            constd(x)=(exactpoint(x),ntuple(unused->z,nlane))
            function vard(x,primitive_lane,mapped_row)
                exactpoint(x),ntuple(i->mapped_mode ?
                    iv.asiv(mapped_geometry_rows[mapped_row][active_mapped[i]]) :
                    (i==primitive_lane ? one : z),nlane)
            end
            da(a,b)=(iv.add(a[1],b[1]),ntuple(l->iv.add(a[2][l],b[2][l]),nlane))
            ds(a,b)=(iv.sub(a[1],b[1]),ntuple(l->iv.sub(a[2][l],b[2][l]),nlane))
            dm(a,b)=(iv.mul(a[1],b[1]),ntuple(l->iv.add(iv.mul(a[2][l],b[1]),iv.mul(a[1],b[2][l])),nlane))
            di(a)=begin
                inverse=iv.diviv(one,a[1]);inverse2=iv.sq(inverse)
                (inverse,ntuple(l->iv.neg(iv.mul(a[2][l],inverse2)),nlane))
            end
            dd(a,b)=dm(a,di(b))
            R=vard(target[1],1,1);Z=vard(target[2],2,2)
            aR=vard(pa[1],3,3);aZ=vard(pa[2],4,4);bR=vard(pb[1],5,5);bZ=vard(pb[2],6,6)
            U=constd(u);OU=ds(constd(1),U)
            A=da(dm(OU,ds(aR,R)),dm(U,ds(bR,R)))
            B=da(dm(OU,ds(aZ,Z)),dm(U,ds(bZ,Z)))
            rho=da(dm(A,A),dm(B,B))
            rhobf=iv.asiv(rho[1])
            rhobf[1]>0 || error("full angular-point chord separation unresolved")
            det=ds(dm(ds(aR,R),ds(bZ,Z)),dm(ds(aZ,Z),ds(bR,R)))
            detbf=iv.asiv(det[1])
            # This is a signed multiplier, including its complete derivative;
            # neither the radial moments nor their consumer divides by det or
            # selects a branch from its sign.  An outward interval may straddle
            # zero for a thin, nonzero fan without invalidating the integral.
            # Geometric zero aliases and chord/radius singularities have their
            # own checks and are not inferred from this interval.
            all(isfinite,detbf) && detbf[1]<=detbf[2] ||
                error("signed fan determinant interval is not finite and ordered")
            bounds=cell.bounds
            hx=ds(constd(bounds[2]),constd(bounds[1]));hz=ds(constd(bounds[4]),constd(bounds[3]))
            xi0=dd(ds(R,constd(bounds[1])),hx);xi1=dd(A,hx)
            eta0=dd(ds(Z,constd(bounds[3])),hz);eta1=dd(B,hz)
            # Form the weighted bilinear density once. Six geometry jets are
            # unnecessary for the four source basis polynomials, whose only
            # consumer below is the primal source response.
            c1,c2,c3,c4=map(constd,cell.current_coefficients)
            cx=ds(c2,c1);cy=ds(c3,c1);cxy=da(ds(ds(c1,c2),c3),c4)
            density=(da(da(da(c1,dm(cx,xi0)),dm(cy,eta0)),dm(cxy,dm(xi0,eta0))),
                da(dm(da(cx,dm(cxy,eta0)),xi1),dm(da(cy,dm(cxy,xi0)),eta1)),
                dm(cxy,dm(xi1,eta1)))
            pluspoly(p,q)=(iv.mul(p[1],q[1]),iv.add(iv.mul(p[1],q[2]),iv.mul(p[2],q[1])),iv.mul(p[2],q[2]))
            xp=(xi0[1],xi1[1]);yp=(eta0[1],eta1[1])
            ox=(iv.sub(one,xi0[1]),iv.neg(xi1[1]));oy=(iv.sub(one,eta0[1]),iv.neg(eta1[1]))
            phi=(pluspoly(ox,oy),pluspoly(xp,oy),pluspoly(ox,yp),pluspoly(xp,yp))
            m.powers==(0,1,2,3,4) && length(m.geometry_directions)==2 || error("radial moment ABI mismatch")
            # Reconstruct the R partial from full outward value and A/B
            # partial intervals using homogeneity of degree -1 in (R,A,B).
            # The values and both partials already include their omitted-tail
            # radii; interval dependency may widen this enclosure but cannot
            # exclude the exact derivative.
            ouiv=iv.exact(ou);uuiv=iv.exact(uu)
            euler_backend=_moment_arithmetic_backend
            R_interval=iv.asiv(R[1])
            R_interval[1]>0 || error("Euler radial reconstruction requires positive target radius")
            euler_invR_interval=iv.diviv(iv.exact(1),R_interval)
            euler_invR=euler_backend===nothing ? nothing : euler_backend.from_interval(euler_invR_interval)
            function euler_partials(value,da_,db_)
                if euler_backend!==nothing
                    numerator=euler_backend.add(euler_backend.add(value,
                        euler_backend.mul(A[1],da_)),euler_backend.mul(B[1],db_))
                    dR=euler_backend.mul(euler_backend.neg(numerator),euler_invR)
                    return (dR,da_,db_)
                end
                value_iv=iv.asiv(value);da_iv=iv.asiv(da_);db_iv=iv.asiv(db_)
                A_iv=iv.asiv(A[1]);B_iv=iv.asiv(B[1])
                dR=iv.diviv(iv.neg(iv.add(iv.add(value_iv,iv.mul(A_iv,da_iv)),
                    iv.mul(B_iv,db_iv))),R_interval)
                (dR,da_iv,db_iv)
            end
            todual(value,derivs)=mapped_mode ? (value,ntuple(l->begin
                v=z
                for b in 1:3
                    v=iv.add(v,iv.mul(derivs[b],mapped_dirs[l][b]))
                end
                v
            end,nlane)) : begin
                dR,dA,dB=derivs
                (value,(iv.sub(dR,dA),iv.neg(dB),iv.mul(ouiv,dA),iv.mul(ouiv,dB),
                    iv.mul(uuiv,dA),iv.mul(uuiv,dB)))
            end
            KM=ntuple(p->todual(m.K_over_sqrtD[p],euler_partials(m.K_over_sqrtD[p],
                m.dK_over_sqrtD[1][p],m.dK_over_sqrtD[2][p])),5)
            EM=ntuple(p->todual(m.E_over_sqrtD[p],euler_partials(m.E_over_sqrtD[p],
                m.dE_over_sqrtD[1][p],m.dE_over_sqrtD[2][p])),5)
            two=constd(2);R2=dm(R,R);RA=dm(R,A);A2minusB2=ds(dm(A,A),dm(B,B))
            BoverR=dd(B,R);BoverRrho=dd(B,dm(R,rho));rho_inverse=di(rho)
            twoR2=dm(two,R2);twoRA=dm(two,RA)
            brparts=ntuple(p->ds(dm(BoverR,KM[p+2]),
                dm(BoverRrho,da(da(dm(twoR2,EM[p]),dm(twoRA,EM[p+1])),dm(rho,EM[p+2])))),3)
            bzparts=ntuple(p->da(KM[p+1],dm(da(dm(twoRA,EM[p]),dm(A2minusB2,EM[p+1])),rho_inverse)),3)
            scale=dm(constd(iv.diviv(iv.exact(mu0),iv.mul(iv.exact(2),iv.exact(pi)))),
                dm(constd(fan.multiplicity),det))
            field=ntuple(component->begin
                parts=component==1 ? brparts : bzparts
                value=constd(0)
                for p in 1:3;value=da(value,dm(density[p],parts[p]));end
                dm(scale,value)
            end,2)
            source=ntuple(k->ntuple(component->begin
                parts=component==1 ? brparts : bzparts
                v=z
                for p in 1:3;v=iv.add(v,iv.mul(phi[k][p],parts[p][1]));end
                iv.mul(scale[1],v)
            end,2),4)
            velocities=(fan.target_velocity...,fan.edge_velocities[1]...,fan.edge_velocities[2]...)
            captured=ntuple(component->begin
                v=z
                if !mapped_mode
                    for l in 1:6;v=iv.add(v,iv.mul(field[component][2][l],iv.exact(velocities[l])));end
                end
                for k in 1:4;v=iv.add(v,iv.mul(source[k][component],iv.exact(cell.current_coefficient_direction[k])));end
                v
            end,2)
            euler_receipt=(schema=:radial_moment_euler_R_reconstruction_v1,
                status=:evaluated_full_tail_enclosed_R_partial,
                identity=:R_dR_plus_A_dA_plus_B_dB_equals_minus_m,
                used_full_widened_value=true,used_full_widened_A_B_partials=true,
                R_interval=R_interval,positive_R_proved=true,
                inverse_R_interval=euler_invR_interval,
                inverse_R_backend=euler_backend===nothing ? :bigfloat_interval : :shared_midrad_interval,
                inverse_R_shared_across_K_E_moments=10,
                reconstructed_R_partials=10,global_closure=false)
            (status=:evaluated_signed_fan_radial_current,
             weighted_field_RZ=Tuple(v[1] for v in field),
             primitive_geometry_derivative_RZ=mapped_mode ? :typed_absent_unused_diagnostic :
                ntuple(l->ntuple(k->field[k][2][l],2),6),
             primitive_order=mapped_mode ? :typed_absent_unused_diagnostic :
                (:target_R,:target_Z,:edge_a_R,:edge_a_Z,:edge_b_R,:edge_b_Z),
             mapped_geometry_derivative_RZ=mapped_mode ?
                ntuple(k->ntuple(l->field[k][2][l],nmapped),2) : :typed_absent_unused_diagnostic,
             mapped_geometry_lane_ids=Tuple(mapped_geometry_lane_ids[j] for j in active_mapped),
             mapped_geometry_lane_slots=active_mapped,mapped_geometry_receipt=mapped_geometry_receipt,
             mapped_geometry_mapping_receipt=mapped_geometry_receipt,
             source_basis_RZ=source,source_columns=cell.columns,
             captured_total_direction_RZ=mapped_mode ? :typed_absent_unused_diagnostic : captured,
             euler_reconstruction_receipt=euler_receipt,
             radial_moment_certificate=m,angular_coordinate=u,
             interval_operation_increment=interval_ops[]-origin,interval_operations=interval_ops[],
             max_interval_operations=max_interval_ops,kernel_calls=0,
             angular_quadrature_certified=false,full_native_J_assembled=false,global_closure=false)
        end
        near_radial_ring_moments(target[1],ai[1],ai[2];powers=0:4,
            elliptic_order=elliptic_order,radial_order=radial_order,precision_bits=precision_bits,
            interval_ops=interval_ops,max_interval_ops=max_interval_ops,
            geometry_directions=geometry_dirs,_moment_consumer=consumer,
            _arithmetic_backend=_moment_arithmetic_backend)
    end
end

# Branch-safe complex Cauchy majorant for the RADIALLY INTEGRATED signed fan.
# It integrates the logarithmic r endpoint analytically in the majorant.
# No annulus sup, pointwise r=0 evaluation, ring call, or quadrature comparison.
Base.@noinline Base.@nospecializeinfer function near_signed_fan_angular_bound(cell,fan,mu0,ubox;
        disk_fraction=0.8,precision_bits=192,interval_ops=Ref(0),max_interval_ops=8_000_000,
        q1_invariant_cache=nothing,q1_cache_stats=nothing,mapped_geometry_rows=nothing,
        mapped_geometry_lane_ids=(),mapped_geometry_receipt=nothing,common_z_geometry_hull=nothing,
        epsilon_cauchy_radius=nothing,source_only_certificate=false)
    Base.@nospecialize cell fan ubox interval_ops q1_invariant_cache q1_cache_stats mapped_geometry_rows
    Base.@nospecialize mapped_geometry_lane_ids mapped_geometry_receipt common_z_geometry_hull
    fan.zero_area && error("qualify zero fan alias before omitting it")
    0<=ubox[1]<ubox[2]<=1 && all(isfinite,ubox) || error("invalid angular panel")
    0<disk_fraction<1 && isfinite(disk_fraction) || error("invalid root disk fraction")
    precision_bits isa Integer && 128<=precision_bits<=1024 || error("invalid precision")
    max_interval_ops in (8_000_000,24_000_000) || error("use original 8M or explicitly authorized 24M per-ray cap")
    origin=interval_ops[]
    charge()=begin interval_ops[]<max_interval_ops || error("angular proof operation cap");interval_ops[]+=1;end
    setprecision(BigFloat,precision_bits) do
        down(f)=(charge();setrounding(f,BigFloat,RoundDown))
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        exact(x)=x isa Tuple && length(x)==2 ?
            (down(()->BigFloat(x[1])),up(()->BigFloat(x[2]))) :
            (down(()->BigFloat(x)),up(()->BigFloat(x)))
        add(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        sub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        mul(a,b)=(minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
        diviv(a,b)=begin b[1]>0 || error("positive denominator absent");mul(a,(down(()->1/b[2]),up(()->1/b[1]))) end
        sq(a)=begin
            if a[1]>=0
                (down(()->a[1]*a[1]),up(()->a[2]*a[2]))
            elseif a[2]<=0
                (down(()->a[2]*a[2]),up(()->a[1]*a[1]))
            else
                (BigFloat(0),max(up(()->a[1]*a[1]),up(()->a[2]*a[2])))
            end
        end
        sqrtiv(a)=begin a[1]>0 || error("positive root absent");(down(()->sqrt(a[1])),up(()->sqrt(a[2]))) end
        logiv(a)=begin a[1]>0 || error("positive logarithm absent");(down(()->log(a[1])),up(()->log(a[2]))) end
        absiv(a)=max(abs(a[1]),abs(a[2]))
        pu(a,b)=up(()->a+b);mu(a,b)=up(()->a*b);du(a,b)=up(()->a/b)
        powu(a,n)=begin v=BigFloat(1);for k in 1:n;v=mu(v,a);end;v end
        z=BigFloat(0);one=BigFloat(1);nlane=6
        T=fan.target;pa,pb=fan.edge_points
        all(x->(x isa Float64 || x isa Rational{BigInt}) && isfinite(x),(T...,pa...,pb...)) ||
            error("captured binary64 or exact-rational geometry required")
        clip_hull=common_z_geometry_hull
        include_unit_geometry_directions=true
        if clip_hull!==nothing
            uniform_native=hasproperty(clip_hull,:native_direction_domain) &&
                clip_hull.native_direction_domain===:uniform_all_native_columns
            include_unit_geometry_directions=(uniform_native &&
                hasproperty(clip_hull,:include_unit_geometry_directions)) ?
                    clip_hull.include_unit_geometry_directions : true
            include_unit_geometry_directions isa Bool || error("common-z unit-geometry direction flag must be Bool")
            direction_domain_ok=uniform_native ? clip_hull.n_native_dof==69447 &&
                clip_hull.common_parameter===:one_shared_complex_z_and_epsilon_for_all_69447_native_directions &&
                hasproperty(clip_hull,:direction_normalization_scale) && clip_hull.direction_normalization_scale>0 :
                clip_hull.common_parameter===:one_shared_complex_z_for_target_endpoints_and_selected_native_dof_lanes &&
                !isempty(clip_hull.selected_native_dof_ids)
            clip_hull.schema===:x3cb_signedfan_common_z_geometry_hull_v1 &&
                clip_hull.status===:evaluated_exact_shared_z_geometry_hull &&
                direction_domain_ok &&
                clip_hull.geometry_cauchy_radius>1 && clip_hull.epsilon_cauchy_radius>0 &&
                clip_hull.normalized_epsilon_hull.source_direction_supplied===true ||
                    error("verified coupled common-z/epsilon signed-fan hull required")
            epsilon_cauchy_radius===nothing || BigFloat(epsilon_cauchy_radius)==BigFloat(clip_hull.epsilon_cauchy_radius) ||
                error("explicit epsilon Cauchy radius differs from the bound hull")
        end
        target_R=exact(T[1]);target_Z=exact(T[2])
        if clip_hull!==nothing
            TRradius=BigFloat(clip_hull.target_delta_radius.R)
            TZradius=BigFloat(clip_hull.target_delta_radius.Z)
            re=BigFloat(clip_hull.epsilon_cauchy_radius)
            eps_target=clip_hull.normalized_epsilon_hull.target
            TRradius=up(()->TRradius+re*BigFloat(eps_target.R))
            TZradius=up(()->TZradius+re*BigFloat(eps_target.Z))
            target_R=(down(()->target_R[1]-TRradius),up(()->target_R[2]+TRradius))
            target_Z=(down(()->target_Z[1]-TZradius),up(()->target_Z[2]+TZradius))
            mapped_geometry_rows===nothing || error("common-z primal mode uses selected epsilon directions from its bound hull")
        end
        R=target_R;R[1]>0 || error("positive target R absent throughout common-z hull")
        Alo=sub(exact(pa[1]),R);Blo=sub(exact(pa[2]),target_Z)
        Dela=sub(exact(pb[1]),exact(pa[1]));Delb=sub(exact(pb[2]),exact(pa[2]))
        ulo=exact(ubox[1]);uhi=exact(ubox[2]);width=sub(uhi,ulo)
        mid=diviv(add(ulo,uhi),exact(2));half=diviv(width,exact(2))
        nominal_rho=if clip_hull===nothing
            nothing
        else
            nominal_Ac=add(sub(exact(pa[1]),exact(T[1])),mul(mid,sub(exact(pb[1]),exact(pa[1]))))
            nominal_Bc=add(sub(exact(pa[2]),exact(T[2])),mul(mid,sub(exact(pb[2]),exact(pa[2]))))
            add(sq(nominal_Ac),sq(nominal_Bc))
        end
        Ac=add(Alo,mul(mid,Dela));Bc=add(Blo,mul(mid,Delb))
        rho0=add(sq(Ac),sq(Bc));L2=add(sq(Dela),sq(Delb))
        center_delta=BigFloat(0);slope_delta=BigFloat(0);ac_delta=BigFloat(0);bc_delta=BigFloat(0)
        if clip_hull===nothing
            droot=diviv(sqrtiv(rho0),sqrtiv(L2))
        else
            hr=BigFloat(clip_hull.geometry_cauchy_radius)
            ac_delta=BigFloat(clip_hull.relative_chord_center_delta_modulus.A)
            bc_delta=BigFloat(clip_hull.relative_chord_center_delta_modulus.B)
            da_delta=BigFloat(clip_hull.relative_chord_delta_coefficients.deltaA)
            db_delta=BigFloat(clip_hull.relative_chord_delta_coefficients.deltaB)
            epsc=clip_hull.normalized_epsilon_hull.chord.center
            epss=clip_hull.normalized_epsilon_hull.chord.slope
            re=BigFloat(clip_hull.epsilon_cauchy_radius)
            center_delta=up(()->hr*sqrt(ac_delta^2+bc_delta^2)+re*sqrt(BigFloat(epsc.A)^2+BigFloat(epsc.B)^2))
            slope_delta=up(()->hr*sqrt(da_delta^2+db_delta^2)+re*sqrt(BigFloat(epss.A)^2+BigFloat(epss.B)^2))
            rootlo=max(BigFloat(0),down(()->sqrt(max(BigFloat(0),rho0[1]))-center_delta))
            roothi=up(()->sqrt(rho0[2])+center_delta)
            Lhi=up(()->sqrt(L2[2])+slope_delta)
            Llo=max(BigFloat(0),down(()->sqrt(max(BigFloat(0),L2[1]))-slope_delta))
            rootlo>0 && Lhi>0 && Llo>0 || return (status=:typed_absent,reason=:common_z_root_or_chord_margin_unresolved,
                interval_operations=interval_ops[],interval_operation_increment=interval_ops[]-origin,
                kernel_calls=0,global_closure=false)
            droot=(down(()->rootlo/Lhi),up(()->roothi/Llo))
        end
        disk=mul(exact(disk_fraction),exact(droot[1]))[1]
        cauchy_radius=sub(exact(disk),exact(half[2]))[1]
        cauchy_radius>0 || return (status=:typed_absent,reason=:angular_panel_wider_than_root_disk,
            interval_operations=interval_ops[],interval_operation_increment=interval_ops[]-origin,
            kernel_calls=0,global_closure=false)
        theta=du(disk,droot[1]);theta<1 || error("root disk touches a branch point")
        omt=down(()->1-theta);opt=pu(1,theta)
        rho_lower=mul(exact(rho0[1]),sq(exact(omt)))[1]
        rho_upper=mul(exact(rho0[2]),sq(exact(opt)))[2]
        Aabs=pu(absiv(Ac),mu(disk,absiv(Dela)))
        Babs=pu(absiv(Bc),mu(disk,absiv(Delb)))
        if clip_hull!==nothing
            hr=BigFloat(clip_hull.geometry_cauchy_radius)
            panel_r=BigFloat(clip_hull.relative_chord_delta_coefficients.panel_radius)
            epsc=clip_hull.normalized_epsilon_hull.chord.center
            epss=clip_hull.normalized_epsilon_hull.chord.slope
            re=BigFloat(clip_hull.epsilon_cauchy_radius)
            Aabs=pu(Aabs,up(()->hr*(ac_delta+(panel_r+disk)*abs(da_delta))+re*(BigFloat(epsc.A)+
                (panel_r+disk)*BigFloat(epss.A))))
            Babs=pu(Babs,up(()->hr*(bc_delta+(panel_r+disk)*abs(db_delta))+re*(BigFloat(epsc.B)+
                (panel_r+disk)*BigFloat(epss.B))))
            # Preserve downward rounding through the final square as well as
            # the square-root subtraction; the lower modulus is consumed by
            # the radial and elliptic denominator guards below.
            rho_radius_lower=max(BigFloat(0),down(()->sqrt(rho_lower)-center_delta-disk*slope_delta))
            rho_lower=down(()->rho_radius_lower*rho_radius_lower)
            rho_upper=up(()->Aabs^2+Babs^2)
        end
        uabs=pu(absiv(mid),disk);ouabs=pu(absiv(sub(exact(1),mid)),disk)
        Ad=(one,z,ouabs,z,uabs,z);Bd=(z,one,z,ouabs,z,uabs);Rd=(one,z,z,z,z,z)
        mapped_mode=mapped_geometry_rows!==nothing
        mapped_mode && (length(mapped_geometry_rows)==6 && all(row->length(row)==128,mapped_geometry_rows) &&
            length(mapped_geometry_lane_ids)==128 && mapped_geometry_receipt!==nothing ||
            error("joint angular proof needs six pinned 128-lane rows and receipt"))
        lane_zero(x)=x isa Tuple ? iszero(x[1]) && iszero(x[2]) : iszero(x)
        active_mapped=mapped_mode ? Tuple(j for j in 1:128 if any(row->!lane_zero(row[j]),mapped_geometry_rows)) : ()
        mapped_dirs=mapped_mode ? ntuple(l->begin
            j=active_mapped[l]
            dR=exact(mapped_geometry_rows[1][j]);dZ=exact(mapped_geometry_rows[2][j])
            daR=sub(exact(mapped_geometry_rows[3][j]),dR);daZ=sub(exact(mapped_geometry_rows[4][j]),dZ)
            dbR=sub(exact(mapped_geometry_rows[5][j]),dR);dbZ=sub(exact(mapped_geometry_rows[6][j]),dZ)
            da_center=add(mul(sub(exact(1),mid),daR),mul(mid,dbR))
            db_center=add(mul(sub(exact(1),mid),daZ),mul(mid,dbZ))
            da=pu(absiv(da_center),mu(disk,absiv(sub(dbR,daR))))
            db=pu(absiv(db_center),mu(disk,absiv(sub(dbZ,daZ))))
            Ax0=sub(exact(pa[1]),R);Ay0=sub(exact(pa[2]),target_Z)
            Bx0=sub(exact(pb[1]),R);By0=sub(exact(pb[2]),target_Z)
            dAx=sub(exact(mapped_geometry_rows[3][j]),dR);dAy=sub(exact(mapped_geometry_rows[4][j]),dZ)
            dBx=sub(exact(mapped_geometry_rows[5][j]),dR);dBy=sub(exact(mapped_geometry_rows[6][j]),dZ)
            ddet=add(sub(add(mul(dAx,By0),mul(Ax0,dBy)),mul(dAy,Bx0)),mul(Ay0,dBx))
            (absiv(dR),absiv(dZ),da,db,absiv(ddet))
        end,length(active_mapped)) : ()
        # A source-only certificate retains the same analytic radial and Q1
        # source basis proof, but deliberately constructs no primitive/native
        # geometry derivative lanes.  This is used when a separate correlated
        # A-minus-production-J certificate owns the G/J term.
        source_only_certificate isa Bool || error("source-only certificate flag must be Bool")
        nlane=source_only_certificate ? 0 :
            clip_hull!==nothing ? 0 : mapped_mode ? length(active_mapped) : 6
        Rd=mapped_mode ? ntuple(l->mapped_dirs[l][1],nlane) : Rd
        Ad=mapped_mode ? ntuple(l->mapped_dirs[l][3],nlane) : Ad
        Bd=mapped_mode ? ntuple(l->mapped_dirs[l][4],nlane) : Bd
        detd=mapped_mode ? ntuple(l->mapped_dirs[l][5],nlane) :
            (absiv(sub(exact(pa[2]),exact(pb[2]))),absiv(sub(exact(pb[1]),exact(pa[1]))),
             absiv(sub(exact(pb[2]),exact(T[2]))),absiv(sub(exact(pb[1]),exact(T[1]))),
             absiv(sub(exact(pa[2]),exact(T[2]))),absiv(sub(exact(pa[1]),exact(T[1]))))
        rhod=ntuple(l->mu(2,pu(mu(Aabs,Ad[l]),mu(Babs,Bd[l]))),nlane)
        Rlo=R[1];Rhi=R[2]
        R2lower=down(()->Rlo*Rlo);D0lower=down(()->4R2lower)
        cabs=du(rho_upper,D0lower);babs=du(Aabs,Rlo);t=pu(babs,cabs)
        t<1 || return (status=:typed_absent,reason=:complex_radial_denominator_disk_unresolved,
            interval_operations=interval_ops[],interval_operation_increment=interval_ops[]-origin,
            kernel_calls=0,global_closure=false)
        delta_margin=down(()->1-t);Q=du(cabs,delta_margin)
        Q<1 || error("complex elliptic complement disk not inside unit disk")
        qmargin=down(()->1-Q)
        if clip_hull===nothing
            # At fixed real geometry the two rho roots are conjugates.
            Lcenter=logiv(diviv(mul(exact(8),R),sqrtiv(rho0)))
            L0max=pu(absiv(Lcenter),-down(()->log(omt)))
        else
            # On the common-z complex geometry disk, do not assume conjugate
            # rho roots. Bound each analytic logarithm by its unit-disk
            # perturbation from the real base-center value.
            base_R=BigFloat(T[1]);base_rho=nominal_rho[1]
            base_R>0 && base_rho>0 || return (status=:typed_absent,reason=:common_z_log_base_unresolved,
                interval_operations=interval_ops[],interval_operation_increment=interval_ops[]-origin,
                kernel_calls=0,global_closure=false)
            etaR=up(()->TRradius/base_R)
            etaW=up(()->(disk*sqrt(L2[2])+center_delta+disk*slope_delta)/sqrt(base_rho))
            etaR<1 && etaW<1 || return (status=:typed_absent,reason=:common_z_log_unit_disk_unresolved,
                eta_R=etaR,eta_W=etaW,interval_operations=interval_ops[],
                interval_operation_increment=interval_ops[]-origin,kernel_calls=0,global_closure=false)
            base_log=absiv(logiv(diviv(mul(exact(8),exact(base_R)),sqrtiv(nominal_rho))))
            L0max=up(()->base_log-log1p(-etaR)-log1p(-etaW))
        end
        C=pu(pu(L0max,2),du(-down(()->log(delta_margin)),2))
        rootdelta=sqrtiv(exact(delta_margin))[1]
        twiceRlo=down(()->2Rlo)
        prefmax=du(1,down(()->twiceRlo*rootdelta))
        prel=BigFloat[];labs=BigFloat[];qd=BigFloat[]
        for l in 1:nlane
            Rrel=du(Rd[l],Rlo)
            bd=pu(du(Ad[l],Rlo),mu(babs,Rrel))
            cd=pu(du(rhod[l],D0lower),mu(2,mu(cabs,Rrel)))
            td=pu(bd,cd)
            halfd=du(td,down(()->2delta_margin))
            push!(prel,pu(Rrel,halfd))
            push!(labs,pu(pu(Rrel,du(rhod[l],down(()->2rho_lower))),halfd))
            push!(qd,pu(du(cd,delta_margin),du(mu(cabs,td),down(()->delta_margin^2))))
        end
        # Bound objects carry modulus upper/lower and only the active
        # derivative-modulus directions. Only R and rho are inverted.
        constant(v)=(v=absiv(exact(v)),lo=BigFloat(0),d=ntuple(l->z,nlane))
        obj(v,lo,d)=(v=v,lo=lo,d=d)
        plus(a,b)=obj(pu(a.v,b.v),z,ntuple(l->pu(a.d[l],b.d[l]),nlane))
        times(a,b)=obj(mu(a.v,b.v),down(()->a.lo*b.lo),
            ntuple(l->pu(mu(a.d[l],b.v),mu(a.v,b.d[l])),nlane))
        inverse(a)=begin
            a.lo>0 || error("complex inverse lacks lower modulus")
            den=down(()->a.lo*a.lo)
            obj(du(1,a.lo),down(()->1/a.v),ntuple(l->du(a.d[l],den),nlane))
        end
        divide(a,b)=times(a,inverse(b))
        ro=obj(Rhi,Rlo,Rd);ao=obj(Aabs,z,Ad);bo=obj(Babs,z,Bd);rho=obj(rho_upper,rho_lower,rhod)
        KM=NamedTuple[];EM=NamedTuple[]
        for p in 0:4
            d=BigFloat(p+1);d3=BigFloat(p+3)
            d2=BigFloat((p+1)^2);d32=BigFloat((p+3)^2)
            kshape=pu(du(C,d),du(1,d2))
            eshape=pu(du(C,d3),du(1,d32))
            kval=mu(du(prefmax,qmargin),kshape)
            eval=pu(du(prefmax,d),mu(du(mu(2,mu(prefmax,Q)),qmargin),eshape))
            # These p-dependent coefficients are common to every native
            # geometry lane. Precompute them once, but retain each lane's
            # signed-chain-derived positive prel/labs/qd inputs and the same
            # complex-disk sup through Q/qmargin. This shares the complex
            # derivative majorant work without combining unrelated lane bounds.
            kpre=mu(prefmax,du(pu(du(C,d),du(1,d2)),qmargin))
            klab=mu(prefmax,du(du(1,d),qmargin))
            kqd=mu(prefmax,du(eshape,down(()->qmargin*qmargin)))
            epre=pu(du(prefmax,d),mu(mu(2,prefmax),
                mu(du(Q,qmargin),pu(du(C,d3),du(1,d32)))))
            elab=mu(mu(2,prefmax),mu(du(Q,qmargin),du(1,d3)))
            eqd=mu(mu(2,prefmax),du(eshape,down(()->qmargin*qmargin)))
            kd=ntuple(l->begin
                pu(pu(mu(kpre,prel[l]),mu(klab,labs[l])),mu(kqd,qd[l]))
            end,nlane)
            ed=ntuple(l->begin
                pu(pu(mu(epre,prel[l]),mu(elab,labs[l])),mu(eqd,qd[l]))
            end,nlane)
            push!(KM,obj(kval,z,kd));push!(EM,obj(eval,z,ed))
        end
        q1_key=(cell.native_cell,Tuple(cell.bounds),Tuple(cell.columns),
            Tuple(cell.current_coefficients),Tuple(T),Float64(mu0),precision_bits,
            clip_hull===nothing ? :fixed_geometry : clip_hull.schema,
            clip_hull===nothing ? nothing : (clip_hull.selected_native_dof_ids,
                clip_hull.geometry_cauchy_radius,clip_hull.epsilon_cauchy_radius,
                clip_hull.target_delta_radius,clip_hull.relative_chord_delta_radius,
                clip_hull.normalized_epsilon_hull))
        q1data=q1_invariant_cache===nothing ? nothing : get(q1_invariant_cache,q1_key,nothing)
        if q1data===nothing
            q1_start=interval_ops[]
            bounds=cell.bounds
            hx=sub(exact(bounds[2]),exact(bounds[1]));hz=sub(exact(bounds[4]),exact(bounds[3]))
            hx[1]>0 && hz[1]>0 || error("positive native Q1 widths absent")
            xi=diviv(sub(R,exact(bounds[1])),hx);eta=diviv(sub(target_Z,exact(bounds[3])),hz)
            coefficients=(cell.current_coefficients,(1.0,0.0,0.0,0.0),(0.0,1.0,0.0,0.0),
                (0.0,0.0,1.0,0.0),(0.0,0.0,0.0,1.0))
            bases=ntuple(i->begin
                c1,c2,c3,c4=map(exact,coefficients[i])
                cx=sub(c2,c1);cy=sub(c3,c1);cxy=add(sub(sub(c1,c2),c3),c4)
                j0=add(add(add(c1,mul(cx,xi)),mul(cy,eta)),mul(cxy,mul(xi,eta)))
                ja=diviv(add(cx,mul(cxy,eta)),hx);jb=diviv(add(cy,mul(cxy,xi)),hz)
                jab=diviv(cxy,mul(hx,hz))
                if clip_hull===nothing
                    (j0=absiv(j0),ja=absiv(ja),jb=absiv(jb),ab=absiv(jab))
                else
                    if i==1
                        # The helper combines signed vertex directions into
                        # power-basis coefficients lane by lane before taking
                        # moduli, preserving their correlation.
                        s1,sx,sy,sxy=BigFloat.(clip_hull.normalized_epsilon_hull.q1_power_basis_coefficients)
                        xabs=absiv(xi);yabs=absiv(eta)
                        j0eps=up(()->re*(s1+sx*xabs+sy*yabs+sxy*xabs*yabs))
                        jaeps=up(()->re*(sx+sxy*yabs)/hx[1])
                        jbeps=up(()->re*(sy+sxy*xabs)/hz[1])
                        abe=up(()->re*sxy/(hx[1]*hz[1]))
                        (j0=up(()->absiv(j0)+j0eps),ja=up(()->absiv(ja)+jaeps),
                         jb=up(()->absiv(jb)+jbeps),ab=up(()->absiv(jab)+abe))
                    else
                        (j0=absiv(j0),ja=absiv(ja),jb=absiv(jb),ab=absiv(jab))
                    end
                end
            end,5)
            q1data=(hx=hx,hz=hz,xi=xi,eta=eta,bases=bases,operation_count=interval_ops[]-q1_start)
            if q1_invariant_cache!==nothing
                q1_invariant_cache[q1_key]=q1data
            end
            if q1_cache_stats!==nothing
                q1_cache_stats[:misses]+=1
            end
        else
            if q1_cache_stats!==nothing
                q1_cache_stats[:hits]+=1
                q1_cache_stats[:operations_saved]+=q1data.operation_count
            end
        end
        hx=q1data.hx;hz=q1data.hz;xi=q1data.xi;eta=q1data.eta
        function density_objects(base)
            if mapped_mode
                jzero=obj(base.j0,z,ntuple(l->pu(mu(base.ja,mapped_dirs[l][1]),
                    mu(base.jb,mapped_dirs[l][2])),nlane))
                jA=obj(base.ja,z,ntuple(l->mu(base.ab,mapped_dirs[l][2]),nlane))
                jB=obj(base.jb,z,ntuple(l->mu(base.ab,mapped_dirs[l][1]),nlane))
            else
                jzero=obj(base.j0,z,clip_hull===nothing ? (base.ja,base.jb,z,z,z,z) : ntuple(l->z,nlane))
                jA=obj(base.ja,z,clip_hull===nothing ? (z,base.ab,z,z,z,z) : ntuple(l->z,nlane))
                jB=obj(base.jb,z,clip_hull===nothing ? (base.ab,z,z,z,z,z) : ntuple(l->z,nlane))
            end
            jone=plus(times(jA,ao),times(jB,bo))
            jtwo=times(obj(base.ab,z,ntuple(l->z,nlane)),times(ao,bo))
            (jzero,jone,jtwo)
        end
        rhoR=times(ro,rho);two=constant(2);R2=times(ro,ro);RA=times(ro,ao)
        brparts=ntuple(p->plus(times(divide(bo,ro),KM[p+2]),
            times(divide(bo,rhoR),plus(plus(times(times(two,R2),EM[p]),times(times(two,RA),EM[p+1])),times(rho,EM[p+2])))),3)
        bzparts=ntuple(p->plus(KM[p+1],divide(plus(times(times(two,RA),EM[p]),
            times(plus(times(ao,ao),times(bo,bo)),EM[p+1])),rho)),3)
        Ax=sub(exact(pa[1]),R);Ay=sub(exact(pa[2]),target_Z)
        Bx=sub(exact(pb[1]),R);By=sub(exact(pb[2]),target_Z)
        det=sub(mul(Ax,By),mul(Ay,Bx))
        det_abs=absiv(det)
        clip_hull===nothing || (det_abs=pu(det_abs,up(()->clip_hull.determinant_delta_radius+
            clip_hull.normalized_epsilon_hull.determinant_radius)))
        detobj=obj(mu(fan.multiplicity,det_abs),z,ntuple(l->mu(fan.multiplicity,detd[l]),nlane))
        pref=diviv(exact(mu0),mul(exact(2),exact(pi)))[2]
        scale=times(constant(pref),detobj)
        function contract(density)
            ntuple(component->begin
                parts=component==1 ? brparts : bzparts
                value=obj(z,z,ntuple(l->z,nlane))
                for p in 1:3;value=plus(value,times(density[p],parts[p]));end
                times(scale,value)
            end,2)
        end
        weighted=contract(density_objects(q1data.bases[1]))
        source=ntuple(k->contract(density_objects(q1data.bases[k+1])),4)
        # Q8 error: Peano constant times 16! M/radius^16. All factors are positive.
        peano=diviv(exact(factorial(big(8))^4),exact(17*factorial(big(16))^2))[2]
        radpow=BigFloat(1)
        for k in 1:16;radpow=down(()->radpow*cauchy_radius);end
        error_factor=du(mu(peano,powu(width[2],17)),radpow)
        values=Tuple(w.v for w in weighted)
        gradients=ntuple(l->ntuple(k->weighted[k].d[l],2),nlane)
        source_values=ntuple(i->Tuple(w.v for w in source[i]),4)
        clip_delta_certificate=if clip_hull===nothing
            :not_requested
        else
            # Keep the physical field and source-response majorants separate:
            # their units differ, so they cannot share one Cauchy numerator.
            clip_M_weighted=maximum(values)
            clip_M_source=ntuple(i->maximum(source_values[i]),4)
            rz=BigFloat(clip_hull.geometry_cauchy_radius)
            zden=down(()->rz-1)
            zden>0 || error("positive downward geometry Cauchy denominator absent")
            re=BigFloat(clip_hull.epsilon_cauchy_radius)
            gden=down(()->re*zden)
            gden>0 || error("positive downward bidisk Cauchy denominator absent")
            uniform_native=hasproperty(clip_hull,:native_direction_domain) &&
                clip_hull.native_direction_domain===:uniform_all_native_columns
            exact_point_and_J_noop=all(iszero,Iterators.flatten(clip_hull.target_delta_RZ)) &&
                all(iszero,Iterators.flatten(clip_hull.edge_a_delta_RZ)) &&
                all(iszero,Iterators.flatten(clip_hull.edge_b_delta_RZ)) &&
                all(iszero,Iterators.flatten(clip_hull.delta_primitive_geometry_rows))
            bclip=exact_point_and_J_noop ? ntuple(_->BigFloat(0),2) : ntuple(k->up(()->values[k]/zden),2)
            eclip=exact_point_and_J_noop ? ntuple(_->ntuple(_->BigFloat(0),2),4) :
                ntuple(i->ntuple(k->up(()->source_values[i][k]/zden),2),4)
            (schema=:near_signed_fan_common_z_clip_cauchy_v1,
             status=:evaluated_common_z_epsilon_primal_clip_cauchy_majorant,
             scope=:one_whole_radially_integrated_near_signed_fan_angular_panel,
             geometry_cauchy_radius=rz,
             epsilon_cauchy_radius=BigFloat(clip_hull.epsilon_cauchy_radius),
             M_weighted_field_RZ=values,
             M_weighted_field_global=clip_M_weighted,
             M_source_basis_RZ=source_values,
             M_source_basis_global=clip_M_source,
             B_clip_delta_RZ=bclip,
              B_clip_delta_direction_domain=uniform_native ?
                 (include_unit_geometry_directions ? :unit_geometry_and_all_native_state_directions : :all_native_state_directions) :
                 :selected_native_dof_lanes,
             E_clip_delta_RZ=eclip,
              E_clip_delta_direction_domain=uniform_native ?
                 (include_unit_geometry_directions ? :unit_geometry_and_all_native_state_directions : :all_native_state_directions) :
                 :selected_native_dof_lanes,
             G_clip_delta_RZ=exact_point_and_J_noop ?
                ntuple(_->ntuple(_->BigFloat(0),2),length(clip_hull.direction_normalization_scales)) :
                uniform_native ? () : ntuple(l->begin
                    sig=BigFloat(last(clip_hull.direction_normalization_scales[l]))
                    ntuple(k->up(()->sig*values[k]/gden),2)
                end,length(clip_hull.direction_normalization_scales)),
              G_clip_uniform_geometry_RZ=uniform_native && include_unit_geometry_directions ?
                (exact_point_and_J_noop ? ntuple(_->BigFloat(0),2) : ntuple(k->up(()->values[k]/gden),2)) :
                :typed_absent_not_requested,
              G_clip_uniform_geometry_scope=uniform_native && include_unit_geometry_directions ?
                 :unit_polygon_coordinate_directions : :typed_absent_not_requested,
             J_clip_uniform_native_RZ=uniform_native ?
                (exact_point_and_J_noop ? ntuple(_->BigFloat(0),2) :
                    ntuple(k->up(()->BigFloat(clip_hull.direction_normalization_scale)*values[k]/gden),2)) :
                :typed_absent_not_requested,
             J_clip_uniform_native_dof_count=uniform_native ? clip_hull.n_native_dof : 0,
             J_clip_uniform_native_scope=uniform_native ? :all_native_state_dofs_including_zero_C_nonpsi :
                :typed_absent_not_requested,
              include_unit_geometry_directions=uniform_native ? include_unit_geometry_directions : :not_applicable_selected_lane,
              clip_direction_domain=uniform_native ?
                 (include_unit_geometry_directions ? :unit_geometry_and_all_native_state_directions : :all_native_state_directions) :
                 :selected_native_dof_lanes,
              G_native_dof_ids=uniform_native ?
                 (include_unit_geometry_directions ? () : :typed_absent_not_requested) :
                Tuple(clip_hull.selected_native_dof_ids[s.lane] for s in clip_hull.direction_normalization_scales),
              G_native_dof_count=uniform_native ?
                 (include_unit_geometry_directions ? clip_hull.n_native_dof : :typed_absent_not_requested) :
                 length(clip_hull.selected_native_dof_ids),
             common_z_geometry_hull=clip_hull,
             exact_point_and_J_geometry_noop=exact_point_and_J_noop,
             root_radial_and_complex_log_margins_checked=true,
             six_signed_geometry_rows_combined_before_hull=true,
             coupled_complex_variables=(:z,:epsilon,:u),
             G_scope=uniform_native ? (include_unit_geometry_directions ?
                :uniform_polygon_unit_and_full_native_state_directions : :full_native_state_directions_only) :
                :selected_native_directions_only,
             kernel_calls=0,integral_calls=0,whole_continuous_angular_panel=true)
        end
        (status=:evaluated_signed_fan_integrated_angular_cauchy_bound,angular_panel=ubox,
         certificate_scope=source_only_certificate ? :four_Q1_source_basis_only : :weighted_field_and_derivatives,
         disk_radius=disk,cauchy_radius=cauchy_radius,root_disk_fraction_upper=theta,
         rho_modulus_lower=rho_lower,rho_modulus_upper=rho_upper,
         logarithm_branch_proof=clip_hull===nothing ? :conjugate_chord_root_disks_exclude_zero :
            :common_z_unit_disk_perturbation_from_real_base_center,
         radial_delta_upper=t,q_over_r2_upper=Q,
         M_weighted_field_RZ=values,
         M_primitive_geometry_RZ=(source_only_certificate || mapped_mode) ? :typed_absent_unused_diagnostic :
            clip_hull!==nothing ? :typed_absent_not_produced_by_primal_clip_mode : gradients,
         M_mapped_geometry_RZ=source_only_certificate ? :typed_absent_source_only_certificate : mapped_mode ? ntuple(k->ntuple(l->gradients[l][k],nlane),2) :
            clip_hull!==nothing ? :typed_absent_not_produced_by_primal_clip_mode : :typed_absent_unused_diagnostic,
         mapped_geometry_lane_ids=mapped_mode ? Tuple(mapped_geometry_lane_ids[j] for j in active_mapped) : (),
         mapped_geometry_lane_slots=mapped_mode ? active_mapped : (),
         mapped_geometry_receipt=mapped_mode ? mapped_geometry_receipt : nothing,
         M_source_basis_RZ=source_values,
         bivariate_clip_cauchy=clip_delta_certificate,
         Q8_error_weighted_RZ=source_only_certificate ? :typed_absent_source_only_certificate : ntuple(k->mu(error_factor,values[k]),2),
         Q8_error_primitive_geometry_RZ=(source_only_certificate || mapped_mode) ? :typed_absent_unused_diagnostic :
            clip_hull!==nothing ? :typed_absent_not_produced_by_primal_clip_mode :
                ntuple(l->ntuple(k->mu(error_factor,gradients[l][k]),2),6),
         Q8_error_mapped_geometry_RZ=source_only_certificate ? :typed_absent_source_only_certificate : mapped_mode ? ntuple(k->ntuple(l->mu(error_factor,gradients[l][k]),nlane),2) :
            :typed_absent_unused_diagnostic,
         Q8_error_source_basis_RZ=ntuple(i->ntuple(k->mu(error_factor,source_values[i][k]),2),4),
         first_u_derivative_weighted_RZ=ntuple(k->du(values[k],cauchy_radius),2),
         first_u_derivative_primitive_geometry_RZ=(source_only_certificate || mapped_mode) ? :typed_absent_unused_diagnostic :
            clip_hull!==nothing ? :typed_absent_not_produced_by_primal_clip_mode :
                ntuple(l->ntuple(k->du(gradients[l][k],cauchy_radius),2),6),
         first_u_derivative_mapped_geometry_RZ=mapped_mode ? ntuple(k->ntuple(l->du(gradients[l][k],cauchy_radius),nlane),2) :
            :typed_absent_unused_diagnostic,
         first_u_derivative_source_basis_RZ=ntuple(i->ntuple(k->du(source_values[i][k],cauchy_radius),2),4),
         interval_operation_increment=interval_ops[]-origin,interval_operations=interval_ops[],
         max_interval_operations=max_interval_ops,kernel_calls=0,
         stored_rule_drift_included=false,actual_consumer_compared=false,global_closure=false)
    end
end

Base.@noinline Base.@nospecializeinfer function near_signed_fan_panel(cell,fan,mu0,ubox,qualified_rule,stored_nodes,stored_weights;
        elliptic_order=2,radial_order=6,disk_fraction=0.8,precision_bits=192,
        interval_ops=Ref(0),max_interval_ops=8_000_000,precomputed_angular_certificate=nothing,
        _moment_arithmetic_backend=nothing,node_sink=nothing,mapped_geometry_rows=nothing,
        mapped_geometry_lane_ids=(),mapped_geometry_receipt=nothing,angular_geometry_receipt=nothing,
        saved_fixedQ_node_terms=nothing,saved_panel_index=nothing,common_z_geometry_hull=nothing,
        source_only_certificate=false,source_only_fan_key=nothing)
    Base.@nospecialize cell fan qualified_rule stored_nodes stored_weights interval_ops
    Base.@nospecialize precomputed_angular_certificate _moment_arithmetic_backend node_sink
    Base.@nospecialize mapped_geometry_rows mapped_geometry_lane_ids mapped_geometry_receipt angular_geometry_receipt
    Base.@nospecialize saved_fixedQ_node_terms common_z_geometry_hull source_only_fan_key
    max_interval_ops in (8_000_000,24_000_000) || error("panel cap must be original 8M or authorized 24M")
    source_only_certificate && (println("SOURCE_ONLY_STAGE panel_enter cell=",cell.native_cell," fan=",source_only_fan_key," panel=",ubox);flush(stdout))
    qualified_rule.status===:evaluated_true_Gauss_rule_interval && qualified_rule.root_count==8 ||
        error("already qualified true Q8 rule required")
    pairs=qualified_rule.mapped_nodes_and_weights
    length(pairs)==length(stored_nodes)==length(stored_weights)==8 || error("Q8 rule shape mismatch")
    all(p->0<p.node[1]<=p.node[2]<1 && 0<p.weight[1]<=p.weight[2],pairs) || error("invalid true Q8 enclosures")
    all(x->x isa Float64 && isfinite(x),stored_nodes) &&
        all(x->x isa Float64 && isfinite(x) && x>0,stored_weights) || error("stored binary64 Q8 rule required")
    all(x->x isa Float64 && isfinite(x),ubox) || error("binary64 angular panel endpoints required")
    source_only_certificate isa Bool || error("source-only certificate flag must be Bool")
    source_only_certificate && mapped_geometry_rows!==nothing && error("source-only certificate does not consume mapped-G lanes")
    source_only_certificate && source_only_fan_key===nothing && saved_fixedQ_node_terms!==nothing &&
        error("source-only replay requires the pinned native fan key")
    source_only_fan_key===nothing || (source_only_fan_key isa Tuple && length(source_only_fan_key)==2 &&
        isequal(source_only_fan_key[1],cell.native_cell)) || error("source-only fan key differs from the native cell")
    origin=interval_ops[]
    source_only_certificate && (println("SOURCE_ONLY_STAGE angular_begin cell=",cell.native_cell," fan=",source_only_fan_key," panel=",ubox);flush(stdout))
    bound=if precomputed_angular_certificate===nothing
        near_signed_fan_angular_bound(cell,fan,mu0,ubox;disk_fraction=disk_fraction,
            precision_bits=precision_bits,interval_ops=interval_ops,max_interval_ops=max_interval_ops,
            mapped_geometry_rows=mapped_geometry_rows,mapped_geometry_lane_ids=mapped_geometry_lane_ids,
            mapped_geometry_receipt=angular_geometry_receipt===nothing ? mapped_geometry_receipt : angular_geometry_receipt,
            common_z_geometry_hull=common_z_geometry_hull,
            source_only_certificate=source_only_certificate)
    else
        expected=(target=fan.target,edge_points=fan.edge_points,multiplicity=fan.multiplicity,
            bounds=cell.bounds,current_coefficients=cell.current_coefficients,source_columns=cell.columns,
            common_z_geometry_hull=common_z_geometry_hull,
            mu0=mu0,angular_panel=ubox,disk_fraction=disk_fraction,precision_bits=precision_bits)
        precomputed_angular_certificate.binding==expected || error("precomputed angular proof binding differs")
        source_only_certificate &&
            (!hasproperty(precomputed_angular_certificate.proof,:certificate_scope) ||
             precomputed_angular_certificate.proof.certificate_scope!==:four_Q1_source_basis_only) &&
            error("source-only mode cannot reuse a weighted-field/G proof")
        (mapped_geometry_rows===nothing ? precomputed_angular_certificate.proof.mapped_geometry_receipt===nothing :
            precomputed_angular_certificate.proof.mapped_geometry_receipt==
                (angular_geometry_receipt===nothing ? mapped_geometry_receipt : angular_geometry_receipt)) ||
            error("precomputed mapped angular proof receipt differs")
        precomputed_angular_certificate.proof.angular_panel==ubox || error("precomputed proof panel differs")
        precomputed_angular_certificate.proof
    end
    source_only_certificate && (println("SOURCE_ONLY_STAGE angular_done cell=",cell.native_cell," fan=",source_only_fan_key," panel=",ubox," intervalops=",interval_ops[]-origin);flush(stdout))
    bound.status===:evaluated_signed_fan_integrated_angular_cauchy_bound || return bound
    charge(n=1)=begin interval_ops[]<=max_interval_ops-n || error("panel operation cap");interval_ops[]+=n;end
    setprecision(BigFloat,precision_bits) do
        down(f)=(charge();setrounding(f,BigFloat,RoundDown))
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        exact(x)=(down(()->BigFloat(x)),up(()->BigFloat(x)))
        add(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        sub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        mul(a,b)=(minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
        widen(a,e)=(down(()->a[1]-e),up(()->a[2]+e))
        absup(a)=max(abs(a[1]),abs(a[2]))
        z=exact(0);width=sub(exact(ubox[2]),exact(ubox[1]))
        mapped_mode=mapped_geometry_rows!==nothing
        mapped_lanes=mapped_mode ? length(bound.mapped_geometry_lane_ids) : 0
        saved_nodes=saved_fixedQ_node_terms===nothing ? nothing : Tuple(saved_fixedQ_node_terms)
        if saved_nodes!==nothing
            source_only_certificate || mapped_mode || error("saved fixed-Q replay requires mapped geometry unless source-only mode is explicit")
            length(saved_nodes)==8 || error("saved fixed-Q replay requires exactly eight nodes for this selected panel")
            saved_panel_index===nothing || (saved_panel_index isa Integer && saved_panel_index>0) ||
                error("invalid expected saved panel index")
            expected_map_receipt=angular_geometry_receipt===nothing ? mapped_geometry_receipt : angular_geometry_receipt
            finite_interval(x)=x isa Tuple && length(x)==2 &&
                all(y->y isa Real && isfinite(y),x) && x[1]<=x[2]
            if !source_only_certificate
            expected_map_receipt isa NamedTuple && hasproperty(expected_map_receipt,:fan_key) ||
                error("saved fixed-Q replay requires a state-bound fan map receipt")
            expected_map_receipt.schema===:same_call_mapped_primitive_geometry_rows_v1 &&
                expected_map_receipt.state_coordinate_id isa Symbol &&
                expected_map_receipt.state_input_sha256 isa AbstractString &&
                length(expected_map_receipt.state_input_sha256)==64 &&
                expected_map_receipt.target_index isa Integer && expected_map_receipt.target_index>0 &&
                Tuple(expected_map_receipt.polygon_lane_ids)==Tuple(1:128) &&
                length(expected_map_receipt.geometry_map_size)==2 && expected_map_receipt.geometry_map_size[1]==128 &&
                expected_map_receipt.geometry_map_size[2]==length(expected_map_receipt.state_columns) &&
                expected_map_receipt.geometry_map_identity.shape==expected_map_receipt.geometry_map_size ||
                error("saved fixed-Q replay map receipt schema/shape is not qualified")
            receipt_keys=(:schema,:state_coordinate_id,:state_input_sha256,:geometry_map_identity,
                :fan_key,:target_index,:polygon_lane_ids,:state_columns,:geometry_map_size)
            receipt_matches(a,b)=a isa NamedTuple && b isa NamedTuple &&
                all(k->hasproperty(a,k) && hasproperty(b,k) && isequal(getproperty(a,k),getproperty(b,k)),receipt_keys)
            expected_lanes=Tuple(bound.mapped_geometry_lane_ids)
            all(1<=lane<=128 for lane in expected_lanes) && length(unique(expected_lanes))==length(expected_lanes) ||
                error("mapped angular proof has invalid active lanes")
            all(j->j in expected_lanes || all(row->iszero(row[j]),mapped_geometry_rows),1:128) ||
                error("mapped angular proof lane support omits a nonzero native geometry row")
            end
            observed_panel_index=nothing
            for i in 1:8
                record=saved_nodes[i]
                hasproperty(record,:radial_result) && hasproperty(record,:fixed_u) &&
                    hasproperty(record,:weight) && hasproperty(record,:panel_width) &&
                    hasproperty(record,:angular_panel) && hasproperty(record,:node_index) &&
                    hasproperty(record,:fan_key) && hasproperty(record,:panel_index) ||
                    error("saved fixed-Q node record is incomplete")
                if source_only_certificate
                    hasproperty(record,:fan_key) && record.fan_key==source_only_fan_key ||
                        error("saved fixed-Q source-only node fan identity differs")
                else
                    record.fan_key!=expected_map_receipt.fan_key &&
                        error("saved fixed-Q node fan identity differs from mapped receipt")
                end
                pi=record.panel_index
                pi isa Integer && pi>0 || error("saved fixed-Q panel index is invalid")
                observed_panel_index===nothing ? (observed_panel_index=pi) : (pi==observed_panel_index ||
                    error("saved fixed-Q node panel indexes disagree"))
                saved_panel_index===nothing || pi==saved_panel_index ||
                    error("saved fixed-Q panel index differs from selected plan")
                record.node_index==i && record.angular_panel==ubox ||
                    error("saved fixed-Q node/panel coordinates differ from selected panel")
                radial=record.radial_result
                radial.status===:evaluated_signed_fan_radial_current && radial.angular_coordinate==record.fixed_u &&
                    record.fixed_u==ubox[1]+(ubox[2]-ubox[1])*stored_nodes[i] && radial.kernel_calls==0 &&
                    radial.source_columns==cell.columns && length(radial.weighted_field_RZ)==2 &&
                    all(finite_interval,radial.weighted_field_RZ) && length(radial.source_basis_RZ)==4 &&
                    all(row->length(row)==2 && all(finite_interval,row),radial.source_basis_RZ) &&
                    radial.interval_operation_increment isa Integer && radial.interval_operation_increment>=0 &&
                    hasproperty(radial,:radial_moment_certificate) &&
                    hasproperty(radial.radial_moment_certificate,:K_tail_upper) &&
                    hasproperty(radial.radial_moment_certificate,:E_tail_upper) ||
                    error("saved fixed-Q radial identity/shape differs")
                expected_weight=BigFloat(stored_weights[i]);w=record.weight
                w isa Tuple && length(w)==2 && all(x->x isa Real && isfinite(x),w) && w[1]<=w[2] &&
                    BigFloat(w[1])<=expected_weight<=BigFloat(w[2]) ||
                    error("saved fixed-Q node weight does not enclose the selected rule weight")
                width_record=record.panel_width;exact_width=BigFloat(ubox[2])-BigFloat(ubox[1])
                width_record isa Tuple && length(width_record)==2 &&
                    all(x->x isa Real && isfinite(x),width_record) && width_record[1]<=width_record[2] &&
                    BigFloat(width_record[1])<=exact_width<=BigFloat(width_record[2]) ||
                    error("saved fixed-Q panel width does not enclose the selected panel")
                (source_only_certificate || (hasproperty(radial,:mapped_geometry_derivative_RZ) &&
                    hasproperty(radial,:mapped_geometry_lane_ids) &&
                    hasproperty(radial,:mapped_geometry_mapping_receipt) &&
                    Tuple(radial.mapped_geometry_lane_ids)==expected_lanes &&
                    length(radial.mapped_geometry_derivative_RZ)==2 &&
                    all(row->length(row)==length(expected_lanes) && all(finite_interval,row),radial.mapped_geometry_derivative_RZ) &&
                    receipt_matches(radial.mapped_geometry_mapping_receipt,expected_map_receipt))) ||
                    error("saved fixed-Q mapped derivative/map receipt differs")
            end
            length(Set((n.panel_index,n.node_index) for n in saved_nodes))==8 ||
                error("saved fixed-Q panel node identities are not unique")
        end
        weighted=[z,z];geometry=source_only_certificate ? Tuple[] : [z for l in 1:(mapped_mode ? mapped_lanes : 6),k in 1:2];source=[z for j in 1:4,k in 1:2]
        weight_drift=BigFloat(0);node_drift=BigFloat(0);profiles=NamedTuple[];replayed_radial_ops=0;radial_origin=interval_ops[]
        source_only_certificate && (println("SOURCE_ONLY_STAGE radialnode_begin cell=",cell.native_cell," fan=",source_only_fan_key," panel=",ubox," nodes=8");flush(stdout))
        for i in 1:8
            # Deliberately materialize the same simple binary64 panel node; its
            # discrepancy from the true mapped algebraic node is bounded below.
            charge(3)
            u=ubox[1]+(ubox[2]-ubox[1])*stored_nodes[i]
            ubox[1]<=u<=ubox[2] || error("stored mapped node left angular panel")
            record=saved_nodes===nothing ? nothing : saved_nodes[i]
            node=if record===nothing
                near_signed_fan_radial_current(cell,fan,mu0,u;elliptic_order=elliptic_order,
                    radial_order=radial_order,precision_bits=precision_bits,
                    interval_ops=interval_ops,max_interval_ops=max_interval_ops,
                    _moment_arithmetic_backend=_moment_arithmetic_backend,
                    mapped_geometry_rows=source_only_certificate ? nothing : mapped_geometry_rows,
                    mapped_geometry_lane_ids=mapped_geometry_lane_ids,
                    mapped_geometry_receipt=mapped_geometry_receipt)
            else
                replayed_radial_ops+=Int(record.radial_result.interval_operation_increment)
                record.radial_result
            end
            node.status===:evaluated_signed_fan_radial_current || error("radial current provider absent")
            wi=exact(stored_weights[i])
            if node_sink!==nothing && record===nothing
                # Preserve the exact already-evaluated finite-Q node. Joint
                # mode carries only mapped native-coordinate directions.
                push!(node_sink,(fixed_u=u,weight=wi,panel_width=width,radial_result=node,
                    angular_panel=ubox,node_index=i))
            end
            for k in 1:2
                if !source_only_certificate
                weighted[k]=add(weighted[k],mul(wi,node.weighted_field_RZ[k]))
                if mapped_mode
                    Tuple(node.mapped_geometry_lane_ids)==Tuple(bound.mapped_geometry_lane_ids) ||
                        error("fixed-Q radial and angular mapped supports differ")
                    for l in 1:mapped_lanes
                        geometry[l,k]=add(geometry[l,k],mul(wi,node.mapped_geometry_derivative_RZ[k][l]))
                    end
                else
                    for l in 1:6;geometry[l,k]=add(geometry[l,k],mul(wi,node.primitive_geometry_derivative_RZ[l][k]));end
                end
                end
                for j in 1:4;source[j,k]=add(source[j,k],mul(wi,node.source_basis_RZ[j][k]));end
            end
            true_node=(pairs[i].node[1],pairs[i].node[2]);true_weight=(pairs[i].weight[1],pairs[i].weight[2])
            utrue=add(exact(ubox[1]),mul(width,true_node))
            du=absup(sub(utrue,exact(u)));dw=absup(sub(true_weight,wi))
            weight_drift=up(()->weight_drift+dw)
            node_piece=up(()->abs(BigFloat(stored_weights[i]))*du)
            node_drift=up(()->node_drift+node_piece)
            push!(profiles,(node_index=i,u=u,node_drift_upper=du,weight_drift_upper=dw,
                interval_operations=node.interval_operation_increment,
                elliptic_tail_maximum=maximum((node.radial_moment_certificate.K_tail_upper...,
                    node.radial_moment_certificate.E_tail_upper...))))
        end
        source_only_certificate && (println("SOURCE_ONLY_STAGE radialnode_end cell=",cell.native_cell," fan=",source_only_fan_key," panel=",ubox," nodes=8 intervalops=",interval_ops[]-radial_origin," replayed_intervalops=",replayed_radial_ops);flush(stdout))
        function error_total(M,M1,Peano)
            wd=up(()->M*weight_drift);nd=up(()->M1*node_drift)
            drift=mul(width,exact(up(()->wd+nd)))[2]
            (total=up(()->Peano+drift),Peano=Peano,stored_rule_drift=drift)
        end
        weighted_errors=source_only_certificate ? :typed_absent_source_only_certificate : ntuple(k->error_total(bound.M_weighted_field_RZ[k],
            bound.first_u_derivative_weighted_RZ[k],bound.Q8_error_weighted_RZ[k]),2)
        geometry_errors=source_only_certificate ? :typed_absent_source_only_certificate : mapped_mode ? ntuple(k->ntuple(l->error_total(bound.M_mapped_geometry_RZ[k][l],
            bound.first_u_derivative_mapped_geometry_RZ[k][l],bound.Q8_error_mapped_geometry_RZ[k][l]),mapped_lanes),2) :
            ntuple(l->ntuple(k->error_total(bound.M_primitive_geometry_RZ[l][k],
            bound.first_u_derivative_primitive_geometry_RZ[l][k],bound.Q8_error_primitive_geometry_RZ[l][k]),2),6)
        source_errors=ntuple(j->ntuple(k->error_total(bound.M_source_basis_RZ[j][k],
            bound.first_u_derivative_source_basis_RZ[j][k],bound.Q8_error_source_basis_RZ[j][k]),2),4)
        wresult=source_only_certificate ? :typed_absent_source_only_certificate : ntuple(k->widen(mul(width,weighted[k]),weighted_errors[k].total),2)
        gresult=source_only_certificate ? :typed_absent_source_only_certificate : mapped_mode ? ntuple(k->ntuple(l->widen(mul(width,geometry[l,k]),geometry_errors[k][l].total),mapped_lanes),2) :
            ntuple(l->ntuple(k->widen(mul(width,geometry[l,k]),geometry_errors[l][k].total),2),6)
        eresult=ntuple(j->ntuple(k->widen(mul(width,source[j,k]),source_errors[j][k].total),2),4)
        (status=:evaluated_signed_fan_angular_panel,angular_panel=ubox,
         certificate_scope=source_only_certificate ? :four_Q1_source_basis_only : :weighted_field_and_derivatives,
         weighted_field_RZ=wresult,
         primitive_geometry_derivative_RZ=mapped_mode ? :typed_absent_unused_diagnostic : gresult,
         mapped_geometry_derivative_RZ=mapped_mode ? ntuple(k->ntuple(j->begin
             q=findfirst(==(j),bound.mapped_geometry_lane_slots);q===nothing ? z : gresult[k][q]
         end,128),2) : :typed_absent_unused_diagnostic,
         mapped_geometry_error_radius_RZ=mapped_mode ? ntuple(k->ntuple(j->begin
             q=findfirst(==(j),bound.mapped_geometry_lane_slots);q===nothing ? BigFloat(0) : geometry_errors[k][q].total
         end,128),2) : :typed_absent_unused_diagnostic,
         mapped_geometry_support=mapped_mode ? bound.mapped_geometry_lane_slots : (),
         mapped_geometry_receipt=mapped_mode ? bound.mapped_geometry_receipt : nothing,
         source_basis_RZ=eresult,source_columns=cell.columns,
         weighted_error_parts=weighted_errors,geometry_error_parts=geometry_errors,source_error_parts=source_errors,
         angular_bound=bound,node_profiles=Tuple(profiles),
         radial_node_replay=saved_nodes!==nothing,replayed_radial_interval_operations=replayed_radial_ops,
         interval_operation_increment=interval_ops[]-origin,interval_operations=interval_ops[],
         max_interval_operations=max_interval_ops,kernel_calls=0,
         stored_rule_drift_included=true,radial_and_angular_integral_enclosed=true,
         angular_proof_reused=precomputed_angular_certificate!==nothing,
         actual_original_consumer_compared=false,full_native_J_assembled=false,global_closure=false)
    end
end

Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_profile_source_native_jacobian(domain,x,core_ids,span,u,v)
    Base.@nospecialize domain core_ids
    jrows=Int[];jcols=Int[];jvals=Float64[]
    sizehint!(jrows,5length(core_ids));sizehint!(jcols,5length(core_ids));sizehint!(jvals,5length(core_ids))
    for (q,k) in enumerate(core_ids)
        row=_ccp_q1_lcfs_profile_source_row(domain,x,k,span,u,v;need_jacobian=true)
        push!(jrows,q);push!(jcols,4k);push!(jvals,row.jacobian.psi)
        if domain.dynamic_profile_span
            push!(jrows,q);push!(jcols,domain.span_columns[1]);push!(jvals,row.jacobian.axis)
            push!(jrows,q);push!(jcols,domain.span_columns[2]);push!(jvals,row.jacobian.boundary)
        end
        if domain.vary_profile_coefficients
            push!(jrows,q);push!(jcols,domain.coefficient_columns[1]);
            push!(jvals,row.jacobian.u)
            push!(jrows,q);push!(jcols,domain.coefficient_columns[2]);
            push!(jvals,row.jacobian.v)
        end
    end
    Jsource_current=sparse(jrows,jcols,jvals,length(core_ids),domain.ndof)
    Jsource_current
end

# Replace one nonnegative stored error bound in an outward total. Subtraction
# removes that stored bound, not an independent uncertain physical quantity:
# T >= sum(q_i) implies T-q_old >= sum(i!=old). Charge both roundings.
function _ccp_signed_fan_replacement_totals(total,old,new,up;operator_budget=true)
    new.panel_count>old.panel_count || error("angular replacement must increase panel count")
    replace_scalar(t,a,b)=begin
        all(v->isfinite(v)&&v>=0,(t,a,b)) || error("finite nonnegative angular bounds required")
        remainder=up(()->t-a)
        remainder>=0 || error("angular total does not contain its selected bound")
        up(()->remainder+b)
    end
    (field=ntuple(k->replace_scalar(total.field[k],old.field_angular_error[k],new.field_angular_error[k]),2),
     captured=ntuple(k->replace_scalar(total.captured[k],old.captured_angular_error[k],new.captured_angular_error[k]),2),
     panels=total.panels-old.panel_count+new.panel_count,
     E_Frobenius=operator_budget ? replace_scalar(total.E_Frobenius,old.E_Frobenius_angular_error,new.E_Frobenius_angular_error) : total.E_Frobenius,
     G_Frobenius=operator_budget ? replace_scalar(total.G_Frobenius,old.G_Frobenius_angular_error,new.G_Frobenius_angular_error) : total.G_Frobenius)
end

function _ccp_signed_fan_rule_drift_factors(box,rule_record;
        interval_ops,max_interval_ops,precision_bits=192)
    rule=rule_record.qualified_rule
    rule.status===:evaluated_true_Gauss_rule_interval && rule.root_count==8 || error("true Q8 absent")
    0<=box[1]<box[2]<=1 || error("invalid rule drift panel")
    charge(n=1)=(interval_ops[]<=max_interval_ops-n || error("ray plan operation cap");interval_ops[]+=n)
    setprecision(BigFloat,precision_bits) do
        down(f)=(charge();setrounding(f,BigFloat,RoundDown))
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        exact(x)=(down(()->BigFloat(x)),up(()->BigFloat(x)))
        add(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        sub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        mul(a,b)=(minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
        absup(a)=max(abs(a[1]),abs(a[2]))
        width=sub(exact(box[2]),exact(box[1]));wd=BigFloat(0);nd=BigFloat(0)
        for i in 1:8
            charge(3);u=box[1]+(box[2]-box[1])*rule_record.production_nodes[i]
            true_u=add(exact(box[1]),mul(width,rule.mapped_nodes_and_weights[i].node))
            du=absup(sub(true_u,exact(u)))
            dw=absup(sub(rule.mapped_nodes_and_weights[i].weight,exact(rule_record.production_weights[i])))
            wd=up(()->wd+dw)
            p=up(()->abs(BigFloat(rule_record.production_weights[i]))*du)
            nd=up(()->nd+p)
        end
        (width=width[2],weight=wd,node=nd)
    end
end

function _ccp_signed_fan_complete_angular_error(M,M1,P,d;
        interval_ops,max_interval_ops,precision_bits=192)
    charge()=(interval_ops[]<max_interval_ops || error("ray plan operation cap");interval_ops[]+=1)
    setprecision(BigFloat,precision_bits) do
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        a=up(()->M*d.weight);b=up(()->M1*d.node)
        c=up(()->a+b);e=up(()->d.width*c)
        (total=up(()->P+e),Peano=P,drift=e)
    end
end

# Finite angular planning only. N2M6 is fixed; no point diagnostics or
# manually selected worst fan are needed by the production call.
Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_signed_fan_plan(payload,full_geometry,native,rule_record;
        selected_state_dof,interval_ops,max_interval_ops,field_tolerance,captured_direction_tolerance,
        E_frobenius_tolerance=nothing,G_frobenius_tolerance=nothing,_selected_panel_counts=nothing,
        angular_bound_evaluator=nothing,checkpoint_callback=nothing,candidate_replay=nothing,
        angular_target_fraction=0.1)
    Base.@nospecialize payload full_geometry native rule_record
    angular_target_fraction isa Real && isfinite(angular_target_fraction) &&
        0<angular_target_fraction<=1 || error("angular planning fraction must be in (0,1]")
    isfinite(field_tolerance) && field_tolerance>0 && isfinite(captured_direction_tolerance) &&
        captured_direction_tolerance>0 || error("positive finite scientific tolerances required")
    operator_budget=(E_frobenius_tolerance!==nothing || G_frobenius_tolerance!==nothing)
    !operator_budget || (E_frobenius_tolerance isa Real && G_frobenius_tolerance isa Real &&
        isfinite(E_frobenius_tolerance) && E_frobenius_tolerance>0 &&
        isfinite(G_frobenius_tolerance) && G_frobenius_tolerance>0) || error("both positive operator budgets required")
    invt=full_geometry.inventory;geo=full_geometry.geometry
    (_selected_panel_counts===nothing || (_selected_panel_counts isa Vector{Int} &&
        length(_selected_panel_counts)==invt.target_fan_count-invt.zero_area_fan_count &&
        all(n->n in (1,2,4,8),_selected_panel_counts))) ||
        error("saved selected panel-count vector does not match nonzero fan inventory")
    slot=findfirst(==(selected_state_dof),native.psi_global_dof_ids)
    slot===nothing && error("selected native geometry column missing")
    size(native.coordinate_jacobian)==(128,length(native.psi_global_dof_ids)) || error("native map shape")
    direction=Vector(native.coordinate_jacobian[:,slot])
    Tuple(direction)==Tuple(payload.coordinate_direction) || error("captured native map differs")
    rule=rule_record.qualified_rule
    rule.status===:evaluated_true_Gauss_rule_interval && rule.root_count==8 || error("true Q8 absent")
    ops=interval_ops;start=ops[]
    charge(n=1)=begin ops[]<=max_interval_ops-n || error("ray plan operation cap");ops[]+=n;end
    setprecision(BigFloat,192) do
        down(f)=(charge();setrounding(f,BigFloat,RoundDown))
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        exact(x)=(down(()->BigFloat(x)),up(()->BigFloat(x)))
        add(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        sub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        mul(a,b)=(minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
        absup(a)=max(abs(a[1]),abs(a[2]))
        halfwidth(a)=begin d=up(()->a[2]-a[1]);up(()->d/2) end
        scale(a,x)=x>=0 ? (down(()->a[1]*x),up(()->a[2]*x)) : (down(()->a[2]*x),up(()->a[1]*x))
        drift_factors(box)=_ccp_signed_fan_rule_drift_factors(box,rule_record;
            interval_ops=ops,max_interval_ops=max_interval_ops)
        # The rule and binary64 mapping are identical for all fans on each grid.
        drifts=Dict(n=>Tuple(begin charge(2);drift_factors(((i-1)/n,i/n)) end for i in 1:n) for n in (1,2,4,8))
        complete_error(M,M1,P,d)=_ccp_signed_fan_complete_angular_error(M,M1,P,d;
            interval_ops=ops,max_interval_ops=max_interval_ops)
        replay_rows=Dict{Any,Any}()
        if candidate_replay!==nothing
            r=candidate_replay
            r.schema===:actual_signed_fan_plan_progress_v1 && r.target_index==payload.prep.target_index &&
                r.selected_state_dof==selected_state_dof && r.capture_identity==full_geometry.capture_identity &&
                r.field_tolerance==field_tolerance && r.captured_direction_tolerance==captured_direction_tolerance &&
                r.E_frobenius_tolerance==E_frobenius_tolerance && r.G_frobenius_tolerance==G_frobenius_tolerance ||
                error("saved candidate proof belongs to a different numerical problem")
            for row in r.completed_fan_records
                candidates=row.candidates
                if row.native_cell==r.active_fan.native_cell && row.fan_index==r.active_fan.fan_index &&
                        !any(q->q.panel_count==r.candidate.panel_count,candidates)
                    row.cell_index==r.active_fan.cell_index && row.source_columns==r.active_fan.source_columns &&
                        row.target==r.active_fan.target && row.edge_points==r.active_fan.edge_points &&
                        row.current_coefficients==r.active_fan.current_coefficients || error("active saved candidate geometry differs")
                    candidates=(candidates...,r.candidate)
                end
                replay_rows[(row.native_cell,row.fan_index)]=merge(row,(candidates=candidates,))
            end
            sum(q.proof_operations for row in values(replay_rows) for q in row.candidates;init=0)<=r.interval_operations ||
                error("saved candidate costs exceed their actual source ledger")
        end
        fanrows=NamedTuple[]
        q1_invariant_cache=Dict{Any,Any}()
        q1_cache_stats=Dict{Symbol,Int}(:hits=>0,:misses=>0,:operations_saved=>0)
        candidate_evaluators=Function[]
        for (ci,c) in enumerate(invt.cells),(fi,f) in enumerate(c.fans)
            f.zero_area && continue
            rows=(Tuple(geo.target_jacobian[1,:]),Tuple(geo.target_jacobian[2,:]),
                f.endpoint_motion_keys[1]...,f.endpoint_motion_keys[2]...)
            vel=ntuple(l->begin charge(256);LinearAlgebra.dot(collect(rows[l]),direction) end,6)
            vel==(f.target_velocity...,f.edge_velocities[1]...,f.edge_velocities[2]...) || error("full map/captured fan mismatch")
            charge(10);v=Tuple(BigFloat(x) for x in vel);dc=Tuple(BigFloat(x) for x in c.current_coefficient_direction)
            # Frobenius triangle bounds use all active source columns and all
            # 128 polygon columns, independently of the regression direction.
            rownorms=operator_budget ? ntuple(l->begin
                q=BigFloat(0)
                for x in rows[l]
                    iszero(x) && continue
                    charge();rx=BigFloat(x);y=up(()->rx*rx);q=up(()->q+y)
                end
                up(()->sqrt(q))
            end,6) : nothing
            function evaluate_candidate(n)
                saved=get(replay_rows,(c.native_cell,fi),nothing)
                if saved!==nothing
                    saved.cell_index==ci && saved.source_columns==c.columns && saved.target==f.target &&
                        saved.edge_points==f.edge_points && saved.current_coefficients==c.current_coefficients &&
                        saved.current_coefficient_direction==c.current_coefficient_direction &&
                        saved.primitive_to_polygon_rows==rows && saved.actual_selected_native_velocity==vel ||
                        error("saved angular candidate physical state/geometry mapping changed")
                    qindex=findfirst(q->q.panel_count==n,saved.candidates)
                    if qindex!==nothing
                        q=saved.candidates[qindex]
                        q.proof_operations isa Integer && q.proof_operations>=0 || error("saved candidate cost missing")
                        # Reuse the actual stored proof and charge its complete
                        # original candidate work; no proof or integral reruns.
                        charge(q.proof_operations)
                        return merge(q,(reused_saved_candidate_proof=true,))
                    end
                end
                begin_cost=ops[];parts=NamedTuple[];valid=true
                E=[BigFloat(0),BigFloat(0)];G=copy(E);PE=copy(E);PG=copy(E);DE=copy(E);DG=copy(E)
                operator_E=operator_budget ? fill(BigFloat(0),4,2) : nothing
                operator_G=operator_budget ? fill(BigFloat(0),6,2) : nothing
                for i in 1:n
                    charge(2);box=((i-1)/n,i/n)
                    b=angular_bound_evaluator===nothing ?
                        near_signed_fan_angular_bound(c,f,payload.prep.law.mu0_N_per_A2,box;
                            interval_ops=ops,max_interval_ops=max_interval_ops,
                            q1_invariant_cache=q1_invariant_cache,q1_cache_stats=q1_cache_stats) :
                        Base.invokelatest(angular_bound_evaluator,c,f,payload.prep.law.mu0_N_per_A2,box;
                            interval_ops=ops,max_interval_ops=max_interval_ops,
                            q1_invariant_cache=q1_invariant_cache,q1_cache_stats=q1_cache_stats)
                    if b.status!==:evaluated_signed_fan_integrated_angular_cauchy_bound
                        valid=false;push!(parts,(angular_panel=box,proof=b));continue
                    end
                    d=drifts[n][i]
                    ee=ntuple(k->complete_error(b.M_weighted_field_RZ[k],b.first_u_derivative_weighted_RZ[k],b.Q8_error_weighted_RZ[k],d),2)
                    gg=ntuple(l->ntuple(k->complete_error(b.M_primitive_geometry_RZ[l][k],b.first_u_derivative_primitive_geometry_RZ[l][k],b.Q8_error_primitive_geometry_RZ[l][k],d),2),6)
                    ss=ntuple(j->ntuple(k->complete_error(b.M_source_basis_RZ[j][k],b.first_u_derivative_source_basis_RZ[j][k],b.Q8_error_source_basis_RZ[j][k],d),2),4)
                    if operator_budget
                        for k in 1:2,basis_index in 1:4
                            c.columns[basis_index]>0 || continue
                            operator_E[basis_index,k]=up(()->operator_E[basis_index,k]+ss[basis_index][k].total)
                        end
                        for k in 1:2,l in 1:6
                            operator_G[l,k]=up(()->operator_G[l,k]+gg[l][k].total)
                        end
                    end
                    for k in 1:2
                        E[k]=up(()->E[k]+ee[k].total);PE[k]=up(()->PE[k]+ee[k].Peano);DE[k]=up(()->DE[k]+ee[k].drift)
                        for l in 1:6
                            a=up(()->abs(v[l])*gg[l][k].total);p=up(()->abs(v[l])*gg[l][k].Peano);q=up(()->abs(v[l])*gg[l][k].drift)
                            G[k]=up(()->G[k]+a);PG[k]=up(()->PG[k]+p);DG[k]=up(()->DG[k]+q)
                        end
                        for j in 1:4
                            a=up(()->abs(dc[j])*ss[j][k].total);p=up(()->abs(dc[j])*ss[j][k].Peano);q=up(()->abs(dc[j])*ss[j][k].drift)
                            G[k]=up(()->G[k]+a);PG[k]=up(()->PG[k]+p);DG[k]=up(()->DG[k]+q)
                        end
                    end
                    push!(parts,(angular_panel=box,proof=b,weighted_error=ee,primitive_geometry_error=gg,source_error=ss))
                end
                operator_E_error=BigFloat(0);operator_G_error=BigFloat(0)
                if operator_budget
                    q=BigFloat(0)
                    for x in operator_E
                        iszero(x) && continue
                        y=up(()->x*x);q=up(()->q+y)
                    end
                    operator_E_error=up(()->sqrt(q))
                    for l in 1:6
                        q1=up(()->operator_G[l,1]^2);q2=up(()->operator_G[l,2]^2)
                        q=up(()->q1+q2);gnorm=up(()->sqrt(q));z=up(()->gnorm*rownorms[l])
                        operator_G_error=up(()->operator_G_error+z)
                    end
                end
                candidate=(panel_count=n,all_proofs_present=valid,field_angular_error=Tuple(E),captured_angular_error=Tuple(G),
                    E_Frobenius_angular_error=operator_E_error,G_Frobenius_angular_error=operator_G_error,
                    field_Peano=Tuple(PE),captured_Peano=Tuple(PG),field_drift=Tuple(DE),captured_drift=Tuple(DG),
                    proof_operations=ops[]-begin_cost,panels=Tuple(parts))
                if checkpoint_callback!==nothing
                    # Save actual completed proof work before selection, including
                    # candidates later rejected. No closures or executable cache
                    # objects enter this numerical progress record.
                    Base.invokelatest(checkpoint_callback,(
                        schema=:actual_signed_fan_plan_progress_v1,stage=:angular_candidate_completed,
                        target_index=payload.prep.target_index,selected_state_dof=selected_state_dof,
                        capture_identity=full_geometry.capture_identity,
                        completed_fan_records=Tuple(merge(row,(candidates=Tuple(row.candidates),)) for row in fanrows),
                        active_fan=(cell_index=ci,fan_index=fi,native_cell=c.native_cell,
                            source_columns=c.columns,target=f.target,edge_points=f.edge_points,
                            current_coefficients=c.current_coefficients),candidate=candidate,
                        interval_operations=ops[],max_interval_operations=max_interval_ops,
                        field_tolerance=field_tolerance,captured_direction_tolerance=captured_direction_tolerance,
                        E_frobenius_tolerance=E_frobenius_tolerance,G_frobenius_tolerance=G_frobenius_tolerance,
                        complete_plan=false,full64=false,global_closure=false))
                end
                candidate
            end
            candidates=NamedTuple[]
            if _selected_panel_counts===nothing
                for n in (1,2,4,8)
                    push!(candidates,Base.invokelatest(evaluate_candidate,n))
                    candidates[end].all_proofs_present && break
                end
            else
                n=_selected_panel_counts[length(fanrows)+1]
                push!(candidates,Base.invokelatest(evaluate_candidate,n))
            end
            push!(fanrows,(cell_index=ci,fan_index=fi,native_cell=c.native_cell,source_columns=c.columns,
                target=f.target,edge_points=f.edge_points,current_coefficients=c.current_coefficients,
                current_coefficient_direction=c.current_coefficient_direction,primitive_to_polygon_rows=rows,
                actual_selected_native_velocity=vel,candidates=candidates))
            push!(candidate_evaluators,evaluate_candidate)
        end
        length(fanrows)==invt.target_fan_count-invt.zero_area_fan_count || error("nonzero fan coverage differs")
        # Generate panel-count candidates only as selection reaches them; all bounds
        # and allocation comparisons use the same order and formulas. A 10% angular
        # planning target reserves room for the STILL UNPROVED other radial tails;
        # the final scientific E/G limits are unchanged and must be tested later.
        selected=_selected_panel_counts===nothing ?
            [something(findfirst(c->c.all_proofs_present,row.candidates),0) for row in fanrows] :
            ones(Int,length(fanrows))
        all_present=all(>(0),selected)
        if _selected_panel_counts!==nothing
            all_present &= all(j->fanrows[j].candidates[1].all_proofs_present &&
                fanrows[j].candidates[1].panel_count==_selected_panel_counts[j],eachindex(fanrows))
        end
        function totals(indices)
            E=[BigFloat(0),BigFloat(0)];G=copy(E);np=0;OE=BigFloat(0);OG=BigFloat(0)
            for j in eachindex(fanrows)
                q=fanrows[j].candidates[indices[j]];np+=q.panel_count
                for k in 1:2;E[k]=up(()->E[k]+q.field_angular_error[k]);G[k]=up(()->G[k]+q.captured_angular_error[k]);end
                if operator_budget
                    OE=up(()->OE+q.E_Frobenius_angular_error);OG=up(()->OG+q.G_Frobenius_angular_error)
                end
            end
            (field=Tuple(E),captured=Tuple(G),panels=np,E_Frobenius=OE,G_Frobenius=OG)
        end
        function score(q)
            v=maximum((up(()->q.field[1]/field_tolerance),up(()->q.field[2]/field_tolerance),
                up(()->q.captured[1]/captured_direction_tolerance),up(()->q.captured[2]/captured_direction_tolerance)))
            operator_budget ? max(v,up(()->q.E_Frobenius/E_frobenius_tolerance),
                up(()->q.G_Frobenius/G_frobenius_tolerance)) : v
        end
        total=all_present ? totals(selected) : nothing
        steps=NamedTuple[]
        if all_present && _selected_panel_counts===nothing
            for step in 1:(3length(fanrows))
                score(total)<=angular_target_fraction && break
                best=nothing;bestgain=BigFloat(0)
                for j in eachindex(fanrows)
                    old=selected[j];new=old+1;row=fanrows[j]
                    if new>length(row.candidates)
                        new<=4 || continue
                        push!(row.candidates,Base.invokelatest(candidate_evaluators[j],(1,2,4,8)[new]))
                    end
                    row.candidates[new].all_proofs_present || continue
                    t=_ccp_signed_fan_replacement_totals(total,row.candidates[old],row.candidates[new],up;
                        operator_budget=operator_budget)
                    gain=up(()->score(total)-score(t));charge();extra=t.panels-total.panels
                    rate=up(()->gain/extra)
                    if rate>bestgain;bestgain=rate;best=(fan=j,index=new,total=t);end
                end
                best===nothing && break
                selected[best.fan]=best.index
                # Rebase once per accepted choice, rather than for every trial;
                # this discards carried rounding slack in the original fold.
                total=totals(selected)
                push!(steps,(fan=best.fan,panel_count=fanrows[best.fan].candidates[best.index].panel_count,score=score(total)))
            end
        end
        angular_target_met=all_present && score(total)<=angular_target_fraction
        (status=:evaluated_finite_signed_fan_plan,target_index=payload.prep.target_index,
         selected_state_dof=selected_state_dof,fan_count=length(fanrows),
         qualified_zero_alias_count=invt.zero_area_fan_count,original_leaf_count=invt.original_leaf_count,
         fan_records=Tuple(merge(row,(candidates=Tuple(row.candidates),)) for row in fanrows),selected_candidate_indices=Tuple(selected),selection_steps=Tuple(steps),
         reused_saved_candidate_count=count(q->get(q,:reused_saved_candidate_proof,false),
             (q for row in fanrows for q in row.candidates)),
         reused_saved_candidate_proof_operations=sum(q.proof_operations for row in fanrows for q in row.candidates
             if get(q,:reused_saved_candidate_proof,false);init=0),
         all_fans_have_a_finite_angular_candidate=all_present,angular_planning_target_fraction=angular_target_fraction,
         angular_planning_target_met=angular_target_met,selected_angular_totals=total,
         planning_interval_operations=ops[],planning_interval_operation_increment=ops[]-start,
         q1_invariant_cache_stats=(hits=q1_cache_stats[:hits],misses=q1_cache_stats[:misses],
             directed_operations_saved=q1_cache_stats[:operations_saved]),
         field_tolerance=field_tolerance,captured_direction_tolerance=captured_direction_tolerance,
         E_frobenius_tolerance=E_frobenius_tolerance,G_frobenius_tolerance=G_frobenius_tolerance,
         operator_budget_enabled=operator_budget,
         native_geometry_map=native.coordinate_jacobian,native_geometry_state_columns=Tuple(native.psi_global_dof_ids),
         all_fan_radial_tails_certified=false,actual_full_ray_integral_evaluated=false,global_closure=false,kernel_calls=0)
    end
end

# The joint contraction has consumed the radial nodes. Preserve its actual
# numeric intervals and all panel error/branch metadata, rather than retaining
# the same large radial moment graphs in every later checkpoint.
Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_compact_completed_joint_fan(row)
    Base.@nospecialize row
    row.fixedQ_joint_BJ!==nothing && row.fixedQ_joint_BJ.status===:evaluated_same_fixedQ_primal_and_derivative ||
        error("raw nodes can be released only after the actual joint contraction")
    result=row.result
    row.fixedQ_joint_BJ.node_count==8length(result.panels) || error("joint/panel count differs before node release")
    panels=map(p->merge(p,(fixedQ_node_terms=nothing,)),result.panels)
    merge(row,(result=merge(result,(panels=panels,fixedQ_node_terms=nothing)),
        raw_node_payload=:released_after_completed_joint_contraction))
end

Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_compact_joint_checkpoint(saved)
    Base.@nospecialize saved
    hasproperty(saved,:joint_accumulators) && saved.joint_accumulators!==nothing ||
        error("completed joint accumulator required before releasing checkpoint nodes")
    q=saved.joint_accumulators;rows=saved.fan_results
    keys=Tuple((r.native_cell,r.fan_index) for r in rows)
    q.schema===:same_fixedQ_joint_accumulators_v1 && Tuple(saved.completed_fans)==keys==Tuple(q.completed_fans) &&
        q.node_count==saved.new_nodes==8saved.new_panels &&
        q.node_count==sum(r.fixedQ_joint_BJ.node_count for r in rows) &&
        length(q.error_parts)==length(rows)==length(q.branch_records) &&
        Tuple((r.native_cell,r.fan_index) for r in q.error_parts)==keys &&
        Tuple((r.native_cell,r.fan_index) for r in q.branch_records)==keys &&
        length(q.field)==2 && size(q.G)==(2,128) && size(q.angular_geometry_error)==(2,128) &&
        0<=q.contraction_operations<=saved.interval_operations &&
        q.contraction_operations==sum(r.fixedQ_joint_BJ.interval_operation_increment for r in rows) ||
        error("joint checkpoint coverage/ledger differs")
    valid_iv(v)=v isa Tuple && length(v)==2 && all(isfinite,v) && v[1]<=v[2]
    all(valid_iv,q.field) && all(valid_iv,q.G) &&
        all(kv->1<=first(kv)<=length(saved.source_current_native_ids) && length(last(kv))==2 &&
            all(valid_iv,last(kv)),q.E_Q1) &&
        all(v->isfinite(v)&&v>=0,q.angular_geometry_error) &&
        all(c->1<=c<=128,q.angular_geometry_support) &&
        all(r->r.fixedQ_joint_BJ.status===:evaluated_same_fixedQ_primal_and_derivative &&
            r.fixedQ_joint_BJ.node_count==8length(r.result.panels),rows) ||
        error("joint checkpoint numerical intervals/receipts are invalid")
    valid_radius(x,shape)=size(x)==shape && all(v->isfinite(v)&&v>=0,x)
    for i in eachindex(rows)
        e=q.error_parts[i];r=rows[i]
        length(e.B_Q_abs_error_radius_RZ)==2 && all(v->isfinite(v)&&v>=0,e.B_Q_abs_error_radius_RZ) &&
            valid_radius(e.E_Q1_abs_error_radius_RZ,(2,4)) &&
            valid_radius(e.G_Q_abs_error_radius_RZ,(2,128)) &&
            valid_radius(e.G_Q_interval_arithmetic_radius_RZ,(2,128)) &&
            valid_radius(e.G_Q_mapped_angular_error_radius_RZ,(2,128)) &&
            all(k->all(c->isequal(e.G_Q_mapped_angular_error_radius_RZ[k,c],
                r.result.mapped_angular_error_radius_RZ[k][c]),1:128),1:2) &&
            e.G_Q_total_error_handling===:diagnostic_only_global_panel_radius_applied_once &&
            q.branch_records[i].topology_branch.active_canonical_branch_verified===true &&
            isequal(q.branch_records[i].topology_branch,r.fixedQ_joint_BJ.topology_branch) ||
            error("completed joint error/branch payload differs before node release")
    end
    if rows isa Vector{NamedTuple}
        for k in eachindex(rows);rows[k]=_ccp_q1_lcfs_compact_completed_joint_fan(rows[k]);end
        saved
    else
        merge(saved,(fan_results=NamedTuple[_ccp_q1_lcfs_compact_completed_joint_fan(r) for r in rows],))
    end
end

Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_signed_fan_integral(payload,full_geometry,plan,rule_record;
        selected_state_dof,source_chain,interval_ops,max_interval_ops,
        checkpoint_callback=nothing,resume_fan_checkpoint=nothing,
        checkpoint_each_fan=false,_moment_arithmetic_backend=nothing,joint_operator_evaluator=nothing,
        mapped_geometry_receipt=nothing,saved_pending_fixedQ_fan=nothing)
    Base.@nospecialize payload full_geometry plan rule_record
    checkpoint_each_fan isa Bool || error("checkpoint_each_fan must be Bool")
    checkpoint_each_fan && checkpoint_callback===nothing && error("per-fan checkpoints require a callback")
    if _moment_arithmetic_backend!==nothing
        ctx=_moment_arithmetic_backend.context
        ctx.interval_ops===interval_ops && ctx.max_interval_ops==max_interval_ops && ctx.precision_bits==192 ||
            error("midradius context must share the integral ledger, cap, and precision")
    end
    if joint_operator_evaluator!==nothing
        mapped_geometry_receipt!==nothing || error("same-call mapped geometry receipt required")
        all(k->hasproperty(mapped_geometry_receipt,k),
            (:state_coordinate_id,:state_input_sha256,:geometry_map_identity)) ||
            error("mapped geometry receipt lacks state/map identity")
        mapped_geometry_receipt.state_coordinate_id===:native_F_defect_T_m_v1 ||
            error("mapped geometry state coordinate differs")
        mapped_geometry_receipt.state_input_sha256 isa AbstractString &&
            occursin(r"^[0-9a-f]{64}$",mapped_geometry_receipt.state_input_sha256) ||
            error("mapped geometry state input pin is invalid")
        mapped_geometry_receipt.geometry_map_identity!==nothing || error("stable geometry-map identity absent")
    end
    # Keep large saved records out of the keyword-specialized numerical body.
    Base.invokelatest(_ccp_q1_lcfs_signed_fan_integral_body,payload,full_geometry,plan,rule_record,
        selected_state_dof,source_chain,interval_ops,max_interval_ops,checkpoint_callback,resume_fan_checkpoint,
        checkpoint_each_fan,_moment_arithmetic_backend,joint_operator_evaluator,mapped_geometry_receipt,saved_pending_fixedQ_fan)
end

Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_signed_fan_integral_body(
        payload,full_geometry,plan,rule_record,selected_state_dof,source_chain,
        interval_ops,max_interval_ops,checkpoint_callback,resume_fan_checkpoint,checkpoint_each_fan=false,
        _moment_arithmetic_backend=nothing,joint_operator_evaluator=nothing,mapped_geometry_receipt=nothing,
        saved_pending_fixedQ_fan=nothing)
    Base.@nospecialize payload full_geometry plan rule_record source_chain checkpoint_callback resume_fan_checkpoint _moment_arithmetic_backend joint_operator_evaluator mapped_geometry_receipt saved_pending_fixedQ_fan
    plan.status===:evaluated_finite_signed_fan_plan && plan.target_index==payload.prep.target_index &&
        plan.selected_state_dof==selected_state_dof && plan.angular_planning_target_met &&
        plan.all_fans_have_a_finite_angular_candidate || error("complete finite angular plan required")
    invt=full_geometry.inventory
    expected_fans=Set((ci,fi) for (ci,c) in enumerate(invt.cells) for (fi,f) in enumerate(c.fans) if !f.zero_area)
    planned_fans=Tuple((r.cell_index,r.fan_index) for r in plan.fan_records)
    length(planned_fans)==length(plan.selected_candidate_indices)==length(unique(planned_fans)) &&
        Set(planned_fans)==expected_fans || error("planned fan identities do not cover actual nonzero fans")
    interval_ops[]==(resume_fan_checkpoint===nothing ? plan.planning_interval_operations :
        resume_fan_checkpoint.interval_operations) || error("planning/resume ledger differs")
    ops=interval_ops;origin=plan.planning_interval_operations
    charge(n=1)=begin ops[]<=max_interval_ops-n || error("full ray authorized operation cap");ops[]+=n;end
    setprecision(BigFloat,192) do
        down(f)=(charge();setrounding(f,BigFloat,RoundDown))
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        cache=Dict{Any,Tuple{BigFloat,BigFloat}}()
        exact(x)=get!(cache,(typeof(x),x)) do
            (down(()->BigFloat(x)),up(()->BigFloat(x)))
        end
        z=(BigFloat(0),BigFloat(0))
        zeroiv(a)=iszero(a[1]) && iszero(a[2])
        add(a,b)=zeroiv(a) ? b : zeroiv(b) ? a : (down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        sub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        scale(a,x)=begin
            isfinite(x) || error("nonfinite chain coefficient")
            iszero(x) && return z
            xx=exact(x);xx[1]==xx[2] || error("chain coefficient is not exactly representable")
            v=xx[1]
            v>=0 ? (down(()->a[1]*v),up(()->a[2]*v)) : (down(()->a[2]*v),up(()->a[1]*v))
        end
        absup(a)=max(abs(a[1]),abs(a[2]))
        halfwidth(a)=begin d=up(()->a[2]-a[1]);up(()->d/2) end
        function point_and_radius(a)
            zeroiv(a) && return (value=0.0,absolute_error_upper=BigFloat(0))
            charge(3);m=Float64((a[1]+a[2])/2)
            isfinite(m) || error("stored field/J midpoint is nonfinite")
            q=exact(m);r=max(up(()->q[1]-a[1]),up(()->a[2]-q[2]))
            (value=m,absolute_error_upper=r)
        end
        field=[z,z];captured_direct=[z,z]
        E=Dict{Int,Vector{Tuple{BigFloat,BigFloat}}}()
        G=[z for k in 1:2,c in 1:128]
        fan_results=NamedTuple[];completed_fan_keys=Set{Tuple{Tuple{Int,Int},Int}}();new_nodes=0;new_panels=0
        joint_field=[z,z];joint_G=[z for k in 1:2,c in 1:128]
        joint_angular_geometry_error=[BigFloat(0) for k in 1:2,c in 1:128]
        joint_angular_geometry_support=Set{Int}()
        joint_E_Q1=Dict{Int,Vector{Tuple{BigFloat,BigFloat}}}()
        joint_source_J=Dict{Int,Vector{Tuple{BigFloat,BigFloat}}}();joint_node_count=0
        joint_cost=0;joint_error_parts=NamedTuple[];joint_branch_records=NamedTuple[]
        recover_saved_joint=false;recovery_remaining=0;recovery_total=0;recovery_start=ops[]
        saved_fan_rows=Dict{Tuple{Tuple{Int,Int},Int},NamedTuple}()
        pending_nodes_replayed=0;pending_replay_used=false
        joint_snapshot()=joint_operator_evaluator===nothing ? nothing :
            (schema=:same_fixedQ_joint_accumulators_v1,
             completed_fans=Tuple((r.native_cell,r.fan_index) for r in fan_results),
             field=copy(joint_field),G=copy(joint_G),
             E_Q1=Dict(k=>copy(v) for (k,v) in joint_E_Q1),
             angular_geometry_error=copy(joint_angular_geometry_error),
             angular_geometry_support=Tuple(sort!(collect(joint_angular_geometry_support))),
             node_count=joint_node_count,contraction_operations=joint_cost,
             error_parts=copy(joint_error_parts),branch_records=copy(joint_branch_records))
        function emit_fan_checkpoint(;joint_recovery=nothing)
            checkpoint_callback===nothing && return
            Base.invokelatest(checkpoint_callback,(schema=:signed_fan_pre_native_map_numeric_v1,
                arithmetic_backend=_moment_arithmetic_backend===nothing ? :bigfloat : :midrad_v1,
                target_index=payload.prep.target_index,selected_state_dof=selected_state_dof,
                source_current_native_ids=Tuple(payload.prep.core_ids),
                planning_interval_operations=plan.planning_interval_operations,interval_operations=ops[],
                field=copy(field),captured_direct=copy(captured_direct),E=copy(E),G=copy(G),
                fan_results=copy(fan_results),completed_fans=Tuple((r.native_cell,r.fan_index) for r in fan_results),
                new_nodes=new_nodes,new_panels=new_panels,
                joint_accumulators=joint_snapshot(),joint_recovery=joint_recovery))
        end
        if resume_fan_checkpoint!==nothing
            saved=resume_fan_checkpoint
            saved_fan_keys=Set((r.native_cell,r.fan_index) for r in saved.fan_results)
            expected_fan_keys=Set((r.native_cell,r.fan_index) for r in plan.fan_records)
            saved.schema===:signed_fan_pre_native_map_numeric_v1 &&
                saved.target_index==payload.prep.target_index && saved.selected_state_dof==selected_state_dof &&
                saved.source_current_native_ids==Tuple(payload.prep.core_ids) &&
                saved.planning_interval_operations==plan.planning_interval_operations &&
                saved.interval_operations<=max_interval_ops &&
                length(saved_fan_keys)==length(saved.fan_results) && issubset(saved_fan_keys,expected_fan_keys) &&
                (checkpoint_each_fan ?
                    (hasproperty(saved,:completed_fans) && Tuple(saved.completed_fans)==Tuple((r.native_cell,r.fan_index) for r in saved.fan_results) &&
                     hasproperty(saved,:arithmetic_backend) && saved.arithmetic_backend===(_moment_arithmetic_backend===nothing ? :bigfloat : :midrad_v1)) :
                    saved_fan_keys==expected_fan_keys) ||
                error("saved completed fan integral identity/coverage/ledger differs")
            field=collect(saved.field);captured_direct=collect(saved.captured_direct)
            E=saved.E;G=saved.G;fan_results=collect(saved.fan_results)
            completed_fan_keys=saved_fan_keys
            new_nodes=saved.new_nodes;new_panels=saved.new_panels
            if joint_operator_evaluator!==nothing
                if hasproperty(saved,:joint_accumulators) && saved.joint_accumulators!==nothing
                    q=saved.joint_accumulators
                    q.schema===:same_fixedQ_joint_accumulators_v1 &&
                        Tuple(q.completed_fans)==Tuple((r.native_cell,r.fan_index) for r in fan_results) &&
                        length(q.field)==2 && size(q.G)==(2,128) && size(q.angular_geometry_error)==(2,128) &&
                        q.node_count==new_nodes && q.contraction_operations>=0 &&
                        length(q.error_parts)==length(fan_results)==length(q.branch_records) ||
                        error("saved joint accumulators do not cover the completed fan prefix")
                    valid_iv(v)=v isa Tuple && length(v)==2 && all(isfinite,v) && v[1]<=v[2]
                    all(valid_iv,q.field) && all(valid_iv,q.G) &&
                        all(kv->1<=first(kv)<=length(payload.prep.current) && length(last(kv))==2 &&
                            all(valid_iv,last(kv)),q.E_Q1) &&
                        all(v->isfinite(v)&&v>=0,q.angular_geometry_error) &&
                        all(c->1<=c<=128,q.angular_geometry_support) &&
                        q.node_count==sum(r.fixedQ_joint_BJ.node_count for r in fan_results) &&
                        q.contraction_operations<=saved.interval_operations &&
                        Tuple((r.native_cell,r.fan_index) for r in q.branch_records)==Tuple(q.completed_fans) &&
                        Tuple((r.native_cell,r.fan_index) for r in q.error_parts)==Tuple(q.completed_fans) ||
                        error("saved joint accumulator values/counts differ from the actual prefix")
                    joint_field=copy(q.field);joint_G=copy(q.G)
                    joint_E_Q1=Dict(k=>copy(v) for (k,v) in q.E_Q1)
                    joint_angular_geometry_error=copy(q.angular_geometry_error)
                    joint_angular_geometry_support=Set{Int}(q.angular_geometry_support)
                    joint_node_count=q.node_count;joint_cost=q.contraction_operations
                    joint_error_parts=collect(q.error_parts);joint_branch_records=collect(q.branch_records)
                else
                    # Legacy checkpoints retain every actual fixed-Q node but
                    # omitted the joint B/E/G accumulators. Rebuild only that
                    # postprocessor, charging its work to the inherited ledger.
                    # The radial/angle integrals are never evaluated again.
                    recover_saved_joint=true;recovery_remaining=length(fan_results);recovery_total=recovery_remaining
                    recovery_start=ops[]
                    for r in fan_results;saved_fan_rows[(r.native_cell,r.fan_index)]=r;end
                end
            end
        end
        for (j,record) in enumerate(plan.fan_records)
            saved_key=(record.native_cell,record.fan_index)
            restoring_joint= saved_key in completed_fan_keys
            restoring_joint && !recover_saved_joint && continue
            cell=invt.cells[record.cell_index];fan=cell.fans[record.fan_index]
            !fan.zero_area && cell.native_cell==record.native_cell && cell.columns==record.source_columns &&
                cell.current_coefficients==record.current_coefficients && cell.current_coefficient_direction==record.current_coefficient_direction &&
                fan.target==record.target && fan.edge_points==record.edge_points || error("planned actual fan binding differs")
            all(c->0<=c<=length(payload.prep.current),cell.columns) || error("source slot outside captured core order")
            Tuple(c==0 ? 0.0 : payload.prep.current[c] for c in cell.columns)==cell.current_coefficients &&
                Tuple(c==0 ? 0.0 : payload.prep.dcurrent[c] for c in cell.columns)==cell.current_coefficient_direction || error("raw current law values differ from saved fan")
            original_cell=payload.prep.prepared_cells[cell.cell_index]
            original_cell.native_cell==cell.native_cell && original_cell.bounds==cell.bounds &&
                original_cell.columns==cell.columns || error("raw native Q1 chart differs from planned fan")
            actual_rows=(Tuple(full_geometry.geometry.target_jacobian[1,:]),Tuple(full_geometry.geometry.target_jacobian[2,:]),
                fan.endpoint_motion_keys[1]...,fan.endpoint_motion_keys[2]...)
            actual_rows==record.primitive_to_polygon_rows || error("planned full128 fan map differs")
            choice=plan.selected_candidate_indices[j]
            1<=choice<=length(record.candidates) || error("planned angular choice missing")
            candidate=record.candidates[choice]
            candidate.all_proofs_present && length(candidate.panels)==candidate.panel_count || error("planned angular coverage incomplete")
            replay_pending=!restoring_joint && saved_pending_fixedQ_fan!==nothing && !pending_replay_used
            if replay_pending
                saved_pending_fixedQ_fan.meta.expected_fan_key==saved_key &&
                    saved_pending_fixedQ_fan.primitive_rows==actual_rows &&
                    length(saved_pending_fixedQ_fan.nodes)==8candidate.panel_count ||
                    error("saved pending radial nodes do not match the first remaining fan")
            end
            fr=if restoring_joint
                row=saved_fan_rows[saved_key]
                row.source_columns==cell.columns && row.target==fan.target && row.edge_points==fan.edge_points &&
                    row.primitive_to_polygon_rows==actual_rows || error("saved fixed-Q fan binding differs during joint recovery")
                q=row.result
                Tuple(p.angular_panel for p in q.panels)==Tuple(p.angular_panel for p in candidate.panels) &&
                    length(q.fixedQ_node_terms)==8candidate.panel_count &&
                    length(q.mapped_angular_error_radius_RZ)==2 &&
                    all(v->length(v)==128,q.mapped_angular_error_radius_RZ) ||
                    error("saved fixed-Q nodes/angular coverage are incomplete")
                for k in 1:2,c in 1:128
                    joint_angular_geometry_error[k,c]=up(()->joint_angular_geometry_error[k,c]+q.mapped_angular_error_radius_RZ[k][c])
                end
                union!(joint_angular_geometry_support,q.mapped_angular_support)
                q
            else
              begin
                begin_ops=ops[];ff=[z,z];gg=[z for l in 1:6,k in 1:2];ee=[z for s in 1:4,k in 1:2]
                fan_angular_error=[BigFloat(0) for k in 1:2,c in 1:128]
                panels=NamedTuple[]
                reused_mapped_proofs=nothing
                for (pi,part) in enumerate(candidate.panels)
                    charge(2);box=((pi-1)/candidate.panel_count,pi/candidate.panel_count)
                    panel_nodes=joint_operator_evaluator===nothing ? nothing : NamedTuple[]
                    part.angular_panel==box && part.proof.angular_panel==box || error("planned panels are not the complete canonical grid")
                    binding=(target=fan.target,edge_points=fan.edge_points,multiplicity=fan.multiplicity,
                        bounds=cell.bounds,current_coefficients=cell.current_coefficients,source_columns=cell.columns,
                        common_z_geometry_hull=nothing,
                        mu0=payload.prep.law.mu0_N_per_A2,angular_panel=box,disk_fraction=0.8,precision_bits=192)
                    samecall_map_receipt=joint_operator_evaluator===nothing ? nothing :
                        (mapped_geometry_receipt===nothing ? error("state-bound mapped geometry receipt required") :
                         merge(mapped_geometry_receipt,(schema=:same_call_mapped_primitive_geometry_rows_v1,
                         fan_key=(cell.native_cell,record.fan_index),target_index=payload.prep.target_index,
                         polygon_lane_ids=Tuple(1:128),state_columns=Tuple(plan.native_geometry_state_columns),
                         geometry_map_size=size(plan.native_geometry_map))))
                    reuse_provider=(_moment_arithmetic_backend!==nothing &&
                        hasproperty(_moment_arithmetic_backend,:mapped_angular_proof_evaluator)) ?
                            _moment_arithmetic_backend.mapped_angular_proof_evaluator : nothing
                    if joint_operator_evaluator!==nothing && reuse_provider!==nothing && reused_mapped_proofs===nothing
                        reused_mapped_proofs=Base.invokelatest(reuse_provider,record,candidate,cell,fan,
                            payload.prep.law.mu0_N_per_A2,actual_rows,samecall_map_receipt;
                            interval_ops=ops,max_interval_ops=max_interval_ops)
                        reused_mapped_proofs.status===:evaluated_from_saved_primitive_proofs &&
                            length(reused_mapped_proofs.panels)==candidate.panel_count ||
                                error("mapped angular proof reuse returned incomplete fan coverage")
                    end
                    angular_proof=joint_operator_evaluator===nothing ? part.proof :
                        reused_mapped_proofs!==nothing ? begin
                            q=reused_mapped_proofs.panels[pi]
                            q.angular_panel==box && q.binding==binding ||
                                error("reused mapped angular certificate differs from the actual panel")
                            q.proof
                        end :
                        near_signed_fan_angular_bound(cell,fan,payload.prep.law.mu0_N_per_A2,box;
                            interval_ops=ops,max_interval_ops=max_interval_ops,
                            mapped_geometry_rows=actual_rows,mapped_geometry_lane_ids=Tuple(1:128),
                            mapped_geometry_receipt=samecall_map_receipt)
                    replay_nodes=replay_pending ? Tuple(n for n in saved_pending_fixedQ_fan.nodes if n.panel_index==pi) : nothing
                    panel=near_signed_fan_panel(cell,fan,payload.prep.law.mu0_N_per_A2,box,
                        rule_record.qualified_rule,rule_record.production_nodes,rule_record.production_weights;
                        elliptic_order=2,radial_order=6,interval_ops=ops,max_interval_ops=max_interval_ops,
                        precomputed_angular_certificate=(binding=binding,proof=angular_proof),
                        _moment_arithmetic_backend=_moment_arithmetic_backend,node_sink=panel_nodes,
                        mapped_geometry_rows=joint_operator_evaluator===nothing ? nothing : actual_rows,
                        mapped_geometry_lane_ids=joint_operator_evaluator===nothing ? () : Tuple(1:128),
                        angular_geometry_receipt=samecall_map_receipt,
                        mapped_geometry_receipt=samecall_map_receipt,
                        saved_fixedQ_node_terms=replay_nodes,saved_panel_index=replay_pending ? pi : nothing)
                    if replay_pending
                        length(replay_nodes)==8 || error("pending panel must retain its eight actual radial nodes")
                        append!(panel_nodes,replay_nodes)
                    end
                    panel.status===:evaluated_signed_fan_angular_panel || error("saved angular proof failed actual integration")
                    panel=panel_nodes===nothing ? panel : merge(panel,(fixedQ_node_terms=Tuple(panel_nodes),))
                    push!(panels,panel);new_panels+=1;new_nodes+=8
                    for k in 1:2
                        ff[k]=add(ff[k],panel.weighted_field_RZ[k])
                        if joint_operator_evaluator===nothing
                            for l in 1:6;gg[l,k]=add(gg[l,k],panel.primitive_geometry_derivative_RZ[l][k]);end
                        else
                            for c in 1:128
                                fan_angular_error[k,c]=up(()->fan_angular_error[k,c]+panel.mapped_geometry_error_radius_RZ[k][c])
                            end
                            union!(joint_angular_geometry_support,panel.mapped_geometry_support)
                        end
                        for s in 1:4;ee[s,k]=add(ee[s,k],panel.source_basis_RZ[s][k]);end
                    end
                end
                if joint_operator_evaluator!==nothing
                    for k in 1:2,c in 1:128
                        joint_angular_geometry_error[k,c]=up(()->joint_angular_geometry_error[k,c]+fan_angular_error[k,c])
                    end
                end
                (weighted_field_RZ=Tuple(ff),
                 primitive_geometry_derivative_RZ=joint_operator_evaluator===nothing ?
                    ntuple(l->ntuple(k->gg[l,k],2),6) : :typed_absent_unused_diagnostic,
                 mapped_angular_error_radius_RZ=joint_operator_evaluator===nothing ? :typed_absent_unused_diagnostic :
                    ntuple(k->Tuple(fan_angular_error[k,c] for c in 1:128),2),
                 mapped_angular_support=joint_operator_evaluator===nothing ? () :
                    Tuple(c for c in 1:128 if any(k->!iszero(fan_angular_error[k,c]),1:2)),
                 mapped_angular_receipt=joint_operator_evaluator===nothing ? nothing :
                    (isempty(panels) ? error("joint angular receipt requires selected panels") :
                     panels[1].mapped_geometry_receipt),
                 source_basis_RZ=ntuple(s->ntuple(k->ee[s,k],2),4),panels=Tuple(panels),interval_operation_increment=ops[]-begin_ops,
                 fixedQ_node_terms=joint_operator_evaluator===nothing ? nothing :
                    Tuple(node for panel in panels for node in panel.fixedQ_node_terms),
                 elliptic_order=2,radial_order=6,reused_complete_certificate=false)
              end
            end
            joint_fan_result=nothing
            if joint_operator_evaluator!==nothing
                joint_nodes=Tuple(merge(node,(fan_key=(cell.native_cell,record.fan_index),panel_index=pi)) for (pi,panel) in enumerate(fr.panels)
                    for node in panel.fixedQ_node_terms)
                primitive_rows=(Tuple(full_geometry.geometry.target_jacobian[1,:]),Tuple(full_geometry.geometry.target_jacobian[2,:]),
                    fan.endpoint_motion_keys[1]...,fan.endpoint_motion_keys[2]...)
                length(joint_nodes)==8length(fr.panels) && length(primitive_rows)==6 ||
                    error("fixed-Q node/primitive row coverage differs")
                # The callback must only postprocess these node evaluations.
                # It cannot own a field provider or make ring/PF calls.
                joint_fan_result=Base.invokelatest(joint_operator_evaluator,joint_nodes,primitive_rows,
                    (expected_fan_key=(cell.native_cell,record.fan_index),native_cell=cell.native_cell,
                     fan_index=record.fan_index,target_index=payload.prep.target_index,
                     source_columns=cell.columns,q1_source_slots=cell.columns,
                     branch=(schema=:actual_signed_fan_fixedQ_branch_v1,active_canonical_branch_verified=true,
                        target_index=payload.prep.target_index,native_cell=cell.native_cell,fan_key=(cell.native_cell,record.fan_index),
                        fixed_panel_template=true,polygon_coordinates=fan.target,oriented_edge_points=fan.edge_points),
                     state_ndof=payload.prep.domain.ndof,source_sparse_S=source_chain.source_current_jacobian_A_per_m2_per_state_dof,
                     source_current_jacobian=source_chain.source_current_jacobian_A_per_m2_per_state_dof,
                     geometry_C=plan.native_geometry_map,psi_global_dof_ids=plan.native_geometry_state_columns,
                     capture_identity=full_geometry.capture_identity,source_current_native_ids=Tuple(payload.prep.core_ids),
                     rule_record=rule_record,elliptic_order=2,radial_order=6,precision_bits=192,
                     panel_count=candidate.panel_count,mu0=payload.prep.law.mu0_N_per_A2,fan=fan,cell_bounds=cell.bounds,
                     mapped_angular_error_radius_RZ=fr.mapped_angular_error_radius_RZ,
                     mapped_angular_support=fr.mapped_angular_support,
                     mapped_angular_receipt=fr.mapped_angular_receipt,
                     mapped_geometry_receipt=mapped_geometry_receipt,
                     target=fan.target,edge_points=fan.edge_points,multiplicity=fan.multiplicity,
                     current_coefficients=cell.current_coefficients,
                     backend_id=_moment_arithmetic_backend===nothing ? :bigfloat_v1 :
                        (hasproperty(_moment_arithmetic_backend,:schema) ? _moment_arithmetic_backend.schema : :midrad_custom),
                     producer_settings=(elliptic_order=2,radial_order=6,precision_bits=192,
                        backend_id=_moment_arithmetic_backend===nothing ? :bigfloat_v1 :
                            (hasproperty(_moment_arithmetic_backend,:schema) ? _moment_arithmetic_backend.schema : :midrad_custom),
                        mu0=payload.prep.law.mu0_N_per_A2,cell=cell.native_cell,current_coefficients=cell.current_coefficients,
                        rule_receipt_sha256=:bound_by_actual_vertical_entry,target_RZ_m=fan.target,
                        edge_points_RZ_m=fan.edge_points,native_cell_bounds_RZ_m=cell.bounds,
                        target_index=payload.prep.target_index,fan_key=(cell.native_cell,record.fan_index),
                        multiplicity=fan.multiplicity,q1_source_slots=cell.columns,
                        q1_source_current_coefficients_A_per_m2=cell.current_coefficients,
                        source_current_native_ids=Tuple(payload.prep.core_ids),
                        psi_global_dof_ids=plan.native_geometry_state_columns),
                     interval_ops=ops,max_interval_ops=max_interval_ops))
                if joint_fan_result.status===:typed_needs_rebuild
                    return (status=:typed_needs_rebuild,reason=:fixedQ_topology_or_quadrature_branch_changed,
                        target_index=payload.prep.target_index,native_cell=cell.native_cell,fan_index=record.fan_index,
                        detail=joint_fan_result,interval_operations=ops[],full64=false,global_closure=false)
                end
                joint_fan_result.status===:rejected_before_contraction &&
                    return (status=:typed_interval_budget_exhausted,reason=:fixedQ_joint_operator_budget_unavailable,
                        target_index=payload.prep.target_index,native_cell=cell.native_cell,fan_index=record.fan_index,
                        detail=joint_fan_result,interval_operations=ops[],full64=false,global_closure=false)
                joint_fan_result.status===:evaluated_same_fixedQ_primal_and_derivative || error("fixed-Q joint B/J callback ABI")
                length(joint_fan_result.B_Q_RZ)==2 && size(joint_fan_result.G_Q_RZ)==(2,128) ||
                    error("fixed-Q joint B/G output shape")
                size(joint_fan_result.G_Q_mapped_angular_error_radius_RZ)==(2,128) &&
                    all(k->all(c->isequal(joint_fan_result.G_Q_mapped_angular_error_radius_RZ[k,c],
                        fr.mapped_angular_error_radius_RZ[k][c]),1:128),1:2) ||
                    error("fixed-Q helper changed/doubled the selected-panel mapped angular radius")
                for k in 1:2
                    joint_field[k]=add(joint_field[k],joint_fan_result.B_Q_RZ[k])
                    for c in 1:128;joint_G[k,c]=add(joint_G[k,c],joint_fan_result.G_Q_RZ[k,c]);end
                end
                size(joint_fan_result.E_Q1_RZ)==(2,4) || error("fixed-Q Q1 source response shape")
                for b in 1:4
                    source_slot=cell.columns[b];source_slot==0 && continue
                    accum=get!(joint_E_Q1,source_slot) do;[z,z];end
                    for k in 1:2;accum[k]=add(accum[k],joint_fan_result.E_Q1_RZ[k,b]);end
                end
                joint_node_count+=length(joint_nodes)
                joint_cost+=joint_fan_result.interval_operation_increment
                push!(joint_branch_records,(native_cell=cell.native_cell,fan_index=record.fan_index,
                    topology_branch=joint_fan_result.topology_branch))
                push!(joint_error_parts,(native_cell=cell.native_cell,fan_index=record.fan_index,
                    B_Q_abs_error_radius_RZ=joint_fan_result.B_Q_abs_error_radius_RZ,
                    E_Q1_abs_error_radius_RZ=joint_fan_result.E_Q1_abs_error_radius_RZ,
                    G_Q_abs_error_radius_RZ=joint_fan_result.G_Q_abs_error_radius_RZ,
                    G_Q_interval_arithmetic_radius_RZ=joint_fan_result.G_Q_interval_arithmetic_radius_RZ,
                    G_Q_mapped_angular_error_radius_RZ=joint_fan_result.G_Q_mapped_angular_error_radius_RZ,
                    G_Q_total_error_handling=:diagnostic_only_global_panel_radius_applied_once))
            end
            if restoring_joint
                # Persist the actual replay receipt as well as its accumulators;
                # a subsequent restore must not read absent/stale legacy joint
                # metadata from a successfully repaired checkpoint.
                slot=findfirst(r->(r.native_cell,r.fan_index)==saved_key,fan_results)
                slot!==nothing || error("restored fixed-Q fan is missing from its saved prefix")
                fan_results[slot]=merge(fan_results[slot],(fixedQ_joint_BJ=
                    (status=joint_fan_result.status,node_count=length(joint_nodes),
                     interval_operation_increment=joint_fan_result.interval_operation_increment,
                     topology_branch=joint_fan_result.topology_branch),))
                fan_results[slot]=_ccp_q1_lcfs_compact_completed_joint_fan(fan_results[slot])
                if resume_fan_checkpoint.fan_results isa Vector{NamedTuple}
                    resume_fan_checkpoint.fan_results[slot]=fan_results[slot]
                end
                delete!(saved_fan_rows,saved_key)
                row=nothing;q=nothing;joint_nodes=nothing;fr=fan_results[slot].result
                recovery_remaining-=1
                if recovery_remaining==0
                    joint_node_count==new_nodes || error("recovered fixed-Q nodes do not cover the saved prefix")
                    emit_fan_checkpoint(joint_recovery=(status=:recovered_actual_saved_fixedQ_joint_prefix,
                        recovered_fans=recovery_total,new_radial_nodes=0,new_integrals=0,new_kernel_calls=0,
                        interval_operation_increment=ops[]-recovery_start))
                end
                continue
            end
            velocity=(fan.target_velocity...,fan.edge_velocities[1]...,fan.edge_velocities[2]...)
            velocity==record.actual_selected_native_velocity || error("saved captured velocity differs")
            fcap=joint_operator_evaluator===nothing ? ntuple(k->begin
                s=z
                for l in 1:6;s=add(s,scale(fr.primitive_geometry_derivative_RZ[l][k],velocity[l]));end
                for b in 1:4;s=add(s,scale(fr.source_basis_RZ[b][k],cell.current_coefficient_direction[b]));end
                s
            end,2) : :typed_absent_unused_diagnostic
            for k in 1:2
                field[k]=add(field[k],fr.weighted_field_RZ[k])
                joint_operator_evaluator===nothing && (captured_direct[k]=add(captured_direct[k],fcap[k]))
                if joint_operator_evaluator===nothing
                    for l in 1:6,c in 1:128
                        iszero(actual_rows[l][c]) && continue
                        G[k,c]=add(G[k,c],scale(fr.primitive_geometry_derivative_RZ[l][k],actual_rows[l][c]))
                    end
                end
                for b in 1:4
                    source_slot=cell.columns[b];source_slot==0 && continue
                    accum=get!(E,source_slot) do;[z,z];end
                    accum[k]=add(accum[k],fr.source_basis_RZ[b][k])
                end
            end
            completed_row=(native_cell=cell.native_cell,fan_index=record.fan_index,source_columns=cell.columns,
                target=fan.target,edge_points=fan.edge_points,primitive_to_polygon_rows=actual_rows,
                captured_selected_native_derivative_RZ=fcap,result=fr,
                fixedQ_joint_BJ=joint_fan_result===nothing ? nothing :
                    (status=joint_fan_result.status,node_count=length(joint_nodes),
                     interval_operation_increment=joint_fan_result.interval_operation_increment,
                     topology_branch=joint_fan_result.topology_branch),
                field_halfwidth_RZ=ntuple(k->halfwidth(fr.weighted_field_RZ[k]),2),
                captured_halfwidth_RZ=joint_operator_evaluator===nothing ? ntuple(k->halfwidth(fcap[k]),2) : :typed_absent_unused_diagnostic)
            if joint_operator_evaluator!==nothing
                completed_row=_ccp_q1_lcfs_compact_completed_joint_fan(completed_row)
                fr=completed_row.result
                joint_nodes=nothing;panels=nothing;panel_nodes=nothing;panel=nothing
            end
            if replay_pending
                pending_nodes_replayed=length(saved_pending_fixedQ_fan.nodes);pending_replay_used=true
                saved_pending_fixedQ_fan=nothing;replay_nodes=nothing
            end
            push!(fan_results,completed_row)
            push!(completed_fan_keys,(record.native_cell,record.fan_index))
            if checkpoint_each_fan
                emit_fan_checkpoint()
            end
        end
        length(fan_results)==length(expected_fans) && new_nodes==8new_panels &&
            new_panels==plan.selected_angular_totals.panels || error("whole ray signed-fan/panel coverage failed")
        if checkpoint_callback!==nothing && !checkpoint_each_fan
            emit_fan_checkpoint()
        end
        # Compose the complete polygon-coordinate block with the saved actual
        # native psi map. Sparse interval entries imply exact zero elsewhere.
        native_columns=plan.native_geometry_state_columns;C=plan.native_geometry_map
        size(C)==(128,length(native_columns)) && length(unique(native_columns))==length(native_columns) &&
            all(c->1<=c<=payload.prep.domain.ndof,native_columns) || error("native geometry map shape/columns")
        selected_native_slot=findfirst(==(selected_state_dof),native_columns)
        selected_native_slot!==nothing && Tuple(C[:,selected_native_slot])==Tuple(payload.coordinate_direction) || error("full native map does not reproduce actual selected-column capture")
        # The compatibility near-J map is unused when the fixed-Q joint
        # operator is active: that path maps its composed G block exactly
        # once below, including the angular radius.
        mapped=joint_operator_evaluator===nothing ?
            Base.invokelatest(x3_near_native_map_float64_enclosure,G,C,native_columns;
                interval_ops=ops,max_interval_ops=max_interval_ops) : nothing
        J=mapped===nothing ? Dict{Int,Vector{Tuple{BigFloat,BigFloat}}}() : mapped.J
        joint_mapped=nothing;joint_J=Dict{Int,Vector{Tuple{BigFloat,BigFloat}}}()
        joint_native_entries=()
        if joint_operator_evaluator!==nothing
            # The fixed-Q callback returns the signed G center intervals and a
            # separate angular radius. Widen only the map input; keep joint_G
            # untouched for its own reported center/arithmetic radius. This
            # propagates C*deltaG exactly once through the existing native-map
            # enclosure, retaining its independent Float64 GEMM roundoff bound.
            joint_G_map_input=copy(joint_G)
            for k in 1:2,c in 1:128
                r=joint_angular_geometry_error[k,c]
                isfinite(r) && r>=0 || error("mapped angular G radius is invalid")
                iszero(r) && continue
                joint_G_map_input[k,c]=(down(()->joint_G[k,c][1]-r),up(()->joint_G[k,c][2]+r))
            end
            joint_mapped=Base.invokelatest(x3_near_native_map_float64_enclosure,joint_G_map_input,C,native_columns;
                interval_ops=ops,max_interval_ops=max_interval_ops)
            # Compose signed-aggregated Q1 coefficient responses with the
            # saved source-current Jacobian exactly once, after all fans.
            S=source_chain.source_current_jacobian_A_per_m2_per_state_dof
            SparseArrays.issparse(S) && size(S)==(length(payload.prep.current),payload.prep.domain.ndof) ||
                error("fixed-Q source native Jacobian shape")
            sr,sc,sv=SparseArrays.findnz(S)
            for i in eachindex(sv)
                haskey(joint_E_Q1,sr[i]) || continue
                accum=get!(joint_source_J,sc[i]) do;[z,z];end
                for k in 1:2;accum[k]=add(accum[k],scale(joint_E_Q1[sr[i]][k],sv[i]));end
            end
            for (native_dof,field_intervals) in joint_source_J
                accum=get!(joint_J,native_dof) do;[z,z];end
                for k in 1:2;accum[k]=add(accum[k],field_intervals[k]);end
            end
            for (native_dof,field_intervals) in joint_mapped.J
                accum=get!(joint_J,native_dof) do;[z,z];end
                for k in 1:2;accum[k]=add(accum[k],field_intervals[k]);end
            end
            joint_native_entries=Tuple((native_dof=c,field_RZ=Tuple(joint_J[c]),
                stored_midpoint=ntuple(k->point_and_radius(joint_J[c][k]),2)) for c in sort!(collect(keys(joint_J))))
        end
        geometry_only_J=mapped===nothing ? :typed_absent_unused_joint_compatibility_map :
            Tuple((native_dof=c,field_RZ=Tuple(J[c])) for c in sort!(collect(keys(J))))
        full_chain=false
        source_modified_columns=Set{Int}()
        if source_chain!==nothing
            source_chain.schema in (:near_source_native_chain_saved_numeric_v1,:near_source_native_chain_actual_state_v1) || error("actual source-chain receipt required")
            source_chain.selected_state_dof==selected_state_dof &&
                source_chain.source_current_law===:same_state_GS4_profile_Jphi_on_actual_clipped_Q1_support || error("source-chain selected state/law differs")
            id=full_geometry.capture_identity
            string(source_chain.candidate_hash)==string(id.candidate_hash) && string(source_chain.context_hash)==string(id.context_hash) &&
                string(source_chain.trace_hash)==string(id.trace_hash) || error("source-chain actual identity differs")
            Tuple(source_chain.source_current_native_ids)==Tuple(payload.prep.core_ids) &&
                Tuple(source_chain.core_current_A_per_m2)==Tuple(payload.prep.current) &&
                Tuple(source_chain.selected_dcurrent_A_per_m2)==Tuple(payload.prep.dcurrent) &&
                source_chain.max_abs_Jsource_direction_difference_A_per_m2==0 || error("source-current row/direction binding differs")
            Tuple(source_chain.selected_geometry_direction_from_map_m)==Tuple(payload.coordinate_direction) &&
                Tuple(source_chain.selected_geometry_direction_from_capture_m)==Tuple(payload.coordinate_direction) || error("source receipt geometry direction differs")
            S=source_chain.source_current_jacobian_A_per_m2_per_state_dof
            SparseArrays.issparse(S) && size(S)==(length(payload.prep.current),payload.prep.domain.ndof) || error("source-native Jacobian shape")
            rr,cc,vv=SparseArrays.findnz(S)
            for i in eachindex(vv)
                haskey(E,rr[i]) || continue
                push!(source_modified_columns,cc[i])
                accum=get!(J,cc[i]) do;[z,z];end
                for k in 1:2;accum[k]=add(accum[k],scale(E[rr[i]][k],vv[i]));end
            end
            full_chain=true
        end
        captured_mapped=ntuple(k->begin
            s=z
            for c in 1:128;s=add(s,scale(G[k,c],payload.coordinate_direction[c]));end
            for c in sort!(collect(keys(E)));s=add(s,scale(E[c][k],payload.prep.dcurrent[c]));end
            s
        end,2)
        # Original stored Float64 near E/G matrices are treated as exact inputs
        # to this comparison; enclosing their real contractions does not certify
        # later whole-consumer BLAS rounding or far/PF/TF terms.
        comparison_available=hasproperty(payload,:production_E) && hasproperty(payload,:production_G) &&
            payload.production_E!==nothing && payload.production_G!==nothing
        original_field=:typed_absent;original_captured=:typed_absent
        original_field_distance=:typed_absent;original_captured_distance=:typed_absent
        if comparison_available
        size(payload.production_E)==(2,length(payload.prep.current)) && size(payload.production_G)==(2,128) || error("original near response shapes")
        original_field=ntuple(k->begin
            s=z
            for c in eachindex(payload.prep.current);s=add(s,scale(exact(payload.production_E[k,c]),payload.prep.current[c]));end
            s
        end,2)
        original_captured=ntuple(k->begin
            s=z
            for c in eachindex(payload.prep.dcurrent);s=add(s,scale(exact(payload.production_E[k,c]),payload.prep.dcurrent[c]));end
            for c in 1:128;s=add(s,scale(exact(payload.production_G[k,c]),payload.coordinate_direction[c]));end
            s
        end,2)
        original_field_distance=ntuple(k->absup(sub(original_field[k],field[k])),2)
        original_captured_distance=ntuple(k->absup(sub(original_captured[k],captured_mapped[k])),2)
        end
        proposed_field=ntuple(k->point_and_radius(field[k]),2)
        proposed_captured=ntuple(k->point_and_radius(captured_mapped[k]),2)
        J_entries=Tuple((native_dof=c,field_RZ=Tuple(J[c]),
            stored_midpoint=c in source_modified_columns ? ntuple(k->point_and_radius(J[c][k]),2) : mapped.stored_midpoints[c])
            for c in sort!(collect(keys(J))))
        E_entries=Tuple((source_slot=c,native_core_id=payload.prep.core_ids[c],field_RZ=Tuple(E[c])) for c in sort!(collect(keys(E))))
        proposed_E=zeros(Float64,2,length(payload.prep.current));proposed_E_bound=fill(BigFloat(0),size(proposed_E))
        proposed_G=zeros(Float64,2,128);proposed_G_bound=fill(BigFloat(0),size(proposed_G))
        for c in keys(E),k in 1:2
            q=point_and_radius(E[c][k]);proposed_E[k,c]=q.value;proposed_E_bound[k,c]=q.absolute_error_upper
        end
        for c in 1:128,k in 1:2
            q=point_and_radius(G[k,c]);proposed_G[k,c]=q.value;proposed_G_bound[k,c]=q.absolute_error_upper
        end
        function matrix_error_measure(values,bounds)
            reflo=BigFloat(0);refhi=BigFloat(0);errhi=BigFloat(0)
            for i in eachindex(values)
                if !iszero(values[i])
                    v=exact(values[i]);lo=down(()->v[1]*v[1]);hi=up(()->v[1]*v[1])
                    reflo=down(()->reflo+lo);refhi=up(()->refhi+hi)
                end
                if !iszero(bounds[i]);s=up(()->bounds[i]*bounds[i]);errhi=up(()->errhi+s);end
            end
            rlo=down(()->sqrt(reflo));rhi=up(()->sqrt(refhi));ehi=up(()->sqrt(errhi))
            ratio=rlo>0 ? up(()->ehi/rlo) : ehi==0 ? BigFloat(0) : :typed_absent_zero_reference
            (reference_Frobenius_norm_lower=rlo,reference_Frobenius_norm_upper=rhi,
             error_Frobenius_norm_upper=ehi,relative_error_upper=ratio,
             scope=:single_ray_near_block_not_full64_or_full_B_out)
        end
        E_measure=matrix_error_measure(proposed_E,proposed_E_bound)
        G_measure=matrix_error_measure(proposed_G,proposed_G_bound)
        field_width=ntuple(k->halfwidth(field[k]),2);G_width=ntuple(k->halfwidth(captured_mapped[k]),2)
        direct_map_difference=ntuple(k->sub(captured_direct[k],captured_mapped[k]),2)
        joint_selected_derivative=joint_operator_evaluator===nothing ? :typed_absent :
            Tuple(get(joint_J,selected_state_dof,(z,z)))
        reported_selected_derivative=joint_operator_evaluator===nothing ? captured_mapped : joint_selected_derivative
        reported_proposed_captured=ntuple(k->point_and_radius(reported_selected_derivative[k]),2)
        reported_captured_width=ntuple(k->halfwidth(reported_selected_derivative[k]),2)
        joint_G_interval_arithmetic_radius=joint_operator_evaluator===nothing ? :typed_absent :
            [halfwidth(joint_G[k,c]) for k in 1:2,c in 1:128]
        joint_G_total_error_radius=joint_operator_evaluator===nothing ? :typed_absent :
            [up(()->joint_G_interval_arithmetic_radius[k,c]+joint_angular_geometry_error[k,c])
                for k in 1:2,c in 1:128]
        (status=:evaluated_actual_signed_fan_integral,target_index=payload.prep.target_index,target_indices=(payload.prep.target_index,),
         selected_state_dof=selected_state_dof,
         field_components=(:Br,:Bz),response_scope=:prepared_near_target_cut_cells_only,
         polygon_coordinate_order=:ray_major_R_then_Z_128_coordinates,native_state_column_order=:component_full_state_dof_order,
         source_current_native_ids=Tuple(payload.prep.core_ids),original_leaf_count=invt.original_leaf_count,signed_fan_count=invt.target_fan_count,
         nonzero_fan_count=length(expected_fans),qualified_identically_zero_fan_count=invt.zero_area_fan_count,complete_signed_coverage=true,
         angular_panel_count=new_panels,new_angular_panels=new_panels,new_radial_nodes=new_nodes,reused_complete_worst_nodes=0,
         saved_pending_radial_nodes_replayed=pending_nodes_replayed,
         actual_fresh_radial_node_evaluations=new_nodes-
            (resume_fan_checkpoint===nothing ? 0 : resume_fan_checkpoint.new_nodes)-pending_nodes_replayed,
         nonreused_elliptic_order=2,nonreused_radial_order=6,fan_results=Tuple(fan_results),
         weighted_field_RZ=Tuple(field),captured_selected_native_derivative_RZ=reported_selected_derivative,
         selected_state_projection_of_fixedQ_joint_J_Q=joint_selected_derivative,
         captured_direct_fan_projection_RZ=joint_operator_evaluator===nothing ? Tuple(captured_direct) : joint_selected_derivative,
         legacy_captured_direct_fan_projection_RZ=Tuple(captured_direct),direct_minus_fullmap_interval_RZ=direct_map_difference,
         source_response_intervals=E_entries,source_response_shape=(2,length(payload.prep.current)),
         polygon_geometry_derivative_intervals=G,native_geometry_only_intervals=geometry_only_J,
         native_geometry_map_arithmetic=mapped===nothing ? :typed_absent_unused_joint_compatibility_map : mapped.metadata,
         proposed_E_response_T_per_A_m2=proposed_E,proposed_E_error_bound_T_per_A_m2=proposed_E_bound,
         proposed_G_geometry_T_per_polygon_coordinate=proposed_G,
         proposed_G_error_bound_T_per_polygon_coordinate=proposed_G_bound,
         proposed_near_E_error_measure=E_measure,proposed_near_G_error_measure=G_measure,
         E_operator_subbudget_passed=get(plan,:operator_budget_enabled,false) ? E_measure.error_Frobenius_norm_upper<=plan.E_frobenius_tolerance : :not_requested,
         G_operator_subbudget_passed=get(plan,:operator_budget_enabled,false) ? G_measure.error_Frobenius_norm_upper<=plan.G_frobenius_tolerance : :not_requested,
         proposed_E_G_measures_are_full64_acceptance=false,
         native_state_J_intervals=J_entries,native_state_J_shape=(2,payload.prep.domain.ndof),unlisted_native_entries_exact_zero=full_chain,
         native_state_J_interval_scope=full_chain ? :complete_near_source_and_geometry : :geometry_only_source_typed_absent,
         full_native_source_and_geometry_chain_assembled=full_chain,
         full_native_J_error_budget=:typed_absent_no_all_native_column_tolerances_supplied,
         full_native_J_scientific_acceptance=:typed_absent,original_whole_consumer_float_rounding=:typed_absent,
         proposed_stored_field_RZ=proposed_field,proposed_stored_captured_derivative_RZ=reported_proposed_captured,
         field_halfwidth_RZ=field_width,captured_halfwidth_RZ=reported_captured_width,
         field_enclosure_within_original_allowance=all(x->x.absolute_error_upper<=plan.field_tolerance,proposed_field),
         captured_enclosure_within_original_allowance=joint_operator_evaluator===nothing ?
            all(x->x.absolute_error_upper<=plan.captured_direction_tolerance,proposed_captured) :
            :typed_absent_fixedQ_interval_excludes_separate_angular_truncation_error,
         original_stored_near_E_current_real_contraction_RZ=original_field,
         original_stored_near_E_dcurrent_plus_G_dx_real_contraction_RZ=original_captured,
         original_near_field_distance_upper_RZ=original_field_distance,original_near_captured_distance_upper_RZ=original_captured_distance,
         original_comparison_status=comparison_available ? :evaluated_real_contraction : :typed_absent,
         original_near_field_distance_within_allowance=comparison_available ? all(x->x<=plan.field_tolerance,original_field_distance) : :typed_absent,
         original_near_captured_distance_within_allowance=comparison_available ? all(x->x<=plan.captured_direction_tolerance,original_captured_distance) : :typed_absent,
         fixedQ_joint_operator=joint_operator_evaluator===nothing ?
            (status=:typed_absent,reason=:fixedQ_postprocessor_not_supplied) :
            (status=:evaluated_fixedQ_joint_BJ,target_index=payload.prep.target_index,
             source_current_native_ids=Tuple(payload.prep.core_ids),B_Q_RZ=Tuple(joint_field),
             E_Q1_RZ=Tuple((source_slot=c,native_core_id=payload.prep.core_ids[c],field_RZ=Tuple(joint_E_Q1[c]))
                for c in sort!(collect(keys(joint_E_Q1)))),
             G_Q_RZ=joint_G,native_state_J_intervals=joint_native_entries,
             B_Q_abs_error_radius_RZ=ntuple(k->halfwidth(joint_field[k]),2),
             B_Q_angular_error_radius_RZ=:reused_from_existing_signed_fan_angular_contract,
             E_Q1_abs_error_radius_by_source_slot=Tuple((source_slot=c,radius_RZ=ntuple(k->halfwidth(joint_E_Q1[c][k]),2))
                for c in sort!(collect(keys(joint_E_Q1)))),
             G_Q_abs_error_radius_RZ=joint_G_total_error_radius,
             G_Q_interval_arithmetic_radius_RZ=joint_G_interval_arithmetic_radius,
             G_Q_mapped_angular_error_radius_RZ=ntuple(k->Tuple(joint_angular_geometry_error[k,c] for c in 1:128),2),
             G_Q_total_radius_composition=:interval_arithmetic_plus_mapped_angular_once,
             mapped_angular_support=Tuple(sort!(collect(joint_angular_geometry_support))),
             mapped_angular_error_scope=:per_polygon_coordinate_q8_peano_plus_stored_rule_drift,
             mapped_angular_error_composed_with_numerical=:included_once_in_G_radius_and_native_C_interval_input,
             mapped_angular_geometry_receipt=mapped_geometry_receipt,
             native_C_map_arithmetic=joint_operator_evaluator===nothing ? :typed_absent : joint_mapped.metadata,
             native_J_mapped_angular_radius_included=true,
             J_Q_abs_error_radius_by_native_dof=Tuple((native_dof=c,radius_RZ=ntuple(k->halfwidth(joint_J[c][k]),2))
                for c in sort!(collect(keys(joint_J)))),
             componentwise_error_parts_by_fan=Tuple(joint_error_parts),
             native_state_J_shape=(2,payload.prep.domain.ndof),joint_node_count=joint_node_count,
             joint_postprocessor_interval_operations=joint_cost,
             interval_operations=ops[],authorized_interval_cap=max_interval_ops,
             topology_branch_by_fan=Tuple(joint_branch_records),actual_fixed_clipping_topology_verified=true,
             fixed_reference_nodes_and_weights=true,physical_node_motion_in_primitive_chain=true,
             source_current_motion_in_native_chain=true,continuous_hadamard_used_as_B_Q=false,
             angular_quadrature_certified=false,full64=false,global_closure=false),
         field_tolerance=plan.field_tolerance,captured_direction_tolerance=plan.captured_direction_tolerance,
         prior_qualification_and_plan_interval_operations=origin,new_interval_operations=ops[]-origin,interval_operations=ops[],
         original_interval_cap=8_000_000,authorized_interval_cap=max_interval_ops,original_8M_budget_passed=ops[]<=8_000_000,
         authorized_interval_budget_passed=ops[]<=max_interval_ops,prior_kernel_calls=payload.kernel_calls_before_join,new_kernel_calls=0,
         cumulative_kernel_calls=payload.kernel_calls_before_join,max_kernel_calls=min(payload.max_kernel_calls,40_000_000),
         reused_plan_angular_proofs_already_in_prior_ledger=true,actual_full_ray_near_integral_evaluated=true,
         actual_full64_rays_evaluated=false,full_B_out_consumer_certified=false,global_closure=false)
    end
end

# A single-ray producer. Its caller must bind the numeric payload and supplied
# full geometry/source maps to the same actual state. No closure is serialized,
# no solver is invoked, and this function does not loop or certify all 64 rays.
Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_signed_fan_near_response(payload,polygon,native_geometry,source_chain,rule_record;
        capture_identity,field_tolerance,captured_direction_tolerance,max_interval_ops,
        interval_ops=Ref(0),E_frobenius_tolerance=nothing,G_frobenius_tolerance=nothing,
        joint_operator_evaluator=nothing,mapped_geometry_receipt=nothing,
        _moment_arithmetic_backend=nothing,checkpoint_callback=nothing,
        resume_fan_checkpoint=nothing,checkpoint_each_fan=false,
        angular_bound_evaluator=nothing,planning_checkpoint_callback=nothing,candidate_replay=nothing,
        plan_only=false)
    Base.@nospecialize payload polygon native_geometry source_chain rule_record
    payload.schema in (:near_cut_q8_numeric_replay_v1,:near_signed_fan_prepared_numeric_v1) || error("actual near numeric payload required")
    payload.schema===:near_signed_fan_prepared_numeric_v1 && (hasproperty(payload,:production_E) || hasproperty(payload,:production_G)) && error("direct production payload cannot carry an unbound old comparison")
    p=payload.prep;1<=p.target_index<=64 || error("target outside actual 64-ray polygon")
    max_interval_ops in (8_000_000,24_000_000) || error("explicit authorized per-ray cap required")
    0<=interval_ops[]<max_interval_ops || error("invalid cumulative interval ledger")
    0<=payload.kernel_calls_before_join<=min(payload.max_kernel_calls,40_000_000) || error("shared kernel cap")
    selected_state_dof=source_chain.selected_state_dof
    1<=selected_state_dof<=p.domain.ndof && length(p.state_direction)==p.domain.ndof &&
        count(!iszero,p.state_direction)==1 && p.state_direction[selected_state_dof]==1.0 ||
        error("payload must bind the declared one-hot native direction")
    source_chain.schema in (:near_source_native_chain_saved_numeric_v1,:near_source_native_chain_actual_state_v1) || error("source-chain ABI")
    all(k->string(getproperty(capture_identity,k))==string(getproperty(source_chain,k)),
        (:candidate_hash,:context_hash,:trace_hash)) || error("actual source identity differs")
    source_chain.source_current_law===:same_state_GS4_profile_Jphi_on_actual_clipped_Q1_support || error("source law differs")
    Tuple(source_chain.source_current_native_ids)==Tuple(p.core_ids) &&
        Tuple(source_chain.core_current_A_per_m2)==Tuple(p.current) &&
        Tuple(source_chain.selected_dcurrent_A_per_m2)==Tuple(p.dcurrent) &&
        source_chain.max_abs_Jsource_direction_difference_A_per_m2==0 || error("actual source rows/current/direction differ")
    Tuple(source_chain.selected_geometry_direction_from_map_m)==Tuple(payload.coordinate_direction) &&
        Tuple(source_chain.selected_geometry_direction_from_capture_m)==Tuple(payload.coordinate_direction) ||
        error("source receipt geometry direction differs")
    S=source_chain.source_current_jacobian_A_per_m2_per_state_dof
    SparseArrays.issparse(S) && size(S)==(length(p.current),p.domain.ndof) || error("source native Jacobian shape")
    length(polygon)==64 && Tuple(Tuple(x) for x in polygon)==Tuple(Tuple(x) for x in native_geometry.coordinates_RZ_m) ||
        error("polygon and actual native geometry differ")
    rule_record.schema=="actual-R4-Cauchy-Gauss8-rule-checkpoint-v1" || error("qualified Q8 receipt required")
    rule_record.interval_operations>=rule_record.qualified_rule.interval_operations>=0 || error("Q8 qualification ledger differs")
    interval_ops[]<=max_interval_ops-rule_record.interval_operations || error("rule qualification exhausts cap")
    # Charge the existing rule qualification once in this call's cumulative
    # ledger; every subsequent exact/interval operation shares the same Ref.
    entry_start_operations=interval_ops[]
    interval_ops[]+=rule_record.interval_operations
    geometry=Base.invokelatest(near_signed_fan_geometry_maps,@__MODULE__,payload,Tuple(Tuple(x) for x in polygon))
    inventory=Base.invokelatest(near_signed_cell_fan_inventory,@__MODULE__,payload;interval_ops=interval_ops,
        max_interval_ops=max_interval_ops,full_vertex_motion_key=(ci,pi,ti,vi)->near_signed_fan_motion_key(geometry,ci,pi,ti,vi))
    zero_aliases=Base.invokelatest(near_signed_fan_qualify_zero_aliases,geometry,inventory)
    full_geometry=(schema=:actual_full128_zero_fan_alias_v1,geometry=geometry,inventory=inventory,
        zero_aliases=zero_aliases,capture_identity=capture_identity)
    plan=Base.invokelatest(_ccp_q1_lcfs_signed_fan_plan,payload,full_geometry,native_geometry,rule_record;
        selected_state_dof=selected_state_dof,interval_ops=interval_ops,max_interval_ops=max_interval_ops,
        field_tolerance=field_tolerance,captured_direction_tolerance=captured_direction_tolerance,
        E_frobenius_tolerance=E_frobenius_tolerance,G_frobenius_tolerance=G_frobenius_tolerance,
        angular_bound_evaluator=angular_bound_evaluator,checkpoint_callback=planning_checkpoint_callback,
        candidate_replay=candidate_replay)
    if plan_only
        return (status=:prepared_actual_signed_fan_plan,target_index=p.target_index,
            angular_plan=plan,full_geometry=full_geometry,
            capture_identity=capture_identity,interval_operations=interval_ops[],
            new_integral_calls=0,new_kernel_calls=0,full64=false,global_closure=false)
    end
    if !plan.angular_planning_target_met
        return (status=:typed_absent,reason=:finite_signed_fan_angular_candidates_exhausted,
            target_index=p.target_index,plan=plan,interval_operations=interval_ops[],global_closure=false)
    end
    result=Base.invokelatest(_ccp_q1_lcfs_signed_fan_integral,payload,full_geometry,plan,rule_record;
        selected_state_dof=selected_state_dof,source_chain=source_chain,
        interval_ops=interval_ops,max_interval_ops=max_interval_ops,
        joint_operator_evaluator=joint_operator_evaluator,mapped_geometry_receipt=mapped_geometry_receipt,
        _moment_arithmetic_backend=_moment_arithmetic_backend,checkpoint_callback=checkpoint_callback,
        resume_fan_checkpoint=resume_fan_checkpoint,checkpoint_each_fan=checkpoint_each_fan)
    merge(result,(angular_plan=plan,zero_alias_proof=zero_aliases,geometry_inventory=inventory,
        capture_identity=capture_identity,entry_start_interval_operations=entry_start_operations,
        shared_rule_qualification_operations_charged=rule_record.interval_operations,
        new_interval_operations_this_call=interval_ops[]-entry_start_operations-rule_record.interval_operations,
        interval_budget_scope=max_interval_ops==8_000_000 ? :single_ray_original_8M :
            :single_ray_24M_authorized_not_original_8M_or_batch_total,
        canonical_algorithm=:signed_fan_radial_N2M6_Q8_finite_angular_v1))
end
# Bound by the production component closure below. Its record is admitted in
# that component's coordinate system before any geometry/current is evaluated.
# Its real exact-PF geometry work is charged once and reused by every target of
# this same state. R4 records are not inputs to this construction.
Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_signed_fan_state_inputs(domain,state_record,identity;kernel_calls_ref,max_kernel_calls=40_000_000,pf_ring_evaluations_ref=Ref(0))
    Base.@nospecialize domain state_record identity
    max_kernel_calls==40_000_000 && 0<=kernel_calls_ref[]<=max_kernel_calls || error("shared batch kernel cap")
    calls_before=kernel_calls_ref[];rings_before=pf_ring_evaluations_ref[]
    x=_ccp_full_native_admit_toroidal_state_record(domain,state_record)
    geometry=_ccp_full_native_dynamic_geometry(domain.dynamic_geometry_data,x;
        model_id=_ccp_native_geometry_model_id(domain.native_field_model_id),kernel_calls_ref=kernel_calls_ref,max_kernel_calls=max_kernel_calls,
        pf_ring_evaluations_ref=pf_ring_evaluations_ref)
    geometry.status===:evaluated_dynamic_LCFS_geometry && geometry.mask_event===:unchanged ||
        return (status=:typed_absent,reason=:actual_state_geometry_unavailable,geometry=geometry,kernel_calls=kernel_calls_ref[]-calls_before)
    cache=(domain=domain,state=copy(x),geometry=geometry)
    x=_ccp_full_native_checked_state(domain,x;geometry_cache=cache,kernel_calls_ref=kernel_calls_ref,max_kernel_calls=max_kernel_calls)
    length(geometry.coordinates_RZ_m)==64 || error("actual polygon must have 64 targets")
    _ccp_full_profile_law_supported(domain.law) || error("unsupported actual source law")
    core_ids=findall(domain.mask);isempty(core_ids) && error("actual source support empty")
    span=_ccp_full_native_profile_span(domain,x)
    u,v=domain.vary_profile_coefficients ?
        (x[domain.coefficient_columns[1]],x[domain.coefficient_columns[2]]) : domain.accepted_coefficients
    S=_ccp_q1_lcfs_profile_source_native_jacobian(domain,x,core_ids,span,u,v)
    all(isfinite,S.nzval) || error("actual source Jacobian nonfinite")
    current=Float64[_ccp_q1_lcfs_profile_source_row(domain,x,k,span,u,v;need_current=true).current for k in core_ids]
    all(isfinite,current) || error("actual source current nonfinite")
    (status=:prepared_actual_state_signed_fan_inputs,domain=domain,state=copy(x),
        state_coordinate_id=state_record.state_coordinate_id,identity=identity,
        geometry=geometry,geometry_cache=cache,source_current_native_ids=Tuple(core_ids),source_current_jacobian=S,
        source_current_A_per_m2=current,
        kernel_calls=kernel_calls_ref[]-calls_before,geometry_kernel_calls=kernel_calls_ref[]-calls_before,
        cumulative_kernel_calls=kernel_calls_ref[],kernel_count_unit=:exact_PF_jet_provider_call,
        geometry_pf_ring_evaluations=pf_ring_evaluations_ref[]-rings_before,
        new_near_integral_field_calls=0,all_rays_evaluated=false,global_closure=false)
end

# Select a real native psi column which moves both this target and the source.
# Keep the existing moving-prepare diagnostic prerequisites unchanged. The full
# G128 and native J remain independent of this one regression-direction choice.
Base.@noinline Base.@nospecializeinfer function _ccp_q1_lcfs_signed_fan_prepare_target(inputs,target_index;
        selected_state_dof=nothing,kernel_calls_ref,max_kernel_calls=40_000_000,old_comparison=nothing)
    Base.@nospecialize inputs
    old_comparison===nothing || error("direct production accepts no unbound old E/G comparison")
    inputs.status===:prepared_actual_state_signed_fan_inputs || error("actual component state inputs required")
    1<=target_index<=64 || error("target outside actual polygon")
    max_kernel_calls==40_000_000 && 0<=kernel_calls_ref[]<=max_kernel_calls || error("shared whole-batch kernel cap")
    domain=inputs.domain;x=inputs.state;geometry=inputs.geometry;S=inputs.source_current_jacobian
    columns=geometry.psi_global_dof_ids;C=geometry.coordinate_jacobian
    size(C)==(128,length(columns)) || error("actual native coordinate map shape")
    if selected_state_dof===nothing
        best=0;motion=0.0
        for (j,c) in enumerate(columns)
            any(i->!iszero(S.nzval[i]),SparseArrays.nzrange(S,c)) || continue
            m=hypot(C[2target_index-1,j],C[2target_index,j])
            if m>motion;motion=m;best=c;end
        end
        best>0 || return (status=:typed_absent,reason=:no_joint_target_source_native_direction,target_index=target_index,kernel_calls=0)
        selected_state_dof=best
    end
    1<=selected_state_dof<=domain.ndof || error("selected native column outside domain")
    direction=zeros(Float64,domain.ndof);direction[selected_state_dof]=1.0
    prep=_ccp_q1_lcfs_moving_geometry_directional_prepare(domain,x,direction,target_index;
        geometry_cache=inputs.geometry_cache,kernel_calls_ref=kernel_calls_ref,max_kernel_calls=max_kernel_calls)
    prep.status===:prepared || return prep
    prep.state==x && prep.domain===domain && prep.target_index==target_index &&
        prep.target==geometry.coordinates_RZ_m[target_index] &&
        Tuple(prep.core_ids)==inputs.source_current_native_ids || error("actual state/preparation binding differs")
    coordinate_direction=_ccp_full_native_coordinate_direction(geometry,direction)
    jdirection=Vector(S*direction)
    maxdiff=maximum(abs,jdirection-prep.dcurrent)
    # Do not replace a measured discrepancy by a tolerance or by a literal zero.
    maxdiff==0 || return (status=:typed_absent,reason=:source_native_direction_not_exact,
        maximum_difference=maxdiff,target_index=target_index,kernel_calls=0)
    coverage=Tuple((target_index,prep.prepared_cells[cp.cell_index].native_cell,
        pp.piece_index,t.triangle_index,t.child_path) for cp in prep.quadrature_partition if cp.near_target
        for pp in cp.pieces for t in pp.triangles)
    length(unique(coverage))==length(coverage)>0 || error("actual near affine leaf coverage is empty/duplicated")
    # prep contains the existing actual chart data. No E/G term is required to
    # define its source inventory, and no zero response placeholder is emitted.
    payload=(schema=:near_signed_fan_prepared_numeric_v1,prep=prep,
        source_coverage_ids=coverage,coordinate_direction=coordinate_direction,
        kernel_calls_before_join=kernel_calls_ref[],max_kernel_calls=max_kernel_calls)
    chain=(schema=:near_source_native_chain_actual_state_v1,
        candidate_hash=inputs.identity.candidate_hash,context_hash=inputs.identity.context_hash,trace_hash=inputs.identity.trace_hash,
        selected_state_dof=selected_state_dof,source_current_law=:same_state_GS4_profile_Jphi_on_actual_clipped_Q1_support,
        source_current_native_ids=Tuple(prep.core_ids),core_current_A_per_m2=copy(prep.current),
        source_current_jacobian_A_per_m2_per_state_dof=S,selected_dcurrent_A_per_m2=copy(prep.dcurrent),
        max_abs_Jsource_direction_difference_A_per_m2=maxdiff,
        selected_geometry_direction_from_map_m=coordinate_direction,selected_geometry_direction_from_capture_m=coordinate_direction)
    (status=:prepared_actual_target_signed_fan_inputs,target_index=target_index,payload=payload,
        source_chain=chain,native_geometry=geometry,capture_identity=inputs.identity,
        state_coordinate_id=inputs.state_coordinate_id,kernel_calls=0,new_field_calls=0,global_closure=false)
end
