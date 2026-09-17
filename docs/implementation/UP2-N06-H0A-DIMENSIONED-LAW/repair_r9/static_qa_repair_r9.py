"""Static QA for the narrow H0-A test-helper repair; never invokes Julia/DESC."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TEST = ROOT / "test" / "GenomeV5" / "UP2" / "n06_dimensioned_law_tests.jl"
SOURCE = ROOT / "src" / "GenomeV5" / "UP2" / "N06DimensionedLedgerLawV1.jl"
FIXTURE = ROOT / "test" / "GenomeV5" / "UP2" / "n06_dimensioned_law_fixtures.json"


def main() -> int:
    text = TEST.read_text(encoding="utf-8")
    if "_h0a_digest(ch) = G.digest256_text(String(ch))" not in text:
        raise SystemExit("helper does not use canonical text digest")
    if "_h0a_digest(ch) = G.Digest256" in text:
        raise SystemExit("production Digest256 validation was bypassed in the test helper")
    if "Digest256(" in text or "repeat(" in text:
        raise SystemExit("test still constructs raw Digest256/repeated literals")
    for label in ("z", "foreign-schema", "foreign-canonical", "stale", "stale-g3"):
        if f'_h0a_digest("{label}")' not in text:
            raise SystemExit(f"expected source-derived label missing: {label}")
    if not SOURCE.exists() or not FIXTURE.exists():
        raise SystemExit("protected H0-A source or fixture is missing")
    print("static_qa=pass")
    print("julia_or_desc_executed=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
