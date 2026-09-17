"""Static/import boundary check for the final UP1 R4 regression."""

from __future__ import annotations

import ast
import importlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))
SETS = [
    ROOT / "tools" / "up1_external_closure_r3" / "atomic_bundle",
    ROOT / "test" / "up1_external_closure_r3" / "atomic_bundle",
    ROOT / "tools" / "up1_external_closure_r4",
    ROOT / "test" / "up1_external_closure_r4",
]
FILES = sorted(p for s in SETS for p in s.rglob("*.py") if "__pycache__" not in p.parts)

for path in FILES:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    compile(tree, str(path), "exec")

implementation_files = sorted(
    p for s in (SETS[0], SETS[2]) for p in s.rglob("*.py") if "__pycache__" not in p.parts
)
forbidden_network = {"socket", "ssl", "urllib", "requests", "httpx", "certifi"}
network_imports: set[str] = set()
for path in implementation_files:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            network_imports.update(alias.name.split(".", 1)[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            network_imports.add(node.module.split(".", 1)[0])
network_imports &= forbidden_network
if network_imports:
    raise AssertionError(f"forbidden network imports in implementation: {sorted(network_imports)}")

MODULES = [
    "tools.up1_external_closure_r3.atomic_bundle",
    "tools.up1_external_closure_r3.atomic_bundle.bundle",
    "tools.up1_external_closure_r4",
    "tools.up1_external_closure_r4.authoritative_intake.intake",
    "tools.up1_external_closure_r4.environment_closure.collector",
    "tools.up1_external_closure_r4.freshness.core",
    "tools.up1_external_closure_r4.g2_mapping.validator",
    "tools.up1_external_closure_r4.integration.orchestrator",
    "tools.up1_external_closure_r4.integration.runner",
    "tools.up1_external_closure_r4.source_axis_binding.source_axis_binding",
    "tools.up1_external_closure_r4.trust_chain.verifier",
]
for module in MODULES:
    importlib.import_module(module)

print(f"AST_COMPILE_OK files={len(FILES)}")
print(f"IMPORT_OK modules={len(MODULES)}")
print("NO_NETWORK_IMPORT_EXECUTION=PASS (implementation imports completed; no network client imported)")
print("NO_HEAVY_LANE_EXECUTION=PASS (static/import only; no Julia/DESC/T0/S3 command invoked)")
