using Test
using FusionConceptAI

const _IRV1_SOURCE = normpath(joinpath(@__DIR__, "../../src/RuntimeV4/InverseRealizationRequestContractV1.jl"))
@assert isfile(_IRV1_SOURCE)
include(_IRV1_SOURCE)

struct _IRV1BrokenString <: AbstractString end
Base.String(::_IRV1BrokenString) =
    throw(TypeError(:convert, String, _IRV1BrokenString))

function _irv1_fixture(; provider=true, return_port=true, target_quantity=:power,
        target_domain="electrical-hardware", source_domain="electrical-hardware",
        emf_policy=:required, derivative_orders=(1,), material_models=("steel-v1",),
        geometry_models=("coil-shell-v1",))
    power = InverseRealizationBoundV1(:power, :W, 1.0, 100.0)
    current = InverseRealizationBoundV1(:current, :A, 0.1, 20.0)
    voltage = InverseRealizationBoundV1(:voltage, :V, 1.0, 500.0)
    density = InverseRealizationBoundV1(:density, :kg_m3, 100.0, 9000.0)
    conductivity = InverseRealizationBoundV1(:conductivity, :S_m, 0.0, 1.0e8)
    extent = InverseRealizationBoundV1(:extent, :m, 0.001, 10.0)
    bounds = target_quantity === :power ? power : target_quantity === :current ? current : voltage
    target = InverseRealizationPortV1("target.power", :target, target_quantity,
        target_quantity === :power ? :W : target_quantity === :current ? :A : :V,
        :scalar, target_domain, bounds)
    source = InverseRealizationPortV1("source.voltage", :source, :voltage, :V,
        :scalar, source_domain, voltage)
    returned = return_port ? InverseRealizationPortV1("return.target", :return,
        target.quantity, target.unit, target.function_space, target.domain, target.bound) : nothing
    electrical = InverseRealizationElectricalV1(power=power, current=current,
        voltage=voltage, emf_policy=emf_policy)
    material = InverseRealizationMaterialV1("material.steel", "steel-v1", density, conductivity)
    geometry = InverseRealizationGeometryV1("geometry.coil", "coil-shell-v1",
        :geometry_map, target_domain, 3, extent)
    provider_domains = Tuple(sort!(unique((target_domain, source_domain))))
    capability = provider ? InverseRealizationProviderCapabilityV1("provider.local.contract";
        quantities=(:power, :voltage), units=(:W, :V), function_spaces=(:scalar, :geometry_map),
        domains=provider_domains, derivative_orders=derivative_orders,
        emf_policies=(emf_policy,), material_models=material_models,
        geometry_models=geometry_models) : nothing
    InverseRealizationRequestV1("inverse.request.001", "candidate.local.001", target,
        source, returned, electrical, material, geometry, capability)
end

