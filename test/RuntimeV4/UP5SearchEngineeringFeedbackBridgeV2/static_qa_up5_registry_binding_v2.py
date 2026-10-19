from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/RuntimeV4/UP5SearchEngineeringFeedbackBridgeV2.jl"
TEST = ROOT / "test/RuntimeV4/UP5SearchEngineeringFeedbackBridgeV2/up5_search_engineering_feedback_bridge_v2_tests.jl"


def check(condition, label):
    if not condition:
        raise AssertionError(label)


source = SOURCE.read_text(encoding="utf-8")
test = TEST.read_text(encoding="utf-8")

check('"UP5-SEARCH-ENGINEERING-FEEDBACK-BRIDGE-V2-R1"' in source,
      "V2 revision is explicit")
check("entry.registry_hash == context.registry_hash" in source,
      "queue/context registry hashes are compared")
check("context.registry_hash == canonical_hash(context.registry)" in source,
      "context registry digest is independently recomputed")
check("SearchEngineeringRegistryBindingV2" in source and
      "binding_hash::Digest256" in source,
      "typed digest-bound registry proof exists")
check("canonical_hash(feedback)" in source and
      "feedback_hash=canonical_hash(feedback)" in source,
      "V2 output binds the typed V1 feedback digest")
check(":queue_registry_context_mismatch" in source and
      "_up5_sefb_finish_v1(queue, entry_ref, :deferred" in source,
      "registry mismatch returns through typed deferred path")

route_start = source.index("function route_search_engineering_feedback_v2!")
route = source[route_start:]
preflight_at = route.index("_up5_sefb_v2_active_preflight")
mismatch_at = route.index("if binding.status === :mismatch")
exact_delegate_at = route.rindex("feedback = route_search_engineering_feedback!(queue, entry_ref,")
check(preflight_at < mismatch_at < exact_delegate_at,
      "registry gate precedes V1 consumer call")
check("_up5_sefb_finish_v1(queue, entry_ref, :deferred" in route[mismatch_at:exact_delegate_at] and
      "route_search_engineering_feedback!(" not in route[mismatch_at:exact_delegate_at],
      "mismatch does not invoke the consumer")

check("FusionRuntimeV4.jl" in source,
      "source documents that production loader integration is intentionally absent")
check("include(" not in source,
      "isolated V2 file does not edit or load shared runtime entrypoints")
check('include(joinpath(REPO, "src", "RuntimeV4", "UP5SearchEngineeringFeedbackBridgeV1.jl"))' not in source,
      "V2 does not load or rewrite V1")

check("U.enqueue_candidate!(" in test and "U.next_compilable!(" in test,
      "tests use public queue eligibility API")
check("@test U.next_compilable!(matching_queue) === nothing" in test and
      "@test U.next_compilable!(mismatch_queue) === nothing" in test,
      "test fixtures remain deferred and are never forced active")
check(re.search(r"queue\.entries\[[^\n]+\]\s*=", test) is None and
      re.search(r"mismatch_queue\.entries\[[^\n]+\]\s*=", test) is None,
      "tests do not mutate internal queue state directly")
check("SearchEngineeringRegistryBindingV2" not in test,
      "test exercises public typed binding operation")
check("same-prefix-foreign-candidate" in test and
      "@test_throws ArgumentError" in test,
      "same-prefix candidate-identity drift is rejected")
check("foreign_registry_hash" in test and ":exact" in test and ":mismatch" in test,
      "matching and foreign registry metadata are covered")

print("UP5_V2_STATIC_QA=PASS")
print("CHECKS=17")
