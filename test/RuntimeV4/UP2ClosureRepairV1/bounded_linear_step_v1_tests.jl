#= Focused unit tests; execution requires the root's serialized Julia lane.

Usage: julia --startup-file=no --project=. THIS_FILE ORACLE.json OUTPUT_DIR
Optional fourth argument: --n1-snapshots (reassemble saved 40-DOF states only;
no new nonlinear solve). This writes actual A/r/l before solving each linear
subproblem. A separate tester can read the snapshots without this module.
Optional saved subproblem: --saved-linear PRODUCTION_DIR OUTPUT_DIR. Add
--profile-saved-linear in place of --saved-linear to collect a CPU profile,
sampled allocations at 1e-5, and GC-byte delta for the same bounded solve.
=#
using Test, LinearAlgebra, SparseArrays, JSON3, SHA, Profile
const ROOT=normpath(joinpath(@__DIR__,"..","..",".."))
const BOUNDED_STEP_LEGACY_PATH=joinpath(ROOT,"src","RuntimeV4","SpatialBoundedLinearStepV1.jl")
const BOUNDED_STEP_FACADE_PATH=joinpath(ROOT,"src","RuntimeV4","Solvers","BoundedLinearStep.jl")
const BOUNDED_STEP_LEGACY_SHA256=bytes2hex(SHA.sha256(read(BOUNDED_STEP_LEGACY_PATH)))
const BOUNDED_STEP_FACADE_SHA256=bytes2hex(SHA.sha256(read(BOUNDED_STEP_FACADE_PATH)))
include(BOUNDED_STEP_LEGACY_PATH)
include(BOUNDED_STEP_FACADE_PATH)
const BLS=BoundedLinearStep
const BLS_IMPLEMENTATION_IDENTITY=BLS.implementation_identity()
const BLS_FACADE_IDENTITY=BLS.facade_identity()
String(BLS_IMPLEMENTATION_IDENTITY.implementation_sha256)==BOUNDED_STEP_LEGACY_SHA256 ||
    error("bounded-step backend identity differs from its source at load")
BLS_FACADE_IDENTITY.source_sha256==BOUNDED_STEP_FACADE_SHA256 ||
    error("bounded-step facade identity differs from its source at load")