@testset "UP4 inverse realization request contract-only v1" begin
    request = _irv1_fixture()
    result = validate_inverse_realization_request(request)
    @test result.valid
    @test result.status == :prepared
    @test result.claim_ceiling == :contract_only
    @test result.provider_calls == 0
    @test canonical_hash(request) == request.request_hash
    @test canonical_hash(result) == result.result_hash

    reordered = _irv1_fixture(derivative_orders=(1,), material_models=("steel-v1",),
        geometry_models=("coil-shell-v1",))
    @test canonical_hash(reordered) == canonical_hash(request)
    @test validate_inverse_realization_request(reordered).provider_calls == 0

    cross_domain = _irv1_fixture(target_domain="target-domain", source_domain="source-domain")
    @test cross_domain.provider !== nothing
    @test cross_domain.provider.domains == ("source-domain", "target-domain")
    cross_domain_result = validate_inverse_realization_request(cross_domain)
    @test cross_domain_result.status == :fail_closed
    @test "source_geometry_domain_mismatch" in cross_domain_result.reasons
    @test cross_domain_result.provider_calls == 0

    mismatch = _irv1_fixture()
    mismatch_target = InverseRealizationPortV1("target.current", :target, :current, :A,
        :scalar, "electrical-hardware", InverseRealizationBoundV1(:current, :A, 0.1, 20.0))
    mismatch_return = InverseRealizationPortV1("return.power", :return, :power, :W,
        :scalar, "electrical-hardware", InverseRealizationBoundV1(:power, :W, 1.0, 100.0))
    mismatch = InverseRealizationRequestV1(mismatch.request_ref, mismatch.candidate_ref,
        mismatch_target, mismatch.source, mismatch_return, mismatch.electrical,
        mismatch.material, mismatch.geometry, mismatch.provider)
    mismatch_result = validate_inverse_realization_request(mismatch)
    @test mismatch_result.status == :fail_closed
    @test !mismatch_result.valid
    @test "target_return_quantity_mismatch" in mismatch_result.reasons
    @test mismatch_result.provider_calls == 0

    @test validate_inverse_realization_request(_irv1_fixture(provider=false)).status == :terminal_deferred
    @test validate_inverse_realization_request(_irv1_fixture(return_port=false)).status == :terminal_deferred
    @test validate_inverse_realization_request(_irv1_fixture(derivative_orders=())).status == :terminal_deferred
    @test validate_inverse_realization_request(_irv1_fixture(material_models=())).status == :terminal_deferred
    @test validate_inverse_realization_request(_irv1_fixture(geometry_models=())).status == :terminal_deferred

    voltage_forbidden = _irv1_fixture(target_quantity=:voltage, emf_policy=:forbidden)
    voltage_forbidden_result = validate_inverse_realization_request(voltage_forbidden)
    @test voltage_forbidden_result.status == :fail_closed
    @test "voltage_requires_nonforbidden_emf_policy" in voltage_forbidden_result.reasons
    @test voltage_forbidden_result.provider_calls == 0

    @test_throws InverseExternalInputError InverseRealizationBoundV1(:power, :W, 2.0, 1.0)
    @test_throws InverseExternalInputError InverseRealizationBoundV1(:power, :W, NaN, 1.0)
    @test_throws InverseExternalInputError InverseRealizationPortV1("bad.unit", :source, :power, :V,
        :scalar, "electrical-hardware", InverseRealizationBoundV1(:power, :W, 1.0, 2.0))

    constructor_reject = admit_inverse_realization_request() do
        InverseRealizationBoundV1(:power, :V, 1.0, 2.0)
    end
    @test constructor_reject.status == :fail_closed
    @test !constructor_reject.valid
    @test constructor_reject.provider_calls == 0

    malformed_float = admit_inverse_realization_request() do
        InverseRealizationBoundV1(:power, :W, "not-a-float", 2.0)
    end
    @test malformed_float.status == :fail_closed
    @test !malformed_float.valid
    @test "constructor_fail_closed" in malformed_float.reasons
    @test malformed_float.provider_calls == 0

    malformed_method = admit_inverse_realization_request() do
        InverseRealizationBoundV1(:power, Ref(:W), 1.0, 2.0)
    end
    @test malformed_method.status == :fail_closed
    @test !malformed_method.valid

    malformed_dimension = admit_inverse_realization_request() do
        extent = InverseRealizationBoundV1(:extent, :m, 0.001, 10.0)
        InverseRealizationGeometryV1("geometry.bad-dimension", "coil-shell-v1",
            :geometry_map, "electrical-hardware", 3.5, extent)
    end
    @test malformed_dimension.status == :fail_closed
    @test !malformed_dimension.valid

    malformed_overflow = admit_inverse_realization_request() do
        InverseRealizationProviderCapabilityV1("provider.bad-overflow";
            derivative_orders=(big(typemax(Int)) + 1,))
    end
    @test malformed_overflow.status == :fail_closed
    @test !malformed_overflow.valid

    malformed_type = admit_inverse_realization_request() do
        _irv1_checked_conversion(_ -> throw(TypeError(:convert, Float64, :bad)),
            :bad, "typed external input")
    end
    @test malformed_type.status == :fail_closed
    @test !malformed_type.valid

    malformed_abstract_string = admit_inverse_realization_request() do
        _irv1_text(_IRV1BrokenString(), "broken external string")
    end
    @test malformed_abstract_string.status == :fail_closed
    @test !malformed_abstract_string.valid
    @test malformed_abstract_string.provider_calls == 0

    duplicate_provider_domains = admit_inverse_realization_request() do
        InverseRealizationProviderCapabilityV1("provider.duplicate-domains";
            quantities=(:power, :voltage), units=(:W, :V),
            function_spaces=(:scalar, :geometry_map),
            domains=("electrical-hardware", "electrical-hardware"),
            derivative_orders=(1,), emf_policies=(:required,),
            material_models=("steel-v1",), geometry_models=("coil-shell-v1",))
    end
    @test duplicate_provider_domains.status == :fail_closed
    @test !duplicate_provider_domains.valid
    @test any(occursin("duplicate provider domains", reason)
        for reason in duplicate_provider_domains.reasons)
    @test duplicate_provider_domains.provider_calls == 0

    same_message = "inverse external input [malformed_input]: bound unit conversion failed"
    @test_throws ArgumentError admit_inverse_realization_request() do
        throw(ArgumentError(same_message))
    end
    @test_throws MethodError admit_inverse_realization_request() do
        getindex(1, same_message)
    end
    @test_throws ErrorException admit_inverse_realization_request() do
        error(same_message)
    end

    @test_throws ErrorException admit_inverse_realization_request() do
        error("internal_program_defect")
    end
    @test_throws ArgumentError admit_inverse_realization_request() do
        throw(ArgumentError("internal_program_defect"))
    end

    for candidate in (_irv1_fixture(provider=false), _irv1_fixture(return_port=false),
            _irv1_fixture(derivative_orders=()))
        @test validate_inverse_realization_request(candidate).provider_calls == 0
    end
end
