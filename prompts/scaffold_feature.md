# Scaffold Feature

Create a new feature following the project architecture strictly.

**Before writing any code:**
1. Pull (from Favourites only if they exist) the relevant screen from Stitch and confirm the design exists.
   If the screen is missing, flag it — do not invent a layout.
2. Confirm which layer owns each piece of the feature before starting.

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
  │   ├── screen/         # Activity and Fragment classes
  │   ├── components/     # Reusable custom Views
  │   ├── adapter/        # RecyclerView ListAdapter + DiffCallback classes
  │   ├── state/          # UiState abstract classes (Loading / Success / Error)
  │   └── viewmodel/      # ViewModel classes
  └── di/
      └── module/         # NetworkModule, DatabaseModule, RepositoryModule
```

> `network/` is not a top-level layer. OkHttpClient, Retrofit, and interceptors live in `di/module/NetworkModule`.

---

## Required Components

- `UseCase` (in `domain/usecase/`) — one class, one `execute()` method
- Repository interface (in `domain/repository/`) + `RepositoryImpl` (in `data/repository/`)
- `ViewModel` (in `ui/viewmodel/`) — `MutableLiveData` private, `LiveData` public
- XML layout + Fragment (in `ui/screen/`) — built from the Stitch design, not invented
- `ListAdapter` + `DiffCallback` (in `ui/adapter/`) if the screen has a list
- `UiState` abstract class (in `ui/state/`) — Loading / Success / Error
- Retrofit `ApiService` interface (in `data/datasource/remote/`) if network is required
- Hilt module update in `di/module/`

---

## Constraints

- Java first — no Kotlin unless a library requires it
- XML layouts + ViewBinding — no Jetpack Compose
- SOLID principles throughout
- Error handling: `Result<T>` wrapper in domain/data layers; `UiState` in ViewModel
- All DAO reads return `LiveData<T>` — all DAO writes are `void` called from `AppExecutors.diskIO()`
- Business logic only in UseCase — none in ViewModel or UI
- State exposed as `LiveData<UiState>` — private `MutableLiveData`, public `LiveData`
- All network calls via `AppExecutors.networkIO()` — never on main thread
- `binding = null` in `onDestroyView()` — mandatory
- `getViewLifecycleOwner()` for all LiveData observation in Fragments
