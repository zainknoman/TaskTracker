import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workspace_repository.dart';
import '../models/workspace.dart';
import 'auth_providers.dart';
import 'member_providers.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) => WorkspaceRepository());

final workspaceListProvider = FutureProvider<List<Workspace>>((ref) async {
  ref.watch(currentUserProvider);
  return ref.watch(workspaceRepositoryProvider).listForUser();
});

final activeWorkspaceIdProvider = StateProvider<String?>((ref) {
  final workspaces = ref.watch(workspaceListProvider).value;
  if (workspaces != null && workspaces.isNotEmpty) return workspaces.first.id;
  return null;
});

final activeWorkspaceProvider = Provider<Workspace?>((ref) {
  final workspaces = ref.watch(workspaceListProvider).value ?? [];
  final activeId = ref.watch(activeWorkspaceIdProvider);
  if (activeId == null) return null;
  for (final w in workspaces) {
    if (w.id == activeId) return w;
  }
  return workspaces.isNotEmpty ? workspaces.first : null;
});

final activeMembershipProvider = Provider((ref) {
  final activeId = ref.watch(activeWorkspaceIdProvider);
  final currentUser = ref.watch(currentUserProvider);
  if (activeId == null || currentUser == null) return null;
  final members = ref.watch(membersProvider(activeId)).value ?? [];
  for (final m in members) {
    if (m.userId == currentUser.id) return m;
  }
  return null;
});
