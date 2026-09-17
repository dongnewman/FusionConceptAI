# Engineering/control/fault obligations V4 report

Added isolated typed contracts and adversarial focused checks. They require external `ForwardChainContextV4` validation and owned graph lookup, map each obligation to a typed capability/evidence class, and retain missing capability as a recoverable gap. No evidence, promotion, terminal unsupported classification, or credible-device count is produced.

The fixture intentionally demonstrates that the existing startup context cannot be silently reused for a control-fault scenario with a different scenario identity; this fails closed. The runner and focused test use separate exit markers. No aggregator or rejected prototype was modified.
