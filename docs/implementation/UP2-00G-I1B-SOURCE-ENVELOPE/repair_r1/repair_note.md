# G-I1B-A narrow repair R1

Status remains `review_pending`; `accepted=false`; no Julia/DESC process was
started.  This repair is limited to the files owned by
`UP2-00G-I1B-SOURCE-ENVELOPE`.

The inherited draft had five source-bound defects.  Layer symbols were lower
case while the authority dispatch expected `:G1/:G2/:G3`, which could bind G2
and G3 rows to the G1 outer ref.  Semantic selectors for the matched G1
operator, selected G1 state, selected G3 effort port/entry/closure/link,
selected boundary patch, and interface-ref tuple were not resolved from the
actual A objects.  G2 region/interface aliases therefore returned typed
absence despite actual source fields.  N06 returned absence before reading
the uniquely selected local G3 value, losing typed identity while E2 was
deferred.  N05 source ownership used a generic G3 ref, and N05-05 did not use
the R2 endpoint-unit provenance source ref/hash.  Finally, row authority-gap
text was conflated with runtime source gaps and all resolved rows were made
deferred by construction.

The repair keeps the 50-row matrix and adds source-derived accessors for those
semantic selectors.  N06 retains a uniquely selected actual G3 typed value
when available, while its missing dimensioned E2 authority remains
`terminal_deferred`.  N05 present rows bind to the declaration endpoint/law
refs and hashes; N05-05 binds to
`declaration.right_endpoint.unit.source.source_ref` and its
`source_hash`, matching source-matrix R2.  N10 rows bind to the appropriate
outer or candidate ref.  Local mutation classification is selected from the
registered mutation semantics and actual authority state; fixture labels are
not read by production code.  The row's frozen authority-gap description is
kept separately from an observed runtime source gap.

No package, E0, loader, G-I1A, N01-N10 source, old archive, or core file was
modified by this repair.
