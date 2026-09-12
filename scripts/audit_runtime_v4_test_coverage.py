#!/usr/bin/env python3
"""Static, deterministic RuntimeV4 entry-point and test-coverage inventory.

This intentionally does not execute Julia.  Includes are evidence of a load
edge only; they are not evidence that the loaded code ran or passed a test.
"""
from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
ROOT_NAMES = [
    "src/FusionConceptAI.jl",
    "src/RuntimeV4/FusionRuntimeV4.jl",
    "test/runtests.jl",
    "examples/runtime_v4_spatial_candidate.jl",
    "scripts/run_v4_spatial_chain.jl",
]


def rel(path: Path) -> str:
    return path.relative_to(REPO).as_posix()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=REPO, text=True).strip()


def literal_include(line: str) -> str | None:
    # Julia's simple include("path") and Base.include(mod, "path") forms.
    m = re.search(r"\b(?:Base\.)?include\s*\(\s*\"([^\"]+)\"\s*\)", line)
    return m.group(1) if m else None


def scan_file(path: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    edges: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not re.search(r"\b(?:Base\.)?include\s*\(", line):
            continue
        target = literal_include(line)
        if target is None:
            unresolved.append({"source": rel(path), "line": number,
                               "expression": line.strip(), "kind": "dynamic_or_unresolved"})
            continue
        # Literal includes are resolved relative to the including file, as Julia does.
        target_path = (path.parent / target).resolve()
        edges.append({"source": rel(path), "line": number, "target_literal": target,
                      "target": rel(target_path) if target_path.is_relative_to(REPO) else target_path.as_posix(),
                      "exists": target_path.is_file(), "kind": "literal_include"})
    return edges, unresolved


def classify(path: str) -> str:
    p = path.lower()
    if any(x in p for x in ("acceptance", "authority", "wholedevice")):
        return "final acceptance"
    if any(x in p for x in ("provider", "desc", "physical")):
        return "provider integration"
    if any(x in p for x in ("benchmark", "spatial", "multiregion", "science")):
        return "real scientific benchmark"
    return "fast contract/numerics"


def inventory() -> list[str]:
    paths: set[str] = set()
    for pattern in ("src/RuntimeV4/*.jl", "test/*runtime_v4*.jl", "test/*spatial*.jl",
                    "examples/*runtime_v4*.jl", "scripts/*v4*.jl"):
        paths.update(rel(p) for p in REPO.glob(pattern) if p.is_file())
    paths.update(ROOT_NAMES)
    return sorted(paths)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    tracked = set(filter(None, git("ls-files").splitlines()))
    status_lines = git("status", "--short").splitlines()
    dirty = bool(status_lines)
    status_by_path: dict[str, str] = {}
    for item in status_lines:
        raw = item[3:] if len(item) >= 3 else item
        status_by_path[raw.replace("\\", "/")] = "untracked" if item.startswith("??") else "modified"

    all_paths = inventory()
    nodes: dict[str, dict[str, Any]] = {}
    for name in all_paths:
        p = REPO / Path(name)
        nodes[name] = {"path": name, "exists": p.is_file(),
                       "tracked": name in tracked,
                       "working_tree_status": status_by_path.get(name, "clean" if name in tracked else "untracked"),
                       "tier": classify(name),
                       "kind": ("runtime_v4_module" if name.startswith("src/RuntimeV4/") else
                                "test" if name.startswith("test/") else
                                "example" if name.startswith("examples/") else
                                "runner" if name.startswith("scripts/") else "root")}

    edges: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    reachable: dict[str, set[str]] = {r: set() for r in ROOT_NAMES}
    for root in ROOT_NAMES:
        queue = [root]
        seen: set[str] = set()
        while queue:
            current = queue.pop(0)
            if current in seen:
                continue
            seen.add(current)
            p = REPO / Path(current)
            if not p.is_file():
                continue
            reachable[root].add(current)
            es, us = scan_file(p)
            edges.extend(es)
            unresolved.extend(us)
            for edge in es:
                target = edge["target"]
                if edge["exists"] and target in nodes:
                    queue.append(target)
        reachable[root] = set(sorted(reachable[root]))

    # Deduplicate repeated edges caused by roots converging on the same source.
    edges = sorted({json.dumps(e, sort_keys=True): e for e in edges}.values(),
                   key=lambda e: (e["source"], e["line"], e["target_literal"]))
    unresolved = sorted({json.dumps(e, sort_keys=True): e for e in unresolved}.values(),
                        key=lambda e: (e["source"], e["line"], e["expression"]))
    for name, node in nodes.items():
        node["reachable_from"] = [root for root in ROOT_NAMES if name in reachable[root]]

    payload = {
        "schema": "runtime_v4_test_coverage.v1",
        "source_commit": git("rev-parse", "HEAD"),
        "dirty_state_warning": dirty,
        "status_entries": sorted(status_lines),
        "roots": ROOT_NAMES,
        "nodes": [nodes[n] for n in sorted(nodes)],
        "include_edges": edges,
        "unresolved_or_dynamic_includes": unresolved,
        "reachability": {r: sorted(reachable[r]) for r in ROOT_NAMES},
        "coverage_boundary": {
            "package_assertions": "The package's 2631 assertions are not RuntimeV4 total coverage.",
            "include_parsing": "Parsed include edges inventory loading syntax only; it is not execution or test evidence.",
            "world_age_prone_path": [
                "scripts/run_v4_spatial_chain.jl includes examples/runtime_v4_spatial_candidate.jl",
                "the example loads the versioned src/RuntimeV4/SpatialRuntimeV4.jl aggregator",
                "the aggregator loads SpatialWholeDeviceV4 before candidate staged execution",
                "the former late WholeDevice Base.include is no longer present in the runner",
            ],
            "spatial_aggregator": {
                "path": "src/RuntimeV4/SpatialRuntimeV4.jl",
                "source_order": [
                    "SpatialExecutionTypesV4.jl", "SpatialMultiRegionV4.jl",
                    "SpatialPickupEngineeringV4.jl", "SpatialVerificationUQV4.jl",
                    "SpatialCandidateV4.jl", "SpatialWholeDeviceV4.jl"
                ],
            },
            "dynamic_predecessor_chain": "The parent candidate and computed Base.include expressions remain unresolved/dynamic inventory entries.",
        },
        "tier_definitions": {
            "fast contract/numerics": "package and lightweight RuntimeV4 contract/numerics checks",
            "provider integration": "provider/adaptor and external solver integration surfaces",
            "real scientific benchmark": "spatial or benchmark execution requiring scientific inputs",
            "final acceptance": "whole-device/authority/acceptance decisions; not implied by static reachability",
        },
    }
    # Internal consistency failures are errors; expected gaps are represented in the report.
    assert payload["source_commit"] and len(payload["source_commit"]) == 40
    assert len(set(payload["roots"])) == len(payload["roots"])
    assert all(n["path"] == n["path"].replace("\\", "/") for n in payload["nodes"])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
