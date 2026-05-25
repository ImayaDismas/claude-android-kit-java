# Android Architecture Standard

This is the single source of truth for all architectural decisions in this project.
Where any conflict exists between this document and another guideline file, this document
takes precedence. Module-specific guidelines (networking, database, DI, security,
preferences, UI) define implementation detail for their domain — they do not override
the layer contracts defined here.

---

## 1. Architecture Overview

### Pattern
**Clean Architecture + MVVM** with unidirectional data flow.

### Data Flow
```
UI (Activity / Fragment — XML layouts)
  ↓  user events / method calls
ViewModel
  ↓  calls
UseCase                    ← all business logic lives here
  ↓  calls
Repository                 ← only data access point; interface in domain/, impl in data/
  ↙                   ↘
RemoteDataSource        LocalDataSource
(Retrofit ApiService)   (Room DAO)
```

### Layer Responsibilities

| Layer | Owns | Forbidden |
|-------|------|-----------|
| `ui/screen/` | Observe `LiveData<UiState>`, call ViewModel methods, render XML | Business logic, data construction, direct data access |
| `ui/viewmodel/` | Hold `MutableLiveData<UiState>`, call UseCases, post state | Business logic, Android framework refs (`Activity`, `View`), direct data/DB access |
| `domain/usecase/` | Business rules, orchestration | Android SDK imports, awareness of data sources |
| `domain/repository/` | Repository interface definitions | Implementations of any kind |
| `data/repository/` | Orchestrate `RemoteDataSource` + `LocalDataSource`, sync logic | Business logic |
| `data/datasource/remote/` | Call Retrofit `ApiService`, return DTOs | Persistence, business logic |
| `data/datasource/local/` | Call Room DAO, return entities | Networking, business logic |
| `di/module/` | Instantiate and wire all dependencies | Logic of any kind |

---

## 2. Project Structure

```
app/
├── data/
│   ├── datasource/
│   │   ├── remote/        # RemoteDataSource classes + Retrofit ApiService interfaces
│   │   └── local/         # LocalDataSource classes + Room DAOs
│   ├── model/             # API response DTOs + Room @Entity classes
│   └── repository/        # RepositoryImpl classes
│
├── domain/
│   ├── model/             # Pure Java domain models (no Android/framework imports)
│   ├── repository/        # Repository interfaces
│   └── usecase/           # UseCase classes (one per operation)
│
├── ui/
│   ├── screen/            # Activity and Fragment classes
│   ├── components/        # Reusable custom Views and shared XML layout fragments
│   ├── adapter/           # RecyclerView Adapters (ListAdapter + DiffUtil)
│   ├── state/             # UiState abstract classes
│   └── viewmodel/         # ViewModel classes
│
└── di/
    └── module/            # Hilt modules: NetworkModule, DatabaseModule, RepositoryModule
```

> OkHttpClient, Retrofit, and interceptors are instantiated inside `di/module/NetworkModule`.
> They are infrastructure — they belong in the DI layer, not the data layer.
> `network/` is not a top-level package.

---

## 3. Naming Conventions

All class names must follow these patterns consistently. No deviations.

| Class Type | Pattern | Example |
|------------|---------|---------|
| UseCase | `VerbNounUseCase` | `GetUserUseCase`, `SyncOrdersUseCase` |
| Repository interface | `NounRepository` | `UserRepository` |
| Repository implementation | `NounRepositoryImpl` | `UserRepositoryImpl` |
| Remote data source | `NounRemoteDataSource` | `UserRemoteDataSource` |
| Local data source | `NounLocalDataSource` | `UserLocalDataSource` |
| Retrofit service | `NounApiService` | `UserApiService` |
| Room DAO | `NounDao` | `UserDao` |
| Room entity | `NounEntity` | `UserEntity` |
| API request/response DTO | `NounRequest` / `NounResponse` | `CreateUserRequest`, `UserResponse` |
| Domain model | `Noun` (plain) | `User`, `Order` |
| ViewModel | `NounViewModel` | `UserViewModel` |
| UiState | `NounUiState` | `UserUiState` |
| RecyclerView Adapter | `NounAdapter` | `UserAdapter`, `TransactionAdapter` |
| DiffUtil Callback | `NounDiffCallback` | `TransactionDiffCallback` |
| Hilt module | `NounModule` | `NetworkModule`, `UserModule` |

---

## 4. ViewModel Contract

