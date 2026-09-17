# M5 Conditional EGraph R2 execution record

R2 produced no authoritative result. PID 110436 (START
`2026-09-16T21:47:00.5998202+08:00`) and PID 89744 were observed through
wrappers that failed to return a bound final exit/raw receipt. Both are
recorded as `wrapper_collection_failure/not_authoritative`; no exit is
inferred. The attempt records are preserved under `attempt1_collection_failure`
and `attempt2_wrapper_collection_failure`. R3 is a separate run id.
