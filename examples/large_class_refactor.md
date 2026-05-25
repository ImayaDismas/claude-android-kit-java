# Example: Refactoring a Large Class (Java)

This example shows how to split a bloated ViewModel that has accumulated business logic and data access — a common pattern as features grow. Apply the same approach to any class that has grown beyond its layer's responsibility.

---

## The Problem

`LedgerViewModel` has grown to handle data fetching, business calculations, error parsing, and UI state — all in one class. This violates the single responsibility principle and makes it untestable in isolation.

---

## Before: Bloated ViewModel

```java
// ui/viewmodel/LedgerViewModel.java — BEFORE
@HiltViewModel
public class LedgerViewModel extends ViewModel {

    private final LedgerDao ledgerDao;           // ❌ direct DB access from ViewModel
    private final LedgerApiService api;          // ❌ direct network access from ViewModel
    private final AppExecutors executors;

    public final MutableLiveData<UiState> uiState = new MutableLiveData<>(); // ❌ public mutable

    @Inject
    public LedgerViewModel(LedgerDao ledgerDao, LedgerApiService api, AppExecutors executors) {
        this.ledgerDao = ledgerDao;
        this.api = api;
        this.executors = executors;
    }

    public void loadDailySummary(String date) {
        executors.diskIO().execute(() -> {
            try {
                List<TransactionEntity> transactions = ledgerDao.getByDateSync(date); // ❌ sync DAO call
                List<TransactionDto> remote = api.fetchTransactions(date).execute().body(); // ❌ network in ViewModel
                List<Transaction> merged = new ArrayList<>(mapToDomain(transactions));
                merged.addAll(mapDtosToDomain(remote));

                // ❌ business logic in ViewModel
                long totalSales = 0, totalExpenses = 0;
                for (Transaction t : merged) {
                    if (t.getType().equals("SALE")) totalSales += t.getAmount();
                    else totalExpenses += t.getAmount();
                }
                long outstanding = ledgerDao.getOutstandingCreditSync(); // ❌ second DAO call

                DailySummary summary = new DailySummary(totalSales, totalExpenses, outstanding);
                uiState.postValue(new UiState.Success(summary));

            } catch (Exception e) {
                uiState.postValue(new UiState.Error(e.getMessage())); // ❌ raw exception to UI
            }
        });
    }
}
```

**Problems:**
- ViewModel directly holds DAO and ApiService — bypasses Repository entirely.
- Business logic (merging, filtering, summing) belongs in a UseCase.
- Two separate DAO calls should be one coordinated Repository operation.
- Raw exception message leaks to the UI — no domain-level error mapping.
- Impossible to unit test without spinning up Room and a mock HTTP server.

---

## After: Each Layer Owns its Responsibility

### Domain Layer

```java
// domain/model/DailySummary.java
public class DailySummary {
    public final long totalSales;
    public final long totalExpenses;
    public final long outstandingCredit;
    public final String date;

    public DailySummary(long totalSales, long totalExpenses, long outstandingCredit, String date) {
        this.totalSales = totalSales;
        this.totalExpenses = totalExpenses;
        this.outstandingCredit = outstandingCredit;
        this.date = date;
    }
}

// domain/repository/LedgerRepository.java
public interface LedgerRepository {
    LiveData<Result<DailySummary>> getDailySummary(String date);
}

// domain/usecase/GetDailySummaryUseCase.java
public class GetDailySummaryUseCase {

    private final LedgerRepository repository;

    @Inject
    public GetDailySummaryUseCase(LedgerRepository repository) {
        this.repository = repository;
    }

    public LiveData<Result<DailySummary>> execute(String date) {
        return repository.getDailySummary(date);
    }
}
```

### Data Layer