```java
@HiltViewModel
public class UserViewModel extends ViewModel {

    private final GetUserUseCase getUser;
    private final AppExecutors executors;

    private final MutableLiveData<UserUiState> _uiState =
        new MutableLiveData<>(new UserUiState.Loading());
    public final LiveData<UserUiState> uiState = _uiState;

    @Inject
    public UserViewModel(GetUserUseCase getUser, AppExecutors executors) {
        this.getUser = getUser;
        this.executors = executors;
    }

    public void loadUser(String userId) {
        _uiState.setValue(new UserUiState.Loading());
        executors.diskIO().execute(() -> {
            Result<User> result = getUser.execute(userId);
            if (result.isSuccess()) {
                _uiState.postValue(new UserUiState.Success(result.getData()));
            } else {
                _uiState.postValue(new UserUiState.Error("Could not load user. Try again."));
            }
        });
    }

    @Override
    protected void onCleared() {
        super.onCleared();
    }
}
```

**Rules:**
- Annotated with `@HiltViewModel`; dependencies injected via constructor.
- Exposes exactly **one** `LiveData<NounUiState>` per screen — no multiple state streams.
- Calls UseCases only — never Repositories, DAOs, or DataSources directly.
- **Must not** hold references to `Activity`, `Fragment`, `View`, or `Context` (use `AndroidViewModel` only when `Application` context is unavoidable).
- All background work dispatched via `AppExecutors` — never `new Thread()` or `AsyncTask`.
- State updated via `setValue()` on main thread, `postValue()` from background threads.

---

## 5. UiState Contract

```java
// ui/state/UserUiState.java
public abstract class UserUiState {

    private UserUiState() {}

    public static final class Loading extends UserUiState {}

    public static final class Success extends UserUiState {
        public final User user;
        public Success(User user) { this.user = user; }
    }

    public static final class Error extends UserUiState {
        public final String message;
        public Error(String message) { this.message = message; }
    }
}
```

**Rules:**
- One `NounUiState` abstract class per screen. No shared state objects across screens.
- All fields are `final` — state is immutable.
- `LiveData<NounUiState>` only — a `MutableLiveData` backing field is kept private.
- Never expose `MutableLiveData` publicly; expose only `LiveData`.

---

## 6. UI (Fragment / Activity) Contract

```java
// ui/screen/UserFragment.java
@AndroidEntryPoint
public class UserFragment extends Fragment {

    private UserViewModel viewModel;
    private FragmentUserBinding binding;

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
        binding = FragmentUserBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        viewModel = new ViewModelProvider(this).get(UserViewModel.class);

        viewModel.uiState.observe(getViewLifecycleOwner(), state -> {
            if (state instanceof UserUiState.Loading) {
                showLoading();
            } else if (state instanceof UserUiState.Success) {
                showUser(((UserUiState.Success) state).user);
            } else if (state instanceof UserUiState.Error) {
                showError(((UserUiState.Error) state).message);
            }
        });

        viewModel.loadUser(requireArguments().getString("userId"));
    }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
```

**Rules:**
- Use `ViewBinding` — never `findViewById()` in new code.
- Observe `LiveData` with `getViewLifecycleOwner()` — never with `this` in a Fragment.
- Set `binding = null` in `onDestroyView()` — prevents memory leaks.
- No business logic, data fetching, or threading in UI classes.
- Fragments do not pass data directly to each other — use shared ViewModel or SafeArgs.

---

## 7. UseCase Contract

```java
// domain/usecase/GetUserUseCase.java
public class GetUserUseCase {

    private final UserRepository repository;

    @Inject
    public GetUserUseCase(UserRepository repository) {
        this.repository = repository;
    }

    public Result<User> execute(String userId) {
        return repository.getUser(userId);
    }
}
```

**Rules:**
- **Mandatory** — all business logic must live in a UseCase. No business logic in ViewModel, Repository, or DataSource.
- One class, one operation. `execute(...)` is the single public entry point.
- Returns `Result<T>` for single values or `LiveData<Result<T>>` for reactive streams.
- Pure Java — zero Android SDK or framework imports unless strictly required.

---

## 8. Repository Contract

```java
// domain/repository/UserRepository.java
public interface UserRepository {
    LiveData<Result<User>> observeUser(String userId);
    Result<Void> syncUser(String userId);
}

// data/repository/UserRepositoryImpl.java
public class UserRepositoryImpl implements UserRepository {

    private final UserRemoteDataSource remoteSource;
    private final UserLocalDataSource localSource;
    private final AppExecutors executors;

    @Inject
    public UserRepositoryImpl(UserRemoteDataSource remoteSource,
                               UserLocalDataSource localSource,
                               AppExecutors executors) {
        this.remoteSource = remoteSource;
        this.localSource = localSource;
        this.executors = executors;
    }

    @Override
    public LiveData<Result<User>> observeUser(String userId) {
        // Always emit from Room; trigger a background sync
        syncUser(userId);
        return Transformations.map(
            localSource.observeUser(userId),
            entity -> entity != null
                ? Result.success(entity.toDomain())
                : Result.error(new AppException.NotFound())
        );
    }

    @Override
    public Result<Void> syncUser(String userId) {
        try {
            UserResponse dto = remoteSource.fetchUser(userId);
            localSource.upsertUser(UserEntity.fromDto(dto));
            return Result.success(null);
        } catch (IOException e) {
            return Result.error(new AppException.NetworkUnavailable());
        } catch (HttpException e) {
            return Result.error(new AppException.ServerError(e.code(), e.getMessage()));
        }
    }
}
```

