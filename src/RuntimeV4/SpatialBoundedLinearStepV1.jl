"""Versioned lower-bounded linearized step; no physical residual is changed.

The production adapter supplies A = diag(1/row_scale)*J*diag(column_scale),
r = residual/row_scale, and lower[p] = -pressure/pressure_scale. All other
lower bounds are -Inf. Thus s and lower are dimensionless and the state update
is column_scale .* s. Zero must be feasible. This module does not perform the
nonlinear line search, change outer budgets, or certify physical closure.
"""
module SpatialBoundedLinearStepV1
using LinearAlgebra, SparseArrays, SHA

export bounded_linear_step_policy_v1, bounded_linear_step_identity_v1,
       solve_lower_bounded_step_v1, bounded_step_kkt_v1, bounded_linear_step_snapshot_v1

const SOURCE_SHA256 = bytes2hex(SHA.sha256(read(@__FILE__)))
const METHOD = :lower_bounded_sparse_QR_active_set_v1

"Frozen numerical policy for the inner linear problem, not the physical gate."
bounded_linear_step_policy_v1() = (
    revision="spatial-bounded-linear-step-policy-v1", method=METHOD,
    rank_relative_tolerance=1.0e-10, kkt_absolute_tolerance=1.0e-10,
    kkt_roundoff_factor=64.0, feasibility_roundoff_factor=8.0,
    inner_iteration_factor=8, inner_iteration_offset=16,
    inner_budget_rule=:factor_times_columns_plus_offset,
    factorization=:sparse_QR_no_normal_equations_no_regularization,
    bound_semantics=:scaled_step_lower_bounds_zero_feasible,
    tie_rule=:lowest_column_index, nonlinear_acceptance=:caller_original_Armijo)

bounded_linear_step_identity_v1() = (method=METHOD, policy=bounded_linear_step_policy_v1(),
    implementation_sha256=SOURCE_SHA256, scope=:linearized_subproblem_only)

finite_or_nothing(x) = isfinite(x) ? x : nothing
maxabs(x) = maximum(abs,x;init=0.0)

function _sbls_trace_event_v1(trace, name, edge)
    trace === nothing && return nothing
    try
        trace(name, edge, time_ns())
    catch err
        detail = try
            sprint(showerror, err)
        catch
            string(typeof(err))
        end
        try
            println(stderr, "SMGW_TRACE_INCOMPLETE name=", name, " edge=", edge,
                " reason=", detail)
            flush(stderr)
        catch
        end
    end
    nothing
end

function checked_inputs(A,r,lower,policy)
    policy == bounded_linear_step_policy_v1() || throw(ArgumentError("unsupported bounded-step policy"))
    A isa AbstractMatrix && r isa AbstractVector && lower isa AbstractVector ||
        throw(ArgumentError("matrix and vector inputs required"))
    m,n=size(A);m>0 && n>0 && length(r)==m && length(lower)==n ||
        throw(ArgumentError("bounded-step dimensions mismatch or empty problem"))
    eltype(A)<:Real && eltype(r)<:Real && eltype(lower)<:Real ||
        throw(ArgumentError("real bounded-step inputs required"))
    AA=sparse(Float64.(A));rr=Float64.(r);ll=Float64.(lower)
    all(isfinite,nonzeros(AA)) && all(isfinite,rr) || throw(ArgumentError("nonfinite A or r"))
    all(v->isfinite(v) || v == -Inf,ll) || throw(ArgumentError("lower bounds must be finite or -Inf"))
    all(v->v<=0.0,ll) || throw(ArgumentError("zero step must be feasible"))
    AA,rr,ll
end

