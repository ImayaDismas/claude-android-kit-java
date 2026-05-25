# Hilt Guidelines

Implementation rules for dependency injection. The DI contract (scoping rules, what is and is not a singleton) is defined in `architecture_standard.md` §11. See also `examples/hilt_modules.md` for the three canonical module implementations.

---

## Setup

```java
// Application class — required
@HiltAndroidApp
public class APP_NAMEApplication extends Application {}

// All Activities, Fragments, Services, and BroadcastReceivers that receive injection
@AndroidEntryPoint
public class MainActivity extends AppCompatActivity { ... }

@AndroidEntryPoint
public class LedgerFragment extends Fragment { ... }

// All ViewModels
@HiltViewModel
public class LedgerViewModel extends ViewModel {

    private final GetDailySummaryUseCase getSummary;

    @Inject
    public LedgerViewModel(GetDailySummaryUseCase getSummary) {
        this.getSummary = getSummary;
    }
}
```

---

## Injection Style

**Rules:**
- Constructor injection always — `@Inject` on the constructor.
- Field injection (`@Inject` on a field) only where constructor injection is impossible (e.g., `BroadcastReceiver` — which cannot have `@AndroidEntryPoint` in some cases).
- Service locator pattern (`getInstance()`, static accessors) is **forbidden**.
- Manual instantiation of any Hilt-managed class is **forbidden**.

---

## Module Types — `class` with `@Provides` vs `abstract class` with `@Binds`

This distinction is the most commonly confused point in Hilt.

```java
// ✅ Regular class with @Provides — use when constructing concrete instances
@Module
@InstallIn(SingletonComponent.class)
public class NetworkModule {

    @Provides
    @Singleton
    public OkHttpClient provideOkHttpClient(AuthInterceptor authInterceptor) {
        return new OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .build();
    }
}

// ✅ Abstract class with @Binds — use for interface → implementation bindings
@Module
@InstallIn(SingletonComponent.class)
public abstract class RepositoryModule {

    @Binds
    @Singleton
    public abstract LedgerRepository bindLedgerRepository(LedgerRepositoryImpl impl);
}
```

**Rule:** `@Binds` requires `abstract` methods inside an `abstract class`. `@Provides` uses regular methods inside a regular (or abstract) class. In Java, you can mix `@Provides` and `@Binds` in an abstract class by making the `@Provides` methods `static` — but prefer splitting into separate modules for clarity.

---

## `@Binds` vs `@Provides`

```java
// ✅ @Binds — preferred for interface → impl binding (zero overhead at runtime)
@Binds
@Singleton
public abstract LedgerRepository bindLedgerRepository(LedgerRepositoryImpl impl);

// ⚠️ @Provides — acceptable but less efficient (Hilt creates a wrapper)
@Provides
@Singleton
public LedgerRepository provideLedgerRepository(LedgerRepositoryImpl impl) {
    return impl;
}
```

Use `@Binds` for all interface-to-implementation bindings. Use `@Provides` for:
- Third-party classes that cannot have `@Inject` on their constructor (OkHttpClient, Retrofit, Room)
- Objects requiring complex construction logic

---

## Scoping

| Scope | Annotation | Use for |
|---|---|---|
| App lifetime | `@Singleton` | OkHttpClient, Retrofit, AppDatabase, DataStore, AppExecutors, top-level Repositories |
| ViewModel lifetime | `@ViewModelScoped` | UseCases — they hold no shared state |
| Activity lifetime (survives rotation) | `@ActivityRetainedScoped` | State shared across screens within one Activity |

**Rules:**
- Do not annotate DAOs with `@Singleton` — Room manages DAO lifecycle via the database.
- UseCases must be `@ViewModelScoped`, not `@Singleton` — each ViewModel gets its own instance.
- Overuse of `@Singleton` causes memory leaks when a singleton holds a reference to a shorter-lived object.

---

## Module Organisation

```
di/module/
├── NetworkModule.java     # OkHttpClient, Retrofit, ApiService interfaces
├── DatabaseModule.java    # AppDatabase, all DAOs, AppExecutors
└── RepositoryModule.java  # Repository interface → RepositoryImpl bindings
```

**Rules:**
- One module per concern — do not create a single `AppModule` with everything.
- Feature-specific dependencies go in a feature module, not in the three core modules.
- Module files live in `di/module/` — not in `data/` or `domain/`.

---

## Testing with Hilt

**Replace a module in instrumented tests:**

```java
@HiltAndroidTest
@UninstallModules(RepositoryModule.class)
public class LedgerViewModelTest {

    @BindValue
    LedgerRepository ledgerRepository = new FakeLedgerRepository();

    @Rule
    public HiltAndroidRule hiltRule = new HiltAndroidRule(this);

    @Before
    public void setUp() {
        hiltRule.inject();
    }
}
```

**Rules:**
- Use `@UninstallModules` + `@BindValue` to replace production bindings with fakes in instrumented tests.
- Unit tests (non-instrumented) do not need Hilt — inject fakes manually via constructor.
- Never mock the Room database — use an in-memory Room instance or a fake Repository.

---

## Anti-Patterns — Forbidden

| Pattern | Correct Replacement |
|---|---|
| `NetworkClient.getInstance()` static singleton | `@Provides @Singleton` in `NetworkModule` |
| `@Inject` on a concrete Repository in a UseCase | `@Inject` on the Repository **interface**; `@Binds` wires the impl |
| `@Singleton` on every dependency by default | Match scope to the shortest lifecycle that is correct |
| Manual `new RepositoryImpl(new Dao())` in ViewModel | Inject via Hilt constructor injection |
| Passing dependencies through constructors across 3+ layers | Inject at the point of use via Hilt |
