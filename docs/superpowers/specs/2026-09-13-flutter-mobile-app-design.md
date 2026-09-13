# TaskFlow Pro — Flutter Mobile App Design

**Date:** 2026-09-13
**Status:** Approved
**Author:** Zain Kamali
**Supabase Project:** zynunureylcdexxhvdth (shared with the existing web app — same data, same RLS)

---

## 1. Context & Decisions

### What exists today

TaskFlow Pro is a multi-tenant SaaS project/task tracker: vanilla JS ES modules (no build step, no framework) on Supabase (Postgres + Auth + RLS + Realtime), deployed as a static site on GitHub Pages. Users belong to one or more workspaces (tenants), with an owner/member/guest RBAC model enforced by Postgres RLS. The app has 8 views (Dashboard, Projects, Tasks, Kanban, Calendar, Gantt, Analytics, Team) plus a command palette, invite links, and live realtime sync across tabs/users. Full detail in `readme.md` and `docs/superpowers/specs/2026-05-16-multi-user-collaboration-design.md`.

### Confirmed decisions from brainstorming

| Decision | Choice | Reason |
|---|---|---|
| Platform target | Mobile only (iOS + Android) | Flutter's strongest suit; web/desktop stay on the existing site |
| Feature scope | Full parity — all 8 views, RBAC, invitations, notifications, Realtime | Matches the web app one-to-one rather than shipping a reduced subset |
| Backend | Reuse the existing Supabase project (same URL/anon key/tables/RLS) | One live dataset shared between web and mobile clients; zero new backend work |
| State management | Riverpod | Compile-safe, scales well for realtime cross-view state, standard choice for new Flutter apps |
| Repo layout | New `flutter_app/` folder inside this repo | Shared migrations/docs/history with the web app; one repo to manage |
| Offline support | None for v1 — online-only | Matches the web app's existing online-only requirement; avoids a new offline-sync architecture |
| Push notifications | None for v1 — in-app/Realtime only while the app is open | Mirrors the web app's bell badge behavior; avoids new FCM/APNs + Edge Function infra |

### Out of scope for v1

Offline caching/sync, push notifications (FCM/APNs), Flutter web/desktop build targets, command palette (Ctrl/⌘+K has no mobile equivalent — replaced by a search sheet), any backend/schema changes (the Flutter app is read/write against the existing schema, unchanged).

---

## 2. System Architecture Overview

```
Flutter app (iOS + Android)
 lib/
   main.dart
   core/            Supabase client init (supabase_flutter), theming, GoRouter, constants
   models/          Dart classes mirroring the Postgres schema (Workspace, Project, Task, Member, ...)
   data/            Repositories — one per entity, wraps supabase_flutter calls (mirrors js/storage.js)
   providers/       Riverpod providers — auth, workspace, per-entity StreamProviders, permissions
   features/
     auth/          login / signup
     dashboard/
     projects/
     tasks/
     kanban/
     calendar/
     gantt/
     analytics/
     team/
     workspace/     switcher, invite, members panel
   widgets/          shared UI (cards, badges, avatars, empty states, toasts)

Supabase (zynunureylcdexxhvdth) — SAME project the web app uses, unchanged
 ├── Auth        email/password — same user pool as web
 ├── Postgres    same 10 workspace-scoped tables (tt_projects, tasks, milestones, sprints, ...)
 ├── RLS         same policies — the real security/tenant-isolation boundary for both clients
 └── Realtime    same postgres_changes subscriptions, now also consumed by the Flutter client
```

### Data flow

