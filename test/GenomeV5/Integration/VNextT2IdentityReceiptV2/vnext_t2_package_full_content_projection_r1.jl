using Test
using JSON3
include(joinpath(@__DIR__, "fixture_helpers.jl"))

length(ARGS) == 1 || error(
    "usage: vnext_t2_package_full_content_projection_r1.jl <actual-observation.json>")
const T2_PACKAGE_PROJECTION_OBSERVATION = normpath(abspath(ARGS[1]))
isdir(dirname(T2_PACKAGE_PROJECTION_OBSERVATION)) ||
    error("projection regression recorder must create the evidence directory")
ispath(T2_PACKAGE_PROJECTION_OBSERVATION) &&
    error("projection regression actual observation already exists")

function t2_write_package_projection_observation(value)
    (ispath(T2_PACKAGE_PROJECTION_OBSERVATION) ||
        islink(T2_PACKAGE_PROJECTION_OBSERVATION)) &&
        error("projection regression actual observation already exists")
    temp_path, io = mktemp(dirname(T2_PACKAGE_PROJECTION_OBSERVATION);
        cleanup=false)
    try
        JSON3.write(io, value)
        write(io, '\n')
        flush(io)
        close(io)
        mv(temp_path, T2_PACKAGE_PROJECTION_OBSERVATION; force=false)
    catch
        isopen(io) && close(io)
        ispath(temp_path) && rm(temp_path; force=true)
        rethrow()
    end
end

actual = try
    # Use one source-backed fixture.  Exercise the wire and declaration carrier
    # attacks sequentially so their copied byte payloads are never retained at
    # the same time.  Both deliberately retain the stored package identities.
    chain = t2_chain()
    original = chain.admission.package
    reloaded = chain.reloaded_package
    original_validation = T2_G.vnext_t1_package_v2_validate(original)
    reloaded_validation = T2_G.vnext_t1_package_v2_validate(reloaded)
    package_content_equal =
        T2_G._vnext_t2_t1_package_content_equal_v2(original, reloaded)
    original_content_hash =
        T2_G._vnext_t2_t1_package_content_hash_v2(original)
    reloaded_content_hash =
        T2_G._vnext_t2_t1_package_content_hash_v2(reloaded)

    projection = T2_G._vnext_t2_t1_package_projection_v2(reloaded)
    projection_domain = projection.domain
    projection_key_count = length(keys(projection))
    projection_wire_base64_equal =
        projection.wire.base64 == T2_G.semantic_view(reloaded.wire).base64
    projection_wire_length_equal =
        projection.wire.length == T2_G.byte_length(reloaded.wire)
    admission_projection = T2_G._vnext_t2_t1_admission_projection_v2(
        chain.admission)
    admission_projection_domain = admission_projection.domain
    admission_package_projection_full_content_equal =
        T2_G._vnext_t2_v2_content_equal(
            admission_projection.package, projection)
    admission_package_projection_hash =
        T2_G.canonical_hash(admission_projection.package)
    projection_hash = T2_G.canonical_hash(projection)
    projection = nothing
    admission_projection = nothing
    GC.gc(false)

    wire_bytes = T2_G.copy_bytes(reloaded.wire)
    wire_bytes[1] = xor(wire_bytes[1], 0x01)
    tampered_wire = t2_replace_struct_field(reloaded, :wire,
        T2_G.VNextT1CanonicalBytesV2(wire_bytes))
    wire_package_hash_retained =
        tampered_wire.package_hash == reloaded.package_hash
    wire_semantic_identity_retained =
        tampered_wire.semantic_identity == reloaded.semantic_identity
    wire_content_equal =
        T2_G._vnext_t2_t1_package_content_equal_v2(original, tampered_wire)
    wire_content_hash =
        T2_G._vnext_t2_t1_package_content_hash_v2(tampered_wire)
    wire_build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(
        chain.source.witness, chain.admission_input, chain.admission,
        tampered_wire, chain.adapter, chain.gate,
        scenario=chain.gate.scenario)
    wire_result = T2_G.vnext_t2_rebind_identity_receipts_v2(wire_build)
    wire_build_status = String(wire_build.status)
    wire_build_resolution = String(wire_build.resolution)
    wire_build_reason = String(wire_build.reason)
    wire_attempted_events = length(wire_result.attempted_trace.events)
    wire_attempted_counts =
        T2_G.semantic_view(wire_result.attempted_trace.counts)
    wire_zero_attempted_counts = all(==(0), values(wire_attempted_counts))
    wire_bytes = nothing
    tampered_wire = nothing
    wire_build = nothing
    wire_result = nothing
    GC.gc(false)

    first_declaration = reloaded.declarations[1]
    source_bytes = T2_G.copy_bytes(first_declaration.source_bytes)
    source_bytes[1] = xor(source_bytes[1], 0x01)
    tampered_declaration = t2_replace_struct_field(first_declaration,
        :source_bytes, T2_G.VNextT1CanonicalBytesV2(source_bytes))
    tampered_source = t2_replace_struct_field(reloaded, :declarations,
        (tampered_declaration, reloaded.declarations[2],
            reloaded.declarations[3]))
    source_package_hash_retained =
        tampered_source.package_hash == reloaded.package_hash
    source_semantic_identity_retained =
        tampered_source.semantic_identity == reloaded.semantic_identity
    source_content_equal =
        T2_G._vnext_t2_t1_package_content_equal_v2(original, tampered_source)
    source_content_hash =
        T2_G._vnext_t2_t1_package_content_hash_v2(tampered_source)
    source_build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(
        chain.source.witness, chain.admission_input, chain.admission,
        tampered_source, chain.adapter, chain.gate,
        scenario=chain.gate.scenario)
    source_result = T2_G.vnext_t2_rebind_identity_receipts_v2(source_build)
    source_build_status = String(source_build.status)
    source_build_resolution = String(source_build.resolution)
    source_build_reason = String(source_build.reason)
    source_attempted_events = length(source_result.attempted_trace.events)
    source_counts = T2_G.semantic_view(source_result.attempted_trace.counts)
    source_zero_counts = all(==(0), values(source_counts))
    source_bytes = nothing
    tampered_declaration = nothing
    tampered_source = nothing
    source_build = nothing
    source_result = nothing
    GC.gc(false)

    (schema="vnext-t2-package-full-content-projection-actual-r1",
        suite="vnext-t2-package-full-content-projection-r1",
        status="actual_observed",
        classification="supplemental_product_regression",
        process_id=getpid(),
        recorded_before_assertions=true,
        planned_test_sites=24,
        assertion_sites_completed=0,
        groups=(
            reload_content_equivalence=(planned_sites=8, observed_values=8,
                original_validation=original_validation === nothing ?
                    "none" : String(original_validation),
                reloaded_validation=reloaded_validation === nothing ?
                    "none" : String(reloaded_validation),
                package_content_equal=package_content_equal,
                content_hash_equal=original_content_hash == reloaded_content_hash,
                projection_domain=projection_domain,
                projection_key_count=projection_key_count,
                wire_base64_equal=projection_wire_base64_equal,
                wire_length_equal=projection_wire_length_equal),
            wire_byte_tamper_detection=(planned_sites=7, observed_values=7,
                stored_package_hash_retained=wire_package_hash_retained,
                stored_semantic_identity_retained=
                    wire_semantic_identity_retained,
                full_content_equal=wire_content_equal,
                full_content_hash_changed=
                    wire_content_hash != reloaded_content_hash,
                build_status=wire_build_status,
                build_resolution=wire_build_resolution,
                build_reason=wire_build_reason,
                attempted_events=wire_attempted_events,
                attempted_counts=wire_attempted_counts,
                zero_attempted_counts=wire_zero_attempted_counts),
            source_byte_tamper_detection=(planned_sites=7, observed_values=7,
                stored_package_hash_retained=source_package_hash_retained,
                stored_semantic_identity_retained=
                    source_semantic_identity_retained,
                full_content_equal=source_content_equal,
                full_content_hash_changed=
                    source_content_hash != reloaded_content_hash,
                build_status=source_build_status,
                build_resolution=source_build_resolution,
                build_reason=source_build_reason,
                attempted_events=source_attempted_events,
                attempted_counts=source_counts,
                zero_attempted_counts=source_zero_counts),
            admission_envelope_projection=(planned_sites=2, observed_values=2,
                projection_domain=admission_projection_domain,
                package_projection_full_content_equal=
                    admission_package_projection_full_content_equal,
                package_projection_hash_equal_observation=
                    admission_package_projection_hash == projection_hash)),
        original_content_hash=original_content_hash.value,
        reloaded_content_hash=reloaded_content_hash.value,
        wire_tampered_content_hash=wire_content_hash.value,
        source_tampered_content_hash=source_content_hash.value,
        formal_t2_accepted=false,
        actual_model_attestation="unavailable")
