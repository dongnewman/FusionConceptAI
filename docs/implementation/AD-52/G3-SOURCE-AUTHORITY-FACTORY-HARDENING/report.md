# AD-52 implementation report: G3 source-authority factory hardening

Implementation package status: `completed_review_pending`; `accepted=false`.
Independent review and root acceptance remain pending. This package does not
claim `accepted_limited`, source authority, trusted identity, candidate/final
identity, provider, mesh, engineering, physical, search, or R01-R10 credit.

The owned factory now closes repository-root identity, exact HEAD, stage-zero
tracked index entry, HEAD tree path, 40-hex blob, `show`/`cat-file` bytes,
working-tree bytes, SHA-256/length, porcelain cleanliness, and assume-unchanged
or skip-worktree flags. Absent or untracked current-repository locators become
typed absence. Four positive scopes use a real temporary HEAD-tracked fixture;
all trusted/candidate/final flags remain false.

See `raw/` for replay receipts, output/error streams, hashes, baseline/final
inventories, cleanup inventory, and preserved failure history.

