# Sample: Paging 3 with Room-backed PagingSource (Java)

Full implementation of Paging 3 for a large transaction list — Room as the source of truth, network sync via `RemoteMediator`, displayed in a RecyclerView with `PagingDataAdapter`.

---

## When to Use Paging 3

Use Paging 3 when a list could grow beyond what fits comfortably in memory — typically any list that can exceed ~100 items. For bounded lists, a regular `LiveData<List<T>>` DAO query is sufficient.

---

## DAO — PagingSource

```java
// data/datasource/local/TransactionDao.java
@Dao
public interface TransactionDao {

    // ✅ Room generates the PagingSource — no manual implementation needed
    @Query("""
        SELECT id, amount, currency_code, type, date, sync_state
        FROM transactions
        WHERE date BETWEEN :start AND :end
        ORDER BY date DESC, created_at DESC
    """)
    PagingSource<Integer, TransactionEntity> getTransactionsPaged(String start, String end);

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void upsertAll(List<TransactionEntity> entities);
}
```

---

## RemoteMediator (Network + Room Sync)

```java
// data/datasource/remote/TransactionRemoteMediator.java
@OptIn(markerClass = ExperimentalPagingApi.class)
public class TransactionRemoteMediator extends RxRemoteMediator<Integer, TransactionEntity> {

    private final LedgerRemoteDataSource remoteDataSource;
    private final TransactionDao transactionDao;
    private final AppDatabase database;
    private final String start;
    private final String end;

    @Inject
    public TransactionRemoteMediator(
            LedgerRemoteDataSource remoteDataSource,
            TransactionDao transactionDao,
            AppDatabase database,
            String start,
            String end) {
        this.remoteDataSource = remoteDataSource;
        this.transactionDao = transactionDao;
        this.database = database;
        this.start = start;
        this.end = end;
    }

    @NonNull
    @Override
    public MediatorResult loadSingle(
            @NonNull LoadType loadType,
            @NonNull PagingState<Integer, TransactionEntity> state) {

        int page;
        switch (loadType) {
            case REFRESH: page = 1; break;
            case PREPEND: return new MediatorResult.Success(true);
            case APPEND:
                TransactionEntity lastItem = state.lastItemOrNull();
                if (lastItem == null) return new MediatorResult.Success(true);
                page = (state.getPages().stream().mapToInt(p -> p.getData().size()).sum()
                    / state.getConfig().pageSize) + 1;
                break;
            default: return new MediatorResult.Success(true);
        }

        try {
            List<TransactionDto> dtos = remoteDataSource.getTransactions(start, page);

            database.runInTransaction(() -> {
                if (loadType == LoadType.REFRESH) {
                    transactionDao.deleteByDateRange(start, end);
                }
                List<TransactionEntity> entities = new ArrayList<>();
                for (TransactionDto dto : dtos) entities.add(TransactionEntity.fromDto(dto));
                transactionDao.upsertAll(entities);
            });

            return new MediatorResult.Success(dtos.isEmpty());

        } catch (IOException | AppException e) {
            return new MediatorResult.Error(e);
        }
    }
}
```

---

## Repository — Pager Construction

```java
// data/repository/LedgerRepositoryImpl.java
@OptIn(markerClass = ExperimentalPagingApi.class)
@Override
public LiveData<PagingData<Transaction>> getTransactionsPaged(String start, String end) {

    Pager<Integer, TransactionEntity> pager = new Pager<>(
        new PagingConfig(
            /* pageSize= */ 50,
            /* prefetchDistance= */ 10,
            /* enablePlaceholders= */ false
        ),
        new TransactionRemoteMediator(remoteDataSource, transactionDao, database, start, end),
        () -> transactionDao.getTransactionsPaged(start, end)
    );

    // Map entity → domain model, then convert Flow to LiveData
    return Transformations.map(
        PagingLiveData.getLiveData(pager),
        pagingData -> pagingData.map(TransactionEntity::toDomain)
    );
}
```

---

## ViewModel

```java
// ui/viewmodel/TransactionListViewModel.java
@HiltViewModel
public class TransactionListViewModel extends ViewModel {

    private final GetTransactionsPagedUseCase getTransactionsPaged;
    public final LiveData<PagingData<Transaction>> transactions;

    @Inject
    public TransactionListViewModel(GetTransactionsPagedUseCase getTransactionsPaged) {
        this.getTransactionsPaged = getTransactionsPaged;

        String start = LocalDate.now().minusDays(30).toString();
        String end = LocalDate.now().toString();

        // ✅ cachedIn — survives rotation; no redundant network calls
        transactions = PagingLiveData.cachedIn(
            getTransactionsPaged.execute(start, end),
            this
        );
    }
}
```

---

