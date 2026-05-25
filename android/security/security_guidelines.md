# Security Guidelines

Implementation rules for each security domain. Global security principles are defined in `architecture_standard.md` §12, which takes precedence.

---

## Credentials and Token Storage

| Storage need | Correct mechanism | Forbidden |
|---|---|---|
| Auth tokens (access, refresh) | DataStore with Keystore-backed AES/GCM encryption | `EncryptedSharedPreferences`, plaintext files, `SharedPreferences` |
| Encryption keys | Android Keystore | Hardcoded strings, plaintext files, `BuildConfig` |
| Sensitive user preferences | DataStore with Keystore-backed encryption | `EncryptedSharedPreferences` |

> `EncryptedSharedPreferences` is **forbidden** in new code. It uses a deprecated encryption scheme. Use DataStore with Keystore encryption for all sensitive key-value storage.

**Rules:**
- Never store tokens in `SharedPreferences`, `Bundle`, or `Intent` extras.
- Never log tokens — not even partial values or hashes.
- Clear tokens immediately on logout or refresh failure — do not wait for the next session.
- Read tokens synchronously from `TokenStore` when needed in OkHttp interceptors; do not cache in memory.

---

## Android Keystore

```java
// security/KeystoreHelper.java
public class KeystoreHelper {

    private static final String KEY_ALIAS = "app_master_key";

    @Inject
    public KeystoreHelper() {}

    public void generateKeyIfAbsent() throws GeneralSecurityException {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        if (keyStore.containsAlias(KEY_ALIAS)) return;

        KeyGenerator keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");

        keyGenerator.init(
            new KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(false) // set true only for biometric-gated keys
                .build()
        );
        keyGenerator.generateKey();
    }

    public SecretKey getKey() throws GeneralSecurityException, IOException {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        return (SecretKey) keyStore.getKey(KEY_ALIAS, null);
    }
}
```

**Rules:**
- All encryption keys must be generated and stored in Android Keystore — never in files, DataStore, or memory.
- Use AES/GCM — not AES/CBC (GCM provides authenticated encryption).
- `setUserAuthenticationRequired(true)` only when the key must be gated behind biometric — do not use for app-level encryption keys that need to work in the background.
- Generate the key once and store only the alias — retrieve via `KeyStore.getInstance("AndroidKeyStore")`.

---

## Database Encryption (SQLCipher)

```java
// ✅ Correct — passphrase from Keystore
Room.databaseBuilder(context, AppDatabase.class, "app.db")
    .openHelperFactory(new SupportFactory(keystoreHelper.getDatabasePassphrase()))
    .addMigrations(MIGRATION_1_2)
    // ❌ Never: .fallbackToDestructiveMigration()
    .build();
```

**Rules:**
- All Room databases must use SQLCipher via `SupportFactory`.
- The passphrase must come from Android Keystore — never hardcoded.
- The passphrase must not be stored anywhere other than in Keystore-protected memory.

---

## Biometric Authentication

```java
BiometricPrompt biometricPrompt = new BiometricPrompt(
    activity,
    ContextCompat.getMainExecutor(activity),
    new BiometricPrompt.AuthenticationCallback() {

        @Override
        public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
            Cipher cipher = result.getCryptoObject().getCipher();
            // use cipher to decrypt/encrypt Keystore-protected data
        }

        @Override
        public void onAuthenticationError(int errorCode, @NonNull CharSequence errString) {
            // show error to user — do not swallow silently
        }

        @Override
        public void onAuthenticationFailed() {
            // a single failed attempt — do not lock out yet
        }
    }
);

biometricPrompt.authenticate(promptInfo, new BiometricPrompt.CryptoObject(cipher));
```

**Rules:**
- Use `androidx.biometric.BiometricPrompt` only — never roll a custom biometric flow.
- Always use a `CryptoObject` — do not authenticate without cryptographic purpose.
- Handle all three callbacks: `onAuthenticationSucceeded`, `onAuthenticationError`, `onAuthenticationFailed`.
- Never fall back to PIN/password silently — surface the fallback to the user explicitly.

---

## Network Security

**Rules:**
- HTTPS only — no cleartext connections at any layer.
- Add `android:usesCleartextTraffic="false"` to `AndroidManifest.xml`.
- Certificate pinning for high-value endpoints (auth, payments):

```java
OkHttpClient client = new OkHttpClient.Builder()
    .certificatePinner(
        new CertificatePinner.Builder()
            .add("api.example.app", "sha256/AAAA...")
            .build()
    )
    .build();
```

- Never disable certificate verification for development — use a custom trust manager only in debug builds, never in release.
- `HttpLoggingInterceptor` must be debug-only and must never log `Authorization` headers or response bodies containing tokens.

---

## Input Validation

**Rules:**
- Validate all external inputs at the system boundary: user input, file imports, API responses.
- Do not trust client-side data — validate server-side equivalents too.
- File import (PDF/CSV) must be scanned for valid format before parsing — never pass raw file content to a parser without format validation.
- Reject malformed data before inserting to Room — validate DTOs in `RemoteDataSource`.

---

## Logging and Debugging

**Rules:**
- `Log.*` calls are **forbidden** in release builds — use a logging facade (`Timber` or equivalent) that strips debug logs in release.
- Never log: tokens, passphrases, biometric results, PII (names, phone numbers, amounts), or Room database paths.
- Sanitize error messages before surfacing to the UI — no raw exception messages, file paths, or stack traces.

---

## Build and Release

**Rules:**
- R8 obfuscation mandatory for all release builds.
- `debuggable false` in all release build types.
- Remove all `TODO`, `FIXME`, and debug flags before release.
- `BuildConfig.DEBUG` is the only accepted gate for dev-only code paths.

---

## Dependency Supply Chain

**Rules:**
- Keep all dependencies up to date — run `./gradlew dependencyUpdates` before each release.
- Do not add untrusted or unmaintained libraries — check GitHub activity and CVE history.
- Pin dependency versions — do not use dynamic version ranges (`+`).
