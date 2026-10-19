# Manifest supersession note

`review_manifest_pre_provenance.json` SHA-256 `9e3bbe3d5f7475f61ccfee61086958830d4842101dde368c00806b5ce288889b` is retained as the first, interim manifest. It was generated before the exact V10 state-hash provenance and V20 supervisor-branch reconciliation were added. The report was expanded and two evidence-only reconciliation receipts were added afterward, so the interim manifest's report hash no longer matches the current report and the interim manifest is not the final integrity claim.

No V20 runtime raw file, saved input, owner source, or protocol was changed. The final `review_manifest.json` is regenerated over the complete evidence leaf, including this note and the preserved interim manifest. It is the manifest to use for final verification.
