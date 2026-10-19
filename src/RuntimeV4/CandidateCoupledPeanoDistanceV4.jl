# Directed radial Peano-distance moments; physical numerators remain in the caller.
# This file deliberately contains no field/current numerator construction and
# no quadrature.  The caller supplies its already-certified global-absolute
# convolution coefficients; only J_m(dmin) is replaced by a distance-correlated
# radial moment, with the same cap-enforcing interval and exact-operation ledgers.

module X3NonnearPeanoDistanceMoments

const SCHEMA = :x3_nonnear_peano_distance_moments_v1

_bf(x) = BigFloat(x)
_rat(x::Float64) = Rational{BigInt}(x)
_ratbig(x::BigFloat) = Rational{BigInt}(x)

function _choose(n,k)
    (k < 0 || k > n) && return BigInt(0)
    binomial(big(n),big(k))
end

function _distance_pieces(P0,P1,P2,T,ra,rb;exact_ops=Ref(0),max_exact_ops=2_000_000)
    # Preserve the source map from the actual Float64 vertices: convert each
    # vertex to its exact binary rational first, then form the two edge vectors
    # with charged rational subtraction.  Passing pre-rounded Float64 edges
    # would define a different source map.
    charge_rational!()=begin
        exact_ops[]<max_exact_ops || error("exact rational geometry operation cap")
        exact_ops[]+=1
    end
    radd(a,b)=(charge_rational!();a+b);rsub(a,b)=(charge_rational!();a-b)
    rmul(a,b)=(charge_rational!();a*b);rdiv(a,b)=(charge_rational!();iszero(b)&&error("exact rational divide by zero");a/b)
    point64(v,label)=begin
        (v isa Tuple || v isa AbstractVector) && length(v)==2 ||
            error("$label must be an actual two-coordinate R/Z Float64 vertex/target tuple or vector")
        q=Float64.(v);all(isfinite,q) || error("$label contains a nonfinite coordinate");q
    end
    P0f=point64(P0,"P0");P1f=point64(P1,"P1");P2f=point64(P2,"P2");Tf=point64(T,"T")
    P0r=map(_rat,P0f); P1r=map(_rat,P1f); P2r=map(_rat,P2f)
    TT=map(_rat,Tf)
    E1=map((a,b)->rsub(a,b),P1r,P0r); E2=map((a,b)->rsub(a,b),P2r,P0r)
    V=map((a,b)->rsub(a,b),E2,E1);W=map((a,b)->rsub(a,b),TT,P0r)
    dot(a,b)=foldl(radd,(rmul(a[i],b[i]) for i in eachindex(a));init=Rational{BigInt}(0))
    vv=dot(V,V); vv>0 || error("degenerate source chord")
    t0=rdiv(dot(W,V),vv);t1=-rdiv(dot(E1,V),vv)
    cuts=Rational{BigInt}[_rat(Float64(ra)),_rat(Float64(rb))]
    for level in (Rational{BigInt}(0),Rational{BigInt}(1))
        denom=rsub(t1,level)
        if !iszero(denom)
            root=-rdiv(t0,denom)
            cuts[1]<root<cuts[2] && push!(cuts,root)
        end
    end
    sort!(unique!(cuts)); length(cuts)<=4 || error("chord split exceeded three analytic regions")
    out=NamedTuple[]
    for q in 1:length(cuts)-1
        a,b=cuts[q],cuts[q+1];mid=rdiv(radd(a,b),Rational{BigInt}(2));u=radd(rdiv(t0,mid),t1)
        if 0<u<1
            ww=dot(W,V);ev=dot(E1,V)
            A=rsub(dot(E1,E1),rdiv(rmul(ev,ev),vv))
            B=radd(-rmul(Rational{BigInt}(2),dot(W,E1)),rdiv(rmul(Rational{BigInt}(2),rmul(ww,ev)),vv))
            C=rsub(dot(W,W),rdiv(rmul(ww,ww),vv))
            branch=:interior
        else
            E=u<=0 ? E1 : E2
            A=dot(E,E);B=-rmul(Rational{BigInt}(2),dot(W,E));C=dot(W,W);branch=u<=0 ? :endpoint0 : :endpoint1
        end
        # Strict positivity is checked at the exact quadratic minimum on this
        # closed interval (the interval endpoints are included).
        d2(r)=radd(radd(rmul(A,rmul(r,r)),rmul(B,r)),C)
        vals=Rational{BigInt}[d2(a),d2(b)]
        if A>0
            rvertex=-rdiv(B,rmul(Rational{BigInt}(2),A))
            a < rvertex < b && push!(vals,d2(rvertex))
        end
        minimum(vals)>0 || error("chord-distance quadratic is not strictly positive")
        push!(out,(lo=a,hi=b,A=A,B=B,C=C,branch=branch))
    end
    out
end

function _directed_api(interval_ops,max_interval_ops,api)
    interval_ops isa Base.RefValue && interval_ops[] isa Integer || error("directed Peano proof requires the shared interval ledger Ref")
    for k in (:exact,:add,:sub,:mul,:divi,:sqrt_i,:log_i,:charge!)
        hasproperty(api,k) && getproperty(api,k) isa Function || error("missing core interval operation $k")
    end
    ops=interval_ops
    charge!()=api.charge!()
    check(a)=a isa Tuple && length(a)==2 && a[1] isa BigFloat && a[2] isa BigFloat && isfinite(a[1]) && isfinite(a[2]) && a[1]<=a[2] || error("malformed directed interval")
    exact(x)=api.exact(x)
    neg(a)=(-a[2],-a[1])
    add(a,b)=api.add(a,b);sub(a,b)=api.sub(a,b);mul(a,b)=api.mul(a,b)
    divi(a,b)=begin
        b[1]>0 ? api.divi(a,b) : (b[2]<0 ? api.divi(neg(a),neg(b)) : error("directed moment denominator crosses zero"))
    end
    down(f)=(charge!();setrounding(BigFloat,RoundDown) do;f();end)
    up(f)=(charge!();setrounding(BigFloat,RoundUp) do;f();end)
    atan_i(a)=begin check(a);(down(()->atan(a[1])),up(()->atan(a[2]))) end
    asinh_i(a)=begin check(a);(down(()->asinh(a[1])),up(()->asinh(a[2]))) end
    sqrt_i(a)=api.sqrt_i(a);log_i(a)=api.log_i(a)
    qrat(x::Rational{BigInt})=begin
        charge!();(setrounding(BigFloat,RoundDown) do;BigFloat(x);end,
                   setrounding(BigFloat,RoundUp) do;BigFloat(x);end)
    end
    powi(a,n::Int)=begin
        n==0 && return exact(1)
        n<0 && return divi(exact(1),powi(a,-n))
        z=exact(1);b=a;k=n
        while k>0
            isodd(k) && (z=mul(z,b))
            k>>=1;k>0 && (b=mul(b,b))
        end
        z
    end
    powhalf(a,e::Rational{Int})=begin
        n=numerator(e);d=denominator(e);d in (1,2) || error("only integer/half-integer powers are supported")
        if d==1
            return powi(a,n)
        end
        n>=0 ? sqrt_i(powi(a,n)) : divi(exact(1),sqrt_i(powi(a,-n)))
    end
    for x in (exact(0),exact(1));check(x);end
    (ops=ops,cap=max_interval_ops,charge! = charge!,exact=exact,add=add,sub=sub,mul=mul,divi=divi,
     neg=neg,sqrt_i=sqrt_i,log_i=log_i,atan_i=atan_i,asinh_i=asinh_i,qrat=qrat,
     powi=powi,powhalf=powhalf,check=check)
end

function _directed_i0(A,δ,yl,yu,ν,delta_sign,sgn_y,api;cache=nothing)
    if cache!==nothing && haskey(cache,ν)
        return cache[ν]
    end
    z=_directed_i0_uncached(A,δ,yl,yu,ν,delta_sign,sgn_y,api,cache)
    cache!==nothing && (cache[ν]=z)
    z
end

