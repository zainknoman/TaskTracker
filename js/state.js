
export const state = {
  // Auth
  currentUser: null,          // Supabase auth user object

  // Workspace
  workspaces: [],             // all workspaces user belongs to
  activeWorkspaceId: null,    // currently selected workspace id
  currentMember: null,        // workspace_members row for current user in active workspace

  // Entities (all workspace-scoped, snake_case from DB)
  projects:   [],
  tasks:      [],
  milestones: [],
  sprints:    [],
  members:    [],             // workspace_members for active workspace

  // UI state
  settings:         { theme: 'light' },
  activeProjectId:  null,
  currentView:      'dashboard',
  activeProjectTab: 'overview',
  projectViewMode:  'grid',
  sortField:        'created_at',
  sortDir:          'desc',
  filters:          { project:'', status:'', priority:'', ba:'', milestone:'', from:'', to:'' },
  searchQuery:      '',
  calendarDate:     new Date(),
  draggedTaskId:    null,
  formTags:         [],
  formDocs:         [],
  formSubtasks:     [],
  projTags:         [],
  cmdIndex:         0,
  notifications:    [],
  savedViews:       [],
};

export function setState(updates) { Object.assign(state, updates); }

export function updateEntity(arrayKey, id, updates) {
  const idx = state[arrayKey].findIndex(e => e.id === id);
  if (idx !== -1) state[arrayKey][idx] = { ...state[arrayKey][idx], ...updates };
}

export function addEntity(arrayKey, entity) { state[arrayKey].push(entity); }

export function removeEntity(arrayKey, id) {
  state[arrayKey] = state[arrayKey].filter(e => e.id !== id);
}

// Data helpers (used by renderers)
export function findTask(id) { return state.tasks.find(t => t.id === id); }
export function findProject(id) { return state.projects.find(p => p.id === id); }
export function getProjectTasks(pid) { return state.tasks.filter(t => t.project_id === pid); }
export function getActiveTasks() { return state.activeProjectId ? getProjectTasks(state.activeProjectId) : state.tasks; }
export function getBAList() { return [...new Set(state.tasks.map(t => t.ba).filter(Boolean))].sort(); }