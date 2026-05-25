# Sample: OkHttp + Retrofit + Auth (Java)

Full wiring of OkHttp (with auth interceptor and token refresh) and Retrofit, provided as Hilt singletons. Matches the setup required by `android/networking/okhttp_networking.md` and `android/networking/token_interceptor.md`.

---

## Retrofit API Interface

```java
// data/datasource/remote/LedgerApiService.java
public interface LedgerApiService {

    @GET("transactions")
    Call<TransactionPageResponse> getTransactions(
        @Query("date") String date,           // ISO 8601: "2024-01-15"
        @Query("page") int page,
        @Query("per_page") int perPage
    );

    @POST("transactions")
    Call<TransactionResponse> createTransaction(@Body CreateTransactionRequest request);

    @DELETE("transactions/{id}")
    Call<Void> deleteTransaction(@Path("id") String id);
}
```

---

## Auth Interceptor

```java
// data/datasource/remote/AuthInterceptor.java
public class AuthInterceptor implements Interceptor {

    private final TokenStore tokenStore; // reads from encrypted storage

    @Inject
    public AuthInterceptor(TokenStore tokenStore) {
        this.tokenStore = tokenStore;
    }

    @Override
    public Response intercept(Chain chain) throws IOException {
        // ✅ Always read fresh from TokenStore — never cache in a field
        String token = tokenStore.getAccessToken();

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

## Token Refresh Authenticator

```java
// data/datasource/remote/TokenAuthenticator.java
public class TokenAuthenticator implements Authenticator {

    private final TokenStore tokenStore;
    private final AuthApiService authApiService;

    // ✅ Single lock — prevents multiple simultaneous refresh calls
    private final Object refreshLock = new Object();

    @Inject
    public TokenAuthenticator(TokenStore tokenStore, AuthApiService authApiService) {
        this.tokenStore = tokenStore;
        this.authApiService = authApiService;
    }

    @Nullable
    @Override
    public Request authenticate(Route route, @NonNull Response response) throws IOException {
        // Stop retrying after a refresh was already attempted
        if (response.request().header("X-Retry-After-Refresh") != null) return null;

        synchronized (refreshLock) {
            // Re-check: another thread may have already refreshed
            String currentToken = tokenStore.getAccessToken();
            String requestToken = extractBearer(response.request());
            if (currentToken != null && !currentToken.equals(requestToken)) {
                return response.request().newBuilder()
                    .header("Authorization", "Bearer " + currentToken)
                    .header("X-Retry-After-Refresh", "true")
                    .build();
            }

            String refreshToken = tokenStore.getRefreshToken();
            if (refreshToken == null) {
                tokenStore.clearTokens();
                return null;
            }

            try {
                Response<TokenResponse> refreshResponse =
                    authApiService.refreshToken(new RefreshRequest(refreshToken)).execute();

                if (!refreshResponse.isSuccessful() || refreshResponse.body() == null) {
                    tokenStore.clearTokens();
                    return null;
                }

                TokenResponse tokens = refreshResponse.body();
                tokenStore.saveTokens(tokens.accessToken, tokens.refreshToken);

                return response.request().newBuilder()
                    .header("Authorization", "Bearer " + tokens.accessToken)
                    .header("X-Retry-After-Refresh", "true")
                    .build();

            } catch (IOException e) {
                tokenStore.clearTokens();
                return null;
            }
        }
    }

    @Nullable
    private String extractBearer(Request request) {
        String auth = request.header("Authorization");
        return (auth != null && auth.startsWith("Bearer ")) ? auth.substring(7) : null;
    }
}
```

---

## Hilt NetworkModule

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
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(authInterceptor)        // ✅ Auth token injected via interceptor
            .authenticator(tokenAuthenticator);

        if (BuildConfig.DEBUG) {
            // ✅ Logging only in debug — never log in release builds
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
            .client(okHttpClient)               // ✅ Shared client — not rebuilt
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

---

## RemoteDataSource

```java
// data/datasource/remote/LedgerRemoteDataSource.java
public class LedgerRemoteDataSource {

    private final LedgerApiService api;

    @Inject
    public LedgerRemoteDataSource(LedgerApiService api) {
        this.api = api;
    }

    // ✅ Called from AppExecutors.networkIO() — blocking execute() is safe here
    public List<TransactionDto> getTransactions(String date, int page) throws AppException {
        try {
            Response<TransactionPageResponse> response =
                api.getTransactions(date, page, 50).execute();

            if (!response.isSuccessful() || response.body() == null) {
                mapHttpError(response.code());
            }
            return response.body().transactions;
        } catch (IOException e) {
            throw new AppException.NetworkUnavailable();
        }
    }

    private void mapHttpError(int code) throws AppException {
        if (code == 401) throw new AppException.UnauthorizedException();
        if (code >= 500) throw new AppException.ServerException(code, "Server error: " + code);
        throw new AppException.NetworkException(code, "Request failed: " + code);
    }
}
```

---

## Error Mapping in Repository

```java
// data/repository/LedgerRepositoryImpl.java (sync excerpt)
private void syncFromNetwork(String date) {
    executors.networkIO().execute(() -> {
        try {
            List<TransactionDto> dtos = remoteDataSource.getTransactions(date, 1);
            List<TransactionEntity> entities = new ArrayList<>();
            for (TransactionDto dto : dtos) {
                entities.add(TransactionEntity.fromDto(dto));
            }
            executors.diskIO().execute(() -> localDataSource.upsertAll(entities));

        } catch (AppException.NetworkUnavailable e) {
            // Network unavailable — Room already emits cached data; no action needed
        } catch (AppException.UnauthorizedException e) {
            // Token refresh failed — trigger re-auth via event or LiveData
        } catch (AppException e) {
            // Log non-fatal error — Room still serves cached data
        }
    });
}
```

---

## Dependency Graph

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
                                                  ├── AuthInterceptor
                                                  └── TokenAuthenticator
```

---

## Forbidden Patterns

| Forbidden | Correct Replacement |
|---|---|
| Hardcoded token in Retrofit call site | OkHttp `AuthInterceptor` injects it automatically |
| Multiple `OkHttpClient` instances | Single `@Singleton` in `NetworkModule` |
| `HttpLoggingInterceptor` in release builds | Gate behind `BuildConfig.DEBUG` |
| Calling `Call.execute()` on the main thread | Wrap in `AppExecutors.networkIO().execute(...)` |
| Catching `Throwable` without re-throwing unknowns | Explicitly handle known types; rethrow everything else |
| `Call.enqueue()` in UI or ViewModel | Execute via `RemoteDataSource` on background thread only |
