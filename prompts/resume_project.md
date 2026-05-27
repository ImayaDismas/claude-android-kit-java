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
   - App concept note (concept/app_concept.md)

2. WORK SELECTION
   Read concept/app_concept.md and identify how the work is grouped — it
   may use phases, features, sprints, milestones, or any other term.
   Use whatever term concept/app_concept.md uses throughout this session.

   List every group in a numbered table, marking which are done and which remain:

   | # | [Group term from concept note] | Goal | Status |
   |---|-------------------------------|------|--------|
   | 1 | ...                           | ...  | done / in progress / not started |

   Then ask: "Which one are you currently working on, and which do you want
   to resume?"
   Wait for the user's answer before continuing.
   Record the chosen group — all subsequent steps apply only to it.

3. DESIGN SYSTEM
   Pull the active Stitch design system and list available screens.
   Note which screens exist and which are still missing for the chosen group.

4. RECONSTRUCT TASK STATE
   I will tell you what has been completed and what was in progress.
   Based on that, reconstruct the full remaining task list for the chosen group.
   Group tasks by feature area. Mark the correct task as in_progress.

   What is done: [FILL IN — list completed features or screens]
   What was in progress: [FILL IN — the task that was cut off]
   What is blocked: [FILL IN — anything waiting on a dependency, or leave blank]

5. PERSIST TASK STATE
   Write the reconstructed task list to tasks/active.md using the
   standard format (In Progress / Completed / Blocked / Next Session).
   Include the current group name and its term (e.g. "Phase 1", "Feature: Auth",
   "Sprint 2") at the top of the file.
   Do not overwrite with a blank slate — reflect actual project state.

6. CONFIRM
   State:
   - What is marked as in_progress
   - How many tasks remain in the chosen group
   - Any Stitch screens that are missing and need to be created
   - What we will work on today

Do not write any code until all six steps are confirmed.
```

---

> After this session, use `reorient.md` at the start of every session. This prompt is a one-time bridge — it runs once per project adoption, not once per session.
> Step 2 (WORK SELECTION) pauses and waits for user input — Claude will not proceed until you reply with a number or name.
