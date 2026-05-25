# Token Expiry & Refresh Guidelines (OkHttp)

## Purpose

- Automatically handle expired access tokens
- Ensure seamless request retry without user disruption
- Prevent duplicate refresh calls and race conditions

---

## Detection

**Rules:**
- Treat HTTP `401 Unauthorized` as token expiry (unless the request already carried a refresh sentinel header).
- Handle via OkHttp `Authenticator` — not inside `RemoteDataSource` or `Repository`.
- Do not attempt refresh on other error codes.

---

## Token Injection

**Rules:**
- Add access token via `AuthInterceptor` (Authorization header) — never manually in API call sites.
- Always read the latest token from `TokenStore` on every request — do not cache in memory.

---

## Token Refresh Authenticator

```java
// data/datasource/remote/TokenAuthenticator.java
public class TokenAuthenticator implements Authenticator {

    private final TokenStore tokenStore;
    private final AuthApiService authApiService;

    // ✅ Lock prevents multiple simultaneous refresh calls
    private final Object refreshLock = new Object();

    @Inject
    public TokenAuthenticator(TokenStore tokenStore, AuthApiService authApiService) {
        this.tokenStore = tokenStore;
        this.authApiService = authApiService;
    }

    @Nullable
    @Override
    public Request authenticate(Route route, @NonNull Response response) throws IOException {
        // Stop retrying after the first 401 on a refresh attempt
        if (response.request().header("X-Retry-After-Refresh") != null) return null;

        synchronized (refreshLock) {
            // Check again inside the lock — another thread may have already refreshed
            String currentToken = tokenStore.getAccessToken();
            String requestToken = extractBearerToken(response.request());
            if (currentToken != null && !currentToken.equals(requestToken)) {
                // Token was already refreshed by another thread — retry with new token
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
    private String extractBearerToken(Request request) {
        String auth = request.header("Authorization");
        if (auth != null && auth.startsWith("Bearer ")) {
            return auth.substring(7);
        }
        return null;
    }
}
```

---

## Concurrency Control (Critical)

**Rules:**
- Use a `synchronized` block on a dedicated lock object — ensures only one refresh runs at a time.
- Inside the lock, check whether the token was already refreshed by another waiting thread before calling the refresh API.
- If refresh is in progress, other threads block on the lock and then use the freshly refreshed token.
- If refresh succeeds → retry original request with new token.
- If refresh fails → clear all tokens, return `null` (OkHttp will not retry further).

---

## Retry Logic

**Rules:**
- Retry the original request **once** after a successful refresh — use the `X-Retry-After-Refresh` sentinel header to prevent infinite loops.
- Never create an infinite retry loop.
- For POST requests, ensure the request body is reusable (Retrofit handles this by default for `@Body` parameters).

---

## Failure Handling

**Rules:**
- If the refresh token is missing or the refresh call fails:
  - Call `tokenStore.clearTokens()` to remove all stored tokens.
  - Return `null` from `authenticate()` — OkHttp will propagate the 401 to the caller.
  - The Repository receives `AppException.UnauthorizedException` and the ViewModel emits a sign-in prompt.
- Do not attempt further retries after a failed refresh.

---

## Storage

**Rules:**
- Store tokens via `TokenStore`, which encrypts with Keystore-backed AES/GCM — see `android/preferences/datastore.md`.
- `EncryptedSharedPreferences` is **forbidden**.
- Always read the latest token from `TokenStore` before each request — never cache in a field.

---

## Edge Cases

**Rules:**
- Handle app cold start with expired token — the first authenticated request triggers the refresh flow.
- Handle multiple parallel API calls failing simultaneously — only one refresh runs; others wait and reuse the result.
- Ensure idempotency for retried requests — GET and DELETE are inherently idempotent; POST retry is safe only for the token re-attach, not for business logic.

---

## Architecture Rules

- Token refresh logic is fully centralized in `TokenAuthenticator` — no token handling in Repository, UseCase, or ViewModel.
- Repository and UI must not manually handle token refresh.
- The networking layer is fully responsible for the auth lifecycle.
