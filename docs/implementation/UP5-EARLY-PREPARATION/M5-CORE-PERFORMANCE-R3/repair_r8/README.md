# M5 core performance R3 repair R8

R8 is a single deterministic canonical-writer repair.  The query-result
writer now supplies the `conditional_equality_query_result` domain tag to
`_ceg_wrap`, matching the existing canonical contract and historical writer.
No other product or test semantics were changed.

The focused test now parses the query receipt with JSON3, checks the exact
top-level `kind` and `domain`, and checks repeat-call determinism plus the
canonical hash relation.  A static scan found zero remaining cache-free
`invoke(_ceg_wrap, Tuple{String,String}, invoke(...))` shapes under
`src/Canonical`.

Julia/DESC is not run in this lane.  Status remains
`screen_only / performance implementation pending runtime`; factorial root
cause remains unresolved.
