# Resume Project

Use this prompt when adopting this kit mid-project, or any time `tasks/active.md` is empty but the project is already in progress. Run it once to reconstruct task state, then use `reorient.md` every session after.

---

```
This Android Java project is already in progress. Do not re-initialise from scratch.

1. CONTEXT CHECK
   Confirm you have loaded context for each of the following areas.
   Flag any that are missing — do not proceed if any are absent:
   - Architecture standard + SOLID principles + Android Java stack
   - Networking: OkHttp client + token interceptor (Java)
   - Database: Room + SQLCipher guidelines (Java)
   - Dependency injection: Hilt guidelines (Java)
   - Preferences: secure token storage guidelines
   - Security guidelines
   - Testing guidelines (JUnit 4 + Mockito + InstantTaskExecutorRule)
   - XML UI guidelines (ViewBinding + RecyclerView + Material Components)
   - App concept note (APP_NAME)

2. DESIGN SYSTEM
   Pull the active Stitch design system and list available screens.
   Note which screens exist and which are still missing for Phase 1.

3. RECONSTRUCT TASK STATE
   I will tell you what has been completed and what was in progress.
   Based on that, reconstruct the full remaining Phase 1 task list.
   Group tasks by feature area (ledger, reconciliation, credit,
   summary, export, security). Mark the correct task as in_progress.

   What is done: [FILL IN — list completed features or screens]
   What was in progress: [FILL IN — the task that was cut off]
   What is blocked: [FILL IN — anything waiting on a dependency, or leave blank]

4. PERSIST TASK STATE
   Write the reconstructed task list to tasks/active.md using the
   standard format (In Progress / Completed / Blocked / Next Session).
   Do not overwrite with a blank slate — reflect actual project state.

5. CONFIRM
   State:
   - What is marked as in_progress
   - How many Phase 1 tasks remain
   - Any Stitch screens that are missing and need to be created
   - What we will work on today

Do not write any code until all five steps are confirmed.
```

---

> After this session, use `reorient.md` at the start of every session. This prompt is a one-time bridge — it runs once per project adoption, not once per session.
