# TaskFlow Pro ⚡

> **Multi-Tenant SaaS Work Management Platform** — a Jira/Asana-style project & task tracker built with vanilla JavaScript ES modules (no build step, no framework) on top of Supabase (Postgres + Auth + Row-Level Security + Realtime).

![Version](https://img.shields.io/badge/version-4.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![JS](https://img.shields.io/badge/JavaScript-ES2020%20modules-yellow)
![Backend](https://img.shields.io/badge/backend-Supabase-3ecf8e)

<p align="center">
  <img src="/docs/screenshots/01-dashboard.jpeg" alt="TaskFlow Pro dashboard" width="600"/>
</p>

## Table of Contents

- [What This Project Is](#what-this-project-is)
- [Architecture](#architecture)
- [Database](#database)
- [Getting Started](#getting-started)
- [Test / Demo Accounts](#test--demo-accounts)
- [Data Seeder](#data-seeder)
- [Roles & Permissions](#roles--permissions)
- [Views & Features](#views--features)
- [Data Model](#data-model)
- [File Structure](#file-structure)
- [Extending the App](#extending-the-app)
- [Deployment (GitHub Pages)](#deployment-github-pages)
- [Known Gaps / Roadmap](#known-gaps--roadmap)
- [Browser Support](#browser-support)

---

## What This Project Is

TaskFlow Pro is a **multi-tenant SaaS project & task management platform**. Each signed-up user creates or joins one or more **workspaces** (tenants). Everything inside a workspace — projects, tasks, milestones, sprints, members, notifications — is scoped to that workspace and isolated from every other workspace via Postgres Row-Level Security. Multiple people can collaborate live inside the same workspace: changes made by one member appear for everyone else within 1–2 seconds via Supabase Realtime.

It intentionally has **no build step and no frontend framework** — it's plain HTML/CSS/JS, loaded as native ES modules directly by the browser. The only external dependency loaded at runtime is the `@supabase/supabase-js` client, pulled from a CDN in `index.html`.

This is the second architecture generation of this project:

| | v3 (legacy, still in git history) | v4 (current) |
|---|---|---|
| Data storage | One JSON blob per user in `localStorage` | Normalized Postgres tables, one row per entity |
| Users | Single user per browser | Multi-tenant workspaces with invited collaborators |
| Auth | Supabase Auth, login-gate only | Supabase Auth + workspace membership + roles |
| Collaboration | None | Realtime sync, invite links, RBAC, notifications |
| Frontend | One `app.js` (~2,600 lines) | ES modules under `js/` and `js/ui/` |

---

## Architecture

```
Browser (static files, no build step)
 index.html
   ├── <script src="cdn.../@supabase/supabase-js@2">   ← CDN, loaded first
   ├── config.js                                        ← Supabase URL + anon key (gitignored)
   └── app.js  (type="module", entry point)
        ├── js/supabase.js       Supabase client (sb)
        ├── js/auth.js           login / signup / session / invite-token detection
        ├── js/workspace.js      workspace CRUD, load, switch
        ├── js/invitations.js    create / accept / cancel invite links
        ├── js/permissions.js    canEdit / canDelete / canInvite / canManageMembers
        ├── js/storage.js        one function per entity → Supabase table reads/writes
        ├── js/state.js          in-memory global state object (single source of truth for rendering)
        ├── js/realtime.js       Supabase Realtime channel subscriptions
        ├── js/notifications.js  notification list + bell badge
        ├── js/router.js         tiny view-switch indirection
        ├── js/utils.js          DOM helpers, escaping, overlays, toasts
        └── js/ui/*.js           one renderer module per view (dashboard, projects, tasks,
                                  kanban, calendar, gantt, analytics, team, workspace-switcher)

Supabase project (zynunureylcdexxhvdth)
 ├── Auth        email/password, session refresh, auto-confirm enabled
 ├── Postgres    10 workspace-scoped tables, see Database section
 ├── RLS         enforced on every table — the real security boundary
 ├── Realtime    postgres_changes subscriptions on tasks/projects/milestones/sprints/notifications
 └── DB Trigger  auto-inserts `notifications` rows when a task is assigned or its status changes
```

### Request flow

1. `auth.js` restores the Supabase session on load (or shows the login screen).
2. `workspace.js` lists every workspace the user belongs to (`workspace_members` join) and loads the active one — `storage.js` fetches projects/tasks/milestones/sprints/members for that `workspace_id` in parallel.
3. `state.js` holds all of it in one plain object; every `js/ui/*.js` renderer reads directly from `state`.
4. A user action (e.g. save task) updates `state` optimistically, re-renders, then calls the matching `storage.js` function to write to Postgres in the background.
5. `realtime.js` receives the Postgres change broadcast (from this tab or any other member's tab) and merges it into `state`, re-rendering the affected view — this is how live multi-user sync works.
6. Nothing besides `workspace_id`/role checks lives only in the frontend: `permissions.js` only controls what the UI *shows*; the actual enforcement is RLS policies at the database layer, so a malicious client can't bypass permissions by calling the API directly.

---

## Database

### ⚠️ Known issue: shared Supabase project table collision

The configured Supabase project (`zynunureylcdexxhvdth`) is **shared with an unrelated app** — a portfolio/showcase site that already owned a table named `projects` (columns like `title`, `emoji`, `category`, `location` — no `workspace_id`). When the original schema migration ran, `CREATE TABLE projects (...)` collided with that pre-existing table, so TaskFlow's own projects table was never created, and `tasks`/`milestones`/`sprints` risked foreign-keying against the wrong table entirely.

**Fix:** TaskFlow's project table now lives under a distinct name, **`tt_projects`** (see `migrations/005_rename_projects_to_tt_projects.sql`). The unrelated app's `projects` table is left completely untouched. `js/storage.js` reads/writes `tt_projects`, not `projects`. If you fork this into your own, unshared Supabase project, you can rename it back to `projects` if you prefer — just update `js/storage.js` and re-point the three foreign keys.

The collision had already produced 12 real tasks (from early manual testing, 2026-05-16) referencing 4 "projects" that were never actually saved anywhere. `migrations/006_recover_orphaned_projects.sql` recreated those 4 as real `tt_projects` rows (reusing their original ids) so no task data was lost, then fully validated the foreign keys. Both migrations have been applied to the live project.

**Also note:** `auth.users` is a Postgres-instance-wide table, so it's shared across both apps too — not just `projects`. A signup from either app lands in the same user pool. This is harmless for TaskTracker (RLS means a user with no workspace membership sees nothing), but it's why you may see unfamiliar accounts in Authentication → Users that don't belong to this app.

### Schema

| Table | Purpose |
|---|---|
| `workspaces` | One row per tenant |
| `workspace_members` | Join table: user ↔ workspace, with `role` (`owner`/`member`/`guest`) |
| `invitations` | Invite-link tokens (7-day expiry, one-time use) |
| `notifications` | Per-user notifications, inserted only by DB trigger |
| `tt_projects` | Projects (see collision note above) |
| `milestones` | Project milestones |
| `sprints` | Project sprints |
| `tasks` | Tasks — linked to project/milestone/sprint/parent task/assignee |
| `task_comments` | Comment thread per task |
| `task_activity` | Append-only audit log per task (no UPDATE/DELETE policies) |

Full column definitions: `migrations/001_schema.sql`. Every table (except the two low-frequency/global ones) carries `workspace_id`, so RLS checks are a single indexed lookup with no joins.

### Row-Level Security & multi-tenancy

RLS is enabled on every table — this is the actual security boundary, not the frontend. Two `SECURITY DEFINER` helper functions back almost every policy:

```sql
is_workspace_member(_workspace_id)     -- current user belongs to this workspace?
get_my_workspace_role(_workspace_id)   -- 'owner' | 'member' | 'guest' | null
```

Membership check pattern used everywhere: `USING (is_workspace_member(workspace_id))`. This is what makes tenant isolation real — a member of Workspace A can never `SELECT` a row belonging to Workspace B, no matter what the frontend does.

### Migrations (run in this order)

```
migrations/
├── 001_schema.sql                       all tables + indexes
├── 002_rls_policies.sql                 RLS + helper functions + owner-auto-join trigger
├── 003_notifications_trigger.sql        DB trigger: notify on task assign / status change
├── 003_rls_bootstrap_fix.sql            fixes a chicken-and-egg RLS bug on workspace creation
├── 004_accept_invitation_rpc.sql        accept_invitation() RPC (SECURITY DEFINER)
├── 005_rename_projects_to_tt_projects.sql  fixes the table collision above
└── 006_recover_orphaned_projects.sql    recovers pre-existing tasks orphaned by the collision
```

> Two files share the `003_` prefix (`003_notifications_trigger.sql` and `003_rls_bootstrap_fix.sql`) — they're independent of each other; run both, in either order, after `002`.

Run each file's contents in the [Supabase SQL editor](https://supabase.com/dashboard/project/zynunureylcdexxhvdth/sql/new), top to bottom, in numeric order.

### How to access the database

| Method | Use it for |
|---|---|
| [Supabase Dashboard](https://supabase.com/dashboard/project/zynunureylcdexxhvdth) | General project management |
| Dashboard → **Table Editor** | Browse/edit rows in any table (`workspaces`, `tasks`, etc.) without SQL |
| Dashboard → **SQL Editor** | Run migrations, ad-hoc queries, `SELECT * FROM auth.users` to list all login accounts |
| Dashboard → **Authentication → Users** | See every registered login user (email, confirmed status, last sign-in) — this is the canonical place to check "who has an account" |
| Dashboard → **Database → Replication** | Verify Realtime is enabled on `tasks`, `tt_projects`, `milestones`, `sprints`, `notifications` |
| REST API directly (`$SUPABASE_URL/rest/v1/<table>`) | Scripting — requires `apikey` + `Authorization: Bearer <key>` headers; the anon key is subject to RLS (only returns what that session is allowed to see), the service-role key bypasses RLS entirely and should never be used from the browser |
| `scripts/seed.js` (see below) | Populate test data using only the public anon key |

**Credentials** live in `config.js` (gitignored, created from `config.example.js`):
```js
window.APP_CONFIG = {
  supabaseUrl: 'https://zynunureylcdexxhvdth.supabase.co',
  supabaseKey: '<anon/public key — safe for the browser, RLS-restricted>'
};
```
The anon key is meant to be public (it ships to every browser) — it is not a secret. The **service-role key** (found in Dashboard → Project Settings → API) bypasses RLS completely and must never be put in `config.js`, committed, or shipped to a browser.

---

## Getting Started

No build step, no `npm install` required to run the app itself.

```bash
# Clone the repo
git clone https://github.com/zainknoman/TaskTracker.git
cd TaskTracker

# Set up Supabase credentials
cp config.example.js config.js
# Edit config.js and fill in your supabaseUrl and supabaseKey

# Apply database migrations (see Database section) via the Supabase SQL editor,
# in numeric order, before first use.

# Serve the static files (opening index.html directly also works for quick checks,
# but a local server avoids some browser module/CORS quirks)
npx serve .
# — or —
python3 -m http.server 8080
```

### First run

1. Open the app → you'll see the login screen.
2. **Sign up** with any email/password (this Supabase project has `mailer_autoconfirm` enabled, so no email confirmation step is needed — you're logged in immediately).
3. First login with no workspace → you're prompted to name a workspace. That creates it and makes you its `owner`.
4. Invite a second account: **Settings → Invite Member** generates a link (`?invite=<token>`) — open it in another browser/incognito window signed in as a different user to test collaboration.
5. Or skip manual signup entirely and use the **[seeded test accounts](#test--demo-accounts)** below.

---

## Test / Demo Accounts

### Existing accounts

The live database already has real accounts from early manual testing (2026-05-16), plus one unrelated account belonging to the other app sharing this Supabase project (see the shared-`auth.users` note above):

| Email | Workspace | Role |
|---|---|---|
| `zainknoman@gmail.com` | ZainABC | owner |
| `zainknoman@hotmail.com` | ZainABC (member) **and** WSUser2 (owner) | member / owner |
| `admin@aac.pk` | — (no workspace; belongs to the other app) | — |

If you don't already know the passwords for the first two, reset them via Supabase Dashboard → Authentication → Users, or just use the freshly-seeded accounts below instead.

### Seeded test accounts

For dedicated, disposable multi-tenant test data (without touching the real accounts above), run `npm run seed` (see [Data Seeder](#data-seeder)). It creates two more independent tenants to exercise workspace isolation, RBAC, and the workspace switcher:

| Email | Password | Workspace | Role |
|---|---|---|---|
| `alice.owner@tasktracker.test` | `Test1234!` | Acme Corporation | owner |
| `bob.member@tasktracker.test` | `Test1234!` | Acme Corporation **and** Globex Industries | member (in both — use this account to test the workspace switcher) |
| `carol.guest@tasktracker.test` | `Test1234!` | Acme Corporation | guest (read-only) |
| `dave.owner@tasktracker.test` | `Test1234!` | Globex Industries | owner |
| `erin.member@tasktracker.test` | `Test1234!` | Globex Industries | member |

Each workspace also gets 1–2 sample projects with milestones, an active sprint, and a handful of tasks in varying statuses/priorities assigned across members, so the Dashboard/Kanban/Gantt/Analytics views have real data to render immediately.

**What to test with these accounts:**
- Log in as `alice.owner` → confirm Globex's data is never visible (tenant isolation).
- Log in as `bob.member` → use the workspace switcher (sidebar) to flip between Acme and Globex.
- Log in as `carol.guest` → confirm create/edit/delete controls are hidden (guest = read-only).
- Open two browser tabs as different Acme members → change a task's status in one, watch it update live in the other (Realtime).
- Assign a task to a member → confirm they get a notification (bell badge).

---

## Data Seeder

`scripts/seed.js` is a re-runnable Node script that creates real Supabase Auth users and workspace data using only the **public anon key** — no service-role key needed, because this project has email auto-confirm enabled.

```bash
npm install          # installs @supabase/supabase-js as a dev dependency
npm run seed          # reads credentials from config.js automatically
```

It reads `supabaseUrl`/`supabaseKey` straight out of your local `config.js`, or from `SUPABASE_URL`/`SUPABASE_ANON_KEY` env vars if you prefer not to have `config.js` present yet. It is **idempotent per workspace slug** — re-running it detects an already-seeded workspace (by owner + slug) and skips recreating it, so it's safe to run repeatedly during development.

Requires migrations `001`–`006` to be applied first (the seeder writes into `tt_projects`, `workspaces`, `tasks`, etc., which must exist).

To extend it with more tenants or different roles, edit the `TENANTS`-equivalent calls at the bottom of `scripts/seed.js` — each tenant is just a call to `ensureUser` → `ensureWorkspace` → `addMember` → `seedProject`.

---

## Roles & Permissions

Three tiers, enforced twice: as a UX layer in `js/permissions.js` (hides/disables controls) and — the part that actually matters — as Postgres RLS policies.

| Action | Owner | Member | Guest |
|---|:---:|:---:|:---:|
| View projects/tasks | ✓ | ✓ | ✓ |
| Create/edit project or task | ✓ | ✓ | ✗ |
| Delete project or task | ✓ (any) | own only | ✗ |
| Invite members | ✓ | ✓ | ✗ |
| Change member roles / remove members | ✓ | ✗ | ✗ |
| Rename or delete workspace | ✓ | ✗ | ✗ |
| Comment on tasks | ✓ | ✓ | ✗ |

```js
// js/permissions.js
getMyRole()          → state.currentMember.role
canEdit()             → role !== 'guest'
canDelete(entity)     → role === 'owner' || entity.created_by === currentUser.id
canInvite()           → role === 'owner' || role === 'member'
canManageMembers()    → role === 'owner'
```

---

## Views & Features

| Shortcut/Trigger | View | Notes |
|---|---|---|
| — | Dashboard | Stats, upcoming deadlines, team workload |
| — | Projects | Grid of workspace projects → project detail (Overview/Tasks/Kanban/Milestones/Sprints tabs) |
| — | Tasks | Filterable/sortable task table |
| — | Kanban | Drag-and-drop status board (Pending/In Progress/Completed/Blocked) |
| — | Calendar | Monthly due-date view |
| — | Gantt | Timeline bar chart across projects |
| — | Analytics | Status/priority charts, workload distribution |
| — | Team | Real workspace members (from `workspace_members`), avatar/skills editing, remove member |
| `Ctrl/⌘ + K` | Command Palette | Fuzzy-search launcher for navigation and recent tasks |

Notifications are auto-generated server-side (task assigned / task status changed) via a Postgres trigger and delivered live through a per-user Realtime channel; the bell badge updates without a page refresh.

---

## Data Model

### Project (`tt_projects`)
```js
{ id, workspace_id, name, code, description, department, client, pm, ba_team,
  status,   // 'active' | 'planning' | 'onhold' | 'completed' | 'archived'
  priority, // 'low' | 'medium' | 'high' | 'critical'
  start_date, end_date, budget, color, tags, created_by, created_at, updated_at }
```

### Task
```js
{ id, workspace_id, project_id, milestone_id, sprint_id, parent_task_id,
  title, description, priority, status, start_date, due_date,
  ba, assignee_id, estimated_hours, actual_hours, progress,
  tags, documents, dependencies, subtasks, notes, starred, pinned,
  created_by, created_at, updated_at }
```

### Workspace member
```js
{ id, workspace_id, user_id, role, display_name, avatar_url, avatar_preset, color, skills, joined_at }
```

Milestones, sprints, invitations, notifications, task_comments, and task_activity follow the columns listed in [Database](#database).

---

## File Structure

```
TaskTracker/
├── index.html                    App shell — all views, modals, overlays; loads supabase-js from CDN
├── app.js                        Entry point: routing, auth UI glue, event binding, init
├── style.css                     Design tokens, layout, components, dark mode
├── config.js                     Supabase credentials — gitignored, generate from config.example.js
├── config.example.js             Credential template committed to the repo
├── package.json                  Only dependency: @supabase/supabase-js (dev, used by scripts/seed.js)
├── scripts/
│   └── seed.js                   Data seeder — see Data Seeder section
├── js/
│   ├── supabase.js               Supabase client
│   ├── auth.js                   login / signup / session / invite-token handling
│   ├── workspace.js               workspace CRUD, membership loading
│   ├── invitations.js            invite link create/accept/cancel
│   ├── permissions.js            role guard functions
│   ├── storage.js                Supabase table reads/writes, one fn per entity
│   ├── state.js                  global state object + mutation helpers
│   ├── realtime.js               Realtime channel subscriptions
│   ├── notifications.js          notification loading + bell badge
│   ├── router.js                 view-switch indirection
│   ├── utils.js                  DOM helpers, escaping, overlays, toasts
│   └── ui/
│       ├── dashboard.js          dashboard + command palette
│       ├── projects.js           projects list/detail, milestone/sprint forms
│       ├── tasks.js              task list/detail/form
│       ├── kanban.js             drag-and-drop board
│       ├── calendar.js           monthly calendar
│       ├── gantt.js              timeline chart
│       ├── analytics.js          charts & KPIs
│       ├── team.js               workspace member cards + profile editing
│       └── workspace-switcher.js workspace dropdown, invite modal, members panel
├── migrations/                   SQL migrations, run in numeric order — see Database section
└── .github/workflows/deploy.yml  GitHub Actions: injects secrets → deploys to Pages
```

---

## Extending the App

**Add a new view:**
1. Add `<section id="view-myview" class="view">…</section>` in `index.html`
2. Add `myview: renderMyView` to the `renderers` map in `switchView()` (`app.js`)
3. Add a nav link with `data-view="myview"`

**Add a field to tasks/projects:**
1. Add a column via a new migration file
2. Add the input to the relevant form in `index.html`
3. Read/write it in the matching `save*` function in `js/storage.js` and the relevant `js/ui/*.js` module

**Add a new workspace-scoped table:**
1. `CREATE TABLE` with `workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE`
2. Enable RLS + policy using `is_workspace_member(workspace_id)` / `get_my_workspace_role(workspace_id)`
3. Add load/save functions to `js/storage.js`
4. If it needs live sync, subscribe to it in `js/realtime.js`

---

## Deployment (GitHub Pages)

`config.js` is gitignored, so `.github/workflows/deploy.yml` generates it from repository secrets at deploy time.

1. Add repo secrets: **Settings → Secrets and variables → Actions** → `SUPABASE_URL`, `SUPABASE_KEY`
2. **Settings → Pages → Source → GitHub Actions**
3. Push to `main` — the workflow builds `config.js` from secrets and deploys.

```
Git repo (no config.js) → Actions runner reads secrets → generates config.js
  → uploads full site as Pages artifact → deploys to https://zainknoman.github.io/TaskTracker/
```

---

## Known Gaps / Roadmap

Carried over from the previous single-user version but **not yet ported** to the multi-tenant Supabase architecture (present only as inert markup/state, not wired to any handler):

- Global search (`#globalSearch` input exists in `index.html`, no listener)
- Export/Import JSON & CSV (`#exportJsonBtn` exists, no handler; no export/import functions exist anywhere in `js/`)
- Saved views (`state.savedViews` exists, unused)
- Smart Productivity Check, Deadline Health Score, Sprint Burndown chart (fully absent — not present in any form)
- Number-key view shortcuts (`1`–`8`) and `Ctrl/⌘+N` new task (only `Ctrl/⌘+K` command palette is currently wired)

**Known bug:** on some login/reload sequences, `js/realtime.js` throws `cannot add postgres_changes callbacks ... after subscribe()` in the console — `subscribeToWorkspace()` appears to get called twice for the same workspace channel (likely both `initApp()`'s direct call and the `onAuthStateChange('SIGNED_IN')` handler racing). It didn't block functionality in testing, but the second subscription attempt silently fails, so live sync from that duplicate call is lost. Worth guarding `subscribeToWorkspace`/`unsubscribeAll` against re-entrancy.

Out of scope for the current design (per the [multi-user collaboration spec](docs/superpowers/specs/2026-05-16-multi-user-collaboration-design.md)): email-based invitations, presence indicators, collaborative editing/conflict resolution, per-project roles, billing enforcement.

---

## Browser Support

Requires native ES module support and `fetch`/WebSocket (for Realtime): Chrome 90+, Firefox 88+, Safari 14+, Edge 90+. Requires an internet connection at all times — unlike the old localStorage version, all data lives in Supabase.

---

## Author

Zain Kamali
