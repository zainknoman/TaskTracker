
'use strict';
import { sb } from './js/supabase.js';
import { state, setState, findProject } from './js/state.js';
import { $id, esc, setVal, openOverlay, closeOverlay, toast } from './js/utils.js';
import { getSession, signIn, signUp, signOut, onAuthStateChange, getInviteToken, clearInviteParam } from './js/auth.js';
import { listWorkspaces, createWorkspace, loadWorkspace } from './js/workspace.js';
import { createInvitation, acceptInvitation } from './js/invitations.js';
import { canEdit, canDelete, canInvite, canManageMembers } from './js/permissions.js';
import { subscribeToWorkspace, subscribeToNotifications, unsubscribeAll } from './js/realtime.js';
import { loadNotifications, updateBell } from './js/notifications.js';
import { renderDashboard } from './js/ui/dashboard.js';
import { renderProjects, renderProjectDetail, openProjectForm, saveProject, confirmDeleteProject } from './js/ui/projects.js';
import { renderTaskList, openTaskForm, saveTask, openTaskDetail, confirmDeleteTask } from './js/ui/tasks.js';
import { renderKanban } from './js/ui/kanban.js';
import { renderCalendar } from './js/ui/calendar.js';
import { renderGantt } from './js/ui/gantt.js';
import { renderAnalytics } from './js/ui/analytics.js';
import { renderTeam, openMemberForm, saveMember } from './js/ui/team.js';
import { renderWorkspaceSwitcher, renderInviteModal } from './js/ui/workspace-switcher.js';

// Expose functions called from inline onclick attributes in HTML render output
window.openTaskForm = openTaskForm;
window.openTaskDetail = openTaskDetail;
window.confirmDeleteTask = confirmDeleteTask;
window.openProjectDetail = (pid) => { switchView('project-detail'); openProjectDetailView(pid); };
window.openProjectForm = openProjectForm;
window.confirmDeleteProject = confirmDeleteProject;
window.openMemberForm = openMemberForm;
window.saveMember = saveMember;
window.closeOverlay = closeOverlay;

// ── View Routing ──────────────────────────────────────────────
export function switchView(name) {
  state.currentView = name;
  document.querySelectorAll('.view').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.nav-link[data-view]').forEach(el => el.classList.remove('active'));
  $id('view-' + name)?.classList.add('active');
  document.querySelector(`.nav-link[data-view="${name}"]`)?.classList.add('active');
  $id('sidebar')?.classList.remove('mobile-open');
  const renderers = {
    dashboard: renderDashboard, projects: renderProjects, tasks: renderTaskList,
    kanban: renderKanban, calendar: renderCalendar, gantt: renderGantt,
    analytics: renderAnalytics, team: renderTeam, settings: renderSettingsView,
  };
  renderers[name]?.();
  updateBreadcrumb(name);
  updateNavBadges();
  updateSidebarProjects();
}

export function openProjectDetailView(pid) {
  state.activeProjectId = pid;
  state.activeProjectTab = 'overview';
  document.querySelectorAll('.view').forEach(el => el.classList.remove('active'));
  $id('view-project-detail')?.classList.add('active');
  renderProjectDetail(pid);
  updateBreadcrumb('project-detail');
  updateNavBadges();
  updateSidebarProjects();
}

export function refreshView() {
  if (state.currentView === 'project-detail') renderProjectDetail(state.activeProjectId);
  else switchView(state.currentView);
}

function updateBreadcrumb(view) {
  const el = $id('topbarBreadcrumb'); if (!el) return;
  const labels = { dashboard:'Dashboard', projects:'Projects', tasks:'All Tasks', kanban:'Kanban',
    calendar:'Calendar', gantt:'Gantt Timeline', analytics:'Analytics', team:'Team', settings:'Settings' };
  if (view === 'project-detail') {
    const p = findProject(state.activeProjectId);
    el.innerHTML = `<span class="crumb-item" style="cursor:pointer" id="breadProjects">Projects</span><span class="crumb-sep"> › </span><span class="crumb-current" style="color:${p?.color || 'var(--primary)'}">${esc(p?.name || 'Project')}</span>`;
    $id('breadProjects')?.addEventListener('click', () => switchView('projects'));
  } else {
    el.innerHTML = `<span class="crumb-item">${labels[view] || view}</span>`;
  }
}

function updateNavBadges() {
  const pb = $id('navBadgeProjects'); if (pb) pb.textContent = state.projects.filter(p => p.status === 'active').length;
  const tb = $id('navBadgeTasks'); if (tb) tb.textContent = state.tasks.filter(t => t.status !== 'completed').length;
}

function updateSidebarProjects() {
  const list = $id('sidebarProjectList'); if (!list) return;
  $id('clearActiveProjectBtn') && ($id('clearActiveProjectBtn').style.display = state.activeProjectId ? '' : 'none');
  list.innerHTML = state.projects.filter(p => p.status !== 'archived').map(p => {
    const count = state.tasks.filter(t => t.project_id === p.id && t.status !== 'completed').length;
    return `<li><div class="nav-project-item${state.activeProjectId === p.id ? ' active' : ''}" data-pid="${esc(p.id)}">
      <div class="nav-project-dot" style="background:${esc(p.color || '#2563eb')}"></div>
      <span class="nav-project-name">${esc(p.name)}</span>
      ${count ? `<span class="nav-project-count">${count}</span>` : ''}
    </div></li>`;
  }).join('');
  list.querySelectorAll('.nav-project-item').forEach(el =>
    el.addEventListener('click', () => { state.activeProjectId = el.dataset.pid; switchView('project-detail'); openProjectDetailView(el.dataset.pid); })
  );
}

function renderSettingsView() {
  import('./js/ui/workspace-switcher.js').then(m => m.renderMembersPanel());
}

