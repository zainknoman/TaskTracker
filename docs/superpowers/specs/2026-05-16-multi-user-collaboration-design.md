# TaskFlow SaaS — Multi-User Collaboration Design

**Date:** 2026-05-16  
**Status:** Approved  
**Author:** Zain Kamali  
**Supabase Project:** zynunureylcdexxhvdth (new, clean slate)  
**Old Project:** dqpnhyjbuovsjmpebcis (preserved, single-user blob — unchanged)

---

## 1. Context & Decisions

### What exists today

TaskFlow Pro is a monolithic vanilla JS app (`app.js`, ~2,600 lines) deployed on GitHub Pages. It uses Supabase Auth for login only. All application data (projects, tasks, milestones, sprints, users, notifications) is stored as a single JSONB blob in one `workspaces` table row per authenticated user.

### Confirmed decisions from brainstorming

| Decision | Choice | Reason |
|---|---|---|
| Migration strategy | Approach B — Full normalized schema | Starting fresh (no existing users to migrate) |
| Invite system | Invite links only (no email for v1) | No email service infra needed |
| Frontend architecture | Modularize into ES modules | Monolith will grow too large; cleaner long-term |
| Realtime scope | Live data sync only | No presence indicators for v1 |
| RBAC | 3-tier: Owner / Member / Guest | Covers the actual use case without over-engineering |
| Supabase project | New project from zero | Old project preserved for single-user blob users |

---

## 2. System Architecture Overview

```
GitHub Pages (static)
  └── index.html
       └── app.js (entry point, ~200 lines)
            ├── js/supabase.js      ← Supabase client
            ├── js/auth.js          ← login/logout/session
            ├── js/workspace.js     ← workspace CRUD + member mgmt
            ├── js/invitations.js   ← invite link create/accept
            ├── js/permissions.js   ← role guards (canEdit, canDelete)
            ├── js/storage.js       ← all DB reads/writes (per entity)
            ├── js/state.js         ← global state + mutations
            ├── js/realtime.js      ← Supabase Realtime subscriptions
            ├── js/notifications.js ← notification load + bell badge
            └── js/ui/              ← view renderers (one file per view)

Supabase (zynunureylcdexxhvdth)
  ├── Auth            ← email/password, session management
  ├── PostgreSQL      ← 10 normalized tables (see §4)
  ├── RLS             ← enforced on all tables
  └── Realtime        ← tasks, projects, milestones, sprints, notifications
```

### Data flow (multi-user)

1. User logs in → `auth.js` gets session → `workspace.js` loads workspace list
2. Active workspace selected → `storage.js` loads all entities for that workspace
3. `state.js` populated → views rendered from state (same pattern as before)
4. User mutates data → `storage.js` writes to specific table → local state updated (optimistic)
5. `realtime.js` receives broadcast from Supabase → merges remote change into state → re-renders affected view

---

## 3. Database Schema

### Supabase project: zynunureylcdexxhvdth

All tables use `uuid` primary keys (`gen_random_uuid()`) and `timestamptz` for timestamps. RLS is enabled on every table.

#### 3.1 Workspace Layer

```sql
workspaces
----------
id             uuid PK default gen_random_uuid()
name           text NOT NULL
slug           text UNIQUE NOT NULL    -- auto-generated: slugify(name) + random suffix, e.g. "my-team-a3f2"
owner_id       uuid NOT NULL → auth.users(id)
plan_type      text DEFAULT 'free'
settings       jsonb DEFAULT '{}'
created_at     timestamptz DEFAULT now()
updated_at     timestamptz DEFAULT now()
```

```sql
workspace_members
-----------------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
user_id        uuid NOT NULL → auth.users(id) ON DELETE CASCADE
role           text NOT NULL CHECK (role IN ('owner','member','guest')) DEFAULT 'member'
display_name   text
avatar_url     text
avatar_preset  int
color          text
skills         text[]
joined_at      timestamptz DEFAULT now()
UNIQUE (workspace_id, user_id)
```

```sql
invitations
-----------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
invited_by     uuid NOT NULL → auth.users(id)
token          text UNIQUE NOT NULL
role           text NOT NULL CHECK (role IN ('member','guest')) DEFAULT 'member'
label          text                    -- optional friendly label set by inviter
status         text NOT NULL CHECK (status IN ('pending','accepted','cancelled')) DEFAULT 'pending'
accepted_by    uuid → auth.users(id)  -- set when accepted
expires_at     timestamptz NOT NULL    -- DEFAULT now() + interval '7 days'
created_at     timestamptz DEFAULT now()
```