```java
// data/repository/LedgerRepositoryImpl.java
public class LedgerRepositoryImpl implements LedgerRepository {

    private final LedgerLocalDataSource localSource;
    private final LedgerRemoteDataSource remoteSource;
    private final AppExecutors executors;

    @Inject
    public LedgerRepositoryImpl(
            LedgerLocalDataSource localSource,
            LedgerRemoteDataSource remoteSource,
            AppExecutors executors) {
        this.localSource = localSource;
        this.remoteSource = remoteSource;
        this.executors = executors;
    }

    @Override
    public LiveData<Result<DailySummary>> getDailySummary(String date) {
        // Sync remote data into Room first, then emit from Room (offline-first)
        executors.networkIO().execute(() -> {
            try {
                List<TransactionDto> remote = remoteSource.fetchTransactions(date);
                executors.diskIO().execute(() ->
                    localSource.upsertAll(mapToEntities(remote)));
            } catch (AppException.NetworkUnavailable e) {
                // Network unavailable — serve cached data; no error surfaced to UI
            } catch (AppException e) {
                // Log non-fatal; Room still serves cached data
            }
        });

        return Transformations.map(
            localSource.getDailySummary(date),
            summaryEntity -> summaryEntity != null
                ? Result.success(summaryEntity.toDomain())
                : Result.error(new AppException.NotFound())
        );
    }
}
```

### ViewModel — Now Just Coordinates State

```java
// ui/viewmodel/LedgerViewModel.java — AFTER
@HiltViewModel
public class LedgerViewModel extends ViewModel {

    private final GetDailySummaryUseCase getDailySummary;

    private final MutableLiveData<LedgerUiState> _uiState =
        new MutableLiveData<>(new LedgerUiState.Loading());
    public final LiveData<LedgerUiState> uiState = _uiState;

    @Inject
    public LedgerViewModel(GetDailySummaryUseCase getDailySummary) {
        this.getDailySummary = getDailySummary;
    }

    public void loadSummary(String date) {
        _uiState.setValue(new LedgerUiState.Loading());

        // Observe the UseCase's LiveData and map to UiState
        LiveData<Result<DailySummary>> source = getDailySummary.execute(date);
        // Use MediatorLiveData to observe and transform
        // (In practice, inject and observe once in Fragment or use Transformations)
    }
}
```

---

## What Changed and Why

| Before | After | Reason |
|--------|-------|--------|
| ViewModel held DAO + ApiService | ViewModel holds UseCase only | Enforces layer boundary — ViewModel never touches data sources |
| Business logic in ViewModel | Logic in UseCase | UseCase is the only testable, reusable place for business logic |
| Two raw DAO calls | Repository coordinates one LiveData | Repository is the single data access point; Room is source of truth |
| Raw exception to UI | Domain error mapped to user message | No implementation detail leaks to the presentation layer |
| Untestable without infrastructure | ViewModel testable with a fake UseCase | Fake `LedgerRepository` replaces all data access in tests |
| `public MutableLiveData` | `private MutableLiveData` + `public LiveData` | UI cannot corrupt ViewModel state |

---

## Test Pattern After Refactor

```java
// Unit test — no Room, no network, no Hilt
public class LedgerViewModelTest {

    @Rule
    public InstantTaskExecutorRule instantTaskRule = new InstantTaskExecutorRule();

    private FakeLedgerRepository fakeRepository;
    private GetDailySummaryUseCase useCase;
    private LedgerViewModel viewModel;

    @Before
    public void setUp() {
        fakeRepository = new FakeLedgerRepository();
        useCase = new GetDailySummaryUseCase(fakeRepository);
        viewModel = new LedgerViewModel(useCase);
    }

    @Test
    public void givenValidDate_whenLoadingSummary_thenEmitsSuccessState() {
        fakeRepository.setSummary("2024-01-15", testSummary);

        List<LedgerUiState> states = new ArrayList<>();
        viewModel.uiState.observeForever(states::add);

        viewModel.loadSummary("2024-01-15");

        assertTrue(states.get(states.size() - 1) instanceof LedgerUiState.Success);
        assertEquals(testSummary,
            ((LedgerUiState.Success) states.get(states.size() - 1)).summary);
    }

    @Test
    public void givenNetworkError_whenLoadingSummary_thenEmitsErrorState() {
        fakeRepository.setError(new AppException.NetworkUnavailable());

        List<LedgerUiState> states = new ArrayList<>();
        viewModel.uiState.observeForever(states::add);

        viewModel.loadSummary("2024-01-15");

        assertTrue(states.get(states.size() - 1) instanceof LedgerUiState.Error);
    }
}
```

---

## Apply the Same Pattern When You See

- A ViewModel with more than one constructor dependency that is not a UseCase.
- A Repository that makes decisions about what data to show (that is a UseCase's job).
- A UseCase that calls multiple other UseCases — split into a coordinator or flatten.
- Any class longer than ~150 lines — it is almost always doing two jobs.
- A ViewModel with a `public MutableLiveData` field — always make the backing field private.
