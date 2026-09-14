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

* [What This Project Is](#what-this-project-is)
* [Architecture](#architecture)
* [Database](#database)
* [Getting Started](#getting-started)
* [Test / Demo Accounts](#test--demo-accounts)
* [Data Seeder](#data-seeder)
* [Roles & Permissions](#roles--permissions)
* [Views & Features](#views--features)
* [Data Model](#data-model)
* [File Structure](#file-structure)
* [Extending the App](#extending-the-app)
* [Deployment (GitHub Pages)](#deployment-github-pages)
* [Known Gaps / Roadmap](#known-gaps--roadmap)
* [Browser Support](#browser-support)

---

## What This Project Is

TaskFlow Pro is a **multi-tenant SaaS project & task management platform**. Each signed-up user creates or joins one or more **workspaces** (tenants). Everything inside a workspace — projects, tasks, milestones, sprints, members, notifications — is scoped to that workspace and isolated from every other workspace via Postgres Row-Level Security. Multiple people can collaborate live inside the same workspace: changes made by one member appear for everyone else within 1–2 seconds via Supabase Realtime.

It intentionally has **no build step and no frontend framework** — it's plain HTML/CSS/JS, loaded as native ES modules directly by the browser. The only external dependency loaded at runtime is the `@supabase/supabase-js` client, pulled from a CDN in `index.html`.

This is the second architecture generation of this project:

|               | v3 (legacy, still in git history)        | v4 (current)                                       |
| ------------- | ---------------------------------------- | -------------------------------------------------- |
| Data storage  | One JSON blob per user in `localStorage` | Normalized Postgres tables, one row per entity     |
| Users         | Single user per browser                  | Multi-tenant workspaces with invited collaborators |
| Auth          | Supabase Auth, login-gate only           | Supabase Auth + workspace membership + roles       |
| Collaboration | None                                     | Realtime sync, invite links, RBAC, notifications   |
| Frontend      | One `app.js` (~2,600 lines)              | ES modules under `js/` and `js/ui/`                |

---

## Architecture

```text
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

Supabase project
 ├── Auth        email/password, session refresh, auto-confirm enabled
 ├── Postgres    workspace-scoped application tables
 ├── RLS         enforced on every table — the real security boundary
 ├── Realtime    postgres_changes subscriptions on tasks/projects/milestones/sprints/notifications
 └── DB Trigger  auto-inserts notification rows when a task is assigned or its status changes
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

### Project table

The application uses a dedicated project table named **`tt_projects`** to avoid naming conflicts with other applications when multiple applications are deployed against the same database.

The table is referenced by `js/storage.js` and the related migrations.

### Schema

| Table               | Purpose                                                              |
| ------------------- | -------------------------------------------------------------------- |
| `workspaces`        | One row per tenant                                                   |
| `workspace_members` | Join table: user ↔ workspace, with `role` (`owner`/`member`/`guest`) |
| `invitations`       | Invite-link tokens (7-day expiry, one-time use)                      |
| `notifications`     | Per-user notifications, inserted only by DB trigger                  |
| `tt_projects`       | Projects                                                             |
| `milestones`        | Project milestones                                                   |
| `sprints`           | Project sprints                                                      |
| `tasks`             | Tasks — linked to project/milestone/sprint/parent task/assignee      |
| `task_comments`     | Comment thread per task                                              |
| `task_activity`     | Append-only audit log per task (no UPDATE/DELETE policies)           |

Full column definitions: `migrations/001_schema.sql`.

Every workspace-scoped table carries `workspace_id`, allowing RLS to enforce tenant isolation.

### Row-Level Security & multi-tenancy

RLS is enabled on every table — this is the actual security boundary, not the frontend. Two `SECURITY DEFINER` helper functions back almost every policy:

```sql
is_workspace_member(_workspace_id)     -- current user belongs to this workspace?
get_my_workspace_role(_workspace_id)   -- 'owner' | 'member' | 'guest' | null
```

Membership check pattern used throughout the application:

```sql
USING (is_workspace_member(workspace_id))
```

This makes tenant isolation real — a member of Workspace A cannot `SELECT` rows belonging to Workspace B, regardless of frontend behavior.

### Migrations

Run the migrations in this order:

```text
migrations/
├── 001_schema.sql
├── 002_rls_policies.sql
├── 003_notifications_trigger.sql
├── 003_rls_bootstrap_fix.sql
├── 004_accept_invitation_rpc.sql
├── 005_rename_projects_to_tt_projects.sql
└── 006_recover_orphaned_projects.sql
```

> Two files share the `003_` prefix (`003_notifications_trigger.sql` and `003_rls_bootstrap_fix.sql`) — they're independent of each other; run both after `002`.

Run each file's contents in your own Supabase SQL editor, top to bottom, in numeric order.

### How to access the database

| Method                                              | Use it for                                |
| --------------------------------------------------- | ----------------------------------------- |
| Supabase Dashboard                                  | General project management                |
| Dashboard → **Table Editor**                        | Browse/edit application rows              |
| Dashboard → **SQL Editor**                          | Run migrations and SQL queries            |
| Dashboard → **Authentication → Users**              | Manage registered login users             |
| Dashboard → **Database → Replication**              | Verify Realtime is enabled                |
| REST API directly (`$SUPABASE_URL/rest/v1/<table>`) | Application/API scripting                 |
| `scripts/seed.js`                                   | Populate disposable development/test data |

The repository does **not** document or depend on a specific production Supabase project.

### Credentials

Credentials live in `config.js`, which is gitignored and created from `config.example.js`.

```js
window.APP_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT_REF.supabase.co',
  supabaseKey: '<anon/public key>'
};
```

The anon/public key is designed to be used by browser applications and is protected by Row-Level Security.

The **service-role key** bypasses RLS completely and must never be:

* committed to Git
* placed in `config.js`
* embedded in frontend JavaScript
* published in documentation
* shipped to browsers

---

## Getting Started

No build step and no `npm install` is required to run the application itself.

```bash
# Clone the repo
git clone https://github.com/zainknoman/TaskTracker.git
cd TaskTracker

# Set up Supabase credentials
cp config.example.js config.js

# Edit config.js and provide your own Supabase project URL
# and anon/public key.

# Apply database migrations through the Supabase SQL editor
# in numeric order before first use.

# Serve the static files
npx serve .

# — or —
python3 -m http.server 8080
```

### First run

1. Open the application and you'll see the login screen.
2. **Sign up** with an email/password.
3. After login, create a workspace when prompted.
4. The first user becomes the workspace `owner`.
5. Invite another account through **Settings → Invite Member** to test collaboration.
6. Alternatively, use the disposable seeded accounts described below.

---

## Test / Demo Accounts

The repository does not document or publish personal production accounts.

For development and demonstration, use the dedicated disposable test accounts created by the seed script:

| Email                          | Password    | Workspace                                  | Role   |
| ------------------------------ | ----------- | ------------------------------------------ | ------ |
| `alice.owner@tasktracker.test` | `Test1234!` | Acme Corporation                           | owner  |
| `bob.member@tasktracker.test`  | `Test1234!` | Acme Corporation **and** Globex Industries | member |
| `carol.guest@tasktracker.test` | `Test1234!` | Acme Corporation                           | guest  |
| `dave.owner@tasktracker.test`  | `Test1234!` | Globex Industries                          | owner  |
| `erin.member@tasktracker.test` | `Test1234!` | Globex Industries                          | member |

These accounts are intended for local/development testing only.

**What to test with these accounts:**

* Log in as `alice.owner` → confirm Globex's data is never visible.
* Log in as `bob.member` → use the workspace switcher to switch between Acme and Globex.
* Log in as `carol.guest` → confirm create/edit/delete controls are hidden.
* Open two browser tabs as different Acme members → change a task's status in one and observe the Realtime update in the other.
* Assign a task to a member → confirm the member receives a notification.

> Do not place real personal email addresses or production credentials in this README.

---

## Data Seeder

`scripts/seed.js` is a re-runnable Node script that creates Supabase Auth users and workspace data using the **public anon key**.

```bash
npm install
npm run seed
```

It reads `supabaseUrl` / `supabaseKey` from the local `config.js`, or from:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

environment variables.

The seeder is **idempotent per workspace slug**. Re-running it detects an already-seeded workspace and avoids recreating the same test data.

Requires migrations `001`–`006` to be applied first.

To extend the seed data with more tenants or different roles, edit the tenant/user definitions at the bottom of `scripts/seed.js`.

---

## Roles & Permissions

Three tiers are enforced twice: as a UX layer in `js/permissions.js` and, more importantly, through Postgres RLS policies.

| Action                               |  Owner  |  Member  | Guest |
| ------------------------------------ | :-----: | :------: | :---: |
| View projects/tasks                  |    ✓    |     ✓    |   ✓   |
| Create/edit project or task          |    ✓    |     ✓    |   ✗   |
| Delete project or task               | ✓ (any) | own only |   ✗   |
| Invite members                       |    ✓    |     ✓    |   ✗   |
| Change member roles / remove members |    ✓    |     ✗    |   ✗   |
| Rename or delete workspace           |    ✓    |     ✗    |   ✗   |
| Comment on tasks                     |    ✓    |     ✓    |   ✗   |

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

| Shortcut/Trigger | View            | Notes                                                                                       |
| ---------------- | --------------- | ------------------------------------------------------------------------------------------- |
| —                | Dashboard       | Stats, upcoming deadlines, team workload                                                    |
| —                | Projects        | Grid of workspace projects → project detail (Overview/Tasks/Kanban/Milestones/Sprints tabs) |
| —                | Tasks           | Filterable/sortable task table                                                              |
| —                | Kanban          | Drag-and-drop status board (Pending/In Progress/Completed/Blocked)                          |
| —                | Calendar        | Monthly due-date view                                                                       |
| —                | Gantt           | Timeline bar chart across projects                                                          |
| —                | Analytics       | Status/priority charts, workload distribution                                               |
| —                | Team            | Real workspace members (from `workspace_members`), avatar/skills editing, remove member     |
| `Ctrl/⌘ + K`     | Command Palette | Fuzzy-search launcher for navigation and recent tasks                                       |

Notifications are auto-generated server-side when tasks are assigned or their status changes and delivered live through a per-user Realtime channel.

---

## Data Model

### Project (`tt_projects`)

```js
{
  id,
  workspace_id,
  name,
  code,
  description,
  department,
  client,
  pm,
  ba_team,
  status,      // 'active' | 'planning' | 'onhold' | 'completed' | 'archived'
  priority,    // 'low' | 'medium' | 'high' | 'critical'
  start_date,
  end_date,
  budget,
  color,
  tags,
  created_by,
  created_at,
  updated_at
}
```

### Task

```js
{
  id,
  workspace_id,
  project_id,
  milestone_id,
  sprint_id,
  parent_task_id,
  title,
  description,
  priority,
  status,
  start_date,
  due_date,
  ba,
  assignee_id,
  estimated_hours,
  actual_hours,
  progress,
  tags,
  documents,
  dependencies,
  subtasks,
  notes,
  starred,
  pinned,
  created_by,
  created_at,
  updated_at
}
```

### Workspace member

```js
{
  id,
  workspace_id,
  user_id,
  role,
  display_name,
  avatar_url,
  avatar_preset,
  color,
  skills,
  joined_at
}
```

Milestones, sprints, invitations, notifications, task_comments, and task_activity follow the columns listed in the [Database](#database) section.

---

## File Structure

```text
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
│   ├── workspace.js              workspace CRUD, membership loading
│   ├── invitations.js            invite link create/accept/cancel
│   ├── permissions.js            role guard functions
│   ├── storage.js                Supabase table reads/writes, one fn per entity
│   ├── state.js                  global state object + mutation helpers
│   ├── realtime.js                Realtime channel subscriptions
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
├── migrations/                   SQL migrations, run in numeric order
└── .github/workflows/deploy.yml  GitHub Actions: injects secrets → deploys to Pages
```

---

## Extending the App

**Add a new view:**

1. Add `<section id="view-myview" class="view">…</section>` in `index.html`.
2. Add `myview: renderMyView` to the `renderers` map in `switchView()` (`app.js`).
3. Add a navigation link with `data-view="myview"`.

**Add a field to tasks/projects:**

1. Add a column through a new migration file.
2. Add the input to the relevant form in `index.html`.
3. Read/write it in the matching save function in `js/storage.js`.
4. Update the relevant `js/ui/*.js` renderer.

**Add a new workspace-scoped table:**

1. Create the table with:

```sql
workspace_id uuid REFERENCES workspaces(id) ON DELETE CASCADE
```

2. Enable RLS.
3. Add policies using:

```sql
is_workspace_member(workspace_id)
```

or:

```sql
get_my_workspace_role(workspace_id)
```

4. Add load/save functions to `js/storage.js`.
5. If live synchronization is required, subscribe to it in `js/realtime.js`.

---

## Deployment (GitHub Pages)

`config.js` is gitignored, so `.github/workflows/deploy.yml` generates it from repository secrets at deployment time.

1. Add repository secrets:

   * `SUPABASE_URL`
   * `SUPABASE_KEY`
2. Open **Settings → Pages → Source → GitHub Actions**.
3. Push to the deployment branch.
4. The workflow generates `config.js` and deploys the application.

```text
Git repository
    ↓
GitHub Actions
    ↓
Reads repository secrets
    ↓
Generates config.js
    ↓
Uploads site artifact
    ↓
Deploys to GitHub Pages
```

Never commit `config.js` when it contains environment-specific credentials.

---

## Known Gaps / Roadmap

Carried over from the previous single-user version but **not yet ported** to the multi-tenant Supabase architecture:

* Global search (`#globalSearch` input exists in `index.html`, no listener)
* Export/Import JSON & CSV (`#exportJsonBtn` exists, no handler; no export/import functions exist anywhere in `js/`)
* Saved views (`state.savedViews` exists, unused)
* Smart Productivity Check
* Deadline Health Score
* Sprint Burndown chart
* Number-key view shortcuts (`1`–`8`)
* `Ctrl/⌘ + N` new task shortcut

### Known bug

On some login/reload sequences, `js/realtime.js` may throw:

```text
cannot add postgres_changes callbacks ... after subscribe()
```

`subscribeToWorkspace()` may be called twice for the same workspace channel, likely because both the initialization flow and the authentication state handler can race.

The issue does not necessarily block normal application functionality, but the duplicate subscription should be guarded against.

### Current out-of-scope items

The following remain outside the current multi-user collaboration design:

* Email-based invitations
* Presence indicators
* Collaborative editing/conflict resolution
* Per-project roles
* Billing enforcement

---

## Browser Support

Requires native ES module support and `fetch`/WebSocket for Realtime.

Supported browsers include:

* Chrome 90+
* Firefox 88+
* Safari 14+
* Edge 90+

An internet connection is required because application data is stored in Supabase.

---

## Security & Privacy

Before publishing or deploying the application:

* Keep `config.js` out of Git.
* Never commit a Supabase service-role key.
* Use separate Supabase projects for development, staging, and production where appropriate.
* Do not publish real user email addresses in documentation.
* Do not publish real customer or company data in seed files.
* Use disposable `.test` accounts for demonstrations.
* Review screenshots for personal information before committing them.
* Keep database RLS enabled on every workspace-scoped table.
* Do not assume frontend permission checks provide security; enforce authorization at the database/API layer.
* Rotate credentials if a sensitive key is accidentally committed.

---

## Project Status

TaskFlow Pro is a functional multi-tenant work-management application with:

* Supabase authentication
* Multi-tenant workspaces
* Workspace membership
* Owner/member/guest roles
* PostgreSQL persistence
* Row-Level Security
* Realtime collaboration
* Projects
* Tasks
* Milestones
* Sprints
* Kanban
* Calendar
* Gantt
* Analytics
* Team management
* Invitations
* Notifications
* GitHub Pages deployment support
* Disposable development seed data

The application continues to evolve from the original single-user/localStorage architecture toward a more complete SaaS work-management platform.

---

## License

This project is licensed under the MIT License.

See `LICENSE` for details.