## PagingDataAdapter

```java
// ui/adapter/TransactionPagingAdapter.java
public class TransactionPagingAdapter
        extends PagingDataAdapter<Transaction, TransactionPagingAdapter.ViewHolder> {

    private final OnTransactionClickListener listener;

    public TransactionPagingAdapter(OnTransactionClickListener listener) {
        super(new TransactionDiffCallback());
        this.listener = listener;
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        ItemTransactionBinding binding = ItemTransactionBinding.inflate(
            LayoutInflater.from(parent.getContext()), parent, false);
        return new ViewHolder(binding);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        Transaction transaction = getItem(position);
        if (transaction != null) {
            holder.bind(transaction, listener);
        }
        // null = placeholder shown during prefetch
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        private final ItemTransactionBinding binding;

        ViewHolder(ItemTransactionBinding binding) {
            super(binding.getRoot());
            this.binding = binding;
        }

        void bind(Transaction transaction, OnTransactionClickListener listener) {
            binding.tvMerchant.setText(transaction.getMerchant());
            binding.tvAmount.setText(
                AmountFormatter.format(transaction.getAmount(), transaction.getCurrencyCode()));
            binding.getRoot().setOnClickListener(v ->
                listener.onTransactionClick(transaction.getId()));
        }
    }

    public interface OnTransactionClickListener {
        void onTransactionClick(String transactionId);
    }
}
```

---

## Fragment Setup

```java
// ui/screen/TransactionListFragment.java
@AndroidEntryPoint
public class TransactionListFragment extends Fragment {

    private FragmentTransactionListBinding binding;
    private TransactionListViewModel viewModel;
    private TransactionPagingAdapter adapter;

    @Override
    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        viewModel = new ViewModelProvider(this).get(TransactionListViewModel.class);

        adapter = new TransactionPagingAdapter(this::onTransactionClick);

        // ✅ withLoadStateFooter — shows loading/error states at bottom of list
        binding.recyclerView.setAdapter(
            adapter.withLoadStateFooter(new TransactionLoadStateAdapter(adapter::retry))
        );
        binding.recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));

        // ✅ Submit paged data
        viewModel.transactions.observe(getViewLifecycleOwner(), adapter::submitData);

        // ✅ Full-screen loading on initial fetch
        adapter.addLoadStateListener(loadStates -> {
            LoadState refresh = loadStates.getRefresh();
            binding.progressBar.setVisibility(
                refresh instanceof LoadState.Loading ? View.VISIBLE : View.GONE);

            if (refresh instanceof LoadState.Error) {
                showError(((LoadState.Error) refresh).getError().getMessage());
            }
        });
    }

    private void onTransactionClick(String transactionId) {
        TransactionListFragmentDirections.ActionListToDetail action =
            TransactionListFragmentDirections.actionListToDetail(transactionId);
        Navigation.findNavController(binding.getRoot()).navigate(action);
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
```

---

## Testing the PagingSource (DAO Layer)

```java
@RunWith(AndroidJUnit4.class)
public class TransactionDaoPagingTest {

    private AppDatabase database;
    private TransactionDao dao;

    @Before
    public void setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase.class
        ).build();
        dao = database.transactionDao();
    }

    @After
    public void tearDown() {
        database.close();
    }

    @Test
    public void givenSeededTransactions_whenPaging_thenReturnsInDateOrder() throws Exception {
        List<TransactionEntity> entities = new ArrayList<>();
        for (int i = 1; i <= 20; i++) {
            entities.add(buildTransactionEntity("tx-" + i));
        }
        dao.upsertAll(entities);

        PagingSource<Integer, TransactionEntity> pagingSource =
            dao.getTransactionsPaged("2024-01-01", "2024-01-31");

        PagingSource.LoadResult<Integer, TransactionEntity> result =
            pagingSource.load(
                new PagingSource.LoadParams.Refresh<>(null, 10, false)
            ).get(); // ListenableFuture.get() — use in test only

        assertTrue(result instanceof PagingSource.LoadResult.Page);
        assertEquals(10, ((PagingSource.LoadResult.Page<?, TransactionEntity>) result)
            .getData().size());
    }
}
```

---

## Forbidden Patterns

| Forbidden | Correct Replacement |
|---|---|
| Manual `PagingSource` implementation over a Room DAO | Use `@Query` → `PagingSource<Integer, Entity>` — Room generates it |
| Missing `cachedIn` in ViewModel | Always cache — prevents redundant network calls on rotation |
| `SELECT *` in the paged query | Name all columns explicitly |
| Clearing the entire table on `REFRESH` | Clear only the date range being paged |
| `notifyDataSetChanged()` on `PagingDataAdapter` | Paging handles diffing internally — never call notify methods manually |
