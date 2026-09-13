import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_repository.dart';
import '../models/project.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) => ProjectRepository());

final projectsProvider = StreamProvider.family<List<Project>, String>((ref, workspaceId) {
  return ref.watch(projectRepositoryProvider).streamForWorkspace(workspaceId);
});
