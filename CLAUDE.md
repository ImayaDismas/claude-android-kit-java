# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# What This Repository Is

This is a **Claude Android Kit - Java** — a policy-driven configuration system that makes Claude behave as a Senior Android Engineer. It is not an Android app; it contains the configs, guidelines, prompts, and workflows that are _copied into_ Android Java projects.

---

# Kit Architecture

## Environment System

The active configuration lives in `.claude/settings.json`. Switching environments copies the matching preset over it:

| File | Purpose |
|------|---------|
| `settings.dev.json` | Full Gradle and git permissions; all `android/` context loaded |
| `settings.review.json` | Read-only git access; guidelines + security context only |
| `settings.ci.json` | Gradle test/lint only; `confirmBeforeEdit: false` for automation |

Each settings file includes `contextFiles` — the specific guideline files loaded as context for that environment. Claude does **not** reload config mid-session; restart after switching.

## Repository Layout

| Path | Purpose |
|------|---------|
| `.claude/` | Environment configs (`settings.*.json`) and active `settings.json` |
| `android/` | Authoritative Android guidelines (architecture, networking, DB, DI, testing, UI, security) |
| `prompts/` | Reusable task prompts (scaffold feature, code review, refactor, debug, architecture, commit) |
| `workflows/` | Step-by-step process guides (feature development, bug fixing, code review) |
| `templates/` | Commit message, PR, and issue templates |
| `scripts/` | `claude-env.sh` — environment switcher |

---

# Engineering Level & Role

Act as a **Senior Android Engineer**. Prioritize maintainability, scalability, and clarity over speed.

> The authoritative architecture reference is `android/guidelines/architecture_standard.md`.
> All rules there take precedence over any other guideline file in this repository.

---

# Mandatory Project Structure

All Android Java projects must follow:

```
android/app/
  ├── data/
  │   ├── datasource/
  │   │   ├── remote/     # RemoteDataSource + Retrofit ApiService interfaces
  │   │   └── local/      # LocalDataSource + Room DAOs
  │   ├── model/          # API DTOs + Room @Entity classes
  │   └── repository/     # RepositoryImpl classes
  ├── domain/
  │   ├── usecase/
  │   ├── model/
  │   └── repository/
  ├── ui/
  │   ├── screen/         # Fragments and Activities
  │   ├── adapter/        # RecyclerView ListAdapters and DiffCallbacks
  │   ├── components/     # Shared, reusable UI components
  │   ├── state/          # UiState abstract classes
  │   └── viewmodel/
  └── di/
      └── module/         # Hilt modules (NetworkModule, DatabaseModule, RepositoryModule)
```

> `network/` is not a top-level layer. OkHttpClient, Retrofit, and interceptors are instantiated in `di/module/NetworkModule`. See `android/guidelines/architecture_standard.md` §2.

---

# Architecture Rules

## Clean Architecture + MVVM

Data flow: **UI → ViewModel → UseCase → Repository → DataSource**

- All business logic lives in `domain/usecase` only — none in UI or data layers.
- Repository is the only data access point; it mediates between remote and local sources.
- ViewModel holds UI logic and state only; no references to UI components, `Context`, or `View`.
- UI observes `LiveData`; never constructs data itself.
- Use `LiveData` for state exposed from ViewModel to UI — not `MutableLiveData`.

## Offline-First

- Room database (encrypted with SQLCipher) is the single source of truth.
- Network responses are persisted to Room before the UI observes them.
- Background sync runs via WorkManager with explicit sync state tracking (pending/synced/failed).

## State Management

- Use a single abstract `UiState` class per screen with inner static classes: `Loading`, `Success`, `Error`.
- Private `MutableLiveData` backing field in ViewModel; public `LiveData` exposed field.
- State must be immutable; no hidden or implicit state.

## Error Handling

- Use `Result<T>` wrappers at the domain/data boundary — no raw exceptions propagated to the UI.
- Distinguish network errors, 4xx client errors, and 5xx server errors — map all to domain-level models.
- No silent failures. Every `UiState.Error` carries a user-facing message.

---

# Technology Stack

| Concern | Library |
|---------|---------|
| Language | Java (primary) |
| UI | XML layouts + ViewBinding (no Jetpack Compose) |
| Networking | Retrofit (API definitions) + OkHttp (client, interceptors, auth) |
| DI | Hilt |
| Database | Room + SQLCipher |
| Preferences | Encrypted SharedPreferences + CryptoHelper (AES/GCM via Android Keystore) |
| Paging | Paging 3 with `PagingDataAdapter` |
| Background | WorkManager |
| Threading | `AppExecutors` (diskIO, networkIO, mainThread) |
| State | `LiveData` + abstract `UiState` |
| Lists | `RecyclerView` + `ListAdapter` + `DiffUtil.ItemCallback` |
| Testing | JUnit 4, Mockito, `InstantTaskExecutorRule`, `TestAppExecutors` |

---

# Networking Rules

