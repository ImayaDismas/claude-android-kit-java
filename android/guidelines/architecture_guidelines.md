# Architecture Guidelines — Anti-Patterns and Decision Rationale

`architecture_standard.md` is the single source of truth for all architectural rules. This file supplements it with common anti-patterns, the rationale behind key decisions, and guidance for grey-area situations. It does not override the standard.

---

## UseCase — mandatory, not optional

UseCases are **mandatory** for all business logic. There is no "simple enough to skip the UseCase" threshold.

**Why:** Without a UseCase, business logic accumulates in the ViewModel or Repository over time. By the time the class is large enough to refactor, the coupling is deep. A UseCase that wraps a single repository call today is the correct place for the validation, transformation, and orchestration that will be added next week.

**What counts as business logic:**
- Any calculation, transformation, or aggregation on data (e.g., computing a daily total)
- Any rule applied before or after a data operation (e.g., "do not allow negative balances")
- Any coordination between two data sources (e.g., "if local data is stale, sync from remote first")
- Any conditional flow based on domain state (e.g., "if user is offline, return cached data")

**What does NOT belong in UseCase:**
- UI state mapping — that is the ViewModel's job
- Database queries — that is the Repository's job
- Network calls — that is the DataSource's job

---

## Repository — interface in domain, implementation in data

**Anti-pattern:**
```java
// ❌ Injecting the concrete class — breaks testability and violates DIP
public class GetSummaryUseCase {
    private final LedgerRepositoryImpl repo; // wrong — implementation, not interface

    @Inject
    public GetSummaryUseCase(LedgerRepositoryImpl repo) {
        this.repo = repo;
    }
}
```

**Correct:**
```java
// ✅ Inject the interface — implementation is wired by Hilt
public class GetSummaryUseCase {
    private final LedgerRepository repo; // correct — interface from domain/

    @Inject
    public GetSummaryUseCase(LedgerRepository repo) {
        this.repo = repo;
    }
}
```

**Why:** Injecting the interface allows the implementation to be swapped in tests without Hilt. A fake `LedgerRepository` can be used in unit tests; the real `LedgerRepositoryImpl` is only needed in integration or instrumented tests.

---

## ViewModel — state machine, not orchestrator

The ViewModel owns exactly one `LiveData<UiState>` per screen. It does not:
- Decide which data source to query (Repository does that)
- Apply business rules to the data (UseCase does that)
- Construct UI models from raw data (UseCase or a mapper does that)

**Anti-pattern:**
```java
// ❌ ViewModel making business decisions
public void loadSummary() {
    executors.diskIO().execute(() -> {
        List<Transaction> local = dao.getTransactions();       // ❌ direct DAO
        List<Transaction> remote = api.fetchTransactions();    // ❌ direct API
        List<Transaction> merged = new ArrayList<>(local);
        merged.addAll(remote);                                 // ❌ business logic in ViewModel
        long total = 0;
        for (Transaction t : merged) total += t.getAmount();
        _uiState.postValue(new UiState.Success(total));
    });
}
```

**Correct:** The ViewModel calls a single UseCase and maps the `Result` to `UiState`. Nothing else.

---

## Offline-first — UI never blocks on a network call

**Anti-pattern:**
```java
// ❌ Emitting network response directly — app breaks offline
public LiveData<List<Transaction>> observeTransactions() {
    MutableLiveData<List<Transaction>> result = new MutableLiveData<>();
    executors.networkIO().execute(() -> {
        List<Transaction> remote = api.fetchTransactions().execute().body(); // null if offline
        result.postValue(remote);
    });
    return result;
}
```

**Correct:** Always emit from Room. Sync from network opportunistically in the background. If network fails, Room still serves data. See `examples/offline_first_repository.md`.

---

## DI — no manual instantiation, ever

**Anti-pattern:**
```java
// ❌ Manual singleton — bypasses Hilt, untestable, thread-unsafe
public class NetworkClient {
    private static OkHttpClient instance;
    public static OkHttpClient getInstance() {
        if (instance == null) instance = new OkHttpClient.Builder().build();
        return instance;
    }
}

// ❌ Manual construction in a ViewModel
public class LedgerViewModel extends ViewModel {
    private final LedgerRepository repo = new LedgerRepositoryImpl(new LedgerDao()); // wrong
}
```

**Correct:** All objects are provided by Hilt. If a class cannot be constructor-injected, add a `@Provides` method in the appropriate module. See `examples/hilt_modules.md`.

---

## LiveData — correct observation lifecycle

**Anti-pattern:**
```java
// ❌ Observing with 'this' in a Fragment — leaks after view destruction
viewModel.uiState.observe(this, state -> { ... });

// ❌ Observing in onStart() without removing — adds duplicate observers
@Override
protected void onStart() {
    viewModel.uiState.observe(this, state -> { ... }); // adds another observer each time
}
```

**Correct:**
```java
// ✅ Observe in onViewCreated() with getViewLifecycleOwner() in Fragment
viewModel.uiState.observe(getViewLifecycleOwner(), state -> {
    // safe — auto-removed when Fragment view is destroyed
});

// ✅ Observe in onCreate() with 'this' in Activity
viewModel.uiState.observe(this, state -> {
    // safe — Activity is both LifecycleOwner and observer target
});
```

---

## RecyclerView — correct adapter pattern

**Anti-pattern:**
```java
// ❌ Replacing the whole list on update — causes full redraws and loses scroll position
adapter.setData(newList);
adapter.notifyDataSetChanged();
```

**Correct:**
```java
// ✅ ListAdapter with DiffUtil — only changed items are redrawn
public class TransactionAdapter extends ListAdapter<Transaction, TransactionAdapter.ViewHolder> {

    public TransactionAdapter() {
        super(new TransactionDiffCallback());
    }

    // submitList() handles diffing automatically
}

// In Fragment/Activity:
adapter.submitList(transactions);
```

---

## Grey Areas

**"Should this logic be in the UseCase or the Repository?"**

If it is a business rule (something a product manager or domain expert would describe), it belongs in the UseCase.
If it is a data-access rule (how and where data is stored or fetched), it belongs in the Repository.

Example: "Do not allow a credit entry where amount is zero" → UseCase.
Example: "If the remote fetch fails, return cached data" → Repository.

**"Should this be a new UseCase or can I add it to an existing one?"**

One UseCase, one operation. If you are adding a second public method, create a second UseCase. The `execute()` convention enforces this.

**"Should this be `@Singleton` or `@ViewModelScoped`?"**

Use `@ViewModelScoped` for UseCases — they hold no shared state and should be created fresh per ViewModel.
Use `@Singleton` only for objects that are expensive to create and safe to share: OkHttpClient, Retrofit, Room database, AppExecutors, top-level Repositories.