```sql
notifications
-------------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
user_id        uuid NOT NULL → auth.users(id) ON DELETE CASCADE
type           text NOT NULL   -- 'task_assigned' | 'status_changed' | 'invite_accepted' | ...
title          text NOT NULL
body           text
entity_type    text            -- 'task' | 'project' | 'workspace'
entity_id      uuid
read           boolean DEFAULT false
created_at     timestamptz DEFAULT now()
```

#### 3.2 Project Layer

```sql
projects
--------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
name           text NOT NULL
code           text
description    text
department     text
client         text
pm             text
ba_team        text[]
status         text DEFAULT 'active' CHECK (status IN ('active','planning','onhold','completed','archived'))
priority       text DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical'))
start_date     date
end_date       date
budget         numeric
color          text
tags           text[]
created_by     uuid NOT NULL → auth.users(id)
created_at     timestamptz DEFAULT now()
updated_at     timestamptz DEFAULT now()
```

```sql
milestones
----------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
project_id     uuid NOT NULL → projects(id) ON DELETE CASCADE
name           text NOT NULL
description    text
due_date       date
status         text DEFAULT 'pending' CHECK (status IN ('pending','completed'))
sort_order     int DEFAULT 0
created_at     timestamptz DEFAULT now()
```

```sql
sprints
-------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
project_id     uuid NOT NULL → projects(id) ON DELETE CASCADE
name           text NOT NULL
goal           text
start_date     date
end_date       date
status         text DEFAULT 'planning' CHECK (status IN ('planning','active','completed'))
velocity       int
created_at     timestamptz DEFAULT now()
```

#### 3.3 Task Layer

```sql
tasks
-----
id               uuid PK
workspace_id     uuid NOT NULL → workspaces(id) ON DELETE CASCADE
project_id       uuid NOT NULL → projects(id) ON DELETE CASCADE
milestone_id     uuid → milestones(id) ON DELETE SET NULL
sprint_id        uuid → sprints(id) ON DELETE SET NULL
parent_task_id   uuid → tasks(id) ON DELETE SET NULL     -- subtask parent
title            text NOT NULL
description      text
priority         text DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical'))
status           text DEFAULT 'pending' CHECK (status IN ('pending','inprogress','completed','blocked'))
start_date       date
due_date         date
ba               text                                    -- text ref for backward compat
assignee_id      uuid → auth.users(id)                  -- real workspace member
estimated_hours  numeric
actual_hours     numeric
progress         int DEFAULT 0 CHECK (progress BETWEEN 0 AND 100)
tags             text[]
documents        jsonb DEFAULT '[]'                      -- [{name, url, type}] — stays JSONB
dependencies     uuid[]                                  -- array of task IDs
subtasks         jsonb DEFAULT '[]'                      -- [{id, title, done}] — stays JSONB
notes            text
starred          boolean DEFAULT false
pinned           boolean DEFAULT false
created_by       uuid NOT NULL → auth.users(id)
created_at       timestamptz DEFAULT now()
updated_at       timestamptz DEFAULT now()
```

```sql
task_comments
-------------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
task_id        uuid NOT NULL → tasks(id) ON DELETE CASCADE
author_id      uuid NOT NULL → auth.users(id)
content        text NOT NULL
created_at     timestamptz DEFAULT now()
updated_at     timestamptz DEFAULT now()
```

```sql
task_activity
-------------
id             uuid PK
workspace_id   uuid NOT NULL → workspaces(id) ON DELETE CASCADE
task_id        uuid NOT NULL → tasks(id) ON DELETE CASCADE
actor_id       uuid NOT NULL → auth.users(id)
action         text NOT NULL   -- 'status_changed' | 'assigned' | 'commented' | 'created' | ...
old_value      text
new_value      text
description    text            -- human-readable e.g. "Status changed from Pending to In Progress"
created_at     timestamptz DEFAULT now()
```

#### 3.4 Recommended Indexes

```sql
CREATE INDEX ON workspace_members (workspace_id, user_id);
CREATE INDEX ON workspace_members (user_id);
CREATE INDEX ON projects (workspace_id);
CREATE INDEX ON milestones (project_id);
CREATE INDEX ON sprints (project_id);
CREATE INDEX ON tasks (workspace_id, project_id);
CREATE INDEX ON tasks (assignee_id);
CREATE INDEX ON tasks (status, due_date);
CREATE INDEX ON task_comments (task_id);
CREATE INDEX ON task_activity (task_id, created_at DESC);
CREATE INDEX ON notifications (user_id, read);
CREATE INDEX ON invitations (token);   -- fast public token lookup
```

