import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/member_repository.dart';
import '../models/workspace_member.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) => MemberRepository());

// FutureProvider, not StreamProvider: workspace_members has no Realtime
// replication enabled on this Supabase project (see readme.md "Database ->
// How to access the database" and js/realtime.js, which only subscribes to
// tasks/projects/milestones/sprints/notifications). Callers that mutate
// members must ref.invalidate(membersProvider(workspaceId)) afterwards.
final membersProvider = FutureProvider.family<List<WorkspaceMember>, String>((ref, workspaceId) {
  return ref.watch(memberRepositoryProvider).listForWorkspace(workspaceId);
});
