# Android Java Stack

Approved libraries and the rules for each. Using a library not on this list requires explicit approval. Using a library on the Forbidden list is a review-blocking violation.

---

## Presentation

| Library | Use for | Forbidden use |
|---|---|---|
| **XML Layouts** | All UI — screens, dialogs, list items | Jetpack Compose in new code (see note below) |
| **ViewBinding** | Binding XML layouts in Activity/Fragment | `findViewById()` in new code |
| **ViewModel** | Hold `UiState`, post results, call UseCases | Holding `Activity`, `View`, or `Fragment` references |
| **Navigation Component** | Screen routing, back stack, SafeArgs | Manual `FragmentManager` transactions for navigation |
| **Material Components** | Buttons, cards, text fields, bottom sheets | Custom view implementations that duplicate Material behaviour |
| **RecyclerView + ListAdapter** | All scrollable lists | Loading full datasets into `ListView` or `ScrollView` |

> **Compose note:** Jetpack Compose is acceptable as optional reference material for teams evaluating future migration. It is **not** the standard for new features in this kit. XML + ViewBinding is the primary and required UI approach.

---

## State and Reactivity

| Library | Use for | Forbidden use |
|---|---|---|
| **LiveData** | All UI state exposure from ViewModel | Exposing `MutableLiveData` publicly |
| **MutableLiveData** | Private backing field in ViewModel | Sharing across multiple screens without a mediator |
| **Transformations** | `map()` and `switchMap()` on LiveData chains | Complex transformations that belong in a UseCase |
| **MediatorLiveData** | Merging multiple LiveData sources | Over-engineering simple single-source observations |

**RxJava** is acceptable only on projects where it already exists. Do not introduce it in greenfield code.

---

## Networking

| Library | Use for | Notes |
|---|---|---|
| **Retrofit** | API endpoint definitions as Java interfaces | Use `Call<T>` — execute on background thread via `AppExecutors` |
| **OkHttp** | HTTP client, interceptors, auth, logging | Single shared `@Singleton` instance |
| **Gson** | JSON serialization/deserialization | Acceptable for Java; Moshi requires Kotlin reflection adapter |

Both Retrofit and OkHttp are required. Retrofit defines the contract; OkHttp is the transport. They are wired together in `di/module/NetworkModule`.

Retrofit `Call<T>` must be executed on a background thread via `AppExecutors.networkIO()` — never on the main thread and never via `.enqueue()` in UI code.

---

## Database

| Library | Use for | Forbidden use |
|---|---|---|
| **Room** | All structured, relational, queryable data | SQLite directly, raw cursors |
| **SQLCipher** | Encrypting the Room database at rest | Unencrypted Room in production |
| **Paging 3** | Large datasets from Room or network | Loading entire tables into memory |

Room DAO methods returning `LiveData<T>` are automatically observed on a background thread. Room DAO write methods (`@Insert`, `@Update`, `@Delete`) must be called from a background thread via `AppExecutors.diskIO()`.

---

## Preferences and Storage

| Library | Use for | Forbidden |
|---|---|---|
| **DataStore (Preferences)** | Key-value preferences, auth tokens | `SharedPreferences`, `EncryptedSharedPreferences` |
| **DataStore (Proto)** | Strongly typed, structured preferences | — |
| **EncryptedFile** | Storing sensitive files on disk | Plaintext files for sensitive data |

`SharedPreferences` and `EncryptedSharedPreferences` are **forbidden** in new code.

---

## Background Work

| Library | Use for | Forbidden use |
|---|---|---|
| **WorkManager** | Periodic sync, background tasks that must survive process death | `JobScheduler` directly, `AlarmManager` for work |
| **AppExecutors** | In-process async work in Repository and DataSource | `AsyncTask`, `new Thread()`, `Handler` for business logic |

`AsyncTask` is removed from the Android SDK. Do not use it.

---

## Dependency Injection

| Library | Use for |
|---|---|
| **Hilt** | All dependency injection — no exceptions |

Manual singletons, service locator patterns, and static factory methods are **forbidden**. Hilt works fully with Java — all annotations (`@HiltAndroidApp`, `@AndroidEntryPoint`, `@HiltViewModel`, `@Inject`, `@Binds`, `@Provides`) are Java-compatible.

---

## Testing

| Library | Use for |
|---|---|
| **JUnit 4** | All unit tests — `@Test`, `@Before`, `@After`, `@Rule` |
| **Mockito** | Mocking Java interfaces and classes at layer boundaries |
| **In-memory Room** | Database layer tests — `Room.inMemoryDatabaseBuilder(...)` |
| **MockWebServer** | Testing Retrofit/OkHttp responses and error codes |
| **Hilt Testing** | `@HiltAndroidTest`, `@UninstallModules`, `@BindValue` for integration tests |
| **InstantTaskExecutorRule** | Synchronous `LiveData` observation in unit tests |
| **Robolectric** | Lightweight Android component tests without a device |

**MockK** is Kotlin-only. All Java tests use Mockito.

---

## Forbidden Libraries (any use is a review violation)

| Library | Reason |
|---|---|
| `RxJava` / `RxAndroid` | `AppExecutors` + `LiveData` is the project standard for Java |
| `SharedPreferences` | Replaced by DataStore |
| `EncryptedSharedPreferences` | Deprecated encryption; replaced by DataStore + Keystore |
| `AsyncTask` | Removed from Android SDK |
| Manual `OkHttpClient` / `Retrofit` instantiation | Must go through `NetworkModule` |
| `new Thread()` for business logic | Must go through `AppExecutors` |
| Static singleton factories (`getInstance()`) | Must go through Hilt |
