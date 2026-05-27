# Continue Session

Use this prompt at the **start of every session after the first**. It costs minimal tokens — it reads state, not guidelines.

---

```
Summarise the current task state from tasks/active.md — already loaded in context.

State in three lines:
1. What was in progress when we last stopped
2. What is blocked and why (if anything)
3. What we will tackle first today

Do not summarise architecture, guidelines, or re-read any files — all context is already loaded.
If today's first task involves a UI screen, pull the relevant screen from Stitch before writing any code.

TRANSITION CHECK (run before starting work):
- If tasks/active.md shows no remaining In Progress or Next Session tasks for
  the current group, do not start coding. Instead:
  1. Read concept/app_concept.md for the full list of groups (phases, features,
     sprints, milestones — whatever term it uses).
  2. Present all groups in a table showing which are done and which remain.
  3. Ask: "[Group name] is complete. Which one do you want to tackle next?"
  4. Wait for the user's answer.
  5. Before moving on, write the ship log for the completed group:
     - Create shipped/[group-slug].md using templates/ship_log.md as the base.
     - Populate every section from tasks/active.md and the session history:
       Completed, In Progress (none if fully done), Pending, Blocked, Deferred.
     - Set Status to "Shipped" and fill in the Shipped date.
     - Write a 1–2 sentence Summary capturing what was delivered and why it mattered.
     - Add any architectural decisions or gotchas to the Notes section.
  6. Once the ship log is written, create the task list for the new group in
     tasks/active.md (In Progress / Completed / Blocked / Next Session)
     and update the group name at the top of the file.
  7. Confirm the new group, its first task, and any missing Stitch screens.
- If tasks remain in the current group, start work immediately.
```

---

> **At the end of every session**, update `tasks/active.md` before closing:
> - Move completed items to the Completed section
> - Note any blockers discovered
> - Write the next task in the Next Session section
>
> Also update `shipped/[current-group-slug].md` if one exists for the active group:
> - Move any newly completed sub-tasks to the Completed section with today's date
> - Update the sub-task table status column to reflect current state
> - Log any deferred or blocked items discovered this session