**Rules:**
- Interface in `domain/repository/`, implementation in `data/repository/`. Never merged.
- Injected via its interface — never the concrete class.
- The only component that calls both `RemoteDataSource` and `LocalDataSource`.
- Always returns domain models (`domain/model/`) — never exposes `@Entity` or DTOs.
- Maps all exceptions to `AppException` before returning — never lets raw Retrofit or Room exceptions propagate.

---

## 9. DataSource Contract

**Rules:**
- `RemoteDataSource` calls one Retrofit `ApiService` interface — no other network access.
- `LocalDataSource` calls one Room `Dao` interface — no other database access.
- Both map their outputs to the types the Repository expects (entity / DTO).
- Neither calls the other — all orchestration belongs in the Repository.
- Network operations must never be called on the main thread.

```java
// data/datasource/remote/UserRemoteDataSource.java
public class UserRemoteDataSource {

    private final UserApiService api;

    @Inject
    public UserRemoteDataSource(UserApiService api) {
        this.api = api;
    }

    public UserResponse fetchUser(String id) throws IOException {
        Response<UserResponse> response = api.getUser(id).execute();
        if (!response.isSuccessful() || response.body() == null) {
            throw new HttpException(response);
        }
        return response.body();
    }
}
```

---

## 10. Offline-First Rules

These rules apply across all layers. No layer may violate them.

1. **Write to Room first.** After every successful network response, persist to the local database before the result reaches the caller.
2. **UI observes Room only.** ViewModels observe `LiveData` from the Repository, which observes Room. Raw network responses are never emitted to the UI.
3. **Background sync via WorkManager.** Sync is not triggered from the UI thread. Use `PeriodicWorkRequest` for scheduled sync, `OneTimeWorkRequest` for on-demand sync.
4. **Remote wins on conflict.** Use `updatedAt` timestamps for conflict resolution. Remote data overwrites local data unless a feature specifies otherwise explicitly.
5. **Soft deletes for syncable entities.** Mark records deleted with a flag; reconcile with the server before hard-deleting.
6. **Stale data is always rendered.** UI must display cached data immediately and reflect sync status. Loading states must not block rendering of stale content.

---

## 11. Dependency Injection Contract

**Setup (mandatory):**
- `@HiltAndroidApp` on the `Application` class.
- `@AndroidEntryPoint` on all Activities, Fragments, Services, and BroadcastReceivers that receive injection.
- `@HiltViewModel` on all ViewModels.

**Injection style:**
- Constructor injection by default — always preferred.
- Field injection (`@Inject` on a field) only where constructor injection is impossible (e.g., `BroadcastReceiver`).
- Service locator pattern (`getInstance()`, static accessors) is **forbidden**.
- Manual instantiation of any Hilt-managed class is **forbidden**.

**Scoping:**

| Scope | Use For |
|-------|---------|
| `@Singleton` | OkHttpClient, Retrofit, Room database, AppExecutors, top-level Repositories |
| `@ViewModelScoped` | UseCases, per-screen state holders |
| `@ActivityRetainedScoped` | State shared across screens that must survive rotation |

- Match scope to the **shortest lifecycle** that satisfies correctness. Overuse of `@Singleton` causes memory leaks and untestable dependencies.

---

## 12. Security Principles

These are global rules. Implementation details belong in `android/security/`.

| Concern | Rule |
|---------|------|
| Cryptographic keys | Android Keystore only. Never in files, preferences, or memory beyond the operation. |
| Database at rest | Room encrypted with SQLCipher. Encryption key in Android Keystore. |
| Preferences / tokens | Encrypted via Keystore-backed cipher stored in DataStore or EncryptedFile. |
| User authentication | `BiometricPrompt` (androidx.biometric) only. Never roll custom biometric flows. |
| Network transport | TLS only. No cleartext connections. Certificate pinning for high-security endpoints. |
| Logging | Never log tokens, keys, PII, or biometric data at any layer. |
| Release builds | R8 obfuscation mandatory. All debug flags disabled. |

---

## 13. Storage Decision

| Data Type | Storage Mechanism |
|-----------|------------------|
| Auth tokens, session data, user preferences, feature flags | DataStore (Preferences) with Keystore encryption |
| Structured, relational, or queryable data | Room |
| In-memory ephemeral UI state | `MutableLiveData` in ViewModel |
| Large binaries (images, files) | File system + Room metadata |

