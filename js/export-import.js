import { state, findProject, findTask, setState } from './state.js';
import { saveProject, saveTask, saveMilestone, saveSprint } from './storage.js';
import { today, uid, toast } from './utils.js';

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function downloadJSON(data, filename) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function exportPayload(exportType, data) {
  return {
    exportType,
    formatVersion: 1,
    exportedAt: new Date().toISOString(),
    workspaceId: state.activeWorkspaceId,
    ...data,
  };
}

export function exportWorkspaceJSON() {
  const data = exportPayload('taskflow-workspace', {
    projects: clone(state.projects),
    tasks: clone(state.tasks),
    milestones: clone(state.milestones),
    sprints: clone(state.sprints),
  });
  downloadJSON(data, 'taskflow_workspace.json');
  toast(`Exported ${state.projects.length} projects and ${state.tasks.length} tasks`, 'success');
}

export function exportProjectJSON(projectId) {
  const project = findProject(projectId);
  if (!project) return;
  const tasks = state.tasks.filter(t => t.project_id === projectId);
  const data = exportPayload('taskflow-project', {
    project: clone(project),
    tasks: clone(tasks),
    milestones: clone(state.milestones.filter(m => m.project_id === projectId)),
    sprints: clone(state.sprints.filter(s => s.project_id === projectId)),
  });
  downloadJSON(data, `taskflow_project_${project.code || project.id}.json`);
  toast(`Exported project "${project.name}" with ${tasks.length} tasks`, 'success');
}

export function exportTaskJSON(taskId) {
  const task = findTask(taskId);
  if (!task) return;
  const project = task.project_id ? findProject(task.project_id) : null;
  const data = exportPayload('taskflow-task', {
    task: clone(task),
    project: project ? { id: project.id, name: project.name, code: project.code || '' } : null,
  });
  downloadJSON(data, `taskflow_task_${task.id}.json`);
  toast(`Exported task "${task.title}"`, 'success');
}

function readJSON(file) {
  return new Promise((resolve, reject) => {
    if (!file || !/\\.json$/i.test(file.name)) {
      reject(new Error('Only .json files are allowed'));
      return;
    }
    const reader = new FileReader();
    reader.onload = e => {
      try { resolve(JSON.parse(e.target.result)); }
      catch { reject(new Error('The selected file is not valid JSON')); }
    };
    reader.onerror = () => reject(new Error('Unable to read the selected file'));
    reader.readAsText(file);
  });
}

function validateTaskExport(data) {
  if (data?.exportType !== 'taskflow-task' || data?.formatVersion !== 1 ||
      !data.task || typeof data.task !== 'object' || Array.isArray(data.task)) {
    throw new Error('This is not a valid TaskFlow Pro task export');
  }
}

function matchProject(sourceProject) {
  if (!sourceProject) return null;
  return state.projects.find(p => p.id === sourceProject.id) ||
    state.projects.find(p => sourceProject.code && p.code === sourceProject.code) ||
    state.projects.find(p => sourceProject.name && p.name === sourceProject.name) ||
    null;
}

export async function importTaskJSON(file, refresh) {
  try {
    const data = await readJSON(file);
    validateTaskExport(data);
    const source = clone(data.task);
    const project = matchProject(data.project);

    const task = {
      ...source,
      id: undefined,
      project_id: project?.id || null,
      parent_task_id: null,
      dependencies: [],
      created_by: undefined,
      created_at: undefined,
      updated_at: undefined,
    };
    delete task.id;
    delete task.created_by;
    delete task.created_at;
    delete task.updated_at;
    task.progress = Array.isArray(task.subtasks) && task.subtasks.length
      ? Math.round(task.subtasks.filter(s => s?.done).length / task.subtasks.length * 100)
      : (task.progress || 0);

    const saved = await saveTask(task);
    state.tasks.unshift(saved);
    refresh?.();
    toast(project ? `Imported "${saved.title}" into ${project.name}` : `Imported "${saved.title}" without a project`, 'success');
  } catch (e) {
    toast('Import failed: ' + e.message, 'error');
  }
}

export async function importWorkspaceJSON(file, refresh) {
  try {
    const data = await readJSON(file);
    if (data?.exportType !== 'taskflow-workspace' || data?.formatVersion !== 1 ||
        !Array.isArray(data.projects) || !Array.isArray(data.tasks)) {
      throw new Error('This is not a valid TaskFlow Pro workspace export');
    }

    const projectMap = new Map();
    const milestoneMap = new Map();
    const sprintMap = new Map();
    const taskMap = new Map();

    for (const source of data.projects) {
      const saved = await saveProject({ ...clone(source), id: undefined });
      projectMap.set(source.id, saved.id);
      state.projects.push(saved);
    }

    for (const source of (data.milestones || [])) {
      const saved = await saveMilestone({
        ...clone(source),
        id: undefined,
        project_id: projectMap.get(source.project_id) || null,
      });
      milestoneMap.set(source.id, saved.id);
      state.milestones.push(saved);
    }

    for (const source of (data.sprints || [])) {
      const saved = await saveSprint({
        ...clone(source),
        id: undefined,
        project_id: projectMap.get(source.project_id) || null,
      });
      sprintMap.set(source.id, saved.id);
      state.sprints.push(saved);
    }

    for (const source of data.tasks) {
      const raw = clone(source);
      const saved = await saveTask({
        ...raw,
        id: undefined,
        project_id: projectMap.get(source.project_id) || null,
        milestone_id: milestoneMap.get(source.milestone_id) || null,
        sprint_id: sprintMap.get(source.sprint_id) || null,
        parent_task_id: taskMap.get(source.parent_task_id) || null,
        dependencies: Array.isArray(source.dependencies)
          ? source.dependencies.map(id => taskMap.get(id)).filter(Boolean)
          : [],
        created_by: undefined,
        created_at: undefined,
        updated_at: undefined,
      });
      taskMap.set(source.id, saved.id);
      state.tasks.push(saved);
    }

    refresh?.();
    toast(`Imported ${data.projects.length} projects and ${data.tasks.length} tasks`, 'success');
  } catch (e) {
    toast('Import failed: ' + e.message, 'error');
  }
}

export function bindExportImport({ refresh }) {
  document.getElementById('exportJsonBtn')?.addEventListener('click', e => {
    e.preventDefault();
    exportWorkspaceJSON();
  });
  document.getElementById('importJsonBtn')?.addEventListener('click', e => {
    e.preventDefault();
    document.getElementById('workspaceImportFile')?.click();
  });
  document.getElementById('workspaceImportFile')?.addEventListener('change', e => {
    const file = e.target.files?.[0];
    if (file) importWorkspaceJSON(file, refresh);
    e.target.value = '';
  });

  document.getElementById('exportProjectsBtn')?.addEventListener('click', () => {
    const status = document.getElementById('projectStatusFilter')?.value || '';
    const projects = status ? state.projects.filter(p => p.status === status) : state.projects;
    const data = exportPayload('taskflow-projects', {
      projects: clone(projects),
      tasks: clone(state.tasks),
      milestones: clone(state.milestones),
      sprints: clone(state.sprints),
    });
    downloadJSON(data, 'taskflow_projects.json');
    toast(`Exported ${projects.length} projects`, 'success');
  });

  ['importTasksBtn', 'importTaskFromProjectsBtn'].forEach(id => {
    document.getElementById(id)?.addEventListener('click', () =>
      document.getElementById('taskImportFile')?.click()
    );
  });
  document.getElementById('taskImportFile')?.addEventListener('change', e => {
    const file = e.target.files?.[0];
    if (file) importTaskJSON(file, refresh);
    e.target.value = '';
  });
}
