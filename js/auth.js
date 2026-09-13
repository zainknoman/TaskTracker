
import { sb } from './supabase.js';
import { state, setState } from './state.js';

export async function getSession() {
  const { data: { session } } = await sb.auth.getSession();
  return session;
}

export async function signIn(email, password) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  setState({ currentUser: data.user });
  return data.user;
}

export async function signUp(email, password) {
  const { data, error } = await sb.auth.signUp({ email, password });
  if (error) throw error;
  if (data.user) setState({ currentUser: data.user });
  return data;
}

export async function signOut() {
  await sb.auth.signOut();
  setState({ currentUser: null, workspaces: [], activeWorkspaceId: null, currentMember: null,
    projects: [], tasks: [], milestones: [], sprints: [], members: [], notifications: [] });
}

export function onAuthStateChange(callback) {
  return sb.auth.onAuthStateChange((event, session) => {
    callback(event, session?.user ?? null);
  });
}

// Returns ?invite=<token> param value or null
export function getInviteToken() {
  return new URLSearchParams(window.location.search).get('invite');
}

// Removes ?invite param from URL without reload
export function clearInviteParam() {
  const url = new URL(window.location.href);
  url.searchParams.delete('invite');
  window.history.replaceState({}, '', url.toString());
}