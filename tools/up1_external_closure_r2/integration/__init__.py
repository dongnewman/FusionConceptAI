"""Offline UP1 R2 integration slice.

This package is an orchestration boundary only.  It adapts the public JSON
interfaces of the component validators without changing their ownership or
granting any UP1/T0 credit.
"""

from .runner import SCHEMA_VERSION, run_pipeline, run, canonical_digest, receipt_preimage, receipt_digest, state_digest, IntegrationAdapter, PipelineRunner

__all__ = ["SCHEMA_VERSION", "run_pipeline", "run", "canonical_digest", "receipt_preimage", "receipt_digest", "state_digest", "IntegrationAdapter", "PipelineRunner"]
