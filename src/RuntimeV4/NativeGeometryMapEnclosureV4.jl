# Certified fast enclosure for the native geometry-map contraction G*C.
# The 24M counter here is the caller's directed BigFloat proof-operation
# ledger. Dense Float64 BLAS work is reported separately in returned metadata.
Base.@noinline Base.@nospecializeinfer function x3_near_native_map_float64_enclosure(
        G,C,native_columns;interval_ops=Ref(0),max_interval_ops=24_000_000,precision_bits=192)
    Base.@nospecialize G C native_columns
    trace=get(ENV,"FUSION_NATIVE_MAP_TRACE","0")=="1"
    interval_ops isa Base.RefValue && interval_ops[] isa Integer && !(interval_ops[] isa Bool) ||
        error("interval_ops must be a RefValue holding an integer proof ledger")
    max_interval_ops isa Integer && !(max_interval_ops isa Bool) && 0<=max_interval_ops<=24_000_000 ||
        error("max_interval_ops must be an integer in 0:24_000_000")
    precision_bits isa Integer && !(precision_bits isa Bool) && precision_bits>=53 ||
        error("precision_bits must be an integer of at least 53 bits")
    size(G)==(2,128) || error("native G map must have shape 2x128")
    C isa AbstractMatrix{Float64} && size(C,1)==128 || error("native coordinate map must be Float64 with 128 rows")
    size(C,2)==length(native_columns) || error("native coordinate columns must match C")
    native_ids=Vector{Int}(undef,length(native_columns));native_id_set=Set{Int}()
    for s in eachindex(native_ids)
        c=native_columns[s]
        c isa Integer && !(c isa Bool) && c>0 || error("native coordinate IDs must be positive integers")
        id=Int(c);id in native_id_set && error("native coordinate columns must be unique")
        native_ids[s]=id;push!(native_id_set,id)
    end
    trace && (println("NATIVE_MAP_STAGE ids_ready columns=",length(native_ids));flush(stdout))
    all(isfinite,C) || error("nonfinite native coordinate map")
    0<=interval_ops[]<=max_interval_ops || error("incoming native-map proof ledger outside cap")

    # This helper uses only the known IEEE/OpenBLAS or MKL Float64 GEMM path.
    # The gamma bound below is order-independent for at most 256 elementary
    # operations per dot product, including fused multiply-add implementations.
    vendor=LinearAlgebra.BLAS.vendor()
    backend_libraries=vendor===:lbt ? Tuple(lib.libname for lib in LinearAlgebra.BLAS.get_config().loaded_libs) : ()
    supported_backend=vendor in (:openblas,:openblas64,:mkl) ||
        (vendor===:lbt && !isempty(backend_libraries) &&
            all(path->occursin("openblas",lowercase(basename(path))) ||
                occursin("mkl",lowercase(basename(path))),backend_libraries))
    supported_backend || error("unsupported/unknown BLAS backend for certified native map")
    e=eps(Float64)
    tiny=nextfloat(0.0)
    tiny*1.0==tiny || error("scalar Float64 path flushes subnormals")
    probe_A=zeros(Float64,2,128);probe_B=zeros(Float64,128,5);probe_Y=zeros(Float64,2,5)
    probe_A[1,1]=1.0;probe_A[1,2]=e/2;probe_B[1,1]=1.0;probe_B[2,1]=1.0
    probe_A[1,3]=1.0;probe_A[1,4]=0.75e;probe_B[3,2]=1.0;probe_B[4,2]=1.0
    probe_A[1,5]=tiny;probe_B[5,3]=1.0
    probe_A[2,1]=-1.0;probe_A[2,2]=-e/2;probe_B[1,4]=1.0;probe_B[2,4]=1.0
    probe_A[2,3]=-1.0;probe_A[2,4]=-0.75e;probe_B[3,5]=1.0;probe_B[4,5]=1.0
    LinearAlgebra.mul!(probe_Y,probe_A,probe_B)
    probe_Y[1,1]==1.0 && probe_Y[1,2]==nextfloat(1.0) && probe_Y[1,3]==tiny &&
        probe_Y[2,4]==-1.0 && probe_Y[2,5]==prevfloat(-1.0) ||
        error("BLAS GEMM does not satisfy ties-to-even gradual-underflow Float64 behavior")

    ops=interval_ops
    start_ops=ops[]
    charge()=begin ops[]<max_interval_ops || error("native-map proof operation cap");ops[]+=1;end
    setprecision(BigFloat,precision_bits) do
        down(f)=(charge();setrounding(f,BigFloat,RoundDown))
        up(f)=(charge();setrounding(f,BigFloat,RoundUp))
        M=zeros(Float64,2,128);D=zeros(Float64,2,128)
        for k in 1:2,c in 1:128
            iv=G[k,c]
            iv isa Tuple && length(iv)==2 || error("native G map entry must be a two-endpoint interval")
            lo,hi=iv
            lo isa BigFloat && hi isa BigFloat && isfinite(lo) && isfinite(hi) && lo<=hi ||
                error("native G interval must contain finite ordered BigFloat endpoints")
            if iszero(lo) && iszero(hi)
                M[k,c]=0.0;D[k,c]=0.0;continue
            end
            lof=Float64(lo);hif=Float64(hi)
            isfinite(lof) && isfinite(hif) || error("native G interval has no finite Float64 center")
            m=lof/2+hif/2
            isfinite(m) || error("native G midpoint is nonfinite")
            mb=BigFloat(m) # Exact conversion of a finite Float64 at >=53-bit precision.
            dl=up(()->abs(mb-lo));dh=up(()->abs(hi-mb));rb=max(dl,dh)
            rd=Float64(rb)
            isfinite(rd) || error("native G radius exceeds finite Float64 range")
            if BigFloat(rd)<rb
                rd=nextfloat(rd)
                isfinite(rd) || error("outward native G radius overflows Float64")
            end
            M[k,c]=m;D[k,c]=rd
        end

        C64=Matrix{Float64}(C);AC=abs.(C64)
        # These three GEMMs are nominal work, not directed proof operations:
        # Y is the midpoint product; A and R are positive magnitude/radius sums.
        Y=M*C64
        A=abs.(M)*AC
        R=D*AC
        trace && (println("NATIVE_MAP_STAGE gemm_ready outputs=",length(Y));flush(stdout))
        all(isfinite,Y) && all(isfinite,A) && all(isfinite,R) || error("Float64 BLAS midpoint/radius propagation overflowed")

        n=128;q=2n
        eps64=up(()->BigFloat(e))
        qeps=up(()->BigFloat(q)*eps64)
        oneiv=BigFloat(1)
        denom=down(()->oneiv-qeps)
        denom>0 || error("gamma denominator is nonpositive")
        gamma=up(()->qeps/denom)
        eta=down(()->ldexp(BigFloat(1),-1075))
        qeta=up(()->BigFloat(q)*eta)
        qeta_over_denom=up(()->qeta/denom)
        interval_zero=(BigFloat(0),BigFloat(0))
        J=Dict{Int,Vector{Tuple{BigFloat,BigFloat}}}()
        stored_midpoints=Dict{Int,Any}()
        exact_zero_rows=ntuple(k->all(c->iszero(G[k,c][1]) && iszero(G[k,c][2]),1:128),2)
        # One conservative enclosure per row avoids repeating BigFloat bound
        # construction for every native degree of freedom.
        row_error=Vector{BigFloat}(undef,2)
        row_point_radius=Vector{BigFloat}(undef,2)
        u_mpfr=up(()->ldexp(BigFloat(1),1-precision_bits))
        for k in 1:2
            amax=maximum(view(A,k,:));rmax=maximum(view(R,k,:))
            af=up(()->BigFloat(amax));rf=up(()->BigFloat(rmax))
            a_num=up(()->af+qeta);r_num=up(()->rf+qeta)
            a_upper=up(()->a_num/denom);r_upper=up(()->r_num/denom)
            dot_round=up(()->gamma*a_upper)
            dot_round=up(()->dot_round+qeta_over_denom)
            row_error[k]=up(()->r_upper+dot_round)
            ymax=maximum(abs,view(Y,k,:))
            endpoint_scale=up(()->BigFloat(ymax)+row_error[k])
            four_u_mpfr=up(()->BigFloat(4)*u_mpfr)
            endpoint_pad=up(()->four_u_mpfr*endpoint_scale)
            row_point_radius[k]=up(()->row_error[k]+endpoint_pad)
        end
        exact_zero_columns=Int[];nonzero_output_count=0
        for s in axes(C64,2)
            vals=Vector{Tuple{BigFloat,BigFloat}}(undef,2)
            points=Vector{Tuple{Float64,BigFloat}}(undef,2)
            any_nonzero=false
            for k in 1:2
                structural_zero=all(c->iszero(C64[c,s]) || (iszero(M[k,c]) && iszero(D[k,c])),1:128)
                if structural_zero
                    vals[k]=interval_zero
                    points[k]=(0.0,BigFloat(0))
                    continue
                end
                any_nonzero=true
                y=Y[k,s];yb=BigFloat(y);rho=row_error[k]
                vals[k]=(down(()->yb-rho),up(()->yb+rho))
                points[k]=(y,row_point_radius[k])
                nonzero_output_count+=1
            end
            if any_nonzero
                J[native_ids[s]]=vals
                stored_midpoints[native_ids[s]]=ntuple(k->
                    (value=points[k][1],absolute_error_upper=points[k][2]),2)
            else
                push!(exact_zero_columns,native_ids[s])
            end
        end
        length(J)+length(exact_zero_columns)==length(native_ids) &&
            isempty(intersect(Set(keys(J)),Set(exact_zero_columns))) &&
            union(Set(keys(J)),Set(exact_zero_columns))==native_id_set ||
            error("native map output lost or duplicated a state column")
        proof_ops=ops[]-start_ops
        trace && (println("NATIVE_MAP_STAGE enclosure_ready proof_ops=",proof_ops);flush(stdout))
        nominal_outputs=2*size(C64,2)
        (J=J,stored_midpoints=stored_midpoints,metadata=(schema=:x3_near_native_geometry_map_float64_enclosure_v1,
            status=:evaluated_certified_float64_blas_map,
            interval_operations=proof_ops,cumulative_interval_operations=ops[],
            max_interval_operations=max_interval_ops,
            interval_operation_scope=:directed_bigfloat_proof_operations_only,
            enclosure_method=:per_row_uniform_bound_with_stored_float64_midpoints,
            row_uniform_error_upper=Tuple(row_error),
            row_midpoint_absolute_error_upper=Tuple(row_point_radius),
            midpoint_padding_formula=:rho_plus_4u_mpfr_times_maxabsY_plus_rho,
            dense_blas_gemm_count=3,guard_blas_gemm_count=1,midpoint_gemm=:M_times_C,
            absolute_midpoint_gemm=:abs_M_times_abs_C,
            interval_radius_gemm=:D_times_abs_C,
            blas_vendor=vendor,backend_libraries=backend_libraries,
            blas_path=:ieee_float64_round_to_nearest_gradual_underflow,
            matrix_shapes=(M=size(M),C=size(C64),Y=size(Y),A=size(A),R=size(R)),
            dot_length=n,gamma_operation_count=q,gamma_upper=gamma,
            subnormal_absolute_error_per_operation=eta,
            operations_per_dot_upper=q,subnormal_absolute_error_per_dot=qeta,
            theoretical_scalar_flops_upper=3*nominal_outputs*q,
            C_exact_stored_float64=true,C_provenance_error_included=false,
            exact_zero_rows=exact_zero_rows,exact_zero_native_columns=Tuple(sort!(exact_zero_columns)),
            exact_zero_native_column_count=length(exact_zero_columns),
            nonzero_output_component_count=nonzero_output_count,
            input_interval_midpoint_radius_map=:Float64_point_with_upward_Float64_radius,
            BLAS_magnitude_and_radius_products_independently_enclosed=true,
            output_scope=:near_geometry_map_only_no_source_chain_or_physical_acceptance))
    end
end