// ── Auth UI ───────────────────────────────────────────────────
function showApp() {
  $id('loginScreen').style.display = 'none';
  $id('app').style.display = '';
  $id('logoutBtn') && ($id('logoutBtn').style.display = '');
  const ws = $id('workspaceNameDisplay');
  if (ws && state.activeWorkspaceId) {
    const w = state.workspaces.find(x => x.id === state.activeWorkspaceId);
    ws.textContent = w?.name || '';
    ws.style.display = '';
  }
  $id('notificationBell') && ($id('notificationBell').style.display = '');
}

function showLogin() {
  $id('loginScreen').style.display = 'flex';
  $id('app').style.display = 'none';
}

function setLoginError(msg = '') {
  const el = $id('loginError'); if (!el) return;
  el.style.display = msg ? 'block' : 'none';
  el.textContent = msg;
}

function setTheme(theme) {
  state.settings.theme = theme;
  document.documentElement.setAttribute('data-theme', theme);
  const lbl = $id('themeLabel'); if (lbl) lbl.textContent = theme === 'dark' ? 'Light Mode' : 'Dark Mode';
}

// ── App Init ──────────────────────────────────────────────────
async function initApp() {
  const session = await getSession();
  if (!session) { showLogin(); return; }
  setState({ currentUser: session.user });

  // Check for invite token before loading workspaces
  const inviteToken = getInviteToken();

  const workspaces = await listWorkspaces(session.user.id);
  setState({ workspaces });

  if (inviteToken) {
    try {
      const joined = await acceptInvitation(inviteToken, session.user.id);
      clearInviteParam();
      toast(`Joined workspace "${joined.workspace_name}"`, 'success');
      // Reload workspaces after joining
      const refreshed = await listWorkspaces(session.user.id);
      setState({ workspaces: refreshed });
      await activateWorkspace(joined.workspace_id);
    } catch (e) {
      toast(e.message || 'Invite link invalid or expired', 'error');
      if (workspaces.length) await activateWorkspace(workspaces[0].id);
      else showOnboarding();
    }
    return;
  }

  if (!workspaces.length) { showLogin(); showOnboarding(); return; }
  await activateWorkspace(workspaces[0].id);
}

async function activateWorkspace(workspaceId) {
  await loadWorkspace(workspaceId);
  const notifs = await loadNotifications(workspaceId, state.currentUser.id);
  setState({ notifications: notifs });
  updateBell(state.notifications);
  subscribeToWorkspace(workspaceId, refreshView);
  subscribeToNotifications(state.currentUser.id, (notif) => {
    state.notifications.unshift(notif);
    updateBell(state.notifications);
  });
  setTheme(state.settings.theme || 'light');
  showApp();
  switchView('dashboard');
}

function showOnboarding() {
  // Simple onboarding: prompt for workspace name
  const name = prompt('Welcome! Enter a name for your workspace:');
  if (!name?.trim()) { showLogin(); return; }
  createWorkspace(name.trim(), state.currentUser.id)
    .then(ws => {
      const ws2 = { ...ws, myRole: 'owner' };
      setState({ workspaces: [ws2] });
      return activateWorkspace(ws.id);
    })
    .catch(e => { toast(e.message, 'error'); showLogin(); });
}

// ── Event Binding ─────────────────────────────────────────────
function bindEvents() {
  document.querySelectorAll('.nav-link[data-view]').forEach(link =>
    link.addEventListener('click', e => { e.preventDefault(); switchView(link.dataset.view); })
  );
  $id('sidebarCollapseBtn')?.addEventListener('click', () => $id('sidebar').classList.toggle('collapsed'));
  $id('menuBtn')?.addEventListener('click', () => $id('sidebar').classList.toggle('mobile-open'));
  $id('themeToggle')?.addEventListener('click', () => setTheme(state.settings.theme === 'dark' ? 'light' : 'dark'));

  $id('loginBtn')?.addEventListener('click', async () => {
    setLoginError();
    const email = $id('loginEmail')?.value.trim();
    const pass  = $id('loginPassword')?.value;
    try { await signIn(email, pass); await initApp(); }
    catch (e) { setLoginError(e.message); }
  });
  $id('signupBtn')?.addEventListener('click', async () => {
    setLoginError();
    const email = $id('loginEmail')?.value.trim();
    const pass  = $id('loginPassword')?.value;
    try { await signUp(email, pass); await initApp(); }
    catch (e) { setLoginError(e.message); }
  });
  $id('logoutBtn')?.addEventListener('click', async () => {
    unsubscribeAll();
    await signOut();
    showLogin();
  });

  ['newTaskBtn','newTaskBtnList'].forEach(id =>
    $id(id)?.addEventListener('click', () => openTaskForm(null, state.activeProjectId))
  );
  ['newProjectBtn','newProjectTopBtn','newProjectSidebarBtn'].forEach(id =>
    $id(id)?.addEventListener('click', e => { e.preventDefault(); openProjectForm(); })
  );
  $id('openInviteBtn')?.addEventListener('click', () => {
    renderInviteModal();
    openOverlay('inviteOverlay');
  });
  $id('inviteClose')?.addEventListener('click', () => closeOverlay('inviteOverlay'));
  $id('clearActiveProjectBtn')?.addEventListener('click', () => { state.activeProjectId = null; refreshView(); updateSidebarProjects(); });

  document.addEventListener('keydown', e => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') { e.preventDefault(); import('./js/ui/dashboard.js').then(m => m.openCommandPalette?.()); }
  });
}

// ── Bootstrap ─────────────────────────────────────────────────
onAuthStateChange(async (event, user) => {
  if (event === 'SIGNED_OUT') { setState({ currentUser: null }); showLogin(); }
});

bindEvents();
initApp();