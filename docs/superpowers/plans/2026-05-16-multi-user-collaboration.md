# TaskFlow SaaS — Multi-User Collaboration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform TaskFlow Pro from a single-user JSON-blob app into a collaborative multi-user SaaS platform on Supabase project `zynunureylcdexxhvdth`.

**Architecture:** The old `Storage.save/load` JSONB blob is replaced by per-entity Supabase table reads/writes across a 10-table normalized schema. `app.js` becomes a ~200-line ES module entry point. RLS enforces multi-tenancy at the DB level; `permissions.js` mirrors those rules in the UI. The old Supabase project (`dqpnhyjbuovsjmpebcis`) is left untouched.

**Tech Stack:** Vanilla JS ES Modules (no bundler), Supabase JS v2 via CDN (`window.supabase`), GitHub Pages, Supabase PostgreSQL + RLS + Realtime.

---

## Critical: Field Name Migration

Data from Supabase is **snake_case**. The old blob used **camelCase**. Every renderer and save function must use the new names:

| Old | New |
|---|---|
| `t.projectId` | `t.project_id` |
| `t.milestoneId` | `t.milestone_id` |
| `t.sprintId` | `t.sprint_id` |
| `t.parentTaskId` | `t.parent_task_id` |
| `t.dueDate` | `t.due_date` |
| `t.startDate` | `t.start_date` |
| `t.estimatedHours` | `t.estimated_hours` |
| `t.actualHours` | `t.actual_hours` |
| `t.createdAt` | `t.created_at` |
| `t.updatedAt` | `t.updated_at` |
| `p.startDate` | `p.start_date` |
| `p.endDate` | `p.end_date` |
| `p.baTeam` (string) | `p.ba_team` (text[]) |
| `p.createdAt` | `p.created_at` |
| `m.projectId` | `m.project_id` |
| `m.dueDate` | `m.due_date` |
| `m.sortOrder` | `m.sort_order` |
| `s.projectId` | `s.project_id` |
| `s.startDate` | `s.start_date` |
| `s.endDate` | `s.end_date` |
| `state.users` | `state.members` (workspace_members rows) |
| `u.avatarPreset` | `u.avatar_preset` |
| `u.avatarUrl` | `u.avatar_url` |

---

## File Map

**Create:**
```
migrations/001_schema.sql
migrations/002_rls_policies.sql
migrations/003_notifications_trigger.sql
js/supabase.js
js/utils.js
js/state.js
js/storage.js
js/auth.js
js/workspace.js
js/invitations.js
js/permissions.js
js/realtime.js
js/notifications.js
js/ui/workspace-switcher.js
js/ui/dashboard.js
js/ui/projects.js
js/ui/tasks.js
js/ui/kanban.js
js/ui/calendar.js
js/ui/gantt.js
js/ui/analytics.js
js/ui/team.js
```

**Modify:** `app.js`, `index.html`, `style.css`, `config.example.js`

---

## Phase 1: Foundation

### Task 1: Create SQL Schema Migration Files

**Files:**
- Create: `migrations/001_schema.sql`
- Create: `migrations/002_rls_policies.sql`

- [ ] **Step 1: Create `migrations/001_schema.sql`**

```sql
-- Run in Supabase SQL editor for project: zynunureylcdexxhvdth

CREATE TABLE workspaces (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text UNIQUE NOT NULL,
  owner_id    uuid NOT NULL REFERENCES auth.users(id),
  plan_type   text DEFAULT 'free',
  settings    jsonb DEFAULT '{}',
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

CREATE TABLE workspace_members (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role          text NOT NULL CHECK (role IN ('owner','member','guest')) DEFAULT 'member',
  display_name  text,
  avatar_url    text,
  avatar_preset int,
  color         text,
  skills        text[],
  joined_at     timestamptz DEFAULT now(),
  UNIQUE (workspace_id, user_id)
);

CREATE TABLE invitations (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  invited_by    uuid NOT NULL REFERENCES auth.users(id),
  token         text UNIQUE NOT NULL,
  role          text NOT NULL CHECK (role IN ('member','guest')) DEFAULT 'member',
  label         text,
  status        text NOT NULL CHECK (status IN ('pending','accepted','cancelled')) DEFAULT 'pending',
  accepted_by   uuid REFERENCES auth.users(id),
  expires_at    timestamptz NOT NULL,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE notifications (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type          text NOT NULL,
  title         text NOT NULL,
  body          text,
  entity_type   text,
  entity_id     uuid,
  read          boolean DEFAULT false,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE projects (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name          text NOT NULL,
  code          text,
  description   text,
  department    text,
  client        text,
  pm            text,
  ba_team       text[],
  status        text DEFAULT 'active' CHECK (status IN ('active','planning','onhold','completed','archived')),
  priority      text DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  start_date    date,
  end_date      date,
  budget        numeric,
  color         text,
  tags          text[],
  created_by    uuid NOT NULL REFERENCES auth.users(id),
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

CREATE TABLE milestones (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  due_date      date,
  status        text DEFAULT 'pending' CHECK (status IN ('pending','completed')),
  sort_order    int DEFAULT 0,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE sprints (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name          text NOT NULL,
  goal          text,
  start_date    date,
  end_date      date,
  status        text DEFAULT 'planning' CHECK (status IN ('planning','active','completed')),
  velocity      int,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE tasks (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id     uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  project_id       uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  milestone_id     uuid REFERENCES milestones(id) ON DELETE SET NULL,
  sprint_id        uuid REFERENCES sprints(id) ON DELETE SET NULL,
  parent_task_id   uuid REFERENCES tasks(id) ON DELETE SET NULL,
  title            text NOT NULL,
  description      text,
  priority         text DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  status           text DEFAULT 'pending' CHECK (status IN ('pending','inprogress','completed','blocked')),
  start_date       date,
  due_date         date,
  ba               text,
  assignee_id      uuid REFERENCES auth.users(id),
  estimated_hours  numeric,
  actual_hours     numeric,
  progress         int DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  tags             text[],
  documents        jsonb DEFAULT '[]',
  dependencies     uuid[],
  subtasks         jsonb DEFAULT '[]',
  notes            text,
  starred          boolean DEFAULT false,
  pinned           boolean DEFAULT false,
  created_by       uuid NOT NULL REFERENCES auth.users(id),
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

CREATE TABLE task_comments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  task_id       uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  author_id     uuid NOT NULL REFERENCES auth.users(id),
  content       text NOT NULL,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

CREATE TABLE task_activity (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  task_id       uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  actor_id      uuid NOT NULL REFERENCES auth.users(id),
  action        text NOT NULL,
  old_value     text,
  new_value     text,
  description   text,
  created_at    timestamptz DEFAULT now()
);

-- Indexes
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
CREATE INDEX ON invitations (token);
```

- [ ] **Step 2: Create `migrations/002_rls_policies.sql`**

```sql
-- Enable RLS on all tables
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

-- Helper functions
CREATE OR REPLACE FUNCTION is_workspace_member(_workspace_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = _workspace_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION get_my_workspace_role(_workspace_id uuid)
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM workspace_members
  WHERE workspace_id = _workspace_id AND user_id = auth.uid()
  LIMIT 1;
$$;

-- workspaces
CREATE POLICY "members view" ON workspaces FOR SELECT USING (is_workspace_member(id));
CREATE POLICY "auth create" ON workspaces FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());
CREATE POLICY "owner update" ON workspaces FOR UPDATE USING (owner_id = auth.uid());
CREATE POLICY "owner delete" ON workspaces FOR DELETE USING (owner_id = auth.uid());

-- workspace_members
CREATE POLICY "members view members" ON workspace_members FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "owner add members" ON workspace_members FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) = 'owner');
CREATE POLICY "owner update roles" ON workspace_members FOR UPDATE USING (get_my_workspace_role(workspace_id) = 'owner');
CREATE POLICY "owner remove or self-leave" ON workspace_members FOR DELETE USING (
  get_my_workspace_role(workspace_id) = 'owner' OR user_id = auth.uid()
);

-- invitations (SELECT open — token is the credential)
CREATE POLICY "anyone read invitations" ON invitations FOR SELECT USING (true);
CREATE POLICY "members create invitations" ON invitations FOR INSERT WITH CHECK (is_workspace_member(workspace_id));
CREATE POLICY "accepting user update" ON invitations FOR UPDATE USING (status = 'pending');
CREATE POLICY "owner cancel" ON invitations FOR DELETE USING (get_my_workspace_role(workspace_id) = 'owner');

-- projects
CREATE POLICY "members view projects" ON projects FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create projects" ON projects FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update projects" ON projects FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "owner or creator delete" ON projects FOR DELETE USING (get_my_workspace_role(workspace_id) = 'owner' OR created_by = auth.uid());

-- milestones
CREATE POLICY "members view milestones" ON milestones FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create milestones" ON milestones FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update milestones" ON milestones FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests delete milestones" ON milestones FOR DELETE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));

-- sprints
CREATE POLICY "members view sprints" ON sprints FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create sprints" ON sprints FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update sprints" ON sprints FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests delete sprints" ON sprints FOR DELETE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));

-- tasks
CREATE POLICY "members view tasks" ON tasks FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create tasks" ON tasks FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update tasks" ON tasks FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "owner or creator delete tasks" ON tasks FOR DELETE USING (get_my_workspace_role(workspace_id) = 'owner' OR created_by = auth.uid());

-- task_comments
CREATE POLICY "members view comments" ON task_comments FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create comments" ON task_comments FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "author update comment" ON task_comments FOR UPDATE USING (author_id = auth.uid());
CREATE POLICY "author or owner delete comment" ON task_comments FOR DELETE USING (author_id = auth.uid() OR get_my_workspace_role(workspace_id) = 'owner');

-- task_activity (append-only: no UPDATE or DELETE policies)
CREATE POLICY "members view activity" ON task_activity FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests log activity" ON task_activity FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));

-- notifications (INSERT via DB trigger only)
CREATE POLICY "own notifications" ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "mark read" ON notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "delete own" ON notifications FOR DELETE USING (user_id = auth.uid());
```

