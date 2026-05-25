# Example: Hilt Modules (Java)

This example shows the correct structure for the three core Hilt modules: `NetworkModule`, `DatabaseModule`, and `RepositoryModule`. These are the most commonly misplaced or mis-structured dependencies in the project.

> `network/` is not a top-level package. OkHttpClient, Retrofit, and all interceptors live in `di/module/NetworkModule`. This is enforced in the architecture standard.

---

## NetworkModule

```java
// di/module/NetworkModule.java
@Module
@InstallIn(SingletonComponent.class)
public class NetworkModule {

    @Provides
    @Singleton
    public OkHttpClient provideOkHttpClient(
            AuthInterceptor authInterceptor,
            TokenAuthenticator tokenAuthenticator) {

        OkHttpClient.Builder builder = new OkHttpClient.Builder()
            .addInterceptor(authInterceptor)        // ✅ Auth token injected via interceptor
            .authenticator(tokenAuthenticator)      // ✅ Token refresh on 401
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS);

        if (BuildConfig.DEBUG) {
            // ✅ Logging only in debug — never log tokens in release
            HttpLoggingInterceptor logging = new HttpLoggingInterceptor();
            logging.setLevel(HttpLoggingInterceptor.Level.BODY);
            builder.addInterceptor(logging);
        }

        return builder.build();
    }

    @Provides
    @Singleton
    public Gson provideGson() {
        return new GsonBuilder()
            .setFieldNamingPolicy(FieldNamingPolicy.LOWER_CASE_WITH_UNDERSCORES)
            .create();
    }

    @Provides
    @Singleton
    public Retrofit provideRetrofit(OkHttpClient okHttpClient, Gson gson) {
        return new Retrofit.Builder()
            .baseUrl(BuildConfig.BASE_URL)
            .client(okHttpClient)                   // ✅ Shared client passed in — not rebuilt
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build();
    }

    @Provides
    @Singleton
    public LedgerApiService provideLedgerApiService(Retrofit retrofit) {
        return retrofit.create(LedgerApiService.class);
    }

    @Provides
    @Singleton
    public AuthApiService provideAuthApiService(Retrofit retrofit) {
        return retrofit.create(AuthApiService.class);
    }
}
```

**What NOT to do:**

```java
// ❌ Creating OkHttpClient inside provideRetrofit — second instance, interceptors not shared
public Retrofit provideRetrofit() {
    return new Retrofit.Builder()
        .client(new OkHttpClient.Builder().build()) // new client, no auth interceptor
        .build();
}

// ❌ Logging interceptor always at BODY level — logs tokens in release
logging.setLevel(HttpLoggingInterceptor.Level.BODY); // without BuildConfig.DEBUG check

// ❌ Token passed directly at call site — should be in interceptor
@GET("data")
Call<DataResponse> fetchData(@Header("Authorization") String token);
```

---

## AuthInterceptor

```java
// data/datasource/remote/AuthInterceptor.java
public class AuthInterceptor implements Interceptor {

    private final TokenStore tokenStore;

    @Inject
    public AuthInterceptor(TokenStore tokenStore) {
        this.tokenStore = tokenStore;
    }

    @Override
    public Response intercept(Chain chain) throws IOException {
        String token = tokenStore.getAccessToken(); // synchronous read from encrypted store

        Request request = chain.request();
        if (token != null) {
            request = request.newBuilder()
                .header("Authorization", "Bearer " + token)
                .build();
        }
        return chain.proceed(request);
    }
}
```

---

## DatabaseModule

