using Test
using JSON3
using Serialization
using SHA
using FusionConceptAI

const G = FusionConceptAI
const _N05_RECEIPT_FIXTURE = JSON3.read(read(joinpath(@__DIR__, "n05_flux_authority_fixtures.json"), String))

function _n05e_named(x::JSON3.Object)
    keys_tuple = Tuple(Symbol(String(k)) for k in keys(x))
    values_tuple = Tuple(_n05e_named(getproperty(x, k)) for k in keys_tuple)
    NamedTuple{keys_tuple}(values_tuple)
end
_n05e_named(x::JSON3.Array) = Tuple(_n05e_named(v) for v in x)
_n05e_named(x) = x
_n05e_roundtrip(x) = JSON3.read(JSON3.write(x))

function _n05e_write_forged(output_dir, name, envelope)
    path = joinpath(output_dir, "forged_$(name).json")
    open(path, "w") do io
        JSON3.write(io, envelope)
    end
    path
end

function _n05e_expect_file_rejection(path, package, e0, authored, absent, specs,
        expected_message)
    caught = try
        G.n05_check_receipt_file(path, package, e0, authored, absent, specs)
        nothing
    catch err
        err
    end
    @test caught isa ArgumentError
    actual_message = caught isa ArgumentError ? sprint(showerror, caught) : string(caught)
    if caught isa ArgumentError
        @test occursin(expected_message, actual_message)
    end
    actual_message
end

function _n05e_file_record(path, id, changed_field, expected_message, actual_message)
    (id=id, path=abspath(path), bytes=filesize(path),
        sha256=bytes2hex(SHA.sha256(read(path))), changed_field=changed_field,
        expected_targeted_rejection=expected_message,
        actual_error_message=actual_message)
end

