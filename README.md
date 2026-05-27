# Claude Android Kit - Java
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/ImayaDismas/claude-android-kit-java)](https://github.com/ImayaDismas/claude-android-kit-java/releases)

A policy-driven configuration system that turns Claude Code into a consistent, project-aware Senior Android Engineer. Copy it into any Android Java project and Claude will follow your architecture, not its defaults.

---

## What This Is

This is not an Android Java app. It is a kit of configs, guidelines, prompts, and workflows that you **copy into your Android Java project**. Once in place, Claude Code reads them automatically and behaves as a senior engineer who knows your stack, your patterns, and your rules.

The kit enforces Java-first, XML-first Android development: Clean Architecture + MVVM, Room + Retrofit, LiveData, AppExecutors threading, ViewBinding, RecyclerView with ListAdapter, and Hilt DI — the patterns that hold up in large, long-lived enterprise codebases.

---

## Repo Layout

| Folder / File | Purpose |
|---------------|---------|
| `.claude/` | Claude Code settings — active `settings.json` plus environment presets (`dev`, `review`, `ci`) |
| `android/` | Authoritative Android guidelines — architecture, networking, database, DI, testing, security, UI |
| `concept/` | App concept documentation — start here before writing any code |
| `prompts/` | Reusable task prompts — new project start, session continue, scaffold a feature, review code, write a commit message, debug, refactor |
| `tasks/` | Cross-session task tracker — `active.md` persists what is in progress, blocked, and next across Claude sessions |
| `shipped/` | Ship logs — one `.md` file per completed group (phase, feature, sprint, milestone) recording what was delivered, deferred, and any architectural decisions worth preserving |
| `workflows/` | Step-by-step process guides Claude follows automatically — feature development, bug fixing, hotfix, code review, CI failure triage |
| `templates/` | Commit message format with examples, PR template, and issue template — Claude uses these automatically when committing, opening PRs, or filing issues |
| `examples/` | Annotated before/after examples of correct patterns — large class refactor, LiveData + UiState, offline-first repository, Hilt modules |
| `android/samples/` | Complete working code samples — `xml_fragment_screen.md`, `okhttp_api.md`, `paging_api.md`. Reference material; read on demand, not auto-loaded |
| `scripts/` | `claude-env.sh` (environment switcher) and `install-hooks.sh` (git hooks installer) |
| `CLAUDE.md` | Claude's primary instructions — loaded automatically on every session |

---

## Start Here: Document Your Concept

Before writing any code, document what you are building in the `concept/` folder.

**Step 1 — Open the template:**
```
concept/app_concept.md
```

This file is a blank starting point. Fill it in with:
- What problem your app solves
- Who it is for
- What the core features are
- What phases you plan to build in

**Step 2 — Paste or write your concept into the file.**
Claude will read it automatically in every dev session once the kit is applied to your project.

**Step 3 — When your concept is refined, save the updated version:**
```
concept/app_concept_v2.md   ← your working concept note
concept/app_concept.md      ← keep as the blank template for others
```

> The concept folder is for planning — it does not affect the app code. You can safely gitignore it if you do not want it committed to your Android Java project (see below).

---

## Applying This Kit to an Android Java Project

Copy everything your Android Java project needs. At minimum:

```bash
# Navigate to your Android Java project root
cd /path/to/your/android/project

# Copy Claude settings and guidelines
cp -r /path/to/claude-android-kit-java/.claude ./
cp -r /path/to/claude-android-kit-java/android ./
cp -r /path/to/claude-android-kit-java/concept ./
cp -r /path/to/claude-android-kit-java/prompts ./
cp -r /path/to/claude-android-kit-java/tasks ./
cp -r /path/to/claude-android-kit-java/shipped ./
cp -r /path/to/claude-android-kit-java/workflows ./
cp -r /path/to/claude-android-kit-java/templates ./
cp -r /path/to/claude-android-kit-java/examples ./
cp -r /path/to/claude-android-kit-java/scripts ./
cp    /path/to/claude-android-kit-java/CLAUDE.md ./

# Make scripts executable
chmod +x scripts/claude-env.sh scripts/install-hooks.sh

# Install git hooks
./scripts/install-hooks.sh
```

> Requires `jq`. Install if missing:
> ```bash
> brew install jq          # macOS
> sudo apt-get install jq  # Ubuntu / Debian
> ```

---

## Personalise Before First Use

After copying, replace `YOUR_NAME`, `YOUR_EMAIL`, and `APP_NAME` across the files below. Claude reads all of them and uses them when writing commits and generating app-specific code.

**Files to update:**

| File | What to replace |
|------|----------------|
| `templates/commit_message.txt` | `YOUR_NAME` (×2) and `YOUR_EMAIL` (×1) |
| `CLAUDE.md` | `YOUR_NAME` (×1) in the `Commit authorship` section |
| `workflows/feature_development.md` | `YOUR_NAME` (×1) in step 10 |
| `workflows/bug_fixing.md` | `YOUR_NAME` (×1) in step 5 |
| `workflows/hotfix.md` | `YOUR_NAME` (×1) in step 5 |
| `prompts/new_project.md` | `APP_NAME` (×1) |
| `prompts/resume_project.md` | `APP_NAME` (×1) |
| `examples/offline_first_repository.md` | `APP_NAME` (×1) |
| `android/di/hilt_guidelines.md` | `APP_NAME` (×1) |

You can replace them all at once from your project root:

```bash
# Replace YOUR_NAME (do this first, then update YOUR_EMAIL separately)
grep -rl "YOUR_NAME" templates/ CLAUDE.md workflows/ | xargs sed -i '' 's/YOUR_NAME/Jane Smith/g'

# Replace YOUR_EMAIL
sed -i '' 's/YOUR_EMAIL/jane@example.com/g' templates/commit_message.txt

# Replace APP_NAME
grep -rl "APP_NAME" prompts/ examples/ android/ | xargs sed -i '' 's/APP_NAME/MyApp/g'
```

Or open each file and replace manually.

**Confirm your git config is set correctly:**

```bash
git config user.name   # should return your name
git config user.email  # should return your email
```

If not set, configure them:

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

> Git authorship (who appears in `git log` and GitHub blame) is controlled by `git config` — not by the template. The template tells Claude whose name to use in commit messages and confirms no `Co-Authored-By` line is added.

---

## Updating the Kit on a Running Project

When the kit itself changes (guidelines updated, new examples added, settings revised), re-copy the changed folders to your Android Java project and restart Claude. Your app code is untouched — only Claude's configuration and reference files change.

```bash
# Re-copy updated kit folders — overwrites old versions, leaves your app code alone
cd /path/to/your/android/project

cp -r /path/to/claude-android-kit-java/.claude ./
cp -r /path/to/claude-android-kit-java/android ./
cp -r /path/to/claude-android-kit-java/prompts ./
cp -r /path/to/claude-android-kit-java/workflows ./
cp -r /path/to/claude-android-kit-java/templates ./
cp -r /path/to/claude-android-kit-java/examples ./
cp    /path/to/claude-android-kit-java/CLAUDE.md ./
```

> Do **not** re-copy `tasks/` or `shipped/` — those folders hold your project's task state and ship logs. Overwriting them clears your in-progress history and delivery records.

After re-copying, check if any new files introduced new `YOUR_NAME` or `YOUR_EMAIL` placeholders:

```bash
grep -rl "YOUR_NAME" workflows/ templates/ CLAUDE.md
grep -rl "YOUR_EMAIL" templates/
```

Replace any found — then restart Claude to load the updated context.

### After updating the kit: which session prompt to use?

| State of `tasks/active.md` | Prompt |
|-----------------------------|--------|
| Has content from before the update | `prompts/reorient.md` — task state is intact; just start working |
| **Empty** (no prior state) | `prompts/resume_project.md` — fill in what is done and what was in progress; runs once to rebuild state |

---

## Keeping Kit Files Out of Your Android Java Project's Git History

The kit files are Claude's configuration — they are not your app's source code. If you do not want them committed to your Android Java project repo, add this block to your project's `.gitignore`:

```gitignore
# Claude Android Kit - Java — local AI configuration, not app source
.claude/
android/
prompts/
tasks/
shipped/
workflows/
templates/
scripts/
concept/
examples/
CLAUDE.md
```

> **Team note:** If you want all developers on a team to share the same Claude behaviour automatically, commit `.claude/` and `android/` instead of ignoring them. The `android/` guidelines are what Claude reads as context — without them in the repo, each developer must copy the kit manually.

---

## Environment Switching

The active configuration lives in `.claude/settings.json`. Manage it with `claude-env.sh`:

```bash
./scripts/claude-env.sh            # Auto-detect env from current branch and switch
./scripts/claude-env.sh dev        # Switch to dev — full Gradle and git permissions
./scripts/claude-env.sh review     # Switch to review — read-only, strict standards
./scripts/claude-env.sh ci         # Switch to CI — test/lint only, no confirmations
./scripts/claude-env.sh status     # Show current active environment (no changes made)
./scripts/claude-env.sh list       # List all environments and branch mappings
./scripts/claude-env.sh help       # Show full usage
```

Switching automatically kills any running Claude sessions. Run `claude` afterwards to start fresh with the new config.

### Auto-detect: branch → environment

If no argument is given, the script reads the current branch and picks the environment:

| Branch pattern | Environment |
|----------------|-------------|
| `main`, `release/*`, `hotfix/*` | `review` |
| `develop`, `feature/*`, `bugfix/*` | `dev` |
| `ci`, `ci/*` | `ci` |
| (anything else) | `dev` (default) |

### Checking the current environment

```bash
./scripts/claude-env.sh status
```

Reports the active environment, current branch, and any running Claude sessions — without making any changes.

> Claude does not reload config mid-session. Always restart after switching environments.

---

## Git Hooks — Automatic Environment Switching

Hook templates live in `scripts/hooks/` and are version-controlled. Install once:

```bash
chmod +x scripts/install-hooks.sh
./scripts/install-hooks.sh
```

Re-run `install-hooks.sh` after pulling kit updates to pick up hook changes.

| Hook | Trigger | Behaviour |
|------|---------|-----------|
| `post-checkout` | Branch switch | Detects new branch, switches env, kills any running Claude sessions |
| `post-merge` | `git merge` / `git pull` | Re-applies env for current branch, kills any running Claude sessions |

---

## Environments at a Glance

| Environment | Best for | Permissions |
|-------------|----------|-------------|
| `dev` | Feature work, fast iteration | Full Gradle, git read/write, all guidelines loaded |
| `review` | Code review, PR feedback | Read-only git, guidelines + security context only |
| `ci` | Automated pipelines | Gradle test/lint only, `confirmBeforeEdit: false` |

---

## MCP Servers — Connecting External Tools

Claude Code connects to remote AI tools via the [Model Context Protocol](https://modelcontextprotocol.io). The `dev` environment is pre-configured to allow **Stitch** — Google's AI UI generator that creates XML/Compose screens from text prompts directly inside your Claude session.

MCP servers are registered via the `claude mcp add` CLI command, which saves them to `~/.claude.json` (user scope) or `.mcp.json` (project scope). Credentials are stored in a separate credentials file outside the repo — no secrets ever land in settings files or git history.

---

### Setup: Stitch (Google AI UI Generator)

**Step 1 — Get your API key**

1. Go to [stitch.withgoogle.com](https://stitch.withgoogle.com) and sign in
2. Open **Settings → API Keys**
3. Click **Create API Key** and copy the key immediately — it is shown only once

**Step 2 — Copy the credentials template to your home directory**

```bash
cp .mcp-credentials.sample ~/.mcp-credentials
chmod 600 ~/.mcp-credentials
```

> `chmod 600` makes the file readable only by you. Do this every time you create a credentials file.

**Step 3 — Open the file and add your key**

```bash
nano ~/.mcp-credentials
```

Replace the placeholder on this line:

```bash
export STITCH_API_KEY="your-stitch-api-key-here"
```

**Step 4 — Source the file from your shell profile**

Add this line to `~/.zshrc` (or `~/.bashrc`):

```bash
[ -f ~/.mcp-credentials ] && source ~/.mcp-credentials
```

Then reload immediately:

```bash
source ~/.zshrc
```

**Step 5 — Register Stitch via the CLI**

```bash
# Confirm the key is loaded
echo $STITCH_API_KEY

# Register the server (saves to ~/.claude.json — available in all projects)
claude mcp add stitch \
  --transport http https://stitch.googleapis.com/mcp \
  --header "X-Goog-Api-Key: $STITCH_API_KEY" \
  -s user
```

> `-s user` registers the server globally for your account. Use `-s project` instead to create a `.mcp.json` in the project root and limit it to this repo only.

**Step 6 — Restart Claude Code and verify**

```
/mcp
```

`stitch` should appear with status `connected`. If it shows `failed`, check that `STITCH_API_KEY` is set (`echo $STITCH_API_KEY`) and re-run Step 5.

---

### Using Stitch With Your Existing Project

Once connected, you don't invoke tools manually — just talk to Claude naturally:

**Find your project:**
```
List my Stitch projects
```

**Inspect what's already there:**
```
List all screens in my [project name] Stitch project
```

**Generate a new XML screen:**
```
In my Stitch project [project ID], generate a screen for a
transaction history list — each item shows merchant name,
amount, date, and a status badge (pending/completed/failed).
Use Material Components and match our existing design system.
```

**Edit an existing screen:**
```
Edit the login screen in project [project ID] — replace the
email field with a phone number input and add an OTP step below it
```

**Generate variants to compare options:**
```
Generate 3 variants of the dashboard screen in project [project ID] —
vary the card layout and color hierarchy, keep the same data
```

---

### Adding Future MCP Servers

Every new server follows the same pattern:

**1. Add credentials to `~/.mcp-credentials`**

Uncomment and fill in the relevant block (GitHub, Linear, Slack, etc.):

```bash
nano ~/.mcp-credentials
source ~/.zshrc
```

**2. Register via the CLI**

For remote HTTP servers:

```bash
claude mcp add <server-name> \
  --transport http https://your-mcp-endpoint/mcp \
  --header "X-Api-Key: $YOUR_API_KEY" \
  -s user
```

For local servers (running via npx):

```bash
claude mcp add <server-name> \
  --command npx -- -y @scope/package-name \
  -s user
```

**3. Allow the server's tools in `permissions.allow` in `.claude/settings.dev.json`**

```json
"mcp__server-name__*"
```

**4. Restart Claude Code and verify with `/mcp`**

---

### Security: Threats and Mitigations

| Threat | Mitigation |
|--------|------------|
| API key committed to git | `.mcp-credentials` is in `.gitignore`; only `.mcp-credentials.sample` (no real values) is committed |
| Key exposed in settings files | MCP servers are registered via CLI — no keys ever appear in settings files |
| Key readable by other processes | `chmod 600 ~/.mcp-credentials` — owner-read-only; no group or world access |
| Key accidentally logged by Claude | The `deny` rules in `settings.dev.json` block Claude from reading `.env` and `.env.*` files |
| Key exposed if machine is stolen or shared | Rotate immediately from the Stitch Settings page; update the one line in `~/.mcp-credentials` and re-run `claude mcp add` |
| OAuth token expiry causing silent failures | Use **API Keys, not OAuth** — OAuth tokens expire hourly and require manual copy-paste to refresh; API Keys are persistent |
| Key leaked via shell history | The key is sourced from a file, not typed inline — it never appears in `~/.zsh_history` |

---

### Why API Keys, Not OAuth

The Stitch docs offer both. For a personal dev machine, **API Keys are the correct choice**:

- OAuth tokens expire every hour and require manually copying a new token into config each time
- API Keys are persistent — set once, work indefinitely until you revoke them
- OAuth is designed for zero-trust or ephemeral environments (CI runners, shared machines) — not a personal laptop

---

## How Guidelines Are Loaded — No Action Needed

You do not need to tell Claude to read the guidelines. The `contextFiles` array in `.claude/settings.json` lists every guideline file. Claude Code reads all of them **automatically at the start of every session**, before you type anything.

```json
"contextFiles": [
  "CLAUDE.md",
  "android/guidelines/architecture_standard.md",
  "android/guidelines/jetpack_stack.md",
  "android/database/database_guidelines.md",
  "android/di/hilt_guidelines.md",
  "android/networking/okhttp_networking.md",
  "android/security/security_guidelines.md",
  "android/testing/testing_guidelines.md",
  "android/ui/xml_guidelines.md",
  "concept/app_concept_v2.md"
]
```

Claude enters every session already knowing your architecture rules, stack, security constraints, and app concept. You just start working.

> **If guidelines change mid-session** (e.g. you edit a guideline file while Claude is running), restart Claude to reload them. Config is read once at session start.

### Restarting Claude

| Surface | Command |
|---------|---------|
| **CLI** | Press `Ctrl+C` to exit, then run `claude` to start a fresh session |
| **VS Code extension** | Click the `+` (New Conversation) button in the Claude panel, or run **Claude: New Conversation** from the command palette (`Cmd+Shift+P`) |
| **In-session (soft reset)** | Type `/clear` — clears conversation history and re-reads `contextFiles` without closing Claude |

> `/clear` is the fastest restart. Use it after switching environments or editing a guideline file.

---

## Session Workflow

Guidelines load automatically — you never need to ask Claude to re-read them. The only thing to manage is **task state**, which does not survive between sessions.

### Starting a new project (run once)

Use this when `tasks/active.md` is empty and no code has been written yet — the very first session on a new project.

Paste the contents of `prompts/new_project.md` into Claude.

What it does in one shot:
- Verifies all context areas are loaded (flags any gaps before you start)
- Lists all groups (phases, features, sprints, milestones) from `concept/app_concept.md` and asks which to start with
- Pulls the active Stitch design system and lists available screens for the chosen group
- Builds a task list from the chosen group's deliverables and writes it to `tasks/active.md`
- Confirms what you are building and what you are starting with today

This prompt is intentionally thorough — it runs **once** per project. After this, use `reorient.md` every session.

---

### Resuming a project already in progress (run once)

Use this when adopting the kit mid-project or when `tasks/active.md` is empty but work is already underway — for example, after a long break or switching machines.

Paste the contents of `prompts/resume_project.md` into Claude, filling in the two placeholders:
- **What is done** — list the features or screens already completed
- **What was in progress** — the task that was cut off

What it does:
- Verifies all context areas are loaded
- Lists all groups from `concept/app_concept.md` and asks which to resume
- Pulls the active Stitch design system
- Reconstructs the task list for the chosen group from what you tell it, marking the right task as in-progress
- Writes the reconstructed state to `tasks/active.md`

After this session, switch to `reorient.md` — this prompt is a one-time bridge, not a recurring start.

---

### Continuing an ongoing session (every session after the first)

Use this at the start of every normal session — including after a rate-limit interruption, closing Claude mid-task, or picking up the next day. As long as `tasks/active.md` has state, this is all you need.

Paste the contents of `prompts/reorient.md` into Claude.

What it does:
- Summarises task state from `tasks/active.md` — already in context, no file read needed
- States in-progress, blocked, and next in three lines
- Checks if the current group is complete; if so, lists remaining groups and asks which to tackle next, writes the ship log for the finished group, then initialises the new group's task list
- Starts work immediately if tasks remain in the current group

It does **not** re-summarise guidelines or read files — both are already loaded by the harness. The prompt is a few lines of direction, not a context-loading operation.

**At the end of every session**, Claude updates two files:
- `tasks/active.md` — moves completed items, notes blockers, writes the next task
- `shipped/[group-slug].md` — updates completed sub-tasks with today's date, logs any new deferrals or blockers discovered this session

---

### Task file: `tasks/active.md`

| Section | Purpose |
|---------|---------|
| In Progress | Exactly one task — what Claude is working on right now |
| Next Session | First task to pick up at the start of the next session |
| Blocked | Tasks that cannot proceed and why |
| Completed | Done tasks with a brief outcome note |

### Ship log: `shipped/[group-slug].md`

Created automatically by Claude when a group is fully complete (during the TRANSITION CHECK in `reorient.md`). One file per group, named after the group — e.g. `shipped/phase-1-foundation.md`, `shipped/feature-auth.md`. Use `templates/ship_log.md` as the base if creating manually.

| Section | Purpose |
|---------|---------|
| Summary | 1–2 sentences on what was delivered and why it mattered |
| Sub-tasks | Table of every sub-task with its final status |
| Completed | Done sub-tasks with delivery date and a brief note |
| In Progress | Sub-tasks still running (empty once the group is shipped) |
| Pending | Sub-tasks not yet started |
| Blocked | Sub-tasks that could not proceed and why |
| Deferred | Sub-tasks consciously pushed to a later group, with destination |
| Notes | Architectural decisions, trade-offs, and gotchas worth preserving |

---

## How Claude Uses This Kit

| What controls Claude | How |
|----------------------|-----|
| Behaviour & rules | `CLAUDE.md` |
| Domain knowledge | `android/` guidelines — auto-loaded via `contextFiles` at session start |
| Process | `workflows/` — auto-loaded per environment; Claude follows the correct process for features, bugs, hotfixes, reviews, and CI failures without being asked |
| Output format | `templates/` — auto-loaded; Claude uses the correct commit, PR, and issue format automatically |
| Architecture patterns | `examples/` — auto-loaded in dev; Claude knows the correct pattern for LiveData + UiState, offline-first repositories, Hilt modules, and class refactoring |
| Working code samples | `android/samples/` — not auto-loaded; read on demand when building a specific screen, API setup, or paged list |
| Task state | `tasks/active.md` — auto-loaded in dev; persists what is in progress across sessions |
| Permissions | `settings.json` — what Claude is allowed to run |
| Environment | `claude-env.sh` swaps `settings.json` presets |
| Trigger prompts | `prompts/` — paste into Claude to start a session, scaffold a feature, debug, or review |

---

## Quick Reference

### Session prompts

| When | Prompt file |
|------|-------------|
| First time on a new project | `prompts/new_project.md` — verifies context, pulls Stitch, initialises `tasks/active.md` |
| Mid-project adoption or resuming after interruption | `prompts/resume_project.md` — reconstructs task state from what you tell it, writes `tasks/active.md` once |
| Every subsequent session | `prompts/reorient.md` — summarises `tasks/active.md` already in context, starts immediately |
| Scaffolding a feature | `prompts/scaffold_feature.md` — pulls Stitch screen first, then builds all layers |
| Planning architecture | `prompts/architecture.md` |
| Code review | `prompts/code_review.md` |
| Refactoring | `prompts/refactor.md` |
| Debugging | `prompts/debugging.md` |
| Writing a commit message | `prompts/commit_message.md` |

### Environment and tools

| Task | Command |
|------|---------|
| Auto-detect and switch env | `./scripts/claude-env.sh` |
| Switch to dev | `./scripts/claude-env.sh dev` |
| Switch to review | `./scripts/claude-env.sh review` |
| Switch to ci | `./scripts/claude-env.sh ci` |
| Check current environment | `./scripts/claude-env.sh status` |
| List all environments | `./scripts/claude-env.sh list` |
| Show usage | `./scripts/claude-env.sh help` |
| Install git hooks | `./scripts/install-hooks.sh` |
| Apply kit to project | `cp -r .claude android prompts tasks shipped workflows templates scripts /your/project/` |
| Restart Claude (soft) | `/clear` — in Claude session |
| Restart Claude (full — CLI) | `Ctrl+C` → `claude` |
| Restart Claude (full — VS Code) | `+` button or `Cmd+Shift+P` → Claude: New Conversation |

---

## Android SDK and Emulator Setup for Claude Code

Claude Code runs Bash commands in a non-interactive shell that does not source `~/.zshrc`. This means `adb` and the Android emulator tools are invisible to Claude even when an emulator is already running in Android Studio.

**Fix: add the SDK paths to `~/.zshenv`**

`~/.zshenv` is sourced for every zsh session — interactive or not — so it makes `adb` available to Claude's shell automatically.

```bash
# Open (or create) ~/.zshenv
nano ~/.zshenv
```

Add these lines:

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator
```

Save and verify in a new terminal (or Claude's Bash):

```bash
which adb
adb devices
```

If the emulator is running in Android Studio it should now appear in `adb devices` from any shell, including Claude Code's.

> This is a one-time machine setup. You do not need to repeat it when applying the kit to a new project.

---

## Requirements

- [Claude Code](https://claude.ai/code) installed and authenticated
- `jq` installed (for `claude-env.sh`)
- Android Java project using Java, XML layouts, Hilt, Room, Retrofit, LiveData, ViewBinding, RecyclerView, and WorkManager (the kit's guidelines are written for this stack)