#### 3.5 Design Notes

- **`workspace_id` is denormalized onto every table** — enables fast single-column RLS checks with no joins
- **`subtasks` and `documents` stay JSONB on `tasks`** — always loaded with the parent task, never queried independently
- **`task_activity` is append-only** — UPDATE and DELETE RLS policies are set to `false`; immutable audit trail
- **`ba` stays as a text field** — preserves backward compatibility with the existing team model; `assignee_id` is the real FK for collaboration
- **Realtime enabled on:** `tasks`, `projects`, `milestones`, `sprints`, `notifications`
- **Realtime NOT enabled on:** `task_activity` (polled on demand), `workspace_members` (low-frequency), `invitations` (low-frequency)

---

## 4. Row Level Security (RLS)

RLS is enabled on all tables. The core pattern is a helper function that checks workspace membership — used across most policies.

### 4.1 Helper function (run once in migration)

```sql
CREATE OR REPLACE FUNCTION is_workspace_member(_workspace_id uuid)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = _workspace_id
      AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION get_my_workspace_role(_workspace_id uuid)
RETURNS text
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM workspace_members
  WHERE workspace_id = _workspace_id
    AND user_id = auth.uid()
  LIMIT 1;
$$;
```

### 4.2 Policy summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `workspaces` | member of workspace | authenticated user | owner only | owner only |
| `workspace_members` | member of workspace | owner only | owner only | owner (any) / self (own row) |
| `invitations` | member OR anon (token-gated — see note) | member | accepting user (own row) | owner only |
| `projects` | workspace member | member or owner | member or owner | owner or created_by |
| `milestones` | workspace member | member or owner | member or owner | member or owner |
| `sprints` | workspace member | member or owner | member or owner | member or owner |
| `tasks` | workspace member | member or owner | member or owner | owner or created_by |
| `task_comments` | workspace member | member or owner | author only | author or owner |
| `task_activity` | workspace member | member or owner (insert via trigger) | `FALSE` | `FALSE` |
| `notifications` | `user_id = auth.uid()` | via DB trigger only | `user_id = auth.uid()` (mark read) | `user_id = auth.uid()` |

### 4.3 Key security notes

- **Notifications are inserted by DB trigger, not the frontend** — prevents RLS bypass; ensures atomicity with the event that caused the notification
- **`invitations` SELECT is semi-public** — the policy is set to `true` for both authenticated and anonymous (anon key) requests. Any user who knows the URL can read that invitation row. Security relies on the token's entropy (UUID = 122 bits, not guessable). This is the standard pattern for invite links — the token *is* the credential. The frontend only queries by the specific `?invite=<token>` from the URL, never lists all invitations without auth.
- **`task_activity` UPDATE/DELETE are `FALSE`** — policies that evaluate to `false` unconditionally block those operations even for the table owner
- **SECURITY DEFINER on helper functions** — required so the function can query `workspace_members` even when called from a restricted RLS context

---

## 5. RBAC — 3-Tier Permission Model

### Roles

| Role | Assigned to | How |
|---|---|---|
| `owner` | Workspace creator | Auto-assigned on workspace creation |
| `member` | Invited collaborators (default) | Set in `invitations.role` at invite time |
| `guest` | Read-only collaborators | Set in `invitations.role` at invite time |

### Permission matrix

| Action | Owner | Member | Guest |
|---|---|---|---|
| **Workspace** | | | |
| Rename workspace | ✓ | ✗ | ✗ |
| Invite members | ✓ | ✓ | ✗ |
| Change member roles | ✓ | ✗ | ✗ |
| Remove any member | ✓ | ✗ | ✗ |
| Leave workspace | ✓ | ✓ | ✓ |
| Delete workspace | ✓ | ✗ | ✗ |
| **Projects** | | | |
| View all projects | ✓ | ✓ | ✓ |
| Create project | ✓ | ✓ | ✗ |
| Edit any project | ✓ | ✓ | ✗ |
| Delete project | ✓ | own only | ✗ |
| **Tasks** | | | |
| View all tasks | ✓ | ✓ | ✓ |
| Create task | ✓ | ✓ | ✗ |
| Edit any task | ✓ | ✓ | ✗ |
| Delete task | ✓ | own only | ✗ |
| Assign task | ✓ | ✓ | ✗ |
| Change task status | ✓ | ✓ | ✗ |
| Comment on task | ✓ | ✓ | ✗ |