- [ ] **Step 3: Run migrations in Supabase SQL Editor**

Open https://supabase.com/dashboard/project/zynunureylcdexxhvdth/sql/new

Paste and run `001_schema.sql` first. Expected: "Success. No rows returned."

Then paste and run `002_rls_policies.sql`. Expected: "Success. No rows returned."

- [ ] **Step 4: Verify in Supabase Table Editor**

Open https://supabase.com/dashboard/project/zynunureylcdexxhvdth/editor

Confirm these tables exist: `workspaces`, `workspace_members`, `invitations`, `notifications`, `projects`, `milestones`, `sprints`, `tasks`, `task_comments`, `task_activity`.

Open Database → Functions. Confirm `is_workspace_member` and `get_my_workspace_role` exist.

- [ ] **Step 5: Commit migration files**

```bash
git add migrations/001_schema.sql migrations/002_rls_policies.sql
git commit -m "feat: add Supabase schema + RLS for multi-user collaboration"
```

---

### Task 2: Create `js/supabase.js`, `js/utils.js`, `js/state.js`

**Files:**
- Create: `js/supabase.js`
- Create: `js/utils.js`
- Create: `js/state.js`

- [ ] **Step 1: Create `js/supabase.js`**

```js
// Requires window.supabase from CDN <script> in index.html (loads before modules)
// Requires window.APP_CONFIG from config.js

if (!window.APP_CONFIG?.supabaseUrl || !window.APP_CONFIG?.supabaseKey) {
  document.body.innerHTML = `<div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0f172a;color:white;font-family:Arial,sans-serif;padding:40px"><div style="max-width:600px;background:#111827;padding:40px;border-radius:20px;border:1px solid #374151"><h1 style="margin-top:0">Configuration Missing</h1><p style="color:#d1d5db">Create a <code>config.js</code> file based on <code>config.example.js</code>, then reload.</p></div></div>`;
  throw new Error('APP_CONFIG not found — copy config.example.js to config.js');
}