function _n05e_child_fixture(layer::String)
    output = tempname()
    script = joinpath(@__DIR__, "..", "UP1-04", "layer_fixture_child.jl")
    run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $script $layer $output`)
    open(output, "r") do io
        Serialization.deserialize(io)
    end
end

function _n05e_package(candidate_id="fusionconceptai://candidate/candidate-1")
    candidate = G.QualifiedRefV1(candidate_id, "v5")
    base_g1 = _n05e_child_fixture("G1")
    g1_old = base_g1.payload.contract_ref
    g1_ref = G.G1GenomeContractRefV2(replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G1/"),
        g1_old.version, g1_old.schema_hash, g1_old.canonicalization_hash,
        g1_old.compatibility_profile, g1_old.version_axes, candidate.id;
        grammar_profile_hash=g1_old.grammar_profile_hash,
        applicability_profile_hash=g1_old.applicability_profile_hash)
    g1_payload = G.MechanismGenomePayloadV2(g1_ref, base_g1.payload.states,
        base_g1.payload.equation_plan, base_g1.payload.grammar_profile)
    g1 = G.MechanismGenomeV5(G.g1_materialize_contract_ref(g1_ref, base_g1.payload.grammar_profile),
        g1_payload, base_g1.version_axes)
    base_g2 = _n05e_child_fixture("G2")
    g2_ref = G.GenomeContractRef(replace(candidate.id, "fusionconceptai://candidate/" => "fusionconceptai://GenomeV5/G2/"),
        "v5", base_g2.contract_ref.schema_hash, base_g2.contract_ref.canonicalization_hash,
        base_g2.contract_ref.compatibility_profile)
    g2 = G.FieldGeometryGenomeV5(g2_ref, base_g2.region_interface, base_g2.plan,
        base_g2.grammar_profile, base_g2.version_axes)
    base_g3 = _n05e_child_fixture("G3")
    rb = G.G3ContractBindingV2(base_g3.realization.contract_binding.contract_ref,
        candidate, base_g3.realization.contract_binding.version_axes)
    cb = G.G3ContractBindingV2(base_g3.control.contract_binding.contract_ref,
        candidate, base_g3.control.contract_binding.version_axes)
    bb = G.G3ContractBindingV2(base_g3.binding.contract_binding.contract_ref,
        candidate, base_g3.binding.contract_binding.version_axes)
    bundle = G.G3ContractBindingV2(base_g3.contract_binding.contract_ref,
        candidate, base_g3.contract_binding.version_axes)
    realization = G.RealizationGenomeV5(rb, base_g3.realization.network,
        base_g3.realization.material_domains, base_g3.realization.manufacturing_domains;
        provider_match=:no_match)
    control = G.ControlGenomeV5(cb, base_g3.control.signal_ports, base_g3.control.controllers,
        base_g3.control.faults, base_g3.control.plan; provider_match=:no_match)
    feedback = Tuple(G.G3FeedbackChannelV2(x.feedback_id, x.target_layer,
        x.target_layer === :G1 ? g1.contract_ref : g2_ref, x.channel, x.unit, x.kind,
        x.source_id) for x in base_g3.binding.feedback)
    binding = G.CoupledRealizationControlBindingV2(bb, rb, cb, base_g3.binding.links, feedback)
    g3 = G.RealizationControlGenomeV5(bundle, realization, control, binding)
    G.integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)
end

function _n05e_decl(package)
    candidate = package.candidate_ref
    g1_ref, g2_ref, g3_ref = package.g1.contract_ref, package.g2.contract_ref, package.g3.contract_binding.contract_ref
    interface = package.g2.region_interface.interfaces[1]
    equations = package.g1.payload.equation_plan.equations
    occurrences = [o for e in equations for o in e.occurrences]
    left_o, right_o = occurrences[1], occurrences[2]
    left_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :left), "v1")
    right_ref = G.QualifiedRefV1(G._n05_endpoint_id(candidate, interface.interface_ref, :right), "v1")
    unit = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
    left_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(left_ref, unit), :authoritative)
    right_unit = G.UP2N05UnitProvenanceV1(unit, G._n05_authored_unit_source(right_ref, unit), :authoritative)
    left = G.UP2N05FluxEndpointV1(left_ref, "authored-flux-left", :left, 1, left_unit,
        G.UP2N05OccurrenceLocatorV1(left_o.equation_id, left_o.port_side, left_o.port_index,
            left_o.ledger_id, G.UP2N05SourceLocatorV1(:G1, G._n05_occurrence_path(left_o),
                g1_ref, package.g1.candidate_hash, :G1LedgerOccurrenceV2)))
    right = G.UP2N05FluxEndpointV1(right_ref, "authored-flux-right", :right, -1, right_unit,
        G.UP2N05OccurrenceLocatorV1(right_o.equation_id, right_o.port_side, right_o.port_index,
            right_o.ledger_id, G.UP2N05SourceLocatorV1(:G1, G._n05_occurrence_path(right_o),
                g1_ref, package.g1.candidate_hash, :G1LedgerOccurrenceV2)))
    expression = G.UP2N05LawExpressionV1(:signed_transfer, left.port_id, right.port_id, :antisymmetric_transfer)
    law_ref = G.QualifiedRefV1(G._n05_law_id(candidate, interface.interface_ref), "v1")
    law = G.UP2N05FluxLawV1(law_ref, :flux, expression, 1, -1, unit,
        G.UP2N05SourceLocatorV1(:N05, "/n05/authored_flux_law/$(law_ref.id)", law_ref,
            G._n05_law_source_hash(law_ref, expression, 1, -1, unit), :AuthoredFluxLawV1))
    G.UP2N05FluxDeclarationV1(candidate, package.candidate_hash, g1_ref, g2_ref, g3_ref,
        package.version_axes, :flux, law, interface.interface_ref, interface.left_region_id,
        interface.right_region_id, left, right)
end

function _n05e_specs()
    Tuple(G.UP2N05MutationSpecV1(String(x.id), String(x.field_path), Symbol(String(x.mutation_kind)),
        Symbol(String(x.expected_error)), Symbol(String(x.expected_resolution))) for x in _N05_RECEIPT_FIXTURE.mutations)
end

@testset "UP2-00E1 N05 serialized receipt envelope" begin
    package = _n05e_package()
    e0 = G.up2_candidate_physical_binding_from_a(package)
    declaration = _n05e_decl(package)
    authored = G.up2n05_authority_from_a(package, e0; declaration=declaration)
    absent = G.up2n05_authority_from_a(package, e0)
    output_root = get(ENV, "N05_RECEIPT_OUTPUT_DIR", "")
    if isempty(output_root)
        output_root = mktempdir()
    else
        mkpath(output_root)
    end
    path = joinpath(output_root, "n05_receipts.json")
    manifest_path = joinpath(output_root, "negative_control_manifest.json")
    isfile(manifest_path) && error("N05 negative-control manifest already exists")
    envelope = G.n05_export_receipt_envelope(package, e0, authored, absent, _n05e_specs(); output_path=path)
    @test isfile(path)
    println("N05_RECEIPT_PATH=", path)
    println("N05_RECEIPT_SHA256=", bytes2hex(SHA.sha256(read(path))))
    @test G.n05_check_receipt_envelope(envelope, package, e0, authored, absent, _n05e_specs()).status == :source_bound_valid
    @test G.n05_check_receipt_file(path).status == :valid
    @test G.n05_check_receipt_file(path).authored_count == 5
    @test G.n05_check_receipt_file(path).absent_count == 5
    @test G.n05_check_receipt_file(path, package, e0, authored, absent,
        _n05e_specs()).status == :source_bound_valid
    file_envelope = JSON3.read(read(path, String))
    file_named = _n05e_named(file_envelope)
    @test envelope.claims.compile_calls == 0
    @test envelope.claims.provider_calls == 0
    @test envelope.claims.solver_calls == 0
    authored_bad_row = merge(file_named.authored_receipts[1], (source_locator=merge(
        file_named.authored_receipts[1].source_locator, (source_hash=repeat("0", 64),)),))
    authored_bad = _n05e_roundtrip(merge(file_named, (authored_receipts=(authored_bad_row,
        file_named.authored_receipts[2], file_named.authored_receipts[3],
        file_named.authored_receipts[4], file_named.authored_receipts[5]),)))
    absent_bad_row = merge(file_named.absent_authority_receipts[1],
        (mutation_hash=repeat("0", 64),))
    absent_bad = _n05e_roundtrip(merge(file_named, (absent_authority_receipts=(absent_bad_row,
        file_named.absent_authority_receipts[2], file_named.absent_authority_receipts[3],
        file_named.absent_authority_receipts[4], file_named.absent_authority_receipts[5]),)))
    negative_dir = joinpath(output_root, "forged_negative_controls")
    mkpath(negative_dir)
    authored_bad_path = _n05e_write_forged(negative_dir, "authored_source_hash", authored_bad)
    absent_bad_path = _n05e_write_forged(negative_dir, "absent_mutation_hash", absent_bad)
    authored_bad_error = _n05e_expect_file_rejection(authored_bad_path, package, e0, authored, absent,
        _n05e_specs(), "N05 authored receipt differs from actual source recomputation")
    absent_bad_error = _n05e_expect_file_rejection(absent_bad_path, package, e0, authored, absent,
        _n05e_specs(), "N05 mutation hash mismatch")
    fake_candidate = _n05e_roundtrip(merge(file_named,
        (candidate_ref=merge(file_named.candidate_ref, (id="fusionconceptai://candidate/forged",)),)))
    fake_package = _n05e_roundtrip(merge(file_named, (package_hash=repeat("f", 64),)))
    fake_e0 = _n05e_roundtrip(merge(file_named,
        (e0=merge(file_named.e0, (binding_hash=repeat("e", 64),)),)))
    fake_declaration = _n05e_roundtrip(merge(file_named,
        (declaration=merge(file_named.declaration, (authored_hash=repeat("d", 64),)),)))
    missing_authored = _n05e_roundtrip(merge(file_named,
        (authored_receipts=Tuple(file_named.authored_receipts[i] for i in 2:5),)))
    fake_candidate_path = _n05e_write_forged(negative_dir, "candidate_ref", fake_candidate)
    fake_package_path = _n05e_write_forged(negative_dir, "package_hash", fake_package)
    fake_e0_path = _n05e_write_forged(negative_dir, "e0_binding_hash", fake_e0)
    fake_declaration_path = _n05e_write_forged(negative_dir, "declaration_hash", fake_declaration)
    missing_authored_path = _n05e_write_forged(negative_dir, "missing_authored", missing_authored)
    fake_candidate_error = _n05e_expect_file_rejection(fake_candidate_path, package, e0, authored, absent,
        _n05e_specs(), "N05 receipt candidate ref mismatch")
    fake_package_error = _n05e_expect_file_rejection(fake_package_path, package, e0, authored, absent,
        _n05e_specs(), "N05 receipt package hash mismatch")
    fake_e0_error = _n05e_expect_file_rejection(fake_e0_path, package, e0, authored, absent,
        _n05e_specs(), "N05 receipt E0 binding hash mismatch")
    fake_declaration_error = _n05e_expect_file_rejection(fake_declaration_path, package, e0, authored, absent,
        _n05e_specs(), "N05 receipt declaration hash mismatch")
    missing_authored_error = _n05e_expect_file_rejection(missing_authored_path, package, e0, authored, absent,
        _n05e_specs(), "N05 authored receipt count is not five")
    negative_records = (
        _n05e_file_record(authored_bad_path, "source_hash",
            "authored_receipts[0].source_locator.source_hash",
            "N05 authored receipt differs from actual source recomputation", authored_bad_error),
        _n05e_file_record(absent_bad_path, "absent_mutation_hash",
            "absent_authority_receipts[0].mutation_hash",
            "N05 mutation hash mismatch", absent_bad_error),
        _n05e_file_record(fake_candidate_path, "candidate_ref", "candidate_ref.id",
            "N05 receipt candidate ref mismatch", fake_candidate_error),
        _n05e_file_record(fake_package_path, "package_hash", "package_hash",
            "N05 receipt package hash mismatch", fake_package_error),
        _n05e_file_record(fake_e0_path, "e0_binding_hash", "e0.binding_hash",
            "N05 receipt E0 binding hash mismatch", fake_e0_error),
        _n05e_file_record(fake_declaration_path, "declaration_hash",
            "declaration.authored_hash", "N05 receipt declaration hash mismatch",
            fake_declaration_error),
        _n05e_file_record(missing_authored_path, "missing_authored_row",
            "authored_receipts[1:5]", "N05 authored receipt count is not five",
            missing_authored_error))
    manifest = (schema_version="UP2-00E1-N05-negative-control-manifest-v1",
        positive_envelope=(path=abspath(path), bytes=filesize(path),
            sha256=bytes2hex(SHA.sha256(read(path)))),
        negative_controls=negative_records,
        claims=(compile_calls=0, provider_calls=0, solver_calls=0,
            B00=false, B04=false, provider=false, mesh=false, physical=false))
    open(manifest_path, "w") do io
        JSON3.write(io, manifest)
    end
    println("N05_NEGATIVE_CONTROL_MANIFEST=", manifest_path)
    println("N05_NEGATIVE_CONTROL_MANIFEST_SHA256=",
        bytes2hex(SHA.sha256(read(manifest_path))))
    @test_throws ArgumentError G.n05_export_receipt_envelope(package, e0, authored, absent,
        _n05e_specs(); output_path=path)
end
