# Static receipts

Baseline checkout: `4b69f55f7f80240147a65a22809dc1207824dde2` on `main`.

The scoped paths were untracked before this slice and were created only for this
work order. Existing unrelated dirty files were left untouched. A process audit
returned no `julia` or `desc` processes.

Static command, run with an explicit interpreter:

```text
D:\Users\Newman\anaconda3\python.exe docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py
exit_code=0
```

The static checker parsed the fixture, recomputed the exact rational energy and
ledger residuals, checked candidate-owned refs and missing authority statuses, and
recorded content hashes. Julia focused tests are supplied but intentionally were not
run for this source-only preparation slice.

