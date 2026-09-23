import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/supabase_config.dart';
import '../models/project.dart';
import '../models/task.dart';
import 'project_repository.dart';
import 'task_repository.dart';

class TaskTransferService {
  final TaskRepository taskRepository;
  final ProjectRepository projectRepository;

  TaskTransferService({
    TaskRepository? taskRepository,
    ProjectRepository? projectRepository,
  })  : taskRepository = taskRepository ?? TaskRepository(),
        projectRepository = projectRepository ?? ProjectRepository();

  Future<void> exportTask(Task task, {Project? project}) async {
    final payload = {
      'exportType': 'taskflow-task',
      'formatVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'workspaceId': task.workspaceId,
      'task': task.toJson(),
      'project': project == null
          ? null
          : {'id': project.id, 'name': project.name, 'code': project.code},
    };
    await _shareJson(payload, 'taskflow_task_${task.id}.json');
  }

  Future<void> exportProject(Project project, List<Task> tasks) async {
    final payload = {
      'exportType': 'taskflow-project',
      'formatVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'workspaceId': project.workspaceId,
      'project': project.toJson(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
    await _shareJson(payload, 'taskflow_project_${project.code.isNotEmpty ? project.code : project.id}.json');
  }

  Future<void> exportWorkspace(String workspaceId) async {
    final projects = await projectRepository.listForWorkspace(workspaceId);
    final tasks = await taskRepository.listForWorkspace(workspaceId);
    final payload = {
      'exportType': 'taskflow-workspace',
      'formatVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'workspaceId': workspaceId,
      'projects': projects.map((p) => p.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
    await _shareJson(payload, 'taskflow_workspace.json');
  }

  Future<Task?> importTask(String workspaceId, String currentUserId) async {
    final file = await FilePicker.platform.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic> ||
        data['exportType'] != 'taskflow-task' ||
        data['formatVersion'] != 1 ||
        data['task'] is! Map) {
      throw const FormatException('Only TaskFlow Pro task JSON exports can be imported.');
    }

    final source = Map<String, dynamic>.from(data['task'] as Map);
    final projects = await projectRepository.listForWorkspace(workspaceId);
    final sourceProject = data['project'] is Map
        ? Map<String, dynamic>.from(data['project'] as Map)
        : null;

    Project? matched;
    if (sourceProject != null) {
      for (final p in projects) {
        if (p.id == sourceProject['id'] ||
            (sourceProject['code'] != null &&
                sourceProject['code'].toString().isNotEmpty &&
                p.code == sourceProject['code']) ||
            p.name == sourceProject['name']) {
          matched = p;
          break;
        }
      }
    }

    final imported = <String, dynamic>{
      ...source,
      'id': const Uuid().v4(),
      'workspace_id': workspaceId,
      'project_id': matched?.id ?? source['project_id'],
      'parent_task_id': null,
      'dependencies': <dynamic>[],
      'created_by': currentUserId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final saved = await taskRepository.create(Task.fromJson(imported));
    return saved;
  }

  Future<void> _shareJson(Map<String, dynamic> payload, String filename) async {
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = Uint8List.fromList(utf8.encode(json));
    final file = XFile.fromData(bytes, mimeType: 'application/json');
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [filename],
        downloadFallbackEnabled: true,
      ),
    );
  }
}
