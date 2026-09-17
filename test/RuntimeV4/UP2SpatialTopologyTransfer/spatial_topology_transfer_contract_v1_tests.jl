using Test

const STTC_ROOT = normpath(joinpath(@__DIR__, "../../.."))
const STTC_SOURCE = joinpath(STTC_ROOT, "src", "RuntimeV4", "SpatialTopologyTransferContractV1.jl")
const STTC_FIXTURE = joinpath(@__DIR__, "spatial_topology_transfer_contract_v1_fixture.json")
@assert isfile(STTC_SOURCE) "spatial topology transfer source is missing"
@assert isfile(STTC_FIXTURE) "spatial topology transfer fixture is missing"
include(STTC_SOURCE)

failure_codes(result) = Set(f.code for f in result.failures)

function rebuild_transfer(x::SpatialTopologyTransferV1;
                          candidate_ref=x.candidate_ref, space_ref=x.space_ref,
                          source=x.source, target=x.target, regions=x.regions,
                          interfaces=x.interfaces, accounts=x.accounts,
                          witness=x.witness, defects=x.defects,
                          diagnostics=x.diagnostics, constraint_refs=x.constraint_refs,
                          physical_event_refs=x.physical_event_refs,
                          external_closure_ref=x.external_closure_ref,
                          return_ref=x.return_ref, canonical_order=x.canonical_order,
                          schema=x.schema, revision=x.revision,
                          claim_ceiling=x.claim_ceiling, evidence_scope=x.evidence_scope)
    SpatialTopologyTransferV1(schema, revision, candidate_ref, space_ref, source, target,
        regions, interfaces, accounts, witness, defects, diagnostics, constraint_refs,
        physical_event_refs, external_closure_ref, return_ref, canonical_order,
        claim_ceiling, evidence_scope)
end

function assert_contract_only(result)
    @test result.claim_ceiling === :contract_only
    @test result.evidence_scope === :screen_only
    @test result.provider_calls == 0
    @test result.mesh_calls == 0
    @test result.solver_calls == 0
end

