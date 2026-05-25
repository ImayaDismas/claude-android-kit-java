# Architecture Prompt

Suggest architecture for this feature as a Senior Android Engineer.

---

## Project Structure

```
android/app/
  ├── data/
  │   ├── datasource/
  │   │   ├── remote/     # RemoteDataSource + Retrofit ApiService interfaces (Call<T>)
  │   │   └── local/      # LocalDataSource + Room DAOs (LiveData reads, void writes)
  │   ├── model/          # API DTOs + Room @Entity classes
  │   └── repository/     # RepositoryImpl classes
  ├── domain/
  │   ├── usecase/        # One class per operation — execute() method
  │   ├── model/          # Pure Java domain models
  │   └── repository/     # Repository interfaces
  ├── ui/
  │   ├── screen/         # Activity and Fragment classes (XML + ViewBinding)
  │   ├── components/     # Reusable custom Views
  │   ├── adapter/        # RecyclerView ListAdapter + DiffCallback classes
  │   ├── state/          # UiState abstract classes
  │   └── viewmodel/      # ViewModel classes
  └── di/
      └── module/         # NetworkModule, DatabaseModule, RepositoryModule
```

> `network/` is not a top-level layer. OkHttpClient, Retrofit, and interceptors live in `di/module/NetworkModule`.

---

## For Each Layer, Define

- Responsibilities (what this layer owns)
- Classes to create and where they live
- How data flows in and out of this layer
- Any constraints or patterns that apply (e.g., `Result<T>` wrapper, `LiveData`, `@Transaction`)

---

## Required Patterns

- Data flow: UI → ViewModel → UseCase → Repository → DataSource
- Business logic only in UseCase
- State: single abstract `UiState` class (Loading / Success / Error) exposed as `LiveData<UiState>`
- Error handling: `Result<T>` wrapper at domain/data boundary; mapped to `UiState.Error` in ViewModel
- Offline-first: Room is the source of truth; network responses write to Room before UI observes them
- Threading: `AppExecutors.networkIO()` for network, `AppExecutors.diskIO()` for Room writes; `LiveData.postValue()` for UI updates
- UI: XML layouts + ViewBinding; RecyclerView + ListAdapter for lists; Navigation Component for screen transitions
