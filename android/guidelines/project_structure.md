# Project Structure

The canonical structure is defined in `architecture_standard.md` §2. This file is a reference copy. If these conflict, the standard takes precedence.

```
app/
├── data/
│   ├── datasource/
│   │   ├── remote/        # RemoteDataSource classes + Retrofit ApiService interfaces
│   │   └── local/         # LocalDataSource classes + Room DAOs
│   ├── model/             # API response DTOs + Room @Entity classes
│   └── repository/        # RepositoryImpl classes
│
├── domain/
│   ├── model/             # Pure Java domain models — no Android or framework imports
│   ├── repository/        # Repository interfaces — no implementations
│   └── usecase/           # UseCase classes — one class per operation
│
├── ui/
│   ├── screen/            # Activity and Fragment classes
│   ├── components/        # Reusable custom Views and shared XML layout components
│   ├── adapter/           # RecyclerView ListAdapter + DiffUtil classes
│   ├── state/             # UiState abstract classes (Loading / Success / Error)
│   └── viewmodel/         # ViewModel classes
│
└── di/
    └── module/            # NetworkModule, DatabaseModule, RepositoryModule
```

> There is no `network/` top-level layer. OkHttpClient, Retrofit, and all interceptors are instantiated inside `di/module/NetworkModule`. They are infrastructure — they belong in the DI layer.

---

## Key Rules

- Domain models in `domain/model/` must have **zero** Android framework imports. They are plain Java objects.
- Repository interfaces in `domain/repository/` contain only the contract. No implementation detail.
- `data/model/` contains both `@Entity` classes (Room) and DTO classes (Retrofit). Keep their names distinct: `UserEntity` vs `UserResponse`.
- Every feature adds an `Adapter` in `ui/adapter/` if it shows a scrollable list.
- `di/module/` contains exactly three standard modules: `NetworkModule`, `DatabaseModule`, `RepositoryModule`. Feature-specific bindings go in a dedicated feature module, not by polluting the three core modules.