@testset "UP2 spatial topology/conservation transfer contract-only V1" begin
    fixture = read(STTC_FIXTURE, String)
    @test occursin("SpatialTopologyTransferContractV1", fixture)
    @test occursin("divB", fixture)
    @test occursin("external_closure", fixture)

    base = spatial_topology_transfer_v1()
    valid = validate_spatial_topology_transfer(base)
    @test valid.valid
    @test valid.status === :ready
    @test isempty(valid.failures)
    assert_contract_only(valid)

    @testset "identity, opposite sign, and canonical order" begin
        @test base.source.side === :source
        @test base.target.side === :target
        @test base.witness.source_topology_ref == base.source.topology_ref
        @test base.witness.target_topology_ref == base.target.topology_ref
        @test base.witness.effects[1].signed_value == -1.0
        @test base.witness.effects[2].signed_value == 1.0
        @test spatial_topology_transfer_canonical_json(base) ==
            spatial_topology_transfer_canonical_json(
                spatial_topology_transfer_v1(regions=reverse(base.regions),
                    interfaces=reverse(base.interfaces), accounts=reverse(base.accounts),
                    effects=reverse(base.witness.effects)))
        @test spatial_topology_transfer_canonical_hash(base) ==
            spatial_topology_transfer_canonical_hash(
                spatial_topology_transfer_v1(regions=reverse(base.regions),
                    interfaces=reverse(base.interfaces), accounts=reverse(base.accounts),
                    effects=reverse(base.witness.effects)))
        @test base.canonical_order == Tuple(sort(collect(base.canonical_order))) ||
            base.canonical_order[1:2] == ("source:" * base.source.topology_ref,
                                           "target:" * base.target.topology_ref)

        # Same transfer/account/orientation keys remain legal split effects;
        # signed value and full unit identity must make their canonical order
        # independent of caller permutation.
        tied_unit = _sttc_unit("tied", (1,0,0,0,0,0,0); scale=1.0)
        tied_effects = (
            SpatialAccountEffectV1("transfer:tied", "account:source-v1", -0.25, tied_unit, :minus),
            SpatialAccountEffectV1("transfer:tied", "account:source-v1", -0.75, tied_unit, :minus),
            SpatialAccountEffectV1("transfer:tied", "account:target-v1", 1.0, tied_unit, :plus))
        tied_a = spatial_topology_transfer_v1(accounts=(
            SpatialTypedAccountV1("account:source-v1", :region, "owner:source-v1",
                "region:source-v1", tied_unit, :minus),
            SpatialTypedAccountV1("account:target-v1", :region, "owner:target-v1",
                "region:target-v1", tied_unit, :plus)), effects=tied_effects)
        tied_b = spatial_topology_transfer_v1(accounts=tied_a.accounts,
            effects=reverse(tied_effects))
        @test validate_spatial_topology_transfer(tied_a).valid
        @test validate_spatial_topology_transfer(tied_b).valid
        @test spatial_topology_transfer_canonical_json(tied_a) ==
            spatial_topology_transfer_canonical_json(tied_b)
        @test spatial_topology_transfer_canonical_hash(tied_a) ==
            spatial_topology_transfer_canonical_hash(tied_b)
    end

    @testset "split and merge transfer witness" begin
        unit = _sttc_unit()
        source_a = SpatialTypedAccountV1("account:source-a", :region, "owner:source-v1",
            "region:source-v1", unit, :minus)
        source_b = SpatialTypedAccountV1("account:source-b", :region, "owner:source-v1",
            "region:source-v1", unit, :minus)
        target = SpatialTypedAccountV1("account:target", :region, "owner:target-v1",
            "region:target-v1", unit, :plus)
        split = spatial_topology_transfer_v1(accounts=(source_a, source_b, target),
            effects=(SpatialAccountEffectV1("transfer:split", "account:source-a", -0.25, unit, :minus),
                     SpatialAccountEffectV1("transfer:split", "account:source-b", -0.75, unit, :minus),
                     SpatialAccountEffectV1("transfer:split", "account:target", 1.0, unit, :plus)))
        result = validate_spatial_topology_transfer(split)
        @test result.valid
        @test isempty(result.failures)
        assert_contract_only(result)
    end

    @testset "compatible scales normalize; incompatible dimensions fail closed" begin
        metre = _sttc_unit("m", (1,0,0,0,0,0,0); scale=1.0)
        centimetre = _sttc_unit("cm", (1,0,0,0,0,0,0); scale=0.01)
        source_m = SpatialTypedAccountV1("account:source-m", :region, "owner:source-v1",
            "region:source-v1", metre, :minus)
        target_cm = SpatialTypedAccountV1("account:target-cm", :region, "owner:target-v1",
            "region:target-v1", centimetre, :plus)
        converted = spatial_topology_transfer_v1(accounts=(source_m, target_cm),
            effects=(SpatialAccountEffectV1("transfer:scaled", source_m.account_ref, -1.0, metre, :minus),
                     SpatialAccountEffectV1("transfer:scaled", target_cm.account_ref, 100.0, centimetre, :plus)))
        converted_result = validate_spatial_topology_transfer(converted)
        @test converted_result.valid
        @test isempty(converted_result.failures)
        assert_contract_only(converted_result)

        second = _sttc_unit("s", (0,0,1,0,0,0,0); scale=1.0)
        target_s = SpatialTypedAccountV1("account:target-s", :region, "owner:target-v1",
            "region:target-v1", second, :plus)
        incompatible = spatial_topology_transfer_v1(accounts=(source_m, target_s),
            effects=(SpatialAccountEffectV1("transfer:incompatible", source_m.account_ref, -1.0, metre, :minus),
                     SpatialAccountEffectV1("transfer:incompatible", target_s.account_ref, 1.0, second, :plus)))
        incompatible_result = validate_spatial_topology_transfer(incompatible)
        @test !incompatible_result.valid
        @test incompatible_result.status === :fail_closed
        @test :unit_mismatch in failure_codes(incompatible_result)
    end

    @testset "external closure is explicit" begin
        unit = _sttc_unit()
        source = first(base.accounts)
        external = SpatialTypedAccountV1("account:external", :external, "external",
            "external", unit, :plus)
        external_transfer = spatial_topology_transfer_v1(accounts=(source, external),
            effects=(SpatialAccountEffectV1("transfer:external", source.account_ref, -1.0, unit, :minus),
                     SpatialAccountEffectV1("transfer:external", external.account_ref, 1.0, unit, :plus)),
            external_closure_ref="external:boundary-closure-v1")
        result = validate_spatial_topology_transfer(external_transfer)
        @test result.valid
        @test result.status === :ready
        assert_contract_only(result)
        no_ref = rebuild_transfer(external_transfer; external_closure_ref="")
        @test validate_spatial_topology_transfer(no_ref).status === :fail_closed
        @test :external_closure_mismatch in failure_codes(validate_spatial_topology_transfer(no_ref))
    end

    @testset "identity, units, ownership, orientation, and finite diagnostics fail closed" begin
        foreign_candidate = rebuild_transfer(base; candidate_ref="candidate:foreign")
        @test :candidate_mismatch in failure_codes(validate_spatial_topology_transfer(foreign_candidate))

        foreign_space = rebuild_transfer(base; space_ref="space:foreign")
        @test :space_mismatch in failure_codes(validate_spatial_topology_transfer(foreign_space))

        bad_topology = SpatialTopologyIdentityV1(base.source.candidate_ref, base.source.space_ref,
            "", base.source.mesh_ref, base.source.basis_ref, base.source.quadrature_ref,
            base.source.dof_ref, base.source.order_ref, :source)
        @test :topology_identity_mismatch in failure_codes(
            validate_spatial_topology_transfer(rebuild_transfer(base; source=bad_topology)))

        wrong_unit = SpatialTransferUnitV1("m", (1,0,0,0,0,0,0), 1.0)
        effects_wrong_unit = (SpatialAccountEffectV1(base.witness.effects[1].transfer_ref,
            base.witness.effects[1].account_ref, -1.0, wrong_unit, :minus), base.witness.effects[2])
        bad_unit = rebuild_transfer(base; witness=SpatialTransferWitnessV1(
            base.source.topology_ref, base.target.topology_ref, effects_wrong_unit))
        @test :unit_mismatch in failure_codes(validate_spatial_topology_transfer(bad_unit))

        empty_effect_unit = SpatialTransferUnitV1("", (0,0,0,0,0,0,0), 1.0)
        bad_effect_unit = rebuild_transfer(base; witness=SpatialTransferWitnessV1(
            base.source.topology_ref, base.target.topology_ref,
            (SpatialAccountEffectV1(base.witness.effects[1].transfer_ref,
                base.witness.effects[1].account_ref, -1.0, empty_effect_unit, :minus),
             base.witness.effects[2])))
        @test :unit_mismatch in failure_codes(validate_spatial_topology_transfer(bad_effect_unit))

        bad_orientation = SpatialAccountEffectV1(base.witness.effects[1].transfer_ref,
            base.witness.effects[1].account_ref, -1.0, base.witness.effects[1].unit, :plus)
        bad_orientation_contract = rebuild_transfer(base; witness=SpatialTransferWitnessV1(
            base.source.topology_ref, base.target.topology_ref,
            (bad_orientation, base.witness.effects[2])))
        @test :orientation_mismatch in failure_codes(validate_spatial_topology_transfer(bad_orientation_contract))

        bad_owner_account = SpatialTypedAccountV1(base.accounts[1].account_ref, :region,
            "owner:foreign", base.accounts[1].region_ref, base.accounts[1].unit, :minus)
        bad_owner = rebuild_transfer(base; accounts=(bad_owner_account, base.accounts[2]))
        @test :owner_mismatch in failure_codes(validate_spatial_topology_transfer(bad_owner))

        interface_account = SpatialTypedAccountV1("account:interface", :interface,
            "owner:foreign", "interface:source-target-v1", base.accounts[1].unit, :minus)
        bad_interface_owner = rebuild_transfer(base;
            accounts=(base.accounts[1], base.accounts[2], interface_account))
        @test :owner_mismatch in failure_codes(validate_spatial_topology_transfer(bad_interface_owner))

        external = SpatialTypedAccountV1("account:external-owner", :external, "owner:foreign",
            "external", base.accounts[1].unit, :plus)
        external_owner_transfer = spatial_topology_transfer_v1(accounts=(base.accounts[1], external),
            effects=(SpatialAccountEffectV1("transfer:external-owner", base.accounts[1].account_ref,
                    -1.0, base.accounts[1].unit, :minus),
                SpatialAccountEffectV1("transfer:external-owner", external.account_ref,
                    1.0, external.unit, :plus)),
            external_closure_ref="external:owner-test")
        @test :owner_mismatch in failure_codes(validate_spatial_topology_transfer(external_owner_transfer))

        empty_interface = SpatialInterfaceIdentityV1("", "region:source-v1", "region:target-v1",
            "owner:interface-v1", :minus_to_plus)
        @test :interface_mismatch in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; interfaces=(empty_interface,))))

        wildcard_interface = SpatialInterfaceIdentityV1("interface:*", "region:source-v1",
            "region:target-v1", "owner:interface-v1", :minus_to_plus)
        @test :interface_mismatch in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; interfaces=(wildcard_interface,))))

        empty_account = SpatialTypedAccountV1("", :region, "owner:source-v1",
            "region:source-v1", base.accounts[1].unit, :minus)
        @test :account_mismatch in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; accounts=(empty_account, base.accounts[2]))))

        bad_defect = SpatialDefectV1(:local, "defect:local-v1", NaN, 0.0)
        bad_defects = (bad_defect, base.defects[2], base.defects[3], base.defects[4], base.defects[5], base.defects[6])
        @test :nonfinite in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; defects=bad_defects)))

        bad_diagnostic = SpatialDiagnosticV1(:divB, Inf, 0.0)
        bad_diagnostics = (bad_diagnostic, base.diagnostics[2], base.diagnostics[3], base.diagnostics[4])
        @test :nonfinite in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; diagnostics=bad_diagnostics)))
    end

    @testset "return, constraints, external, and physical-event misuse fail closed" begin
        @test :return_mismatch in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; return_ref="return:foreign")))
        @test :constraint_mismatch in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; constraint_refs=("physical:event",))))
        @test :physical_event_misuse in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; physical_event_refs=("event:topology-change",))))
        @test :external_closure_mismatch in failure_codes(validate_spatial_topology_transfer(
            rebuild_transfer(base; external_closure_ref="external:unused")))
    end

    @test !isdefined(Main, :CandidateStatePackageV5)
    @test !isdefined(Main, :FusionConceptAI)
end
