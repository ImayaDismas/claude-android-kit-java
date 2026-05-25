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

Start work immediately after this check.
```

---

> **At the end of every session**, update `tasks/active.md` before closing:
> - Move completed items to the Completed section
> - Note any blockers discovered
> - Write the next task in the Next Session section
