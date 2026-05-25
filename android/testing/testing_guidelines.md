# Testing Guidelines

Test business logic, not framework code. The test pyramid for this project is: unit tests (majority) → integration tests (selected) → instrumented UI tests (minimal).

---

## What to Test and Where

| Layer | What to test | Test type |
|---|---|---|
| `UseCase` | Business rules, edge cases, error paths | Unit test with Mockito fakes |
| `ViewModel` | State transitions, all `UiState` branches, LiveData emissions | Unit test with `InstantTaskExecutorRule` + fake UseCase |
| `Repository` | Data mapping, offline-first logic, error propagation | Unit test with fake DataSources |
| `DataSource (local)` | DAO queries, migrations | Integration test with in-memory Room |
| `DataSource (remote)` | Retrofit mapping, error codes | Unit test with MockWebServer |
| UI (Fragment/Activity) | Critical user journeys only | Instrumented test with Espresso |

---

## Tools

| Tool | Use for |
|---|---|
| **JUnit 4** | All unit tests — `@Test`, `@Before`, `@After`, `@Rule` |
| **Mockito** | Mocking Java interfaces at layer boundaries |
| **InstantTaskExecutorRule** | Synchronous LiveData observation in unit tests |
| **Robolectric** | Android component tests without a device |
| **In-memory Room** | Database layer tests — `Room.inMemoryDatabaseBuilder(...)` |
| **MockWebServer** | Testing Retrofit/OkHttp responses and error codes |
| **Hilt Testing** | `@HiltAndroidTest` + `@UninstallModules` for instrumented integration tests |
| **Espresso** | UI interaction tests for critical flows |

**MockK** is Kotlin-only. All Java tests use Mockito.
`AsyncTask` is removed from the SDK — do not write tests against it.

---

## Fakes vs Mocks — When to Use Each

| Situation | Use | Reason |
|---|---|---|
| Testing ViewModel with a Repository | Fake Repository | Full interface implementation; can control return values |
| Testing UseCase with a Repository | Fake Repository | Allows testing error states and edge cases |
| Testing Repository with DataSources | Fake DataSources | Controls what each source returns independently |
| Testing at a layer boundary | Mock (Mockito) | Simple return value verification |
| Testing Room DAOs | In-memory Room | Never mock Room — you must test the actual SQL |

**Rule:** Never mock the Room database. Use `Room.inMemoryDatabaseBuilder()` for all DAO tests.

---

## Naming

All tests follow `givenX_whenY_thenZ`:

```java
@Test
public void givenValidDate_whenLoadingSummary_thenEmitsSuccessState() { ... }

@Test
public void givenNetworkUnavailable_whenSyncing_thenStillEmitsCachedData() { ... }

@Test
public void givenExpiredToken_whenFetchingTransactions_thenRefreshesAndRetries() { ... }

@Test
public void givenZeroAmount_whenRecordingCredit_thenReturnsValidationError() { ... }
```

---

## ViewModel Test Pattern

```java
public class LedgerViewModelTest {

    // ✅ Required — makes LiveData work synchronously in tests
    @Rule
    public InstantTaskExecutorRule instantTaskRule = new InstantTaskExecutorRule();

    private FakeGetDailySummaryUseCase fakeUseCase;
    private LedgerViewModel viewModel;

    @Before
    public void setUp() {
        fakeUseCase = new FakeGetDailySummaryUseCase();
        viewModel = new LedgerViewModel(fakeUseCase, new TestAppExecutors());
    }

    @Test
    public void givenValidDate_whenLoadingSummary_thenEmitsLoadingThenSuccess() {
        fakeUseCase.setResult(Result.success(testSummary));

        List<LedgerUiState> states = new ArrayList<>();
        viewModel.uiState.observeForever(states::add);

        viewModel.loadSummary("2024-01-15");

        assertEquals(2, states.size());
        assertTrue(states.get(0) instanceof LedgerUiState.Loading);
        assertTrue(states.get(1) instanceof LedgerUiState.Success);
        assertEquals(testSummary, ((LedgerUiState.Success) states.get(1)).summary);
    }

    @Test
    public void givenUseCaseFailure_whenLoadingSummary_thenEmitsError() {
        fakeUseCase.setResult(Result.error(new AppException.NetworkUnavailable()));

        List<LedgerUiState> states = new ArrayList<>();
        viewModel.uiState.observeForever(states::add);

        viewModel.loadSummary("2024-01-15");

        assertTrue(states.get(states.size() - 1) instanceof LedgerUiState.Error);
    }
}
```

