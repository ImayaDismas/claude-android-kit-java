# Code Review

Review the code provided against the full checklist in `workflows/code_review.md`.
Work through every section in order — do not skip sections because nothing looks wrong.

---

## What to Review

The code provided (diff, file, or selection above this prompt).

---

## How to Report Findings

Use the structure from `templates/pr_template.md`.

Separate findings into two tiers:

**Blocking** — must be resolved before this can merge:
- Architecture violations (wrong layer, business logic in ViewModel or UI, direct DB/API access from ViewModel)
- Missing or incorrect error handling (silent failures, raw exception messages in UI)
- Security issues (logged tokens, unencrypted sensitive data, unvalidated external input)
- Threading violations (network or disk I/O on the main thread, `setValue()` from background thread)
- Broken or missing tests for critical paths
- Destructive migrations or schema changes without an explicit migration
- `binding = null` missing in Fragment `onDestroyView()`
- `observe(this, ...)` in Fragment instead of `observe(getViewLifecycleOwner(), ...)`

**Non-blocking** — should be addressed but does not block merge:
- Java style improvements (unnecessary null checks, missing `@NonNull`/`@Nullable`, `notifyDataSetChanged()` instead of `submitList()`)
- Missing edge case tests
- Naming that does not follow `givenX_whenY_thenZ` convention
- Minor readability improvements
- `public MutableLiveData` field (should be private with public `LiveData` accessor)

For each finding, state: which section of the checklist it fails, what the violation is, and the specific fix.

---

## What This Review Is Not

Do not suggest new features or refactors unrelated to the code under review.
Do not approve code that has any blocking finding — state clearly that it cannot merge until resolved.
