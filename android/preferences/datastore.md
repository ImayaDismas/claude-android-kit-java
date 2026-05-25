# DataStore Guidelines

DataStore replaces `SharedPreferences` for all new preference storage. `EncryptedSharedPreferences` is **forbidden** — it uses a deprecated encryption scheme. Use DataStore with Keystore-backed encryption for sensitive values.

---

## Which DataStore Type to Use

| Data | Use |
|---|---|
| Simple key-value pairs (flags, settings, language preference) | Preferences DataStore |
| Auth tokens, sensitive values | Preferences DataStore + Keystore-backed encryption |
| Structured data with type safety | Proto DataStore |
| Relational, queryable, or large data | Room — not DataStore |
| API response cache | Room — not DataStore |

---

## Preferences DataStore Setup

```java
// di/module/PreferencesModule.java
@Module
@InstallIn(SingletonComponent.class)
public class PreferencesModule {

    @Provides
    @Singleton
    public DataStore<Preferences> provideDataStore(@ApplicationContext Context context) {
        return new RxPreferenceDataStoreBuilder(context, "app_prefs").build();
        // Or using the standard API:
        // return PreferenceDataStoreFactory.INSTANCE.create(
        //     new ReplaceFileCorruptionHandler<>(e -> PreferencesKt.emptyPreferences()),
        //     Collections.emptyList(),
        //     () -> new File(context.getFilesDir(), "app_prefs.preferences_pb")
        // );
    }
}
```

> In a Java project, DataStore is most practically accessed via the `DataStore<Preferences>` RxJava2 or RxJava3 adapter, or via direct Java interop with the Kotlin coroutine-based API using `ListenableFuture` adapters. The pattern below uses the `ListenableFuture` approach, which is pure Java.

```java
// Recommended Java pattern using DataStore with ListenableFuture
// Wrap reads/writes in AppExecutors for background threading
```

**Rules:**
- Provide as `@Singleton` via Hilt — creating multiple instances of the same DataStore file causes write conflicts.
- Do not create a DataStore instance manually; let Hilt provide it everywhere it is needed.

---

## TokenStore — Secure Token Storage

Since DataStore's primary API is Kotlin coroutine-based, Java projects should wrap it in a synchronous `TokenStore` backed by `SharedPreferences` encrypted via Keystore AES/GCM, or use `EncryptedFile` for serialized token storage. The key requirement is: **Keystore-backed AES/GCM encryption, never plaintext**.

```java
// security/TokenStore.java
@Singleton
public class TokenStore {

    private static final String PREFS_FILE = "secure_tokens";
    private static final String KEY_ACCESS_TOKEN = "access_token";
    private static final String KEY_REFRESH_TOKEN = "refresh_token";

    private final SharedPreferences securePrefs;
    private final CryptoHelper cryptoHelper;

    @Inject
    public TokenStore(@ApplicationContext Context context, CryptoHelper cryptoHelper) {
        this.cryptoHelper = cryptoHelper;
        // Use application-level encrypted prefs backed by Keystore key
        this.securePrefs = context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE);
    }

    // ✅ Called from OkHttp interceptor (background thread) — synchronous read is safe here
    @Nullable
    public String getAccessToken() {
        String encrypted = securePrefs.getString(KEY_ACCESS_TOKEN, null);
        return encrypted != null ? cryptoHelper.decrypt(encrypted) : null;
    }

    @Nullable
    public String getRefreshToken() {
        String encrypted = securePrefs.getString(KEY_REFRESH_TOKEN, null);
        return encrypted != null ? cryptoHelper.decrypt(encrypted) : null;
    }

    // ✅ Called from background thread only
    public void saveTokens(String accessToken, String refreshToken) {
        securePrefs.edit()
            .putString(KEY_ACCESS_TOKEN, cryptoHelper.encrypt(accessToken))
            .putString(KEY_REFRESH_TOKEN, cryptoHelper.encrypt(refreshToken))
            .apply();
    }

    public void clearTokens() {
        securePrefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .apply();
    }
}
```

**Rules:**
- Encrypt sensitive values before writing — storage files are readable on rooted devices.
- Clear tokens immediately on logout or refresh failure.
- Do not cache decrypted tokens in memory beyond the duration of a single request.
- `TokenStore` reads are safe from OkHttp interceptors (which run on background threads).

---

## CryptoHelper — AES/GCM Encryption

```java
// security/CryptoHelper.java
@Singleton
public class CryptoHelper {

    private final KeystoreHelper keystoreHelper;

    @Inject
    public CryptoHelper(KeystoreHelper keystoreHelper) {
        this.keystoreHelper = keystoreHelper;
    }

    public String encrypt(String plaintext) {
        try {
            SecretKey key = keystoreHelper.getKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key);

            byte[] iv = cipher.getIV();
            byte[] encrypted = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            // Prepend IV to ciphertext for storage: [iv_length(1 byte)][iv][ciphertext]
            byte[] combined = new byte[1 + iv.length + encrypted.length];
            combined[0] = (byte) iv.length;
            System.arraycopy(iv, 0, combined, 1, iv.length);
            System.arraycopy(encrypted, 0, combined, 1 + iv.length, encrypted.length);

            return Base64.encodeToString(combined, Base64.DEFAULT);
        } catch (Exception e) {
            throw new SecurityException("Encryption failed", e);
        }
    }

    public String decrypt(String ciphertext) {
        try {
            byte[] combined = Base64.decode(ciphertext, Base64.DEFAULT);
            int ivLength = combined[0] & 0xFF;
            byte[] iv = Arrays.copyOfRange(combined, 1, 1 + ivLength);
            byte[] encrypted = Arrays.copyOfRange(combined, 1 + ivLength, combined.length);

            SecretKey key = keystoreHelper.getKey();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, iv));

            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new SecurityException("Decryption failed", e);
        }
    }
}
```

---

## General Preferences (Non-Sensitive)

For non-sensitive preferences (feature flags, UI settings, language), use DataStore via its Java-compatible RxJava adapter or simply use unencrypted `SharedPreferences` — they are acceptable for non-sensitive data.

```java
// For non-sensitive preferences — unencrypted SharedPreferences is acceptable
SharedPreferences prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE);
prefs.edit().putString("language", "en").apply();
String language = prefs.getString("language", "en");
```

---

## Forbidden Patterns

| Pattern | Correct Replacement |
|---|---|
| `EncryptedSharedPreferences` | DataStore with Keystore encryption or `TokenStore` with `CryptoHelper` |
| Storing tokens in plain `SharedPreferences` | `TokenStore` with AES/GCM encryption |
| Accessing `TokenStore` from the main thread for heavy operations | Use `AppExecutors.diskIO()` for any non-trivial storage operations |
| Multiple instances of the same DataStore file | Single `@Singleton` provided by Hilt |
| Caching decrypted tokens as instance fields | Always decrypt on demand from storage |