if length(ARGS)==3 && last(ARGS)=="--n1-snapshots"
    include(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl"))
end
sha(path)=bytes2hex(SHA.sha256(read(path)))

function facade_identity_negative_controls()
    @testset "bounded-step facade source identity controls" begin
        @test String(BLS_IMPLEMENTATION_IDENTITY.implementation_sha256)==BOUNDED_STEP_LEGACY_SHA256
        @test BLS_FACADE_IDENTITY.api_revision=="runtime-v4-bounded-linear-step-facade-v1"
        @test BLS_FACADE_IDENTITY.source_sha256==sha(BOUNDED_STEP_FACADE_PATH)
        @test BLS_FACADE_IDENTITY.source_sha256!=String(BLS_IMPLEMENTATION_IDENTITY.implementation_sha256)

        fake_backend=Module(gensym(:FakeBoundedStepBackend))
        fake_source="""
        module SpatialBoundedLinearStepV1
            const SOURCE_SHA256="$BOUNDED_STEP_LEGACY_SHA256"
            bounded_linear_step_policy_v1()=(method=:lower_bounded_sparse_QR_active_set_v1,)
            bounded_linear_step_identity_v1()=(
                method=:lower_bounded_sparse_QR_active_set_v1,
                implementation_sha256=SOURCE_SHA256,
                policy=bounded_linear_step_policy_v1())
            bounded_linear_step_snapshot_v1(args...;kwargs...)=nothing
            solve_lower_bounded_step_v1(args...;kwargs...)=nothing
            bounded_step_kkt_v1(args...;kwargs...)=nothing
        end
        """
        Base.include_string(fake_backend,fake_source,"fake_bounded_backend.jl")
        Base.include(fake_backend,BOUNDED_STEP_FACADE_PATH)
        fake_module=getfield(fake_backend,:SpatialBoundedLinearStepV1)
        fake_facade=getfield(fake_backend,:BoundedLinearStep)
        fake_identity=Base.invokelatest(fake_module.bounded_linear_step_identity_v1)
        @test String(fake_identity.implementation_sha256)==BOUNDED_STEP_LEGACY_SHA256
        fake_method=first(methods(fake_module.solve_lower_bounded_step_v1))
        fake_location=try
            Base.functionloc(fake_method)
        catch
            nothing
        end
        fake_source_value=fake_location isa Tuple && !isempty(fake_location) ?
            first(fake_location) : nothing
        fake_source_text=if fake_source_value isa Symbol || fake_source_value isa AbstractString
            String(fake_source_value)
        else
            ""
        end
        fake_source_is_legacy=!isempty(fake_source_text) &&
            normpath(abspath(fake_source_text))==normpath(abspath(BOUNDED_STEP_LEGACY_PATH))
        @test !fake_source_is_legacy
        @test_throws ArgumentError Base.invokelatest(fake_facade.solve_lower_bounded_step,
            sparse(reshape([1.0],1,1)),[0.0],[-Inf])

        mktempdir() do temp_root
            fixture_runtime=joinpath(temp_root,"src","RuntimeV4")
            fixture_solver_dir=joinpath(fixture_runtime,"Solvers")
            mkpath(fixture_solver_dir)
            drifted_legacy=joinpath(fixture_runtime,"SpatialBoundedLinearStepV1.jl")
            drifted_facade=joinpath(fixture_solver_dir,"BoundedLinearStep.jl")
            original_legacy=read(BOUNDED_STEP_LEGACY_PATH)
            write(drifted_legacy,original_legacy)
            cp(BOUNDED_STEP_FACADE_PATH,drifted_facade)
            drift_fixture=Module(gensym(:BoundedStepDriftFixture))
            Base.include(drift_fixture,drifted_legacy)
            Base.include(drift_fixture,drifted_facade)
            drift_facade=getfield(drift_fixture,:BoundedLinearStep)
            @test String(Base.invokelatest(drift_facade.implementation_identity).implementation_sha256)==
                sha(drifted_legacy)
            write(drifted_legacy,vcat(original_legacy,collect(codeunits("\n# post-load backend drift\n"))))
            @test sha(drifted_legacy)!=BOUNDED_STEP_LEGACY_SHA256
            @test_throws ArgumentError Base.invokelatest(drift_facade.implementation_identity)
            write(drifted_legacy,original_legacy)
            @test String(Base.invokelatest(drift_facade.implementation_identity).implementation_sha256)==
                sha(drifted_legacy)
            open(drifted_facade,"a") do io
                write(io,"\n# post-load facade drift\n")
            end
            @test_throws ArgumentError Base.invokelatest(drift_facade.facade_identity)
        end
    end
end

function caught_exception(f)
    try
        f()
        nothing
    catch err
        err
    end
end

function trace_equivalence_tests()
    @testset "bounded-step stage trace is observational" begin
        A=sparse([1.0 1.0;0.0 1.0]);r=[-3.0,3.0];lower=[-Inf,-0.5]
        plain=BLS.solve_lower_bounded_step_v1(A,r,lower)
        events=Tuple{String,Symbol,UInt64}[]
        sink=(name,edge,timestamp)->push!(events,(String(name),edge,UInt64(timestamp)))
        traced=BLS.solve_lower_bounded_step_v1(A,r,lower;stage_trace=sink)
        traced_pairs(event_records)=[(event[1],event[2]) for event in event_records]
        trace_names_for_history(matrix,result)=begin
            names=["native_bounded_step_checked_inputs"]
            for h in result.history
                active_ids=isempty(h.active_before) ? "none" : join(h.active_before,",")
                push!(names,"native_bounded_step_qr_backsolve_rankdiag_iteration_$(h.iteration)_m$(size(matrix,1))_n$(size(matrix,2))_nnz$(nnz(matrix))_free$(length(h.free_columns))_active$(length(h.active_before))_active_ids$(active_ids)")
                push!(names,"native_bounded_step_rank_iteration_$(h.iteration)_rank$(h.rank_estimate)_rank_threshold$(repr(h.rank_threshold))_free_columns$(length(h.free_columns))")
                if h.event===:bind
                    hit=only(h.added)
                    push!(names,"native_bounded_step_decision_iteration_$(h.iteration)_bind_hit$(hit)_added$(join(h.added,","))_alpha$(repr(h.alpha))")
                elseif h.event===:release
                    release=only(h.released)
                    push!(names,"native_bounded_step_decision_iteration_$(h.iteration)_release_column$(release)_alpha$(repr(h.alpha))_gradient$(repr(h.kkt.gradient[release]))_kkt_roundoff_floor$(repr(h.kkt.roundoff_floor))")
                end
            end
            names
        end
        expected_pairs(names)=reduce(vcat,([ (name,:begin),(name,:end) ] for name in names))
        @test traced_pairs(events)==expected_pairs(trace_names_for_history(A,traced))
        bind_history=only(filter(h->h.event===:bind,traced.history))
        @test bind_history.added==(2,)
        @test [h.rank_estimate for h in traced.history]==[2,1]
        @test all(event->event[3]>0,events)
        @test plain.converged && traced.converged
        @test merge(plain,(elapsed_seconds=0.0,))==merge(traced,(elapsed_seconds=0.0,))

        release_A=sparse(Matrix{Float64}(I,2,2));release_r=[-2.0,-3.0];release_lower=[0.0,0.0]
        release_plain=BLS.solve_lower_bounded_step_v1(release_A,release_r,release_lower)
        release_events=Tuple{String,Symbol,UInt64}[]
        release_sink=(name,edge,timestamp)->push!(release_events,(String(name),edge,UInt64(timestamp)))
        release_traced=BLS.solve_lower_bounded_step_v1(release_A,release_r,release_lower;stage_trace=release_sink)
        release_history=filter(h->h.event===:release,release_traced.history)
        @test [only(h.released) for h in release_history]==[2,1]
        @test [h.rank_estimate for h in release_traced.history]==[0,1,2]
        @test traced_pairs(release_events)==expected_pairs(trace_names_for_history(release_A,release_traced))
        @test release_plain.converged && release_traced.converged
        @test merge(release_plain,(elapsed_seconds=0.0,))==merge(release_traced,(elapsed_seconds=0.0,))

        throwing_calls=Ref(0)
        throwing_sink=(args...)->begin
            throwing_calls[]+=1
            error("intentional trace sink failure")
        end
        safe_traced=BLS.solve_lower_bounded_step_v1(A,r,lower;stage_trace=throwing_sink)
        @test throwing_calls[]>0
        @test safe_traced.converged
        @test merge(plain,(elapsed_seconds=0.0,))==merge(safe_traced,(elapsed_seconds=0.0,))

        invalid_A=sparse(reshape([1.0],1,1))
        original_error=caught_exception(()->BLS.solve_lower_bounded_step_v1(invalid_A,[1.0,2.0],[-Inf]))
        calls_before_invalid=throwing_calls[]
        traced_error=caught_exception(()->BLS.solve_lower_bounded_step_v1(
            invalid_A,[1.0,2.0],[-Inf];stage_trace=throwing_sink))
        @test original_error isa ArgumentError
        @test typeof(traced_error)==typeof(original_error)
        @test sprint(showerror,traced_error)==sprint(showerror,original_error)
        @test throwing_calls[]==calls_before_invalid+2
    end
end

function write_new(path,value)
    ispath(path) && error("retain existing evidence: $path")
    open(path,"w") do io;JSON3.write(io,value);write(io,'\n');end
end

function downdate_cache_transition_tests()
    @testset "bounded-step successive QR cache downdates and release" begin
        SBLS = SpatialBoundedLinearStepV1
        tol = BLS.bounded_linear_step_policy_v1().rank_relative_tolerance
        A = sparse([1.0 0.3 -0.2 0.1;
                    0.1 1.2 0.4 -0.1;
                   -0.2 0.2 1.1 0.3;
                    0.3 -0.1 0.2 1.3;
                    0.5 0.1 -0.1 0.2;
                   -0.1 0.4 0.2 -0.3])
        rhs = [2.0, -3.0, 5.0, 7.0, 0.0, 0.0]
        free = collect(1:size(A, 2))
        F = qr(A[:, free]; tol=tol)
        cache = SBLS._sbls_make_downdate_cache_v1(F, free, tol)
        @test cache !== nothing
        @test cache.R === nothing
        @test cache.updates == 0

        reference_solution(cols) = qr(A[:, cols]; tol=tol) \ rhs
        cache_solution() = begin
            result = SBLS._sbls_downdated_solution_v1(cache, rhs, tol)
            @test result !== nothing
            x = zeros(size(A, 2))
            x[cache.pivoted_columns] .= result.x
            @test result.rank == length(cache.free_columns)
            expected = zeros(size(A, 2))
            expected[cache.free_columns] .= reference_solution(cache.free_columns)
            @test isapprox(x, expected; atol=1.0e-11, rtol=1.0e-11)
            A_free = A[:, cache.free_columns]
            @test norm(A_free' * (A_free * x[cache.free_columns] - rhs)) <= 1.0e-11
            x
        end

        # Drop the middle pivot, then the leftmost pivot of the reduced cache.
        removed_middle = cache.pivoted_columns[2]
        after_middle = setdiff(cache.free_columns, [removed_middle])
        @test SBLS._sbls_drop_one_column_v1!(cache, after_middle, tol)
        @test cache.R !== nothing
        @test cache.updates == 1
        first_rotation_count = length(cache.rotations)
        @test first_rotation_count > 0
        original_rhs_solution = cache_solution()
        original_rhs_snapshot = BLS.bounded_linear_step_snapshot_v1(
            A[:, cache.free_columns], -rhs, fill(-Inf, length(cache.free_columns)))

        # Reuse the same projected/downdated QR state with a new right-hand side.
        # A fresh sparse-QR solve checks the changed projection; snapshots
        # confirm the captured residual follows that changed RHS.
        changed_rhs = [-1.25, 0.5, -4.0, 2.25, 1.5, -2.0]
        @test changed_rhs != rhs
        changed_result = SBLS._sbls_downdated_solution_v1(cache, changed_rhs, tol)
        @test changed_result !== nothing
        @test Tuple(cache.rhs_snapshot) == Tuple(changed_rhs)
        changed_solution = zeros(size(A, 2))
        changed_solution[cache.pivoted_columns] .= changed_result.x
        changed_free_matrix = Matrix(A[:, cache.free_columns])
        changed_reference = qr(A[:, cache.free_columns]; tol=tol) \ changed_rhs
        @test changed_result.rank == length(cache.free_columns)
        @test isapprox(changed_solution[cache.free_columns], changed_reference;
            atol=1.0e-11, rtol=1.0e-11)
        @test norm(changed_solution - original_rhs_solution) > 1.0e-6
        @test norm(changed_free_matrix' *
            (changed_free_matrix * changed_solution[cache.free_columns] - changed_rhs)) <= 1.0e-11
        changed_rhs_snapshot = BLS.bounded_linear_step_snapshot_v1(
            A[:, cache.free_columns], -changed_rhs,
            fill(-Inf, length(cache.free_columns)))
        @test changed_rhs_snapshot.matrix == original_rhs_snapshot.matrix
        @test changed_rhs_snapshot.lower_bounds == original_rhs_snapshot.lower_bounds
        @test changed_rhs_snapshot.residual == Tuple(-changed_rhs)
        @test changed_rhs_snapshot.residual != original_rhs_snapshot.residual

        # Release the first bound, bind a second pivot, then release it. Each
        # transition is checked against a new canonical sparse-QR solve.
        released_free = sort([cache.free_columns; removed_middle])
        @test SBLS._sbls_add_one_column_v1!(cache, A, released_free, tol)
        @test cache.free_columns == released_free
        @test cache.updates == 2
        @test cache.projected_rhs === nothing
        cache_solution()

        removed_left = cache.pivoted_columns[1]
        after_left = setdiff(cache.free_columns, [removed_left])
        @test SBLS._sbls_drop_one_column_v1!(cache, after_left, tol)
        @test cache.updates == 3
        @test length(cache.rotations) > first_rotation_count
        cache_solution()
        released_left = sort([cache.free_columns; removed_left])
        @test SBLS._sbls_add_one_column_v1!(cache, A, released_left, tol)
        @test cache.free_columns == released_left
        @test cache.updates == 4
        cache_solution()

        # Insertion also handles a released column outside the SPQR base span:
        # Q' * A[:, j] retains its orthogonal residual in the padded R rows.
        A3 = sparse(hcat(Matrix(A), [0.0, 0.0, 0.0, 0.0, 0.0, 1.0]))
        rhs3 = [1.0, -2.0, 0.5, 3.0, -0.75, 0.25]
        base_free3 = collect(1:4)
        cache3 = SBLS._sbls_make_downdate_cache_v1(
            qr(A3[:, base_free3]; tol=tol), base_free3, tol)
        @test cache3 !== nothing
        base3_matrix = A3[:, base_free3]
        base3_column = Vector{Float64}(A3[:,5])
        base3_coefficients = qr(base3_matrix; tol=tol) \ base3_column
        base3_orthogonal = base3_column - base3_matrix * base3_coefficients
        @test norm(base3_orthogonal) > 1.0e-8
        removed3 = cache3.pivoted_columns[2]
        reduced3 = setdiff(cache3.free_columns, [removed3])
        @test SBLS._sbls_drop_one_column_v1!(cache3, reduced3, tol)
        expanded3 = sort([reduced3; 5])
        @test SBLS._sbls_add_one_column_v1!(cache3, A3, expanded3, tol)
        result3 = SBLS._sbls_downdated_solution_v1(cache3, rhs3, tol)
        @test result3 !== nothing
        got3 = zeros(5); got3[cache3.pivoted_columns] .= result3.x
        expected3 = zeros(5)
        canonical3 = qr(A3[:, expanded3]; tol=tol)
        expected3[expanded3] .= canonical3 \ rhs3
        @test isapprox(got3, expected3; atol=1.0e-10, rtol=1.0e-10)
        residual3 = rhs3 - A3[:, cache3.pivoted_columns] * result3.x
        @test length(cache3.projected_rhs) == size(A3,1)
        @test norm(A3[:,expanded3]' * residual3) <= 1.0e-10
        qres3 = canonical3.Q' * residual3[canonical3.prow]
        @test norm(qres3[1:length(expanded3)]) <= 1.0e-10
        @test isapprox(norm(qres3[length(expanded3)+1:end]), norm(residual3);
            atol=1.0e-10, rtol=1.0e-10)
        @test isapprox(norm(cache3.projected_rhs[length(expanded3)+1:end]),
            norm(residual3); atol=1.0e-10, rtol=1.0e-10)

        # A reinsertion that duplicates a retained basis column is rejected by
        # the cache and then solved through the canonical rank-deficient SPQR path.
        base4 = sparse(Matrix(A[:,1:3]))
        base_free4 = collect(1:3)
        cache4 = SBLS._sbls_make_downdate_cache_v1(
            qr(base4[:,base_free4]; tol=tol), base_free4, tol)
        @test cache4 !== nothing
        retained4 = cache4.pivoted_columns[1]
        removed4 = cache4.pivoted_columns[end]
        A4 = sparse(hcat(Matrix(base4), Matrix(base4[:,retained4:retained4])))
        reduced4 = setdiff(cache4.free_columns, [removed4])
        @test SBLS._sbls_drop_one_column_v1!(cache4, reduced4, tol)
        expanded4 = sort([reduced4; 4])
        @test !SBLS._sbls_add_one_column_v1!(cache4, A4, expanded4, tol)
        Afree4 = Matrix(A4[:,expanded4])
        canonical4 = qr(A4[:,expanded4]; tol=tol)
        singular_values4 = svdvals(Afree4)
        @test minimum(singular_values4) <= tol * max(1.0, maximum(singular_values4))
        @test SBLS._sbls_make_downdate_cache_v1(
            canonical4, expanded4, tol) === nothing
        rhs4 = [0.5, -1.0, 2.0, 0.25, -0.75, 1.5]
        fallback4 = canonical4 \ rhs4
        residual4 = A4[:,expanded4] * fallback4 - rhs4
        @test all(isfinite, fallback4)
        @test norm(A4[:,expanded4]' * residual4) <= 1.0e-10

        deficient = sparse([1.0 2.0; 2.0 4.0; 3.0 6.0])
        deficient_free = [1, 2]
        deficient_qr = qr(deficient[:, deficient_free]; tol=tol)
        @test SBLS._sbls_make_downdate_cache_v1(
            deficient_qr, deficient_free, tol) === nothing

        @testset "32 successive cache drops match fresh QR; 33rd is a no-op" begin
            n36 = 36
            A36 = sparse([Float64(i == j ? 1.5 :
                0.01 * (((17i + 23j) % 13) - 6) / (1 + abs(i-j)))
                for i in 1:n36, j in 1:n36])
            rhs36 = [sin(0.3i) + cos(0.7i) / 3 for i in 1:n36]
            free36 = collect(1:n36)
            cache36 = SBLS._sbls_make_downdate_cache_v1(
                qr(A36[:, free36]; tol=tol), free36, tol)
            @test cache36 !== nothing
            lower36 = zeros(n36)
            for drop_index in 1:32
                gone = cache36.free_columns[cld(length(cache36.free_columns), 2)]
                next_free = setdiff(cache36.free_columns, [gone])
                @test SBLS._sbls_drop_one_column_v1!(cache36, next_free, tol;
                    rhs=rhs36, lower_bounds=lower36)
                @test cache36.updates == drop_index
                cached = SBLS._sbls_downdated_solution_v1(cache36, rhs36, tol)
                @test cached !== nothing
                got = zeros(n36)
                got[cache36.pivoted_columns] .= cached.x
                expected = zeros(n36)
                expected[cache36.free_columns] .=
                    qr(A36[:, cache36.free_columns]; tol=tol) \ rhs36
                @test isapprox(got, expected; atol=1.0e-10, rtol=1.0e-10)
                residual = A36[:, cache36.free_columns] *
                    got[cache36.free_columns] - rhs36
                @test norm(A36[:, cache36.free_columns]' * residual) <= 1.0e-10
            end
            @test length(cache36.free_columns) == 4
            @test cache36.updates == 32

            free_before = copy(cache36.free_columns)
            pivots_before = copy(cache36.pivoted_columns)
            rotations_before = copy(cache36.rotations)
            R_before = copy(cache36.R)
            projected_before = copy(cache36.projected_rhs)
            rhs_snapshot_before = copy(cache36.rhs_snapshot)
            gone33 = cache36.free_columns[cld(length(cache36.free_columns), 2)]
            @test !SBLS._sbls_drop_one_column_v1!(cache36,
                setdiff(cache36.free_columns, [gone33]), tol;
                rhs=rhs36, lower_bounds=lower36)
            @test cache36.updates == 32
            @test cache36.free_columns == free_before
            @test cache36.pivoted_columns == pivots_before
            @test cache36.rotations == rotations_before
            @test cache36.R == R_before
            @test cache36.projected_rhs == projected_before
            @test cache36.rhs_snapshot == rhs_snapshot_before
        end

        @testset "cached Q-transpose RHS follows nonzero bound activations" begin
            A2 = sparse([1.0 0.3 -0.2 0.1;
                         0.1 1.2 0.4 -0.1;
                        -0.2 0.2 1.1 0.3;
                         0.3 -0.1 0.2 1.3;
                         0.5 0.1 -0.1 0.2;
                        -0.1 0.4 0.2 -0.3])
            rhs0 = [2.0, -3.0, 5.0, 7.0, 0.0, 0.0]
            lower2 = zeros(size(A2,2))
            free2 = collect(1:size(A2,2))
            base2 = qr(A2[:,free2];tol=tol)
            cache2 = SBLS._sbls_make_downdate_cache_v1(base2,free2,tol)
            @test cache2 !== nothing && cache2.projected_rhs === nothing

            reference2(cols,b) = qr(A2[:,cols];tol=tol) \ b
            check2(b) = begin
                result=SBLS._sbls_downdated_solution_v1(cache2,b,tol)
                @test result !== nothing
                x=zeros(size(A2,2));x[cache2.pivoted_columns].=result.x
                expected=zeros(size(A2,2));expected[cache2.free_columns].=
                    reference2(cache2.free_columns,b)
                @test isapprox(x,expected;atol=1.0e-10,rtol=1.0e-10)
                @test norm(A2[:,cache2.free_columns]' *
                    (A2[:,cache2.free_columns]*x[cache2.free_columns]-b))<=1.0e-10
            end

            removed1=cache2.pivoted_columns[2]
            lower2[removed1]=-0.35
            free_after1=setdiff(cache2.free_columns,[removed1])
            rhs1=Vector{Float64}(rhs0-A2[:,removed1]*lower2[removed1])
            @test SBLS._sbls_drop_one_column_v1!(cache2,free_after1,tol;
                rhs=rhs1,lower_bounds=lower2)
            check2(rhs1)
            @test cache2.projected_rhs !== nothing

            removed2=cache2.pivoted_columns[1]
            lower2[removed2]=-0.2
            free_after2=setdiff(cache2.free_columns,[removed2])
            rhs2=Vector{Float64}(rhs1-A2[:,removed2]*lower2[removed2])
            @test SBLS._sbls_drop_one_column_v1!(cache2,free_after2,tol;
                rhs=rhs2,lower_bounds=lower2)
            check2(rhs2)
            @test cache2.rhs_snapshot==rhs2
        end
    end
end

function unit_cases(oraclepath,out)
    data=JSON3.read(read(oraclepath,String));observed=NamedTuple[]
    @testset "bounded model step independent fixture oracles" begin
        for (case_index,case) in enumerate(data.cases)
            m=length(case.A);n=length(case.A[1]);A=[Float64(case.A[i][j]) for i in 1:m,j in 1:n]
            r=Float64.(case.r);lower=[v===nothing ? -Inf : Float64(v) for v in case.lower]
            result=BLS.solve_lower_bounded_step_v1(sparse(A),r,lower)
            push!(observed,(name=String(case.name),input=BLS.bounded_linear_step_snapshot_v1(A,r,lower),result=result))
            write_new(joinpath(out,"unit_case_$case_index.json"),last(observed))
            # Check raw q independently; do not merely assert the helper flag.
            @test result.converged
            @test result.exit_code==0
            @test result.kkt.passed
            s=collect(Float64.(result.step));q=transpose(A)*(A*s+r)
            finite_bounds=findall(isfinite,lower)
            bound_tol=[8eps(Float64)*max(1.0,abs(s[i]),isfinite(lower[i]) ? abs(lower[i]) : 0.0) for i in 1:n]
            independently_active=[i for i in finite_bounds if abs(s[i]-lower[i])<=bound_tol[i]]
            independently_free=setdiff(collect(1:n),independently_active)
            @test all(i->s[i]>=lower[i]-bound_tol[i],finite_bounds)
            @test maximum(abs.(q[independently_free]);init=0.0)<=1.0e-10
            @test minimum(q[independently_active];init=0.0)>=-1.0e-10
            @test all(i->i in independently_active,result.active_indices)
            objective=norm(A*s+r)^2/2
            @test isapprox(objective,Float64(case.oracle.objective);atol=1.0e-10,rtol=1.0e-10)
            @test objective<=norm(r)^2/2+1.0e-12
            @test result.inner_iterations<=result.inner_iteration_limit
            @test result.algorithm.method==BLS_IMPLEMENTATION_IDENTITY.method
            @test result.physical_convergence==:not_assessed
            if String(case.name)=="bind_then_release_after_qr_downdate"
                @test [h.event for h in result.history]==[:bind,:release,:kkt_converged]
                @test result.history[1].added==(1,)
                @test result.history[2].released==(3,)
                @test result.history[2].free_columns==(2,)
                @test result.history[3].free_columns==(2,3)
                @test result.active_indices==(1,)
                @test result.free_indices==(2,3)
                @test collect(Float64.(result.step))≈[-0.5,0.0,1.0]
            end
        end
    end
    write_new(joinpath(out,"unit_cases.json"),(schema="bounded-step-unit-results-v1",oracle_sha256=sha(oraclepath),cases=observed))
    @testset "analytic causes and bound semantics" begin
        A=sparse([1.0 1.0;0.0 1.0])
        a=BLS.solve_lower_bounded_step_v1(A,[-3.0,1.0],[-Inf,0.0])
        @test collect(a.step)≈[3.0,0.0]
        @test collect(a.kkt.gradient)≈[0.0,1.0]
        b=BLS.solve_lower_bounded_step_v1(A,[-3.0,3.0],[-Inf,-.5])
        @test collect(b.step)≈[3.5,-.5]
        @test 2 in b.active_indices
        @test any(h->h.event==:bind,b.history)
        @test first(b.history).kkt.roundoff_floor==b.kkt.roundoff_floor
        c=BLS.solve_lower_bounded_step_v1(sparse(Matrix{Float64}(I,2,2)),[-2.0,-3.0],[0.0,0.0])
        @test collect(c.step)≈[2.0,3.0]
        @test count(h->h.event==:release,c.history)==2
        @test BLS.bounded_step_kkt_v1(A,[-3.0,1.0],[-Inf,0.0],[3.0,0.0],(2,)).passed
        @test !BLS.bounded_step_kkt_v1(A,[-3.0,1.0],[-Inf,0.0],[0.0,0.0],(2,)).passed
        @test !BLS.bounded_step_kkt_v1(A,[-3.0,1.0],[-Inf,0.0],[4.0,-1.0],()).passed
        large=BLS.bounded_step_kkt_v1(1.0e6.*sparse(Matrix{Float64}(I,2,2)),[1.0e6,1.0e6],
            [-Inf,-Inf],[-1.0+eps(Float64),-1.0],())
        @test large.roundoff_floor>large.tolerance
        @test large.free_stationarity>1.0e-10
        @test !large.passed
        masked=BLS.bounded_step_kkt_v1(zeros(1,2),[0.0],[0.0,-Inf],[-1.0,1.0e16],(1,))
        @test !masked.primal_feasible
        @test !masked.working_bounds_satisfied
        @test !masked.passed

        I2=sparse(Matrix{Float64}(I,2,2));scaled_I2=1.0e6.*I2
        unrestricted=[-Inf,-Inf]
        small_public=BLS.bounded_step_kkt_v1(I2,[1.0,0.0],unrestricted,[0.0,0.0],())
        large_public=BLS.bounded_step_kkt_v1(scaled_I2,[1.0,0.0],unrestricted,[0.0,0.0],())
        @test large_public.roundoff_floor>1.0e5*small_public.roundoff_floor

        small_solve=BLS.solve_lower_bounded_step_v1(I2,[1.0,0.0],unrestricted)
        large_solve=BLS.solve_lower_bounded_step_v1(scaled_I2,[1.0,0.0],unrestricted)
        small_solve_again=BLS.solve_lower_bounded_step_v1(I2,[1.0,0.0],unrestricted)
        @test small_solve.converged && large_solve.converged && small_solve_again.converged
        @test large_solve.kkt.roundoff_floor>1.0e5*small_solve.kkt.roundoff_floor
        @test small_solve_again.kkt.roundoff_floor==small_solve.kkt.roundoff_floor
        @test merge(small_solve,(elapsed_seconds=0.0,))==merge(small_solve_again,(elapsed_seconds=0.0,))
    end
    @testset "invalid inputs and explicit nonconvergence" begin
        A=sparse(Matrix{Float64}(I,2,2));r=[1.0,2.0];l=[-Inf,0.0]
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,r,[0.0])
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,[1.0],l)
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,[NaN,2.0],l)
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1([Inf 0.0;0.0 1.0],r,l)
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,r,[Inf,0.0])
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,r,[NaN,0.0])
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,r,[0.0,.01])
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,r,l;policy=merge(BLS.bounded_linear_step_policy_v1(),(kkt_absolute_tolerance=1.0e-3,)))
        @test_throws ArgumentError BLS.solve_lower_bounded_step_v1(A,r,l;seconds=-1.0)
        @test_throws ArgumentError BLS.bounded_step_kkt_v1(A,r,l,[0.0,0.0],(1,))
        @test_throws ArgumentError BLS.bounded_step_kkt_v1(A,r,l,[0.0,0.0],(2,2))
        timed=BLS.solve_lower_bounded_step_v1(A,r,l;seconds=0.0)
        @test !timed.converged
        @test timed.status==:wall_time_budget
        @test timed.exit_code!=0
        @test timed.step==(0.0,0.0)
    end
