# G-I1B source matrix R2 repair

- Reversed only the known R2 insertions to preserve exact R1 before bytes; verified the four known R1 SHA256 values.
- Corrected only N05-05 `component_or_content_hash` to `declaration.right_endpoint.unit.source.source_hash`.
- Regenerated `source_matrix.json`; compared all 50 rows and found only N05-05 changed.
- Production citations: `src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl:292-296,428-429`.
- No Julia/DESC command was run.
- Status remains `review_pending`, `accepted=false`; no formal B04, provider, mesh, engineering, physical or R credit.
