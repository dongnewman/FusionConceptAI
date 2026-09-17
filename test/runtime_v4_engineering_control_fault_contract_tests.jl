using Test

module ECFTestModule
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "EngineeringControlFaultContracts.jl"))
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_declared_fixture.jl"))
end

const ECF = ECFTestModule.FusionRuntimeV4
const F = ECFTestModule.FusionConceptAI
const d = F.digest256_text
using .ECFTestModule: _fixture_mechanism, _fixture_field, _fixture_realization, registry, candidate

@testset "G4 engineering/control/fault contracts" begin
    load = ECF.EngineeringLoadV4("vessel", 10.0, 15.0; evidence_ref="eng-1")
    obs = ECF.ObservationDependencyV4("temperature", F.ObservationChannelRefV1("diag.temperature"); channel_hash=d("g3-observation"))
    act = ECF.ActuationDependencyV4("quench", F.OperatorSiteRefV1("coil.quench"); actuator_hash=d("g3-actuation"))
    fault = ECF.FaultScenarioV4("sensor-loss", "timeout", "safe", "reacquire";
        observation_names=("temperature",), actuation_names=("quench",), evidence_ref="fault-1")
    obligations = (ECF.EvidenceObligationV4("physical-test", :physical; status=:unknown),
        ECF.EvidenceObligationV4("engineering-test", :engineering; status=:pass, evidence_target=(d("e"),d("a"))))
    input = ECF.EngineeringControlFaultInputV4(candidate, registry; loads=(load,), observations=(obs,),
        actuations=(act,), faults=(fault,), obligations=obligations)
    @test ECF.engineering_margin(load) == 0.5
    @test ECF.canonical_hash(input) == input.input_hash
    decision = ECF.validate_engineering_control_fault(input)
    @test decision.status === :deferred
    @test decision.control_status === :pass
    @test !decision.physical_evidence_satisfied
    @test any(occursin("physical", x) for x in decision.unresolved)
    @test ECF.canonical_hash(decision) == decision.decision_hash
end

@testset "G4 preserves unsupported capabilities and load failure" begin
    bad = ECF.EngineeringControlFaultInputV4(candidate, registry;
        loads=(ECF.EngineeringLoadV4("overload", 3.0, 2.0),),
        observations=(ECF.ObservationDependencyV4("x", F.ObservationChannelRefV1("missing.obs")),))
    decision = ECF.validate_engineering_control_fault(bad)
    @test decision.status === :deferred
    @test decision.engineering_status === :fail
    @test decision.control_status === :unsupported
    @test !isempty(decision.unsupported)
    @test !isempty(decision.unresolved)
end
