# Feature Development Workflow

Follow these steps in order for every new feature. Do not skip steps or reorder them.

---

## 1. Confirm Scope

- Read the feature spec in `concept/app_concept_v2.md` before writing anything.
- State the acceptance criteria in plain language before starting.
- Identify which layers are affected: data / domain / ui / di.

---

## 2. Design the Architecture

- Map the data flow for this feature: UI → ViewModel → UseCase → Repository → DataSource.
- Define the domain model (what the UseCase returns).
- Define the `UiState` abstract class: `Loading`, `Success(data)`, `Error(message)`.
- Identify whether this feature needs a new Hilt module or an update to an existing one.
- Identify whether the screen has a list — if so, define the `ListAdapter` and `DiffCallback`.

Explain the plan before writing any code. Do not proceed if the architecture is unclear.

---

## 3. Pull the Stitch Design

- Fetch the relevant screen from Stitch (Favourites only if they exist).
- Confirm the screen exists before writing any XML layout or Fragment code.
- If the screen is missing, flag it — do not invent a layout.

---

## 4. Implement the Domain Layer First

- `UseCase` in `domain/usecase/` — wraps result in `Result<T>`, contains all business logic, one `execute()` method.
- `Repository` interface in `domain/repository/` — defines the contract, no implementation.
- Domain models in `domain/model/` — plain Java classes, no Android imports.

---

## 5. Implement the Data Layer

- `RepositoryImpl` in `data/repository/` — mediates between remote and local sources via `AppExecutors`.
- Room `@Entity` and `@Dao` in `data/model/` and `data/datasource/local/`.
- Retrofit `ApiService` interface in `data/datasource/remote/` (only if network is required).
- All DAO reads return `LiveData<T>`. All DAO writes are `void` — called from `AppExecutors.diskIO()`. No exceptions.
- Network response must be written to Room before the UI observes it (offline-first).
- Update `di/module/` if new bindings are required.

---

## 6. Implement the ViewModel

- Located in `ui/viewmodel/`.
- Private `MutableLiveData<UiState>` backing field; public `LiveData<UiState>` exposed field.
- Calls the UseCase only — no repository or data source references.
- No UI component references, no `Context`, no `View`.
- Background work dispatched via `AppExecutors` — result posted via `postValue()`.
- Error from `Result.error()` maps to `UiState.Error`.

---

## 7. Implement the XML Screen

- XML layout in `res/layout/` — built from the Stitch design.
- Fragment in `ui/screen/` using ViewBinding.
- `binding = null` in `onDestroyView()` — mandatory.
- Observe `LiveData` with `getViewLifecycleOwner()` — mandatory in Fragments.
- Handle all three `UiState` cases: `Loading`, `Success`, `Error`.
- If the screen has a list: create `ListAdapter` and `DiffCallback` in `ui/adapter/`.
- Use `ListAdapter.submitList()` — never `notifyDataSetChanged()`.
- Shared components go in `ui/components/` — do not duplicate across screens.
- Navigate via Navigation Component SafeArgs — never manual `FragmentManager` transactions.

---

## 8. Write Tests

Write tests in this order — most stable layer first:

1. **UseCase tests** — mock the repository interface with Mockito, test business logic in isolation.
2. **ViewModel tests** — use a fake repository, use `InstantTaskExecutorRule` to assert `LiveData` emissions.
3. **Repository tests** — mock remote and local data sources independently.

Naming format: `givenValidInput_whenActionTaken_thenExpectedOutcome`

Target ≥ 80% coverage on UseCase and ViewModel. Do not test framework code.

---

## 9. Run Checks

```bash
./gradlew test        # all unit tests must pass
./gradlew lint        # no new lint warnings
```

Do not proceed to commit if either fails.

---

## 10. Write the Commit

Use the format in `templates/commit_message.txt`.
Subject line: present tense, max 72 chars, explains why — not what files changed.
No `Co-Authored-By` line. The sole author is YOUR_NAME.

---

## 11. Update tasks/active.md

- Move the completed task to the Completed section with a brief outcome note.
- Set the next task as in-progress.
- Note any blockers discovered during this feature.
