# Active Tasks

> This file is the cross-session task tracker. Claude reads it at the start of every session via `reorient.md` and updates it before ending each session. Do not summarise guidelines here — just task state.

---

## In Progress

<!-- Claude sets exactly one task here at a time -->

---

## Next Session

<!-- Claude writes the next task to pick up here before closing -->

---

## Blocked

<!-- Note blocker, what it depends on, and when it can unblock -->

---

## Completed

<!-- Move tasks here when done. Format: - [x] Task name — brief outcome note -->

---

## How to use this file

- **Start of session**: paste `reorient.md` prompt — Claude reads this file and loads task state.
- **During session**: Claude moves tasks between sections as work progresses.
- **End of session**: Claude updates In Progress, Blocked, and Next Session before closing.
- **New project**: paste `new_project.md` prompt — Claude initialises this file with Phase 1 tasks.
