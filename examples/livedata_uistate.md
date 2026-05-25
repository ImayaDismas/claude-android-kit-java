# Example: LiveData and UiState (Java)

This example shows the correct pattern for exposing UI state from a ViewModel and observing it in a Fragment. These are the most common points of error in the presentation layer.

---

## The UiState Abstract Class

Define one abstract class per screen. Keep it in `ui/state/`.

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

**Rules:**
- One `UiState` per screen — do not share across screens.
- `Loading` has no data.
- `Success` carries the domain model — not a DTO, not a raw DB entity.
- `Error` carries a user-facing string — not an exception, not a stack trace.

---

## The ViewModel

```java
// ui/viewmodel/LedgerViewModel.java
@HiltViewModel
public class LedgerViewModel extends ViewModel {

    private final GetDailySummaryUseCase getDailySummary;
    private final AppExecutors executors;

    // ✅ Private mutable backing field
    private final MutableLiveData<LedgerUiState> _uiState =
        new MutableLiveData<>(new LedgerUiState.Loading());

    // ✅ Public read-only LiveData exposed to the UI
    public final LiveData<LedgerUiState> uiState = _uiState;

    @Inject
    public LedgerViewModel(GetDailySummaryUseCase getDailySummary, AppExecutors executors) {
        this.getDailySummary = getDailySummary;
        this.executors = executors;
    }

    public void loadSummary(String date) {
        // ✅ Reset to Loading when starting a new load — always on main thread
        _uiState.setValue(new LedgerUiState.Loading());

        executors.diskIO().execute(() -> {
            Result<DailySummary> result = getDailySummary.execute(date);

            if (result.isSuccess()) {
                _uiState.postValue(new LedgerUiState.Success(result.getData()));
            } else {
                // ✅ Map exception to a user-facing message — never expose raw message
                _uiState.postValue(new LedgerUiState.Error("Could not load summary. Try again."));
            }
        });
    }
}
```

**What NOT to do:**

```java
// ❌ Exposing MutableLiveData — UI can corrupt state
public MutableLiveData<LedgerUiState> uiState = new MutableLiveData<>();

// ❌ Multiple LiveData fields for the same screen — leads to inconsistent state
public MutableLiveData<Boolean> isLoading = new MutableLiveData<>(false);
public MutableLiveData<DailySummary> summary = new MutableLiveData<>();
public MutableLiveData<String> error = new MutableLiveData<>();

// ❌ Raw exception message exposed to UI
_uiState.postValue(new LedgerUiState.Error(e.getMessage()));

// ❌ setValue() from background thread — must use postValue()
executors.diskIO().execute(() -> {
    _uiState.setValue(new LedgerUiState.Loading()); // crashes on non-main thread
});
```

---

## Observing in the Fragment

```java
// ui/screen/LedgerFragment.java
@AndroidEntryPoint
public class LedgerFragment extends Fragment {

    private FragmentLedgerBinding binding;
    private LedgerViewModel viewModel;

    @Override
    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        viewModel = new ViewModelProvider(this).get(LedgerViewModel.class);

        // ✅ getViewLifecycleOwner() — respects lifecycle; auto-removed when view is destroyed
        viewModel.uiState.observe(getViewLifecycleOwner(), this::renderState);

        viewModel.loadSummary(LocalDate.now().toString());
    }

    private void renderState(LedgerUiState state) {
        // ✅ Handle all three states — no implicit fallthrough
        binding.progressBar.setVisibility(View.GONE);
        binding.contentLayout.setVisibility(View.GONE);
        binding.errorLayout.setVisibility(View.GONE);

        if (state instanceof LedgerUiState.Loading) {
            binding.progressBar.setVisibility(View.VISIBLE);

        } else if (state instanceof LedgerUiState.Success) {
            binding.contentLayout.setVisibility(View.VISIBLE);
            updateContent(((LedgerUiState.Success) state).summary);

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
        binding = null;
    }
}
```

**What NOT to do:**

```java
// ❌ Observing with 'this' in Fragment — lives beyond view destruction
viewModel.uiState.observe(this, state -> { ... });

// ❌ observeForever in Fragment — must be removed manually or leaks
viewModel.uiState.observeForever(state -> { ... });

// ❌ Missing a state branch — Error state silently unhandled
if (state instanceof LedgerUiState.Loading) {
    showLoading();
} else if (state instanceof LedgerUiState.Success) {
    showContent(((LedgerUiState.Success) state).summary);
}
// Error case missing — UI stays in Loading state forever if error occurs
```

---

## Testing the ViewModel

```java
public class LedgerViewModelTest {

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

        // Initial state is Loading (set in field initializer)
        viewModel.loadSummary("2024-01-15");

        assertEquals(3, states.size()); // initial Loading + reset Loading + Success
        assertTrue(states.get(0) instanceof LedgerUiState.Loading);
        assertTrue(states.get(1) instanceof LedgerUiState.Loading);
        assertTrue(states.get(2) instanceof LedgerUiState.Success);
        assertEquals(testSummary, ((LedgerUiState.Success) states.get(2)).summary);
    }

    @Test
    public void givenUseCaseFailure_whenLoadingSummary_thenEmitsError() {
        fakeUseCase.setResult(Result.error(new AppException.NetworkUnavailable()));

        List<LedgerUiState> states = new ArrayList<>();
        viewModel.uiState.observeForever(states::add);

        viewModel.loadSummary("2024-01-15");

        LedgerUiState last = states.get(states.size() - 1);
        assertTrue(last instanceof LedgerUiState.Error);
    }
}
```

---

## Key Rules to Remember

| Rule | Reason |
|------|--------|
| Private `MutableLiveData`, public `LiveData` | Prevents UI from writing state |
| `observe(getViewLifecycleOwner(), ...)` in Fragment | Auto-removed when Fragment view is destroyed |
| `postValue()` from background threads, `setValue()` on main thread | `setValue()` throws if called off main thread |
| One `UiState` per screen | Multiple LiveData fields for one screen create inconsistency windows |
| Map errors to user messages in ViewModel | Domain errors never reach the UI as raw exceptions |
