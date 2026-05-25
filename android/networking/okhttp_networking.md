# Networking Guidelines (Retrofit + OkHttp)

## Architecture

Retrofit and OkHttp work as a pair:
- **Retrofit** — defines API endpoints as Java interfaces with `Call<T>` return types; handles serialization (Gson)
- **OkHttp** — underlying HTTP client; owns connection management, interceptors, and auth lifecycle

```
Retrofit interface (ApiService) — Call<T>
    ↓  .execute() on background thread via AppExecutors.networkIO()
OkHttpClient (interceptors, auth, timeouts)
    ↓
Network
```

**Rules:**
- Pass the configured `OkHttpClient` to `Retrofit.Builder` as the client.
- Both instances must be `@Singleton`, provided via Hilt.
- Never instantiate Retrofit or OkHttp outside the DI layer.
- All `Call<T>.execute()` calls must be on a background thread — never on the main thread.
- Never use `Call<T>.enqueue()` from UI code — enqueue in `RemoteDataSource` only.

---

## API Service Interface

```java
// data/datasource/remote/LedgerApiService.java
public interface LedgerApiService {

    @GET("transactions")
    Call<TransactionPageResponse> getTransactions(
        @Query("date") String date,       // ISO 8601: "2024-01-15"
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

## OkHttpClient Setup

```java
@Provides
@Singleton
public OkHttpClient provideOkHttpClient(
        AuthInterceptor authInterceptor,
        TokenAuthenticator tokenAuthenticator) {

    OkHttpClient.Builder builder = new OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .addInterceptor(authInterceptor)
        .authenticator(tokenAuthenticator);

    if (BuildConfig.DEBUG) {
        // ✅ Logging only in debug — never in release
        HttpLoggingInterceptor logging = new HttpLoggingInterceptor();
        logging.setLevel(HttpLoggingInterceptor.Level.BODY);
        builder.addInterceptor(logging);
    }

    return builder.build();
}
```

**Rules:**
- Configure timeouts (connect, read, write) — never use defaults.
- HTTPS only. Add `android:usesCleartextTraffic="false"` to `AndroidManifest.xml`.
- Do not create multiple OkHttpClient instances — one `@Singleton` only.

---

## Interceptors

- Use interceptors for cross-cutting concerns only.

**Types:**
- `AuthInterceptor` — adds `Authorization` header from `TokenStore`
- `HttpLoggingInterceptor` — dev builds only; never log `Authorization` header or token values
- Retry interceptor — controlled retries for idempotent requests only

**Rules:**
- Do not place business logic in interceptors.
- Keep interceptors small and focused on one concern.
- Interceptors execute on the calling (background) thread — no main thread assumptions.

---

## Authentication Interceptor

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
        String token = tokenStore.getAccessToken(); // reads from encrypted storage synchronously

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

## Response Handling in RemoteDataSource

```java
// data/datasource/remote/LedgerRemoteDataSource.java
public class LedgerRemoteDataSource {

    private final LedgerApiService api;

    @Inject
    public LedgerRemoteDataSource(LedgerApiService api) {
        this.api = api;
    }

    // Called from AppExecutors.networkIO() — never on main thread
    public List<TransactionDto> fetchTransactions(String date, int page) throws AppException {
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
        if (code == 403) throw new AppException.NetworkException(code, "Access denied");
        if (code >= 500) throw new AppException.ServerException(code, "Server error");
        throw new AppException.NetworkException(code, "Request failed: " + code);
    }
}
```

---

## Error Handling Rules

- Distinguish: network errors (no connectivity → `IOException`), client errors (4xx), server errors (5xx).
- Map all Retrofit/OkHttp exceptions to `AppException` in `RemoteDataSource` — never let raw exceptions escape.
- No silent failures — every failure must return or throw.

---

## Pagination

- Pass page/limit or cursor tokens via `@Query` parameters.
- Handle end-of-list (empty page response) explicitly.
- Integrate with Paging 3 `PagingSource` where applicable — see `android/samples/paging_api.md`.

---

## Retries

- Retry only idempotent requests (GET, DELETE).
- Limit retry attempts — never retry indefinitely.
- Avoid duplicate POST operations on retry.
- Use `TokenAuthenticator` for 401 refresh-and-retry — see `android/networking/token_interceptor.md`.

---

## Threading Rules

- All `Call<T>.execute()` calls must be wrapped in `AppExecutors.networkIO().execute(() -> { ... })`.
- `RemoteDataSource` methods are blocking by design — callers are responsible for background threading.
- Never call `Call<T>.execute()` from the main thread.
- Never use `Call<T>.enqueue()` in UI code or ViewModels.

---

## Logging Rules

- `HttpLoggingInterceptor` is enabled only in debug builds — gate behind `BuildConfig.DEBUG`.
- Never log `Authorization` header values.
- Never log response bodies containing tokens or PII.

---

## Architecture Rules

- No networking logic in UI, Fragment, Activity, or ViewModel.
- All network calls go through `RemoteDataSource` → `Repository` → `UseCase` → `ViewModel`.
- Responses are mapped to domain models before leaving the Repository — raw DTOs never reach the UI.
