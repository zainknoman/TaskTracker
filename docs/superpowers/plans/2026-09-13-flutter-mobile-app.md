# TaskFlow Pro Flutter App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter (iOS/Android) client for TaskFlow Pro that reuses the existing Supabase backend and reaches full feature parity with the web app's 8 views, RBAC, invitations, notifications, and Realtime sync.

**Architecture:** A single Flutter app in `flutter_app/`, using `supabase_flutter` against the existing project (`zynunureylcdexxhvdth`), Riverpod for state (auth/workspace/per-entity `StreamProvider`s wired to Postgres Realtime), `go_router` for navigation, and a bottom-nav + "More" drawer shell mirroring the web sidebar's 8 links.

**Tech Stack:** Flutter 3.47 / Dart 3.13, `supabase_flutter`, `flutter_riverpod`, `go_router`, `fl_chart` (Analytics), `intl` (dates).

**Spec:** `docs/superpowers/specs/2026-09-13-flutter-mobile-app-design.md`

## Global Constraints

- Platform target: iOS + Android only (no web/desktop Flutter build targets).
- Reuse the existing Supabase project as-is: no new migrations, no schema changes. Table name is `tt_projects`, not `projects` (documented collision fix in `readme.md`).
- State management: Riverpod only (no Provider/BLoC mixed in).
- Online-only v1: no local caching/offline queue, no FCM/APNs push notifications.
- Command palette (Ctrl/⌘+K) is dropped; replaced by a search sheet.
- RLS is the real permission boundary; `permissionsProvider` in the app is UI-layer only (hide/disable controls), matching `js/permissions.js`'s role rules exactly (see spec §5).
- Every repository call must surface Supabase/Postgrest errors as typed exceptions, not raw exceptions (spec §6).

---

## File Structure

```
flutter_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── supabase_config.dart
│   │   ├── theme.dart
│   │   └── router.dart
│   ├── models/
│   │   ├── workspace.dart
│   │   ├── workspace_member.dart
│   │   ├── project.dart
│   │   ├── milestone.dart
│   │   ├── sprint.dart
│   │   ├── task.dart
│   │   ├── task_comment.dart
│   │   ├── notification.dart
│   │   └── invitation.dart
│   ├── data/
│   │   ├── exceptions.dart
│   │   ├── auth_repository.dart
│   │   ├── workspace_repository.dart
│   │   ├── project_repository.dart
│   │   ├── task_repository.dart
│   │   ├── member_repository.dart
│   │   ├── notification_repository.dart
│   │   └── invitation_repository.dart
│   ├── providers/
│   │   ├── auth_providers.dart
│   │   ├── workspace_providers.dart
│   │   ├── project_providers.dart
│   │   ├── task_providers.dart
│   │   ├── member_providers.dart
│   │   ├── notification_providers.dart
│   │   └── permissions_provider.dart
│   ├── features/
│   │   ├── auth/{login_screen.dart, signup_screen.dart}
│   │   ├── shell/{app_shell.dart, search_sheet.dart}
│   │   ├── dashboard/dashboard_screen.dart
│   │   ├── projects/{projects_list_screen.dart, project_detail_screen.dart, project_form_sheet.dart}
│   │   ├── tasks/{tasks_list_screen.dart, task_detail_screen.dart, task_form_sheet.dart}
│   │   ├── kanban/kanban_screen.dart
│   │   ├── calendar/calendar_screen.dart
│   │   ├── gantt/gantt_screen.dart
│   │   ├── analytics/analytics_screen.dart
│   │   ├── team/team_screen.dart
│   │   ├── notifications/notifications_screen.dart
│   │   └── workspace/{workspace_switcher_sheet.dart, invite_sheet.dart, members_screen.dart}
│   └── widgets/
│       ├── app_toast.dart
│       ├── empty_state.dart
│       ├── role_badge.dart
│       ├── priority_badge.dart
│       └── status_badge.dart
└── test/
    ├── data/task_repository_test.dart
    ├── providers/permissions_provider_test.dart
    └── widgets/login_screen_test.dart
```

## Task Right-Sizing Note

Given this is a UI-heavy port of 8+ screens against an already-fixed backend schema, tasks below are scoped at **feature/sprint granularity** rather than micro widget-by-widget TDD steps — each task's acceptance check is `flutter analyze` (zero errors) plus a targeted widget/unit test, matching how the user asked this to run: build the files, then run tests, fix failures, then commit. Pure-logic units (models' `fromJson`/`toJson`, repositories, `permissionsProvider`) get real unit tests written test-first; UI screens get one smoke-test widget test each (renders without throwing, key elements present) since exhaustive interaction testing of drag-and-drop/Gantt/Calendar is disproportionate for a v1 port.

---

### Sprint 1: Project Scaffold, Supabase Config, Theme, Router Shell

**Files:**
- Create: `flutter_app/pubspec.yaml`, `flutter_app/lib/main.dart`, `flutter_app/lib/core/supabase_config.dart`, `flutter_app/lib/core/theme.dart`, `flutter_app/lib/core/router.dart`

**Interfaces:**
- Produces: `Supabase.instance.client` initialized app-wide; `appRouter` (`GoRouter`) with routes `/login`, `/signup`, `/` (shell); `appTheme` (`ThemeData`).

