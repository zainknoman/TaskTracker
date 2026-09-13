
import { sb } from './supabase.js';
import { state } from './state.js';

// Load all workspace data in parallel
export async function loadWorkspaceData(workspaceId) {
  const [proj, tasks, ms, sp, members] = await Promise.all([
    sb.from('tt_projects').select('*').eq('workspace_id', workspaceId).order('created_at'),
    sb.from('tasks').select('*').eq('workspace_id', workspaceId).order('created_at'),
    sb.from('milestones').select('*').eq('workspace_id', workspaceId).order('sort_order'),
    sb.from('sprints').select('*').eq('workspace_id', workspaceId).order('created_at'),
    sb.from('workspace_members').select('*').eq('workspace_id', workspaceId),
  ]);
  for (const r of [proj, tasks, ms, sp, members]) if (r.error) throw r.error;
  return {
    projects:   proj.data,
    tasks:      tasks.data,
    milestones: ms.data,
    sprints:    sp.data,
    members:    members.data,
  };
}

// Projects
export async function saveProject(project) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id: workspaceId,
    name:         project.name,
    code:         project.code || null,
    description:  project.description || null,
    department:   project.department || null,
    client:       project.client || null,
    pm:           project.pm || null,
    ba_team:      project.ba_team || [],
    status:       project.status || 'active',
    priority:     project.priority || 'medium',
    start_date:   project.start_date || null,
    end_date:     project.end_date || null,
    budget:       project.budget || null,
    color:        project.color || '#2563eb',
    tags:         project.tags || [],
    updated_at:   new Date().toISOString(),
  };
  if (project.id) {
    const { error } = await sb.from('tt_projects').update(payload).eq('id', project.id);
    if (error) throw error;
    return project;
  } else {
    const { data, error } = await sb.from('tt_projects')
      .insert({ ...payload, created_by: state.currentUser.id })
      .select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteProject(id) {
  const { error } = await sb.from('tt_projects').delete().eq('id', id);
  if (error) throw error;
}

// Tasks
export async function saveTask(task) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id:   workspaceId,
    project_id:     task.project_id,
    milestone_id:   task.milestone_id || null,
    sprint_id:      task.sprint_id || null,
    parent_task_id: task.parent_task_id || null,
    title:          task.title,
    description:    task.description || null,
    priority:       task.priority || 'medium',
    status:         task.status || 'pending',
    start_date:     task.start_date || null,
    due_date:       task.due_date || null,
    ba:             task.ba || null,
    assignee_id:    task.assignee_id || null,
    estimated_hours: task.estimated_hours || null,
    actual_hours:   task.actual_hours || null,
    progress:       task.progress || 0,
    tags:           task.tags || [],
    documents:      task.documents || [],
    dependencies:   task.dependencies || [],
    subtasks:       task.subtasks || [],
    notes:          task.notes || null,
    starred:        task.starred || false,
    pinned:         task.pinned || false,
    updated_at:     new Date().toISOString(),
  };
  if (task.id) {
    const { error } = await sb.from('tasks').update(payload).eq('id', task.id);
    if (error) throw error;
    return task;
  } else {
    const { data, error } = await sb.from('tasks')
      .insert({ ...payload, created_by: state.currentUser.id })
      .select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteTask(id) {
  const { error } = await sb.from('tasks').delete().eq('id', id);
  if (error) throw error;
}

// Milestones
export async function saveMilestone(milestone) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id: workspaceId,
    project_id:   milestone.project_id,
    name:         milestone.name,
    description:  milestone.description || null,
    due_date:     milestone.due_date || null,
    status:       milestone.status || 'pending',
    sort_order:   milestone.sort_order || 0,
  };
  if (milestone.id) {
    const { error } = await sb.from('milestones').update(payload).eq('id', milestone.id);
    if (error) throw error;
    return milestone;
  } else {
    const { data, error } = await sb.from('milestones').insert(payload).select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteMilestone(id) {
  const { error } = await sb.from('milestones').delete().eq('id', id);
  if (error) throw error;
}

// Sprints
export async function saveSprint(sprint) {
  const workspaceId = state.activeWorkspaceId;
  const payload = {
    workspace_id: workspaceId,
    project_id:   sprint.project_id,
    name:         sprint.name,
    goal:         sprint.goal || null,
    start_date:   sprint.start_date || null,
    end_date:     sprint.end_date || null,
    status:       sprint.status || 'planning',
    velocity:     sprint.velocity || null,
  };
  if (sprint.id) {
    const { error } = await sb.from('sprints').update(payload).eq('id', sprint.id);
    if (error) throw error;
    return sprint;
  } else {
    const { data, error } = await sb.from('sprints').insert(payload).select().single();
    if (error) throw error;
    return data;
  }
}

export async function deleteSprint(id) {
  const { error } = await sb.from('sprints').delete().eq('id', id);
  if (error) throw error;
}

// Workspace members
export async function updateMember(memberId, updates) {
  const { error } = await sb.from('workspace_members').update(updates).eq('id', memberId);
  if (error) throw error;
}

export async function removeMember(memberId) {
  const { error } = await sb.from('workspace_members').delete().eq('id', memberId);
  if (error) throw error;
}

// Task comments
export async function loadTaskComments(taskId) {
  const { data, error } = await sb.from('task_comments')
    .select('*, author:author_id(id, email)')
    .eq('task_id', taskId)
    .order('created_at');
  if (error) throw error;
  return data;
}

export async function saveTaskComment(taskId, content) {
  const { data, error } = await sb.from('task_comments')
    .insert({ task_id: taskId, workspace_id: state.activeWorkspaceId, author_id: state.currentUser.id, content })
    .select().single();
  if (error) throw error;
  return data;
}

export async function deleteTaskComment(commentId) {
  const { error } = await sb.from('task_comments').delete().eq('id', commentId);
  if (error) throw error;
}

// Task activity
export async function loadTaskActivity(taskId) {
  const { data, error } = await sb.from('task_activity')
    .select('*')
    .eq('task_id', taskId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data;
}

export async function logTaskActivity(taskId, action, oldValue, newValue, description) {
  const { error } = await sb.from('task_activity').insert({
    workspace_id: state.activeWorkspaceId,
    task_id:      taskId,
    actor_id:     state.currentUser.id,
    action, old_value: oldValue, new_value: newValue, description,
  });
  if (error) throw error;
}