# XML UI Guidelines

This file defines implementation rules for XML-based screens using ViewBinding, RecyclerView, and Material Components. Architectural contracts (which layer owns what, UiState shape, ViewModel rules) are defined in `architecture_standard.md` and take precedence.

---

## ViewBinding — Required

Always use ViewBinding. Never use `findViewById()` in new code.

```java
// ✅ Correct — Fragment with ViewBinding
@AndroidEntryPoint
public class LedgerFragment extends Fragment {

    private FragmentLedgerBinding binding;
    private LedgerViewModel viewModel;

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
        observeState();
    }

    private void observeState() {
        // ✅ getViewLifecycleOwner() — auto-removed when Fragment view is destroyed
        viewModel.uiState.observe(getViewLifecycleOwner(), this::renderState);
    }

    private void renderState(LedgerUiState state) {
        binding.progressBar.setVisibility(
            state instanceof LedgerUiState.Loading ? View.VISIBLE : View.GONE);

        if (state instanceof LedgerUiState.Success) {
            LedgerUiState.Success success = (LedgerUiState.Success) state;
            updateSummary(success.summary);
        } else if (state instanceof LedgerUiState.Error) {
            showError(((LedgerUiState.Error) state).message);
        }
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null; // ✅ Prevent memory leak
    }
}
```

**Rules:**
- Enable ViewBinding in `build.gradle`: `viewBinding { enabled = true }`.
- `binding = null` in `onDestroyView()` — the Fragment view is destroyed before the Fragment itself.
- Use `getViewLifecycleOwner()` for all LiveData observation in Fragments.
- Use `this` for LiveData observation in Activities.

---

## RecyclerView + ListAdapter

All scrollable lists use `RecyclerView` with `ListAdapter` and `DiffUtil`.

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
            binding.tvAmount.setText(formatAmount(transaction.getAmount(), transaction.getCurrencyCode()));
            binding.tvDate.setText(transaction.getDate());
            binding.getRoot().setOnClickListener(v -> listener.onTransactionClick(transaction.getId()));
        }
    }

    public interface OnTransactionClickListener {
        void onTransactionClick(String transactionId);
    }
}

// ui/adapter/TransactionDiffCallback.java
public class TransactionDiffCallback extends DiffUtil.ItemCallback<Transaction> {

    @Override
    public boolean areItemsTheSame(@NonNull Transaction oldItem, @NonNull Transaction newItem) {
        return oldItem.getId().equals(newItem.getId()); // ✅ Compare by stable ID
    }

    @Override
    public boolean areContentsTheSame(@NonNull Transaction oldItem, @NonNull Transaction newItem) {
        return oldItem.equals(newItem); // ✅ Full equality check
    }
}
```

**Rules:**
- Always use `ListAdapter` — never `RecyclerView.Adapter` with `notifyDataSetChanged()`.
- `DiffUtil.ItemCallback` must compare by stable ID in `areItemsTheSame()`.
- ViewHolder uses ViewBinding — not `itemView.findViewById()`.
- Call `adapter.submitList(list)` from the Fragment when LiveData emits — never call `notifyDataSetChanged()`.

---

## RecyclerView Setup in Fragment

```java
@Override
public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
    super.onViewCreated(view, savedInstanceState);

    TransactionAdapter adapter = new TransactionAdapter(this::onTransactionClick);
    binding.recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
    binding.recyclerView.setAdapter(adapter);
    binding.recyclerView.setHasFixedSize(true); // ✅ Performance: sizes don't change

    viewModel.uiState.observe(getViewLifecycleOwner(), state -> {
        if (state instanceof LedgerUiState.Success) {
            adapter.submitList(((LedgerUiState.Success) state).transactions);
        }
    });
}

