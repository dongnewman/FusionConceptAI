"""Offline integration seam for the UP1 external-closure R4 modules.

The integration package is deliberately additive and observation-only.  It
does not start a T0/S3 lane, contact a channel, run Julia/DESC, or turn a
local receipt into authority.
"""

from .orchestrator import (
    STAGE_ORDER,
    BindingTuple,
    OfflineIntegrationOrchestrator,
    integrate,
    merge_stage_results,
    orchestrate,
)

__all__ = [
    "STAGE_ORDER",
    "BindingTuple",
    "OfflineIntegrationOrchestrator",
    "integrate",
    "merge_stage_results",
    "orchestrate",
]
