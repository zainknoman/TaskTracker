import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exceptions.dart';
import '../../data/invitation_repository.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_toast.dart';

final _invitationRepositoryProvider = Provider<InvitationRepository>((ref) => InvitationRepository());

class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const InviteSheet(),
    );
  }

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  String _role = 'member';
  String? _inviteLink;
  bool _loading = false;

  Future<void> _generate() async {
    final workspaceId = ref.read(activeWorkspaceIdProvider);
    if (workspaceId == null) return;
    setState(() => _loading = true);
    try {
      final invitation = await ref.read(_invitationRepositoryProvider).create(workspaceId, _role);
      setState(() => _inviteLink = '?invite=${invitation.token}');
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invite a member', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(value: 'guest', child: Text('Guest')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'member'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Generate invite link'),
            ),
            if (_inviteLink != null) ...[
              const SizedBox(height: 16),
              SelectableText(_inviteLink!),
            ],
          ],
        ),
      ),
    );
  }
}
