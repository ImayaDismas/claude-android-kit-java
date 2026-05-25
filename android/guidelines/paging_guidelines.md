# Paging Guidelines (Paging 3 + RecyclerView)

## When to Use Paging 3

Use Paging 3 when a list could grow beyond what fits comfortably in memory or a single query — typically any list that can exceed ~100 items. For bounded lists (e.g., a user's last 7 days of transactions where the count is predictable), a regular `LiveData<List<T>>` DAO query is sufficient.

---

## Setup

```java
// DAO returns PagingSource — Room generates the implementation
@Query("SELECT id, amount, date FROM transactions WHERE date BETWEEN :start AND :end ORDER BY date DESC")
PagingSource<Integer, TransactionEntity> getTransactionsPaged(String start, String end);
```

---

## Repository — Pager Construction

```java
// data/repository/LedgerRepositoryImpl.java
@Override
public LiveData<PagingData<Transaction>> getTransactionsPaged(String start, String end) {
    Pager<Integer, TransactionEntity> pager = new Pager<>(
        new PagingConfig(
            /* pageSize= */ 50,
            /* prefetchDistance= */ 10,
            /* enablePlaceholders= */ false
        ),
        () -> transactionDao.getTransactionsPaged(start, end)
    );

    // Convert Flow to LiveData — Paging 3 provides a LiveData extension
    return PagingLiveData.getLiveData(pager);
}
```

---

## ViewModel

```java
@HiltViewModel
public class TransactionListViewModel extends ViewModel {

    private final GetTransactionsPagedUseCase getTransactionsPaged;
    public final LiveData<PagingData<Transaction>> transactions;

    @Inject
    public TransactionListViewModel(GetTransactionsPagedUseCase getTransactionsPaged) {
        this.getTransactionsPaged = getTransactionsPaged;
        // ✅ cachedIn — survives config change, no redundant network calls
        transactions = PagingLiveData.cachedIn(
            getTransactionsPaged.execute(
                LocalDate.now().minusDays(30).toString(),
                LocalDate.now().toString()
            ),
            getViewModelScope()
        );
    }
}
```

---

## PagingDataAdapter (RecyclerView)

```java
// ui/adapter/TransactionPagingAdapter.java
public class TransactionPagingAdapter extends PagingDataAdapter<Transaction, TransactionPagingAdapter.ViewHolder> {

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
        // null means placeholder — hide or show loading indicator
    }
}
```

---

## Fragment Setup

```java
@Override
public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
    super.onViewCreated(view, savedInstanceState);

    TransactionPagingAdapter adapter = new TransactionPagingAdapter(this::onTransactionClick);

    // ✅ LoadStateAdapter — shows loading/error footer automatically
    binding.recyclerView.setAdapter(
        adapter.withLoadStateFooter(new TransactionLoadStateAdapter(adapter::retry))
    );
    binding.recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));

    viewModel.transactions.observe(getViewLifecycleOwner(), adapter::submitData);

    // ✅ Full-screen loading on initial load
    adapter.addLoadStateListener(loadStates -> {
        CombinedLoadStates refresh = loadStates.getRefresh();
        binding.progressBar.setVisibility(
            refresh instanceof LoadState.Loading ? View.VISIBLE : View.GONE);

        if (refresh instanceof LoadState.Error) {
            LoadState.Error error = (LoadState.Error) refresh;
            showError(error.getError().getMessage());
        }
    });
}
```

---

## Rules

- Avoid heavy transformations on the main thread — map entities to domain models in the Repository before they reach the ViewModel.
- Avoid heavy database joins in the paged query — fetch related data lazily if needed.
- Always call `cachedIn(viewModelScope)` — prevents redundant network calls on rotation.
- Use `withLoadStateFooter()` to automatically handle loading/error states at the end of the list.
- Never call `notifyDataSetChanged()` on a `PagingDataAdapter` — Paging handles diffing internally.
- `SELECT *` is forbidden — always name columns explicitly in the paged query.