catch error
    t2_write_package_projection_observation((
        schema="vnext-t2-package-full-content-projection-actual-r1",
        suite="vnext-t2-package-full-content-projection-r1",
        status="program_exception",
        classification="supplemental_product_regression",
        process_id=getpid(),
        recorded_before_assertions=true,
        planned_test_sites=24,
        assertion_sites_completed=0,
        groups=nothing,
        exception_type=string(typeof(error)),
        exception_message=sprint(showerror, error),
        formal_t2_accepted=false,
        actual_model_attestation="unavailable"))
    rethrow()
end

t2_write_package_projection_observation(actual)
println("VNEXT_T2_PACKAGE_PROJECTION_ACTUAL_SAVED status=",
    actual.status, " assertion_sites_completed=",
    actual.assertion_sites_completed); flush(stdout)

reload_group = actual.groups.reload_content_equivalence
wire_group = actual.groups.wire_byte_tamper_detection
source_group = actual.groups.source_byte_tamper_detection
admission_group = actual.groups.admission_envelope_projection

@testset "VNext T2 full T1 package content projection" begin
    @test reload_group.original_validation == "none"
    @test reload_group.reloaded_validation == "none"
    @test reload_group.package_content_equal
    @test reload_group.content_hash_equal
    @test reload_group.projection_domain ==
        "vnext-t2-t1-package-full-content-projection-v2"
    @test reload_group.projection_key_count == 20
    @test reload_group.wire_base64_equal
    @test reload_group.wire_length_equal

    @test wire_group.stored_package_hash_retained
    @test wire_group.stored_semantic_identity_retained
    @test !wire_group.full_content_equal
    @test wire_group.full_content_hash_changed
    @test wire_group.build_status == "fail_closed"
    @test wire_group.build_reason ==
        "t2_preflight_t1_reloaded_package_mismatch"
    @test wire_group.attempted_events == 0

    @test source_group.stored_package_hash_retained
    @test source_group.stored_semantic_identity_retained
    @test !source_group.full_content_equal
    @test source_group.full_content_hash_changed
    @test source_group.build_status == "fail_closed"
    @test source_group.build_reason ==
        "t2_preflight_t1_reloaded_package_mismatch"
    @test source_group.attempted_events == 0

    @test admission_group.projection_domain ==
        "vnext-t2-t1-admission-full-content-projection-v2"
    @test admission_group.package_projection_full_content_equal
end

println("VNEXT_T2_PACKAGE_PROJECTION_REGRESSION=PASS sites=24 groups=4 ",
    "classification=supplemental_product_regression formal_t2_accepted=false")
flush(stdout)
