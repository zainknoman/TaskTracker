import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workspace_providers.dart';

class Permissions {
  final String? role;
  final String? currentUserId;
  Permissions({required this.role, required this.currentUserId});

  bool get canEdit => role != 'guest';
  bool get canInvite => role == 'owner' || role == 'member';
  bool get canManageMembers => role == 'owner';
  bool canDelete(String createdBy) => role == 'owner' || (role == 'member' && createdBy == currentUserId);
}

final permissionsProvider = Provider<Permissions>((ref) {
  final membership = ref.watch(activeMembershipProvider);
  return Permissions(role: membership?.role, currentUserId: membership?.userId);
});