### Frontend enforcement

Permission checks happen in `permissions.js` using the role stored in `state.currentMember.role`. All UI elements (buttons, form inputs, drag handles) are hidden or disabled based on these guards. This is a UX layer — the real enforcement is in RLS.

```
canEdit(entityType)   → role !== 'guest'
canDelete(entity)     → role === 'owner' || entity.created_by === currentUser.id
canInvite()           → role === 'owner' || role === 'member'
canManageMembers()    → role === 'owner'
getMyRole()           → state.currentMember.role
```

---

## 6. Invite Link Flow

### Step-by-step

1. **Owner/Member clicks "Invite Member"** — opens invite modal; selects role (Member or Guest); optionally adds a label (e.g. "For Ahmed — Dev")
2. **Frontend generates token** — `crypto.randomUUID()` produces a cryptographically secure token
3. **Inserts invitation row** — calls `storage.createInvitation({ workspaceId, role, label, token, expiresAt })`; `expires_at` = now + 7 days
4. **Link displayed** — UI shows `https://zainknoman.github.io/TaskTracker/?invite=<token>`; owner copies and shares via any channel (Slack, WhatsApp, email)
5. **Invitee opens link** — `auth.js` detects `?invite=<token>` on page load; queries `invitations` table by token; validates status = 'pending' and `expires_at` > now; shows workspace name + role
6. **Not logged in** — redirects to login/signup with `?invite=<token>` preserved in URL; after auth, resumes accept flow
7. **Accepts invitation** — `invitations.acceptInvitation(token, userId)`: inserts `workspace_members` row, updates invitation `status = 'accepted'`, sets `accepted_by = userId`
8. **Redirect to workspace** — URL param cleared; workspace loads normally with new member's role applied

### Token security

- Tokens are UUIDs — 122 bits of entropy, not guessable
- One-time use: accepting sets `status = 'accepted'`; the RLS policy for `workspace_members` INSERT checks that the token is still `pending`
- Expiry enforced in application code (7-day check before showing accept UI) and optionally in a DB constraint
- Cancelled invitations (`status = 'cancelled'`) show an "This invite is no longer valid" message

---

## 7. Frontend Module Structure

### File layout

```
TaskTracker/
├── index.html                    (modified — add <script type="module"> tags)
├── style.css                     (modified — workspace switcher, invite modal, member badges)
├── config.js                     (updated — new Supabase project URL + anon key)
├── config.example.js             (updated — same)
├── js/
│   ├── supabase.js               (NEW) Supabase createClient, exports `sb`
│   ├── auth.js                   (NEW) login, logout, session check, invite param detection
│   ├── workspace.js              (NEW) workspace CRUD, member list, workspace switcher
│   ├── invitations.js            (NEW) createInvitation, acceptInvitation, cancelInvitation
│   ├── permissions.js            (NEW) canEdit(), canDelete(), canInvite(), getMyRole()
│   ├── storage.js                (NEW) all Supabase DB reads/writes, one fn per entity
│   ├── state.js                  (NEW) global state object, mutation functions
│   ├── realtime.js               (NEW) Supabase Realtime subscriptions + handlers
│   ├── notifications.js          (NEW) load notifications, mark read, bell badge
│   └── ui/
│       ├── workspace-switcher.js (NEW) workspace selector dropdown in sidebar
│       ├── dashboard.js          (extracted from app.js)
│       ├── projects.js           (extracted from app.js)
│       ├── tasks.js              (extracted from app.js)
│       ├── kanban.js             (extracted from app.js)
│       ├── calendar.js           (extracted from app.js)
│       ├── gantt.js              (extracted from app.js)
│       ├── analytics.js          (extracted from app.js)
│       └── team.js               (extracted + modified — team = workspace members)
└── app.js                        (SLIMMED DOWN — entry point, init, routing only, ~200 lines)
```

### Module responsibilities

**`supabase.js`** — Single place where the Supabase client is created and exported. All other modules import `sb` from here. Config is read from `window.APP_CONFIG`.