```java
// di/module/DatabaseModule.java
@Module
@InstallIn(SingletonComponent.class)
public class DatabaseModule {

    @Provides
    @Singleton
    public AppDatabase provideDatabase(
            @ApplicationContext Context context,
            KeystoreHelper keystoreHelper) {

        byte[] passphrase = keystoreHelper.getDatabasePassphrase();
        SupportFactory factory = new SupportFactory(passphrase);

        return Room.databaseBuilder(context, AppDatabase.class, "app.db")
            .openHelperFactory(factory)                  // ✅ SQLCipher encryption
            .addMigrations(Migrations.MIGRATION_1_2, Migrations.MIGRATION_2_3)
            // ❌ Never: .fallbackToDestructiveMigration()
            .build();
    }

    @Provides
    public TransactionDao provideTransactionDao(AppDatabase db) {
        return db.transactionDao();
    }

    @Provides
    public CreditDao provideCreditDao(AppDatabase db) {
        return db.creditDao();
    }

    // ✅ DAOs are NOT @Singleton — Room manages their lifecycle via the @Singleton database

    @Provides
    @Singleton
    public AppExecutors provideAppExecutors() {
        return new AppExecutors();
    }
}
```

**What NOT to do:**

```java
// ❌ Hardcoded passphrase — key must come from Android Keystore
new SupportFactory("hardcoded-password".getBytes());

// ❌ Destructive migration — destroys all user data on schema change
.fallbackToDestructiveMigration();

// ❌ DAO as @Singleton — unnecessary; Room already handles this
@Singleton
public TransactionDao provideTransactionDao(AppDatabase db) { ... }
```

---

## RepositoryModule

```java
// di/module/RepositoryModule.java
@Module
@InstallIn(SingletonComponent.class)
public abstract class RepositoryModule {

    // ✅ @Binds — tells Hilt which impl to inject when the interface is requested
    @Binds
    @Singleton
    public abstract LedgerRepository bindLedgerRepository(LedgerRepositoryImpl impl);

    @Binds
    @Singleton
    public abstract CreditRepository bindCreditRepository(CreditRepositoryImpl impl);

    @Binds
    @Singleton
    public abstract ReconciliationRepository bindReconciliationRepository(
        ReconciliationRepositoryImpl impl);
}
```

**What NOT to do:**

```java
// ❌ Using @Provides instead of @Binds for interface→impl — less efficient
@Provides
public LedgerRepository provideLedgerRepository(LedgerRepositoryImpl impl) {
    return impl;
}

// ❌ Injecting the concrete class in the UseCase — breaks testability
public class GetDailySummaryUseCase {
    @Inject
    public GetDailySummaryUseCase(LedgerRepositoryImpl repo) { ... } // should be interface
}

// ❌ Not @Singleton for repositories — creates multiple instances
@Binds
public abstract LedgerRepository bindLedgerRepository(LedgerRepositoryImpl impl);
// (missing @Singleton annotation)
```

---

## Module Installation Summary

| Module | `@InstallIn` | Class type | Why |
|--------|-------------|-----------|-----|
| `NetworkModule` | `SingletonComponent` | Regular `class` | Retrofit and OkHttp must be singletons; `@Provides` methods need a class |
| `DatabaseModule` | `SingletonComponent` | Regular `class` | Database is a singleton; DAOs provided without `@Singleton` |
| `RepositoryModule` | `SingletonComponent` | `abstract class` | `@Binds` requires an abstract class |

---

## Correct Dependency Graph

```
LedgerFragment
  └── LedgerViewModel (@HiltViewModel)
        └── GetDailySummaryUseCase
              └── LedgerRepository (interface)
                    └── LedgerRepositoryImpl (@Singleton via RepositoryModule)
                          ├── LedgerLocalDataSource
                          │     └── TransactionDao (via DatabaseModule)
                          │           └── AppDatabase (@Singleton via DatabaseModule)
                          └── LedgerRemoteDataSource
                                └── LedgerApiService (via NetworkModule)
                                      └── Retrofit (@Singleton via NetworkModule)
                                            └── OkHttpClient (@Singleton via NetworkModule)
                                                  └── AuthInterceptor
```

Every node in this graph is either injected by Hilt or provided by one of the three modules. Nothing is manually constructed.
