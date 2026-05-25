# Bug Fixing Workflow

Follow these steps in order. Never fix a bug without first reproducing it in a test.

---

## 1. Reproduce the bug

- Write a failing test that captures the exact broken behaviour before touching any code.
- If you cannot write a test that fails, you do not have a reproducible bug — investigate further.
- Name the test: `givenCondition_whenAction_thenWrongOutcome` so it describes the failure clearly.

---

## 2. Locate the layer

Identify which layer owns the bug. Check in this order:

| Symptom | Likely layer |
|---------|-------------|
| Wrong data displayed | ViewModel — check UiState mapping |
| Data never arrives | UseCase or Repository — check Result handling |
| Network call fails silently | DataSource (remote) — check ApiService or interceptor |
| Stale data shown after write | Repository — check Room is the source of truth; network response must write to Room before UI observes |
| UI does not update after data change | Fragment — check `observe(getViewLifecycleOwner(), ...)` vs `observe(this, ...)`; check `postValue()` vs `setValue()` threading |
| Crash on rotation | ViewModel — check state is not tied to Activity lifecycle; no `Context` or `View` references held |
| `IllegalStateException: Cannot call setValue on a background thread` | ViewModel — replace `setValue()` with `postValue()` from background thread |
| Background work not executing | AppExecutors — check work is dispatched via `diskIO()` or `networkIO()`, not called on main thread |
| Token not sent on requests | OkHttp `AuthInterceptor` — check interceptor, not the Retrofit call site |
| Hilt injection failing | DI — check `@InstallIn`, missing `@Provides`/`@Binds`, missing `@AndroidEntryPoint`, or missing `@HiltViewModel` |
| Room crash on startup | Database — check for missing migration, schema version mismatch, or missing `@TypeConverter` |
| RecyclerView not updating | Adapter — check `ListAdapter.submitList()` is called with a **new list instance**, not the same reference mutated in place |
| Memory leak in Fragment | Fragment — check `binding = null` is in `onDestroyView()`; check `observe(this, ...)` vs `observe(getViewLifecycleOwner(), ...)` |
| DAO write crashes on main thread | DataSource — DAO writes must be `void` and called from `AppExecutors.diskIO()`, never from the main thread |

Fix the bug at the correct layer. Do not patch the UI to hide a domain or data bug.

---

## 3. Fix

- Keep the fix minimal — do not refactor surrounding code unless explicitly asked.
- Do not change unrelated behaviour to make the test pass.
- If the fix requires changes in more than one layer, explain why before proceeding.

---

## 4. Verify

- The failing test from step 1 must now pass.
- Run the full test suite — no new failures introduced:

```bash
./gradlew test
```

- Run lint to confirm no new warnings:

```bash
./gradlew lint
```

---

## 5. Commit

Use the format in `templates/commit_message.txt`.
Subject type for bug fixes: `fix(<scope>): <what was wrong, present tense>`
No `Co-Authored-By` line. The sole author is YOUR_NAME.

Example: `fix(reconciliation): prevent duplicate entries on repeated SMS import`

---

## 6. Update tasks/active.md

- If the bug was a tracked task, move it to Completed with the test name as the outcome note.
- If the bug was a blocker on another task, update that task's Blocked entry.
