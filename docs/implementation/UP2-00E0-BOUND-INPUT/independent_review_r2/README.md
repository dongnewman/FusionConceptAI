# UP2-00E0 r8 precheck

Record status: r8_precheck_changes_requested; no_julia.

This directory preserves a static precheck performed against the taxonomy-fix r8-era bytes. It is not an R2 pass and must not be used as acceptance evidence. The precheck found that the public source-package join overload up2e0_validate_binding(binding, package) appends a program_exception from up2e0_check_package(package) but ends with a generic status=:fail_closed. That conflates the execution taxonomy at the public join boundary.

The r8 author receipt remains in the parent taxonomy_fix archive. A repaired r9 snapshot must be frozen into a fresh independent_review_r3 directory and independently run after the source-join status propagation is fixed. No Julia or DESC was executed here. No B00, B04, provider, mesh, engineering, physical, or R01-R10 credit is granted.
