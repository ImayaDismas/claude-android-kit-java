# SOLID Principles — Android Java Application

Each principle is mapped to a concrete rule in the project architecture. Violations of these principles are also violations of the architecture standard.

---

## S — Single Responsibility

One class, one reason to change.

**In this project:**
- `UseCase` — one class per operation. `GetDailySummaryUseCase` handles exactly one thing.
- `ViewModel` — holds UI state and calls UseCases. It does not fetch data, apply business rules, or format strings.
- `Repository` — mediates between remote and local data sources. It does not apply business rules or format data for the UI.
- `Fragment` / `Activity` — renders state. It does not compute state or make decisions.

**Violation to watch for:** A ViewModel that also calls DAOs or ApiServices directly. A Repository that also applies business rules. A Fragment that formats or filters data.

```java
// ❌ ViewModel doing three jobs
public class LedgerViewModel extends ViewModel {
    public void load() {
        List<Transaction> data = dao.getAll();                  // wrong — data access
        long total = 0;
        for (Transaction t : data) total += t.amount;          // wrong — business logic
        _uiState.postValue(new UiState.Success("KES " + total)); // wrong — formatting
    }
}

// ✅ Each class has one job
@HiltViewModel
public class LedgerViewModel extends ViewModel {

    private final GetDailySummaryUseCase getSummary;
    private final AppExecutors executors;

    @Inject
    public LedgerViewModel(GetDailySummaryUseCase getSummary, AppExecutors executors) {
        this.getSummary = getSummary;
        this.executors = executors;
    }

    public void load(String date) {
        executors.diskIO().execute(() -> {
            Result<DailySummary> result = getSummary.execute(date);
            _uiState.postValue(result.isSuccess()
                ? new LedgerUiState.Success(result.getData())
                : new LedgerUiState.Error("Failed to load summary."));
        });
    }
}
```

---

## O — Open/Closed

Open for extension, closed for modification.

**In this project:**
- Add new features by creating new UseCases — do not modify existing ones.
- Add a new mobile money provider by adding a new parser implementation — do not modify the reconciliation engine.
- Add a new storage backend by creating a new `DataSource` implementation — do not modify the Repository.

**In practice:** New behaviour is added through new classes and new Hilt bindings, not by editing existing classes.

```java
// ✅ Extension via new class — existing ReconciliationUseCase untouched
public class ParseAirtelMoneyUseCase {

    private final SmsParser parser;

    @Inject
    public ParseAirtelMoneyUseCase(SmsParser parser) {
        this.parser = parser;
    }

    public Result<Transaction> execute(String sms) {
        return parser.parse(sms, Provider.AIRTEL);
    }
}
```

---

## L — Liskov Substitution

Any implementation of an interface must be substitutable without breaking callers.

**In this project:**
- Every `RepositoryImpl` must fully honour the contract of its `Repository` interface.
- A `FakeLedgerRepository` used in tests must behave like the real one — same return types, same error semantics.
- A `RemoteDataSource` and `LocalDataSource` implementing the same interface must return the same data shape.

**Violation to watch for:** A `RepositoryImpl` that throws exceptions not declared by the interface contract, or returns `null` where the interface promises a non-null result.

```java
// ❌ Impl violates the interface contract
public interface LedgerRepository {
    Result<List<Transaction>> getTransactions(String date);
}

public class LedgerRepositoryImpl implements LedgerRepository {
    @Override
    public Result<List<Transaction>> getTransactions(String date) {
        throw new RuntimeException("not implemented"); // violates contract — must return Result
    }
}

// ✅ Impl honours the contract completely
public class LedgerRepositoryImpl implements LedgerRepository {
    @Override
    public Result<List<Transaction>> getTransactions(String date) {
        try {
            List<TransactionEntity> entities = localSource.getByDate(date);
            return Result.success(mapToDomain(entities));
        } catch (Exception e) {
            return Result.error(new AppException.LocalException(e.getMessage()));
        }
    }
}
```

---

## I — Interface Segregation

Prefer small, focused interfaces over large, general ones.

**In this project:**
- `LedgerRepository` defines only ledger operations — not credit, not reconciliation.
- `CreditRepository` is separate from `LedgerRepository` even if both touch the same database.
- DAOs are per-entity — `TransactionDao`, `CreditDao`, `ReconciliationDao` — not one giant `AppDao`.

**Violation to watch for:** A Repository interface with 10+ methods spanning multiple features. A DAO with methods for unrelated entities.

```java
// ❌ Fat interface — violates ISP
public interface AppRepository {
    LiveData<List<Transaction>> getTransactions();
    LiveData<List<Credit>> getCredit();
    Result<Match> reconcile(String sms);
    Result<File> exportCsv();
}

// ✅ Segregated by feature
public interface LedgerRepository    { LiveData<Result<List<Transaction>>> getTransactions(String date); }
public interface CreditRepository    { LiveData<Result<List<Credit>>> getCredit(); }
public interface ReconciliationRepository { Result<Match> reconcile(String sms); }
```

---

## D — Dependency Inversion

Depend on abstractions, not on concrete implementations.

**In this project:**
- UseCases depend on `Repository` interfaces — never on `RepositoryImpl`.
- Modules use `@Binds` to wire interfaces to implementations — the implementation is unknown to the caller.
- All Hilt-injected dependencies are constructor-injected as interfaces.

**Violation to watch for:** A UseCase or ViewModel that imports a concrete class from the `data/` layer. Any `@Inject` that references an `Impl` class.

```java
// ❌ UseCase depends on concrete implementation
public class GetSummaryUseCase {
    @Inject
    public GetSummaryUseCase(LedgerRepositoryImpl repo) { // wrong — concrete class
        this.repo = repo;
    }
}

// ✅ UseCase depends on the interface — Hilt provides the impl
public class GetSummaryUseCase {
    @Inject
    public GetSummaryUseCase(LedgerRepository repo) { // correct — interface from domain/
        this.repo = repo;
    }
}

// ✅ Hilt wires the concrete class behind the scenes (in RepositoryModule.java)
@Binds
@Singleton
public abstract LedgerRepository bindLedgerRepository(LedgerRepositoryImpl impl);
```