- [ ] **Step 1:** Run `flutter create flutter_app --platforms=ios,android --org com.tasktrackerapp` from the repo root.
- [ ] **Step 2:** Add dependencies to `pubspec.yaml`: `supabase_flutter: ^2.6.0`, `flutter_riverpod: ^2.6.1`, `go_router: ^14.6.2`, `fl_chart: ^0.69.0`, `intl: ^0.19.0`, `uuid: ^4.5.1`. Run `flutter pub get`.
- [ ] **Step 3:** Create `lib/core/supabase_config.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zynunureylcdexxhvdth.supabase.co',
  );
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
```
- [ ] **Step 4:** Create `lib/core/theme.dart` with a `ThemeData appTheme` using `ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5))` (matches the web app's indigo accent), `useMaterial3: true`.
- [ ] **Step 5:** Create `lib/core/router.dart` with a `GoRouter` exposing `/login`, `/signup`, and a placeholder `/` route rendering `Scaffold(body: Center(child: Text('Home')))` (replaced by the real shell in Sprint 16). Use `refreshListenable` bound to `SupabaseConfig.client.auth.onAuthStateChange` so route guards react to login/logout.
- [ ] **Step 6:** Rewrite `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: TaskFlowApp()));
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TaskFlow Pro',
      theme: appTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
```
- [ ] **Step 7:** Run `flutter analyze` in `flutter_app/`. Expected: no errors.
- [ ] **Step 8: Commit**
```bash
git add flutter_app
git commit -m "Sprint 1: scaffold Flutter app, Supabase config, theme, router shell"
```

---

### Sprint 2: Data Models

**Files:**
- Create: `flutter_app/lib/models/workspace.dart`, `workspace_member.dart`, `project.dart`, `milestone.dart`, `sprint.dart`, `task.dart`, `task_comment.dart`, `notification.dart`, `invitation.dart`
- Test: `flutter_app/test/models/task_test.dart`, `flutter_app/test/models/project_test.dart`

**Interfaces:**
- Produces: `Task.fromJson(Map<String, dynamic>)`, `Task#toJson()`, `Task#copyWith(...)`, and the same for every model listed above. Field names match the Postgres columns documented in the spec §8 / `readme.md` → Data Model exactly (snake_case in JSON, camelCase as Dart fields).

- [ ] **Step 1: Write failing tests** in `flutter_app/test/models/task_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tasktracker_flutter/models/task.dart';

void main() {
  test('Task.fromJson / toJson round-trip', () {
    final json = {
      'id': 't1', 'workspace_id': 'w1', 'project_id': 'p1',
      'milestone_id': null, 'sprint_id': null, 'parent_task_id': null,
      'title': 'Write plan', 'description': 'desc', 'priority': 'high',
      'status': 'in_progress', 'start_date': null, 'due_date': '2026-09-20',
      'ba': null, 'assignee_id': 'u1', 'estimated_hours': 4,
      'actual_hours': 0, 'progress': 25, 'tags': ['flutter'],
      'documents': [], 'dependencies': [], 'subtasks': [], 'notes': null,
      'starred': false, 'pinned': false, 'created_by': 'u1',
      'created_at': '2026-09-01T00:00:00Z', 'updated_at': '2026-09-01T00:00:00Z',
    };
    final task = Task.fromJson(json);
    expect(task.title, 'Write plan');
    expect(task.priority, 'high');
    expect(task.tags, ['flutter']);
    expect(task.toJson()['title'], 'Write plan');
  });

  test('Task.copyWith overrides only given fields', () {
    final task = Task.fromJson({
      'id': 't1', 'workspace_id': 'w1', 'project_id': 'p1',
      'milestone_id': null, 'sprint_id': null, 'parent_task_id': null,
      'title': 'A', 'description': null, 'priority': 'low',
      'status': 'pending', 'start_date': null, 'due_date': null,
      'ba': null, 'assignee_id': null, 'estimated_hours': null,
      'actual_hours': null, 'progress': 0, 'tags': [], 'documents': [],
      'dependencies': [], 'subtasks': [], 'notes': null, 'starred': false,
      'pinned': false, 'created_by': 'u1',
      'created_at': '2026-09-01T00:00:00Z', 'updated_at': '2026-09-01T00:00:00Z',
    });
    final updated = task.copyWith(status: 'completed');
    expect(updated.status, 'completed');
    expect(updated.title, 'A');
  });
}
```
- [ ] **Step 2: Run test to verify it fails** — `flutter test test/models/task_test.dart` — Expected: FAIL (package/class not found).
- [ ] **Step 3: Implement `lib/models/task.dart`:**
```dart
class Task {
  final String id;
  final String workspaceId;
  final String projectId;
  final String? milestoneId;
  final String? sprintId;
  final String? parentTaskId;
  final String title;
  final String? description;
  final String priority; // low | medium | high | critical
  final String status; // pending | in_progress | completed | blocked
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? ba;
  final String? assigneeId;
  final num? estimatedHours;
  final num? actualHours;
  final int progress;
  final List<String> tags;
  final List<dynamic> documents;
  final List<dynamic> dependencies;
  final List<dynamic> subtasks;
  final String? notes;
  final bool starred;
  final bool pinned;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Task({
    required this.id, required this.workspaceId, required this.projectId,
    this.milestoneId, this.sprintId, this.parentTaskId, required this.title,
    this.description, required this.priority, required this.status,
    this.startDate, this.dueDate, this.ba, this.assigneeId,
    this.estimatedHours, this.actualHours, required this.progress,
    required this.tags, required this.documents, required this.dependencies,
    required this.subtasks, this.notes, required this.starred,
    required this.pinned, required this.createdBy, required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        workspaceId: json['workspace_id'] as String,
        projectId: json['project_id'] as String,
        milestoneId: json['milestone_id'] as String?,
        sprintId: json['sprint_id'] as String?,
        parentTaskId: json['parent_task_id'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        priority: json['priority'] as String,
        status: json['status'] as String,
        startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
        dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
        ba: json['ba'] as String?,
        assigneeId: json['assignee_id'] as String?,
        estimatedHours: json['estimated_hours'] as num?,
        actualHours: json['actual_hours'] as num?,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        tags: List<String>.from(json['tags'] as List? ?? const []),
        documents: List<dynamic>.from(json['documents'] as List? ?? const []),
        dependencies: List<dynamic>.from(json['dependencies'] as List? ?? const []),
        subtasks: List<dynamic>.from(json['subtasks'] as List? ?? const []),
        notes: json['notes'] as String?,
        starred: json['starred'] as bool? ?? false,
        pinned: json['pinned'] as bool? ?? false,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'workspace_id': workspaceId, 'project_id': projectId,
        'milestone_id': milestoneId, 'sprint_id': sprintId,
        'parent_task_id': parentTaskId, 'title': title,
        'description': description, 'priority': priority, 'status': status,
        'start_date': startDate?.toIso8601String(),
        'due_date': dueDate?.toIso8601String(), 'ba': ba,
        'assignee_id': assigneeId, 'estimated_hours': estimatedHours,
        'actual_hours': actualHours, 'progress': progress, 'tags': tags,
        'documents': documents, 'dependencies': dependencies,
        'subtasks': subtasks, 'notes': notes, 'starred': starred,
        'pinned': pinned, 'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Task copyWith({
    String? title, String? description, String? priority, String? status,
    DateTime? startDate, DateTime? dueDate, String? assigneeId,
    num? estimatedHours, num? actualHours, int? progress,
    List<String>? tags, String? notes, bool? starred, bool? pinned,
    String? milestoneId, String? sprintId,
  }) => Task(
        id: id, workspaceId: workspaceId, projectId: projectId,
        milestoneId: milestoneId ?? this.milestoneId,
        sprintId: sprintId ?? this.sprintId, parentTaskId: parentTaskId,
        title: title ?? this.title, description: description ?? this.description,
        priority: priority ?? this.priority, status: status ?? this.status,
        startDate: startDate ?? this.startDate, dueDate: dueDate ?? this.dueDate,
        ba: ba, assigneeId: assigneeId ?? this.assigneeId,
        estimatedHours: estimatedHours ?? this.estimatedHours,
        actualHours: actualHours ?? this.actualHours,
        progress: progress ?? this.progress, tags: tags ?? this.tags,
        documents: documents, dependencies: dependencies, subtasks: subtasks,
        notes: notes ?? this.notes, starred: starred ?? this.starred,
        pinned: pinned ?? this.pinned, createdBy: createdBy,
        createdAt: createdAt, updatedAt: DateTime.now(),
      );
}
```
- [ ] **Step 4: Run test to verify it passes** — `flutter test test/models/task_test.dart` — Expected: PASS.
- [ ] **Step 5:** Implement the remaining models (`workspace.dart`, `workspace_member.dart`, `project.dart`, `milestone.dart`, `sprint.dart`, `task_comment.dart`, `notification.dart`, `invitation.dart`) following the same `fromJson`/`toJson` pattern, with fields matching `readme.md` → Data Model and Database → Schema exactly:
  - `Workspace`: `id, name, slug, ownerId, createdAt`
  - `WorkspaceMember`: `id, workspaceId, userId, role, displayName, avatarUrl, avatarPreset, color, skills (List<String>), joinedAt`
  - `Project` (table `tt_projects`): `id, workspaceId, name, code, description, department, client, pm, baTeam, status, priority, startDate, endDate, budget, color, tags (List<String>), createdBy, createdAt, updatedAt`
  - `Milestone`: `id, workspaceId, projectId, title, dueDate, status, createdAt`
  - `Sprint`: `id, workspaceId, projectId, name, startDate, endDate, status, createdAt`
  - `TaskComment`: `id, taskId, workspaceId, authorId, body, createdAt`
  - `AppNotification`: `id, workspaceId, userId, type, message, taskId, read, createdAt`
  - `Invitation`: `id, workspaceId, token, role, createdBy, expiresAt, usedAt, createdAt`
- [ ] **Step 6:** Add `flutter test test/models/project_test.dart` covering `Project.fromJson`/`toJson` round-trip (same pattern as Step 1, using `tt_projects` field names above).
- [ ] **Step 7:** Run `flutter test test/models/` — Expected: all PASS. Run `flutter analyze` — Expected: no errors.
- [ ] **Step 8: Commit**
```bash
git add flutter_app/lib/models flutter_app/test/models
git commit -m "Sprint 2: add data models mirroring Postgres schema"
```

---

### Sprint 3: Data Layer (Repositories)

**Files:**
- Create: `flutter_app/lib/data/exceptions.dart`, `auth_repository.dart`, `workspace_repository.dart`, `project_repository.dart`, `task_repository.dart`, `member_repository.dart`, `notification_repository.dart`, `invitation_repository.dart`
- Test: `flutter_app/test/data/task_repository_test.dart`

**Interfaces:**
- Consumes: `Task`, `Project`, `Workspace`, `WorkspaceMember`, `AppNotification`, `Invitation` from Sprint 2; `SupabaseConfig.client` from Sprint 1.
- Produces: `AuthRepository{signIn, signUp, signOut, currentUser}`, `WorkspaceRepository{listForUser, create, switchActive}`, `ProjectRepository{listForWorkspace(String workspaceId), create(Project), update(Project), delete(String id)}`, `TaskRepository{listForWorkspace(String workspaceId), create(Task), update(Task), delete(String id), streamForWorkspace(String workspaceId)}`, `MemberRepository{listForWorkspace, updateProfile, remove}`, `NotificationRepository{listForUser, markRead, streamForUser(String userId)}`, `InvitationRepository{create, accept(String token), cancel}`. All entity list/CRUD methods throw `AppException` subtypes on failure.

- [ ] **Step 1: Write failing test** `flutter_app/test/data/task_repository_test.dart` (verifies error mapping, using a fake `PostgrestException`):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';
import 'package:tasktracker_flutter/data/exceptions.dart';

void main() {
  test('mapPostgrestError maps RLS denial to PermissionDeniedException', () {
    final err = PostgrestException(message: 'new row violates row-level security policy', code: '42501');
    final mapped = mapPostgrestError(err);
    expect(mapped, isA<PermissionDeniedException>());
  });

  test('mapPostgrestError maps not-found code to NotFoundException', () {
    final err = PostgrestException(message: 'no rows returned', code: 'PGRST116');
    final mapped = mapPostgrestError(err);
    expect(mapped, isA<NotFoundException>());
  });

  test('mapPostgrestError falls back to AppException', () {
    final err = PostgrestException(message: 'boom', code: '500');
    final mapped = mapPostgrestError(err);
    expect(mapped, isA<AppException>());
  });
}
```
- [ ] **Step 2: Run test to verify it fails** — `flutter test test/data/task_repository_test.dart` — Expected: FAIL (file not found).
- [ ] **Step 3:** Implement `lib/data/exceptions.dart`:
```dart
import 'package:postgrest/postgrest.dart';

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

class AuthFailureException extends AppException {
  AuthFailureException(super.message);
}

class PermissionDeniedException extends AppException {
  PermissionDeniedException(super.message);
}

class NotFoundException extends AppException {
  NotFoundException(super.message);
}

AppException mapPostgrestError(PostgrestException err) {
  if (err.code == '42501' || err.message.toLowerCase().contains('row-level security')) {
    return PermissionDeniedException('You do not have permission to do that.');
  }
  if (err.code == 'PGRST116' || err.message.toLowerCase().contains('no rows')) {
    return NotFoundException('The requested item was not found.');
  }
  return AppException(err.message);
}
```
- [ ] **Step 4: Run test to verify it passes** — `flutter test test/data/task_repository_test.dart` — Expected: PASS.
- [ ] **Step 5:** Implement `lib/data/task_repository.dart`:
```dart
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/task.dart';
import 'exceptions.dart';

class TaskRepository {
  final SupabaseClient _client;
  TaskRepository({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  Future<List<Task>> listForWorkspace(String workspaceId) async {
    try {
      final rows = await _client.from('tasks').select().eq('workspace_id', workspaceId);
      return rows.map((r) => Task.fromJson(r)).toList();
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Task> create(Task task) async {
    try {
      final row = await _client.from('tasks').insert(task.toJson()..remove('id')).select().single();
      return Task.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<Task> update(Task task) async {
    try {
      final row = await _client.from('tasks').update(task.toJson()).eq('id', task.id).select().single();
      return Task.fromJson(row);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('tasks').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Stream<List<Task>> streamForWorkspace(String workspaceId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('workspace_id', workspaceId)
        .map((rows) => rows.map((r) => Task.fromJson(r)).toList());
  }
}
```
- [ ] **Step 6:** Implement the remaining repositories following the same pattern (try/catch → `mapPostgrestError`, `.stream(primaryKey: ['id'])` for realtime-backed lists):
  - `ProjectRepository` — table `tt_projects`, same 4 methods + `streamForWorkspace`.
  - `WorkspaceRepository` — `listForUser()` selects `workspace_members` joined to `workspaces` for `auth.currentUser.id`; `create(String name)` inserts into `workspaces` (owner-auto-join trigger handles membership).
  - `MemberRepository` — table `workspace_members`, `listForWorkspace`, `updateProfile(WorkspaceMember)`, `remove(String memberId)`.
  - `NotificationRepository` — table `notifications`, `listForUser(String userId)`, `markRead(String id)`, `streamForUser(String userId)` filtered `.eq('user_id', userId)`.
  - `InvitationRepository` — table `invitations`; `create` inserts a row with a generated `uuid` token; `accept(String token)` calls the existing `accept_invitation` RPC: `_client.rpc('accept_invitation', params: {'invite_token': token})`; `cancel(String id)` deletes the row.
  - `AuthRepository` — wraps `_client.auth.signInWithPassword`, `.signUp`, `.signOut`, exposes `currentUser` getter, mapping `AuthException` (from `supabase_flutter`) to `AuthFailureException`.
- [ ] **Step 7:** Run `flutter analyze` — Expected: no errors. Run `flutter test test/data/` — Expected: all PASS.
- [ ] **Step 8: Commit**
```bash
git add flutter_app/lib/data flutter_app/test/data
git commit -m "Sprint 3: add repository data layer with typed error mapping"
```

---

### Sprint 4: Auth Providers + Login/Signup Screens

**Files:**
- Create: `flutter_app/lib/providers/auth_providers.dart`, `flutter_app/lib/features/auth/login_screen.dart`, `flutter_app/lib/features/auth/signup_screen.dart`
- Modify: `flutter_app/lib/core/router.dart` (wire `/login`, `/signup` to real screens; redirect logic)
- Test: `flutter_app/test/widgets/login_screen_test.dart`

**Interfaces:**
- Consumes: `AuthRepository` from Sprint 3.
- Produces: `authRepositoryProvider` (`Provider<AuthRepository>`), `authStateProvider` (`StreamProvider<AuthState>`, from `SupabaseConfig.client.auth.onAuthStateChange`), `currentUserProvider` (`Provider<User?>`).

- [ ] **Step 1:** Implement `lib/providers/auth_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.value?.session?.user ?? SupabaseConfig.client.auth.currentUser;
});
```
- [ ] **Step 2:** Implement `lib/features/auth/login_screen.dart`: a `ConsumerStatefulWidget` with email/password `TextFormField`s, a "Sign in" `FilledButton` calling `ref.read(authRepositoryProvider).signIn(email, password)` inside a try/catch showing `AppToast.error(context, e.toString())` on `AuthFailureException`, and a `TextButton` linking to `/signup` via `context.push('/signup')`. On success, do nothing explicit — the router's `refreshListenable` (Sprint 1) redirects automatically once `authStateProvider` emits signed-in.
- [ ] **Step 3:** Implement `lib/features/auth/signup_screen.dart`: same form shape, calls `signUp(email, password)`, same error handling, link back to `/login`.
- [ ] **Step 4:** Modify `lib/core/router.dart`: point `/login` → `LoginScreen()`, `/signup` → `SignupScreen()`; add a `redirect:` callback that sends unauthenticated users to `/login` for any route other than `/login`/`/signup`, and authenticated users away from `/login`/`/signup` to `/`.
- [ ] **Step 5: Write widget test** `flutter_app/test/widgets/login_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasktracker_flutter/features/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders email, password fields and sign-in button', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
```
- [ ] **Step 6: Run test** — `flutter test test/widgets/login_screen_test.dart` — Expected: PASS.
- [ ] **Step 7:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 8: Commit**
```bash
git add flutter_app/lib/providers/auth_providers.dart flutter_app/lib/features/auth flutter_app/lib/core/router.dart flutter_app/test/widgets/login_screen_test.dart
git commit -m "Sprint 4: add auth providers and login/signup screens"
```

---

### Sprint 5: Workspace Providers, Switcher, Invite, Members

**Files:**
- Create: `flutter_app/lib/providers/workspace_providers.dart`, `flutter_app/lib/providers/member_providers.dart`, `flutter_app/lib/features/workspace/workspace_switcher_sheet.dart`, `invite_sheet.dart`, `members_screen.dart`

**Interfaces:**
- Consumes: `WorkspaceRepository`, `MemberRepository`, `InvitationRepository` from Sprint 3; `currentUserProvider` from Sprint 4.
- Produces: `workspaceListProvider` (`FutureProvider<List<Workspace>>`), `activeWorkspaceIdProvider` (`StateProvider<String?>`), `activeWorkspaceProvider` (`Provider<Workspace?>`), `activeMembershipProvider` (`Provider<WorkspaceMember?>` — current user's row in the active workspace, source of role for `permissionsProvider` in Sprint 6), `membersProvider` (`StreamProvider.family<List<WorkspaceMember>, String>` keyed by workspace id).

- [ ] **Step 1:** Implement `lib/providers/workspace_providers.dart` with the 4 providers above; `workspaceListProvider` loads via `WorkspaceRepository.listForUser()` and, if the list is non-empty and `activeWorkspaceIdProvider` is null, sets it to the first workspace's id.
- [ ] **Step 2:** Implement `lib/providers/member_providers.dart`: `membersProvider` as a `StreamProvider.family<String, List<WorkspaceMember>>` wrapping `MemberRepository`'s realtime stream (mirrors `TaskRepository.streamForWorkspace` pattern from Sprint 3); `activeMembershipProvider` derives the current user's `WorkspaceMember` by matching `userId == currentUserProvider.id` within `membersProvider(activeWorkspaceId)`.
- [ ] **Step 3:** Implement `lib/features/workspace/workspace_switcher_sheet.dart`: a `ConsumerWidget` bottom sheet listing `workspaceListProvider` entries as `ListTile`s; tapping one sets `activeWorkspaceIdProvider`; includes a "Create workspace" tile opening a text-input dialog calling `WorkspaceRepository.create(name)`.
- [ ] **Step 4:** Implement `lib/features/workspace/invite_sheet.dart`: visible only when `permissionsProvider.canInvite` (added in Sprint 6 — for now gate on `activeMembershipProvider?.role != 'guest'` directly) is true; a button calls `InvitationRepository.create(workspaceId, role)` and displays the resulting `?invite=<token>` deep link in a `SelectableText` for the user to copy/share.
- [ ] **Step 5:** Implement `lib/features/workspace/members_screen.dart`: lists `membersProvider(activeWorkspaceId)` as cards (avatar, display name, role badge via `widgets/role_badge.dart`); owners see a "Remove" action per non-owner row calling `MemberRepository.remove`.
- [ ] **Step 6:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 7: Commit**
```bash
git add flutter_app/lib/providers/workspace_providers.dart flutter_app/lib/providers/member_providers.dart flutter_app/lib/features/workspace
git commit -m "Sprint 5: add workspace switching, invitations, and members screen"
```

---

### Sprint 6: Permissions Provider

**Files:**
- Create: `flutter_app/lib/providers/permissions_provider.dart`
- Test: `flutter_app/test/providers/permissions_provider_test.dart`

**Interfaces:**
- Consumes: `activeMembershipProvider` from Sprint 5.
- Produces: `permissionsProvider` (`Provider<Permissions>`) exposing `bool canEdit`, `bool canInvite`, `bool canManageMembers`, `bool Function(String createdBy) canDelete`.

- [ ] **Step 1: Write failing test** `flutter_app/test/providers/permissions_provider_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasktracker_flutter/providers/permissions_provider.dart';

void main() {
  test('guest cannot edit, invite, or manage members', () {
    final perms = Permissions(role: 'guest', currentUserId: 'u1');
    expect(perms.canEdit, isFalse);
    expect(perms.canInvite, isFalse);
    expect(perms.canManageMembers, isFalse);
    expect(perms.canDelete('u1'), isFalse);
  });

  test('member can edit/invite, can only delete own items', () {
    final perms = Permissions(role: 'member', currentUserId: 'u1');
    expect(perms.canEdit, isTrue);
    expect(perms.canInvite, isTrue);
    expect(perms.canManageMembers, isFalse);
    expect(perms.canDelete('u1'), isTrue);
    expect(perms.canDelete('u2'), isFalse);
  });

  test('owner can delete anything and manage members', () {
    final perms = Permissions(role: 'owner', currentUserId: 'u1');
    expect(perms.canManageMembers, isTrue);
    expect(perms.canDelete('u2'), isTrue);
  });
}
```
- [ ] **Step 2: Run test to verify it fails** — `flutter test test/providers/permissions_provider_test.dart` — Expected: FAIL.
- [ ] **Step 3:** Implement `lib/providers/permissions_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'workspace_providers.dart';

class Permissions {
  final String? role;
  final String? currentUserId;
  Permissions({required this.role, required this.currentUserId});

  bool get canEdit => role != 'guest';
  bool get canInvite => role == 'owner' || role == 'member';
  bool get canManageMembers => role == 'owner';
  bool canDelete(String createdBy) =>
      role == 'owner' || (role == 'member' && createdBy == currentUserId);
}

final permissionsProvider = Provider<Permissions>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  return Permissions(role: membership?.role, currentUserId: membership?.userId);
});
```
- [ ] **Step 4: Run test to verify it passes** — `flutter test test/providers/permissions_provider_test.dart` — Expected: PASS.
- [ ] **Step 5:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 6: Commit**
```bash
git add flutter_app/lib/providers/permissions_provider.dart flutter_app/test/providers/permissions_provider_test.dart
git commit -m "Sprint 6: add permissions provider matching web RBAC rules"
```

---

### Sprint 7: Dashboard Screen

**Files:**
- Create: `flutter_app/lib/features/dashboard/dashboard_screen.dart`

**Interfaces:**
- Consumes: `tasksProvider` (defined in Sprint 9), `projectsProvider` (Sprint 8), `membersProvider` (Sprint 5) — all `.family` providers keyed by `activeWorkspaceIdProvider`.
- Produces: `DashboardScreen` widget mounted at the shell's Dashboard tab (Sprint 16).

- [ ] **Step 1:** Implement `lib/features/dashboard/dashboard_screen.dart` as a `ConsumerWidget`: a `CustomScrollView` with (a) a stats row (`Card`s: total tasks, in-progress, overdue, completed — computed by filtering the watched `tasksProvider` list), (b) an "Upcoming deadlines" list (tasks with `dueDate` in the next 7 days, sorted ascending), (c) a "Team workload" section (task count per assignee from `membersProvider`), each section handling the loading/error/data states of its `AsyncValue`.
- [ ] **Step 2:** Run `flutter analyze` — Expected: no errors (this task depends on Sprint 8/9 providers existing as declared in their Interfaces blocks; if implemented out of order, stub the two provider files with the signatures from Sprints 8/9 first).
- [ ] **Step 3: Commit**
```bash
git add flutter_app/lib/features/dashboard
git commit -m "Sprint 7: add dashboard screen with stats, deadlines, workload"
```

---

### Sprint 8: Projects Feature

**Files:**
- Create: `flutter_app/lib/providers/project_providers.dart`, `flutter_app/lib/features/projects/projects_list_screen.dart`, `project_detail_screen.dart`, `project_form_sheet.dart`

**Interfaces:**
- Consumes: `ProjectRepository` (Sprint 3), `permissionsProvider` (Sprint 6).
- Produces: `projectsProvider` (`StreamProvider.family<String, List<Project>>` keyed by workspace id, used by Sprint 7/9/10/12).

- [ ] **Step 1:** Implement `lib/providers/project_providers.dart`: `projectsProvider` wraps `ProjectRepository.streamForWorkspace`.
- [ ] **Step 2:** Implement `lib/features/projects/projects_list_screen.dart`: `GridView` of project cards (name, code, status badge via `widgets/status_badge.dart`, priority badge) built from `projectsProvider(activeWorkspaceId)`; tapping a card pushes `project_detail_screen.dart`; a FAB (visible only if `permissionsProvider.canEdit`) opens `project_form_sheet.dart` for create.
- [ ] **Step 3:** Implement `lib/features/projects/project_detail_screen.dart`: a `DefaultTabController` with tabs Overview / Tasks / Milestones / Sprints — Overview shows the project's fields; Tasks filters `tasksProvider` (Sprint 9) by `projectId`; Milestones/Sprints list from `MilestoneRepository`/`SprintRepository` (add these two repositories now, following the `ProjectRepository` pattern from Sprint 3, since they were scoped to "remaining repositories" there but not spelled out — add `lib/data/milestone_repository.dart` and `lib/data/sprint_repository.dart` with `listForProject(String projectId)`, `create`, `update`, `delete`).
- [ ] **Step 4:** Implement `lib/features/projects/project_form_sheet.dart`: a form with fields matching the `Project` model (name, code, description, department, client, pm, baTeam, status dropdown, priority dropdown, start/end date pickers, budget, color picker, tags input); submits via `ProjectRepository.create`/`update`.
- [ ] **Step 5:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 6: Commit**
```bash
git add flutter_app/lib/providers/project_providers.dart flutter_app/lib/features/projects flutter_app/lib/data/milestone_repository.dart flutter_app/lib/data/sprint_repository.dart
git commit -m "Sprint 8: add projects list, detail, and form"
```

---

### Sprint 9: Tasks Feature

**Files:**
- Create: `flutter_app/lib/providers/task_providers.dart`, `flutter_app/lib/features/tasks/tasks_list_screen.dart`, `task_detail_screen.dart`, `task_form_sheet.dart`

**Interfaces:**
- Consumes: `TaskRepository` (Sprint 3), `permissionsProvider` (Sprint 6), `projectsProvider` (Sprint 8, for the project picker in the task form).
- Produces: `tasksProvider` (`StreamProvider.family<String, List<Task>>` keyed by workspace id — consumed by Sprint 7, 10, 11, 12, 13).

- [ ] **Step 1:** Implement `lib/providers/task_providers.dart`: `tasksProvider` wraps `TaskRepository.streamForWorkspace`.
- [ ] **Step 2:** Implement `lib/features/tasks/tasks_list_screen.dart`: filterable/sortable `ListView` (filter chips: status, priority; sort menu: due date, priority, created) over `tasksProvider(activeWorkspaceId)`; each row shows title, status badge, priority badge, due date, assignee avatar; tapping pushes `task_detail_screen.dart`; a FAB (gated on `canEdit`) opens `task_form_sheet.dart`.
- [ ] **Step 3:** Implement `lib/features/tasks/task_detail_screen.dart`: full field display, a status `DropdownButton` (calls `TaskRepository.update` on change, gated on `canEdit`), a comments section backed by a new `lib/data/task_comment_repository.dart` (same CRUD pattern as `TaskRepository`, table `task_comments`, plus `streamForTask(String taskId)`), and a delete action gated on `permissionsProvider.canDelete(task.createdBy)`.
- [ ] **Step 4:** Implement `lib/features/tasks/task_form_sheet.dart`: form fields matching the `Task` model (title, description, project picker from `projectsProvider`, milestone/sprint pickers, priority, status, start/due date pickers, assignee picker from `membersProvider`, estimated hours, tags); submits via `TaskRepository.create`/`update`.
- [ ] **Step 5:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 6: Commit**
```bash
git add flutter_app/lib/providers/task_providers.dart flutter_app/lib/features/tasks flutter_app/lib/data/task_comment_repository.dart
git commit -m "Sprint 9: add tasks list, detail with comments, and form"
```

---

### Sprint 10: Kanban Feature

**Files:**
- Create: `flutter_app/lib/features/kanban/kanban_screen.dart`

**Interfaces:**
- Consumes: `tasksProvider` (Sprint 9), `permissionsProvider` (Sprint 6).

- [ ] **Step 1:** Implement `lib/features/kanban/kanban_screen.dart`: a horizontally-scrollable `Row` of 4 `DragTarget<Task>` columns (Pending / In Progress / Completed / Blocked), each populated by filtering `tasksProvider(activeWorkspaceId)` by `status`; each task rendered as a `LongPressDraggable<Task>` card (feedback: elevated copy of the card; child when dragging: reduced-opacity placeholder). On `DragTarget.onAcceptWithDetails`, call `TaskRepository.update(task.copyWith(status: newColumnStatus))` if `permissionsProvider.canEdit`, else no-op and show a toast explaining guests can't move tasks.
- [ ] **Step 2:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 3: Commit**
```bash
git add flutter_app/lib/features/kanban
git commit -m "Sprint 10: add kanban board with touch drag-and-drop"
```

---

### Sprint 11: Calendar Feature

**Files:**
- Create: `flutter_app/lib/features/calendar/calendar_screen.dart`

**Interfaces:**
- Consumes: `tasksProvider` (Sprint 9).

- [ ] **Step 1:** Implement `lib/features/calendar/calendar_screen.dart`: a monthly grid (`GridView.count(crossAxisCount: 7)`) built manually from `DateTime` math (no external calendar package needed for a single month-grid view) with month navigation arrows in the `AppBar`; each day cell shows a dot/count for tasks whose `dueDate` falls on that day (from `tasksProvider`); tapping a day opens a bottom sheet listing that day's tasks.
- [ ] **Step 2:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 3: Commit**
```bash
git add flutter_app/lib/features/calendar
git commit -m "Sprint 11: add monthly calendar view"
```

---

### Sprint 12: Gantt Feature

**Files:**
- Create: `flutter_app/lib/features/gantt/gantt_screen.dart`

**Interfaces:**
- Consumes: `tasksProvider` (Sprint 9), `projectsProvider` (Sprint 8).

- [ ] **Step 1:** No new dependency — Syncfusion does not publish a Flutter Gantt package (`syncfusion_flutter_gantt` does not exist on pub.dev; verified during implementation), so the Gantt view is a custom widget instead of a third-party one.
- [ ] **Step 2:** Implement `lib/features/gantt/gantt_screen.dart` as a custom horizontally-and-vertically scrollable timeline: a project picker in the `AppBar` (default: first project), a header row of date columns (one per day across the project's date span, `intl.DateFormat('MMM d')`), and one row per task rendered as a `Positioned` bar inside a fixed-width day-column `Stack`, spanning from `startDate` (or `createdAt` if null) to `dueDate`, colored by `priority`, with a `LinearProgressIndicator`-style fill for `progress`. Wrap the whole grid in a `SingleChildScrollView(scrollDirection: Axis.horizontal)` nested in a vertical `SingleChildScrollView`. Group rows by `milestoneId` with a section header where present.
- [ ] **Step 3:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 4: Commit**
```bash
git add flutter_app/pubspec.yaml flutter_app/pubspec.lock flutter_app/lib/features/gantt
git commit -m "Sprint 12: add gantt timeline view"
```

---

### Sprint 13: Analytics Feature

**Files:**
- Create: `flutter_app/lib/features/analytics/analytics_screen.dart`

**Interfaces:**
- Consumes: `tasksProvider` (Sprint 9), `membersProvider` (Sprint 5).

- [ ] **Step 1:** Implement `lib/features/analytics/analytics_screen.dart` using `fl_chart`: a `PieChart` for status distribution, a `PieChart` for priority distribution, and a horizontal `BarChart` for workload-per-member (task count grouped by `assigneeId`, matched to `membersProvider` display names) — all derived by aggregating the currently-watched `tasksProvider(activeWorkspaceId)` list client-side (same computation `js/ui/analytics.js` does over `state.tasks`).
- [ ] **Step 2:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 3: Commit**
```bash
git add flutter_app/lib/features/analytics
git commit -m "Sprint 13: add analytics charts for status/priority/workload"
```

---

### Sprint 14: Team, Notifications, Search Sheet

**Files:**
- Create: `flutter_app/lib/providers/notification_providers.dart`, `flutter_app/lib/features/team/team_screen.dart`, `flutter_app/lib/features/notifications/notifications_screen.dart`, `flutter_app/lib/features/shell/search_sheet.dart`

**Interfaces:**
- Consumes: `membersProvider` (Sprint 5), `NotificationRepository` (Sprint 3), `tasksProvider`/`projectsProvider` (Sprints 8/9), `permissionsProvider` (Sprint 6).
- Produces: `notificationsProvider` (`StreamProvider.family<String, List<AppNotification>>` keyed by user id), `unreadNotificationCountProvider` (`Provider<int>`, used by the shell's bell badge in Sprint 16).

- [ ] **Step 1:** Implement `lib/providers/notification_providers.dart`: `notificationsProvider` wraps `NotificationRepository.streamForUser`; `unreadNotificationCountProvider` derives `.where((n) => !n.read).length` from it.
- [ ] **Step 2:** Implement `lib/features/team/team_screen.dart`: reuses `membersProvider`; member cards show avatar (via `avatarPreset`/`avatarUrl`), display name, role badge, skills chips; tapping a card (self, or any card if `canManageMembers`) opens an edit sheet for `displayName`/`avatarPreset`/`color`/`skills`, saved via `MemberRepository.updateProfile`.
- [ ] **Step 3:** Implement `lib/features/notifications/notifications_screen.dart`: `ListView` over `notificationsProvider(currentUserId)`, unread rows highlighted, tapping marks read via `NotificationRepository.markRead` and, if the notification references a `taskId`, pushes `task_detail_screen.dart`.
- [ ] **Step 4:** Implement `lib/features/shell/search_sheet.dart` (replaces the web's Ctrl/⌘+K command palette per spec §3): a full-screen modal with a search `TextField` that fuzzy-filters the combined `tasksProvider`/`projectsProvider` lists by title/name as the user types, each result navigable to its detail screen.
- [ ] **Step 5:** Run `flutter analyze` — Expected: no errors.
- [ ] **Step 6: Commit**
```bash
git add flutter_app/lib/providers/notification_providers.dart flutter_app/lib/features/team flutter_app/lib/features/notifications flutter_app/lib/features/shell/search_sheet.dart
git commit -m "Sprint 14: add team, notifications, and search sheet"
```

---

### Sprint 15: App Shell — Bottom Nav, More Drawer, Final Router Wiring

**Files:**
- Create: `flutter_app/lib/features/shell/app_shell.dart`
- Modify: `flutter_app/lib/core/router.dart`

**Interfaces:**
- Consumes: every screen widget from Sprints 4–14; `unreadNotificationCountProvider` (Sprint 14); `activeWorkspaceProvider` (Sprint 5).

- [ ] **Step 1:** Implement `lib/features/shell/app_shell.dart`: a `StatefulShellRoute`-driven scaffold (via `go_router`'s `StatefulShellRoute.indexedStack`) with a `NavigationBar` (Dashboard, Projects, Tasks, Kanban, Notifications-with-badge) and an `AppBar` leading widget that opens `workspace_switcher_sheet.dart` (shows `activeWorkspaceProvider`'s name) plus a trailing "More" `IconButton` opening a bottom sheet listing Calendar, Gantt, Analytics, Team, Members, Invite, and a search `IconButton` opening `search_sheet.dart`.
- [ ] **Step 2:** Replace the placeholder `/` route in `lib/core/router.dart` with the full route tree: a `StatefulShellRoute` wrapping `AppShell`, with branches `/dashboard`, `/projects` (+ `/projects/:id` detail), `/tasks` (+ `/tasks/:id`), `/kanban`, `/notifications`, and top-level (non-tab) pushes for `/calendar`, `/gantt`, `/analytics`, `/team`, `/members`.
- [ ] **Step 3:** Run `flutter analyze` on the whole project — Expected: no errors across all files from Sprints 1–15.
- [ ] **Step 4:** Run `flutter test` (full suite) — Expected: all tests PASS.
- [ ] **Step 5: Commit**
```bash
git add flutter_app/lib/features/shell/app_shell.dart flutter_app/lib/core/router.dart
git commit -m "Sprint 15: wire app shell with bottom nav, more drawer, and full routing"
```

---

### Sprint 16: Final Verification and Merge to Main

**Files:** none created; verification + git operations only.

- [ ] **Step 1:** From `flutter_app/`, run `flutter pub get` (clean dependency resolution check).
- [ ] **Step 2:** Run `flutter analyze` — Expected: "No issues found!". If issues remain, fix them in the relevant Sprint's files and re-run until clean.
- [ ] **Step 3:** Run `flutter test` — Expected: all tests from Sprints 2, 3, 4, 6 (and any added along the way) PASS. If any fail, fix the implementation (not the test, unless the test itself is wrong) and re-run until green.
- [ ] **Step 4:** Run `flutter build apk --debug` (Android) as a full-toolchain smoke check that the app compiles end-to-end. If unavailable in the current environment (no Android SDK), note this explicitly rather than skipping silently, and rely on `flutter analyze` + `flutter test` as the verification bar.
- [ ] **Step 5:** Confirm current branch state with `git status` and `git log --oneline -20` — all 15 prior sprint commits should be present.
- [ ] **Step 6:** Switch to `main` and bring the Flutter app work in:
```bash
git checkout main
git merge --no-ff dev -m "Merge Flutter mobile app (Sprints 1-15) into main"
```
- [ ] **Step 7:** Run `git log --oneline -5` on `main` to confirm the merge commit and sprint history are present.