**`auth.js`** — Handles `sb.auth.signInWithPassword()`, `signUp()`, `signOut()`, `onAuthStateChange()`. On session start, checks URL for `?invite=token` and triggers invite flow if present.

**`workspace.js`** — `createWorkspace()`, `listWorkspaces()`, `loadWorkspace(id)`, `updateWorkspace()`. Also handles workspace switcher state — which workspace is active.

**`invitations.js`** — `createInvitation(opts)`, `acceptInvitation(token)`, `cancelInvitation(id)`, `listInvitations(workspaceId)`.

**`permissions.js`** — Reads `state.currentMember.role` (set at workspace load time). Exports synchronous guard functions used throughout the UI. The role is always known after workspace load — no async calls needed.

**`storage.js`** — Replaces the old `Storage.save()` / `Storage.load()` blob pattern. Exports targeted functions: `loadProjects(workspaceId)`, `saveProject(project)`, `deleteProject(id)`, `loadTasks(workspaceId)`, `saveTask(task)`, etc. Each function is a thin wrapper around `sb.from(table).select/insert/update/delete`.

**`state.js`** — Same global `state` object shape as before, but populated from individual table loads rather than one blob. Mutation functions (`setState`, `updateTask`, `addProject`, etc.) update state and call `scheduleSave(entity)` which debounces the relevant `storage.js` write.

**`realtime.js`** — `subscribeToWorkspace(workspaceId)` opens the workspace channel. Handlers for INSERT/UPDATE/DELETE events on each subscribed table update state and call the relevant view renderer. `subscribeToNotifications(userId)` opens the user notification channel.

**`app.js` (entry point)** — Imports all modules. On load: init auth → check session → detect invite param → load workspaces → set active workspace → call `realtime.subscribeToWorkspace()` → render initial view → bind keyboard shortcuts. Target: under 200 lines.

---

## 8. Realtime Strategy

### Channels

**`workspace-{workspace_id}`** (one per active workspace)
- Subscribes to `tasks`, `projects`, `milestones`, `sprints` filtered by `workspace_id`
- Events: INSERT, UPDATE, DELETE
- Handler: update local state array → re-render affected view

**`user-{user_id}`** (one per logged-in user)
- Subscribes to `notifications` filtered by `user_id`
- Events: INSERT only
- Handler: prepend to notifications list → update bell badge count

### Optimistic updates

When a user makes a change:
1. Update local `state` immediately (no wait)
2. Re-render affected view
3. Call `storage.saveXxx()` in the background
4. If DB write fails → roll back state + show toast error
5. When Supabase Realtime broadcasts the confirmed change → compare with local state; if identical, ignore (idempotent merge by entity `id` + `updated_at`)

### What is NOT on Realtime

- `task_activity` — append-only, fetched on demand when task detail modal opens
- `workspace_members` — low-frequency changes; polled on workspace reload
- `invitations` — low-frequency; no realtime needed

---

## 9. Supabase Configuration Steps

To set up the new project (`zynunureylcdexxhvdth`) from zero:

### Step 1 — Run schema migration

Run all `CREATE TABLE` statements from §3 in order:
1. `workspaces`
2. `workspace_members`
3. `invitations`
4. `notifications`
5. `projects`
6. `milestones`
7. `sprints`
8. `tasks`
9. `task_comments`
10. `task_activity`
11. All indexes from §3.4

### Step 2 — Enable RLS

```sql
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE sprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_activity ENABLE ROW LEVEL SECURITY;
```

### Step 3 — Create helper functions

Run `is_workspace_member()` and `get_my_workspace_role()` from §4.1.

### Step 4 — Create RLS policies

Apply policies per table as described in §4.2.

### Step 5 — Create notifications trigger

Create a DB trigger on `tasks` AFTER UPDATE that fires when `assignee_id` or `status` changes:

- **`assignee_id` changed:** insert a `task_assigned` notification for the new assignee (`new.assignee_id`), with `entity_type = 'task'`, `entity_id = new.id`
- **`status` changed:** insert a `status_changed` notification for the task `created_by` user (if different from the actor), with old/new status in `body`

The trigger runs with `SECURITY DEFINER` so it can insert into `notifications` bypassing the RLS INSERT block on that table (which otherwise prevents frontend direct inserts).

### Step 6 — Enable Realtime

In Supabase dashboard → Database → Replication → enable for:
- `tasks`
- `projects`
- `milestones`
- `sprints`
- `notifications`

### Step 7 — Update config.js