function _directed_i0_uncached(A,δ,yl,yu,ν,delta_sign,sgn_y,api,cache)
    x=api
    q(y)=x.mul(A,x.add(x.powi(y,2),δ))
    if delta_sign==0
        sgn_y in (-1,1) || error("unresolved zero-discriminant moment branch")
        if ν==1//2
            prim=y->x.mul(x.exact(sgn_y),x.log_i(x.mul(x.exact(sgn_y),y)))
            return x.divi(x.sub(prim(yu),prim(yl)),x.sqrt_i(A))
        end
        p=1//1-2ν
        prim=y->x.divi(x.mul(x.exact(sgn_y),x.powhalf(x.mul(x.exact(sgn_y),y),p)),
            x.mul(x.powhalf(A,ν),x.exact(p)))
        return x.sub(prim(yu),prim(yl))
    elseif ν==1//2
        if delta_sign>0
            s=x.sqrt_i(δ)
            return x.divi(x.sub(x.asinh_i(x.divi(yu,s)),x.asinh_i(x.divi(yl,s))),x.sqrt_i(A))
        end
        s=x.sqrt_i(x.neg(δ))
        prim=y->x.log_i(x.mul(x.exact(sgn_y),x.add(y,x.sqrt_i(x.sub(x.powi(y,2),x.powi(s,2))))))
        return x.divi(x.sub(prim(yu),prim(yl)),x.sqrt_i(A))
    elseif ν==1
        if delta_sign>0
            s=x.sqrt_i(δ)
            return x.divi(x.sub(x.atan_i(x.divi(yu,s)),x.atan_i(x.divi(yl,s))),x.mul(A,s))
        end
        s=x.sqrt_i(x.neg(δ))
        prim=y->x.divi(x.log_i(x.divi(x.sub(y,s),x.add(y,s))),x.mul(x.exact(2),s))
        return x.divi(x.sub(prim(yu),prim(yl)),A)
    end
    ν>1 || error("unsupported directed I0 exponent")
    prev=_directed_i0(A,δ,yl,yu,ν-1,delta_sign,sgn_y,x;cache=cache)
    bd=x.sub(x.mul(yu,x.powhalf(q(yu),1-ν)),x.mul(yl,x.powhalf(q(yl),1-ν)))
    c1=x.qrat(BigInt(numerator(3-2ν))//BigInt(denominator(3-2ν)))
    c2=x.qrat(BigInt(numerator(2*(ν-1)))//BigInt(denominator(2*(ν-1))))
    x.divi(x.sub(bd,x.mul(c1,prev)),x.mul(c2,x.mul(A,δ)))
end

function _directed_moments(A,B,C,L,U,m,branch,api;
        moment_cache=nothing,i0_cache=nothing,endpoint_cache=nothing)
    x=api;ν=(m-1)//2;q(t)=x.add(x.add(x.mul(A,x.powi(t,2)),x.mul(B,t)),C)
    cache=moment_cache===nothing ? Dict{Tuple{Int,Rational{Int}},Tuple{BigFloat,BigFloat}}() : moment_cache
    i0memo=i0_cache===nothing ? Dict{Rational{Int},Tuple{BigFloat,BigFloat}}() : i0_cache
    endpointmemo=endpoint_cache===nothing ? Dict{Any,Tuple{BigFloat,BigFloat}}() : endpoint_cache
    qendpoint(side)=get!(endpointmemo,side===:L ? :qL : :qU) do
        q(side===:L ? L : U)
    end
    endpoint_one()=get!(endpointmemo,:one) do;x.exact(1);end
    qendpointpow(side,e)=get!(endpointmemo,(:qpow,side,e)) do
        x.powhalf(qendpoint(side),e)
    end
    tendpointpow(side,n)=begin
        n==0 && return endpoint_one()
        v=side===:L ? L : U
        v[1]==0 && v[2]==0 && return v
        v[1]==1 && v[2]==1 && return v
        get!(endpointmemo,(:tpow,side,n)) do;x.powi(v,n);end
    end
    endpoint_product(side,n,e)=begin
        tpow=tendpointpow(side,n)
        (tpow[1]==0 && tpow[2]==0) && return tpow
        qpow=qendpointpow(side,e)
        (tpow[1]==1 && tpow[2]==1) && return qpow
        x.mul(tpow,qpow)
    end
    if branch.A_zero
        if branch.B_zero
            res=Tuple{BigFloat,BigFloat}[]
            for k in 0:16
                key=(k,ν)
                if !haskey(cache,key)
                    cache[key]=x.mul(x.divi(x.sub(x.powi(U,k+1),x.powi(L,k+1)),x.exact(k+1)),
                        x.powhalf(C,-ν))
                end
                push!(res,cache[key])
            end
            return res
        end
        res=Tuple{BigFloat,BigFloat}[];uL=x.add(x.mul(B,L),C);uU=x.add(x.mul(B,U),C)
        for k in 0:16
            key=(k,ν)
            if haskey(cache,key)
                push!(res,cache[key]);continue
            end
            v=x.exact(0)
            for j in 0:k
                e=j+1-ν
                term=e==0 ? x.log_i(x.divi(uU,uL)) :
                    x.divi(x.sub(x.powhalf(uU,e),x.powhalf(uL,e)),x.exact(e))
                c=x.qrat(BigInt(binomial(big(k),big(j)))//BigInt(1))
                v=x.add(v,x.divi(x.mul(c,x.mul(x.powi(x.neg(C),k-j),term)),x.powi(B,k+1)))
            end
            cache[key]=v;push!(res,v)
        end
        return res
    end
    x0=x.neg(x.divi(B,x.mul(x.exact(2),A)))
    δ=x.sub(x.divi(C,A),x.powi(x0,2));yl=x.sub(L,x0);yu=x.sub(U,x0)
    sgn=(yl[1]>0 && yu[1]>0) ? 1 : ((yl[2]<0 && yu[2]<0) ? -1 : 0)
    (branch.delta_sign>0 || sgn!=0) || error("centered y interval crosses zero on a singular/disconnected branch")
    # Branch classification uses exact rational geometry metadata from caller;
    # intervals are then evaluated outward on that resolved branch.
    function getI(k,v)
        key=(k,v);haskey(cache,key)&&return cache[key]
        if k==0
            z=_directed_i0(A,δ,yl,yu,v,branch.delta_sign,sgn,x;cache=i0memo)
        elseif k==1
            c=x.qrat(BigInt(numerator(2*(1-v)))//BigInt(denominator(2*(1-v))))
            z=x.add(x.mul(x0,getI(0,v)),v==1 ? x.divi(x.sub(x.log_i(qendpoint(:U)),x.log_i(qendpoint(:L))),x.mul(x.exact(2),A)) :
                x.divi(x.sub(qendpointpow(:U,1-v),qendpointpow(:L,1-v)),x.mul(c,A)))
        else
            upper_term=endpoint_product(:U,k-1,1-v)
            lower_term=endpoint_product(:L,k-1,1-v)
            rhs=(lower_term[1]==0 && lower_term[2]==0) ? upper_term : x.sub(upper_term,lower_term)
            den=(k+1-2v)
            if den==0
                z=x.divi(x.sub(x.sub(getI(k-2,v-1),x.mul(B,getI(k-1,v))),x.mul(C,getI(k-2,v))),A)
            else
                ck=x.qrat(BigInt(numerator(k-v))//BigInt(denominator(k-v)))
                cd=x.qrat(BigInt(den)//BigInt(1));cc=x.qrat(BigInt(k-1)//BigInt(1))
                z=x.divi(x.sub(x.sub(rhs,x.mul(ck,x.mul(B,getI(k-1,v)))),
                    x.mul(cc,x.mul(C,getI(k-2,v)))),x.mul(cd,A))
            end
        end
        cache[key]=z;z
    end
    [getI(k,ν) for k in 0:16]
end

"""Directed moments of `t^k log(A*t^2+B*t+C)` for a strictly positive quadratic.

The positive quadratic is kept correlated throughout: its discriminant branch
is resolved from exact rational coefficients, while endpoint logs and atan are
outward rounded by the shared interval API. Integration by parts reduces each
log moment to the closed-form rational moments `∫t^j/S`.
"""
function _directed_log_quadratic_moments(A::Rational{BigInt},B::Rational{BigInt},
        C::Rational{BigInt},L::Rational{BigInt},U::Rational{BigInt},nmax::Integer,api)
    nmax isa Integer && !(nmax isa Bool) && 0<=nmax<=128 || error("invalid log-quadratic moment degree")
    A>0 && U>L || error("log-quadratic moments require positive curvature and ordered endpoints")
    disc=4A*C-B^2
    disc>=0 || error("line distance quadratic has a negative exact discriminant")
    x=api;rat(r)=BigInt(numerator(r))//BigInt(denominator(r));ivrat(r)=x.qrat(rat(r))
    s=disc==0 ? x.exact(0) : x.sqrt_i(ivrat(disc))
    endpoint(t)=ivrat(A*t*t+B*t+C)
    lo=endpoint(L);hi=endpoint(U)
    lo[1]>0 && hi[1]>0 || error("positive quadratic endpoint enclosure is absent")
    # Endpoint powers and plain monomial integrals are exact rationals. Build
    # them once and round each endpoint power only once, rather than charging
    # repeated interval exponentiation in both the inverse-power recurrence
    # and every logarithmic boundary term.
    endpoint_power=Vector{Tuple{Rational{BigInt},Rational{BigInt}}}(undef,nmax+2)
    plain_exact=Vector{Rational{BigInt}}(undef,nmax+1)
    endpoint_power[1]=(1//BigInt(1),1//BigInt(1))
    for d in 1:nmax+1
        api.charge_exact(2)
        lp,up=endpoint_power[d]
        endpoint_power[d+1]=(lp*L,up*U)
    end
    for d in 0:nmax
        api.charge_exact(3)
        plain_exact[d+1]=(endpoint_power[d+2][2]-endpoint_power[d+2][1])/BigInt(d+1)
    end
    endpoint_power_iv=Tuple((ivrat(p[1]),ivrat(p[2])) for p in endpoint_power)
    plain_iv=Tuple(ivrat(p) for p in plain_exact)
    I=Vector{Tuple{BigFloat,BigFloat}}(undef,nmax+3)
    yL=x.add(x.mul(x.exact(2),x.mul(ivrat(A),ivrat(L))),ivrat(B))
    yU=x.add(x.mul(x.exact(2),x.mul(ivrat(A),ivrat(U))),ivrat(B))
    uL=2A*L+B;uU=2A*U+B;du=uU-uL
    du>0 || error("line parameter interval must be ordered")
    same_side=(uL>0 && uU>0) || (uL<0 && uU<0)
    if disc==0
        same_side || error("collinear line parameter interval crosses its exact zero")
        I0=x.divi(x.mul(x.exact(2),ivrat(du)),ivrat(uL*uU))
    elseif !same_side
        # A strictly positive distance quadratic may have its vertex inside the
        # segment (Δ>0); keep the monotone directed endpoint-atan difference.
        zL=x.divi(yL,s);zU=x.divi(yU,s)
        I0=x.divi(x.mul(x.exact(2),x.sub(x.atan_i(zU),x.atan_i(zL))),s)
    else
        den=disc+uL*uU
        den>0 || error("same-side quadratic atan reduction has nonpositive denominator")
        # Stable same-side atan difference for arbitrary [L,U]. If
        # z=du*sqrt(Δ)/(Δ+uL*uU), then I0=2*du/(Δ+uL*uU)*atan(z)/z.
        z2=du*du*disc/(den*den)
        if z2<1//4
            z2i=ivrat(z2);poly=x.exact(0)
            for j in 12:-1:0
                c=(isodd(j) ? -1 : 1)//BigInt(2j+1)
                poly=x.add(x.mul(poly,z2i),ivrat(c))
            end
            z2pow=x.powi(z2i,13)
            tail=x.divi(z2pow,x.mul(x.exact(27),x.sub(x.exact(1),z2i)))
            ratio=x.add(poly,(-tail[2],tail[2]))
            I0=x.divi(x.mul(x.mul(x.exact(2),ivrat(du)),ratio),ivrat(den))
        else
            z=x.divi(x.mul(ivrat(du),s),ivrat(den))
            I0=x.divi(x.mul(x.exact(2),x.atan_i(z)),s)
        end
    end
    I[1]=I0
    I1=x.sub(x.divi(x.sub(x.log_i(hi),x.log_i(lo)),x.mul(x.exact(2),ivrat(A))),
        x.mul(x.divi(ivrat(B),x.mul(x.exact(2),ivrat(A))),I0))
    nmax+3>=2 && (I[2]=I1)
    for k in 2:nmax+2
        # t^k/S = t^(k-2)/A - (B/A)t^(k-1)/S - (C/A)t^(k-2)/S
        plain=plain_iv[k-1]
        I[k+1]=x.sub(x.sub(x.divi(plain,ivrat(A)),
            x.mul(x.divi(ivrat(B),ivrat(A)),I[k])),
            x.mul(x.divi(ivrat(C),ivrat(A)),I[k-1]))
    end
    logs=Vector{Tuple{BigFloat,BigFloat}}(undef,nmax+1)
    for k in 0:nmax
        lpow,upow=endpoint_power_iv[k+2]
        boundary=x.sub(x.mul(x.divi(upow,ivrat(BigInt(k+1)//1)),x.log_i(hi)),
            x.mul(x.divi(lpow,ivrat(BigInt(k+1)//1)),x.log_i(lo)))
        rational_part=x.add(x.mul(x.mul(x.exact(2),ivrat(A)),I[k+3]),x.mul(ivrat(B),I[k+2]))
        logs[k+1]=x.sub(boundary,x.divi(rational_part,ivrat(BigInt(k+1)//1)))
    end
    (inverse_power_moments=Tuple(I[1:nmax+1]),log_moments=Tuple(logs),
        exact_quadratic=(A=A,B=B,C=C,discriminant=disc),domain=(L=L,U=U))
end

_polytrim(p::Vector{Rational{BigInt}})=begin
    while length(p)>1 && iszero(p[end]);pop!(p);end;p
end
_polyadd(a::Vector{Rational{BigInt}},b::Vector{Rational{BigInt}})=_polytrim(
    [get(a,i,0//BigInt(1))+get(b,i,0//BigInt(1)) for i in 1:max(length(a),length(b))])
_polyscale(a::Vector{Rational{BigInt}},c::Rational{BigInt})=_polytrim([x*c for x in a])
function _polymul(a::Vector{Rational{BigInt}},b::Vector{Rational{BigInt}})
    z=fill(0//BigInt(1),length(a)+length(b)-1)
    for i in eachindex(a),j in eachindex(b);z[i+j-1]+=a[i]*b[j];end
    _polytrim(z)
end
function _directed_polynomial_quadratic_moment(poly::Vector{Rational{BigInt}},
        S::NTuple{3,Rational{BigInt}},domain::Tuple{Rational{BigInt},Rational{BigInt}},
        p::Int,logS::Bool,api,moment_data)
    p>=-1 || error("only reciprocal-or-higher quadratic powers are supported")
    A,B,C=S;L,U=domain;x=api
    if p==-1
        logS && error("log(S)/S moment is outside this analytic series contract")
        w=poly;basis=moment_data.inverse_power_moments
    else
        Spoly=Rational{BigInt}[C,B,A];w=poly
        for _ in 1:p
            api.charge_exact(2*length(w)*length(Spoly))
            w=_polymul(w,Spoly)
        end
        basis=logS ? moment_data.log_moments : moment_data.plain_moments
    end
    api.charge_exact(8*length(w))
    length(w)<=length(basis) || error("shared quadratic moment table is too short")
    z=x.exact(0)
    for k in eachindex(w)
        iszero(w[k]) && continue
        z=x.add(z,x.mul(x.qrat(w[k]),basis[k]))
    end
    z
end

"""Pilot q/log-quadratic AB moments (no kernel calls or local Taylor boxes).

The geometry remains the exact affine-edge quadratic `S=d²` and `D`; the
elliptic complementary-parameter series is expanded through N=5, while only
the smooth D factor is expanded about its exact midpoint through M. Signed
continuous-minus-saved moments are retained componentwise for the caller.
For a radial target endpoint, pass `weighted_endpoint=(endpoint=:start|:end,
weight_slope=...)`. The helper orients the singular endpoint to `s=0`, requires
the exact affine geometry `S(s)=kappa*s^2`, and integrates the supplied
vanishing weight `weight_slope*s`; `:end` moments are mapped back to original
edge parameter `t` before returning. Use slope `1.0` when a shared geometry
certificate will be contracted with direction-specific signed chain weights.
"""
function certify_ring_edge_qlog_moments(T,P,Q,mu0,stored_q8=nothing;
        shared_ops=Ref(0),max_interval_ops=8_000_000,q_terms=5,d_order=8,
        moment_cache=Dict{Any,Any}(),exact_ops=Ref(0),max_line_moment_work_units=typemax(Int),
        weighted_endpoint=nothing,continuous_only=false)
    q_terms==5 && d_order in (8,9,10) || error("pilot controls require q N=5 and D order 8, 9, or 10")
    continuous_only isa Bool || error("continuous_only must be boolean")
    if continuous_only
        stored_q8===nothing || error("continuous-only mode does not accept or inspect saved Q8 samples")
    else
        stored_q8!==nothing && length(stored_q8)==8 || error("AB qlog moments require exactly eight stored Q8 samples")
    end
    shared_ops isa Base.RefValue && 0<=shared_ops[]<=max_interval_ops || error("invalid shared interval ledger")
    moment_cache isa AbstractDict || error("moment cache must be a shared dictionary")
    length(T)==2 && length(P)==2 && length(Q)==2 || error("T/P/Q must be R/Z pairs")
    typeof(mu0)===Float64 && isfinite(mu0) && mu0>0 || error("mu0 must be positive finite Float64")
    # The exact-dyadic geometry ledger is deliberately separate from the
    # inherited source-clipping ledger and is reported independently.
    exact_ops isa Base.RefValue && 0<=exact_ops[]<=max_line_moment_work_units || error("invalid line-moment rational work ledger")
    exact_start=Int(exact_ops[]);op_start=Int(shared_ops[])
    exact_charge!(n=1)=begin
        exact_ops[]<=max_line_moment_work_units-n || error("line-moment rational work-unit cap exceeded")
        exact_ops[]+=n
    end
    rat(x)=begin
        x isa Rational{BigInt} && return x
        x isa Float64 && return Rational{BigInt}(x)
        error("line geometry inputs must be Float64 or exact BigInt rationals")
    end
    # Fixed-format interval arithmetic; every rounded endpoint consumes the
    # caller's shared postprocessing ledger.
    charge!(n=1)=begin
        shared_ops[]<=max_interval_ops-n || error("qlog line moments exceed interval cap")
        shared_ops[]+=n
    end
    down(f)=(charge!();setrounding(BigFloat,RoundDown) do;f();end)
    up(f)=(charge!();setrounding(BigFloat,RoundUp) do;f();end)
    ivrat(r::Rational{BigInt})=(down(()->BigFloat(r)),up(()->BigFloat(r)))
    exactiv(x)=x isa Rational{BigInt} ? ivrat(x) : ivrat(rat(Float64(x)))
    add(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
    sub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
    neg(a)=(-a[2],-a[1])
    mul(a,b)=begin
        charge!(4);(minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
    end
    divi(a,b)=begin b[1]>0 ? mul(a,(down(()->inv(b[2])),up(()->inv(b[1])))) : error("positive divisor required") end
    sqrt_i(a)=begin a[1]>0 || error("positive square root required");(down(()->sqrt(a[1])),up(()->sqrt(a[2]))) end
    log_i(a)=begin a[1]>0 || error("positive log argument required");(down(()->log(a[1])),up(()->log(a[2]))) end
    atan_i(a)=(down(()->atan(a[1])),up(()->atan(a[2])))
    qrat(r::Rational{BigInt})=ivrat(r)
    api=(exact=x->exactiv(x),add=add,sub=sub,mul=mul,divi=divi,sqrt_i=sqrt_i,log_i=log_i,
        atan_i=atan_i,asinh_i=x->(down(()->asinh(x[1])),up(()->asinh(x[2]))),qrat=qrat,neg=neg,
        charge_exact=exact_charge!,
        powi=(a,n)->begin z=ivrat(1//BigInt(1));for _ in 1:n;z=mul(z,a);end;z end,
        powhalf=(a,e)->begin
            n=numerator(e);d=denominator(e);d==2 || error("unsupported power denominator")
            n>=0 ? sqrt_i(api.powi(a,n)) : divi(ivrat(1//BigInt(1)),sqrt_i(api.powi(a,-n)))
        end)
    target=ntuple(i->rat(T[i]),2);pa=ntuple(i->rat(P[i]),2);pb=ntuple(i->rat(Q[i]),2)
    endpoint_mode=weighted_endpoint!==nothing
    endpoint_kind=:none;endpoint_slope=0//BigInt(1)
    if endpoint_mode
        hasproperty(weighted_endpoint,:endpoint) && hasproperty(weighted_endpoint,:weight_slope) ||
            error("weighted endpoint metadata requires endpoint and exact weight_slope")
        endpoint_kind=weighted_endpoint.endpoint
        endpoint_kind in (:start,:end) || error("weighted endpoint must be :start or :end")
        endpoint_slope=rat(weighted_endpoint.weight_slope)
        endpoint_slope>0 || error("weighted endpoint slope must be strictly positive")
        if endpoint_kind===:end
            pa,pb=pb,pa
        end
    end
    dx=pb[1]-pa[1];dz=pb[2]-pa[2];R=target[1]
    R>0 || error("cylindrical target radius must be positive")
    # S(t)=(a(t)-R)^2+(Z-z(t))^2; D=S+4Ra. Rational coefficients are
    # the exact Float64 affine map, not interval products of endpoint boxes.
    x0=pa[1]-R;z0=target[2]-pa[2];vz=-dz
    S=(dx*dx+vz*vz,2*(x0*dx+z0*vz),x0*x0+z0*z0)
    D=(S[1],S[2]+4R*dx,S[3]+4R*pa[1])
    exact_charge!(256)
    S[1]>0 || error("degenerate AB edge has no unique quadratic moment chart")
    zrat=0//BigInt(1);orat=1//BigInt(1);Svec=Rational{BigInt}[S[3],S[2],S[1]]
    Dvec=Rational{BigInt}[D[3],D[2],D[1]]
    padd(a,b)=begin exact_charge!(max(length(a),length(b)))
        _polyadd(a,b)
    end
    pmul(a,b)=begin exact_charge!(2*length(a)*length(b));_polymul(a,b);end
    pscale(a,c)=begin exact_charge!(length(a));_polyscale(a,c);end
    # S and D are stored in descending order (quadratic, linear, constant).
    peval(c,t)=c[3]+c[2]*t+c[1]*t*t
    dmid=peval(D,1//BigInt(2));dmid>0 || error("midpoint denominator is not positive")
    Wvec=pscale(padd(Dvec,pscale(Rational{BigInt}[dmid],-1//BigInt(1))),1//dmid)
    # Exact extrema of the convex quadratics on the closed edge.
    function qrange(c)
        vals=(c[3],c[1]+c[2]+c[3]);lo=min(vals...);hi=max(vals...)
        v=-c[2]/(2c[1]);0<v<1 && (lo=min(lo,peval(c,v)))
        lo,hi
    end
    dmin2,dmax2=qrange(S);Dmin2,Dmax2=qrange(D)
    endpoint_mode ? (dmin2==0 && S[2]==0 && S[3]==0 && S[1]>0 || error("weighted endpoint requires exact S(s)=kappa*s^2")) :
        (dmin2>0 || error("exact line quadratics are not strictly positive"))
    Dmin2>0 || error("exact denominator quadratic must be strictly positive")
    # The smooth D expansion must converge on the entire edge.
    wrange=qrange((Wvec[3],Wvec[2],Wvec[1]));eta=max(abs(wrange[1]),abs(wrange[2]))
    eta<1 || error("whole-edge smooth-D expansion has radius ratio >= 1")
    qlo=endpoint_mode ? 0//BigInt(1) : dmin2/Dmax2
    qhi=min(dmax2/Dmin2,1-4R*min(pa[1],pb[1])/Dmax2)
    0<=qlo<qhi<1 || error("exact complementary parameter range is not inside [0,1)")
    logSmax=if endpoint_mode
        max(abs(log_i(ivrat(dmax2))[1]),abs(log_i(ivrat(dmax2))[2]))
    else
        logSmin_iv=log_i(ivrat(dmin2));logSmax_iv=log_i(ivrat(dmax2))
        max(abs(logSmin_iv[1]),abs(logSmax_iv[2]))
    end
    Smaxrat=dmax2
    # Polynomial helpers below deliberately accept coefficient Vectors only.
    # Keep the descending-order geometry tuple `S=(A,B,C)` separate from ascending
    # polynomial containers used by `_polymul`/`_polyadd`.
    Uc=Rational{BigInt}[S[3]+2R*pa[1],S[2]+2R*dx,S[1]]
    # Direct numerator of H=(a-R)(a+R)-dz(t)^2.
    hz0=target[2]-pa[2];hzv=-dz
    Uh=Rational{BigInt}[pa[1]^2-R^2-hz0^2,2pa[1]*dx-2hz0*hzv,dx^2-hzv^2]
    endpoint_weight_poly=endpoint_mode ? Rational{BigInt}[0//BigInt(1),endpoint_slope] : Rational{BigInt}[1//BigInt(1)]
    function divide_by_endpoint_S(poly)
        endpoint_mode || error("endpoint polynomial cancellation requested in regular mode")
        length(poly)>=3 && iszero(poly[1]) && iszero(poly[2]) ||
            error("weighted endpoint numerator is not exactly divisible by s^2")
        exact_charge!(length(poly)+1)
        Rational{BigInt}[poly[i+2]/S[1] for i in 1:length(poly)-2]
    end
    polymax(c)=sum(abs,c)
    Ucmax=polymax(Uc);Uhmax=polymax(Uh)
    zpoly=Rational{BigInt}[target[2]-pa[2],-dz]
    # K coefficients A_n and logarithmic shifts delta_n; E coefficients B_n/2.
    As=Rational{BigInt}[1//BigInt(1)];Bs=Rational{BigInt}[1//BigInt(1)];deltas=Rational{BigInt}[0//BigInt(1)]
    es=Rational{BigInt}[]
    for n in 0:q_terms-1
        exact_charge!(24)
        push!(es,1//BigInt((2n+1)*(2n+2)))
        push!(As,As[end]*BigInt((2n+1)^2)//BigInt((2n+2)^2))
        push!(Bs,Bs[end]*BigInt((2n+1)*(2n+3))//BigInt(4*(n+1)*(n+2)))
        push!(deltas,deltas[end]+2//BigInt((2n+1)*(2n+2)))
    end
    # For each exponent alpha, use D^-alpha(ln4-delta-.5logS+.5logD)
    # = Dmid^-alpha Σ b_m w^m(C-.5H_m-.5logS).
    dc(α)=begin
        n=numerator(α);den=denominator(α)
        den==2 || error("smooth D exponent must be a half integer")
        api.powhalf(ivrat(dmid),-n//2)
    end
    bcoeff(α,m)=begin
        exact_charge!(8*m)
        b=1//BigInt(1);for j in 0:m-1;b *= -((numerator(α)+denominator(α)*j)//BigInt(denominator(α)*(j+1)));end;b
    end
    # The normalizer for ln(4/sqrt(q)) and Dmid is interval-valued.
    piI=(down(()->BigFloat(pi)),up(()->BigFloat(pi)))
    global_pref=divi(exactiv(mu0),mul(exactiv(2),piI))
    ln4=log_i(exactiv(4));logDmid=log_i(ivrat(dmid))
    ln4halfD=add(ln4,mul(exactiv(1//BigInt(2)),logDmid))
    # After exact series coalescing, P/Q have degree <= 30 and their four
    # shifted log moments need degree <= 33.  R/S needs inverse moments only
    # through degree 25.  This avoids the old uniform degree-64 table.
    log_moment_degree_cap=3 + max(4 + 2q_terms + 2d_order,
        6 + 2*(q_terms-1) + 2d_order)
    inverse_moment_degree_cap=3 + 6 + 2d_order
    moment_key=(:qlog_edge_quadratic_basis_v2,S,0//BigInt(1),1//BigInt(1),endpoint_mode,endpoint_slope,
        precision(BigFloat(1)),log_moment_degree_cap,inverse_moment_degree_cap,
        objectid(shared_ops),objectid(exact_ops))
    shared_moments=get!(moment_cache,moment_key) do
        exact_charge!(128+64*(log_moment_degree_cap+1))
        if endpoint_mode
            κlog=log_i(ivrat(S[1]))
            logs=Tuple(begin
                n=BigInt(j);a=divi(κlog,exactiv(n+1));b=exactiv(2//((n+1)^2));sub(a,b)
            end for j in 0:log_moment_degree_cap)
            (inverse_power_moments=(),log_moments=logs)
        else
            rational_moments=_directed_log_quadratic_moments(S[1],S[2],S[3],
                0//BigInt(1),1//BigInt(1),log_moment_degree_cap,api)
            (inverse_power_moments=rational_moments.inverse_power_moments,
             log_moments=rational_moments.log_moments)
        end
    end
    for (momroot,required) in ((log_moment_degree_cap,33),(inverse_moment_degree_cap,25))
        momroot>=required || error("coalesced moment basis degree is below the polynomial contraction requirement")
    end
    function contract_interval(poly,basis,k)
        length(poly)+k-1<=length(basis) || error("coalesced moment basis is too short")
        acc=exactiv(0)
        for i in eachindex(poly)
            iszero(poly[i]) && continue
            exact_charge!(2)
            acc=add(acc,mul(qrat(poly[i]),basis[i+k]))
        end
        acc
    end
    function contract_plain(poly,k)
        acc=0//BigInt(1)
        for i in eachindex(poly)
            iszero(poly[i]) && continue
            exact_charge!(3)
            acc += poly[i]/BigInt(i+k)
        end
        ivrat(acc)
    end
    w_powers=Vector{Vector{Rational{BigInt}}}(undef,d_order+1)
    w_powers[1]=Rational{BigInt}[1//BigInt(1)]
    for m in 1:d_order
        w_powers[m+1]=pmul(w_powers[m],Wvec)
    end
    S_powers=Vector{Vector{Rational{BigInt}}}(undef,q_terms+1)
    S_powers[1]=Rational{BigInt}[1//BigInt(1)]
    for n in 1:q_terms
        S_powers[n+1]=pmul(S_powers[n],Svec)
    end
    invD_powers=Vector{Rational{BigInt}}(undef,q_terms+1)
    invD_powers[1]=1//BigInt(1)
    for n in 1:q_terms
        exact_charge!(1);invD_powers[n+1]=invD_powers[n]/dmid
    end
    d_coeff_cache=Dict{Rational{BigInt},Any}()
    function d_coefficients(α)
        get!(d_coeff_cache,α) do
            b=Vector{Rational{BigInt}}(undef,d_order+2);h=similar(b)
            b[1]=1//BigInt(1);h[1]=0//BigInt(1)
            for m in 1:d_order+1
                exact_charge!(4)
                b[m+1]=b[m]*(-((numerator(α)+denominator(α)*(m-1))//BigInt(denominator(α)*m)))
                h[m+1]=h[m]+BigInt(denominator(α))//BigInt(numerator(α)+denominator(α)*(m-1))
            end
            (b=b,h=h)
        end
    end
    function add_D_tail!(tail,poly,p,α,scalar,δ;plain=false)
        dc_hi=dc(α)[2];M=d_order;series=d_coefficients(α);bn=abs(series.b[M+2])
        r=up(()->BigFloat(eta)*max(BigFloat(1),BigFloat(numerator(α)+denominator(α)*(M+1))/BigFloat(denominator(α)*(M+2))))
        r<1 || error("D-series remainder ratio is not below one")
        t0=up(()->BigFloat(bn)*BigFloat(eta)^(M+1))
        supS=p<0 ? up(()->inv(BigFloat(dmin2))) : up(()->BigFloat(Smaxrat)^p)
        if endpoint_mode
            if plain
                rem=up(()->dc_hi*t0/(1-r))
            else
                Hstart=up(()->sum(inv(BigFloat(α)+j) for j in 0:M))
                Ccenter=add(ln4halfD,exactiv(-δ))
                Cabs=up(()->max(abs(Ccenter[1]),abs(Ccenter[2])))
                logκ=log_i(ivrat(S[1]))
                Aconst=up(()->Cabs+Hstart/2+max(abs(logκ[1]),abs(logκ[2]))/2)
                Htail=up(()->r/(2*(BigFloat(α)+M+1)*(1-r)^2))
                rem=up(()->dc_hi*t0/(1-r))
            end
            # Preserve the endpoint weight in the integral. Since log S =
            # log(kappa)+2log(s), its unbounded part is integrable against
            # each exact rational polynomial coefficient.
            integ=BigFloat(0)
            for j in eachindex(poly)
                iszero(poly[j]) && continue
                coeff=up(()->abs(BigFloat(poly[j])))
                if plain
                    piece=up(()->coeff/BigFloat(j))
                else
                    piece=up(()->coeff*((Aconst+Htail)/BigFloat(j)+inv(BigFloat(j)^2)))
                end
                integ=up(()->integ+piece)
            end
            term=up(()->rem*integ*BigFloat(abs(scalar))*BigFloat(supS))
            tail[]=up(()->tail[]+term)
            return nothing
        elseif plain
            rem=up(()->dc_hi*t0/(1-r))
        else
            Hstart=up(()->sum(inv(BigFloat(α)+j) for j in 0:M))
            Ccenter=add(ln4halfD,exactiv(-δ))
            Cmax=up(()->max(abs(Ccenter[1]),abs(Ccenter[2]))+logSmax/2)
            rem=up(()->dc_hi*t0*((Cmax+Hstart/2)/(1-r)+r/(2*(BigFloat(α)+M+1)*(1-r)^2)))
        end
        supP=up(()->BigFloat(polymax(poly)))
        term=up(()->rem*supP*supS*abs(BigFloat(scalar)))
        tail[]=up(()->tail[]+term)
        nothing
    end
    root_scale=dc(1//BigInt(2))
    common_scale=mul(global_pref,root_scale)
    # Signed continuous moments, ordered (Br,Bz), each with powers t^0..t^3.
    dtail_by_component=fill(BigFloat(0),2)
    continuous_by_component=Vector{NTuple{4,Tuple{BigFloat,BigFloat}}}(undef,2)
    for c in 1:2
        # Store the k-independent field numerator; `contract_*` applies the
        # requested t^(k-1) moment by shifting the shared basis index.
        tpoly=Rational{BigInt}[1//BigInt(1)]
        field_poly=c==1 ? pmul(pscale(zpoly,inv(R)),tpoly) : tpoly
        Un=c==1 ? Uc : Uh
        moment_poly=c==1 ? pmul(pscale(pmul(Un,zpoly),inv(R)),tpoly) : pmul(Un,tpoly)
        if endpoint_mode
            field_poly=pmul(field_poly,endpoint_weight_poly)
            moment_poly=pmul(moment_poly,endpoint_weight_poly)
        end
        Ppoly=Rational{BigInt}[0//BigInt(1)];Qpoly=Rational{BigInt}[0//BigInt(1)]
        Rpoly=Rational{BigInt}[0//BigInt(1)];tail=Ref(BigFloat(0))

        # K logarithmic terms: combine q^n and the full D series in exact
        # polynomial space before any interval contraction.
        for n in 0:q_terms
            α=BigInt(2n+1)//BigInt(2);series=d_coefficients(α)
            scalar=c==1 ? -As[n+1] : As[n+1]
            add_D_tail!(tail,field_poly,n,α,scalar,deltas[n+1])
            base=pmul(field_poly,S_powers[n+1]);dscale=invD_powers[n+1]
            for m in 0:d_order
                exact_charge!(2)
                coefficient=scalar*series.b[m+1]*dscale
                shift=deltas[n+1]+series.h[m+1]/2
                term=pmul(base,w_powers[m+1])
                Ppoly=padd(Ppoly,pscale(term,coefficient))
                Qpoly=padd(Qpoly,pscale(term,-coefficient*shift))
            end
        end
        # E logarithmic q-series terms.
        for n in 0:q_terms-1
            α=BigInt(2n+3)//BigInt(2);series=d_coefficients(α)
            scalar=Bs[n+1]/2;δ=deltas[n+1]+es[n+1]
            add_D_tail!(tail,moment_poly,n,α,scalar,δ)
            base=pmul(moment_poly,S_powers[n+1]);dscale=invD_powers[n+2]
            for m in 0:d_order
                exact_charge!(2)
                coefficient=scalar*series.b[m+1]*dscale
                shift=δ+series.h[m+1]/2
                term=pmul(base,w_powers[m+1])
                Ppoly=padd(Ppoly,pscale(term,coefficient))
                Qpoly=padd(Qpoly,pscale(term,-coefficient*shift))
            end
        end
        # E constant term is the only 1/S term; share the same D series.
        α=1//BigInt(2);series=d_coefficients(α)
        remainder_poly=endpoint_mode ? divide_by_endpoint_S(moment_poly) : moment_poly
        add_D_tail!(tail,remainder_poly,endpoint_mode ? 0 : -1,α,1//BigInt(1),0//BigInt(1);plain=true)
        for m in 0:d_order
            exact_charge!(1)
            term=pmul(remainder_poly,w_powers[m+1])
            Rpoly=padd(Rpoly,pscale(term,series.b[m+1]))
        end
        # Contract only the four requested moments. Ordinary polynomial
        # integrals on [0,1] are exact rationals; only log(S) and 1/S tables
        # require directed interval arithmetic.
        vals=ntuple(k->begin
            shift=k-1
            pplain=contract_plain(Ppoly,shift)
            plog=contract_interval(Ppoly,shared_moments.log_moments,shift)
            qplain=contract_plain(Qpoly,shift)
            rinv=endpoint_mode ? contract_plain(Rpoly,shift) : contract_interval(Rpoly,shared_moments.inverse_power_moments,shift)
            bracket=add(sub(mul(ln4halfD,pplain),mul(exactiv(1//BigInt(2)),plog)),qplain)
            mul(common_scale,add(bracket,rinv))
        end,4)
        dtail_by_component[c]=up(()->mul(global_pref,(BigFloat(0),tail[]))[2]*(endpoint_mode && endpoint_kind===:end ? 8 : 1))
        continuous_by_component[c]=if endpoint_mode && endpoint_kind===:end
            ntuple(k->begin
                acc=exactiv(0)
                for j in 0:k-1
                    coeff=BigInt(binomial(k-1,j))*(-1)^j
                    acc=add(acc,mul(exactiv(coeff),vals[j+1]))
                end
                acc
            end,4)
        else
            vals
        end
    end
    dtail=Matrix{BigFloat}(undef,2,4)
    for c in 1:2,k in 1:4;dtail[c,k]=dtail_by_component[c];end
    cont=ntuple(c->continuous_by_component[c],2)
    # DLMF q-series omitted tails: coefficients are bounded by one,
    # shifts by two, and q stays below qhi on the full edge.
    # The first omitted K and E powers are both q^(N+1)=q^6.
    qhi_iv=ivrat(qhi)
    qtail_den_lo=down(()->1-qhi_iv[2])
    prefmax=up(()->divi(exactiv(mu0),mul(exactiv(2),piI))[2]/sqrt_i(ivrat(Dmin2))[1])
    qerr=if endpoint_mode
        κ_over_D_hi=ivrat(S[1]/Dmin2)
        κ_over_D_lo=ivrat(S[1]/Dmax2)
        κ_over_D_hi[1]>0 && κ_over_D_hi[2]<1 && κ_over_D_lo[1]>0 ||
            error("weighted endpoint q-tail requires positive kappa/D ratios and kappa/Dmin<1")
        log_c_lo=log_i(κ_over_D_lo)
        Clog=up(()->log(4)-log_c_lo[1]/2)
        function weighted_log_tail(poly)
            total=BigFloat(0)
            for j in eachindex(poly)
                iszero(poly[j]) && continue
                exact_charge!(1)
                coeff=up(()->abs(BigFloat(poly[j])))
                term=up(()->coeff*κ_over_D_hi[2]^(q_terms+1)*
                    ( (Clog+2)/BigFloat(12+j) + inv(BigFloat(12+j)^2) ) / qtail_den_lo)
                total=up(()->total+term)
            end
            total
        end
        ntuple(c->begin
            # Br's K factor is z/R; Bz's is one. The E tail uses the exact
            # cancellation W*U/S, so both endpoint singularities are absent.
            kbase=c==1 ? pscale(Rational{BigInt}[hz0,hzv],inv(R)) : Rational{BigInt}[1//BigInt(1)]
            kpoly=pmul(kbase,endpoint_weight_poly)
            unbase=c==1 ? pscale(pmul(Uc,Rational{BigInt}[hz0,hzv]),inv(R)) : Uh
            unpoly=divide_by_endpoint_S(pmul(unbase,endpoint_weight_poly))
            v=up(()->prefmax*(weighted_log_tail(kpoly)+weighted_log_tail(unpoly))*(endpoint_kind===:end ? 8 : 1))
            Tuple((BigFloat(0),v) for _ in 1:4)
        end,2)
    else
        Lmax=log_i(divi(exactiv(4),sqrt_i(ivrat(qlo))))[2]
        qtail=up(()->qhi_iv[2]^(q_terms+1)*(Lmax+2)/qtail_den_lo)
        ntuple(c->begin
            un=up(()->BigFloat(c==1 ? Ucmax/dmin2 : Uhmax/dmin2))
            zrat=c==1 ? max(abs(hz0),abs(hz0+hzv))/R : 1//BigInt(1)
            zup=up(()->BigFloat(zrat))
            v=up(()->qtail*(1+un)*prefmax*zup)
            Tuple((BigFloat(0),v) for _ in 1:4)
        end,2)
    end
    qtail=maximum(qerr[c][1][2] for c in 1:2)
    tail_2x4=ntuple(c->ntuple(k->begin
        u=up(()->dtail[c,k]+qerr[c][k][2])
        (BigFloat(0),u)
    end,4),2)
    continuous=ntuple(c->ntuple(k->begin
        (down(()->cont[c][k][1]-tail_2x4[c][k][2]),
         up(()->cont[c][k][2]+tail_2x4[c][k][2]))
    end,4),2)
    saved,signed,errors=if continuous_only
        (:typed_absent,:typed_absent,:typed_absent)
    else
        samples=ntuple(i->begin
            s=stored_q8[i];all(k->hasproperty(s,k),(:edge,:t,:weight,:ring_field_RZ)) || error("stored AB Q8 sample fields are incomplete")
            Int(s.edge)==2 || error("qlog moments require AB edge id 2")
            t0=Float64(s.t);t=endpoint_mode && endpoint_kind===:end ? 1-t0 : t0
            w=Float64(s.weight);B=s.ring_field_RZ
            0<=t<=1 && w>0 && isfinite(t) && isfinite(w) && length(B)==2 &&
                isfinite(B[1]) && isfinite(B[2]) || error("invalid stored AB Q8 sample")
            (t=t0,s=t,w=w,B=(Float64(B[1]),Float64(B[2])))
        end,8)
        saved_q8=ntuple(c->ntuple(k->begin
            acc=exactiv(0)
            for s in samples
                tp=exactiv(1)
                for _ in 1:k-1;tp=mul(tp,exactiv(s.t));end
                weighted=endpoint_mode ? mul(exactiv(endpoint_slope),mul(exactiv(s.s),tp)) : tp
                term=mul(exactiv(s.w),mul(weighted,exactiv(s.B[c])))
                acc=add(acc,term)
            end
            acc
        end,4),2)
        signed_defect=ntuple(c->ntuple(k->sub(continuous[c][k],saved_q8[c][k]),4),2)
        abs_error=ntuple(c->ntuple(k->(BigFloat(0),max(abs(signed_defect[c][k][1]),abs(signed_defect[c][k][2]))),4),2)
        (saved_q8,signed_defect,abs_error)
    end
    (schema=:x3_nonnear_ring_edge_qlog_four_moment_v1,
        status=continuous_only ? :evaluated_canonical_ring_edge_continuous_four_moments : :evaluated_canonical_ring_edge_qlog_four_moments,
        bound_type=continuous_only ?
            (endpoint_mode ? :canonical_ring_B_RZ_continuous_weighted_endpoint_D_smooth_series_with_directed_remainders : :canonical_ring_B_RZ_continuous_D_smooth_series_with_directed_remainders) :
            (endpoint_mode ? :canonical_ring_B_RZ_weighted_endpoint_qlog_D_smooth_series_with_directed_remainders : :canonical_ring_B_RZ_qlog_D_smooth_series_with_directed_remainders),
        covered_parameter=(0//BigInt(1),1//BigInt(1)),moment_parameter=:original_edge_t,moment_orders=(0,1,2,3),
        all4shared_geometry=true,field_components=(:Br,:Bz),
        coefficient_construction=:exact_rational_common_Dmid_PQR_polynomials,
        interval_contraction_scope=:final_four_moments_only,
        component_tail_scope=:one_shared_bound_per_component_reused_for_all_four_moments,
        moment_basis_degrees=(log=log_moment_degree_cap,inverse_power=inverse_moment_degree_cap),
        stored_q8_center_semantics=continuous_only ? :typed_absent : :exact_float64_dyadic_values,
        pointwise_roundoff_coverage=continuous_only ? :not_computed_no_Q8_samples_consumed : :saved_float64_Q8_treated_as_exact_comparator,
        pointwise_roundoff_residual_intervals=continuous_only ? :typed_absent : :not_separately_supplied_retain_existing_RN_radius,
        endpoint_weight=(mode=endpoint_mode ? :linear_vanishing_at_endpoint : :none,endpoint=endpoint_kind,
            slope=endpoint_slope,exact_cancellation_verified=endpoint_mode),
        continuous_minus_numeric_Q8_status=continuous_only ? :typed_absent : :evaluated_edge_moment_defect,
        caller_must_reconcile_existing_Q8_RN_radius_without_double_counting=!continuous_only,
        caller_must_reconcile_actual_production_J_RN_radius=continuous_only,
        continuous_only=continuous_only,
        continuous_moments_2x4=continuous,signed_defect_2x4=signed,error_2x4=errors,tail_2x4=tail_2x4,
        stored_q8_moments=saved,
        geometry=(S=S,D=D,distance_squared_min=dmin2,distance_squared_max=dmax2,
            denominator_min=Dmin2,denominator_max=Dmax2,q_range=(qlo,qhi),smooth_D_ratio=eta),
        interval_operations=shared_ops[],new_interval_operations=shared_ops[]-op_start,
        line_moment_rational_work_units=exact_ops[],new_line_moment_rational_work_units=exact_ops[]-exact_start,
        line_moment_rational_accounting=:explicit_conservative_work_units,
        line_moment_work_unit_cap=max_line_moment_work_units,q_series_order=q_terms,D_smooth_order=d_order,
        q_series_tail_upper=qtail,kernel_calls=0,new_quadrature_nodes=0,
        cost=(interval_ops_total=shared_ops[],interval_ops_new=shared_ops[]-op_start,
              rational_work_units_total=exact_ops[],rational_work_units_new=exact_ops[]-exact_start,
              kernels=0,new_q8_nodes=0,cap_interval=max_interval_ops,
              cap_line_moment_work_units=max_line_moment_work_units),
        fullray=false,full64=false,formal_acceptance=false)
end

function _kappa_coeffs_iv(lo,h,nodes,weights,x;lo_rat)
    c=[x.exact(0) for _ in 0:16]
    # Expand (1-lo-h*z)^16 and subtract active (xi-lo-h*z)^15 terms.
    for k in 0:16
        c[k+1]=x.add(c[k+1],x.mul(x.qrat(BigInt(binomial(big(16),big(k)))//BigInt(1)),
            x.mul(x.powi(x.sub(x.exact(1),lo),16-k),x.mul(x.powi(x.neg(h),k),x.exact(1)))))
    end
    for i in eachindex(nodes)
        _ratbig(nodes[i])>lo_rat || continue
        ξ=x.exact(nodes[i]);w=x.exact(weights[i])
        Δ=x.sub(ξ,lo)
        for k in 0:15
            term=x.mul(x.qrat(16*BigInt(binomial(big(15),big(k)))//BigInt(1)),
                x.mul(w,x.mul(x.powi(Δ,15-k),x.powi(x.neg(h),k))))
            c[k+1]=x.sub(c[k+1],term)
        end
    end
    c
end

"""Formal directed moment pass. Requires the same shared core interval API and ledger.

`interval_api` keys are `exact/add/sub/mul/divi/sqrt_i/log_i/charge!`; atan and
asinh are evaluated here with MPFR RoundDown/RoundUp and charge that same Ref.
The kernel perturbation uses the true qualified ideal-rule interval object;
stored-production-rule drift remains the caller's existing separate MVT term.
"""
function evaluate_enclosed(P0,P1,P2,T,radial_interval,nodes_center,weights_center,true_gauss_rule;
        interval_ops,max_interval_ops,interval_api,m_values=10:21,coefficient_contract=(),
        exact_ops=Ref(0),max_exact_ops=2_000_000,qa_lower,shared_geometry_cache=nothing)
    op_origin=interval_ops[];x=_directed_api(interval_ops,max_interval_ops,interval_api)
    true_gauss_rule!==nothing && true_gauss_rule.status===:evaluated_true_Gauss_rule_interval &&
        true_gauss_rule.root_count==8 && length(true_gauss_rule.mapped_nodes_and_weights)==8 ||
        error("directed Peano pass requires the actual qualified true-Gauss rule interval object")
    length(nodes_center)==8 && length(weights_center)==8 || error("candidate center rule ABI")
    # Saved rules use NTuples; normalize the collection interface once here.
    # Their values remain the same high-precision centers of the qualified rule.
    center_nodes=BigFloat[z for z in nodes_center]
    center_weights=BigFloat[z for z in weights_center]
    all(isfinite, center_nodes) && all(isfinite, center_weights) &&
        all(i->center_nodes[i]<center_nodes[i+1],1:7) && all(x->x>0,center_weights) ||
        error("ideal-rule centers must be ordered nodes and positive weights")
    qa=qa_lower isa Tuple ? qa_lower : x.exact(qa_lower)
    x.check(qa);qa[1]>0 || error("angular q lower bound must be strictly positive")
    for i in 1:8
        nw=true_gauss_rule.mapped_nodes_and_weights[i]
        nw.node[1]<=center_nodes[i]<=nw.node[2] && nw.weight[1]<=center_weights[i]<=nw.weight[2] ||
            error("center rule is outside qualified root interval at $i")
    end
    a,b=Float64.(radial_interval);isfinite(a)&&isfinite(b)&&0<=a<b || error("radial interval invalid")
    exact_ops isa Base.RefValue && exact_ops[] isa Integer && 0<=exact_ops[]<=max_exact_ops ||
        error("invalid shared exact-rational operation ledger")
    exact_origin=exact_ops[]
    rational_charge!()=begin exact_ops[]<max_exact_ops || error("exact-rational Peano operation cap");exact_ops[]+=1;end
    radd(a,b)=(rational_charge!();a+b);rsub(a,b)=(rational_charge!();a-b)
    rmul(a,b)=(rational_charge!();a*b);rdiv(a,b)=(rational_charge!();iszero(b)&&error("exact-rational Peano division by zero");a/b)
    arat,brat=_rat(a),_rat(b);Hrat=rsub(brat,arat);H=x.qrat(Hrat)
    pieces=_distance_pieces(P0,P1,P2,T,a,b;exact_ops=exact_ops,max_exact_ops=max_exact_ops)
    knots=sort!(unique!(vcat(BigFloat[0,1],filter(z->0<z<1,center_nodes))))
    length(knots)==10 || error("eight distinct center nodes are required")
    kernel_cache=shared_geometry_cache===nothing ? Dict{Any,Any}() : shared_geometry_cache
    kernel_cache isa AbstractDict || error("shared directed Peano cache must be an existing geometry dictionary")
    rule_key=(:directed_peano_fixed_rule_kernel_v1,precision(center_nodes[1]),Tuple(center_nodes),
        Tuple(center_weights),Tuple((nw.node,nw.weight) for nw in true_gauss_rule.mapped_nodes_and_weights))
    fixed_kernel=get(kernel_cache,rule_key,nothing)
    if fixed_kernel===nothing
        εK_mass=x.exact(0)
        for i in 1:8
            nw=true_gauss_rule.mapped_nodes_and_weights[i]
            ξc=center_nodes[i];wc=center_weights[i]
            x.charge!();x.charge!();x.charge!();x.charge!()
            δξ=max(setrounding(BigFloat,RoundUp) do;abs(ξc-nw.node[1]);end,
                   setrounding(BigFloat,RoundUp) do;abs(nw.node[2]-ξc);end)
            δw=max(setrounding(BigFloat,RoundUp) do;abs(wc-nw.weight[1]);end,
                   setrounding(BigFloat,RoundUp) do;abs(nw.weight[2]-wc);end)
            term=x.add(x.divi(x.mul(x.exact(δw),x.powi(x.exact(nw.node[2]),16)),x.exact(16)),
                x.mul(x.exact(nw.weight[2]),x.mul(x.exact(δξ),x.powi(x.exact(nw.node[2]),15))))
            εK_mass=x.add(εK_mass,term)
        end
        center_mass=x.exact(0);knot_records=NamedTuple[]
        for ik in 1:9
            lo_rat=_ratbig(knots[ik]);hi_rat=_ratbig(knots[ik+1]);hxrat=rsub(hi_rat,lo_rat)
            lo=x.qrat(lo_rat);hxrat_iv=x.qrat(hxrat)
            kap=_kappa_coeffs_iv(lo,hxrat_iv,center_nodes,center_weights,x;lo_rat=lo_rat)
            localmass=x.exact(0)
            for k in 0:16;localmass=x.add(localmass,x.divi(kap[k+1],x.exact(k+1)));end
            center_mass=x.add(center_mass,x.mul(hxrat_iv,localmass))
            push!(knot_records,(lo_rat=lo_rat,hi_rat=hi_rat,lo=lo,h=hxrat_iv,kappa=kap))
        end
        epsilon_kappa=x.mul(x.exact(16),εK_mass)
        center_mass_bounds=(x.sub(center_mass,epsilon_kappa),x.add(center_mass,epsilon_kappa))
        mass=x.qrat(BigInt(factorial(big(8))^4)//BigInt(17*factorial(big(16))^2))
        ideal_mass_expected=mass
        fixed_kernel=(epsilon_kappa_mass=εK_mass,center_mass=center_mass,
            center_mass_bounds=center_mass_bounds,ideal_mass_expected=ideal_mass_expected,
            epsilon_kappa=epsilon_kappa,exact_ideal_mass=mass,
            knot_records=Tuple(knot_records),knots=Tuple(knots))
        kernel_cache[rule_key]=fixed_kernel
    end
    εK_mass=fixed_kernel.epsilon_kappa_mass
    center_mass=fixed_kernel.center_mass
    center_mass_bounds=fixed_kernel.center_mass_bounds
    ideal_mass_expected=fixed_kernel.ideal_mass_expected
    epsilon_kappa=fixed_kernel.epsilon_kappa
    mass=fixed_kernel.exact_ideal_mass
    knots=collect(fixed_kernel.knots)
    center_mass_bounds[1][1]<=ideal_mass_expected[1] && center_mass_bounds[2][2]>=ideal_mass_expected[2] ||
        error("center-kernel mass plus ideal-root perturbation does not enclose exact GL8 Peano mass")
    # Build each geometry-piece × fixed-knot record once.  The same κ and
    # quadratic coefficients are reused for every unique m and every caller lane.
    segments=NamedTuple[]
    for p in pieces, ik in 1:9
        xl=knots[ik];xu=knots[ik+1]
        plo=rdiv(rsub(p.lo,arat),Hrat);phi=rdiv(rsub(p.hi,arat),Hrat)
        xlr=_ratbig(xl);xur=_ratbig(xu)
        (phi<=xlr || plo>=xur) && continue
        lo_rat=plo>xlr ? plo : xlr;hi_rat=phi<xur ? phi : xur
        lo_rat<hi_rat || continue
        hxrat=rsub(hi_rat,lo_rat)
        lo=x.qrat(lo_rat);hi=x.qrat(hi_rat);hx=x.sub(hi,lo)
        knot_index=findfirst(rec->rec.lo_rat==lo_rat && rec.hi_rat==hi_rat,fixed_kernel.knot_records)
        kappa_key=(rule_key,:kappa_interval,lo_rat,hi_rat)
        kap=knot_index===nothing ? get(kernel_cache,kappa_key,nothing) :
            fixed_kernel.knot_records[knot_index].kappa
        if kap===nothing
            kap=_kappa_coeffs_iv(lo,hx,center_nodes,center_weights,x;lo_rat=lo_rat)
            kernel_cache[kappa_key]=kap
        end
        rlo_rat=radd(arat,rmul(Hrat,lo_rat))
        hr_rat=rmul(Hrat,hxrat);Aq=rmul(p.A,rmul(hr_rat,hr_rat))
        Bq=rmul(radd(rmul(Rational{BigInt}(2),rmul(p.A,rlo_rat)),p.B),hr_rat)
        Cq=radd(radd(rmul(p.A,rmul(rlo_rat,rlo_rat)),rmul(p.B,rlo_rat)),p.C)
        A=x.qrat(Aq);B=x.qrat(Bq);C=x.qrat(Cq)
        if iszero(Aq)
            branch=(A_zero=true,B_zero=iszero(Bq),delta_sign=0)
        else
            x0q=-rdiv(Bq,rmul(Rational{BigInt}(2),Aq))
            δq=rsub(rdiv(Cq,Aq),rmul(x0q,x0q))
            branch=(A_zero=false,B_zero=false,delta_sign=sign(δq))
        end
        push!(segments,(lo=lo,hi=hi,hx=hx,hxrat=hxrat,lo_rat=lo_rat,
            kappa_coefficients=kap,A=A,B=B,C=C,branch=branch))
    end
    isempty(segments) && error("no radial × Peano pieces to integrate")
    qmins=Rational{BigInt}[]
    for p in pieces
        qvalue(r)=radd(radd(rmul(p.A,rmul(r,r)),rmul(p.B,r)),p.C)
        push!(qmins,min(qvalue(p.lo),qvalue(p.hi)))
        if p.A>0
            rv=-rdiv(p.B,rmul(Rational{BigInt}(2),p.A))
            p.lo<rv<p.hi && push!(qmins,qvalue(rv))
        end
    end
    dminrat=minimum(qmins);dminrat>0 || error("nonpositive exact chord-distance minimum")
    dmin=x.qrat(dminrat)
    radial_moments=Dict{Int,Tuple{BigFloat,BigFloat}}();moments=Dict{Int,Tuple{BigFloat,BigFloat}}()
    global_radial_moments=Dict{Int,Tuple{BigFloat,BigFloat}}();global_moments=Dict{Int,Tuple{BigFloat,BigFloat}}()
    costs=Dict{Int,Int}()
    x.charge!()
    pi_iv=(setrounding(BigFloat,RoundDown) do;BigFloat(pi);end,
           setrounding(BigFloat,RoundUp) do;BigFloat(pi);end)
    # One global analytic angular majorant, shared by every physical lane.
    # On |theta|<=1, 1-cos(theta)>=11 theta^2/24; on the remaining
    # [-pi,pi] tails it is >=11/24. This avoids the global pi/2 loss
    # without changing quadrature nodes or refining geometry boxes.
    qa_eff=x.mul(x.divi(x.exact(11),x.exact(12)),qa)
    C_m=Dict{Int,Tuple{BigFloat,BigFloat}}(2=>pi_iv,3=>x.exact(2))
    for n in 4:maximum(Int.(collect(m_values)))
        C_m[n]=x.mul(x.divi(x.exact(n-3),x.exact(n-2)),C_m[n-2])
    end
    requested_m=sort!(unique!(Int.(collect(m_values))))
    !isempty(requested_m) && all(m->10<=m<=21,requested_m) ||
        error("weighted-Q1 degree audit permits only live m values 10:21")
    kernel_mass=x.mul(x.powi(H,17),mass)
    tail_length=x.mul(x.exact(2),x.sub(pi_iv,x.exact(1)))
    tail_prefactors=Dict{Int,Tuple{BigFloat,BigFloat}}()
    segment_moment_caches=[Dict{Tuple{Int,Rational{Int}},Tuple{BigFloat,BigFloat}}() for _ in segments]
    segment_i0_caches=[Dict{Rational{Int},Tuple{BigFloat,BigFloat}}() for _ in segments]
    segment_endpoint_caches=[Dict{Any,Tuple{BigFloat,BigFloat}}() for _ in segments]
    for m in requested_m
        ν=(m-1)//2
        gmax=x.powhalf(dmin,-ν)
        center_sum=x.exact(0)
        for (iseg,seg) in enumerate(segments)
            imom=_directed_moments(seg.A,seg.B,seg.C,x.exact(0),x.exact(1),m,seg.branch,x;
                moment_cache=segment_moment_caches[iseg],i0_cache=segment_i0_caches[iseg],
                endpoint_cache=segment_endpoint_caches[iseg])
            loc=x.exact(0)
            for k in 0:16;loc=x.add(loc,x.mul(seg.kappa_coefficients[k+1],imom[k+1]));end
            center_sum=x.add(center_sum,x.mul(x.mul(x.powi(H,17),seg.hx),loc))
        end
        ε=x.mul(x.mul(x.mul(x.exact(16),x.powi(H,17)),εK_mass),gmax)
        # True ideal Gauss8 kernel is nonnegative.  The center polynomial may
        # have tiny negative interval leakage; use positivity only to tighten L.
        lower=x.sub(center_sum,ε);upper=x.add(center_sum,ε)
        enclosure=(max(BigFloat(0),lower[1]),upper[2])
        enclosure[2]>=enclosure[1] || error("kernel-perturbed moment interval is invalid")
        radial_moments[m]=enclosure;costs[m]=length(segments)
        Jfactor=x.mul(C_m[m],x.divi(x.exact(1),x.sqrt_i(qa_eff)))
        tail_prefactors[m]=x.mul(tail_length,x.powhalf(qa_eff,-m//2))
        tail_mass=x.mul(tail_prefactors[m],kernel_mass)
        moments[m]=x.add(x.mul(Jfactor,enclosure),tail_mass)
        global_radial_moments[m]=x.mul(kernel_mass,gmax)
        global_moments[m]=x.add(x.mul(Jfactor,global_radial_moments[m]),tail_mass)
    end
    coeffs=Tuple(coefficient_contract)
    contracted=isempty(coeffs) ? nothing : x.exact(0)
    global_contracted=isempty(coeffs) ? nothing : x.exact(0)
    for ent in coeffs
        hasproperty(ent,:m)&&hasproperty(ent,:coefficient)&&ent.m in keys(moments) || error("invalid directed coefficient contract")
        c=ent.coefficient isa Tuple ? ent.coefficient : x.exact(ent.coefficient)
        x.check(c);c[1]>=0 || error("directed coefficient must be nonnegative")
        contracted=x.add(contracted,x.mul(c,moments[ent.m]))
        global_contracted=x.add(global_contracted,x.mul(c,global_moments[ent.m]))
    end
    (schema=SCHEMA,status=:evaluated_directed_ideal_gauss8_peano_distance_moments,
     positive_distance_moments=moments,global_peano_moments=global_moments,
     radial_positive_distance_moments=radial_moments,global_radial_peano_moments=global_radial_moments,
     angular_prefactors=C_m,qa_lower=qa,effective_central_qa=qa_eff,
     angular_tail_prefactors=tail_prefactors,
     angular_bound=:fixed_one_radian_central_plus_whole_tail,
     coefficient_contract=(entries=coeffs,distance_correlated=contracted,global_dmin=global_contracted),
     kernel_perturbation_mass=εK_mass,geometry_pieces=pieces,normalized_peano_knots=knots,
     normalized_center_kernel_mass=center_mass,normalized_center_mass_plus_root_perturbation=center_mass_bounds,
     exact_ideal_gauss8_peano_mass=ideal_mass_expected,
     unique_radial_knot_segments=segments,exact_global_minimum_distance_squared=dminrat,
     unique_moment_cost=costs,scalar_moments=sum(values(costs)),coefficient_contractions=length(coeffs),
     interval_operation_delta=interval_ops[]-op_origin,interval_operations=interval_ops[],kernel_calls=0,new_quadrature_nodes=0,
     exact_rational_operation_delta=exact_ops[]-exact_origin,exact_rational_operations=exact_ops[],exact_rational_cap=max_exact_ops,
     stored_rule_drift=:preserve_existing_production_to_ideal_rule_MVT_term,
     true_gauss_rule_binding=(status=true_gauss_rule.status,root_count=true_gauss_rule.root_count,
       mapped_nodes_and_weights=true_gauss_rule.mapped_nodes_and_weights))
end

"""Certify the first four canonical ring-field moments using one centered Taylor proof.

`stored_q8` contains eight saved `(t,weight,ring_field_RZ)` records. `majorant`
must be the actual result of the canonical core's
`_ring_edge_moment_request=true` branch, which returns degree-12 directed
Taylor coefficient intervals and a whole-edge normalized derivative
supremum `|B^(13)|/13!`. The degree-12 polynomial times any moment power
t^k (k<=3) is within Gauss-8 exactness; the same proof serves all four moments.
"""
function certify_ring_edge_moments(T,P,Q,mu0,stored_q8;
        majorant,shared_ops=Ref(0),max_interval_ops=8_000_000,moment_cache=Dict{Any,Any}())
    length(stored_q8)==8 || error("edge K-moment certificate requires exactly eight saved Q8 samples")
    majorant isa NamedTuple && hasproperty(majorant,:schema) &&
        majorant.schema===:ccp_canonical_ring_edge_taylor_majorant_v1 &&
        majorant.status===:evaluated_canonical_nonstar_AB_edge_taylor_majorant ||
        error("an evaluated actual canonical core AB-edge Taylor majorant is required")
    shared_ops isa Base.RefValue && shared_ops[] isa Integer && !(shared_ops[] isa Bool) &&
        0<=shared_ops[]<=max_interval_ops<=8_000_000 || error("invalid shared edge interval ledger/cap")
    moment_cache isa AbstractDict || error("moment defect cache must be the caller's shared dictionary")
    point(v,n)=begin
        (v isa Tuple || v isa AbstractVector) && length(v)==2 || error("$n must be an R/Z point")
        z=Float64.(v);all(isfinite,z) || error("$n must be finite");Tuple(z)
    end
    target=point(T,"target");p=point(P,"edge start");q=point(Q,"edge end")
    typeof(mu0)===Float64 && isfinite(mu0) && mu0>0 || error("mu0 must be positive finite Float64")
    box=majorant
    hasproperty(box,:geometry) && hasproperty(box.geometry,:target) &&
        hasproperty(box.geometry,:edge_P1) && hasproperty(box.geometry,:edge_P2) &&
        box.geometry.mu0==mu0 || error("canonical majorant omits or mismatches its actual edge geometry")
    encloses(x,v)=setprecision(BigFloat,256) do
        x isa Tuple && length(x)==2 && x[1] isa BigFloat && x[2] isa BigFloat && x[1]<=BigFloat(v)<=x[2]
    end
    all(i->encloses(box.geometry.target[i][1],target[i]) &&
        encloses(box.geometry.edge_P1[i][1],p[i]) && encloses(box.geometry.edge_P2[i][1],q[i]),1:2) ||
        error("canonical majorant geometry does not enclose the requested target and oriented AB endpoints")
    samples=ntuple(i->begin
        s=stored_q8[i]
        all(k->hasproperty(s,k),(:edge,:t,:weight,:ring_field_RZ)) || error("saved Q8 sample lacks edge fields")
        Int(s.edge)==2 || error("four-moment certificate is restricted to the actual AB edge (edge=2)")
        t=Float64(s.t);w=Float64(s.weight);B=s.ring_field_RZ
        0<=t<=1 && isfinite(t) && w>0 && isfinite(w) &&
            (B isa Tuple || B isa AbstractVector) && length(B)==2 && all(y->y isa Real && isfinite(y),B) ||
            error("saved Q8 sample has invalid node, weight, or ring field")
        (edge=Int(s.edge),t=t,w=w,B=(Float64(B[1]),Float64(B[2])))
    end,8)
    issorted(Tuple(s.t for s in samples)) || error("saved edge Q8 samples must be ordered")
    weight_moments=ntuple(k->sum(s.w*s.t^(k-1) for s in samples),4)
    all(isfinite,weight_moments) && abs(weight_moments[1]-1)<=64eps(Float64) ||
        error("saved production Q8 weights do not form a normalized positive rule")
    before=Int(shared_ops[])
    hasproperty(box,:interval_operations) && box.interval_operations==shared_ops[] &&
        hasproperty(box,:interval_operation_delta) && box.interval_operation_delta isa Integer &&
        box.interval_operation_delta>=0 || error("canonical edge majorant is not bound to the caller shared interval ledger")
    all(k->hasproperty(box,k),(:coefficients_Br,:coefficients_Bz,:derivative_abs_over_factorial_Br,
        :derivative_abs_over_factorial_Bz)) || error("whole-edge Taylor majorant omitted coefficient/remainder fields")
    coeffs=(box.coefficients_Br,box.coefficients_Bz)
    derivs=(box.derivative_abs_over_factorial_Br,box.derivative_abs_over_factorial_Bz)
    valid_interval(x)=x isa Tuple && length(x)==2 && all(y->y isa BigFloat && isfinite(y),x) && x[1]<=x[2]
    all(v->length(v)==13 && all(valid_interval,v),coeffs) || error("Taylor coefficient ABI must hold 13 directed intervals per component")
    all(d->hasproperty(d,:order13),derivs) || error("Taylor derivative-majorant ABI must provide order 13")
    rem_order(d)=d.order13
    all(d->begin x=rem_order(d);x isa BigFloat && isfinite(x) && x>=0 end,derivs) ||
        error("Taylor normalized 13th derivative majorants must be finite and nonnegative")
    charge!(n)=begin
        shared_ops[]<=max_interval_ops-n || error("edge moment postprocessing exceeds shared interval cap")
        shared_ops[]+=n
    end
    down(f)=(charge!(1);setrounding(BigFloat,RoundDown) do;f();end)
    up(f)=(charge!(1);setrounding(BigFloat,RoundUp) do;f();end)
    iv(x)=(BigFloat(x),BigFloat(x)) # Float64/integers are exact at 256-bit precision.
    iadd(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
    isub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
    imul(a,b)=begin
        charge!(4)
        (minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
    end
    idivpos(a,n::Integer)=(down(()->a[1]/n),up(()->a[2]/n))
    ipow(a,n::Integer)=begin
        n>=0 || error("negative power not supported in moment interval arithmetic")
        z=iv(1);for _ in 1:n;z=imul(z,a);end;z
    end
    absupper(a)=max(abs(a[1]),abs(a[2]))
    absiv(a)=(BigFloat(0),absupper(a))
    half=iv(0.5);neg_half=iv(-0.5);zero_i=iv(0)
    moments=setprecision(BigFloat,256) do
        ntuple(c->ntuple(k->begin
            z=zero_i
            for s in samples
                z=iadd(z,imul(iv(s.w),imul(ipow(iv(s.t),k-1),iv(s.B[c]))))
            end
            z
        end,4),2)
    end
    # Exact directed moments for (t-1/2)^j t^(k-1), and their actual stored-Q8
    # counterparts. Each signed sum remains an interval until after subtraction.
    moment_key=(SCHEMA,Tuple(s.t for s in samples),Tuple(s.w for s in samples))
    moment_defect(j,k)=get!(moment_cache,(moment_key,j,k)) do
        integ=zero_i;disc=zero_i
        for l in 0:j
            term=imul(iv(binomial(big(j),big(l))),ipow(neg_half,j-l))
            integ=iadd(integ,idivpos(term,l+k))
        end
        for s in samples
            x=isub(iv(s.t),half) # convert first, then subtract under directed rounding
            term=imul(iv(s.w),imul(ipow(x,j),ipow(iv(s.t),k-1)))
            disc=iadd(disc,term)
        end
        isub(integ,disc)
    end
    errors=ntuple(c->ntuple(k->setprecision(BigFloat,256) do
        n=12;err=zero_i
        for j in 0:n
            defect=moment_defect(j,k)
            # The Taylor coefficient is itself an interval. Multiplying it by
            # the signed-moment defect as an interval handles cancellation safely.
            err=iadd(err,absiv(imul(coeffs[c][j+1],defect)))
        end
        m=n+1;M=rem_order(derivs[c])
        int_rem=up(()->BigFloat(0.5)^m/BigFloat(k))
        err=iadd(err,(BigFloat(0),up(()->M*int_rem)))
        # Float64 production values at stored nodes are compared directly with
        # the Taylor polynomial using endpoint intervals, including node rounding.
        sample_residual=zero_i
        for s in samples
            x=isub(iv(s.t),half);poly=zero_i
            for j in 0:n
                poly=iadd(poly,imul(coeffs[c][j+1],ipow(x,j)))
            end
            residual=isub(iv(s.B[c]),poly)
            weighted=imul(iv(s.w),imul(ipow(iv(s.t),k-1),absiv(residual)))
            sample_residual=iadd(sample_residual,weighted)
        end
        err=iadd(err,sample_residual)
        (BigFloat(0),err[2])
    end,4),2)
    (schema=:x3_nonnear_ring_edge_four_moment_certificate_v1,
        status=:evaluated_whole_edge_ring_field_majorant_four_moments,
        edge=(id=2,orientation=:A_to_B,target=target,P=p,Q=q,mu0=mu0,parameter_domain=(0.0,1.0)),
        stored_q8_moments=moments,error_2x4=errors,
        bound_type=:centered_degree_15_minus_moment_power_Taylor_with_explicit_rule_defect,
        shared_geometry=(one_whole_edge_majorant=true,all_four_moments=true,
            both_field_components=true,moment_errors_reusable_after_velocity_contraction=true,
            kernel_directional_jets_certified=false,center=0.5,
            degree_by_moment=(12,12,12,12),shared_remainder_derivative_order=13),
        cost=(provider_interval_operations=Int(box.interval_operation_delta),
            postprocess_interval_operations=Int(shared_ops[])-before,
            interval_operations=Int(box.interval_operation_delta)+Int(shared_ops[])-before,
            shared_interval_total=Int(shared_ops[]),
            new_kernel_calls=0,new_quadrature_nodes=0,exact_rational_operations=0),
        identity=(rule_nodes=Tuple(s.t for s in samples),rule_weights=Tuple(s.w for s in samples),
            field_source=:canonical_ccp_ring_unit_field_RZ,majorant_provider=:ccp_core_ring_edge_request,
            provider_schema=box.schema),
        fullray=false,full64=false,formal_acceptance=false,physical_validation=false)
end

"""Directed tensor GL8 Peano bound for one plasma-only far Q1 rectangle.

This encloses only the exact-kernel integral minus the ideal tensor GL8 rule.
`production_float64_remainder` is deliberately separate: callers must add the
existing production-to-ideal Float64/AGM/accumulation bound before using this
as a production enclosure.  The four local E columns are parent-Q1 basis
responses; G is contracted with the actual bilinear current polynomial and
contains only the target R/Z columns. No kernel or quadrature evaluations are
performed.
"""
function certify_far_rectangle_tensor_gl8_peano(target,bounds,mu0,current_corners;
        interval_ops=Ref(0),max_interval_ops=8_000_000,precision_bits=256,
        basis_r_endpoints=nothing,basis_z_endpoints=nothing)
    interval_ops isa Base.RefValue && interval_ops[] isa Integer && !(interval_ops[] isa Bool) &&
        0<=interval_ops[]<=max_interval_ops<=8_000_000 || error("invalid shared far-rectangle interval ledger")
    precision_bits isa Integer && !(precision_bits isa Bool) && 128<=precision_bits<=2048 ||
        error("invalid far-rectangle interval precision")
    length(target)==2 && length(bounds)==4 && length(current_corners)==4 ||
        error("far rectangle requires target, four bounds, and four Q1 current corners")
    vals=(target...,bounds...,mu0)
    all(x->x isa Float64 && isfinite(x),vals) && target[1]>0 && mu0>0 &&
        bounds[1]>0 && bounds[1]<bounds[2] && bounds[3]<bounds[4] && length(current_corners)==4 ||
        error("far rectangle contains invalid Float64 geometry/current data")
    ops0=Int(interval_ops[])
    setprecision(BigFloat,precision_bits) do
        charge!()=begin
            interval_ops[]<max_interval_ops || error("far-rectangle Peano interval cap exceeded")
            interval_ops[]+=1
        end
        down(f)=(charge!();setrounding(BigFloat,RoundDown) do;f();end)
        up(f)=(charge!();setrounding(BigFloat,RoundUp) do;f();end)
        exact(x)=(BigFloat(x),BigFloat(x))
        rat(x::Rational{BigInt})=(down(()->BigFloat(x)),up(()->BigFloat(x)))
        input_iv(x)=if x isa Tuple && length(x)==2 && all(y->y isa Real && isfinite(y),x) && x[1]<=x[2]
            (BigFloat(x[1]),BigFloat(x[2]))
        elseif x isa Rational{BigInt}
            rat(x)
        elseif x isa Real && isfinite(x)
            exact(x)
        else
            error("basis/current values must be finite reals or directed endpoint pairs")
        end
        add(a,b)=(down(()->a[1]+b[1]),up(()->a[2]+b[2]))
        sub(a,b)=(down(()->a[1]-b[2]),up(()->a[2]-b[1]))
        neg(a)=(-a[2],-a[1])
        mul(a,b)=begin
            charge!()
            (minimum(down(()->x*y) for x in a for y in b),maximum(up(()->x*y) for x in a for y in b))
        end
        divpos(a,b)=begin b[1]>0 || error("far-rectangle divisor is not positive");
            mul(a,(down(()->inv(b[2])),up(()->inv(b[1])))) end
        sqrtpos(a)=begin a[1]>0 || error("far-rectangle square root is not positive");
            (down(()->sqrt(a[1])),up(()->sqrt(a[2]))) end
        powpos(a,n)=begin z=exact(1.0);for _ in 1:n;z=mul(z,a);end;z end
        absupper(a)=max(abs(a[1]),abs(a[2]))
        R,Z=target;r0,r1,z0,z1=bounds;hR=sub(exact(r1),exact(r0));hZ=sub(exact(z1),exact(z0))
        dx=R<r0 ? sub(exact(r0),exact(R)) : R>r1 ? sub(exact(R),exact(r1)) : exact(0.0)
        dz=Z<z0 ? sub(exact(z0),exact(Z)) : Z>z1 ? sub(exact(Z),exact(z1)) : exact(0.0)
        dx[1]>=0 && dz[1]>=0 || error("distance lower coordinate became negative")
        d=sqrtpos(add(mul(dx,dx),mul(dz,dz)))
        diag=sqrtpos(add(mul(hR,hR),mul(hZ,hZ)))
        d[1]>diag[2] || error("rectangle is not in the producer's strict far-cell partition")
        rho=mul(rat(3//BigInt(4)),(d[1],d[1]))
        q=rat(3//BigInt(4));one=exact(1.0);omq=sub(one,q)
        piI=(down(()->BigFloat(pi)),up(()->BigFloat(pi)))
        amin=divpos(mul(mul(exact(4.0),exact(R)),exact(r0)),mul(piI,piI))
        root_a=sqrtpos(amin)
        rsrho=add(exact(r1),rho)
        base=divpos(exact(mu0),mul(exact(4.0),piI))
        MB=mul(mul(mul(mul(base,rsrho),divpos(add(one,q),powpos(omq,3))),piI),
            divpos(exact(1.0),mul((d[1],d[1]),root_a)))
        gshape=add(divpos(one,powpos(omq,3)),
            mul(exact(3.0),divpos(powpos(add(one,q),2),powpos(omq,5))))
        MG=mul(mul(mul(mul(mul(base,rsrho),gshape),exact(2.0)),
            divpos(exact(1.0),mul(mul((d[1],d[1]),(d[1],d[1])),root_a))),exact(1.0))
        Cgl=rat(BigInt(factorial(8))^4//(BigInt(17)*BigInt(factorial(16))^2))
        hRrho=divpos(hR,rho);hZrho=divpos(hZ,rho)
        # Parent-Q1 basis factors may be restricted to a child/subrectangle.
        # Endpoint factors are given in local child coordinates; the other
        # source axis remains real in each tensor Peano term.
        br=basis_r_endpoints===nothing ? ((1.0,0.0),(0.0,1.0),(1.0,0.0),(0.0,1.0)) : basis_r_endpoints
        bz=basis_z_endpoints===nothing ? ((1.0,0.0),(1.0,0.0),(0.0,1.0),(0.0,1.0)) : basis_z_endpoints
        length(br)==4 && length(bz)==4 && all(x->length(x)==2,br) && all(x->length(x)==2,bz) ||
            error("parent-Q1 axis endpoint factors must contain four endpoint pairs")
        briv=ntuple(k->(input_iv(br[k][1]),input_iv(br[k][2])),4)
        bziv=ntuple(k->(input_iv(bz[k][1]),input_iv(bz[k][2])),4)
        function axis_sup(endpoints,width,rho_axis)
            ntuple(k->begin
                a,b=endpoints[k]
                realmax=max(absupper(a),absupper(b));slope=absupper(sub(b,a))
                complexmax=add((realmax,realmax),mul(divpos(rho_axis,width),(slope,slope)))
                (realmax,complexmax[2])
            end,4)
        end
        rsup=axis_sup(briv,hR,rho);zsup=axis_sup(bziv,hZ,rho)
        eupper_by_basis=ntuple(k->begin
            rreal,rcomplex=rsup[k];zreal,zcomplex=zsup[k]
            shape=add(mul(powpos(hRrho,16),mul((rcomplex,rcomplex),(zreal,zreal))),
                mul(powpos(hZrho,16),mul((rreal,rreal),(zcomplex,zcomplex))))
            # Source integration is dR dz; MB already contains the ring-radius factor.
            mul(mul(Cgl,mul(hR,hZ)),mul(shape,MB))[2]
        end,4)
        jc=ntuple(i->input_iv(current_corners[i]),4)
        absmax(vs)=maximum(absupper(v) for v in vs)
        jabs=absmax(jc)
        dr0=absmax((sub(jc[2],jc[1]),sub(jc[4],jc[3])))
        dz0=absmax((sub(jc[3],jc[1]),sub(jc[4],jc[2])))
        jr=add((jabs,jabs),mul(divpos(rho,hR),
            (dr0,dr0)))
        jz=add((jabs,jabs),mul(divpos(rho,hZ),
            (dz0,dz0)))
        gbase=mul(tensor_factor,MG)
        g_r=mul(gbase,jr);g_z=mul(gbase,jz)
        all(x->isfinite(x)&&x>=0,eupper_by_basis) && all(x->isfinite(x)&&x>=0,(g_r[2],g_z[2])) ||
            error("far-rectangle Peano envelope is nonfinite")
        (schema=:x3_far_rectangle_tensor_gl8_peano_bound_v1,
            status=:evaluated_ideal_tensor_gl8_far_rectangle_peano_bound,
            rule=(family=:GaussLegendre,order=8,semantics=:ideal_exact_rule),
            target_RZ=Tuple(target),bounds=Tuple(bounds),current_corners=Tuple(current_corners),
            source_distance_lower_m=d[1],rectangle_diagonal_upper_m=diag[2],
            source_complex_radius_m=rho[2],rho_over_d=3//4,
            ideal_gl8_tensor_peano_constant=Cgl[2],
            E_basis_error_upper_2x4=ntuple(_->eupper_by_basis,2),
            G_target_error_upper_2x2=((g_r[2],g_z[2]),(g_r[2],g_z[2])),
            production_float64_remainder=:not_included_requires_existing_AGM_jet_accumulation_bound,
            bound_method=:analytic_ring_source_coordinate_cauchy_then_tensor_GL8,
            kernel_calls=0,new_quadrature_nodes=0,
            interval_operation_increment=Int(interval_ops[])-ops0,interval_operations=Int(interval_ops[]),
            precision_bits=precision_bits,full_ray=false,full64=false,formal_acceptance=false)
    end
end

end # module
