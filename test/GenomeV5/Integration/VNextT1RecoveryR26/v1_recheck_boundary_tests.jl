using Test, SHA

const R26_V1_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const R26_V1_FIXTURE_SOURCE = joinpath(R26_V1_ROOT,
    "test/GenomeV5/Integration/vnext_t1_candidate_state_package_v5_next_formal_v2_tests.jl")
const R26_V1_OMISSIONS = Dict("testsets" => 0, "printlns" => 0)

# Reuse the exact frozen fixture/helper definitions while leaving its known
# broken testsets immutable.  Formal target remapping belongs to the separate
# independent formal-test lane.
Base.include(Main, R26_V1_FIXTURE_SOURCE) do expression
    if expression isa Expr
        if expression.head === :macrocall && string(expression.args[1]) == "@testset"
            R26_V1_OMISSIONS["testsets"] += 1
            return nothing
        elseif expression.head === :call && expression.args[1] === :println
            R26_V1_OMISSIONS["printlns"] += 1
            return nothing
        end
    end
    expression
end

function r26_v1_transport_with(t; candidate=t.candidate_ref,
        declarations=t.declarations, children=t.children,
        feedback=t.feedback, status=t.status, errors=t.errors, gaps=t.gaps)
    ordered_feedback = Tuple(sort!(collect(feedback), by=x -> x.target_id))
    body = G._vnl_t0_bundle_body_v1(candidate, Tuple(declarations),
        Tuple(children), ordered_feedback)
    G.VNextT0LocalTransportV1(candidate, Tuple(declarations), Tuple(children),
        ordered_feedback, G.canonical_hash(body), status, errors, gaps)
end

function r26_v1_recheck(transport, records)
    G.vnext_declaration_authority_recheck_local_v1(
        G.VNextAuthorityRecheckLocalInputV1(_T1_CANDIDATE, transport, records))
end

@testset "R26 V1 exact recheck input boundary" begin
    @test R26_V1_OMISSIONS == Dict("testsets" => 2, "printlns" => 5)
    fixture = _t1_fixture()
    present_type = G.VNextAuthorityRecheckLocalResultV1{
        G.VNextAuthorityRecheckLocalCheckedPresentV1}
    absent_type = G.VNextAuthorityRecheckLocalResultV1{
        G.VNextAuthorityRecheckLocalTypedAbsentV1}
    failure_type = G.VNextAuthorityRecheckLocalResultV1{Nothing}
    @test G.VNextT1ExpectedRecheckV1 === present_type
    @test G.VNextT1AdmissionRecheckInputV1 === Union{
        present_type, absent_type, failure_type}
    @test fieldtype(G.VNextT1AdmissionInputV1, :t0_recheck) === Union{
        Nothing, present_type, absent_type, failure_type}

    absent_g3 = G.VNextT0LocalAbsentDeclarationV1(:G3, _T1_CANDIDATE,
        :missing_material, :terminal_deferred)

    # Retained R25 case: present bundle versus absent local record.
    forward_mismatch = r26_v1_recheck(fixture.transport,
        (fixture.declarations[1], fixture.declarations[2], absent_g3))
    @test forward_mismatch isa failure_type
    @test forward_mismatch.status === :fail_closed
    @test forward_mismatch.resolution === :none
    @test forward_mismatch.errors == (:record_bundle_canonical_mismatch,)
    forward_input = G.VNextT1AdmissionInputV1(_T1_CANDIDATE,
        forward_mismatch, fixture.transport)
    forward_result = G.vnext_t1_admit_skeleton_v1(forward_input)
    @test forward_result.status === :fail_closed
    @test forward_result.errors == (:t0_recheck_gate_invalid,)
    @test forward_result.package === nothing

    absent_transport = r26_v1_transport_with(fixture.transport;
        declarations=(fixture.declarations[1], fixture.declarations[2], absent_g3))

    # Reverse mismatch is independently fail-closed.
    reverse_mismatch = r26_v1_recheck(absent_transport, fixture.declarations)
    @test reverse_mismatch isa failure_type
    @test reverse_mismatch.status === :fail_closed
    @test reverse_mismatch.errors == (:record_bundle_canonical_mismatch,)
    reverse_result = G.vnext_t1_admit_skeleton_v1(
        G.VNextT1AdmissionInputV1(_T1_CANDIDATE, reverse_mismatch, absent_transport))
    @test reverse_result.status === :fail_closed
    @test reverse_result.package === nothing

    # Honest absence requires both bundle and independently supplied records to
    # contain the same absent declaration.  V1 admits the object to its public
    # boundary, then preserves its policy of fail-closed with no package.
    coherent_absence = r26_v1_recheck(absent_transport,
        (fixture.declarations[1], fixture.declarations[2], absent_g3))
    @test coherent_absence isa absent_type
    @test coherent_absence.status === :typed_absent
    @test coherent_absence.resolution === :terminal_deferred
    @test coherent_absence.errors === ()
    @test coherent_absence.reasons == (:missing_material, :g3_feedback_material_absent)
    coherent_input = G.VNextT1AdmissionInputV1(_T1_CANDIDATE,
        coherent_absence, absent_transport)
    coherent_result = G.vnext_t1_admit_skeleton_v1(coherent_input)
    @test coherent_result.status === :fail_closed
    @test coherent_result.resolution === :none
    @test coherent_result.errors == (:t0_recheck_gate_invalid,)
    @test coherent_result.package === nothing
    @test coherent_result.accepted === false
    @test coherent_result.claim_ceiling === :contract_only
end

println("R26_V1_BOUNDARY_PASS formal_T1=false")
