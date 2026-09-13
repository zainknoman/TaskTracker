import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/member_repository.dart';
import '../models/workspace_member.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) => MemberRepository());

final membersProvider = StreamProvider.family<List<WorkspaceMember>, String>((ref, workspaceId) {
  return ref.watch(memberRepositoryProvider).streamForWorkspace(workspaceId);
});
