# N06 focused R8 failure

The single authorized frozen runner invocation ran from
`2026-09-14T05:27:19.355459Z` to `2026-09-14T05:28:23.388901Z`, with main PID
`37060`, observed Julia child PIDs `75116`, `17324`, and `77624`, and real
exit `1`. The source/test/fixture/runner input hashes matched the frozen
handoff. The first eight upstream test groups passed (`47/47`, `21/21`,
`57/57`, `59/59`, `8/8`, `49/49`, `35/35`, `23/23`).

The N06 group reached the actual-A projection test and stopped with `24
passed, 0 failed, 1 errored, 25 total`. The error is:

`ArgumentError: N06 mapping is structurally inconsistent: conversion_same_dimension_mismatch`

It was raised by `n06_mapping_from_a` at source line 593 while the positive
test constructed the actual mapping at test line 196. This is a new runtime
program/contract failure after the R8 destructuring repair; it is not a link
undefined error. Raw stdout/stderr and their hashes are retained in
`receipt.json`. No retry or source/test repair was performed. Postflight
Julia/DESC sweep was empty and protected dirty before/after hashes match.

This failure grants no B04/provider/mesh/engineering/physical/R01-R10 credit.
