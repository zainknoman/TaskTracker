import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import '../models/notification.dart';
import 'auth_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => NotificationRepository());

final notificationsProvider = StreamProvider.family<List<AppNotification>, String>((ref, userId) {
  return ref.watch(notificationRepositoryProvider).streamForUser(userId);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return 0;
  final notifications = ref.watch(notificationsProvider(userId)).value ?? [];
  return notifications.where((n) => !n.read).length;
});
