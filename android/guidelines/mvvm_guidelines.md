# MVVM Guidelines

## Core Principle

Each layer has exactly one job. Violations — even small ones — compound into unmaintainable code.

| Layer | Job | Forbidden |
|-------|-----|-----------|
| **View** (Activity / Fragment) | Observe `LiveData`, render XML, forward user events to ViewModel | Business logic, data access, threading |
| **ViewModel** | Hold `UiState`, call UseCases, post state to `LiveData` | Business rules, repository access, Android Views |
| **UseCase** | Execute one business operation | Data access, UI concerns |
| **Repository** | Mediate between remote and local data sources | Business rules, UI concerns |

---

## ViewModel Rules

```java
@HiltViewModel
public class OrderViewModel extends ViewModel {

    private final PlaceOrderUseCase placeOrder;
    private final AppExecutors executors;

    // ✅ Private mutable — public immutable
    private final MutableLiveData<OrderUiState> _uiState =
        new MutableLiveData<>(new OrderUiState.Loading());
    public final LiveData<OrderUiState> uiState = _uiState;

    @Inject
    public OrderViewModel(PlaceOrderUseCase placeOrder, AppExecutors executors) {
        this.placeOrder = placeOrder;
        this.executors = executors;
    }

    public void submitOrder(OrderRequest request) {
        _uiState.setValue(new OrderUiState.Loading());
        executors.diskIO().execute(() -> {
            Result<Order> result = placeOrder.execute(request);
            if (result.isSuccess()) {
                _uiState.postValue(new OrderUiState.Success(result.getData()));
            } else {
                _uiState.postValue(new OrderUiState.Error("Order failed. Try again."));
            }
        });
    }
}
```

---

## View (Fragment) Rules

```java
@AndroidEntryPoint
public class OrderFragment extends Fragment {

    private OrderViewModel viewModel;
    private FragmentOrderBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater,
                             ViewGroup container, Bundle savedInstanceState) {
        binding = FragmentOrderBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        viewModel = new ViewModelProvider(this).get(OrderViewModel.class);

        // ✅ Observe with ViewLifecycleOwner — auto-removed on view destroy
        viewModel.uiState.observe(getViewLifecycleOwner(), this::renderState);

        binding.submitButton.setOnClickListener(v ->
            viewModel.submitOrder(buildRequest()));
    }

    private void renderState(OrderUiState state) {
        binding.progressBar.setVisibility(
            state instanceof OrderUiState.Loading ? View.VISIBLE : View.GONE);

        if (state instanceof OrderUiState.Success) {
            showOrder(((OrderUiState.Success) state).order);
        } else if (state instanceof OrderUiState.Error) {
            showError(((OrderUiState.Error) state).message);
        }
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null; // ✅ Prevent memory leaks
    }
}
```

---

## What NOT to do

```java
// ❌ Business logic in ViewModel
public void loadOrders() {
    executors.diskIO().execute(() -> {
        List<Order> orders = dao.getAll(); // ❌ direct DAO
        long total = 0;
        for (Order o : orders) total += o.amount; // ❌ business logic
        _uiState.postValue(new UiState.Success("Total: " + total)); // ❌ formatting
    });
}

// ❌ Network call in ViewModel
public void fetchOrders() {
    executors.networkIO().execute(() -> {
        Response<List<Order>> res = api.getOrders().execute(); // ❌ direct API
        _uiState.postValue(new UiState.Success(res.body()));
    });
}

// ❌ Observing LiveData in Activity without accounting for config change
viewModel.uiState.observeForever(state -> { ... }); // leaks forever

// ❌ Exposing MutableLiveData publicly
public MutableLiveData<OrderUiState> uiState = new MutableLiveData<>(); // UI can corrupt state
```
