
import { sb } from './supabase.js';
import { state, setState } from './state.js';
import { loadWorkspaceData } from './storage.js';

function slugify(name) {
  const base = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const suffix = Math.random().toString(36).slice(2, 6);
  return `${base}-${suffix}`;
}

export async function listWorkspaces(userId) {
  const { data, error } = await sb
    .from('workspace_members')
    .select('workspace_id, role, workspaces(*)')
    .eq('user_id', userId);
  if (error) throw error;
  return data.map(row => ({ ...row.workspaces, myRole: row.role }));
}

export async function createWorkspace(name, userId) {
  const slug = slugify(name);
  const { data: ws, error: wsErr } = await sb
    .from('workspaces')
    .insert({ name, slug, owner_id: userId })
    .select().single();
  if (wsErr) throw wsErr;

  const { error: memErr } = await sb.from('workspace_members').insert({
    workspace_id: ws.id,
    user_id:      userId,
    role:         'owner',
    display_name: null,
  });
  if (memErr) throw memErr;
  return ws;
}

export async function loadWorkspace(workspaceId) {
  const data = await loadWorkspaceData(workspaceId);
  const currentMember = data.members.find(m => m.user_id === state.currentUser?.id) || null;
  setState({
    activeWorkspaceId: workspaceId,
    currentMember,
    projects:   data.projects,
    tasks:      data.tasks,
    milestones: data.milestones,
    sprints:    data.sprints,
    members:    data.members,
  });
}

export async function updateWorkspace(workspaceId, updates) {
  const { error } = await sb.from('workspaces')
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq('id', workspaceId);
  if (error) throw error;
}