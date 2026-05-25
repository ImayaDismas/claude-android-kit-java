# New Project — Start Prompt

Use this prompt **once** at the beginning of a new project. After this session, use `reorient.md` to continue.

---

```
We are starting a new Android Java project. Complete the following before writing any code:

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
   Note which screens exist and which are still needed for Phase 1.

3. TASK INITIALISATION
   From the app concept's Phase 1 feature list, create a task list covering
   every deliverable. Group tasks by feature area (ledger, reconciliation,
   credit, summary, export, security). Mark the first task as in_progress.

4. PERSIST TASK LIST
   Write the full task list to tasks/active.md using the standard format
   (In Progress / Completed / Blocked / Next Session sections).

5. CONFIRM
   State:
   - App name and current phase
   - Number of Phase 1 tasks initialised
   - The first task we will tackle today
   - Any design screens that are missing and need to be created in Stitch

Do not write any code until all five steps are confirmed.
```

---

> This prompt is intentionally verbose — it runs once. Every subsequent session uses `reorient.md`, which reads `tasks/active.md` directly without re-summarising guidelines.
