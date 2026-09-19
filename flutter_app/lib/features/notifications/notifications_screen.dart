import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/tokens.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_layout.dart';
import '../../widgets/view_header.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null) {
      return const EmptyState(
        icon: Icons.notifications_none,
        message: 'Not signed in',
      );
    }

    final notificationsAsync = ref.watch(notificationsProvider(userId));

    return notificationsAsync.when(
      data: (notifications) {
        final unread = notifications.where((n) => !n.read).length;
        return ListView(
          padding: pagePadding(context),
          children: [
            ViewHeader(
              title: 'Notifications',
              subtitle: unread > 0 ? '$unread unread' : 'You are all caught up',
            ),
            if (notifications.isEmpty)
              const AppCard(
                child: EmptyState(
                  icon: Icons.notifications_none,
                  message: 'No notifications yet',
                ),
              )
            else
              AppCard(
                child: Column(
                  children: [
                    for (final (i, n) in notifications.indexed)
                      InkWell(
                        onTap: () async {
                          if (!n.read) {
                            await ref
                                .read(notificationRepositoryProvider)
                                .markRead(n.id);
                          }
                          if (n.taskId != null && context.mounted) {
                            context.push('/tasks/${n.taskId}');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: n.read
                                ? null
                                : Brand.primary.withValues(alpha: .06),
                            border: i == notifications.length - 1
                                ? null
                                : Border(bottom: BorderSide(color: c.border)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: n.read
                                      ? c.surface2
                                      : Brand.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  n.read
                                      ? Icons.notifications_none
                                      : Icons.notifications_active,
                                  size: 16,
                                  color: n.read ? c.text3 : Brand.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: TextStyle(
                                        fontSize: rem(0.85),
                                        fontWeight: n.read
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                        color: c.text,
                                      ),
                                    ),
                                    if (n.body != null && n.body!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          n.body!,
                                          style: TextStyle(
                                            fontSize: rem(0.8),
                                            color: c.text2,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        DateFormat('d MMM yyyy, HH:mm')
                                            .format(n.createdAt.toLocal()),
                                        style: TextStyle(
                                          fontSize: rem(0.72),
                                          color: c.text3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!n.read)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, left: 8),
                                  child: ColorDot(Brand.primary),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(e),
    );
  }
}
