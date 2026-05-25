# Hotfix Workflow

Use this workflow for production bugs that cannot wait for the normal release cycle.
This is not the same as `bug_fixing.md` — the scope, branch strategy, and review bar are different.

---

## When to use this workflow

- A bug is live in production and actively causing data loss, security exposure, or broken core functionality.
- Normal feature branch → develop → release cycle is too slow.
- The fix must go directly to `main` (or the release branch) and be back-merged to `develop`.

If the bug is not urgent or not in production, use `bug_fixing.md` instead.

---

## 1. Branch from the correct base

```bash
git checkout main          # or the active release branch
git pull
git checkout -b hotfix/<short-description>
```

Do **not** branch from `develop` — that would pull in unreleased work.

---

## 2. Reproduce with a failing test

- Write a failing test that captures the exact broken behaviour before changing any code.
- The test must run against the same conditions as production (no mocked-out infrastructure for the broken path).
- Name it: `givenProductionCondition_whenBugOccurs_thenFailsGracefully`

If you cannot reproduce it in a test, document the manual reproduction steps precisely before proceeding.

---

## 3. Fix — minimum viable change only

- Fix the specific defect. Nothing else.
- No refactoring of surrounding code.
- No adding features, improving naming, or tidying unrelated logic.
- No new dependencies.

If you see other problems nearby, file an issue for them — do not fix them here. Every extra line of change is risk in a hotfix.

---

## 4. Verify

```bash
./gradlew test        # full test suite must pass — not just the new test
./gradlew lint        # no new warnings
```

If any pre-existing tests fail, investigate before proceeding — the hotfix may have an unintended side effect.

---

## 5. Commit

Use the format in `templates/commit_message.txt`.
Subject type: `fix(<scope>): <what was wrong>`
No `Co-Authored-By` line. The sole author is YOUR_NAME.

Include in the body:
- What the production impact was
- Why this specific fix is safe (especially if the fix looks minimal or surprising)

---

## 6. Review — fast but not skipped

Hotfix review is narrower than a full PR review:
- [ ] Does the fix address only the reported defect?
- [ ] Are there any regressions in the test suite?
- [ ] Is there any security implication to the fix or the bug?
- [ ] Is the fix safe to deploy without a data migration?

Skip the full architecture checklist from `code_review.md` — correctness and safety are the only gates.

---

## 7. Merge strategy

```bash
# Merge to main (or release branch) first
git checkout main
git merge --no-ff hotfix/<short-description>

# Immediately back-merge to develop so the fix is not lost
git checkout develop
git merge --no-ff main
```

If the back-merge to `develop` conflicts (because `develop` has diverged), resolve carefully — do not discard the hotfix or the in-flight work.

---

## 8. Update tasks/active.md

- Add the hotfix to the Completed section with: what the bug was, what the fix was, production impact.
- If the hotfix revealed a deeper architectural issue, add it to the Blocked or Next Session section.