end

function n1_snapshots(out)
    # These are reconstructed *accepted states* from the frozen legacy run.
    # The states are not generated by the new linear-step implementation.
    N=N1ManufacturedRefinementV2;S=N.S
    inputdir=joinpath(ROOT,"docs","implementation","UP2-04-CLOSURE-REPAIR-PREC","agent_r2_n1_20260922","runtime_r1","numerical")
    saved=JSON3.read(read(joinpath(inputdir,"solver_input.json"),String))
    attempts=JSON3.read(read(joinpath(inputdir,"attempts.json"),String))
    saved_primary=JSON3.read(read(joinpath(inputdir,"solver_primary.json"),String))
    solver_input_payload=chomp(read(joinpath(inputdir,"solver_input.json"),String))
    solver_input_digest=bytes2hex(SHA.sha256(codeunits(solver_input_payload)))
    solver_input_digest==String(saved_primary.input_hash.value) || error("saved solver-input canonical digest mismatch")
    String(saved.callback_source_sha256)==sha(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl")) || error("saved callback source mismatch")
    parsed(v)=JSON3.read(JSON3.write(v),Dict{String,Any})
    parsed(saved.analytic_inputs)==parsed(N.INPUTS) || error("saved analytic input mismatch")
    saved.flux_Wb==N.flux_v2() || error("saved flux mismatch")
    fixture=N.fixture_v2(first(N.LEVELS));d=fixture.declaration;data=fixture.data
    parsed(saved.declaration)==JSON3.read(S.canonical_json(d),Dict{String,Any}) || error("saved canonical declaration mismatch")
    declaration_payload=S.canonical_json(d);analytic_payload=S.canonical_json(N.INPUTS)
    source_identity=(callback=(saved_sha256=String(saved.callback_source_sha256),
            current_sha256=sha(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl")),
            saved_source="solver_input.json:callback_source_sha256"),
        solver_input=(saved_digest=String(saved_primary.input_hash.value),current_digest=solver_input_digest,
            canonical_payload=solver_input_payload,saved_source="solver_primary.json:input_hash",
            primary_file_sha256=sha(joinpath(inputdir,"solver_primary.json"))),
        declaration=(saved_digest=nothing,saved_digest_status=:absent_as_separate_field,
            saved_source="solver_input.json:declaration; bound by solver_primary.json:input_hash",
            current_digest=S.canonical_hash(d).value,canonical_payload=declaration_payload,
            comparison=:full_parsed_canonical_payload_equal),
        analytic=(saved_digest=nothing,saved_digest_status=:absent_as_separate_field,
            saved_source="solver_input.json:analytic_inputs; bound by solver_primary.json:input_hash",
            current_digest=S.canonical_hash(N.INPUTS).value,canonical_payload=analytic_payload,
            comparison=:full_parsed_payload_equal),
        operator=(module_name=string(S),entry=:assemble_spatial_system_v4,
            source_path=joinpath(ROOT,"src","RuntimeV4","SpatialMultiRegionV4.jl"),
            source_sha256=sha(joinpath(ROOT,"src","RuntimeV4","SpatialMultiRegionV4.jl")),
            callback_module=string(N),source_callback=:source_v2,traction_callback=:traction_v2,
            normal_callback=:normal_v2,flux_callback=:flux_v2),
        canonical_hash_algorithm=:sha256_of_canonical_json_UTF8,
        canonical_sources=(hashes_sha256=sha(joinpath(ROOT,"src","Canonical","Hashes.jl")),
            json_sha256=sha(joinpath(ROOT,"src","Canonical","CanonicalJSON.jl"))))
    x=Float64.(saved.initial_state);cols=repeat([d.scaling.B_T,d.scaling.B_T,d.scaling.B_T,d.scaling.p_Pa],div(length(x),4))
    captured=NamedTuple[]
    for k in 0:length(attempts)
        expected=k==0 ? attempts[1].state_before_hash : attempts[k].state_after_hash
        current_state_digest=S.canonical_hash(Tuple(x)).value
        current_state_digest==String(expected.value) || error("snapshot source state hash mismatch")
        if k in (0,1,length(attempts))
            a=S.assemble_spatial_system_v4(d,data,x;flux_Wb=N.flux_v2(),source_function=N.source_v2,
                boundary_function=N.traction_v2,normal_field_function=N.normal_v2)
            A=spdiagm(0=>1 ./a.row_scales)*a.jacobian*spdiagm(0=>cols);r=a.residual./a.row_scales
            lower=fill(-Inf,length(x));lower[4:4:end].=-x[4:4:end]./cols[4:4:end]
            snapshot=BLS.bounded_linear_step_snapshot_v1(A,r,lower)
            raw_i,raw_j,raw_v=findnz(a.jacobian)
            raw=(residual=Tuple(a.residual),jacobian=(format=:coordinate,index_base=1,
                rows=size(a.jacobian,1),columns=size(a.jacobian,2),row_indices=Tuple(raw_i),
                column_indices=Tuple(raw_j),values=Tuple(raw_v)),origin=:actual_unscaled_assembly)
            binding=(case=:n1_v2_saved_legacy_state,after_accepted_updates=k,state=Tuple(x),column_scales=Tuple(cols),
                state_identity=(saved_digest=String(expected.value),current_digest=current_state_digest,
                    canonical_payload=S.canonical_json(Tuple(x)),saved_source="attempts.json",
                    attempt_index=k==0 ? 1 : k,field=k==0 ? :state_before_hash : :state_after_hash),
                source_identity=source_identity,
                row_scales=Tuple(a.row_scales),row_blocks=Tuple(a.row_blocks),
                old_solver_input_sha256=sha(joinpath(inputdir,"solver_input.json")),old_attempts_sha256=sha(joinpath(inputdir,"attempts.json")),
                benchmark_sha256=sha(joinpath(@__DIR__,"n1_manufactured_refinement_v2.jl")),
                spatial_solver_sha256=sha(joinpath(ROOT,"src","RuntimeV4","SpatialMultiRegionV4.jl")),
                physical_convergence=:not_assessed)
            # Primary A/r/l checkpoint precedes optional QR and bounded solve.
            write_new(joinpath(out,"n1_linear_input_$k.json"),(binding=binding,raw=raw,input=snapshot))
            unconstrained=qr(A;tol=d.solver.rank_relative_tolerance)\(-r)
            result=BLS.solve_lower_bounded_step_v1(A,r,lower;seconds=20.0)
            write_new(joinpath(out,"n1_linear_result_$k.json"),(binding=binding,raw=raw,input=snapshot,
                unbounded_QR_step=Tuple(unconstrained),unbounded_QR_feasible=all(unconstrained.>=lower),result=result))
            push!(captured,(after_accepted_updates=k,converged=result.converged,status=result.status))
        end
        k==length(attempts) && break
        t=attempts[k+1]
        S.canonical_hash(Tuple(x)).value==String(t.state_before_hash.value) || error("legacy state-before hash mismatch")
        if t.accepted
            x .+= Float64(t.accepted_alpha).*cols.*Float64.(t.proposed_scaled_step)
            for i in 4:4:length(x);S._smr_pressure_feasible(x[i],cols[i]) && x[i]<0.0 && (x[i]=0.0);end
        end
        S.canonical_hash(Tuple(x)).value==String(t.state_after_hash.value) || error("legacy state-after hash mismatch")
    end
    write_new(joinpath(out,"n1_snapshot_summary.json"),(scope=:linear_subproblems_only_no_new_nonlinear_solve,cases=Tuple(captured)))
end

function saved_linear_case(production_dir, out; profile_saved=false, pressure_only=false, projection_compare=false)
    projection_compare && (profile_saved || pressure_only) &&
        error("local projection mode is separate from profiling and pressure-only modes")
    # The serialized Jacobian and residual are raw assembly values; replay the
    # frozen row/column scaling and pressure-step lower bounds before solving.
    function csv_rows(path, header)
        lines = readlines(path)
        !isempty(lines) && first(lines) == header || error("unexpected CSV header: $path")
        [split(line, ',') for line in Iterators.drop(lines, 1) if !isempty(line)]
    end
    state_path = joinpath(production_dir, "solver_state.csv")
    residual_path = joinpath(production_dir, "residual_rows.csv")
    jacobian_path = joinpath(production_dir, "global_weak_jacobian.csv")
    state_rows = csv_rows(state_path, "node_id,BR_T,Bphi_T,BZ_T,p_Pa")
    length(state_rows) > 0 || error("saved state is empty")
    state = Vector{Float64}(undef, 4 * length(state_rows))
    for (node, row) in enumerate(state_rows)
        length(row) == 5 && parse(Int, row[1]) == node || error("invalid saved state row")
        state[4node-3:4node] .= parse.(Float64, row[2:5])
    end
    n = length(state)
    residual_rows = csv_rows(residual_path, "row,block,residual,declared_scale")
    m = length(residual_rows)
    m > 0 || error("saved residual is empty")
    residual = Vector{Float64}(undef, m)
    row_scales = Vector{Float64}(undef, m)
    for (rowid, row) in enumerate(residual_rows)
        length(row) == 4 && parse(Int, row[1]) == rowid || error("invalid saved residual row")
        residual[rowid] = parse(Float64, row[3])
        row_scales[rowid] = parse(Float64, row[4])
        isfinite(row_scales[rowid]) && row_scales[rowid] > 0.0 || error("invalid declared row scale")
    end
    matrix_rows = csv_rows(jacobian_path, "row,column,value")
    ii = Int[]; jj = Int[]; vv = Float64[]
    for row in matrix_rows
        length(row) == 3 || error("invalid saved Jacobian row")
        i = parse(Int, row[1]); j = parse(Int, row[2]); value = parse(Float64, row[3])
        1 <= i <= m && 1 <= j <= n && isfinite(value) || error("invalid saved Jacobian coordinate")
        push!(ii, i); push!(jj, j); push!(vv, value)
    end
    J = sparse(ii, jj, vv, m, n)
    nnz(J) == length(vv) || error("saved Jacobian contains duplicate or explicit-zero coordinates")
    n % 4 == 0 || error("saved state does not have four fields per node")
    # Frozen Q1_8 declaration scales in SpatialMultiRegionV4.jl.
    column_scales = repeat([5.0, 5.0, 5.0, 1.0e5], div(n, 4))
    A = spdiagm(0 => 1.0 ./ row_scales) * J * spdiagm(0 => column_scales)
    r = residual ./ row_scales
    # Frozen pressure_lower_Pa=0; production delta_p >= -current_p.
    lower = fill(-Inf, n)
    for index in 4:4:n
        lower[index] = -state[index] / column_scales[index]
    end
    !pressure_only || (all(isfinite,state) && all(isfinite,r) && all(state[4:4:end].>=0.0)) ||
        error("saved pressure diagnostic needs a finite pressure-feasible state")
    !pressure_only || (m==2337 && n==2080) ||
        error("pressure diagnostic requires the frozen Q1_8 row/column inventory")
    solve_columns=pressure_only ? collect(4:4:n) : collect(1:n)
    solve_A=pressure_only ? A[:,solve_columns] : A
    solve_lower=pressure_only ? lower[solve_columns] : lower
    source_sha256 = (state=sha(state_path), residual=sha(residual_path), jacobian=sha(jacobian_path))
    write_new(joinpath(out, "saved_linear_input.json"),
        (schema="bounded-step-saved-q1-8-input-v1", rows=m, columns=length(solve_columns), nnz=nnz(solve_A),
         full_state_columns=n, solve_column_map=Tuple(solve_columns), pressure_only=pressure_only,
         projection_compare=projection_compare,
         full_nonlinear_feasibility_assessed=false,
         raw_jacobian=true, raw_residual=true,
         row_scaling=:divide_by_residual_rows_declared_scale,
         column_scales=Tuple(column_scales), lower_bound_rule=:pressure_step_minus_current_pressure,
         production_dir=abspath(production_dir), source_sha256,
         profiling=(enabled=profile_saved, allocation_sample_rate=profile_saved ? 1.0e-5 : nothing,
            solver_seconds=projection_compare ? 120.0 : 240.0, scope=:diagnostic_only)))
    if projection_compare
        m==2337 && n==2080 && all(isfinite,state) && all(isfinite,r) && all(state[4:4:end].>=0.0) ||
            error("local projection requires the finite pressure-feasible original Q1_8 final point")
        policy=BLS.bounded_linear_step_policy_v1()
        unbounded=BLS.solve_lower_bounded_step_v1(A,r,fill(-Inf,n);policy=policy,seconds=120.0)
        bounded=BLS.solve_lower_bounded_step_v1(A,r,lower;policy=policy,seconds=120.0)
        write_new(joinpath(out,"local_projection_unbounded.json"),unbounded)
        write_new(joinpath(out,"local_projection_bounded.json"),bounded)
        su=Float64.(collect(unbounded.step));sb=Float64.(collect(bounded.step))
        length(su)==n && length(sb)==n && all(isfinite,su) && all(isfinite,sb) ||
            error("local projection backend returned an invalid step")
        ru=r+A*su;rb=r+A*sb;ad=A*(sb-su);gu=transpose(A)*ru
        all(isfinite,ru) && all(isfinite,rb) && all(isfinite,gu) || error("nonfinite local projection")
        byrows(ids)=(rows=length(ids),before_l2=norm(r[ids]),unbounded_l2=norm(ru[ids]),
            bounded_l2=norm(rb[ids]),before_max=maximum(abs,r[ids]),
            unbounded_max=maximum(abs,ru[ids]),bounded_max=maximum(abs,rb[ids]))
        blocks=Tuple(merge((block=block,),byrows(findall(row->row[2]==block,residual_rows)))
            for block in unique(row[2] for row in residual_rows))
        rank_rows=[h for h in unbounded.history if h.rank_estimate isa Integer]
        xu=state+column_scales.*su;xb=state+column_scales.*sb
        lhs=dot(rb,rb);rhs=dot(ru,ru)+dot(ad,ad)
        summary=(scope=:same_final_point_scaled_linear_projection_only,
            source_sha256=source_sha256,rows=m,columns=n,original_gate=1.0e-6,
            unbounded_status=unbounded.status,bounded_status=bounded.status,
            unbounded_converged=unbounded.converged,bounded_converged=bounded.converged,
            unbounded_kkt=unbounded.kkt,bounded_kkt=bounded.kkt,
            unbounded_rank=isempty(rank_rows) ? nothing : last(rank_rows).rank_estimate,
            unbounded_rank_threshold=isempty(rank_rows) ? nothing : last(rank_rows).rank_threshold,
            blocks=blocks,aggregate_volume=byrows(collect(1:2080)),all_rows=byrows(collect(1:m)),
            unbounded_At_r_inf=norm(gu,Inf),
            unbounded_At_r_relative=norm(gu,Inf)/max(opnorm(A,1)*norm(ru,Inf),eps(Float64)),
            pressure_bound_range_cost_l2=norm(ad),projection_cross_term=dot(ru,ad),
            pythagorean_absolute_error=abs(lhs-rhs),
            pythagorean_relative_error=abs(lhs-rhs)/max(abs(lhs),abs(rhs),eps(Float64)),
            state_zero_pressure_dofs=Tuple(i for i in 4:4:n if state[i]==0.0),
            bounded_active_pressure_dofs=Tuple(i for i in bounded.active_indices if i%4==0),
            bounded_active_nonpressure_dofs=Tuple(i for i in bounded.active_indices if i%4!=0),
            unbounded_endpoint_min_pressure_Pa=minimum(xu[4:4:end]),
            unbounded_endpoint_strict_negative_pressure_dofs=Tuple(i for i in 4:4:n if xu[i]<0.0),
            bounded_endpoint_min_pressure_Pa=minimum(xb[4:4:end]),
            linear_l2_over_sqrt_rows=norm(ru)/sqrt(m),rigorous_lower_bound_claim=false,
            numerical_projection_qualified=unbounded.converged && unbounded.kkt.passed,
            pressure_comparison_qualified=unbounded.converged && unbounded.kkt.passed &&
                bounded.converged && bounded.kkt.passed,
            inner_seconds_each=120.0,nonlinear_endpoint_evaluation=:not_executed,
            nonlinear_infeasibility_established=false,benchmark_acceptance=false)
        write_new(joinpath(out,"local_projection_summary.json"),summary)
        println("Q18_LOCAL_LINEAR_PROJECTION_JSON=",JSON3.write(summary));flush(stdout)
        return
    end
    result = if !profile_saved
        BLS.solve_lower_bounded_step_v1(solve_A, r, solve_lower; policy=BLS.bounded_linear_step_policy_v1(), seconds=240.0)
    else
        # Warm the sparse Float64/vector method path; clear both profilers before sampling.
        BLS.solve_lower_bounded_step_v1(sparse([1.0 1.0; 0.0 1.0]),
            [-3.0, 3.0], [-Inf, -0.5]; seconds=10.0)
        Profile.clear()
        Profile.Allocs.clear()
        gc_before = Base.gc_total_bytes(Base.gc_num())
        started_ns = time_ns()
        Profile.Allocs.start(sample_rate=1.0e-5)
        profiled_result = try
            Profile.@profile BLS.solve_lower_bounded_step_v1(A, r, lower;
                policy=BLS.bounded_linear_step_policy_v1(), seconds=240.0)
        finally
            Profile.Allocs.stop()
        end
        elapsed_s = (time_ns() - started_ns) / 1.0e9
        gc_delta = Base.gc_total_bytes(Base.gc_num()) - gc_before
        allocs = Profile.Allocs.fetch().allocs
        println("Q18_PROFILE_RESULT status=", profiled_result.status,
            " inner_iterations=", profiled_result.inner_iterations,
            " history=", length(profiled_result.history), " elapsed_s=", elapsed_s,
            " gc_total_delta=", gc_delta, " sampled_allocations=", length(allocs))
        Profile.print(stdout; format=:flat, sortedby=:count, mincount=5, C=true)
        Profile.print(stdout; format=:tree, sortedby=:count, maxdepth=12, noisefloor=2.0, C=true)
        repo_src = lowercase(replace(normpath(abspath(joinpath(ROOT, "src"))), '\\' => '/')) * "/"
        alloc_groups = Dict{Tuple{String,String,Int},Tuple{Int,Int}}()
        for alloc in allocs
            idx = findfirst(frame -> startswith(lowercase(replace(normpath(string(frame.file)), '\\' => '/')), repo_src), alloc.stacktrace)
            idx === nothing && continue
            frame = alloc.stacktrace[idx]
            key = (string(frame.file), string(frame.func), Int(frame.line))
            prior = get(alloc_groups, key, (0, 0))
            alloc_groups[key] = (prior[1] + 1, prior[2] + alloc.size)
        end
        rows = sort(collect(alloc_groups), by=row -> row.second[2], rev=true)
        for row in rows[1:min(30, length(rows))]
            println("Q18_ALLOC_SITE file=", row.first[1], " function=", row.first[2],
                " line=", row.first[3], " samples=", row.second[1],
                " sampled_bytes=", row.second[2])
        end
        profiled_result
    end
    write_new(joinpath(out, "saved_linear_result.json"), result)
    if pressure_only
        step=Float64.(collect(result.step))
        length(step)==length(solve_columns) && all(isfinite,step) ||
            error("pressure-only diagnostic returned an invalid step")
        model=r+solve_A*step
        endpoint=copy(state); endpoint[solve_columns].+=column_scales[solve_columns].*step
        blocks=Tuple(begin
            ids=findall(row -> row[2]==block,residual_rows)
            (block=block,rows=length(ids),before_max=maximum(abs,r[ids]),
                after_max=maximum(abs,model[ids]),before_l2=norm(r[ids]),after_l2=norm(model[ids]))
        end for block in unique(row[2] for row in residual_rows))
        unchanged_rows=findall(iszero,vec(sum(abs,solve_A;dims=2)))
        report=(scope=:all_original_rows_fixed_B_pressure_affine_subspace,
            rows=m,pressure_columns=length(solve_columns),original_tolerance=1.0e-6,
            model_scaled_max=maximum(abs,model),model_scaled_l2=norm(model),
            endpoint_min_pressure_Pa=minimum(endpoint[solve_columns]),
            solver_converged=result.converged,kkt=result.kkt,blocks=blocks,
            pressure_independent_rows=Tuple(unchanged_rows),
            pressure_independent_scaled_max=maximum(abs,r[unchanged_rows];init=0.0),
            endpoint_B_unchanged=endpoint[setdiff(1:n,solve_columns)]==state[setdiff(1:n,solve_columns)],
            exact_original_operator_reassembly=:required_separate_oracle_check,
            full_nonlinear_infeasibility_established=false,benchmark_acceptance=false)
        write_new(joinpath(out,"saved_pressure_compatibility.json"),report)
        write_new(joinpath(out,"saved_pressure_model_residual.json"),Tuple(model))
        open(joinpath(out,"pressure_endpoint_state.csv"),"w") do io
            println(io,"node_id,BR_T,Bphi_T,BZ_T,p_Pa")
            for node in 1:div(n,4)
                println(io,join((node,endpoint[4node-3:4node]...),","))
            end
        end
        println("Q18_PRESSURE_COMPATIBILITY_JSON=",JSON3.write(report));flush(stdout)
    end
    println("BOUNDED_STEP_SAVED_LINEAR_COMPLETE status=", result.status,
        " converged=", result.converged, " iterations=", result.inner_iterations,
        " seconds=", result.elapsed_seconds, " profiling_diagnostic_only=", profile_saved)
end


function saved_linear_input_case(input_path, out; seconds=240.0, diagnostic=false)
    raw = JSON3.read(read(input_path, String))
    raw["schema"] == "q1-8-saved-linear-input-replay-v1" || error("unsupported saved linear input schema")
    input = raw["input"]
    input["schema"] == "spatial-bounded-linear-input-v1" || error("unsupported bounded linear input schema")
    rows=Int(input["rows"]); columns=Int(input["columns"])
    matrix=input["matrix"]
    matrix["format"] == "coordinate" || error("saved input matrix must use coordinate format")
    Int(input["index_base"]) == 1 || error("saved input indices must be one based")
    ii=Int.(matrix["row_indices"]); jj=Int.(matrix["column_indices"])
    vv=Float64.(matrix["values"])
    length(ii)==length(jj)==length(vv) || error("coordinate lengths differ")
    all(i -> 1 <= i <= rows, ii) && all(j -> 1 <= j <= columns, jj) || error("coordinate index out of range")
    all(isfinite, vv) || error("nonfinite saved matrix value")
    A=sparse(ii,jj,vv,rows,columns)
    nnz(A)==length(vv) || error("saved matrix has duplicate or explicit-zero coordinates")
    length(input["residual"])==rows || error("saved residual length mismatch")
    length(input["lower_bounds"])==columns || error("saved lower bound length mismatch")
    r=Float64.(input["residual"])
    lower=Float64[x === nothing ? -Inf : Float64(x) for x in input["lower_bounds"]]
    all(isfinite,r) && all(x -> isfinite(x) || x == -Inf,lower) || error("invalid saved vectors")
    all(x -> x <= 0.0,lower) || error("saved lower bounds must admit zero step")
    ispath(out) && error("output must be new")
    mkpath(out)
    counts=Dict{String,Int}()
    cache_deltas=NamedTuple[]
    cache_delta_total=Ref(0)
    recorder = diagnostic ? (event -> begin
        try
            name=String(event.event)
            counts[name]=get(counts,name,0)+1
            if event.event===:cache_update_result
                cache_delta_total[]+=1
                if length(cache_deltas)<128
                    detail=event.detail
                    push!(cache_deltas,(iteration=event.iteration,kind=detail.kind,accepted=detail.accepted,
                        reason=detail.reason,updates_before=detail.updates_before,updates_after=detail.updates_after,
                        old_only=detail.old_only,new_only=detail.new_only))
                end
            end
        catch
            # Diagnostics are best effort and must not affect the numerical replay.
        end
        nothing
    end) : nothing
    policy=BLS.bounded_linear_step_policy_v1()
    result = diagnostic ? BLS.solve_lower_bounded_step_v1(A,r,lower;policy,seconds,
        diagnostic_stats=recorder) : BLS.solve_lower_bounded_step_v1(A,r,lower;policy,seconds)
    new_step=Float64.(collect(result.step))
    original=raw["original_bounded_step"]
    old_step=Float64.(original["step"])
    length(old_step)==columns || error("original recorded step length mismatch")
    linear_ratio=norm(A*new_step+r)/max(norm(r),eps(Float64))
    pcols=collect(4:4:columns)
    length(pcols)==520 || error("unexpected Q1_8 pressure column count")
    p_before=Float64[-lower[i]*1.0e5 for i in pcols]
    p_after=p_before .+ Float64[1.0e5*new_step[i] for i in pcols]
    close_lower=findall(i -> abs(new_step[i]-lower[i]) <= 1.0e-10, pcols)
    baseline_ratio=raw["postrecord_linear_relative_residual"]
    summary=(schema="q1-8-saved-linear-replay-result-v1",
        input_path=abspath(input_path),input_sha256=sha(input_path),
        source_attempts_path=raw["source_attempts_path"],source_attempts_sha256=raw["source_attempts_sha256"],
        attempt_array_row_zero_based=raw["attempt_array_row_zero_based"],attempt_index_one_based=raw["attempt_index_one_based"],
        state_before_iteration=raw["state_before_iteration"],accepted_state_iteration=raw["accepted_state_iteration"],
        state_before_hash=raw["state_before_hash"],state_after_hash=raw["state_after_hash"],
        baseline_accepted=raw["accepted"],baseline_accepted_alpha=raw["accepted_alpha"],
        baseline_objective_before=raw["objective_before"],baseline_objective_after=raw["objective_after"],
        baseline_linear_relative_residual=baseline_ratio,rows=rows,columns=columns,nnz=nnz(A),
        actual_input_objective=0.5*dot(r,r),recorded_inner_initial_objective=raw["original_bounded_step_summary"]["initial_objective"],
        replay_status=result.status,replay_converged=result.converged,replay_inner_iterations=result.inner_iterations,
        replay_elapsed_seconds=result.elapsed_seconds,replay_objective=result.kkt.objective,
        replay_linear_relative_residual=linear_ratio,
        original_inner_status=raw["original_bounded_step_summary"]["status"],
        original_inner_iterations=raw["original_bounded_step_summary"]["inner_iterations"],
        original_inner_elapsed_seconds=raw["original_bounded_step_summary"]["elapsed_seconds"],
        original_step_max_abs_difference=maximum(abs.(new_step-old_step);init=0.0),
        original_step_relative_difference=norm(new_step-old_step)/max(norm(old_step),eps(Float64)),
        replay_active_indices_count=length(result.active_indices),
        replay_free_indices_count=length(result.free_indices),
        kkt=(passed=result.kkt.passed,finite=result.kkt.finite,free_stationarity=result.kkt.free_stationarity,
            lower_dual_violation=result.kkt.lower_dual_violation,complementarity=result.kkt.complementarity,
            primal_feasible=result.kkt.primal_feasible,primal_violation=result.kkt.primal_violation,
            tolerance=result.kkt.tolerance),
        pressure_nodes=length(pcols),pressure_min_before_Pa=minimum(p_before),
        pressure_zero_contacts_before=count(iszero,p_before),pressure_min_after_Pa=minimum(p_after),
        pressure_zero_contacts_after=count(iszero,p_after),pressure_step_lower_contacts=length(close_lower),
        diagnostic_enabled=diagnostic,diagnostic_counts=counts,
        cache_update_result_total=cache_delta_total[],cache_update_deltas_truncated=max(0,cache_delta_total[]-length(cache_deltas)))
    write_new(joinpath(out,"saved_linear_replay_summary.json"),summary)
    write_new(joinpath(out,"saved_linear_replay_solver_result.json"),result)
    diagnostic && write_new(joinpath(out,"saved_linear_replay_cache_deltas.json"),cache_deltas)
    println("Q18_SAVED_LINEAR_REPLAY state_before=",raw["state_before_iteration"],
        " attempt=",raw["attempt_index_one_based"]," status=",result.status,
        " converged=",result.converged," iterations=",result.inner_iterations,
        " elapsed_s=",result.elapsed_seconds," kkt=",result.kkt.passed,
        " relative_linear_residual=",linear_ratio," step_maxdiff=",summary.original_step_max_abs_difference,
        " diagnostic=",diagnostic)
end

function main(args)
    if length(args) == 3 && args[1] in ("--saved-linear", "--profile-saved-linear", "--saved-pressure-compatibility", "--saved-local-projection")
        production_dir = abspath(args[2]); out = abspath(args[3])
        isdir(production_dir) || error("production directory does not exist")
        ispath(out) && error("output must be new")
        mkpath(out)
        saved_linear_case(production_dir, out; profile_saved=args[1] == "--profile-saved-linear",
            pressure_only=args[1] == "--saved-pressure-compatibility",
            projection_compare=args[1] == "--saved-local-projection")
        return
    end
    if length(args) in (3,4) && args[1] == "--saved-linear-input"
        input_path=abspath(args[2]);out=abspath(args[3])
        isfile(input_path) || error("saved linear input does not exist")
        diagnostic=length(args)==4 && args[4]=="--diagnostic-stats"
        length(args)==3 || diagnostic || error("unsupported saved linear input option")
        saved_linear_input_case(input_path,out;seconds=240.0,diagnostic)
        return
    end
    length(args) in (2,3) || error("expected ORACLE.json OUTPUT_DIR [--n1-snapshots], --saved-linear/--profile-saved-linear PRODUCTION_DIR OUTPUT_DIR, or --saved-linear-input INPUT.json OUTPUT_DIR [--diagnostic-stats]")
    oraclepath=abspath(args[1]);out=abspath(args[2]);ispath(out) && error("output must be new")
    length(args)==3 && args[3]!="--n1-snapshots" && error("unsupported mode")
    facade_identity_negative_controls()
    trace_equivalence_tests()
    downdate_cache_transition_tests()
    mkpath(out)
    write_new(joinpath(out,"inputs.json"),(schema="bounded-step-test-inputs-v1",oracle_sha256=sha(oraclepath),
        implementation_sha256=String(BLS_IMPLEMENTATION_IDENTITY.implementation_sha256),
        facade_identity=BLS_FACADE_IDENTITY,test_sha256=sha(@__FILE__),algorithm=BLS_IMPLEMENTATION_IDENTITY))
    unit_cases(oraclepath,out)
    length(args)==3 && n1_snapshots(out)
    write_new(joinpath(out,"completion.json"),(execution=:completed,physical_convergence=:not_assessed))
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main(ARGS)
end