function kkt_audit(A,r,lower,s,working,policy;matrix_one_norm_cache=nothing)
    model=A*s+r;q=transpose(A)*model
    free=findall(!,working);active=findall(identity,working)
    matrix_one_norm = if matrix_one_norm_cache === nothing
        opnorm(A,1)
    else
        cached=matrix_one_norm_cache[]
        if cached === nothing
            cached=opnorm(A,1)
            matrix_one_norm_cache[]=cached
        end
        cached
    end
    scale=max(1.0,matrix_one_norm*max(maxabs(model),maxabs(r)))
    tolerance=policy.kkt_absolute_tolerance
    roundoff_floor=policy.kkt_roundoff_factor*eps(Float64)*scale
    finite=all(isfinite,s) && all(isfinite,model) && all(isfinite,q) && isfinite(roundoff_floor)
    finite || return (finite=false,passed=false,gradient=Tuple(finite_or_nothing.(q)),
        tolerance=tolerance,roundoff_floor=finite_or_nothing(roundoff_floor),free_stationarity=nothing,lower_dual_violation=nothing,
        primal_violation=nothing,primal_tolerance=nothing,working_bound_error=nothing,
        primal_coordinate_tolerances=(),primal_feasible=false,working_bounds_satisfied=false,
        complementarity=nothing,scaled_complementarity=nothing,objective=nothing)
    finite_bounds=findall(isfinite,lower)
    primal=maximum((max(0.0,lower[i]-s[i]) for i in finite_bounds);init=0.0)
    coordinate_tolerance(i)=policy.feasibility_roundoff_factor*eps(Float64)*max(1.0,abs(s[i]),abs(lower[i]))
    ptol=maximum((coordinate_tolerance(i) for i in finite_bounds);init=0.0)
    primal_feasible=all(i->s[i]>=lower[i]-coordinate_tolerance(i),finite_bounds)
    binding_feasible=all(i->abs(s[i]-lower[i])<=coordinate_tolerance(i),active)
    binding_error=maximum((abs(s[i]-lower[i]) for i in active);init=0.0)
    stationarity=maxabs(q[free]);dual=maximum((max(0.0,-q[i]) for i in active);init=0.0)
    complementarity=maximum((abs((s[i]-lower[i])*q[i]) for i in finite_bounds);init=0.0)
    scaled_comp=maximum((abs((s[i]-lower[i])*q[i])/max(1.0,abs(s[i]-lower[i])) for i in finite_bounds);init=0.0)
    objective=dot(model,model)/2
    finite &= all(isfinite,(primal,ptol,binding_error,stationarity,dual,complementarity,scaled_comp,objective))
    passed=finite && primal_feasible && binding_feasible && stationarity<=tolerance &&
        dual<=tolerance && scaled_comp<=tolerance
    (finite=finite,passed=passed,gradient=Tuple(finite_or_nothing.(q)),tolerance=tolerance,roundoff_floor=roundoff_floor,
        free_stationarity=finite_or_nothing(stationarity),lower_dual_violation=finite_or_nothing(dual),
        primal_violation=finite_or_nothing(primal),primal_tolerance=finite_or_nothing(ptol),
        working_bound_error=finite_or_nothing(binding_error),complementarity=finite_or_nothing(complementarity),
        primal_coordinate_tolerances=Tuple((index=i,tolerance=coordinate_tolerance(i)) for i in finite_bounds),
        primal_feasible=primal_feasible,working_bounds_satisfied=binding_feasible,
        scaled_complementarity=finite_or_nothing(scaled_comp),objective=finite_or_nothing(objective))
end

# A full-rank sparse QR may be downdated after one bound binds. The original
# SPQR factor remains the orthogonal base; Givens rotations update R and are
# replayed on Q'b. Uncertain rank or active-set decisions force canonical SPQR.
mutable struct _SBLSDowndateCacheV1
    base::Any
    R::Union{Nothing,Matrix{Float64}}
    rotations::Vector{Tuple{Int,Float64,Float64}}
    pivoted_columns::Vector{Int}
    free_columns::Vector{Int}
    updates::Int
    projected_rhs::Union{Nothing,Vector{Float64}}
    rhs_snapshot::Union{Nothing,Vector{Float64}}
end

function _sbls_rank_state_v1(R,n,tol;diagnostic_stats=nothing,iteration=0,source=:unknown)
    _sbls_diagnostic_event_v1(diagnostic_stats,:rank_check_attempt,iteration,
        (source=source,n=n,rows=size(R,1),cols=size(R,2)))
    n>0 && size(R,1)>=n && size(R,2)>=n || return (rank=0,threshold=0.0,stable=false)
    largest=0.0
    for i in 1:n;largest=max(largest,abs(R[i,i]));end
    threshold=tol*max(1.0,largest)
    rank=0;smallest_margin=Inf
    for i in 1:n
        d=abs(R[i,i]);rank+=d>threshold
        smallest_margin=min(smallest_margin,d-threshold)
    end
    margin=sqrt(tol)*max(1.0,largest)
    state=(rank=rank,threshold=threshold,stable=rank==n && smallest_margin>margin)
    _sbls_diagnostic_event_v1(diagnostic_stats,:rank_check_complete,iteration,
        (source=source,n=n,rank=state.rank,stable=state.stable))
    state
end