**Rules:**
- Always use `InstantTaskExecutorRule` — makes `LiveData` post values synchronously.
- Use `observeForever()` in tests (not `observe()` with a LifecycleOwner).
- Use `TestAppExecutors` that runs work synchronously on the calling thread.
- Never test against the ViewModel's internal `MutableLiveData` — only the public `LiveData`.

---

## TestAppExecutors Pattern

```java
// test/TestAppExecutors.java
public class TestAppExecutors extends AppExecutors {

    private final Executor immediate = Runnable::run; // ✅ Runs synchronously

    public TestAppExecutors() {
        super(Runnable::run, Runnable::run, Runnable::run);
    }
}
```

---

## Repository Test Pattern

```java
public class LedgerRepositoryImplTest {

    @Rule
    public InstantTaskExecutorRule instantTaskRule = new InstantTaskExecutorRule();

    private FakeLedgerLocalDataSource fakeLocal;
    private FakeLedgerRemoteDataSource fakeRemote;
    private LedgerRepositoryImpl repository;

    @Before
    public void setUp() {
        fakeLocal = new FakeLedgerLocalDataSource();
        fakeRemote = new FakeLedgerRemoteDataSource();
        repository = new LedgerRepositoryImpl(fakeLocal, fakeRemote, new TestAppExecutors());
    }

    @Test
    public void givenNetworkUnavailable_whenObserving_thenStillEmitsCachedData() {
        fakeLocal.seed("2024-01-15", Collections.singletonList(cachedTransaction));
        fakeRemote.throwOnFetch(new IOException("no network"));

        List<Result<List<Transaction>>> results = new ArrayList<>();
        repository.getTransactions("2024-01-15").observeForever(results::add);

        assertFalse(results.isEmpty());
        assertTrue(results.get(0).isSuccess());
        assertEquals(Collections.singletonList(cachedTransaction.toDomain()),
                     results.get(0).getData());
    }
}
```

---

## DAO Test Pattern (In-Memory Room)

```java
@RunWith(RobolectricTestRunner.class)
public class TransactionDaoTest {

    private AppDatabase database;
    private TransactionDao dao;

    @Before
    public void setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase.class
        ).allowMainThreadQueries().build(); // allowMainThreadQueries for tests only
        dao = database.transactionDao();
    }

    @After
    public void tearDown() {
        database.close();
    }

    @Test
    public void givenInsertedTransaction_whenQuerying_thenReturnsIt() {
        TransactionEntity entity = buildTransactionEntity("tx-1");
        dao.upsertAll(Collections.singletonList(entity));

        List<TransactionEntity> results =
            LiveDataTestUtil.getOrAwaitValue(dao.getByDate("2024-01-15"));

        assertEquals(1, results.size());
        assertEquals("tx-1", results.get(0).id);
    }
}
```

---

## Coverage Targets

| Layer | Target | Rationale |
|---|---|---|
| `UseCase` | ≥ 90% | All business logic lives here — highest priority |
| `ViewModel` | ≥ 80% | State transitions are the contract with the UI |
| `Repository` | ≥ 80% | Offline-first logic is critical and subtle |
| `DataSource` | ≥ 60% | Covered partially by integration tests |
| UI (Fragment/Activity) | No target | Test only critical journeys; avoid testing framework code |

---

## What NOT to Test

- Getters, setters, and plain constructors — trivial and change-proof.
- Framework classes (`Activity`, `Fragment`, `Application`) — test through integration tests, not unit tests.
- Hilt module bindings — correct bindings are verified when the app starts without crashing.
- XML layout details (pixel-level layout, exact colors) — test behaviour, not appearance.