```js
window.APP_CONFIG = {
  supabaseUrl: 'https://zynunureylcdexxhvdth.supabase.co',
  supabaseKey: '<new-project-anon-key>'
};
```

Update GitHub Actions secrets (`SUPABASE_URL`, `SUPABASE_KEY`) to point to the new project.

---

## 10. New UI Elements

These UI components need to be added or modified in `index.html` and `style.css`:

| Component | Location | Description |
|---|---|---|
| Workspace switcher | Sidebar header | Dropdown showing all workspaces user belongs to; "Create workspace" option at bottom |
| Member avatars | Sidebar footer | Small avatar row showing online members (workspace_members) |
| Invite modal | Accessible from workspace switcher | Role selector + token link generator + copy button |
| Member management panel | Settings view (new) | List of workspace members, roles, invite status; remove member button |
| Collaborator badges | Task cards + task detail | Assignee avatar; "created by" attribution |
| Permission guards | All action buttons | Hide create/edit/delete buttons for Guest role |
| Access-denied state | Any write action from Guest | Tooltip or toast: "Guests can view but not edit" |
| Workspace onboarding | First load (new workspace) | Prompt to name workspace + invite first members |

---

## 11. Security Considerations

| Risk | Mitigation |
|---|---|
| Invite token brute force | UUIDs have 122 bits of entropy; not guessable in practice |
| Token reuse after acceptance | `status` check in accept flow; RLS on `workspace_members` INSERT |
| Expired invite used | Frontend checks `expires_at > now()` before showing accept UI |
| Privilege escalation via frontend | RLS enforces role at the DB level regardless of frontend state |
| Cross-workspace data leak | `workspace_id` on every table + membership subquery in all SELECT policies |
| Guest writing via API bypass | RLS `INSERT` policies block guests regardless of how the request is made |
| Notification injection | Notifications inserted only by DB trigger, never by frontend directly |
| Old project exposure | Old Supabase project (`dqpnhyjbuovsjmpebcis`) is entirely separate; no shared tables |

---

## 12. Implementation Phases

### Phase 1 — Foundation (Supabase + Auth + Workspace)
- Set up new Supabase project schema (all tables, RLS, indexes)
- Create `js/supabase.js`, `js/auth.js`
- Login/logout flow pointing to new project
- `js/workspace.js`: create workspace on first login, load workspace
- `js/state.js`: restructure state to be workspace-scoped
- `js/storage.js`: implement `loadProjects`, `loadTasks`, `loadMilestones`, `loadSprints`
- Verify: single user can log in, create workspace, add projects and tasks, see them persist

### Phase 2 — Modularization (Extract UI modules)
- Extract view renderers from `app.js` into `js/ui/*.js`
- Slim `app.js` to entry point only
- All views still work identically to before (same render output)
- Verify: full regression — all 8 views function correctly after extraction

### Phase 3 — Invitations + Members
- `js/invitations.js`: create, accept, cancel invite links
- `js/permissions.js`: role guards
- Invite modal UI + member management panel
- Workspace switcher in sidebar
- `team.js` updated to show real workspace members (from `workspace_members` table)
- Verify: owner creates invite link → second user accepts → both see same workspace

### Phase 4 — Realtime
- `js/realtime.js`: workspace channel + user notification channel
- Optimistic update pattern in `state.js`
- Verify: two browser tabs; change made in tab A appears in tab B within 1–2 seconds

### Phase 5 — Notifications + Activity
- Notifications DB trigger on `tasks`
- `js/notifications.js`: load, mark read, realtime bell
- `task_comments` UI in task detail modal
- `task_activity` display in task detail modal (fetched on open)
- Verify: assign task to member B → member B sees bell badge update in realtime

### Phase 6 — Polish + GitHub Pages Deploy
- Update GitHub Actions secrets for new Supabase project
- Permission guards on all UI elements
- Access-denied states for Guest role
- Workspace onboarding flow (first load)
- `config.js` + `config.example.js` updated
- Full regression across all views in both single-user and multi-user scenarios

---

## 13. Out of Scope for v1

- Email-based invitations (Resend/SendGrid integration)
- Presence indicators (who is online right now)
- Collaborative task editing with conflict resolution (Google Docs style)
- Per-project roles (Contributor/Reviewer/Viewer)
- Billing / plan enforcement
- Workspace analytics (member activity reports)
- Mobile-optimized UI

These can be added in v2 without changing the schema (the foundation supports them).
