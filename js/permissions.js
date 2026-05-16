import { state } from './state.js';

export function getMyRole() { return state.currentMember?.role || 'guest'; }
export function canEdit() { return getMyRole() !== 'guest'; }
export function canDelete(entity) {
  const role = getMyRole();
  if (role === 'owner') return true;
  if (role === 'guest') return false;
  return entity?.created_by === state.currentUser?.id;
}
export function canInvite() { return ['owner','member'].includes(getMyRole()); }
export function canManageMembers() { return getMyRole() === 'owner'; }