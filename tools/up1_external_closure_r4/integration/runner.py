"""Compatibility entry points for the UP1 R4 offline orchestrator."""

from .orchestrator import (
    STAGE_ORDER,
    BindingTuple,
    OfflineIntegrationOrchestrator,
    integrate,
    merge_stage_results,
    orchestrate,
)

SCHEMA_VERSION = "UP1.external-closure-r4.integration.v1"
STAGES = STAGE_ORDER


def run_pipeline(request=None, **kwargs):
    return orchestrate(request, **kwargs)


run = run_pipeline


class PipelineRunner:
    """Small object wrapper retained for callers of earlier UP1 runners."""

    version = SCHEMA_VERSION

    def __init__(self, **kwargs):
        self._orchestrator = OfflineIntegrationOrchestrator(**kwargs)

    def run(self, request=None):
        return self._orchestrator.run(request)


__all__ = [
    "SCHEMA_VERSION",
    "STAGES",
    "BindingTuple",
    "OfflineIntegrationOrchestrator",
    "PipelineRunner",
    "integrate",
    "merge_stage_results",
    "orchestrate",
    "run",
    "run_pipeline",
]