export const sb = window.supabase.createClient(
  window.APP_CONFIG.supabaseUrl,
  window.APP_CONFIG.supabaseKey,
  { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
);
```

- [ ] **Step 2: Create `js/utils.js`**

```js
export const AVATAR_PRESETS = [
  { icon: '👤', color: '#2563eb' }, { icon: '👩', color: '#db2777' },
  { icon: '👨', color: '#0891b2' }, { icon: '👩‍💼', color: '#7c3aed' },
  { icon: '👨‍💼', color: '#059669' }, { icon: '👩‍💻', color: '#dc2626' },
  { icon: '👨‍💻', color: '#d97706' }, { icon: '👩‍🔬', color: '#65a30d' },
  { icon: '👨‍🔬', color: '#0891b2' }, { icon: '🧑‍🎨', color: '#db2777' },
  { icon: '🧑‍🏫', color: '#7c3aed' }, { icon: '🧑‍💻', color: '#2563eb' },
];

export const PROJECT_COLORS = [
  '#2563eb','#059669','#7c3aed','#d97706',
  '#dc2626','#0891b2','#db2777','#65a30d'
];

export const STATUS_META = {
  pending:    { label: 'Pending',     dot: '#fbbf24', color: '#d97706' },
  inprogress: { label: 'In Progress', dot: '#60a5fa', color: '#2563eb' },
  completed:  { label: 'Completed',   dot: '#34d399', color: '#059669' },
  blocked:    { label: 'Blocked',     dot: '#f87171', color: '#dc2626' },
};

export const PRIORITY_META = {
  low:      { label: 'Low',      order: 1 },
  medium:   { label: 'Medium',   order: 2 },
  high:     { label: 'High',     order: 3 },
  critical: { label: 'Critical', order: 4 },
};

export function uid() { return '_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }
export function today() { return new Date().toISOString().split('T')[0]; }
export function fmtDate(d) {
  if (!d) return '—';
  return new Date(d + 'T00:00:00').toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}
export function isOverdue(t) {
  return t.due_date && t.status !== 'completed' && new Date(t.due_date) < new Date(new Date().toDateString());
}
export function daysUntil(d) {
  if (!d) return null;
  return Math.round((new Date(d) - new Date(new Date().toDateString())) / 86400000);
}
export function esc(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
export function getTagColor(tag) {
  let h = 0; for (let c of String(tag)) h = (h * 31 + c.charCodeAt(0)) & 0xffffffff; return Math.abs(h) % 8;
}
export function calcProgress(task) {
  if (!task.subtasks?.length) return task.progress || 0;
  const done = task.subtasks.filter(s => s.done).length;
  return Math.round(done / task.subtasks.length * 100);
}
export function openOverlay(id) { document.getElementById(id)?.classList.add('open'); }
export function closeOverlay(id) { document.getElementById(id)?.classList.remove('open'); }
export function $id(id) { return document.getElementById(id); }
export function setVal(id, v) { const el = $id(id); if (el) el.value = v ?? ''; }
export function markError(id, msg) {
  const el = $id(id); if (!el) return;
  const fg = el.closest('.form-group');
  if (fg) {
    fg.classList.add('has-error');
    if (!fg.querySelector('.field-error')) {
      const e = document.createElement('span');
      e.className = 'field-error'; e.textContent = msg; fg.appendChild(e);
    }
  }
  el.focus();
}

const TOAST_ICONS = {
  success: `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>`,
  error:   `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>`,
  warning: `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>`,
  info:    `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/></svg>`,
};
export function toast(msg, type = 'info', dur = 3500) {
  const c = document.getElementById('toastContainer'); if (!c) return;
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = `${TOAST_ICONS[type] || ''}<span class="toast-msg">${esc(msg)}</span><span class="toast-close">×</span>`;
  el.querySelector('.toast-close').addEventListener('click', () => el.remove());
  c.appendChild(el);
  setTimeout(() => el.remove(), dur + 300);
}
```

- [ ] **Step 3: Create `js/state.js`**

```js
export const state = {
  // Auth
  currentUser: null,          // Supabase auth user object

  // Workspace
  workspaces: [],             // all workspaces user belongs to
  activeWorkspaceId: null,    // currently selected workspace id
  currentMember: null,        // workspace_members row for current user in active workspace

  // Entities (all workspace-scoped, snake_case from DB)
  projects:   [],
  tasks:      [],
  milestones: [],
  sprints:    [],
  members:    [],             // workspace_members for active workspace

  // UI state
  settings:         { theme: 'light' },
  activeProjectId:  null,
  currentView:      'dashboard',
  activeProjectTab: 'overview',
  projectViewMode:  'grid',
  sortField:        'created_at',
  sortDir:          'desc',
  filters:          { project:'', status:'', priority:'', ba:'', milestone:'', from:'', to:'' },
  searchQuery:      '',
  calendarDate:     new Date(),
  draggedTaskId:    null,
  formTags:         [],
  formDocs:         [],
  formSubtasks:     [],
  projTags:         [],
  cmdIndex:         0,
  notifications:    [],
  savedViews:       [],
};

export function setState(updates) { Object.assign(state, updates); }

export function updateEntity(arrayKey, id, updates) {
  const idx = state[arrayKey].findIndex(e => e.id === id);
  if (idx !== -1) state[arrayKey][idx] = { ...state[arrayKey][idx], ...updates };
}

export function addEntity(arrayKey, entity) { state[arrayKey].push(entity); }

export function removeEntity(arrayKey, id) {
  state[arrayKey] = state[arrayKey].filter(e => e.id !== id);
}

// Data helpers (used by renderers)
export function findTask(id) { return state.tasks.find(t => t.id === id); }
export function findProject(id) { return state.projects.find(p => p.id === id); }
export function getProjectTasks(pid) { return state.tasks.filter(t => t.project_id === pid); }
export function getActiveTasks() { return state.activeProjectId ? getProjectTasks(state.activeProjectId) : state.tasks; }
export function getBAList() { return [...new Set(state.tasks.map(t => t.ba).filter(Boolean))].sort(); }
```

- [ ] **Step 4: Verify modules load**

Update `config.js` to point to the new Supabase project:
```js
window.APP_CONFIG = {
  supabaseUrl: 'https://zynunureylcdexxhvdth.supabase.co',
  supabaseKey: 'YOUR_NEW_PROJECT_ANON_KEY'
};
```
Get the anon key from: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/settings/api

Temporarily add to `index.html` before the closing `</body>`:
```html
<script type="module">
  import { sb } from './js/supabase.js';
  import { state } from './js/state.js';
  console.log('[verify] sb:', sb ? 'ok' : 'FAIL');
  console.log('[verify] state:', state ? 'ok' : 'FAIL');
</script>
```
Open index.html in browser. Check console. Expected: `[verify] sb: ok` and `[verify] state: ok`. Remove the test script after.

- [ ] **Step 5: Commit**

```bash
git add js/supabase.js js/utils.js js/state.js
git commit -m "feat: add supabase client, utils, and state modules"
```

---

### Task 3: Create `js/storage.js`

**Files:**
- Create: `js/storage.js`

- [ ] **Step 1: Create `js/storage.js`**

```js
import { sb } from './supabase.js';
import { state } from './state.js';

// Load all workspace data in parallel
export async function loadWorkspaceData(workspaceId) {
  const [proj, tasks, ms, sp, members] = await Promise.all([
    sb.from('projects').select('*').eq('workspace_id', workspaceId).order('created_at'),
    sb.from('tasks').select('*').eq('workspace_id', workspaceId).order('created_at'),
    sb.from('milestones').select('*').eq('workspace_id', workspaceId).order('sort_order'),
    sb.from('sprints').select('*').eq('workspace_id', workspaceId).order('created_at'),
    sb.from('workspace_members').select('*').eq('workspace_id', workspaceId),
  ]);
  for (const r of [proj, tasks, ms, sp, members]) if (r.error) throw r.error;
  return {
    projects:   proj.data,
    tasks:      tasks.data,
    milestones: ms.data,
    sprints:    sp.data,
    members:    members.data,
  };
}

// Projects
export async function saveProject(project) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id: workspaceId,
    name:         project.name,
    code:         project.code || null,
    description:  project.description || null,
    department:   project.department || null,
    client:       project.client || null,
    pm:           project.pm || null,
    ba_team:      project.ba_team || [],
    status:       project.status || 'active',
    priority:     project.priority || 'medium',
    start_date:   project.start_date || null,
    end_date:     project.end_date || null,
    budget:       project.budget || null,
    color:        project.color || '#2563eb',
    tags:         project.tags || [],
    updated_at:   new Date().toISOString(),
  };
  if (project.id) {
    const { error } = await sb.from('projects').update(payload).eq('id', project.id);
    if (error) throw error;
    return project;
  } else {
    const { data, error } = await sb.from('projects')
      .insert({ ...payload, created_by: state.currentUser.id })
      .select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteProject(id) {
  const { error } = await sb.from('projects').delete().eq('id', id);
  if (error) throw error;
}

// Tasks
export async function saveTask(task) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id:   workspaceId,
    project_id:     task.project_id,
    milestone_id:   task.milestone_id || null,
    sprint_id:      task.sprint_id || null,
    parent_task_id: task.parent_task_id || null,
    title:          task.title,
    description:    task.description || null,
    priority:       task.priority || 'medium',
    status:         task.status || 'pending',
    start_date:     task.start_date || null,
    due_date:       task.due_date || null,
    ba:             task.ba || null,
    assignee_id:    task.assignee_id || null,
    estimated_hours: task.estimated_hours || null,
    actual_hours:   task.actual_hours || null,
    progress:       task.progress || 0,
    tags:           task.tags || [],
    documents:      task.documents || [],
    dependencies:   task.dependencies || [],
    subtasks:       task.subtasks || [],
    notes:          task.notes || null,
    starred:        task.starred || false,
    pinned:         task.pinned || false,
    updated_at:     new Date().toISOString(),
  };
  if (task.id) {
    const { error } = await sb.from('tasks').update(payload).eq('id', task.id);
    if (error) throw error;
    return task;
  } else {
    const { data, error } = await sb.from('tasks')
      .insert({ ...payload, created_by: state.currentUser.id })
      .select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteTask(id) {
  const { error } = await sb.from('tasks').delete().eq('id', id);
  if (error) throw error;
}

// Milestones
export async function saveMilestone(milestone) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id: workspaceId,
    project_id:   milestone.project_id,
    name:         milestone.name,
    description:  milestone.description || null,
    due_date:     milestone.due_date || null,
    status:       milestone.status || 'pending',
    sort_order:   milestone.sort_order || 0,
  };
  if (milestone.id) {
    const { error } = await sb.from('milestones').update(payload).eq('id', milestone.id);
    if (error) throw error;
    return milestone;
  } else {
    const { data, error } = await sb.from('milestones').insert(payload).select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteMilestone(id) {
  const { error } = await sb.from('milestones').delete().eq('id', id);
  if (error) throw error;
}

// Sprints
export async function saveSprint(sprint) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id: workspaceId,
    project_id:   sprint.project_id,
    name:         sprint.name,
    goal:         sprint.goal || null,
    start_date:   sprint.start_date || null,
    end_date:     sprint.end_date || null,
    status:       sprint.status || 'planning',
    velocity:     sprint.velocity || null,
  };
  if (sprint.id) {
    const { error } = await sb.from('sprints').update(payload).eq('id', sprint.id);
    if (error) throw error;
    return sprint;
  } else {
    const { data, error } = await sb.from('sprints').insert(payload).select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteSprint(id) {
  const { error } = await sb.from('sprints').delete().eq('id', id);
  if (error) throw error;
}

// Workspace members
export async function updateMember(memberId, updates) {
  const { error } = await sb.from('workspace_members').update(updates).eq('id', memberId);
  if (error) throw error;
}

export async function removeMember(memberId) {
  const { error } = await sb.from('workspace_members').delete().eq('id', memberId);
  if (error) throw error;
}

// Task comments
export async function loadTaskComments(taskId) {
  const { data, error } = await sb.from('task_comments')
    .select('*, author:author_id(id, email)')
    .eq('task_id', taskId)
    .order('created_at');
  if (error) throw error;
  return data;
}

export async function saveTaskComment(taskId, content) {
  const { data, error } = await sb.from('task_comments')
    .insert({ task_id: taskId, workspace_id: state.activeWorkspaceId, author_id: state.currentUser.id, content })
    .select().single();
  if (error) throw error;
  return data;
}

export async function deleteTaskComment(commentId) {
  const { error } = await sb.from('task_comments').delete().eq('id', commentId);
  if (error) throw error;
}

// Task activity
export async function loadTaskActivity(taskId) {
  const { data, error } = await sb.from('task_activity')
    .select('*')
    .eq('task_id', taskId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data;
}

export async function logTaskActivity(taskId, action, oldValue, newValue, description) {
  const { error } = await sb.from('task_activity').insert({
    workspace_id: state.activeWorkspaceId,
    task_id:      taskId,
    actor_id:     state.currentUser.id,
    action, old_value: oldValue, new_value: newValue, description,
  });
  if (error) throw error;
}
```

- [ ] **Step 2: Verify storage module loads**

In the browser console (after the Task 2 verification script is removed), add temporarily to index.html:
```html
<script type="module">
  import { loadWorkspaceData } from './js/storage.js';
  console.log('[verify] storage module loaded');
</script>
```
Expected: no import errors. Remove after.

- [ ] **Step 3: Commit**

```bash
git add js/storage.js
git commit -m "feat: add storage module with per-entity Supabase operations"
```

---

### Task 4: Create `js/auth.js` and `js/workspace.js`

**Files:**
- Create: `js/auth.js`
- Create: `js/workspace.js`

- [ ] **Step 1: Create `js/auth.js`**

```js
import { sb } from './supabase.js';
import { state, setState } from './state.js';

export async function getSession() {
  const { data: { session } } = await sb.auth.getSession();
  return session;
}

export async function signIn(email, password) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  setState({ currentUser: data.user });
  return data.user;
}

export async function signUp(email, password) {
  const { data, error } = await sb.auth.signUp({ email, password });
  if (error) throw error;
  setState({ currentUser: data.user });
  return data.user;
}

export async function signOut() {
  await sb.auth.signOut();
  setState({ currentUser: null, workspaces: [], activeWorkspaceId: null, currentMember: null,
    projects: [], tasks: [], milestones: [], sprints: [], members: [], notifications: [] });
}

export function onAuthStateChange(callback) {
  return sb.auth.onAuthStateChange((event, session) => {
    callback(event, session?.user ?? null);
  });
}

// Returns ?invite=<token> param value or null
export function getInviteToken() {
  return new URLSearchParams(window.location.search).get('invite');
}

// Removes ?invite param from URL without reload
export function clearInviteParam() {
  const url = new URL(window.location.href);
  url.searchParams.delete('invite');
  window.history.replaceState({}, '', url.toString());
}
```

- [ ] **Step 2: Create `js/workspace.js`**

```js
import { sb } from './supabase.js';
import { state, setState } from './state.js';
import { loadWorkspaceData } from './storage.js';

function slugify(name) {
  const base = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const suffix = Math.random().toString(36).slice(2, 6);
  return `${base}-${suffix}`;
}

export async function listWorkspaces(userId) {
  const { data, error } = await sb
    .from('workspace_members')
    .select('workspace_id, role, workspaces(*)')
    .eq('user_id', userId);
  if (error) throw error;
  return data.map(row => ({ ...row.workspaces, myRole: row.role }));
}

export async function createWorkspace(name, userId) {
  const slug = slugify(name);
  const { data: ws, error: wsErr } = await sb
    .from('workspaces')
    .insert({ name, slug, owner_id: userId })
    .select().single();
  if (wsErr) throw wsErr;

  const { error: memErr } = await sb.from('workspace_members').insert({
    workspace_id: ws.id,
    user_id:      userId,
    role:         'owner',
    display_name: null,
  });
  if (memErr) throw memErr;
  return ws;
}

export async function loadWorkspace(workspaceId) {
  const data = await loadWorkspaceData(workspaceId);
  const currentMember = data.members.find(m => m.user_id === state.currentUser?.id) || null;
  setState({
    activeWorkspaceId: workspaceId,
    currentMember,
    projects:   data.projects,
    tasks:      data.tasks,
    milestones: data.milestones,
    sprints:    data.sprints,
    members:    data.members,
  });
}

export async function updateWorkspace(workspaceId, updates) {
  const { error } = await sb.from('workspaces')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', workspaceId);
  if (error) throw error;
}
```

- [ ] **Step 3: Commit**

```bash
git add js/auth.js js/workspace.js
git commit -m "feat: add auth and workspace modules"
```

---

## Phase 2: Modularization + App Bootstrap

### Task 5: Update `index.html` and `app.js` to Bootstrap from Modules

**Files:**
- Modify: `index.html`
- Modify: `app.js`

- [ ] **Step 1: Update `index.html` script section**

In `index.html`, find the closing `</body>` tag. The current file has:
```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```
in `<head>`. Keep it there. Find where `app.js` is loaded (likely near the bottom) and change:
```html
<script src="app.js"></script>
```
to:
```html
<script type="module" src="app.js"></script>
```

Also add a notifications bell to the topbar. Find `<div class="topbar-right">` (around line 178) and add before the first button:
```html
<button class="topbar-icon-btn" id="notificationBell" title="Notifications" style="position:relative;display:none">
  <svg viewBox="0 0 20 20" fill="currentColor" width="18" height="18"><path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-2.83-2h5.66A3 3 0 0110 18z"/></svg>
  <span id="notificationBadge" class="notification-badge" style="display:none">0</span>
</button>
```

Add workspace name display to the sidebar-brand div (find `<div class="sidebar-brand">`, add after the brand-name span):
```html
<div id="workspaceNameDisplay" class="workspace-name-display" style="display:none;font-size:.7rem;color:var(--text-3);padding:2px 8px 0"></div>
```

Add an invite modal before `</body>`:
```html
<div class="overlay" id="inviteOverlay">
  <div class="modal modal-sm">
    <div class="modal-header">
      <h3 class="modal-title">Invite Member</h3>
      <button class="modal-close" id="inviteClose">×</button>
    </div>
    <div class="modal-body" id="inviteModalBody">
      <div class="form-group">
        <label>Role</label>
        <select id="inviteRole" class="filter-select" style="width:100%">
          <option value="member">Member</option>
          <option value="guest">Guest (view only)</option>
        </select>
      </div>
      <div class="form-group">
        <label>Label (optional)</label>
        <input type="text" id="inviteLabel" class="form-input" placeholder="e.g. For Ahmed — Dev"/>
      </div>
      <button class="btn btn-primary" id="generateInviteBtn" style="width:100%">Generate Invite Link</button>
      <div id="inviteLinkWrap" style="display:none;margin-top:12px">
        <label style="font-size:.78rem;color:var(--text-3)">Share this link:</label>
        <div style="display:flex;gap:8px;margin-top:4px">
          <input type="text" id="inviteLinkInput" class="form-input" readonly style="font-size:.75rem"/>
          <button class="btn btn-secondary btn-sm" id="copyInviteBtn">Copy</button>
        </div>
        <p style="font-size:.72rem;color:var(--text-3);margin-top:6px">Expires in 7 days. One-time use.</p>
      </div>
    </div>
  </div>
</div>
```

Add member management panel (Settings view). Find the last `</section>` before `</main>` and add:
```html
<section id="view-settings" class="view">
  <div class="view-header">
    <div><h1 class="view-title">Workspace Settings</h1></div>
    <div class="view-actions">
      <button class="btn btn-primary" id="openInviteBtn">+ Invite Member</button>
    </div>
  </div>
  <div id="membersContainer" class="team-grid"></div>
</section>
```

Add Settings link to sidebar nav (after Team link):
```html
<li><a class="nav-link" data-view="settings" href="#">
  <svg class="nav-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd"/></svg>
  <span class="nav-label">Settings</span>
</a></li>
```

- [ ] **Step 2: Replace app.js with new entry-point bootstrap**

Replace the entire contents of `app.js` with:

```js
'use strict';
import { sb } from './js/supabase.js';
import { state, setState, findProject } from './js/state.js';
import { $id, esc, setVal, openOverlay, closeOverlay, toast } from './js/utils.js';
import { getSession, signIn, signUp, signOut, onAuthStateChange, getInviteToken, clearInviteParam } from './js/auth.js';
import { listWorkspaces, createWorkspace, loadWorkspace } from './js/workspace.js';
import { createInvitation, acceptInvitation } from './js/invitations.js';
import { canEdit, canDelete, canInvite, canManageMembers } from './js/permissions.js';
import { subscribeToWorkspace, subscribeToNotifications, unsubscribeAll } from './js/realtime.js';
import { loadNotifications, updateBell } from './js/notifications.js';
import { renderDashboard } from './js/ui/dashboard.js';
import { renderProjects, renderProjectDetail, openProjectForm, saveProject, confirmDeleteProject } from './js/ui/projects.js';
import { renderTaskList, openTaskForm, saveTask, openTaskDetail, confirmDeleteTask } from './js/ui/tasks.js';
import { renderKanban } from './js/ui/kanban.js';
import { renderCalendar } from './js/ui/calendar.js';
import { renderGantt } from './js/ui/gantt.js';
import { renderAnalytics } from './js/ui/analytics.js';
import { renderTeam, openMemberForm, saveMember } from './js/ui/team.js';
import { renderWorkspaceSwitcher, renderInviteModal } from './js/ui/workspace-switcher.js';

// Expose functions called from inline onclick attributes in HTML render output
window.openTaskForm = openTaskForm;
window.openTaskDetail = openTaskDetail;
window.confirmDeleteTask = confirmDeleteTask;
window.openProjectDetail = (pid) => { switchView('project-detail'); openProjectDetailView(pid); };
window.openProjectForm = openProjectForm;
window.confirmDeleteProject = confirmDeleteProject;
window.openMemberForm = openMemberForm;
window.saveMember = saveMember;
window.closeOverlay = closeOverlay;

// ── View Routing ──────────────────────────────────────────────
export function switchView(name) {
  state.currentView = name;
  document.querySelectorAll('.view').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.nav-link[data-view]').forEach(el => el.classList.remove('active'));
  $id('view-' + name)?.classList.add('active');
  document.querySelector(`.nav-link[data-view="${name}"]`)?.classList.add('active');
  $id('sidebar')?.classList.remove('mobile-open');
  const renderers = {
    dashboard: renderDashboard, projects: renderProjects, tasks: renderTaskList,
    kanban: renderKanban, calendar: renderCalendar, gantt: renderGantt,
    analytics: renderAnalytics, team: renderTeam, settings: renderSettingsView,
  };
  renderers[name]?.();
  updateBreadcrumb(name);
  updateNavBadges();
  updateSidebarProjects();
}

export function openProjectDetailView(pid) {
  state.activeProjectId = pid;
  state.activeProjectTab = 'overview';
  document.querySelectorAll('.view').forEach(el => el.classList.remove('active'));
  $id('view-project-detail')?.classList.add('active');
  renderProjectDetail(pid);
  updateBreadcrumb('project-detail');
  updateNavBadges();
  updateSidebarProjects();
}

export function refreshView() {
  if (state.currentView === 'project-detail') renderProjectDetail(state.activeProjectId);
  else switchView(state.currentView);
}

function updateBreadcrumb(view) {
  const el = $id('topbarBreadcrumb'); if (!el) return;
  const labels = { dashboard:'Dashboard', projects:'Projects', tasks:'All Tasks', kanban:'Kanban',
    calendar:'Calendar', gantt:'Gantt Timeline', analytics:'Analytics', team:'Team', settings:'Settings' };
  if (view === 'project-detail') {
    const p = findProject(state.activeProjectId);
    el.innerHTML = `<span class="crumb-item" style="cursor:pointer" id="breadProjects">Projects</span><span class="crumb-sep"> › </span><span class="crumb-current" style="color:${p?.color || 'var(--primary)'}">${esc(p?.name || 'Project')}</span>`;
    $id('breadProjects')?.addEventListener('click', () => switchView('projects'));
  } else {
    el.innerHTML = `<span class="crumb-item">${labels[view] || view}</span>`;
  }
}

function updateNavBadges() {
  const pb = $id('navBadgeProjects'); if (pb) pb.textContent = state.projects.filter(p => p.status === 'active').length;
  const tb = $id('navBadgeTasks'); if (tb) tb.textContent = state.tasks.filter(t => t.status !== 'completed').length;
}

function updateSidebarProjects() {
  const list = $id('sidebarProjectList'); if (!list) return;
  $id('clearActiveProjectBtn') && ($id('clearActiveProjectBtn').style.display = state.activeProjectId ? '' : 'none');
  list.innerHTML = state.projects.filter(p => p.status !== 'archived').map(p => {
    const count = state.tasks.filter(t => t.project_id === p.id && t.status !== 'completed').length;
    return `<li><div class="nav-project-item${state.activeProjectId === p.id ? ' active' : ''}" data-pid="${esc(p.id)}">
      <div class="nav-project-dot" style="background:${esc(p.color || '#2563eb')}"></div>
      <span class="nav-project-name">${esc(p.name)}</span>
      ${count ? `<span class="nav-project-count">${count}</span>` : ''}
    </div></li>`;
  }).join('');
  list.querySelectorAll('.nav-project-item').forEach(el =>
    el.addEventListener('click', () => { state.activeProjectId = el.dataset.pid; switchView('project-detail'); openProjectDetailView(el.dataset.pid); })
  );
}

function renderSettingsView() {
  import('./js/ui/workspace-switcher.js').then(m => m.renderMembersPanel());
}

// ── Auth UI ───────────────────────────────────────────────────
function showApp() {
  $id('loginScreen').style.display = 'none';
  $id('app').style.display = '';
  $id('logoutBtn') && ($id('logoutBtn').style.display = '');
  const ws = $id('workspaceNameDisplay');
  if (ws && state.activeWorkspaceId) {
    const w = state.workspaces.find(x => x.id === state.activeWorkspaceId);
    ws.textContent = w?.name || '';
    ws.style.display = '';
  }
  $id('notificationBell') && ($id('notificationBell').style.display = '');
}

function showLogin() {
  $id('loginScreen').style.display = 'flex';
  $id('app').style.display = 'none';
}

function setLoginError(msg = '') {
  const el = $id('loginError'); if (!el) return;
  el.style.display = msg ? 'block' : 'none';
  el.textContent = msg;
}

function setTheme(theme) {
  state.settings.theme = theme;
  document.documentElement.setAttribute('data-theme', theme);
  const lbl = $id('themeLabel'); if (lbl) lbl.textContent = theme === 'dark' ? 'Light Mode' : 'Dark Mode';
}

// ── App Init ──────────────────────────────────────────────────
async function initApp() {
  const session = await getSession();
  if (!session) { showLogin(); return; }
  setState({ currentUser: session.user });

  // Check for invite token before loading workspaces
  const inviteToken = getInviteToken();

  const workspaces = await listWorkspaces(session.user.id);
  setState({ workspaces });

  if (inviteToken) {
    try {
      const joined = await acceptInvitation(inviteToken, session.user.id);
      clearInviteParam();
      toast(`Joined workspace "${joined.workspace_name}"`, 'success');
      // Reload workspaces after joining
      const refreshed = await listWorkspaces(session.user.id);
      setState({ workspaces: refreshed });
      await activateWorkspace(joined.workspace_id);
    } catch (e) {
      toast(e.message || 'Invite link invalid or expired', 'error');
      if (workspaces.length) await activateWorkspace(workspaces[0].id);
      else showOnboarding();
    }
    return;
  }

  if (!workspaces.length) { showLogin(); showOnboarding(); return; }
  await activateWorkspace(workspaces[0].id);
}

async function activateWorkspace(workspaceId) {
  await loadWorkspace(workspaceId);
  const notifs = await loadNotifications(workspaceId, state.currentUser.id);
  setState({ notifications: notifs });
  updateBell(state.notifications);
  subscribeToWorkspace(workspaceId, refreshView);
  subscribeToNotifications(state.currentUser.id, (notif) => {
    state.notifications.unshift(notif);
    updateBell(state.notifications);
  });
  setTheme(state.settings.theme || 'light');
  showApp();
  switchView('dashboard');
}

function showOnboarding() {
  // Simple onboarding: prompt for workspace name
  const name = prompt('Welcome! Enter a name for your workspace:');
  if (!name?.trim()) { showLogin(); return; }
  createWorkspace(name.trim(), state.currentUser.id)
    .then(ws => {
      const ws2 = { ...ws, myRole: 'owner' };
      setState({ workspaces: [ws2] });
      return activateWorkspace(ws.id);
    })
    .catch(e => { toast(e.message, 'error'); showLogin(); });
}

// ── Event Binding ─────────────────────────────────────────────
function bindEvents() {
  document.querySelectorAll('.nav-link[data-view]').forEach(link =>
    link.addEventListener('click', e => { e.preventDefault(); switchView(link.dataset.view); })
  );
  $id('sidebarCollapseBtn')?.addEventListener('click', () => $id('sidebar').classList.toggle('collapsed'));
  $id('menuBtn')?.addEventListener('click', () => $id('sidebar').classList.toggle('mobile-open'));
  $id('themeToggle')?.addEventListener('click', () => setTheme(state.settings.theme === 'dark' ? 'light' : 'dark'));

  $id('loginBtn')?.addEventListener('click', async () => {
    setLoginError();
    const email = $id('loginEmail')?.value.trim();
    const pass  = $id('loginPassword')?.value;
    try { await signIn(email, pass); await initApp(); }
    catch (e) { setLoginError(e.message); }
  });
  $id('signupBtn')?.addEventListener('click', async () => {
    setLoginError();
    const email = $id('loginEmail')?.value.trim();
    const pass  = $id('loginPassword')?.value;
    try { await signUp(email, pass); await initApp(); }
    catch (e) { setLoginError(e.message); }
  });
  $id('logoutBtn')?.addEventListener('click', async () => {
    unsubscribeAll();
    await signOut();
    showLogin();
  });

  ['newTaskBtn','newTaskBtnList'].forEach(id =>
    $id(id)?.addEventListener('click', () => openTaskForm(null, state.activeProjectId))
  );
  ['newProjectBtn','newProjectTopBtn','newProjectSidebarBtn'].forEach(id =>
    $id(id)?.addEventListener('click', e => { e.preventDefault(); openProjectForm(); })
  );
  $id('openInviteBtn')?.addEventListener('click', () => {
    renderInviteModal();
    openOverlay('inviteOverlay');
  });
  $id('inviteClose')?.addEventListener('click', () => closeOverlay('inviteOverlay'));
  $id('clearActiveProjectBtn')?.addEventListener('click', () => { state.activeProjectId = null; refreshView(); updateSidebarProjects(); });

  document.addEventListener('keydown', e => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') { e.preventDefault(); import('./js/ui/dashboard.js').then(m => m.openCommandPalette?.()); }
  });
}

// ── Bootstrap ─────────────────────────────────────────────────
onAuthStateChange(async (event, user) => {
  if (event === 'SIGNED_OUT') { setState({ currentUser: null }); showLogin(); }
});

bindEvents();
initApp();
```

- [ ] **Step 3: Verify app loads in browser**

Open `index.html` in the browser. Expected:
- Login screen appears (modules loaded without errors)
- Console shows no import errors
- Sign in with a test account works (or sign up creates a new one)
- After sign in, workspace is created, app view appears

- [ ] **Step 4: Commit**

```bash
git add index.html app.js
git commit -m "feat: switch to ES module entry point with workspace bootstrap"
```

---

### Task 6: Create UI Modules (dashboard, projects, tasks)

**Files:**
- Create: `js/ui/dashboard.js`
- Create: `js/ui/projects.js`
- Create: `js/ui/tasks.js`

- [ ] **Step 1: Create `js/ui/dashboard.js`**

Copy `renderDashboard()` (app.js:443–552), `renderCommandResults()` (app.js:1857–1897), `openCommandPalette()` (app.js:1850–1857), `handleSearch()` (app.js:1811–1850) from app.js into this file. Add imports at top and exports at bottom. Apply field name renames:

- `t.dueDate` → `t.due_date`
- `t.createdAt` → `t.created_at`
- `t.projectId` → `t.project_id`
- `p.createdAt` → `p.created_at`
- `p.startDate` / `p.endDate` → `p.start_date` / `p.end_date`
- `getActiveTasks()` is now imported from state.js
- `state.users` → `state.members`

```js
import { state, getActiveTasks, findProject, findTask } from '../state.js';
import { $id, esc, fmtDate, isOverdue, daysUntil, toast, STATUS_META, PRIORITY_META } from '../utils.js';
import { switchView } from '../../app.js';

export function renderDashboard() { /* copy from app.js:443, applying field renames */ }
export function openCommandPalette() { /* copy from app.js:1850 */ }
export function handleSearch(q) { /* copy from app.js:1811 */ }
// ... other helpers
```

> **Note on circular import:** `dashboard.js` imports `switchView` from `app.js`. To avoid a circular dependency issue (app.js also imports dashboard.js), pass `switchView` as a parameter instead:

```js
// dashboard.js — no import from app.js
export function renderDashboard(switchViewFn) { ... }
// In app.js, call as: renderDashboard.bind(null) and pass switchView where needed via a shared ref

// Cleaner: use a shared router module
```

Create `js/router.js` to break the circular dependency:
```js
// js/router.js — shared reference to switchView, set at init time
let _switchView = null;
export function setRouter(fn) { _switchView = fn; }
export function navigate(view) { _switchView?.(view); }
```

In `app.js` after defining `switchView`, add: `import { setRouter } from './js/router.js'; setRouter(switchView);`

In `dashboard.js` and other UI modules, import `navigate` from `../router.js` instead of importing from `../../app.js`.

- [ ] **Step 2: Create `js/ui/projects.js`**

Copy from app.js:
- `renderProjects()` (line 553)
- `renderProjectDetail(pid)` (line 640)
- `renderProjectTab(pid, tab)` (line 702)
- `openProjectForm(projectId)` (line 1633)
- `saveProject()` (line 1663) — **rewrite** to call `storage.saveProject()` instead of mutating blob
- `confirmDeleteProject(pid)` (line 1699) — **rewrite** to call `storage.deleteProject()`
- `openMilestoneForm()`, `saveMilestone()`, `openSprintForm()`, `saveSprint()` (lines 1721–1792)

Apply field renames: `p.startDate` → `p.start_date`, `p.endDate` → `p.end_date`, `p.baTeam` → `p.ba_team`, `p.createdAt` → `p.created_at`, `m.projectId` → `m.project_id`, `m.dueDate` → `m.due_date`, `s.projectId` → `s.project_id`, `s.startDate` → `s.start_date`, `s.endDate` → `s.end_date`.

Rewritten `saveProject`:
```js
import { saveProject as dbSaveProject, deleteProject as dbDeleteProject, saveMilestone as dbSaveMilestone, deleteMilestone as dbDeleteMilestone, saveSprint as dbSaveSprint, deleteSprint as dbDeleteSprint } from '../storage.js';
import { state, setState, addEntity, updateEntity, removeEntity } from '../state.js';

export async function saveProject() {
  const name = $id('pfName')?.value.trim();
  if (!name) { markError('pfName', 'Project name is required'); return; }
  const pid = $id('pfId')?.value;
  const existing = pid ? state.projects.find(p => p.id === pid) : null;
  const data = {
    id:          existing?.id,
    name,
    code:        $id('pfCode')?.value.trim() || null,
    description: $id('pfDesc')?.value.trim() || null,
    department:  $id('pfDept')?.value.trim() || null,
    pm:          $id('pfPM')?.value.trim() || null,
    ba_team:     ($id('pfBATeam')?.value.trim() || '').split(',').map(s=>s.trim()).filter(Boolean),
    status:      $id('pfStatus')?.value || 'active',
    priority:    $id('pfPriority')?.value || 'medium',
    start_date:  $id('pfStart')?.value || null,
    end_date:    $id('pfEnd')?.value || null,
    budget:      parseFloat($id('pfBudget')?.value) || null,
    color:       $id('pfColor')?.value || '#2563eb',
    tags:        [...(window._projectTags || [])],
  };
  try {
    const saved = await dbSaveProject(data);
    if (existing) updateEntity('projects', existing.id, saved);
    else addEntity('projects', saved);
    toast(existing ? 'Project updated' : `Project "${name}" created`, 'success');
    closeOverlay('projectFormOverlay');
    refreshView();
    updateNavBadgesGlobal();
    updateSidebarProjectsGlobal();
  } catch (e) { toast(e.message, 'error'); }
}
```

Add `refreshView`, `updateNavBadgesGlobal`, `updateSidebarProjectsGlobal` as injected callbacks — set them from `app.js`:
```js
// js/ui/projects.js
let _refresh, _updateBadges, _updateSidebar;
export function setCallbacks(refresh, updateBadges, updateSidebar) {
  _refresh = refresh; _updateBadges = updateBadges; _updateSidebar = updateSidebar;
}
```
In `app.js`: `import { setCallbacks } from './js/ui/projects.js'; setCallbacks(refreshView, updateNavBadges, updateSidebarProjects);`

Use the same callback injection pattern for `tasks.js`.

- [ ] **Step 3: Create `js/ui/tasks.js`**

Copy from app.js:
- `getFilteredTasks()` (line 816)
- `renderTaskTableHTML(tasks)` (line 843)
- `renderTaskRow(t)` (line 859) — rename `t.dueDate` → `t.due_date`, `t.projectId` → `t.project_id`, `t.createdAt` → `t.created_at`, `t.ba` stays same
- `bindTaskTableEvents(container)` (line 884)
- `renderTaskList()` (line 909)
- `refreshProjectFilter()` (line 932)
- `refreshBAFilter()` (line 941)
- `refreshMilestoneFilter()` (line 946)
- `openTaskForm(taskId, presetProjectId)` (line 1401) — update `milestoneId` → `milestone_id` etc.
- `updateDependentSelectors(pid)` (line 1440)
- `renderFormTags()` (line 1454)
- `renderFormDocs()` (line 1460)
- `renderFormSubtasks()` (line 1472)
- `saveTask()` (line 1482) — **rewrite** to call `storage.saveTask()`
- `openTaskDetail(taskId)` (line 1562) — update field names
- `confirmDeleteTask(taskId)` (line 1793) — **rewrite** to call `storage.deleteTask()`

Rewritten `saveTask`:
```js
export async function saveTask() {
  const title = $id('fTitle')?.value.trim();
  if (!title) { markError('fTitle', 'Title is required'); return; }
  const project_id = $id('fProject')?.value;
  if (!project_id) { markError('fProject', 'Please select a project'); return; }

  // Collect docs and subtasks from form
  const documents = [];
  document.querySelectorAll('#docsList .doc-row').forEach(row => {
    const t2 = row.querySelector('.doc-title-inp')?.value.trim();
    const u2 = row.querySelector('.doc-url-inp')?.value.trim();
    if (t2 || u2) documents.push({ title: t2 || '', url: u2 || '' });
  });
  const subtasks = [];
  document.querySelectorAll('#subtaskList .subtask-item').forEach(row => {
    const t2 = row.querySelector('.subtask-input')?.value.trim();
    const done = row.querySelector('.subtask-checkbox')?.checked;
    if (t2) subtasks.push({ id: crypto.randomUUID(), title: t2, done: !!done });
  });
  const dependencies = [...($id('fDeps')?.selectedOptions || [])].map(o => o.value);
  const progress = subtasks.length
    ? Math.round(subtasks.filter(s=>s.done).length / subtasks.length * 100)
    : parseInt($id('fProgress')?.value || 0);
  const taskId = $id('fId')?.value;
  const existing = taskId ? state.tasks.find(t => t.id === taskId) : null;

  const data = {
    id:             existing?.id,
    title,
    description:    $id('fDesc')?.value.trim() || null,
    project_id,
    milestone_id:   $id('fMilestone')?.value || null,
    sprint_id:      $id('fSprint')?.value || null,
    parent_task_id: $id('fParent')?.value || null,
    priority:       $id('fPriority')?.value || 'medium',
    status:         $id('fStatus')?.value || 'pending',
    start_date:     $id('fStartDate')?.value || null,
    due_date:       $id('fDueDate')?.value || null,
    ba:             $id('fBA')?.value.trim() || null,
    assignee_id:    null, // Phase 3+
    estimated_hours: parseFloat($id('fHours')?.value) || null,
    actual_hours:   parseFloat($id('fActualHours')?.value) || null,
    tags:           [...state.formTags],
    documents,
    dependencies,
    subtasks,
    progress,
    notes:          $id('fNotes')?.value.trim() || null,
    starred:        existing?.starred || false,
    pinned:         existing?.pinned || false,
  };

  try {
    const old_status = existing?.status;
    const saved = await dbSaveTask(data);
    if (existing) {
      updateEntity('tasks', existing.id, saved);
      if (old_status !== saved.status) {
        await logTaskActivity(saved.id, 'status_changed', old_status, saved.status,
          `Status changed from ${old_status} to ${saved.status}`);
      }
      toast('Task updated', 'success');
    } else {
      addEntity('tasks', saved);
      await logTaskActivity(saved.id, 'created', null, null, 'Task created');
      toast('Task created', 'success');
    }
    closeOverlay('formOverlay');
    _refresh?.();
    _updateBadges?.();
  } catch (e) { toast(e.message, 'error'); }
}
```

- [ ] **Step 4: Verify all three views render without errors**

Open app in browser. Sign in. Check:
- Dashboard view renders
- Projects view renders
- All Tasks view renders
- No console errors about undefined functions

- [ ] **Step 5: Commit**

```bash
git add js/router.js js/ui/dashboard.js js/ui/projects.js js/ui/tasks.js
git commit -m "feat: extract dashboard, projects, and tasks into ES modules"
```

---

### Task 7: Create Remaining UI Modules

**Files:**
- Create: `js/ui/kanban.js`
- Create: `js/ui/calendar.js`
- Create: `js/ui/gantt.js`
- Create: `js/ui/analytics.js`
- Create: `js/ui/team.js`
- Create: `js/ui/workspace-switcher.js`

- [ ] **Step 1: Create `js/ui/kanban.js`**

Copy `renderKanban()` (app.js:954–1027) and `renderKanbanInto(board, tasks)` (app.js:961). Apply field renames: `t.project_id`, `t.milestone_id`, `t.sprint_id`. The drag-and-drop `ondragstart`/`ondrop` handlers call `saveTask` — update to use async `dbSaveTask` + `updateEntity` from state.

```js
import { state, findProject, getActiveTasks } from '../state.js';
import { $id, esc, STATUS_META, toast } from '../utils.js';
import { saveTask as dbSaveTask } from '../storage.js';
import { updateEntity } from '../state.js';

export function renderKanban() { /* copy from app.js:954, apply field renames */ }
function renderKanbanInto(board, tasks) { /* copy from app.js:961 */ }

// Status drop handler (called from inline ondrop in rendered HTML)
window.kanbanDrop = async function(status) {
  if (!state.draggedTaskId) return;
  const task = state.tasks.find(t => t.id === state.draggedTaskId);
  if (!task || task.status === status) return;
  const oldStatus = task.status;
  updateEntity('tasks', task.id, { status });  // optimistic
  renderKanban();
  try {
    await dbSaveTask({ ...task, status });
  } catch(e) {
    updateEntity('tasks', task.id, { status: oldStatus }); // rollback
    renderKanban();
    toast(e.message, 'error');
  }
};
```

- [ ] **Step 2: Create `js/ui/calendar.js`, `js/ui/gantt.js`, `js/ui/analytics.js`**

For each file, copy the corresponding function from app.js with field renames:
- `calendar.js`: `renderCalendar()` (app.js:1027–1058). Field renames: `t.due_date`, `t.project_id`.
- `gantt.js`: `renderGantt()` (app.js:1058–1143). Field renames: `t.due_date`, `t.start_date`, `p.start_date`, `p.end_date`, `t.project_id`.
- `analytics.js`: `renderAnalytics()` (app.js:1143–1251). Field renames: `t.due_date`, `t.project_id`, `t.created_at`, `p.created_at`.

Each file follows this structure:
```js
import { state, getActiveTasks, findProject } from '../state.js';
import { $id, esc, fmtDate, daysUntil, STATUS_META, PRIORITY_META, toast } from '../utils.js';

export function renderCalendar() { /* ... */ }
```

- [ ] **Step 3: Create `js/ui/team.js`**

Copy `renderTeam()` (app.js:1251), `openMemberForm(userId)` (app.js:1305), `renderAvatarPresetGrid()` (app.js:1325), `renderMemberSkillChips()` (app.js:1340), `saveMember()` (app.js:1354).

**Key changes:**
- `state.users` → `state.members` (workspace_members rows)
- `u.name` → `u.display_name`
- `u.avatarPreset` → `u.avatar_preset`
- `u.avatarUrl` → `u.avatar_url`
- `u.joinedAt` → `u.joined_at`
- Task assignment: `t.ba === u.display_name` stays for backward compat
- `saveMember()` calls `storage.updateMember()` instead of mutating blob

```js
import { state, updateEntity } from '../state.js';
import { $id, esc, setVal, openOverlay, closeOverlay, toast, AVATAR_PRESETS } from '../utils.js';
import { updateMember } from '../storage.js';

export function renderTeam() {
  const container = $id('teamContainer'); if (!container) return;
  if (!state.members.length) {
    container.innerHTML = '<p class="no-data" style="padding:40px">No team members yet. Invite someone from Settings.</p>';
    return;
  }
  container.innerHTML = `<div class="team-grid">${state.members.map(u => {
    const assigned = state.tasks.filter(t => t.ba === u.display_name);
    const open  = assigned.filter(t => t.status !== 'completed').length;
    const done  = assigned.filter(t => t.status === 'completed').length;
    const blkd  = assigned.filter(t => t.status === 'blocked').length;
    const maxTasks = Math.max(...state.members.map(uu =>
      state.tasks.filter(t => t.ba === uu.display_name).length), 1);
    const wlPct = Math.round(assigned.length / maxTasks * 100);
    const avatarHtml = u.avatar_url
      ? `<img src="${esc(u.avatar_url)}" style="width:44px;height:44px;border-radius:50%;object-fit:cover;flex-shrink:0">`
      : (u.avatar_preset != null
          ? `<div class="team-avatar" style="background:${u.color || '#2563eb'}">${AVATAR_PRESETS[u.avatar_preset]?.icon || '👤'}</div>`
          : `<div class="team-avatar" style="background:${u.color || '#2563eb'}">👤</div>`);
    return `<div class="team-card">
      <div class="team-card-top">
        ${avatarHtml}
        <div style="flex:1;min-width:0">
          <div class="team-name">${esc(u.display_name || 'Member')}</div>
          <div class="team-role" style="color:var(--text-3)">${esc(u.role || '')}</div>
        </div>
        <button class="btn btn-ghost btn-sm" onclick="openMemberForm('${u.id}')" style="align-self:flex-start;padding:2px 8px;font-size:.72rem">Edit</button>
      </div>
      <div class="team-stats">
        <div class="team-stat"><div class="team-stat-num">${open}</div><div class="team-stat-lbl">Open</div></div>
        <div class="team-stat"><div class="team-stat-num" style="color:#059669">${done}</div><div class="team-stat-lbl">Done</div></div>
        <div class="team-stat"><div class="team-stat-num" style="color:#dc2626">${blkd}</div><div class="team-stat-lbl">Blocked</div></div>
      </div>
      <div class="team-workload">
        <div class="team-workload-label"><span>Workload</span><span>${wlPct}%</span></div>
        <div class="workload-bar"><div class="workload-fill" style="width:${wlPct}%;background:${wlPct>80?'#dc2626':wlPct>50?'#d97706':(u.color||'#2563eb')}"></div></div>
      </div>
    </div>`;
  }).join('')}</div>`;
}

export function openMemberForm(memberId) {
  const m = state.members.find(x => x.id === memberId); if (!m) return;
  setVal('mId', m.id);
  setVal('mName', m.display_name || '');
  setVal('mColor', m.color || '#2563eb');
  openOverlay('memberFormOverlay');
}

export async function saveMember() {
  const memberId = $id('mId')?.value;
  const m = state.members.find(x => x.id === memberId); if (!m) return;
  const updates = {
    display_name:  $id('mName')?.value.trim() || null,
    color:         $id('mColor')?.value || null,
    avatar_preset: window._selectedAvatarPreset ?? m.avatar_preset,
  };
  try {
    await updateMember(memberId, updates);
    updateEntity('members', memberId, updates);
    toast('Member updated', 'success');
    closeOverlay('memberFormOverlay');
    renderTeam();
  } catch (e) { toast(e.message, 'error'); }
}
```

- [ ] **Step 4: Create `js/ui/workspace-switcher.js`**

```js
import { state, setState } from '../state.js';
import { $id, esc, toast } from '../utils.js';
import { loadWorkspace } from '../workspace.js';
import { createInvitation, cancelInvitation, listInvitations } from '../invitations.js';
import { canInvite, canManageMembers } from '../permissions.js';
import { removeMember } from '../storage.js';
import { removeEntity } from '../state.js';

export function renderWorkspaceSwitcher() {
  const btn = $id('workspaceSwitcherBtn');
  if (!btn) return;
  const ws = state.workspaces.find(w => w.id === state.activeWorkspaceId);
  if (btn) btn.querySelector('span')?.textContent && (btn.querySelector('span').textContent = ws?.name || 'Workspace');
}

export function renderInviteModal() {
  // Reset form
  const inviteLabel = $id('inviteLabel'); if (inviteLabel) inviteLabel.value = '';
  const inviteRole = $id('inviteRole'); if (inviteRole) inviteRole.value = 'member';
  const inviteLinkWrap = $id('inviteLinkWrap'); if (inviteLinkWrap) inviteLinkWrap.style.display = 'none';

  $id('generateInviteBtn')?.addEventListener('click', async () => {
    const role  = $id('inviteRole')?.value || 'member';
    const label = $id('inviteLabel')?.value.trim() || null;
    try {
      const inv = await createInvitation(state.activeWorkspaceId, state.currentUser.id, role, label);
      const link = `${window.location.origin}${window.location.pathname}?invite=${inv.token}`;
      const inp = $id('inviteLinkInput'); if (inp) inp.value = link;
      const wrap = $id('inviteLinkWrap'); if (wrap) wrap.style.display = '';
      $id('copyInviteBtn')?.addEventListener('click', () => {
        navigator.clipboard.writeText(link);
        toast('Link copied!', 'success');
      });
    } catch (e) { toast(e.message, 'error'); }
  }, { once: true });
}

export async function renderMembersPanel() {
  const container = $id('membersContainer'); if (!container) return;
  container.innerHTML = state.members.map(m => {
    const isMe = m.user_id === state.currentUser?.id;
    const canRemove = canManageMembers() && !isMe;
    return `<div class="team-card" style="padding:16px">
      <div style="display:flex;align-items:center;gap:12px">
        <div class="team-avatar" style="background:${m.color || '#2563eb'};width:36px;height:36px;font-size:.9rem">
          ${m.avatar_preset != null ? '' : '👤'}
        </div>
        <div style="flex:1">
          <div style="font-weight:600">${esc(m.display_name || 'Unnamed')}</div>
          <div style="font-size:.75rem;color:var(--text-3)">${esc(m.role)}</div>
        </div>
        ${canRemove ? `<button class="btn btn-ghost btn-sm" onclick="removeMemberById('${m.id}')" style="color:#dc2626">Remove</button>` : ''}
        ${isMe ? '<span style="font-size:.72rem;color:var(--text-3)">(you)</span>' : ''}
      </div>
    </div>`;
  }).join('');
}

window.removeMemberById = async function(memberId) {
  if (!confirm('Remove this member from the workspace?')) return;
  try {
    await removeMember(memberId);
    removeEntity('members', memberId);
    renderMembersPanel();
    toast('Member removed', 'success');
  } catch (e) { toast(e.message, 'error'); }
};
```

- [ ] **Step 5: Verify all views**

Open app in browser. Navigate through every view:
- Dashboard, Projects, Project Detail (click a project), All Tasks, Kanban, Calendar, Gantt, Analytics, Team, Settings
- Check console for errors. Each view should render without throwing.

- [ ] **Step 6: Commit**

```bash
git add js/ui/kanban.js js/ui/calendar.js js/ui/gantt.js js/ui/analytics.js js/ui/team.js js/ui/workspace-switcher.js
git commit -m "feat: extract remaining views into ES modules"
```

---

## Phase 3: Invitations + Permissions

### Task 8: Create `js/permissions.js` and `js/invitations.js`

**Files:**
- Create: `js/permissions.js`
- Create: `js/invitations.js`

- [ ] **Step 1: Create `js/permissions.js`**

```js
import { state } from './state.js';

export function getMyRole() { return state.currentMember?.role || 'guest'; }
export function canEdit() { return getMyRole() !== 'guest'; }
export function canDelete(entity) {
  const role = getMyRole();
  if (role === 'owner') return true;
  if (role === 'guest') return false;
  return entity?.created_by === state.currentUser?.id;
}
export function canInvite() { return ['owner','member'].includes(getMyRole()); }
export function canManageMembers() { return getMyRole() === 'owner'; }
```

- [ ] **Step 2: Create `js/invitations.js`**

```js
import { sb } from './supabase.js';
import { state, addEntity } from './state.js';

export async function createInvitation(workspaceId, invitedBy, role, label) {
  const token = crypto.randomUUID();
  const expires_at = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await sb.from('invitations')
    .insert({ workspace_id: workspaceId, invited_by: invitedBy, token, role, label, expires_at })
    .select().single();
  if (error) throw error;
  return data;
}

export async function acceptInvitation(token, userId) {
  // Look up invitation
  const { data: inv, error: fetchErr } = await sb
    .from('invitations').select('*, workspaces(name)').eq('token', token).maybeSingle();
  if (fetchErr) throw fetchErr;
  if (!inv) throw new Error('Invite link not found');
  if (inv.status !== 'pending') throw new Error('This invite link has already been used or cancelled');
  if (new Date(inv.expires_at) < new Date()) throw new Error('This invite link has expired');

  // Check if already a member
  const { data: existing } = await sb.from('workspace_members')
    .select('id').eq('workspace_id', inv.workspace_id).eq('user_id', userId).maybeSingle();
  if (existing) {
    // Already a member — mark invite as accepted and return
    await sb.from('invitations').update({ status: 'accepted', accepted_by: userId }).eq('id', inv.id);
    return { workspace_id: inv.workspace_id, workspace_name: inv.workspaces?.name };
  }

  // Add member
  const { error: memErr } = await sb.from('workspace_members').insert({
    workspace_id: inv.workspace_id,
    user_id:      userId,
    role:         inv.role,
  });
  if (memErr) throw memErr;

  // Mark invite accepted
  await sb.from('invitations').update({ status: 'accepted', accepted_by: userId }).eq('id', inv.id);

  return { workspace_id: inv.workspace_id, workspace_name: inv.workspaces?.name };
}

export async function cancelInvitation(invitationId) {
  const { error } = await sb.from('invitations')
    .update({ status: 'cancelled' }).eq('id', invitationId);
  if (error) throw error;
}

export async function listInvitations(workspaceId) {
  const { data, error } = await sb.from('invitations')
    .select('*').eq('workspace_id', workspaceId).order('created_at', { ascending: false });
  if (error) throw error;
  return data;
}
```

- [ ] **Step 3: Test invite flow**

1. Sign in as User A. Go to Settings → click "Invite Member". Generate invite link.
2. Copy the link. Open in a new browser (or incognito).
3. Log in (or create) as User B. The `?invite=<token>` param should be detected.
4. Expected: User B is added to the workspace and can see the same projects/tasks.

- [ ] **Step 4: Commit**

```bash
git add js/permissions.js js/invitations.js
git commit -m "feat: add permissions module and invite link flow"
```

---

## Phase 4: Realtime

### Task 9: Create `js/realtime.js`

**Files:**
- Create: `js/realtime.js`

- [ ] **Step 1: Create `js/realtime.js`**

```js
import { sb } from './supabase.js';
import { state, updateEntity, addEntity, removeEntity } from './state.js';

const _channels = [];

export function subscribeToWorkspace(workspaceId, onUpdate) {
  const channel = sb.channel(`workspace-${workspaceId}`)
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'tasks', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('tasks', payload);
      onUpdate();
    })
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'projects', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('projects', payload);
      onUpdate();
    })
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'milestones', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('milestones', payload);
      onUpdate();
    })
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'sprints', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('sprints', payload);
      onUpdate();
    })
    .subscribe();
  _channels.push(channel);
}