@inline function _sbls_diagnostic_event_v1(stats,event,iteration,detail=nothing)
    stats === nothing && return nothing
    stats((event=event,iteration=iteration,detail=detail))
    nothing
end

function _sbls_recoverable_downdate_error_v1(err)
    err isa LinearAlgebra.SingularException && return true
    err isa LinearAlgebra.LAPACKException && return true
    err isa OverflowError && return true
    err isa DomainError && return true
    false
end

function _sbls_dense_downdate_R_v1(F)
    R0=Matrix(F.R);m=size(F.Q,1);n=size(R0,2)
    size(R0,1)<=m || return nothing
    R=zeros(Float64,min(m,n+8),n+8)
    copyto!(view(R,1:size(R0,1),1:n),R0)
    R
end

function _sbls_make_downdate_cache_v1(F,free,tol;diagnostic_stats=nothing,iteration=0)
    try
        n=length(free);state=_sbls_rank_state_v1(F.R,n,tol;diagnostic_stats,iteration,source=:cache_create)
        state.stable || return nothing
        pcol=isempty(F.pcol) ? collect(free) : Int[free[F.pcol[i]] for i in eachindex(F.pcol)]
        length(pcol)==n || return nothing
        _SBLSDowndateCacheV1(F,nothing,Tuple{Int,Float64,Float64}[],pcol,copy(free),0,
            nothing,nothing)
    catch err
        _sbls_recoverable_downdate_error_v1(err) || rethrow()
        nothing
    end
end

function _sbls_drop_one_column_v1!(cache,free,tol;rhs=nothing,lower_bounds=nothing,
                                    diagnostic_stats=nothing,iteration=0)
    length(cache.free_columns)==length(free)+1 || return false
    cache.updates<32 || return false
    gone=0;oldpos=1;newpos=1
    while oldpos<=length(cache.free_columns) && newpos<=length(free)
        if cache.free_columns[oldpos]==free[newpos]
            oldpos+=1;newpos+=1
        elseif cache.free_columns[oldpos]<free[newpos]
            gone==0 || return false
            gone=cache.free_columns[oldpos];oldpos+=1
        else
            return false
        end
    end
    if oldpos<=length(cache.free_columns)
        gone==0 && oldpos==length(cache.free_columns) || return false
        gone=cache.free_columns[oldpos];oldpos+=1
    end
    gone!=0 && oldpos==length(cache.free_columns)+1 && newpos==length(free)+1 || return false
    k=findfirst(==(gone),cache.pivoted_columns);k===nothing && return false
    n=length(cache.pivoted_columns);newn=n-1
    R=cache.R
    if R===nothing
        R=_sbls_dense_downdate_R_v1(cache.base)
        R===nothing && return false
        cache.R=R
    end
    delta=lower_bounds===nothing ? 0.0 : Float64(lower_bounds[gone])
    isfinite(delta) || return false
    projected=cache.projected_rhs
    if projected!==nothing
        length(projected)>=n && size(R,1)>=n || return false
        # When `gone` becomes active, rhs changes by -A[:,gone]*lower[gone].
        # In the current orthogonal coordinates Q' A[:,gone] is column k of R.
        for row in 1:n
            projected[row]-=R[row,k]*delta
        end
    end
    for j in k:newn;copyto!(view(R,:,j),view(R,:,j+1));end
    fill!(view(R,:,n),0.0)
    for i in k:newn
        a=R[i,i];b=R[i+1,i];h=hypot(a,b)
        isfinite(h) || return false
        c=h==0.0 ? 1.0 : a/h;s=h==0.0 ? 0.0 : b/h
        # DROT applies the same plane rotation to these strided row suffixes.
        mR=size(R,1)
        GC.@preserve R LinearAlgebra.BLAS.rot!(newn-i+1,
            pointer(R,i+(i-1)*mR),mR,
            pointer(R,i+1+(i-1)*mR),mR,c,s)
        if projected!==nothing
            x=projected[i];y=projected[i+1]
            projected[i]=c*x+s*y;projected[i+1]=-s*x+c*y
        end
        R[i+1,i]=0.0
        push!(cache.rotations,(i,c,s))
    end
    if rhs!==nothing
        cache.rhs_snapshot=Float64.(rhs)
    end
    deleteat!(cache.pivoted_columns,k);cache.free_columns=copy(free);cache.updates+=1
    _sbls_rank_state_v1(R,newn,tol;diagnostic_stats,iteration,source=:cache_drop).stable
end

