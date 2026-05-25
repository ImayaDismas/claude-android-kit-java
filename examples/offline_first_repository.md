# Example: Offline-First Repository (Java)

This example shows the correct pattern for an offline-first Repository — Room is the single source of truth, network data is written to Room before the UI reads it. This is the central data pattern for APP_NAME.

---

## The Pattern in One Sentence

Emit from Room always. Sync from network opportunistically. Never emit raw network responses to the UI.

---

## Repository Interface (Domain Layer)

```java
// domain/repository/LedgerRepository.java
public interface LedgerRepository {
    LiveData<Result<List<Transaction>>> getTransactions(String date);
    void syncTransactions(String date, @Nullable SyncCallback callback);
}
```

The interface lives in `domain/` — it knows nothing about Room or Retrofit.

---

## RepositoryImpl (Data Layer)

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
    public LiveData<Result<List<Transaction>>> getTransactions(String date) {
        // ✅ Trigger a background sync when this is first called
        syncTransactions(date, null);

        // ✅ Always emit from Room — UI gets cached data immediately
        return Transformations.map(
            localSource.getTransactionsByDate(date),
            entities -> {
                List<Transaction> domain = new ArrayList<>();
                for (TransactionEntity e : entities) domain.add(e.toDomain());
                return Result.success(domain);
            }
        );
    }

    @Override
    public void syncTransactions(String date, @Nullable SyncCallback callback) {
        executors.networkIO().execute(() -> {
            try {
                List<TransactionDto> remote = remoteSource.fetchTransactions(date);
                List<TransactionEntity> entities = new ArrayList<>();
                for (TransactionDto dto : remote) entities.add(TransactionEntity.fromDto(dto));

                executors.diskIO().execute(() -> {
                    localSource.upsertAll(entities); // ✅ Room update triggers LiveData emission
                    if (callback != null) callback.onSuccess();
                });

            } catch (AppException.NetworkUnavailable e) {
                // ✅ Network failure is not fatal — Room still serves cached data
                if (callback != null) callback.onError(e);
            } catch (AppException e) {
                if (callback != null) callback.onError(e);
            }
        });
    }

    public interface SyncCallback {
        void onSuccess();
        void onError(AppException error);
    }
}
```

---

## What NOT to Do

```java
// ❌ Emitting network response directly — bypasses Room, breaks offline mode
@Override
public LiveData<Result<List<Transaction>>> getTransactions(String date) {
    MutableLiveData<Result<List<Transaction>>> result = new MutableLiveData<>();
    executors.networkIO().execute(() -> {
        try {
            List<TransactionDto> remote = remoteSource.fetchTransactions(date);
            result.postValue(Result.success(mapToDomain(remote))); // UI never gets cached data
        } catch (AppException e) {
            result.postValue(Result.error(e));
        }
    });
    return result;
}

// ❌ Returning network data and Room data as two separate LiveData sources — UI flickers
@Override
public LiveData<Result<List<Transaction>>> getTransactions(String date) {
    MediatorLiveData<Result<List<Transaction>>> merged = new MediatorLiveData<>();
    merged.addSource(localSource.getTransactionsByDate(date), entities ->
        merged.setValue(Result.success(mapToDomain(entities))));
    merged.addSource(fetchFromNetwork(date), remote ->
        merged.setValue(remote)); // overwrites Room emission — inconsistent state
    return merged;
}
```

---

## Local Data Source

```java
// data/datasource/local/LedgerLocalDataSource.java
public class LedgerLocalDataSource {

    private final TransactionDao dao;

    @Inject
    public LedgerLocalDataSource(TransactionDao dao) {
        this.dao = dao;
    }

    // ✅ LiveData from Room — auto-updates when the table changes
    public LiveData<List<TransactionEntity>> getTransactionsByDate(String date) {
        return dao.getByDate(date);
    }

    // ✅ Called from diskIO() executor — never on main thread
    public void upsertAll(List<TransactionEntity> entities) {
        dao.upsertAll(entities);
    }
}