---

## 14. Error Handling

### Result type

```java
// domain/model/Result.java
public class Result<T> {
    private final T data;
    private final AppException error;

    private Result(T data, AppException error) {
        this.data = data;
        this.error = error;
    }

    public static <T> Result<T> success(T data) {
        return new Result<>(data, null);
    }

    public static <T> Result<T> error(AppException error) {
        return new Result<>(null, error);
    }

    public boolean isSuccess() { return error == null; }
    public T getData() { return data; }
    public AppException getError() { return error; }
}
```

### Exception hierarchy

```java
// domain/model/AppException.java
public abstract class AppException extends Exception {

    public static class NetworkException extends AppException {
        public final int code;
        public NetworkException(int code, String message) {
            super(message);
            this.code = code;
        }
    }

    public static class ServerException extends AppException {
        public final int code;
        public ServerException(int code, String message) {
            super(message);
            this.code = code;
        }
    }

    public static class LocalException extends AppException {
        public LocalException(String message) { super(message); }
    }

    public static class NetworkUnavailable extends AppException {}
    public static class UnauthorizedException extends AppException {}
    public static class NotFound extends AppException {}
}
```

### Propagation rules

- `RemoteDataSource` maps all Retrofit/OkHttp exceptions → `AppException` at the boundary.
- `LocalDataSource` maps all Room exceptions → `AppException` at the boundary.
- `Repository` receives `AppException` and returns it wrapped in `Result.error()` — no re-mapping.
- `UseCase` receives `Result.error()` and passes it through unchanged — no re-mapping.
- `ViewModel` maps `Result.error()` to `UiState.Error` with a user-facing message — this is the only layer that translates exceptions to UI strings.
- No silent failures at any layer.

---

## 15. Threading

| Context | Mechanism |
|---------|-----------|
| UI updates | Main thread — `LiveData.setValue()` or `LiveData.postValue()` |
| Network / disk I/O | `AppExecutors.networkIO()` or `AppExecutors.diskIO()` |
| CPU-intensive transforms | `AppExecutors.diskIO()` (general background) |
| Background sync | `WorkManager` (persists across process death) |

**Rules:**
- All background work goes through `AppExecutors` — never raw `new Thread()`, `AsyncTask`, or `Handler.post()` for business logic.
- `AppExecutors` is a `@Singleton` provided by Hilt and injected into Repositories and DataSources.
- `LiveData.postValue()` is safe to call from any background thread.
- `LiveData.setValue()` must be called from the main thread only.
- Room `LiveData<T>` return types are automatically observed on a background thread — do not wrap them additionally.
- Never perform network or disk I/O on the main thread.

```java
// di/AppExecutors.java
@Singleton
public class AppExecutors {
    private final Executor diskIO;
    private final Executor networkIO;
    private final Executor mainThread;

    @Inject
    public AppExecutors() {
        this.diskIO = Executors.newSingleThreadExecutor();
        this.networkIO = Executors.newFixedThreadPool(3);
        this.mainThread = new MainThreadExecutor();
    }

    public Executor diskIO()    { return diskIO; }
    public Executor networkIO() { return networkIO; }
    public Executor mainThread(){ return mainThread; }

    private static class MainThreadExecutor implements Executor {
        private final Handler mainThreadHandler = new Handler(Looper.getMainLooper());
        @Override
        public void execute(@NonNull Runnable command) {
            mainThreadHandler.post(command);
        }
    }
}
```

---

## 16. Contradiction Resolution Index

| Topic | Previous State | Resolved Rule | Section |
|-------|---------------|---------------|---------|
| Primary language | Kotlin | **Java** — primary language; Kotlin interop acceptable | §1 |
| UI technology | Jetpack Compose | **XML layouts** — ViewBinding required; Compose is optional reference only | §6 |
| State exposure | `StateFlow` | **`LiveData<UiState>`** — `MutableLiveData` private, `LiveData` public | §5 |
| LiveData | Forbidden in new code | **Required** — primary reactive primitive for Java UI | §5 |
| Threading | Coroutines / `viewModelScope` | **`AppExecutors`** — explicit thread pool; `postValue()` for UI updates | §15 |
| Singleton pattern | Kotlin `object` | **Hilt `@Singleton`** only — no manual singletons | §11 |
| UseCase mandatory | Optional | **Mandatory** — no exceptions | §7 |
| `network/` top-level layer | Peer of `data/`, `domain/` | **Removed** — networking is infrastructure inside `di/module/` | §2 |
| RecyclerView vs LazyColumn | LazyColumn (Compose) | **RecyclerView + ListAdapter** — primary list implementation | §6 |
