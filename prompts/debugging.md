# Debug This Issue

Follow `workflows/bug_fixing.md` exactly. Do not suggest a fix before completing steps 1 and 2.

---

## Step 1 — Reproduce First, Fix Second

Write a failing test that captures the broken behaviour before touching any production code.
Name it: `givenCondition_whenAction_thenWrongOutcome`

If you cannot write a failing test, state why and what additional information is needed before proceeding.

---

## Step 2 — Identify the Layer

Use the diagnosis table in `workflows/bug_fixing.md` to identify which layer owns the bug.
State the layer and your reasoning before proposing any fix.

Common Android Java failure patterns to check:
- `LiveData` not updating the UI → check `observe(getViewLifecycleOwner(), ...)` vs `observe(this, ...)` in Fragment; check `postValue()` vs `setValue()` threading
- Stale data after a write → check whether Room is the source of truth or a network response is bypassing it
- Background work not executing → check whether it is dispatched through `AppExecutors` and not called on main thread
- Token not sent on requests → check the OkHttp `AuthInterceptor`, not the call site
- Hilt injection failing → check `@InstallIn`, missing `@Provides`/`@Binds`, or a missing `@AndroidEntryPoint`
- Room crash → check for a missing migration, a DAO write method called on the main thread, or a missing `@TypeConverter`
- RecyclerView not updating → check `ListAdapter.submitList()` is being called with a new list instance (not the same reference)
- Memory leak in Fragment → check `binding = null` is in `onDestroyView()`; check `observe(this, ...)` vs `observe(getViewLifecycleOwner(), ...)`
- `IllegalStateException: Cannot call setValue on a background thread` → use `postValue()` from background threads

---

## Step 3 — Fix and Verify

Propose the minimal fix — no refactoring, no surrounding cleanup.
Explain why this fix is correct and safe at the identified layer.
Confirm the failing test from step 1 now passes, and no other tests regress.
