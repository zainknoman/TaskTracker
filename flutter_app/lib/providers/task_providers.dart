import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/task_repository.dart';
import '../models/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) => TaskRepository());

final tasksProvider = StreamProvider.family<List<Task>, String>((ref, workspaceId) {
  return ref.watch(taskRepositoryProvider).streamForWorkspace(workspaceId);
});
