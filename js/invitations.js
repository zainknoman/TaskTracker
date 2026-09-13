import { sb } from './supabase.js';
import { state, addEntity } from './state.js';

export async function createInvitation(workspaceId, invitedBy, role, label) {
  const token = crypto.randomUUID();
  const expires_at = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await sb.from('invitations')
    .insert({ workspace_id: workspaceId, invited_by: invitedBy, token, role, label, expires_at })
    .select().single();
  if (error) throw error;
  return data;
}

export async function acceptInvitation(token, userId) {
  const { data, error } = await sb.rpc('accept_invitation', {
    p_token:   token,
    p_user_id: userId,
  });
  if (error) throw error;
  return data; // { workspace_id, workspace_name }
}

export async function cancelInvitation(invitationId) {
  const { error } = await sb.from('invitations')
    .update({ status: 'cancelled' }).eq('id', invitationId);
  if (error) throw error;
}

export async function listInvitations(workspaceId) {
  const { data, error } = await sb.from('invitations')
    .select('*').eq('workspace_id', workspaceId).order('created_at', { ascending: false });
  if (error) throw error;
  return data;
}