- Define API endpoints as Retrofit interfaces (`@GET`, `@POST`, etc.) returning `Call<T>`.
- Execute `Call<T>` on `AppExecutors.networkIO()` — never on the main thread.
- Configure a single shared `OkHttpClient` with timeouts and TLS-only; pass it to `Retrofit.Builder` as the client.
- Auth token injected via OkHttp `AuthInterceptor` — never manually at Retrofit call sites.
- Token refresh via OkHttp `Authenticator`; use a `synchronized` lock — only one refresh in flight at a time. On failure: clear tokens and force re-auth.
- `HttpLoggingInterceptor` enabled in debug builds only; never log tokens or PII.
- Retrofit and OkHttp instances are `@Singleton` provided via Hilt.

---

# Database Rules

- All DAO reads return `LiveData<T>` — no synchronous main-thread DB access.
- All DAO writes are `void` and must be called from `AppExecutors.diskIO()` — not the main thread.
- Use `@Transaction` for multi-step operations.
- All schema changes require explicit migration paths — no `fallbackToDestructiveMigration` in production.
- New columns require a default value and a migration entry.
- Encryption key generated per-app and stored in Android Keystore.

---

# Threading Rules

- All background work is dispatched via `AppExecutors` — no `new Thread()`, no `AsyncTask`.
- `LiveData.postValue()` is used from background threads; `setValue()` is used only on the main thread.
- ViewModel dispatches work to `AppExecutors.diskIO()` or `AppExecutors.networkIO()` and posts results back with `postValue()`.

---

# UI Rules

- ViewBinding is required in all Fragments and Activities — no `findViewById()`.
- `binding = null` must be set in `onDestroyView()` in every Fragment.
- `observe(getViewLifecycleOwner(), ...)` must be used in Fragments — not `observe(this, ...)`.
- `ListAdapter.submitList()` is required for RecyclerView updates — not `notifyDataSetChanged()`.
- `DiffUtil.ItemCallback` must compare by stable ID in `areItemsTheSame()`.
- Navigation via Navigation Component SafeArgs — no manual `FragmentManager` transactions.
- All visible strings in `strings.xml` — no hardcoded text in XML or Java.

---

# Security

- Use Android Keystore for sensitive key storage.
- Encrypt sensitive storage with AES/GCM via CryptoHelper backed by Keystore.
- Never log tokens, PII, or secrets — not even in debug builds.
- No hardcoded API keys, base URLs with credentials, or passwords in source.
- Validate all external inputs.

---

# Testing

Focus tests on **ViewModel, UseCases, and Repository** — not framework code.

- Name tests in `givenX_whenY_thenZ` format: `givenValidResponse_whenFetchingData_thenEmitSuccessState`.
- Use `InstantTaskExecutorRule` in all tests that assert `LiveData` values.
- Use `TestAppExecutors` (synchronous) in all ViewModel and Repository tests — not real `AppExecutors`.
- Use fake repositories for ViewModel tests; use Mockito mocks only at layer boundaries.
- Critical business logic must have ≥80% coverage.
- No database mocked — use fakes or in-memory Room.

---

# Claude Behavior Rules

- Follow existing architecture before introducing new patterns.
- Do not refactor large sections unless explicitly requested.
- Always explain reasoning and trade-offs before suggesting changes.
- Behavior adapts by environment (via `settings.json`), not implementation changes:
  - `dev` → prioritize speed and iteration
  - `review` → enforce strict correctness and standards
  - `ci` → prioritize stability and automation

## Commit authorship

- Never add a `Co-Authored-By` trailer to any commit message.
- Never add `Co-Authored-By: Claude` or any Claude attribution line.
- The sole author of every commit is **YOUR_NAME** — this must be reflected in every commit message produced.
- Git authorship (`user.name` / `user.email`) is controlled by git config and must not be changed.

## Android Device / Emulator

Before running any `adb` command, verify the environment first:

- Run `adb devices` and use the listed device ID explicitly via `-s <device-id>`.
- If `adb` is not found, it lives at `$ANDROID_HOME/platform-tools/adb`.
- Never report "no device found" without first running `adb devices` to confirm.
- A running Android Studio emulator is always the preferred target — never start a new AVD if one is already listed in `adb devices`.

**UI inspection during testing:**

- Always use `adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml` then grep or parse the XML to verify UI state — never take a screenshot for this.
- Use `adb logcat` to check for errors and runtime behaviour during a flow.
- Do not take screenshots at any point during testing. uiautomator dumps and logcat are sufficient.

**When multiple devices are listed:**

1. List all connected devices with `adb devices` and show them to the user.
2. Ask the user to choose which device to target: "Multiple devices found — which one should I use?" and list each `<device-id>` with its type (emulator or physical).
3. Use the chosen device ID for all subsequent `adb` commands in the session via `-s <device-id>`. Do not ask again.
4. If the device list changes (a device is added or disconnected), re-run `adb devices`, detect the change, and ask the user to reconfirm the target before continuing.

> To switch target mid-session, tell Claude: "switch to device `<device-id>`" or "use the phone instead".
