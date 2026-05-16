
import { state, setState } from '../state.js';
import { $id, esc, toast } from '../utils.js';
import { loadWorkspace } from '../workspace.js';
import { createInvitation, cancelInvitation, listInvitations } from '../invitations.js';
import { canInvite, canManageMembers } from '../permissions.js';
import { removeMember } from '../storage.js';
import { removeEntity } from '../state.js';

export function renderWorkspaceSwitcher() {
  const btn = $id('workspaceSwitcherBtn');
  if (!btn) return;
  const ws = state.workspaces.find(w => w.id === state.activeWorkspaceId);
  if (btn) btn.querySelector('span')?.textContent && (btn.querySelector('span').textContent = ws?.name || 'Workspace');
}

export function renderInviteModal() {
  // Reset form
  const inviteLabel = $id('inviteLabel'); if (inviteLabel) inviteLabel.value = '';
  const inviteRole = $id('inviteRole'); if (inviteRole) inviteRole.value = 'member';
  const inviteLinkWrap = $id('inviteLinkWrap'); if (inviteLinkWrap) inviteLinkWrap.style.display = 'none';

  $id('generateInviteBtn')?.addEventListener('click', async () => {
    const role  = $id('inviteRole')?.value || 'member';
    const label = $id('inviteLabel')?.value.trim() || null;
    try {
      const inv = await createInvitation(state.activeWorkspaceId, state.currentUser.id, role, label);
      const link = `${window.location.origin}${window.location.pathname}?invite=${inv.token}`;
      const inp = $id('inviteLinkInput'); if (inp) inp.value = link;
      const wrap = $id('inviteLinkWrap'); if (wrap) wrap.style.display = '';
      $id('copyInviteBtn')?.addEventListener('click', () => {
        navigator.clipboard.writeText(link);
        toast('Link copied!', 'success');
      });
    } catch (e) { toast(e.message, 'error'); }
  }, { once: true });
}

export async function renderMembersPanel() {
  const container = $id('membersContainer'); if (!container) return;
  container.innerHTML = state.members.map(m => {
    const isMe = m.user_id === state.currentUser?.id;
    const canRemove = canManageMembers() && !isMe;
    return `<div class="team-card" style="padding:16px">
      <div style="display:flex;align-items:center;gap:12px">
        <div class="team-avatar" style="background:${m.color || '#2563eb'};width:36px;height:36px;font-size:.9rem">
          ${m.avatar_preset != null ? '' : '👤'}
        </div>
        <div style="flex:1">
          <div style="font-weight:600">${esc(m.display_name || 'Unnamed')}</div>
          <div style="font-size:.75rem;color:var(--text-3)">${esc(m.role)}</div>
        </div>
        ${canRemove ? `<button class="btn btn-ghost btn-sm" onclick="removeMemberById('${m.id}')" style="color:#dc2626">Remove</button>` : ''}
        ${isMe ? '<span style="font-size:.72rem;color:var(--text-3)">(you)</span>' : ''}
      </div>
    </div>`;
  }).join('');
}

window.removeMemberById = async function(memberId) {
  if (!confirm('Remove this member from the workspace?')) return;
  try {
    await removeMember(memberId);
    removeEntity('members', memberId);
    renderMembersPanel();
    toast('Member removed', 'success');
  } catch (e) { toast(e.message, 'error'); }
};