# Write Commit Message

Write a commit message for the staged changes using the format in `templates/commit_message.txt`.

---

## Steps

1. Read the staged diff to understand what changed and — more importantly — why.
2. Identify the correct `type` and `scope` from the lists in the template.
3. Write the subject line: present tense, max 72 chars, explains the reason not the file list.
4. Write the body only if the why is not obvious from the subject line alone.

---

## Rules

- No `Co-Authored-By` line. Author is YOUR_NAME only.
- No bullet list of files changed — that is what `git diff` is for.
- Subject line must stand alone: a reader with no diff context should understand the intent.
- If the change touches more than one scope, split into separate commits rather than widening the scope.

---

## Output

Return only the commit message — no explanation, no markdown fencing, no commentary.
It should be ready to paste directly into `git commit -m "..."`.