1. `core/` initializes the Supabase client on app start; `authProvider` restores the session or routes to the login screen (`supabase_flutter`'s `onAuthStateChange` stream).
2. On login, `workspaceProvider` loads the user's workspace memberships (same `workspace_members` join as web) and the active workspace.
3. Per-entity repositories in `data/` fetch projects/tasks/milestones/sprints/members for the active `workspace_id`, exposed to the UI via Riverpod `StreamProvider`s wired to Supabase Realtime channels — so both the initial load and live updates flow through the same provider, unlike the web app's separate initial-fetch + realtime-merge steps.
4. A user action (e.g. save task) writes through the matching repository function; the `StreamProvider` picks up the resulting Postgres change broadcast and updates the UI — no manual optimistic-state merging needed, since Riverpod re-renders from the stream directly.
5. `permissionsProvider` derives `canEdit`/`canDelete`/`canInvite`/`canManageMembers` from the current member's role — UI-layer only, exactly mirroring `js/permissions.js`. RLS remains the actual enforcement boundary, identical to the web app.

---

## 3. Screens / Feature Mapping

| Web view | Flutter equivalent | Notes |
|---|---|---|
| Dashboard | `features/dashboard/` | Stats, upcoming deadlines, team workload |
| Projects | `features/projects/` | List → detail (Overview/Tasks/Kanban/Milestones/Sprints tabs) |
| Tasks | `features/tasks/` | Filterable/sortable list |
| Kanban | `features/kanban/` | Status columns; touch drag via `LongPressDraggable` (see §4) |
| Calendar | `features/calendar/` | Monthly due-date view, single-column mobile layout |
| Gantt | `features/gantt/` | Horizontally-scrollable timeline (see §4) |
| Analytics | `features/analytics/` | Status/priority charts, workload distribution |
| Team | `features/team/` | Member cards, avatar/skills editing, remove member |
| Workspace switcher / invite | `features/workspace/` | Switch active workspace, generate/accept invite links, members panel |
| Notifications (bell badge) | Notifications tab/sheet | Realtime-driven, same trigger-based generation as web |
| Command palette (Ctrl/⌘+K) | **Dropped** | No keyboard shortcut on mobile; replaced by a search icon → full-screen search sheet |

### Navigation

Bottom navigation bar with the most-used views (Dashboard, Projects, Tasks, Kanban, Notifications); remaining views (Calendar, Gantt, Analytics, Team, Workspace settings) reachable via a "More" tab or drawer — mirrors how the web sidebar's 8 links collapse into a mobile-appropriate structure.

---

## 4. Mobile UX Adaptations

Desktop-oriented interactions in the web app that don't port 1:1:

- **Kanban drag-and-drop**: mouse drag → `LongPressDraggable`/`DragTarget` touch drag between status columns, which stack vertically or scroll horizontally depending on screen width.
- **Gantt chart**: fixed desktop-width timeline → horizontally-scrollable chart (e.g. `syncfusion_flutter_gantt` or a custom scrollable timeline widget).
- **Command palette**: no direct mobile equivalent; replaced with a search sheet triggered from a search icon.
- All other views (forms, lists, Calendar, Analytics charts) use standard single-column responsive Flutter layouts.

---

## 5. Roles & Permissions (unchanged from web)

Same three-tier RBAC, same rules, enforced by the same RLS policies — only the client-side guard logic (`permissionsProvider`) is re-implemented in Dart:

| Action | Owner | Member | Guest |
|---|:---:|:---:|:---:|
| View projects/tasks | ✓ | ✓ | ✓ |
| Create/edit project or task | ✓ | ✓ | ✗ |
| Delete project or task | ✓ (any) | own only | ✗ |
| Invite members | ✓ | ✓ | ✗ |
| Change member roles / remove members | ✓ | ✗ | ✗ |
| Rename or delete workspace | ✓ | ✗ | ✗ |
| Comment on tasks | ✓ | ✓ | ✗ |

---

## 6. Error Handling

Repositories in `data/` map Supabase/Postgrest exceptions to typed Dart exceptions (`AuthException`, `NotFoundException`, `PermissionDeniedException` for RLS rejections), surfaced to the UI as snackbars — consistent with the web app's toast pattern in `js/utils.js`. A Realtime disconnect shows a "reconnecting" banner; since v1 is online-only, there is no offline write queue to reconcile.

---

## 7. Testing

- **Widget tests** for core screens (auth, task list/form, kanban board interactions).
- **Repository unit tests** against a test Supabase project or mocked `SupabaseClient`.
- **Manual multi-tenant pass** using the existing seeded test accounts (`alice.owner@tasktracker.test`, `bob.member@tasktracker.test`, `carol.guest@tasktracker.test`, `dave.owner@tasktracker.test`, `erin.member@tasktracker.test` — see `readme.md` → Test/Demo Accounts) to verify tenant isolation, RBAC, and realtime sync between the Flutter app and the existing web app (e.g. change a task's status on web, confirm it updates live on mobile).

---

## 8. Dependencies (indicative — pinned during implementation)

- `supabase_flutter` — Supabase client, auth, Postgrest, Realtime
- `flutter_riverpod` — state management
- `go_router` — navigation
- A charting package for Analytics (e.g. `fl_chart`)
- A Gantt/timeline package or custom widget for the Gantt view

No new Supabase migrations are required — the Flutter app targets the schema exactly as documented in `readme.md` → Database (tables `workspaces`, `workspace_members`, `invitations`, `notifications`, `tt_projects`, `milestones`, `sprints`, `tasks`, `task_comments`, `task_activity`), including the existing `tt_projects` naming (not `projects`, per the documented table-collision fix).
