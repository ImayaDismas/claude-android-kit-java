# Singleton Guidelines

All singletons in this project are managed by Hilt using `@Singleton`. Manual singletons using static fields, `getInstance()` factories, or double-checked locking are **forbidden**.

> This rule is defined in `architecture_standard.md` §11. `NetworkClient.getInstance()` is the canonical anti-pattern — do not use it.

---

## What should be `@Singleton`

| Dependency | Reason |
|---|---|
| `OkHttpClient` | Expensive to create; connection pool must be shared |
| `Retrofit` | Singleton because its client is a singleton |
| `AppDatabase` | One database connection per app |
| `DataStore` | One instance per file; multiple instances cause write conflicts |
| `AppExecutors` | Thread pools must be shared to avoid resource exhaustion |
| Top-level Repositories | Safe to share; hold no mutable per-user state |

## What should NOT be `@Singleton`

| Dependency | Correct scope | Reason |
|---|---|---|
| `UseCase` | `@ViewModelScoped` | Holds no shared state; cheap to create |
| `ViewModel` | Hilt-managed per screen | Should not outlive its screen |
| DAO | Unscoped (provided by `@Singleton` database) | Room manages DAO lifecycle |

---

## Correct pattern

```java
// ✅ Hilt @Singleton — the only accepted way to create a singleton
@Module
@InstallIn(SingletonComponent.class)
public class NetworkModule {

    @Provides
    @Singleton
    public OkHttpClient provideOkHttpClient(AuthInterceptor authInterceptor) {
        return new OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .build();
    }
}
```

## Forbidden patterns

```java
// ❌ Static getInstance() — bypasses Hilt, untestable, thread-unsafe without care
public class NetworkClient {
    private static volatile OkHttpClient instance;

    public static OkHttpClient getInstance() {
        if (instance == null) {
            synchronized (NetworkClient.class) {
                if (instance == null) {
                    instance = new OkHttpClient.Builder().build();
                }
            }
        }
        return instance;
    }
}

// ❌ Static final field — same problem; cannot be replaced in tests
public class AppConfig {
    public static final Retrofit RETROFIT = new Retrofit.Builder().build();
}
```

**Why forbidden:** Manual singletons cannot be replaced in tests, are not lifecycle-aware, and create hidden global state. Hilt `@Singleton` provides the same single-instance guarantee with full test replaceability via `@UninstallModules` and `@BindValue`.
