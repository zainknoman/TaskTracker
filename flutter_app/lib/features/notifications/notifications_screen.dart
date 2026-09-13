import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null) {
      return const Scaffold(body: EmptyState(icon: Icons.notifications_none, message: 'Not signed in'));
    }

    final notificationsAsync = ref.watch(notificationsProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(icon: Icons.notifications_none, message: 'No notifications yet');
          }
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return ListTile(
                tileColor: n.read ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active),
                title: Text(n.message),
                subtitle: Text(n.createdAt.toLocal().toString()),
                onTap: () async {
                  if (!n.read) {
                    await ref.read(notificationRepositoryProvider).markRead(n.id);
                  }
                  if (n.taskId != null && context.mounted) {
                    context.push('/tasks/${n.taskId}');
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
