# CI Workflow

This workflow defines what CI validates and how to triage and fix CI failures.
Claude in the `ci` environment runs this workflow — it does not write features or review code.

---

## What CI runs

```bash
./gradlew test     # all unit tests
./gradlew lint     # lint checks
./gradlew check    # test + lint + all verification tasks
```

CI does **not** run:
- `assembleRelease` or `bundleRelease` — no release builds in CI
- `publish` or `upload` — no artifact publishing
- Any command that requires signing config or release keystore

---

## Triage: classify the failure before fixing

When CI fails, identify the failure type first. Each type has a different fix path.

### Test failure

```
> Task :app:testDebugUnitTest FAILED
FAILURE: X tests failed
```

1. Read the full test name and failure message — do not guess from the task name alone.
2. Determine which layer the failure is in: UseCase / ViewModel / Repository / DataSource.
3. Check whether the failure is in new code or pre-existing code:
   - New code failure → fix the implementation or the test.
   - Pre-existing failure → the change regressed something; investigate before fixing.
4. Never delete or skip a failing test to make CI pass. Fix the underlying cause.

Common Java-specific test failures:

| Failure | Cause | Fix |
|---------|-------|-----|
| `java.lang.RuntimeException: Method observeForever in LiveData not mocked` | Missing `InstantTaskExecutorRule` | Add `@Rule public InstantTaskExecutorRule rule = new InstantTaskExecutorRule();` |
| NullPointerException in ViewModel test | `LiveData` not initialised before assertion | Call `viewModel.someMethod()` before `viewModel.uiState.getValue()` |
| Test hangs and times out | Background work dispatched to real `AppExecutors` | Use `TestAppExecutors` (synchronous) in all ViewModel and Repository tests |
| `WrongThread` crash on DAO write | DAO write called on the test thread without proper executor | Wrap in `TestAppExecutors.diskIO().execute(...)` or call through ViewModel |

---

### Lint violation

```
> Task :app:lint FAILED
Error: <rule> in <file>:<line>
```

Common violations and correct fixes:

| Violation | Wrong fix | Correct fix |
|-----------|-----------|-------------|
| `HardcodedText` | Add `tools:ignore` | Move string to `strings.xml` |
| `UnusedResource` | Add `tools:ignore` | Delete the unused resource |
| `MissingTranslation` | Add `tools:ignore` | Add the missing translation |
| `WrongConstant` | Cast to suppress | Use the correct constant type |
| `NewApi` | Add `@SuppressLint` | Add an API level check or use a compat library |
| `NotifyDataSetChanged` | Ignore | Replace with `ListAdapter.submitList()` |
| `SetTextI18n` | Ignore | Use `getString(R.string.foo, arg)` with a format string |

Do not suppress lint warnings with `@SuppressLint` or `tools:ignore` unless there is a documented reason in a comment on the same line.

---

### Build failure

```
> Task :app:compileDebugJavaWithJavac FAILED
error: cannot find symbol / incompatible types / ...
```

1. Read the compiler error exactly — do not paraphrase.
2. Check whether the error is in production code or test code.
3. Common Java causes:
   - Missing Hilt `@Inject` or `@Provides` binding.
   - Missing `@AndroidEntryPoint` on an Activity or Fragment that receives injection.
   - Missing Room migration (schema change without a migration file).
   - DAO method returns wrong type (must return `LiveData<T>` for reads, `void` for writes).
   - `@NonNull` / `@Nullable` mismatch caught at compile time by NullAway or similar.

---

### Flaky test

A test that passes locally but fails in CI, or fails intermittently:

1. Check for timing dependencies — tests that `Thread.sleep()` or assume a specific execution order.
2. Check for shared mutable state between tests — each test must set up and tear down its own state.
3. Check for real `AppExecutors` usage in tests — replace with `TestAppExecutors` (synchronous executor).
4. Check for missing `InstantTaskExecutorRule` — `LiveData` observation requires it in all non-Android tests.
5. Fix the test so it is deterministic. Do not mark it as `@Ignore` without a tracked issue.

---

## CI does not replace review

CI passing means:
- Tests pass
- Lint is clean
- The build compiles

CI passing does **not** mean:
- Architecture is correct
- The feature is complete
- The code is reviewable

A passing CI build should be followed by a code review using `workflows/code_review.md` before merge.

---

## After fixing a CI failure

1. Fix the root cause — not the symptom.
2. Run `./gradlew check` locally to confirm before pushing.
3. If the failure revealed a gap in test coverage, add a test for the uncovered case.
4. Update `tasks/active.md` if the CI failure was a blocker on a tracked task.
