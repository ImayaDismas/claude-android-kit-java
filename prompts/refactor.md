# Refactor

Refactor the code provided as a Senior Android Engineer. Follow the pattern in `examples/large_class_refactor.md`.

---

## Before Touching Any Code

1. State which layer the code currently lives in and which layer it should live in after refactoring.
2. Identify every responsibility the class or function currently has.
3. Map each responsibility to the correct layer: domain / data / ui / di.
4. Explain the proposed changes and the trade-offs — wait for confirmation before applying.

---

## Constraints

- Maintain existing behaviour exactly — no logic changes bundled with structural changes.
- Do not introduce new dependencies, libraries, or abstractions not already in the project.
- Do not refactor code outside the scope of what was provided unless a dependency forces it.
- Business logic moves to `domain/usecase/` — not ViewModel, not Repository, not UI.
- If the class is a ViewModel holding DAO or ApiService references, split following the pattern in `examples/large_class_refactor.md`.
- Replace `public MutableLiveData` with a private `MutableLiveData` + public `LiveData` backing field pattern.
- Replace `notifyDataSetChanged()` with `ListAdapter.submitList()` where applicable.

---

## Output Format

For each change:
- State what moved and where it moved to
- State why that layer owns it
- Show the before and after code in Java

Write tests for any logic extracted into a UseCase. Name them `givenX_whenY_thenZ`.
Run `./gradlew test` after applying changes — all existing tests must still pass.