function _sbls_add_one_column_v1!(cache,A,free,tol;diagnostic_stats=nothing,iteration=0)
    length(free)==length(cache.free_columns)+1 || return false
    cache.updates<8 || return false
    added=0;oldpos=1;newpos=1
    while oldpos<=length(cache.free_columns) && newpos<=length(free)
        if cache.free_columns[oldpos]==free[newpos]
            oldpos+=1;newpos+=1
        elseif cache.free_columns[oldpos]>free[newpos]
            added==0 || return false
            added=free[newpos];newpos+=1
        else
            return false
        end
    end
    if newpos<=length(free)
        added==0 && newpos==length(free) || return false
        added=free[newpos];newpos+=1
    end
    added!=0 && oldpos==length(cache.free_columns)+1 && newpos==length(free)+1 || return false
    n=length(cache.pivoted_columns);newn=n+1;m=size(cache.base.Q,1)
    newn<=m || return false
    R=cache.R
    if R===nothing
        R=_sbls_dense_downdate_R_v1(cache.base)
        R===nothing && return false
        cache.R=R
    end
    size(R,1)>=newn && size(R,2)>=newn || return false
    # F.R=F.Q' * A[prow,pcol]; the full Q also gives coordinates for a
    # released column that was outside the original free-set factor.
    column=Float64.(collect(A[cache.base.prow,added]))
    v=Float64.(cache.base.Q' * column)
    length(v)==m || return false
    for (i,c,s) in cache.rotations
        1<=i<m || return false
        a=v[i];b=v[i+1];v[i]=c*a+s*b;v[i+1]=-s*a+c*b
    end
    rotations=Tuple{Int,Float64,Float64}[]
    for row in m:-1:newn+1
        i=row-1;a=v[i];b=v[row];h=hypot(a,b)
        isfinite(h) || return false
        c=h==0.0 ? 1.0 : a/h;s=h==0.0 ? 0.0 : b/h
        v[i]=c*a+s*b;v[row]=-s*a+c*b;v[row]=0.0
        push!(rotations,(i,c,s))
    end
    fill!(view(R,:,newn),0.0)
    copyto!(view(R,:,newn),view(v,1:size(R,1)))
    append!(cache.rotations,rotations)
    push!(cache.pivoted_columns,added);cache.free_columns=copy(free);cache.updates+=1
    cache.projected_rhs=nothing;cache.rhs_snapshot=nothing
    _sbls_rank_state_v1(R,newn,tol;diagnostic_stats,iteration,source=:cache_add).stable
end

function _sbls_downdated_solution_v1(cache,rhs,tol;diagnostic_stats=nothing,iteration=0)
    n=length(cache.pivoted_columns);R=cache.R
    R===nothing && return nothing
    state=_sbls_rank_state_v1(R,n,tol;diagnostic_stats,iteration,source=:cached_backsolve)
    state.stable || return nothing
    rhs64=Float64.(rhs)
    q=if cache.projected_rhs===nothing || cache.rhs_snapshot===nothing || cache.rhs_snapshot!=rhs64
        value=cache.base.Q' * rhs64[cache.base.prow]
        for (i,c,s) in cache.rotations
            1<=i<length(value) || return nothing
            a=value[i];b=value[i+1];value[i]=c*a+s*b;value[i+1]=-s*a+c*b
        end
        cache.projected_rhs=value
        cache.rhs_snapshot=rhs64
        value
    else
        cache.projected_rhs
    end
    length(q)>=n || return nothing
    x=copy(view(q,1:n))
    _sbls_diagnostic_event_v1(diagnostic_stats,:cached_backsolve_attempt,iteration,(n=n,))
    ldiv!(UpperTriangular(view(R,1:n,1:n)),x)
    _sbls_diagnostic_event_v1(diagnostic_stats,:cached_backsolve_complete,iteration,(n=n,))
    all(isfinite,x) || return nothing
    (x=x,rank=state.rank,threshold=state.threshold)
end

function _sbls_update_decision_stable_v1(A,r,lower,s,candidate,working,free,audit,policy)
    audit.finite && audit.roundoff_floor isa Real || return false
    floor=audit.roundoff_floor
    audit.free_stationarity!==nothing && audit.free_stationarity<=audit.tolerance-floor || return false
    audit.scaled_complementarity!==nothing && abs(audit.scaled_complementarity-audit.tolerance)>floor || return false
    blockers=Tuple{Float64,Int}[]
    for i in free
        isfinite(lower[i]) || continue
        coordtol=policy.feasibility_roundoff_factor*eps(Float64)*max(1.0,abs(candidate[i]),abs(lower[i]))
        abs(candidate[i]-lower[i])>coordtol || return false
        candidate[i]<lower[i] && push!(blockers,((lower[i]-s[i])/(candidate[i]-s[i]),i))
    end
    sort!(blockers)
    if !isempty(blockers)
        alpha,hit=blockers[1]
        alpha<=policy.feasibility_roundoff_factor*eps(Float64) && return false
        length(blockers)>1 && blockers[2][1]-alpha<=policy.feasibility_roundoff_factor*eps(Float64)*max(1.0,abs(alpha)) && return false
        next=s+alpha*(candidate-s);next[hit]=lower[hit]
        all(isfinite,next) || return false
        for i in free
            isfinite(lower[i]) || continue
            crossing=lower[i]-next[i]
            crossing_tol=policy.feasibility_roundoff_factor*eps(Float64)*max(1.0,abs(lower[i]),abs(next[i]))
            crossing>0.0 && abs(crossing-crossing_tol)<=crossing_tol && return false
        end
    end
    active=findall(identity,working);eligible=Float64[]
    for i in active
        gradient=audit.gradient[i]
        gradient isa Real || return false
        abs(gradient+audit.tolerance)>floor || return false
        gradient < -audit.tolerance && push!(eligible,gradient)
    end
    sort!(eligible)
    length(eligible)>1 && eligible[2]-eligible[1]<=floor && return false
    true
end

"Canonical-JSON-safe actual linear inputs; unbounded coordinates are explicit."
function bounded_linear_step_snapshot_v1(A,r,lower;policy=bounded_linear_step_policy_v1())
    AA,rr,ll=checked_inputs(A,r,lower,policy);ii,jj,vv=findnz(AA)
    (schema="spatial-bounded-linear-input-v1",algorithm=bounded_linear_step_identity_v1(),
        rows=size(AA,1),columns=size(AA,2),index_base=1,
        matrix=(format=:coordinate,row_indices=Tuple(ii),column_indices=Tuple(jj),values=Tuple(vv)),
        residual=Tuple(rr),lower_bounds=Tuple(isfinite(v) ? v : nothing for v in ll),
        unbounded_below_indices=Tuple(findall(==(-Inf),ll)),
        objective=:half_squared_norm_A_step_plus_residual,
        coordinates=:dimensionless_scaled_step,zero_step_feasible=true)
end

"Audit a supplied step against an explicit working set; no optimization is run."
function bounded_step_kkt_v1(A,r,lower,s,active_indices;policy=bounded_linear_step_policy_v1())
    AA,rr,ll=checked_inputs(A,r,lower,policy);ss=collect(Float64.(s));n=size(AA,2)
    length(ss)==n || throw(ArgumentError("step dimension mismatch"))
    ids=collect(active_indices)
    all(i->i isa Integer && 1<=i<=n && isfinite(ll[i]),ids) && length(unique(ids))==length(ids) ||
        throw(ArgumentError("invalid or duplicate working-set index"))
    working=falses(n);working[Int[ids...]].=true
    kkt_audit(AA,rr,ll,ss,working,policy)
end

"""Solve min 0.5||A*s+r||^2 subject to s>=lower, starting at feasible zero.

Every active coordinate is fixed to its actual lower bound, which need not be
zero. Reduced QR uses rhs=-r-A[:,active]*lower[active]. A feasible segment to
the free least-squares minimizer adds the first blocking constraint; negative
model multipliers release constraints. The current model gradient, not A'r at
the original state, controls release. Rank deficiency is allowed, but only a
measured KKT pass is successful. Budget/factorization/roundoff failures retain
the current feasible iterate and explicit failure diagnostics.
"""
function solve_lower_bounded_step_v1(A,r,lower;policy=bounded_linear_step_policy_v1(),seconds=Inf,
                                    stage_trace=nothing,diagnostic_stats=nothing)
    AA,rr,ll = if stage_trace === nothing
        checked_inputs(A,r,lower,policy)
    else
        trace_name="native_bounded_step_checked_inputs"
        _sbls_trace_event_v1(stage_trace,trace_name,:begin)
        try
            checked_inputs(A,r,lower,policy)
        finally
            _sbls_trace_event_v1(stage_trace,trace_name,:end)
        end
    end
    n=size(AA,2)
    seconds isa Real && !isnan(seconds) && seconds>=0.0 || throw(ArgumentError("nonnegative inner seconds required"))
    start=time_ns()
    matrix_one_norm_cache=Ref{Union{Nothing,Float64}}(nothing)
    s=zeros(n);working=BitVector(ll .== 0.0);history=NamedTuple[]
    maxinner=policy.inner_iteration_factor*n+policy.inner_iteration_offset
    status=:inner_iteration_limit;code=1;failure=nothing;unconstrained=nothing;qr_cache=nothing
    for iteration in 1:maxinner
        if (time_ns()-start)/1.0e9>=seconds
            status=:wall_time_budget;code=1;break
        end
        free=findall(!,working);active=findall(identity,working)
        candidate=copy(s);candidate[active].=ll[active]
        rhs=-rr-AA[:,active]*ll[active]
        rank_estimate=0;rank_threshold=0.0;error_stage=:factorization;updated_audit=nothing
        qr_stage=if stage_trace === nothing
            nothing
        else
            active_ids=isempty(active) ? "none" : join(active,",")
            "native_bounded_step_qr_backsolve_rankdiag_iteration_$(iteration)_m$(size(AA,1))_n$(n)_nnz$(nnz(AA))_free$(length(free))_active$(length(active))_active_ids$(active_ids)"
        end
        qr_stage === nothing || _sbls_trace_event_v1(stage_trace,qr_stage,:begin)
        cache_status=qr_cache===nothing ? :no_previous_factor : :not_attempted
        try
            try
                if !isempty(free)
                    updated=false
                    if qr_cache!==nothing
                        # A lazy dense-cache materialization fails at the same diagnostic stage as the eager copy.
                        qr_cache.R===nothing && (error_stage=:rank_diagnostic)
                        try
                            cache_kind=length(free)==length(qr_cache.free_columns)+1 ? :add_one : :drop_one
                            updates_before=qr_cache.updates
                            cached_free_before=diagnostic_stats===nothing ? nothing : copy(qr_cache.free_columns)
                            _sbls_diagnostic_event_v1(diagnostic_stats,:cache_update_attempt,iteration,
                                (kind=cache_kind,updates=updates_before,free=length(free),cached_free=length(qr_cache.free_columns)))
                            cache_updated=if cache_kind===:add_one
                                _sbls_add_one_column_v1!(qr_cache,AA,free,policy.rank_relative_tolerance;diagnostic_stats,iteration)
                            else
                                _sbls_drop_one_column_v1!(qr_cache,free,
                                    policy.rank_relative_tolerance;rhs=rhs,lower_bounds=ll,diagnostic_stats,iteration)
                            end
                            cache_status=cache_updated ? :cache_update_applied : :cache_update_rejected
                            diagnostic_stats===nothing || _sbls_diagnostic_event_v1(diagnostic_stats,:cache_update_result,iteration,
                                (kind=cache_kind,accepted=cache_updated,reason=cache_status,updates_before=updates_before,
                                 updates_after=qr_cache.updates,old_only=Tuple(setdiff(cached_free_before,free)),
                                 new_only=Tuple(setdiff(free,cached_free_before))))
                            if cache_updated
                                result=_sbls_downdated_solution_v1(qr_cache,rhs,policy.rank_relative_tolerance;diagnostic_stats,iteration)
                                _sbls_diagnostic_event_v1(diagnostic_stats,:cached_solution_result,iteration,
                                    (available=result!==nothing,))
                                cache_status=result===nothing ? :cached_rank_or_solution_rejected : :cached_kkt_check
                                if result!==nothing
                                    candidate[qr_cache.pivoted_columns].=result.x
                                    rank_estimate=result.rank;rank_threshold=result.threshold
                                    error_stage=:rank_diagnostic
                                    check=kkt_audit(AA,rr,ll,candidate,working,policy;
                                        matrix_one_norm_cache=matrix_one_norm_cache)
                                    stable_update=_sbls_update_decision_stable_v1(AA,rr,ll,s,candidate,working,free,check,policy)
                                    _sbls_diagnostic_event_v1(diagnostic_stats,:cached_decision_result,iteration,
                                        (accepted=stable_update,kkt_passed=check.passed,))
                                    if stable_update
                                        updated_audit=check;updated=true;cache_status=:cache_reused
                                    else
                                        cache_status=:cached_candidate_stability_rejected
                                    end
                                end
                            end
                        catch err
                            _sbls_diagnostic_event_v1(diagnostic_stats,:cache_update_exception,iteration,
                                (exception=string(typeof(err)),))
                            cache_status=:cache_update_exception
                            _sbls_recoverable_downdate_error_v1(err) || rethrow()
                            updated=false
                        end
                    end
                    if !updated
                        error_stage=:factorization
                        _sbls_diagnostic_event_v1(diagnostic_stats,:fresh_qr_attempt,iteration,
                            (reason=cache_status,active=length(active),free=length(free),nnz=nnz(AA)))
                        F=qr(AA[:,free];tol=policy.rank_relative_tolerance)
                        _sbls_diagnostic_event_v1(diagnostic_stats,:fresh_qr_complete,iteration,(free=length(free),))
                        error_stage=:back_substitution
                        _sbls_diagnostic_event_v1(diagnostic_stats,:fresh_backsolve_attempt,iteration,(free=length(free),))
                        candidate[free].=F\rhs
                        _sbls_diagnostic_event_v1(diagnostic_stats,:fresh_backsolve_complete,iteration,(free=length(free),))
                        error_stage=:rank_diagnostic
                        _sbls_diagnostic_event_v1(diagnostic_stats,:fresh_rank_diagnostic_attempt,iteration,(free=length(free),))
                        diagonal=abs.(diag(F.R))
                        rank_threshold=policy.rank_relative_tolerance*max(1.0,maximum(diagonal;init=0.0))
                        rank_estimate=count(>(rank_threshold),diagonal)
                        _sbls_diagnostic_event_v1(diagnostic_stats,:fresh_rank_diagnostic_complete,iteration,
                            (free=length(free),rank=rank_estimate,threshold=rank_threshold))
                        qr_cache=_sbls_make_downdate_cache_v1(F,free,policy.rank_relative_tolerance;diagnostic_stats,iteration)
                    end
                else
                    qr_cache=nothing
                end
            finally
                qr_stage === nothing || _sbls_trace_event_v1(stage_trace,qr_stage,:end)
            end
        catch err
            (err isa InterruptException || err isa OutOfMemoryError || err isa StackOverflowError) && rethrow()
            status=:free_QR_failure;code=2;failure=(stage=error_stage,error=sprint(showerror,err))
            push!(history,(iteration=iteration,event=:free_QR_failure,active_before=Tuple(active),
                free_columns=Tuple(free),candidate_step=nothing,alpha=nothing,added=(),released=(),
                rank_estimate=nothing,rank_threshold=nothing,kkt=nothing))
            break
        end
        if stage_trace !== nothing
            rank_stage="native_bounded_step_rank_iteration_$(iteration)_rank$(rank_estimate)_rank_threshold$(repr(rank_threshold))_free_columns$(length(free))"
            _sbls_trace_event_v1(stage_trace,rank_stage,:begin)
            _sbls_trace_event_v1(stage_trace,rank_stage,:end)
        end
        if isempty(active) && unconstrained===nothing
            unconstrained=Tuple(finite_or_nothing.(candidate))
        end
        if (time_ns()-start)/1.0e9>=seconds
            status=:wall_time_budget;code=1
            push!(history,(iteration=iteration,event=status,active_before=Tuple(active),free_columns=Tuple(free),
                candidate_step=Tuple(finite_or_nothing.(candidate)),alpha=nothing,added=(),released=(),
                rank_estimate=rank_estimate,rank_threshold=rank_threshold,kkt=nothing))
            break
        end
        if !all(isfinite,candidate)
            status=:nonfinite_free_solution;code=3
            push!(history,(iteration=iteration,event=status,active_before=Tuple(active),free_columns=Tuple(free),
                candidate_step=Tuple(finite_or_nothing.(candidate)),alpha=nothing,added=(),released=(),
                rank_estimate=rank_estimate,rank_threshold=rank_threshold,kkt=nothing))
            break
        end
        violating=[i for i in free if isfinite(ll[i]) && candidate[i]<ll[i]]
        if !isempty(violating)
            # s is feasible. Only the first hitting constraint is activated;
            # subsequent exact ties are handled by another zero-length segment.
            ratios=[(ll[i]-s[i])/(candidate[i]-s[i]) for i in violating]
            hitpos=argmin(ratios);hit=violating[hitpos];alpha=ratios[hitpos]
            if !isfinite(alpha) || !(0.0 <= alpha <= 1.0)
                status=:invalid_feasible_segment;code=3;failure=(stage=:feasible_segment,error="invalid hitting ratio")
                push!(history,(iteration=iteration,event=status,active_before=Tuple(active),free_columns=Tuple(free),
                    candidate_step=Tuple(candidate),alpha=finite_or_nothing(alpha),added=(),released=(),
                    rank_estimate=rank_estimate,rank_threshold=rank_threshold,kkt=nothing))
                break
            end
            next=s+alpha*(candidate-s);next[hit]=ll[hit];next[active].=ll[active]
            # Correct only sub-ulp crossing of another bound. Material crossing
            # is an explicit numerical failure, never hidden pressure clipping.
            crossings=[i for i in free if isfinite(ll[i]) && next[i]<ll[i]]
            invalid=any(i->ll[i]-next[i]>policy.feasibility_roundoff_factor*eps(Float64)*max(1.0,abs(ll[i]),abs(next[i])),crossings)
            if invalid || !all(isfinite,next)
                status=:infeasible_segment_roundoff;code=3;failure=(stage=:feasible_segment,error="material bound crossing")
                push!(history,(iteration=iteration,event=status,active_before=Tuple(active),free_columns=Tuple(free),
                    candidate_step=Tuple(candidate),alpha=alpha,added=(),released=(),
                    rank_estimate=rank_estimate,rank_threshold=rank_threshold,kkt=nothing))
                break
            end
            for i in crossings;next[i]=ll[i];end
            added=sort!(unique(vcat([hit],crossings)));working[added].=true;s=next
            audit=kkt_audit(AA,rr,ll,s,working,policy;
                matrix_one_norm_cache=matrix_one_norm_cache)
            push!(history,(iteration=iteration,event=:bind,active_before=Tuple(active),free_columns=Tuple(free),
                candidate_step=Tuple(candidate),alpha=alpha,added=Tuple(added),released=(),
                rank_estimate=rank_estimate,rank_threshold=rank_threshold,kkt=audit))
            if stage_trace !== nothing
                decision_stage="native_bounded_step_decision_iteration_$(iteration)_bind_hit$(hit)_added$(join(added,","))_alpha$(repr(alpha))"
                _sbls_trace_event_v1(stage_trace,decision_stage,:begin)
                _sbls_trace_event_v1(stage_trace,decision_stage,:end)
            end
            continue
        end
        s=candidate;audit=updated_audit===nothing ? kkt_audit(AA,rr,ll,s,working,policy;
            matrix_one_norm_cache=matrix_one_norm_cache) : updated_audit
        event=:candidate_kkt_failure;released=()
        if !audit.finite
            status=:nonfinite_model_audit;code=3;event=status
        elseif audit.passed
            status=:kkt_converged;code=0;event=status
        elseif audit.free_stationarity>audit.tolerance
            status=audit.free_stationarity<=audit.roundoff_floor ? :precision_limit : :free_stationarity_failed
            code=4;event=status
        else
            eligible=[i for i in active if audit.gradient[i]<-audit.tolerance]
            if isempty(eligible)
                status=:kkt_audit_failed;code=4;event=status
            else
                release=eligible[argmin([audit.gradient[i] for i in eligible])]
                working[release]=false;released=(release,);event=:release
            end
        end
        push!(history,(iteration=iteration,event=event,active_before=Tuple(active),free_columns=Tuple(free),
            candidate_step=Tuple(candidate),alpha=1.0,added=(),released=released,
            rank_estimate=rank_estimate,rank_threshold=rank_threshold,kkt=audit))
        if stage_trace !== nothing && event === :release
            release=released[1]
            decision_stage="native_bounded_step_decision_iteration_$(iteration)_release_column$(release)_alpha$(repr(1.0))_gradient$(repr(audit.gradient[release]))_kkt_roundoff_floor$(repr(audit.roundoff_floor))"
            _sbls_trace_event_v1(stage_trace,decision_stage,:begin)
            _sbls_trace_event_v1(stage_trace,decision_stage,:end)
        end
        event==:release || break
    end
    finalaudit=kkt_audit(AA,rr,ll,s,working,policy;
        matrix_one_norm_cache=matrix_one_norm_cache)
    (algorithm=bounded_linear_step_identity_v1(),status=status,exit_code=code,
        converged=code==0 && finalaudit.passed,step=Tuple(finite_or_nothing.(s)),
        active_indices=Tuple(findall(identity,working)),free_indices=Tuple(findall(!,working)),
        unconstrained_step=unconstrained,initial_objective=finite_or_nothing(dot(rr,rr)/2),
        kkt=finalaudit,inner_iterations=length(history),inner_iteration_limit=maxinner,
        history=Tuple(history),failure=failure,elapsed_seconds=(time_ns()-start)/1.0e9,
        seconds_budget=finite_or_nothing(Float64(seconds)),unbounded_seconds=seconds==Inf,
        physical_convergence=:not_assessed)
end
end