export function subscribeToNotifications(userId, onNotification) {
  const channel = sb.channel(`user-${userId}`)
    .on('postgres_changes', {
      event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}`
    }, payload => {
      onNotification(payload.new);
    })
    .subscribe();
  _channels.push(channel);
}

export function unsubscribeAll() {
  _channels.forEach(ch => sb.removeChannel(ch));
  _channels.length = 0;
}

function handleEntityChange(table, payload) {
  const { eventType, new: newRow, old: oldRow } = payload;
  if (eventType === 'INSERT') {
    if (!state[table].find(e => e.id === newRow.id)) addEntity(table, newRow);
  } else if (eventType === 'UPDATE') {
    updateEntity(table, newRow.id, newRow);
  } else if (eventType === 'DELETE') {
    removeEntity(table, oldRow.id);
  }
}
```

- [ ] **Step 2: Enable Realtime in Supabase Dashboard**

Open: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/database/replication

Enable replication for tables: `tasks`, `projects`, `milestones`, `sprints`, `notifications`.

- [ ] **Step 3: Test two-tab sync**

Open the app in two browser tabs logged in as the same user (or two users in the same workspace). Create a task in Tab A. Within 1–2 seconds it should appear in Tab B without refresh.

- [ ] **Step 4: Commit**

```bash
git add js/realtime.js
git commit -m "feat: add Supabase Realtime subscriptions for live workspace sync"
```

---

## Phase 5: Notifications + Activity

### Task 10: Run Notifications Trigger + Create `js/notifications.js`

**Files:**
- Create: `migrations/003_notifications_trigger.sql`
- Create: `js/notifications.js`

- [ ] **Step 1: Create `migrations/003_notifications_trigger.sql`**

```sql
CREATE OR REPLACE FUNCTION notify_task_changes()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Notify new assignee when assignee_id changes
  IF NEW.assignee_id IS DISTINCT FROM OLD.assignee_id AND NEW.assignee_id IS NOT NULL THEN
    INSERT INTO notifications (workspace_id, user_id, type, title, body, entity_type, entity_id)
    VALUES (
      NEW.workspace_id,
      NEW.assignee_id,
      'task_assigned',
      'You were assigned a task',
      NEW.title,
      'task',
      NEW.id
    );
  END IF;

  -- Notify task creator when status changes (if creator is not the person making the change)
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.created_by IS NOT NULL
     AND NEW.created_by <> auth.uid() THEN
    INSERT INTO notifications (workspace_id, user_id, type, title, body, entity_type, entity_id)
    VALUES (
      NEW.workspace_id,
      NEW.created_by,
      'status_changed',
      'Task status updated',
      NEW.title || ': ' || OLD.status || ' → ' || NEW.status,
      'task',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER task_change_notifications
  AFTER UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION notify_task_changes();
```

- [ ] **Step 2: Run the trigger SQL in Supabase SQL Editor**

Paste and run `003_notifications_trigger.sql`. Expected: "Success."

- [ ] **Step 3: Create `js/notifications.js`**

```js
import { sb } from './supabase.js';
import { $id } from './utils.js';

export async function loadNotifications(workspaceId, userId) {
  const { data, error } = await sb
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .eq('workspace_id', workspaceId)
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) throw error;
  return data;
}

export async function markNotificationRead(notificationId) {
  const { error } = await sb.from('notifications').update({ read: true }).eq('id', notificationId);
  if (error) throw error;
}

export async function markAllRead(userId) {
  const { error } = await sb.from('notifications').update({ read: true }).eq('user_id', userId).eq('read', false);
  if (error) throw error;
}

export function updateBell(notifications) {
  const badge = $id('notificationBadge');
  const unread = notifications.filter(n => !n.read).length;
  if (!badge) return;
  badge.textContent = unread > 9 ? '9+' : unread;
  badge.style.display = unread > 0 ? '' : 'none';
}
```

- [ ] **Step 4: Wire notification bell click**

In `app.js` `bindEvents()`, add:

```js
$id('notificationBell')?.addEventListener('click', async () => {
  // Simple dropdown: mark all read and show last 5 notifications as toasts
  const unread = state.notifications.filter(n => !n.read);
  if (!unread.length) { toast('No new notifications', 'info'); return; }
  for (const n of unread.slice(0, 3)) toast(n.title + (n.body ? `: ${n.body}` : ''), 'info');
  await markAllRead(state.currentUser.id);
  state.notifications.forEach(n => { n.read = true; });
  updateBell(state.notifications);
});
```

Add import at top of `app.js`:
```js
import { markAllRead } from './js/notifications.js';
```

- [ ] **Step 5: Test notification delivery**

1. User A assigns a task to User B (set `assignee_id` in the task form — wire up the assignee dropdown to list workspace members).
2. User B should see the bell badge update in real-time.

- [ ] **Step 6: Commit**

```bash
git add migrations/003_notifications_trigger.sql js/notifications.js
git commit -m "feat: add notifications trigger and bell badge"
```

---

## Phase 6: Polish + Deploy

### Task 11: Permission Guards + Onboarding + GitHub Secrets

**Files:**
- Modify: `js/ui/projects.js`, `js/ui/tasks.js`, `js/ui/team.js`, `js/ui/workspace-switcher.js`
- Modify: `style.css`
- Modify: `config.example.js`

- [ ] **Step 1: Apply permission guards to action buttons**

In `js/ui/projects.js` — wrap create/delete buttons with `canEdit()` check:

```js
// In renderProjects(), wrap the "+ New Project" button render:
${canEdit() ? `<button class="btn btn-primary" id="newProjectBtn">+ New Project</button>` : ''}

// In project card actions, wrap delete button:
${canDelete(p) ? `<button onclick="confirmDeleteProject('${p.id}')">Delete</button>` : ''}
```

In `js/ui/tasks.js` — wrap "+ New Task" and delete buttons:
```js
// In renderTaskRow():
${canDelete(t) ? `<button onclick="confirmDeleteTask('${t.id}')">×</button>` : ''}
```

In `index.html` — hide "+ Invite Member" button for guests by adding it conditionally in JS rather than HTML. In `app.js` `showApp()`:
```js
if ($id('openInviteBtn')) $id('openInviteBtn').style.display = canInvite() ? '' : 'none';
```

- [ ] **Step 2: Add Guest access-denied toast**

In `js/ui/tasks.js` `saveTask()`, at the very top:
```js
if (!canEdit()) { toast('Guests can view but not edit', 'warning'); return; }
```

In `js/ui/projects.js` `saveProject()`, at the very top:
```js
if (!canEdit()) { toast('Guests can view but not edit', 'warning'); return; }
```

- [ ] **Step 3: Add notification badge CSS to `style.css`**

Add at the end of `style.css`:
```css
.notification-badge {
  position: absolute;
  top: 2px; right: 2px;
  background: #dc2626;
  color: white;
  font-size: .6rem;
  font-weight: 700;
  border-radius: 999px;
  min-width: 16px;
  height: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 3px;
}

.workspace-name-display {
  font-size: .7rem;
  color: var(--text-3);
  padding: 2px 8px 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.modal-sm { max-width: 420px; }

/* Permission guard: hide forbidden buttons */
[data-perm="edit"]:disabled,
[data-perm="edit"][style*="display:none"] { display: none !important; }
```

- [ ] **Step 4: Update `config.example.js`**

```js
// Copy this file to config.js and fill in your Supabase project credentials.
// config.js is gitignored — never commit it.
// New multi-user project: zynunureylcdexxhvdth
// Get your anon key from: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/settings/api
window.APP_CONFIG = {
  supabaseUrl: 'https://zynunureylcdexxhvdth.supabase.co',
  supabaseKey: 'YOUR_ANON_PUBLIC_KEY'
};
```

- [ ] **Step 5: Update GitHub Actions secrets**

In the GitHub repository:
1. Go to Settings → Secrets and Variables → Actions
2. Update `SUPABASE_URL` to: `https://zynunureylcdexxhvdth.supabase.co`
3. Update `SUPABASE_KEY` to the new project's anon public key

(Get the key from: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/settings/api under "Project API keys → anon public")

- [ ] **Step 6: Full regression test**

Test the following flows:
- [ ] User A signs up, workspace created automatically
- [ ] User A creates a project and tasks — data persists on reload
- [ ] User A generates invite link, User B opens it
- [ ] User B signs up via invite link — appears in User A's team
- [ ] User B can view projects and tasks
- [ ] User B cannot create/delete (if role is 'guest')
- [ ] User A changes a task status — User B sees change within 2 seconds (Realtime)
- [ ] User A assigns task to User B — User B's bell updates
- [ ] All 8 views (Dashboard, Projects, Tasks, Kanban, Calendar, Gantt, Analytics, Team) render correctly
- [ ] Dark mode toggle works
- [ ] Sidebar collapse works

- [ ] **Step 7: Final commit**

```bash
git add js/permissions.js js/ui/ style.css config.example.js
git commit -m "feat: permission guards, notification badge styles, deploy config"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] §3 Database Schema → Task 1
- [x] §4 RLS Policies → Task 1
- [x] §5 RBAC → Tasks 8 + 11
- [x] §6 Invite Flow → Task 8
- [x] §7 Frontend Module Structure → Tasks 2–7
- [x] §8 Realtime Strategy → Task 9
- [x] §9 Supabase Config Steps → Task 1 + Task 11 Step 5
- [x] §10 UI Elements (workspace switcher, invite modal, member panel, bell) → Tasks 5 + 7
- [x] §11 Security → RLS in Task 1 covers all risks listed
- [x] §12 Implementation Phases → matches 6-phase structure

**Field names consistent throughout:** All renderers use `t.due_date`, `t.project_id`, `t.created_at`, `p.start_date`, `p.end_date`, `p.ba_team`, `m.project_id`, `m.due_date`, `s.project_id`. `state.members` replaces `state.users`.

**No placeholders:** All task steps include complete code or explicit line references to app.js for copy-and-adapt tasks.
