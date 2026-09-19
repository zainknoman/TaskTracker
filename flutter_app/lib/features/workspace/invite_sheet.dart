import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens.dart';
import '../../data/exceptions.dart';
import '../../data/invitation_repository.dart';
import '../../providers/workspace_providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_form.dart';
import '../../widgets/app_toast.dart';

final _invitationRepositoryProvider = Provider<InvitationRepository>(
  (ref) => InvitationRepository(),
);

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
      final invitation = await ref
          .read(_invitationRepositoryProvider)
          .create(workspaceId, _role);
      setState(() => _inviteLink = '?invite=${invitation.token}');
    } on AppException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SheetScaffold(
      title: 'Invite a Member',
      footer: [
        AppButton.secondary(
          'Close',
          onPressed: () => Navigator.maybePop(context),
        ),
        AppButton(
          'Generate Invite Link',
          onPressed: _generate,
          loading: _loading,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdown<String>(
            label: 'Role',
            value: _role,
            items: const [
              DropdownMenuItem(value: 'member', child: Text('Member')),
              DropdownMenuItem(value: 'guest', child: Text('Guest')),
            ],
            onChanged: (v) => setState(() => _role = v ?? 'member'),
          ),
          if (_inviteLink != null) ...[
            const SizedBox(height: 14),
            const FormLabel('Invite Link'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: Radii.smAll,
                border: Border.all(color: c.border),
              ),
              child: SelectableText(
                _inviteLink!,
                style: TextStyle(fontSize: rem(0.85), color: Brand.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
