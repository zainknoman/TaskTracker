import { sb } from './supabase.js';
import { state, updateEntity, addEntity, removeEntity } from './state.js';

const _channels = [];

export function subscribeToWorkspace(workspaceId, onUpdate) {
  const channel = sb.channel(`workspace-${workspaceId}`)
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'tasks', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('tasks', payload);
      onUpdate();
    })
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'projects', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('projects', payload);
      onUpdate();
    })
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'milestones', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('milestones', payload);
      onUpdate();
    })
    .on('postgres_changes', {
      event: '*', schema: 'public', table: 'sprints', filter: `workspace_id=eq.${workspaceId}`
    }, payload => {
      handleEntityChange('sprints', payload);
      onUpdate();
    })
    .subscribe();
  _channels.push(channel);
}

export function subscribeToNotifications(userId, onNotification) {
  const channel = sb.channel(`user-${userId}`)
    .on('postgres_changes', {
      event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}`
    }, payload => {
      onNotification(payload.new);
    })
    .subscribe();
  _channels.push(channel);
}

export function unsubscribeAll() {
  _channels.forEach(ch => sb.removeChannel(ch));
  _channels.length = 0;
}

function handleEntityChange(table, payload) {
  const { eventType, new: newRow, old: oldRow } = payload;
  if (eventType === 'INSERT') {
    if (!state[table].find(e => e.id === newRow.id)) addEntity(table, newRow);
  } else if (eventType === 'UPDATE') {
    updateEntity(table, newRow.id, newRow);
  } else if (eventType === 'DELETE') {
    removeEntity(table, oldRow.id);
  }
}