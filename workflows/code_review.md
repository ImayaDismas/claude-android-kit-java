# Code Review Workflow

Work through each section in order. Flag every violation — do not silently skip minor ones.
Use the PR template in `templates/pr_template.md` to structure the review output.

---

## 1. Architecture Compliance

- [ ] Data flow is strictly UI → ViewModel → UseCase → Repository → DataSource — no layer skipped.
- [ ] Business logic lives only in `domain/usecase/` — none in ViewModel, UI, or data layer.
- [ ] ViewModel holds no repository or data source references.
- [ ] UI does not construct data — it only observes `LiveData`.
- [ ] `network/` is not a top-level package — OkHttp and Retrofit are in `di/module/NetworkModule`.
- [ ] No Jetpack Compose in new code — XML layouts required.

---

## 2. State Management

- [ ] A single abstract `UiState` class is used per screen: `Loading`, `Success`, `Error`.
- [ ] State is exposed as `LiveData`, not `MutableLiveData`.
- [ ] `MutableLiveData` backing field is private in the ViewModel.
- [ ] No hidden or mutable state exposed outside the ViewModel.
- [ ] All three `UiState` cases are handled in the Fragment/Activity.

---

## 3. Error Handling

- [ ] `Result<T>` wrapper used at the domain/data boundary — no raw exceptions propagated.
- [ ] Network errors, 4xx, and 5xx are each mapped to distinct domain-level errors.
- [ ] No bare `catch (Exception e)` blocks that swallow errors silently.
- [ ] Every `UiState.Error` carries a user-facing message — no raw exception messages shown.

---

## 4. Java Standards

- [ ] All new code is in Java — no Kotlin in new feature files.
- [ ] All network and disk I/O is dispatched via `AppExecutors` — no `new Thread()` or `AsyncTask`.
- [ ] `LiveData.postValue()` used from background threads; `setValue()` used only on main thread.
- [ ] `@NonNull` and `@Nullable` annotations on all public method signatures.
- [ ] No raw exception messages passed to UI.

---

## 5. Database

- [ ] All DAO reads return `LiveData<T>` — no synchronous main-thread DB access.
- [ ] All DAO writes are `void` and called from `AppExecutors.diskIO()` — not the main thread.
- [ ] Multi-step operations use `@Transaction`.
- [ ] No destructive migrations (`fallbackToDestructiveMigration` must not appear).
- [ ] New columns have a default value and an explicit migration path.
- [ ] Room is the source of truth — network responses write to Room before the UI reads them.

---

## 6. UI

- [ ] ViewBinding used — no `findViewById()`.
- [ ] `binding = null` in `onDestroyView()` in every Fragment.
- [ ] `observe(getViewLifecycleOwner(), ...)` used in Fragments — not `observe(this, ...)`.
- [ ] `ListAdapter.submitList()` used for RecyclerView — not `notifyDataSetChanged()`.
- [ ] `DiffUtil.ItemCallback` implemented correctly — `areItemsTheSame()` compares by stable ID.
- [ ] Navigation via Navigation Component SafeArgs — no manual `FragmentManager` transactions.
- [ ] All visible strings in `strings.xml` — no hardcoded text in XML or Java.

---

## 7. Dependency Injection

- [ ] All dependencies are injected via Hilt — no manual instantiation.
- [ ] `@Singleton` used only where a single instance is required (OkHttpClient, Retrofit, DB, AppExecutors).
- [ ] `@AndroidEntryPoint` on all Activities, Fragments, and Services that receive injection.
- [ ] No `@Inject` field injection except where constructor injection is impossible.

---

## 8. Security

- [ ] No secrets, tokens, or PII logged — not even in debug builds.
- [ ] Sensitive data stored with Keystore-backed AES/GCM encryption — never plaintext.
- [ ] No hardcoded API keys, base URLs with credentials, or passwords in source.
- [ ] External inputs validated before use.

---

## 9. Networking

- [ ] Auth token injected via OkHttp `AuthInterceptor` — not passed manually at call sites.
- [ ] Token refresh logic uses a `synchronized` lock — only one refresh in flight at a time.
- [ ] `HttpLoggingInterceptor` is debug-only — not included in release builds.
- [ ] Retrofit and OkHttpClient are `@Singleton` — not recreated per request.
- [ ] All `Call.execute()` calls are on a background thread — never on the main thread.

---

## 10. Testing

- [ ] Tests exist for UseCase, ViewModel, and Repository.
- [ ] Tests named in `givenX_whenY_thenZ` format.
- [ ] `InstantTaskExecutorRule` used in all tests with `LiveData`.
- [ ] No database mocked — use fakes or in-memory Room.
- [ ] Critical business logic has ≥ 80% coverage.
- [ ] `TestAppExecutors` (synchronous) used in ViewModel tests.

---

## Review Output

Summarise findings using `templates/pr_template.md`.
For each violation, state: layer affected, rule broken, and suggested fix.
Separate blocking issues (must fix before merge) from non-blocking suggestions.
