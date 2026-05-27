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
   - App concept note (concept/app_concept.md)

2. WORK SELECTION
   Read concept/app_concept.md and identify how the work is grouped — it
   may use phases, features, sprints, milestones, or any other term.
   Use whatever term concept/app_concept.md uses throughout this session.

   List every group in a numbered table:

   | # | [Group term from concept note] | Goal | Deliverables |
   |---|-------------------------------|------|--------------|
   | 1 | ...                           | ...  | ...          |
   | 2 | ...                           | ...  | ...          |

   Then ask: "Which one do you want to start with?"
   Wait for the user's answer before continuing.
   Record the chosen group — all subsequent steps apply only to it.

3. DESIGN SYSTEM
   Pull the active Stitch design system and list available screens.
   Note which screens exist and which are still needed for the chosen group.

4. TASK INITIALISATION
   From the chosen group's deliverables in concept/app_concept.md, create a task list
   covering every item. Group tasks by feature area. Mark the first task
   as in_progress.

5. PERSIST TASK LIST
   Write the full task list to tasks/active.md using the standard format
   (In Progress / Completed / Blocked / Next Session sections).
   Include the current group name and its term (e.g. "Phase 1", "Feature: Auth",
   "Sprint 2") at the top of the file.

6. CONFIRM
   State:
   - App name and current group
   - Number of tasks initialised
   - The first task we will tackle today
   - Any design screens that are missing and need to be created in Stitch

Do not write any code until all six steps are confirmed.
```

---

> This prompt is intentionally verbose — it runs once. Every subsequent session uses `reorient.md`, which reads `tasks/active.md` directly without re-summarising guidelines.
> Step 2 (WORK SELECTION) pauses and waits for user input — Claude will not proceed until you reply with a number or name.
