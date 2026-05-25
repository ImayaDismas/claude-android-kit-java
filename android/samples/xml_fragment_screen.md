# Sample: XML Fragment Screen with LiveData + UiState

Full implementation of a ledger screen using XML layouts, ViewBinding, RecyclerView, and LiveData — following the UiState pattern and ViewModel contract.

---

## UiState Definition

```java
// ui/state/LedgerUiState.java
public abstract class LedgerUiState {

    private LedgerUiState() {}

    public static final class Loading extends LedgerUiState {}

    public static final class Success extends LedgerUiState {
        public final DailySummary summary;
        public Success(DailySummary summary) { this.summary = summary; }
    }

    public static final class Error extends LedgerUiState {
        public final String message;
        public Error(String message) { this.message = message; }
    }
}
```

---

## ViewModel

```java
// ui/viewmodel/LedgerViewModel.java
@HiltViewModel
public class LedgerViewModel extends ViewModel {

    private final GetDailySummaryUseCase getDailySummary;
    private final AppExecutors executors;

    private final MutableLiveData<LedgerUiState> _uiState =
        new MutableLiveData<>(new LedgerUiState.Loading());
    public final LiveData<LedgerUiState> uiState = _uiState;

    // One-time navigation events — SingleLiveEvent prevents re-delivery on rotation
    private final SingleLiveEvent<LedgerEvent> _events = new SingleLiveEvent<>();
    public final LiveData<LedgerEvent> events = _events;

    @Inject
    public LedgerViewModel(GetDailySummaryUseCase getDailySummary, AppExecutors executors) {
        this.getDailySummary = getDailySummary;
        this.executors = executors;
    }

    public void loadSummary(String date) {
        _uiState.setValue(new LedgerUiState.Loading());
        executors.diskIO().execute(() -> {
            Result<DailySummary> result = getDailySummary.execute(date);
            if (result.isSuccess()) {
                _uiState.postValue(new LedgerUiState.Success(result.getData()));
            } else {
                _uiState.postValue(new LedgerUiState.Error("Could not load summary. Try again."));
            }
        });
    }

    public void onTransactionClick(String transactionId) {
        _events.setValue(new LedgerEvent.NavigateToDetail(transactionId));
    }
}

// ui/state/LedgerEvent.java
public abstract class LedgerEvent {
    public static final class NavigateToDetail extends LedgerEvent {
        public final String transactionId;
        public NavigateToDetail(String transactionId) { this.transactionId = transactionId; }
    }
}
```

---

## XML Layout

```xml
<!-- res/layout/fragment_ledger.xml -->
<androidx.coordinatorlayout.widget.CoordinatorLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <ProgressBar
        android:id="@+id/progressBar"
        style="?android:attr/progressBarStyle"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:visibility="gone" />

    <LinearLayout
        android:id="@+id/contentLayout"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:orientation="vertical"
        android:visibility="gone">

        <include layout="@layout/view_ledger_summary" />

        <androidx.recyclerview.widget.RecyclerView
            android:id="@+id/recyclerView"
            android:layout_width="match_parent"
            android:layout_height="0dp"
            android:layout_weight="1"
            android:clipToPadding="false"
            android:paddingBottom="16dp" />
    </LinearLayout>

    <LinearLayout
        android:id="@+id/errorLayout"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center"
        android:orientation="vertical"
        android:visibility="gone">

        <TextView
            android:id="@+id/tvError"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content" />

        <com.google.android.material.button.MaterialButton
            android:id="@+id/btnRetry"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:text="@string/action_retry" />
    </LinearLayout>

</androidx.coordinatorlayout.widget.CoordinatorLayout>
```

---

## Fragment

