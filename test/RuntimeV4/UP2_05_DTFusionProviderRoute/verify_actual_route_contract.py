"""Static contract checks for the exclusive UP2-05 D-T route test."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TEST = Path(__file__).with_name("dt_fusion_actual_provider_route_v1.jl")
PROVIDER = ROOT / "src" / "RuntimeV4" / "DTFusionReactivityV1.jl"
CONSUMER = ROOT / "src" / "RuntimeV4" / "SteadyPlanarThermalDiffusionConsumerV1.jl"


def main() -> None:
    test = TEST.read_text(encoding="utf-8")
    provider = PROVIDER.read_text(encoding="utf-8")
    consumer = CONSUMER.read_text(encoding="utf-8")
    for text, tokens, label in (
        (provider, ("match_provider(capability, manifests)",
                    "provider.executor(input)",
                    "dt_fusion_reactivity_manifest_v1()"), "provider"),
        (consumer, ("getfield(runtime, provider_function)",
                    "providers=providers",
                    "dt_thermal_required_provider_missing:no_match:",
                    "execute_steady_planar_thermal_diffusion_v1("), "consumer"),
        (test, ("thermal_slab_actual_source_fixture.jl",
                "runtime.match_provider(capability, (manifest,))",
                "consumer.execute_steady_planar_dt_screen_thermal_v1(args...)",
                "providers=()", "provider_result.provider_manifest_hash",
                "thermal_result.volume_source_W_m3",
                "result.thermal_result.integrated_source_W",
                "result.evidence_credit == 0"), "exclusive test"),
    ):
        missing = [token for token in tokens if token not in text]
        assert not missing, f"{label} route is missing required source tokens: {missing}"

    provider_call = consumer.index("getfield(runtime, provider_function)")
    thermal_solve = consumer.index("execute_steady_planar_thermal_diffusion_v1(", provider_call)
    missing_gate = consumer.index("dt_thermal_required_provider_missing:no_match:", provider_call)
    assert provider_call < missing_gate < thermal_solve, \
        "required-provider absence must be raised before the original FV solve"
    print("UP2_05_DTFUSION_ACTUAL_ROUTE_STATIC_QA=PASS")


if __name__ == "__main__":
    main()