private void onTransactionClick(String transactionId) {
    // Navigate via Navigation Component SafeArgs
    LedgerFragmentDirections.ActionLedgerToDetail action =
        LedgerFragmentDirections.actionLedgerToDetail(transactionId);
    Navigation.findNavController(binding.getRoot()).navigate(action);
}
```

---

## Navigation Component

Use the Navigation Component with XML nav graphs and SafeArgs for all screen transitions. The entry point is a single `NavHostFragment` declared in the Activity layout — it owns the back stack and Fragment lifecycle so you never manage `FragmentManager` directly.

### NavHostFragment — Activity Layout

Declare one `NavHostFragment` per Activity. All Fragments are swapped inside it.

```xml
<!-- res/layout/activity_main.xml -->
<androidx.constraintlayout.widget.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <androidx.fragment.app.FragmentContainerView
        android:id="@+id/nav_host_fragment"
        android:name="androidx.navigation.fragment.NavHostFragment"
        android:layout_width="0dp"
        android:layout_height="0dp"
        app:defaultNavHost="true"
        app:navGraph="@navigation/main_nav"
        app:layout_constraintTop_toTopOf="parent"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent" />

</androidx.constraintlayout.widget.ConstraintLayout>
```

**Key attributes:**
- `app:defaultNavHost="true"` — intercepts the system Back button. Only one NavHost per Activity should set this.
- `app:navGraph="@navigation/main_nav"` — declares the starting destination and all destinations at compile time.
- Use `FragmentContainerView`, not `FrameLayout` — it fixes Fragment animation rendering issues.

### NavController — Activity Setup

```java
@AndroidEntryPoint
public class MainActivity extends AppCompatActivity {

    private ActivityMainBinding binding;
    private NavController navController;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        NavHostFragment navHostFragment = (NavHostFragment) getSupportFragmentManager()
            .findFragmentById(R.id.nav_host_fragment);
        navController = navHostFragment.getNavController();

        // ✅ Wire NavController to ActionBar for Up navigation
        NavigationUI.setupActionBarWithNavController(this, navController);
    }

    @Override
    public boolean onSupportNavigateUp() {
        // ✅ Delegate Up button to NavController — do not override manually
        return navController.navigateUp() || super.onSupportNavigateUp();
    }
}
```

### NavController — Fragment Navigation

Fragments never hold `NavController` as a field. Retrieve it each time from the Fragment's view.

```java
// ✅ Retrieve NavController from the Fragment's view
private void onTransactionClick(String transactionId) {
    LedgerFragmentDirections.ActionLedgerToDetail action =
        LedgerFragmentDirections.actionLedgerToDetail(transactionId);
    NavHostFragment.findNavController(this).navigate(action);
}

// ✅ Navigate back programmatically
private void onCancelClick() {
    NavHostFragment.findNavController(this).popBackStack();
}
```

### Nav Graph XML

```xml
<!-- res/navigation/main_nav.xml -->
<navigation xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    xmlns:tools="http://schemas.android.com/tools"
    android:id="@+id/main_nav"
    app:startDestination="@id/ledgerFragment">

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
</navigation>
```

### Why NavHostFragment Handles Lifecycle Better

| Concern | Manual FragmentManager | NavHostFragment |
|---------|----------------------|-----------------|
| Back stack | Manual `addToBackStack()` per transaction | Automatic — nav graph declares the stack |
| Fragment lifecycle on Back | Must handle `onDestroyView` timing manually | NavController pops correctly; `getViewLifecycleOwner()` always reflects current view state |
| Argument passing | Manual `Bundle` keys — no compile-time safety | SafeArgs generates type-safe `Directions` and `Args` classes |
| Deep links | Manual Intent routing in `onNewIntent()` | Declared in nav graph; handled automatically |
| Up navigation | Manual `onBackPressed()` override | `NavigationUI.setupActionBarWithNavController` handles it |
| Shared ViewModel scope | Must scope to Activity (too broad) | `navGraphViewModels(R.id.sub_graph)` scopes to a specific flow |

### Scoping ViewModels to a Nav Graph

When two Fragments in a flow need to share state, scope the ViewModel to the nav sub-graph — not the Activity. The ViewModel is cleared when the user exits the graph, not when the Activity is destroyed.

```java
// ✅ ViewModel shared across all Fragments within the checkout sub-graph
CheckoutViewModel viewModel = new ViewModelProvider(
    Navigation.findNavController(requireView())
        .getBackStackEntry(R.id.checkout_graph)
).get(CheckoutViewModel.class);
```

**Rules:**
- Use SafeArgs for all navigation with arguments — never pass data via `Bundle` keys manually.
- Never use `getSupportFragmentManager().beginTransaction()` for navigation — use `NavController`.
- Retrieve `NavController` from the Fragment view each time (`NavHostFragment.findNavController(this)`) — never store it as a field.
- Deep links must be declared in the nav graph — not handled in `onNewIntent()` manually.
- Set `app:defaultNavHost="true"` on exactly one `FragmentContainerView` per Activity.

---

## Material Components

Use Material Components for all standard UI elements. Never build custom replacements for standard Material patterns.

```xml
<!-- ✅ Material text field -->
<com.google.android.material.textfield.TextInputLayout
    style="@style/Widget.MaterialComponents.TextInputLayout.OutlinedBox"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:hint="@string/label_amount">

    <com.google.android.material.textfield.TextInputEditText
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:inputType="numberDecimal" />
</com.google.android.material.textfield.TextInputLayout>

