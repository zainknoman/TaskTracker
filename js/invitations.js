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
  // Look up invitation
  const { data: inv, error: fetchErr } = await sb
    .from('invitations').select('*, workspaces(name)').eq('token', token).maybeSingle();
  if (fetchErr) throw fetchErr;
  if (!inv) throw new Error('Invite link not found');
  if (inv.status !== 'pending') throw new Error('This invite link has already been used or cancelled');
  if (new Date(inv.expires_at) < new Date()) throw new Error('This invite link has expired');

  // Check if already a member
  const { data: existing } = await sb.from('workspace_members')
    .select('id').eq('workspace_id', inv.workspace_id).eq('user_id', userId).maybeSingle();
  if (existing) {
    // Already a member — mark invite as accepted and return
    await sb.from('invitations').update({ status: 'accepted', accepted_by: userId }).eq('id', inv.id);
    return { workspace_id: inv.workspace_id, workspace_name: inv.workspaces?.name };
  }

  // Add member
  const { error: memErr } = await sb.from('workspace_members').insert({
    workspace_id: inv.workspace_id,
    user_id:      userId,
    role:         inv.role,
  });
  if (memErr) throw memErr;

  // Mark invite accepted
  await sb.from('invitations').update({ status: 'accepted', accepted_by: userId }).eq('id', inv.id);

  return { workspace_id: inv.workspace_id, workspace_name: inv.workspaces?.name };
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