// data/datasource/local/TransactionDao.java
@Dao
public interface TransactionDao {
    @Query("SELECT * FROM transactions WHERE date = :date ORDER BY created_at DESC")
    LiveData<List<TransactionEntity>> getByDate(String date); // ✅ LiveData, not void

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void upsertAll(List<TransactionEntity> entities); // ✅ void for write — called on background thread
}
```

---

## Remote Data Source

```java
// data/datasource/remote/LedgerRemoteDataSource.java
public class LedgerRemoteDataSource {

    private final LedgerApiService api;

    @Inject
    public LedgerRemoteDataSource(LedgerApiService api) {
        this.api = api;
    }

    // ✅ Called from networkIO() executor — blocking execute() is safe here
    public List<TransactionDto> fetchTransactions(String date) throws AppException {
        try {
            Response<List<TransactionDto>> response = api.getTransactions(date).execute();
            if (!response.isSuccessful() || response.body() == null) {
                throw new AppException.ServerException(response.code(), "Fetch failed");
            }
            return response.body();
        } catch (IOException e) {
            throw new AppException.NetworkUnavailable();
        }
    }
}

// data/datasource/remote/LedgerApiService.java
public interface LedgerApiService {
    @GET("transactions")
    Call<List<TransactionDto>> getTransactions(@Query("date") String date);
}
```

---

## Sync State Tracking (for WorkManager Background Sync)

```java
// data/model/TransactionEntity.java
@Entity(tableName = "transactions")
public class TransactionEntity {
    @PrimaryKey @NonNull public String id;
    public long amount;
    public String date;
    @NonNull public String syncState = SyncState.PENDING.name(); // ✅ Track sync from day one
    public long updatedAt;
}

public enum SyncState { PENDING, SYNCED, FAILED }
```

---

## Testing

```java
public class LedgerRepositoryImplTest {

    @Rule
    public InstantTaskExecutorRule instantTaskRule = new InstantTaskExecutorRule();

    private FakeLedgerLocalDataSource fakeLocalSource;
    private FakeLedgerRemoteDataSource fakeRemoteSource;
    private LedgerRepositoryImpl repository;

    @Before
    public void setUp() {
        fakeLocalSource = new FakeLedgerLocalDataSource();
        fakeRemoteSource = new FakeLedgerRemoteDataSource();
        repository = new LedgerRepositoryImpl(
            fakeLocalSource, fakeRemoteSource, new TestAppExecutors());
    }

    @Test
    public void givenCachedData_whenNetworkUnavailable_thenStillEmitsCachedData() {
        fakeLocalSource.seed("2024-01-15", Collections.singletonList(cachedTransaction));
        fakeRemoteSource.throwOnFetch(new AppException.NetworkUnavailable());

        List<Result<List<Transaction>>> results = new ArrayList<>();
        repository.getTransactions("2024-01-15").observeForever(results::add);

        assertFalse(results.isEmpty());
        assertTrue(results.get(0).isSuccess());
        assertEquals(
            Collections.singletonList(cachedTransaction.toDomain()),
            results.get(0).getData()
        );
    }

    @Test
    public void givenNetworkAvailable_whenFetching_thenRoomUpdatesAndEmitsNewData() {
        fakeRemoteSource.returnTransactions("2024-01-15",
            Collections.singletonList(remoteTransaction));

        List<Result<List<Transaction>>> results = new ArrayList<>();
        repository.getTransactions("2024-01-15").observeForever(results::add);

        assertTrue(fakeLocalSource.wasUpserted(TransactionEntity.fromDto(remoteTransactionDto)));
    }
}
```

---

## Key Rules

| Rule | Reason |
|------|--------|
| Always emit from Room, not from network | Room updates automatically when data changes via LiveData |
| Sync failure must not suppress the Room emission | Offline users still get their cached data |
| `LiveData` from DAO for reads, `void` for writes (called on background thread) | DAOs returning LiveData auto-update the UI on DB change |
| Upsert, not insert | Re-syncing the same date must not create duplicates |
| `SyncState` field from day one | Cannot add it cleanly later without a schema migration |