<!-- ✅ Material button -->
<com.google.android.material.button.MaterialButton
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:text="@string/action_submit"
    style="@style/Widget.MaterialComponents.Button" />
```

**Rules:**
- Use `MaterialTheme` colors and typography attributes — never hardcode colors or sizes.
- All visible string values must be in `strings.xml` — no hardcoded text in XML layouts.
- Use `?attr/colorPrimary`, `?attr/colorSurface`, etc. — never `@color/purple_500`.

---

## Loading and Error States

Handle all three UiState branches explicitly in every Fragment.

```java
private void renderState(MyUiState state) {
    // ✅ Reset all views first, then configure for the current state
    binding.progressBar.setVisibility(View.GONE);
    binding.recyclerView.setVisibility(View.GONE);
    binding.errorLayout.setVisibility(View.GONE);

    if (state instanceof MyUiState.Loading) {
        binding.progressBar.setVisibility(View.VISIBLE);
    } else if (state instanceof MyUiState.Success) {
        binding.recyclerView.setVisibility(View.VISIBLE);
        adapter.submitList(((MyUiState.Success) state).items);
    } else if (state instanceof MyUiState.Error) {
        binding.errorLayout.setVisibility(View.VISIBLE);
        binding.tvError.setText(((MyUiState.Error) state).message);
        binding.btnRetry.setOnClickListener(v -> viewModel.retry());
    }
}
```

---

## Shared Components

Shared UI components go in `ui/components/` as custom Views or reusable XML include layouts.

```java
// ui/components/SyncStatusView.java — reusable custom view
public class SyncStatusView extends LinearLayout {

    private ViewSyncStatusBinding binding;

    public SyncStatusView(Context context, AttributeSet attrs) {
        super(context, attrs);
        binding = ViewSyncStatusBinding.inflate(LayoutInflater.from(context), this, true);
    }

    public void setSyncState(SyncState state) {
        binding.ivIcon.setImageResource(iconFor(state));
        binding.tvLabel.setText(labelFor(state));
    }
}
```

---

## Forbidden Patterns

| Pattern | Why |
|---------|-----|
| `findViewById()` in new code | ViewBinding is required — safer, null-safe |
| `notifyDataSetChanged()` | Causes full RecyclerView redraw — use `ListAdapter.submitList()` |
| `LiveData.observe(this, ...)` in Fragment | Use `getViewLifecycleOwner()` — avoids leaks after view destruction |
| Hardcoded strings in XML layouts | Must be in `strings.xml` |
| Business logic in Fragment/Activity | Belongs in UseCase only |
| `Fragment.getFragmentManager()` for navigation | Use Navigation Component NavController |
| Multiple boolean flags for state (`isLoading`, `hasError`) | Use sealed `UiState` class |