```java
// ui/screen/LedgerFragment.java
@AndroidEntryPoint
public class LedgerFragment extends Fragment {

    private FragmentLedgerBinding binding;
    private LedgerViewModel viewModel;
    private TransactionAdapter adapter;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentLedgerBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        viewModel = new ViewModelProvider(this).get(LedgerViewModel.class);

        setupRecyclerView();
        observeState();
        observeEvents();

        viewModel.loadSummary(LocalDate.now().toString());
    }

    private void setupRecyclerView() {
        adapter = new TransactionAdapter(viewModel::onTransactionClick);
        binding.recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
        binding.recyclerView.setAdapter(adapter);
        binding.recyclerView.setHasFixedSize(true);
    }

    private void observeState() {
        // ✅ getViewLifecycleOwner() — auto-removed when Fragment view is destroyed
        viewModel.uiState.observe(getViewLifecycleOwner(), this::renderState);
    }

    private void observeEvents() {
        viewModel.events.observe(getViewLifecycleOwner(), event -> {
            if (event instanceof LedgerEvent.NavigateToDetail) {
                String transactionId = ((LedgerEvent.NavigateToDetail) event).transactionId;
                LedgerFragmentDirections.ActionLedgerToDetail action =
                    LedgerFragmentDirections.actionLedgerToDetail(transactionId);
                Navigation.findNavController(binding.getRoot()).navigate(action);
            }
        });
    }

    private void renderState(LedgerUiState state) {
        // Reset all views
        binding.progressBar.setVisibility(View.GONE);
        binding.contentLayout.setVisibility(View.GONE);
        binding.errorLayout.setVisibility(View.GONE);

        if (state instanceof LedgerUiState.Loading) {
            binding.progressBar.setVisibility(View.VISIBLE);

        } else if (state instanceof LedgerUiState.Success) {
            LedgerUiState.Success success = (LedgerUiState.Success) state;
            binding.contentLayout.setVisibility(View.VISIBLE);
            adapter.submitList(success.summary.getTransactions());

        } else if (state instanceof LedgerUiState.Error) {
            binding.errorLayout.setVisibility(View.VISIBLE);
            binding.tvError.setText(((LedgerUiState.Error) state).message);
            binding.btnRetry.setOnClickListener(v ->
                viewModel.loadSummary(LocalDate.now().toString()));
        }
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null; // ✅ Prevent memory leak
    }
}
```

---

## RecyclerView Adapter

```java
// ui/adapter/TransactionAdapter.java
public class TransactionAdapter extends ListAdapter<Transaction, TransactionAdapter.ViewHolder> {

    private final OnTransactionClickListener listener;

    public TransactionAdapter(OnTransactionClickListener listener) {
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
        holder.bind(getItem(position), listener);
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
            binding.tvDate.setText(transaction.getDate());
            binding.getRoot().setOnClickListener(v ->
                listener.onTransactionClick(transaction.getId()));
        }
    }

    public interface OnTransactionClickListener {
        void onTransactionClick(String transactionId);
    }
}

// ui/adapter/TransactionDiffCallback.java
public class TransactionDiffCallback extends DiffUtil.ItemCallback<Transaction> {
    @Override
    public boolean areItemsTheSame(@NonNull Transaction a, @NonNull Transaction b) {
        return a.getId().equals(b.getId());
    }
    @Override
    public boolean areContentsTheSame(@NonNull Transaction a, @NonNull Transaction b) {
        return a.equals(b);
    }
}
```

---

## Nav Graph Wiring

```xml
<!-- res/navigation/main_nav.xml -->
<fragment
    android:id="@+id/ledgerFragment"
    android:name="com.example.ui.screen.LedgerFragment"
    tools:layout="@layout/fragment_ledger">
    <action
        android:id="@+id/actionLedgerToDetail"
        app:destination="@id/transactionDetailFragment" />
</fragment>

<fragment
    android:id="@+id/transactionDetailFragment"
    android:name="com.example.ui.screen.TransactionDetailFragment"
    tools:layout="@layout/fragment_transaction_detail">
    <argument
        android:name="transactionId"
        app:argType="string" />
</fragment>
```

---

## Forbidden Patterns

| Forbidden | Correct Replacement |
|---|---|
| `notifyDataSetChanged()` | `ListAdapter.submitList(list)` |
| `viewModel.uiState.observe(this, ...)` in Fragment | `observe(getViewLifecycleOwner(), ...)` |
| `binding = null` skipped in `onDestroyView()` | Always null binding in `onDestroyView()` |
| Raw `Bundle` for navigation arguments | SafeArgs with `@+id/action` and `<argument>` |
| Multiple boolean flags (`isLoading`, `hasError`) | Single sealed `UiState` class |
