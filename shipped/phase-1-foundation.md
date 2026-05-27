# Phase 1: Foundation — Ship Log

**App:** MyApp
**Type:** Phase
**Status:** Shipped
**Started:** 2025-01-10
**Shipped:** 2025-01-24

---

## Summary

Delivered the core authentication flow, local database layer, and DI wiring needed to support all subsequent phases. Users can now register, log in, and have their session persisted securely across app restarts.

---

## Sub-tasks

| # | Sub-task | Area | Status |
|---|----------|------|--------|
| 1 | LoginFragment + ViewBinding | Auth UI | Shipped |
| 2 | RegisterFragment + ViewBinding | Auth UI | Shipped |
| 3 | AuthViewModel + LiveData state | Auth | Shipped |
| 4 | AuthUseCase (login, register, logout) | Domain | Shipped |
| 5 | AuthRepository + RemoteDataSource | Data | Shipped |
| 6 | Retrofit ApiService (auth endpoints) | Networking | Shipped |
| 7 | OkHttpClient + AuthInterceptor | Networking | Shipped |
| 8 | Room database + UserEntity + UserDao | Database | Shipped |
| 9 | Hilt NetworkModule + DatabaseModule | DI | Shipped |
| 10 | Token storage via EncryptedSharedPreferences | Security | Shipped |
| 11 | Biometric unlock fallback | Security | Deferred |
| 12 | AuthViewModel unit tests | Testing | Shipped |
| 13 | AuthRepository unit tests | Testing | Shipped |

---

## Completed

- **LoginFragment** — ViewBinding wired, observes `AuthUiState` via `getViewLifecycleOwner()` *(2025-01-13)*
- **RegisterFragment** — input validation inline, error state mapped to `UiState.Error` *(2025-01-13)*
- **AuthViewModel** — dispatches to `AppExecutors.networkIO()`, posts result via `postValue()` *(2025-01-15)*
- **AuthUseCase** — validates credentials, wraps response in `Result<T>` before returning to ViewModel *(2025-01-15)*
- **AuthRepository** — fetches from remote, persists token to Room before resolving LiveData *(2025-01-17)*
- **Retrofit ApiService** — `@POST /auth/login` and `@POST /auth/register` returning `Call<AuthResponse>` *(2025-01-17)*
- **OkHttpClient + AuthInterceptor** — injects Bearer token; `HttpLoggingInterceptor` debug-only *(2025-01-18)*
- **Room + UserEntity + UserDao** — LiveData reads, diskIO writes, SQLCipher encryption *(2025-01-20)*
- **Hilt modules** — `NetworkModule`, `DatabaseModule`, `RepositoryModule` all `@Singleton` *(2025-01-21)*
- **Token storage** — AES/GCM via CryptoHelper backed by Android Keystore *(2025-01-22)*
- **ViewModel + Repository tests** — `InstantTaskExecutorRule` + `TestAppExecutors`, 84% coverage *(2025-01-24)*

---

## In Progress

*(none — group is shipped)*

---

## Pending

*(none — group is shipped)*

---

## Blocked

*(none)*

---

## Deferred

- **Biometric unlock fallback** — **Reason:** BiometricPrompt integration requires UI design sign-off | **Moved to:** Phase 2: Dashboard

---

## Notes

- Token refresh uses a `synchronized` lock in `TokenAuthenticator` — only one refresh can be in flight at a time. If refresh fails, tokens are cleared and the user is sent to `LoginFragment`.
- `fallbackToDestructiveMigration` was explicitly excluded from the Room config; any schema change in Phase 2 requires a migration file.
- `UserDao.getUser()` returns `LiveData<UserEntity>` — do not call on main thread.
