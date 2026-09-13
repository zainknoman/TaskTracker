import 'package:flutter_test/flutter_test.dart';
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
