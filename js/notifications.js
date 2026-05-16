import { sb } from './supabase.js';
import { $id } from './utils.js';

export async function loadNotifications(workspaceId, userId) {
  const { data, error } = await sb
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .eq('workspace_id', workspaceId)
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) throw error;
  return data;
}

export async function markNotificationRead(notificationId) {
  const { error } = await sb.from('notifications').update({ read: true }).eq('id', notificationId);
  if (error) throw error;
}

export async function markAllRead(userId) {
  const { error } = await sb.from('notifications').update({ read: true }).eq('user_id', userId).eq('read', false);
  if (error) throw error;
}

export function updateBell(notifications) {
  const badge = $id('notificationBadge');
  const unread = notifications.filter(n => !n.read).length;
  if (!badge) return;
  badge.textContent = unread > 9 ? '9+' : unread;
  badge.style.display = unread > 0 ? '' : 'none';
}