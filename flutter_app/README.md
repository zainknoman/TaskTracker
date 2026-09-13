# TaskFlow Pro — Mobile ⚡

> **Flutter (iOS/Android) client for TaskFlow Pro** — the same multi-tenant Supabase backend as the [web app](../readme.md), one live dataset, two clients.

This app is a second, mobile-native front end for [TaskFlow Pro](../readme.md). It talks directly to the same Supabase project as the web app — same tables, same Row-Level Security policies, same accounts — via the official `supabase_flutter` SDK. There is no separate backend, no API layer, and no data migration: sign in with an existing TaskFlow account and see the same workspaces, projects, and tasks the web app shows, live-synced in both directions.

Design rationale and scope decisions live in [`docs/superpowers/specs/2026-09-13-flutter-mobile-app-design.md`](../docs/superpowers/specs/2026-09-13-flutter-mobile-app-design.md); the build was carried out per [`docs/superpowers/plans/2026-09-13-flutter-mobile-app.md`](../docs/superpowers/plans/2026-09-13-flutter-mobile-app.md).

## Table of Contents

- [What This App Is](#what-this-app-is)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Views & Features](#views--features)
- [Mobile UX Adaptations](#mobile-ux-adaptations)
- [Roles & Permissions](#roles--permissions)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [Known Gaps / Out of Scope](#known-gaps--out-of-scope)

---

## What This App Is

Same product, mobile-native shell. Every workspace-scoped entity (projects, tasks, milestones, sprints, members, notifications) is read and written straight against Supabase Postgres, with RLS as the real security boundary — identical guarantees to the web app, just enforced against a different client. A change made on mobile shows up on web within 1–2 seconds via Supabase Realtime, and vice versa.

| | Web app | Mobile app (this) |
|---|---|---|
| Platform | Browser (static site, no build step) | iOS + Android (Flutter) |
| Backend | Supabase project `zynunureylcdexxhvdth` | **Same project** — same URL, same anon key, same tables |
| State | Plain JS object (`js/state.js`) | Riverpod providers, mostly `StreamProvider`s bound to Realtime |
| Navigation | Sidebar + view router | Bottom nav (5 tabs) + a "More" sheet for the rest |
| Command palette (Ctrl/⌘+K) | Yes | Dropped — replaced by a search sheet (no mobile keyboard-shortcut equivalent) |
| Offline support | None (always requires a connection) | None (v1 is online-only, matching the web app) |
| Push notifications | None (in-app bell badge only) | None (v1 is in-app only — no FCM/APNs) |

## Architecture

```
Flutter app (iOS + Android)
 lib/
   main.dart              Entry point — Supabase init, ProviderScope, MaterialApp.router
   core/
     supabase_config.dart  Supabase client (same project as the web app)
     theme.dart             Material 3 theme
     router.dart            go_router config: auth guard + StatefulShellRoute tabs
   models/                 Dart classes mirroring the Postgres schema (fromJson/toJson/copyWith)
   data/                    Repositories — one per entity, wraps supabase_flutter calls,
                             maps Postgrest errors to typed AppException/PermissionDeniedException/
                             NotFoundException
   providers/               Riverpod providers — auth, workspace, permissions, and one
                             StreamProvider.family per entity wired to Postgres Realtime
   features/                One folder per screen (see Views & Features below)
   widgets/                 Shared UI: badges, empty states, toasts

Supabase (zynunureylcdexxhvdth) — the SAME project the web app uses, unchanged
 ├── Auth        email/password — same user pool as web
 ├── Postgres    same 10 workspace-scoped tables (tt_projects, tasks, milestones, sprints, ...)
 ├── RLS         same policies — the real security/tenant-isolation boundary for both clients
 └── Realtime    same postgres_changes subscriptions, now also consumed by this app
```

**Data flow:** `SupabaseConfig.initialize()` sets up the client in `main()` → `authStateProvider` restores the session or the router redirects to `/login` → once a workspace is active, per-entity `StreamProvider`s (`tasksProvider`, `projectsProvider`, `membersProvider`, `notificationsProvider`) stream both the initial load and every subsequent Realtime change, so a screen watching one of these providers is always current — no separate "fetch once, then merge realtime patches" step like the web app's `state.js` needs. Writes go through the matching repository in `data/`; the Realtime stream picks up the resulting change and the UI updates automatically. `permissionsProvider` mirrors `js/permissions.js`'s owner/member/guest rules for the UI layer only — RLS is still the actual enforcement, identical to the web app.

## Getting Started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (this app targets 3.47+ / Dart 3.13+) and either an Android emulator, iOS simulator, or a physical device.

```bash
cd flutter_app
flutter pub get
```

### Supabase credentials

The app defaults to the same Supabase project and anon key the web app ships (`zynunureylcdexxhvdth`, matching `config.js` in the repo root) — `flutter run` works with no extra flags. The key is baked in as a default in `lib/core/supabase_config.dart` rather than left blank, because it's RLS-restricted and meant to be public (see the root [`readme.md` → Database](../readme.md#database)) — the same reasoning that already applies to the web app's `config.js`.

To point at a **different** Supabase project (e.g. your own fork), override both at build/run time via `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your anon/public key>
```

### Running

```bash
flutter devices          # list available emulators/simulators/devices
flutter run               # launches on the first available device
flutter run -d <deviceId> # or target a specific one
```

Sign in with any existing TaskFlow account (e.g. the [seeded test accounts](../readme.md#test--demo-accounts)) or sign up — this Supabase project has `mailer_autoconfirm` enabled, so signup logs you in immediately, exactly like the web app.

### Building

```bash
flutter build apk --debug     # Android debug APK
flutter build apk --release   # Android release APK (requires signing config for a real release)
flutter build ios             # iOS build (requires Xcode, macOS)
```

## Views & Features

| Web view | Mobile screen(s) | Notes |
|---|---|---|
| Dashboard | `features/dashboard/` | Stats grid, upcoming deadlines (next 7 days), team workload |
| Projects | `features/projects/` | Grid → detail (Overview/Tasks/Milestones/Sprints tabs), create/edit form |
| Tasks | `features/tasks/` | Filterable/sortable list, detail with status control + comments, create/edit form |
| Kanban | `features/kanban/` | 4 status columns, touch drag-and-drop (`LongPressDraggable`/`DragTarget`) |
| Calendar | `features/calendar/` | Monthly grid, tap a day to see its due tasks |
| Gantt | `features/gantt/` | Custom scrollable timeline (see [Mobile UX Adaptations](#mobile-ux-adaptations)) |
| Analytics | `features/analytics/` | Status/priority pie charts, per-member workload bar chart (`fl_chart`) |
| Team | `features/team/` | Member grid, profile editing (display name, skills) |
| Workspace switcher / invite / members | `features/workspace/` | Switch workspace, generate invite links, manage members |
| Notifications (bell badge) | `features/notifications/` | List + unread badge on the bottom nav, Realtime-driven |
| Command palette (Ctrl/⌘+K) | `features/shell/search_sheet.dart` | Full-screen search sheet, opened from the search icon |

Auth screens (`features/auth/`) and the app shell (`features/shell/app_shell.dart` — bottom nav + "More" sheet + top bar) tie everything together via `core/router.dart`.

## Mobile UX Adaptations

A few desktop-oriented interactions from the web app don't port 1:1 — see [the design spec](../docs/superpowers/specs/2026-09-13-flutter-mobile-app-design.md#4-mobile-ux-adaptations) for the full rationale:

- **Kanban drag-and-drop** — mouse drag becomes a long-press touch drag between status columns.
- **Gantt chart** — no Flutter Gantt package exists on pub.dev (`syncfusion_flutter_gantt` does not exist, despite Syncfusion shipping one for other platforms), so `features/gantt/gantt_screen.dart` is a custom horizontally/vertically scrollable timeline built from `DateTime` math and `Positioned` bars.
- **Command palette** — no mobile keyboard-shortcut equivalent; replaced by a search icon that opens a full-screen search sheet.

## Roles & Permissions

Identical three-tier RBAC to the web app (`lib/providers/permissions_provider.dart` mirrors `js/permissions.js` exactly) — UI-layer only, since Postgres RLS is the real enforcement for both clients:

| Action | Owner | Member | Guest |
|---|:---:|:---:|:---:|
| View projects/tasks | ✓ | ✓ | ✓ |
| Create/edit project or task | ✓ | ✓ | ✗ |
| Delete project or task | ✓ (any) | own only | ✗ |
| Invite members | ✓ | ✓ | ✗ |
| Change member roles / remove members | ✓ | ✗ | ✗ |
| Comment on tasks | ✓ | ✓ | ✗ |

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart
│   ├── core/               Supabase init, theme, router
│   ├── models/              Task, Project, Workspace, WorkspaceMember, Milestone, Sprint,
│   │                        TaskComment, AppNotification, Invitation
│   ├── data/                One repository per entity + typed exception mapping
│   ├── providers/           Riverpod providers (auth, workspace, permissions, per-entity streams)
│   ├── features/            One folder per screen — auth, dashboard, projects, tasks, kanban,
│   │                        calendar, gantt, analytics, team, notifications, workspace, shell
│   └── widgets/             Shared badges/empty-state/toast widgets
├── test/
│   ├── models/               fromJson/toJson/copyWith round-trip tests
│   ├── data/                 Error-mapping unit tests
│   ├── providers/            Permissions logic unit tests
│   └── widgets/               Screen smoke tests
├── android/ , ios/           Platform projects (`flutter create` defaults)
└── pubspec.yaml
```

## Testing

```bash
flutter analyze   # static analysis — should report no errors
flutter test       # unit + widget tests
```

Model tests cover JSON round-tripping against the exact Postgres column names documented in the root [`readme.md` → Data Model](../readme.md#data-model). Repository tests cover Postgrest → typed exception mapping (RLS denial → `PermissionDeniedException`, missing row → `NotFoundException`). Provider tests cover the owner/member/guest permission matrix. Widget tests are smoke tests (screen renders, key controls present) rather than exhaustive interaction tests — drag-and-drop, Gantt, and Calendar are verified manually.

For end-to-end multi-tenant verification, use the same [seeded test accounts](../readme.md#test--demo-accounts) the web app uses — sign in as `alice.owner@tasktracker.test` on mobile and `bob.member@tasktracker.test` on web (or vice versa) to confirm Realtime sync and tenant isolation hold across both clients.

## Known Gaps / Out of Scope

Deliberately deferred for v1 (see the design spec's [Confirmed decisions](../docs/superpowers/specs/2026-09-13-flutter-mobile-app-design.md#confirmed-decisions-from-brainstorming) table for the reasoning):

- **Offline support** — no local caching or write queue; the app requires a live connection at all times, same as the web app.
- **Push notifications** — no FCM/APNs; notifications are in-app + Realtime only, matching the web app's bell badge.
- **Flutter web/desktop build targets** — this app targets iOS and Android only.
- **Command palette** — dropped in favor of a search sheet (see [Mobile UX Adaptations](#mobile-ux-adaptations)).

No backend or schema changes were made for this app — it reads and writes the exact schema documented in the root [`readme.md` → Database](../readme.md#database), including the `tt_projects` table name (not `projects`, per that repo's documented table-collision fix).
