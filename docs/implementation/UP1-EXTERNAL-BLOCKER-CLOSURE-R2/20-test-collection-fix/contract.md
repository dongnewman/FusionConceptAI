# UP1 R2 test collection fix contract

## Scope

This slice repairs only the Python test collection boundary for
`test/up1_external_closure_r2/**`. Production validators and their semantics
are out of scope and must remain byte-for-byte unchanged.

## Failure being repaired

The R2 full regression (`18-full-regression`) failed during collection because
pytest put `test/` on `sys.path`. The test package named
`up1_external_closure_r2` consequently shadowed the production package
`tools/up1_external_closure_r2`; the witness test's short import then raised
`ModuleNotFoundError: No module named 'up1_external_closure_r2.witness_authority.validator'`.

## Allowed change

The witness test imports the production validator through the unique repository
namespace `tools.up1_external_closure_r2.witness_authority.validator`. No
production file, fixture semantics, authority decision, or publish behavior is
changed. Existing failed raw evidence from slice 18 is copied under
`raw/prior_failure_*` and remains immutable evidence of the pre-fix boundary.

## Acceptance command

Run serially twice from the repository root, without `PYTHONPATH` or a special
pytest import mode:

```text
python -B -m pytest -q test/up1_external_closure_r2
```

Both runs must exit 0. Component isolation must also retain all prior pass and
skip outcomes. `-B` is required so this validation does not create Python
bytecode artifacts.

## Claim boundary

This is collection/test infrastructure evidence only. It grants no production
authority, publish, UP1, R01-R10, physical, or engineering readiness credit.
