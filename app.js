/* ============================================================
   TASKFLOW PRO — Enterprise Work Management System
   app.js — Complete Application Engine
   ============================================================ */
'use strict';
/* ════════════════════════════════════════════════════════════
   SUPABASE CONFIG
   FIX 1: URL was pointing to the dashboard page.
          Must be the project API URL: https://<ref>.supabase.co
   ════════════════════════════════════════════════════════════ */
if (!window.APP_CONFIG?.supabaseUrl || !window.APP_CONFIG?.supabaseKey) {
  document.body.innerHTML = `<div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0f172a;color:white;font-family:Arial,sans-serif;padding:40px"><div style="max-width:600px;background:#111827;padding:40px;border-radius:20px;border:1px solid #374151"><h1 style="margin-top:0">Configuration Missing</h1><p style="color:#d1d5db">Create a <code>config.js</code> file in the project root based on <code>config.example.js</code>, then reload.</p></div></div>`;
  throw new Error('APP_CONFIG not found — copy config.example.js to config.js and fill in your credentials');
}
const SUPABASE_URL = window.APP_CONFIG.supabaseUrl;
const SUPABASE_KEY = window.APP_CONFIG.supabaseKey;
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  }
});
/* ════════════════════════════════════════════════════════════
   CONSTANTS & CONFIG
   ════════════════════════════════════════════════════════════ */
const STORAGE_KEY  = 'taskflow_pro_v3';
const AUTOSAVE_MS  = 1800;
const STATUS_META = {
  pending:    { label: 'Pending',     dot: '#fbbf24', color: '#d97706' },
  inprogress: { label: 'In Progress', dot: '#60a5fa', color: '#2563eb' },
  completed:  { label: 'Completed',   dot: '#34d399', color: '#059669' },
  blocked:    { label: 'Blocked',     dot: '#f87171', color: '#dc2626' },
};
const PRIORITY_META = {
  low:      { label: 'Low',      order: 1 },
  medium:   { label: 'Medium',   order: 2 },
  high:     { label: 'High',     order: 3 },
  critical: { label: 'Critical', order: 4 },
};
const PROJECT_COLORS = [
  '#2563eb','#059669','#7c3aed','#d97706',
  '#dc2626','#0891b2','#db2777','#65a30d'
];
const AVATAR_PRESETS = [
  { icon: '👤', color: '#2563eb' },
  { icon: '👩', color: '#db2777' },
  { icon: '👨', color: '#0891b2' },
  { icon: '👩‍💼', color: '#7c3aed' },
  { icon: '👨‍💼', color: '#059669' },
  { icon: '👩‍💻', color: '#dc2626' },
  { icon: '👨‍💻', color: '#d97706' },
  { icon: '👩‍🔬', color: '#65a30d' },
  { icon: '👨‍🔬', color: '#0891b2' },
  { icon: '🧑‍🎨', color: '#db2777' },
  { icon: '🧑‍🏫', color: '#7c3aed' },
  { icon: '🧑‍💻', color: '#2563eb' },
];
/* ════════════════════════════════════════════════════════════
   AUTH USER CACHE — set before Storage is ever called
   ════════════════════════════════════════════════════════════ */
let currentUser = null; // null = guest mode

/* ════════════════════════════════════════════════════════════
   STATE
   ════════════════════════════════════════════════════════════ */
let state = {
  projects:    [],
  tasks:       [],
  milestones:  [],
  sprints:     [],
  users:       [],
  settings:    { theme: 'light' },
  activeProjectId:  null,
  currentView:      'dashboard',
  activeProjectTab: 'overview',
  projectViewMode:  'grid',
  sortField: 'createdAt',
  sortDir:   'desc',
  filters:   { project:'', status:'', priority:'', ba:'', milestone:'', from:'', to:'' },
  searchQuery: '',
  calendarDate: new Date(),
  draggedTaskId: null,
  // form state
  formTags:    [],
  formDocs:    [],
  formSubtasks:[],
  projTags:    [],
  // command palette
  cmdIndex: 0,
  // notification & view state
  notifications: [],
  savedViews:    [],
};
/* ════════════════════════════════════════════════════════════
   STORAGE LAYER
   FIX 2: Storage.save() is async — must be awaited everywhere.
   FIX 3: Storage.load() is async — must be awaited everywhere.
   ════════════════════════════════════════════════════════════ */
const Storage = {
  async save() {
    try {
      if (!currentUser) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
        console.log('[Storage.save] guest → localStorage');
        return;
      }
      const payload = {
        id: currentUser.id,
        user_id: currentUser.id,
        data: state,
        updated_at: new Date().toISOString()
      };
      const { error } = await sb.from('workspaces').upsert(payload);
      if (error) {
        console.error('[Storage.save] Supabase error:', error);
      } else {
        console.log('[Storage.save] saved to Supabase for', currentUser.email);
      }
    } catch (err) {
      console.error('[Storage.save.catch]', err);
    }
  },
  async load() {
    try {
      if (!currentUser) {
        const raw = localStorage.getItem(STORAGE_KEY);
        console.log('[Storage.load] guest → localStorage:', raw ? 'found' : 'empty');
        return raw ? JSON.parse(raw) : null;
      }
      console.log('[Storage.load] querying Supabase for', currentUser.email);
      const timeoutGuard = new Promise(resolve =>
        setTimeout(() => resolve({ data: null, error: new Error('load timeout after 5s') }), 5000)
      );
      const { data, error } = await Promise.race([
        sb.from('workspaces').select('data').eq('user_id', currentUser.id).maybeSingle(),
        timeoutGuard
      ]);
      if (error) {
        console.error('[Storage.load] Supabase error:', error);
        return null;
      }
      console.log('[Storage.load] Supabase result:', data ? 'row found' : 'no row yet');
      return data?.data ?? null;
    } catch (err) {
      console.error('[Storage.load.catch]', err);
      return null;
    }
  }
};
/* ════════════════════════════════════════════════════════════
   AUTH HELPERS
   ════════════════════════════════════════════════════════════ */
function showApp() {
  const login = document.getElementById('loginScreen');
  const app = document.getElementById('app');
  if (login) login.style.display = 'none';
  if (app) app.style.display = '';
  const logoutBtn = document.getElementById('logoutBtn');
  if (logoutBtn) logoutBtn.style.display = currentUser ? '' : 'none';
}
function showLogin() {
  const login = document.getElementById('loginScreen');
  const app = document.getElementById('app');
  if (login) login.style.display = 'flex';
  if (app) app.style.display = 'none';
  const logoutBtn = document.getElementById('logoutBtn');
  if (logoutBtn) logoutBtn.style.display = 'none';
}
function setLoginError(message = '') {
  const el = document.getElementById('loginError');
  if (!el) return;
  if (!message) {
    el.style.display = 'none';
    el.textContent = '';
    return;
  }
  el.style.display = 'block';
  el.textContent = message;
}
/* ════════════════════════════════════════════════════════════
   PERSIST / SCHEDULE SAVE
   FIX 4: persistState must be async and await Storage.save().
   FIX 5: scheduleSave timer callback must be async.
   ════════════════════════════════════════════════════════════ */
async function persistState() {                           // ✅ async
  await Storage.save();                                   // ✅ awaited
}
let _saveTimer;
function scheduleSave() {
  clearTimeout(_saveTimer);
  _saveTimer = setTimeout(async () => {                   // ✅ async callback
    await persistState();                                 // ✅ awaited
  }, AUTOSAVE_MS);
}
/* ════════════════════════════════════════════════════════════
   LOAD STATE
   FIX 6: loadState must be async and await Storage.load().
          Previously Storage.load() returned a Promise but
          was treated as plain data — saved.projects was
          always undefined, forcing seed data every reload.
   ════════════════════════════════════════════════════════════ */
   /*
async function loadState() {
  try{
    //const saved = await Storage.load();
    console.log("Storage.load START");

    const Storage = {
      load() {
        return new Promise((resolve) => {
          try {
            const raw = localStorage.getItem("taskflow_state");

            if (!raw) return resolve(null);

            const parsed = JSON.parse(raw);

            resolve(parsed);
          } catch (err) {
            console.error("Storage.load parse error:", err);
            resolve(null); // NEVER block app
          }
        });
      },

      save() {
        try {
          localStorage.setItem(
            "taskflow_state",
            JSON.stringify(state)
          );
        } catch (err) {
          console.error("Storage.save error:", err);
        }
      }
    };
    console.log("Storage.load END", saved);
    
    if (saved && saved.projects?.length) {
      state.projects      = saved.projects      || [];
      state.tasks         = saved.tasks         || [];
      state.milestones    = saved.milestones    || [];
      state.sprints       = saved.sprints       || [];
      state.users         = saved.users         || buildSeedUsers();
      state.settings      = saved.settings      || { theme: 'light' };
      state.notifications = saved.notifications || [];
      state.savedViews    = saved.savedViews    || [];
    } else {
      const seed = buildSeedData();
      Object.assign(state, seed);
      state.settings      = { theme: 'light' };
      state.notifications = [];
      state.savedViews    = [];
      await Storage.save();
    }
  } catch(err) {
      console.error('[Storage.load.catch]', err);
      return null;
  }
}
  */

async function loadState() {
  try {
    const saved = await Storage.load();
    console.log('[loadState] Storage.load returned:', saved ? 'data found' : 'null (new user)');

    if (saved !== null) {
      state.projects      = saved.projects      || [];
      state.tasks         = saved.tasks         || [];
      state.milestones    = saved.milestones    || [];
      state.sprints       = saved.sprints       || [];
      state.users         = saved.users         || [];
      state.settings      = saved.settings      || { theme: 'light' };
      state.notifications = saved.notifications || [];
      state.savedViews    = saved.savedViews    || [];
    } else {
      // New user — start with a clean empty workspace, no seed data
      state.projects      = [];
      state.tasks         = [];
      state.milestones    = [];
      state.sprints       = [];
      state.users         = [];
      state.settings      = { theme: 'light' };
      state.notifications = [];
      state.savedViews    = [];
    }
  } catch (err) {
    console.error('[loadState.catch]', err);
  }
}
/* ════════════════════════════════════════════════════════════
   SEED DATA
   ════════════════════════════════════════════════════════════ */
function buildSeedUsers() {
  return [
    { id:'u1', name:'Sarah Ahmed',   role:'Business Analyst', avatar:'SA', color:'#2563eb', team:'BA' },
    { id:'u2', name:'Omar Farooq',   role:'Senior BA',        avatar:'OF', color:'#7c3aed', team:'BA' },
    { id:'u3', name:'Ayesha Khan',   role:'UI/UX Designer',   avatar:'AK', color:'#db2777', team:'Design' },
    { id:'u4', name:'Hassan Malik',  role:'Tech Lead',        avatar:'HM', color:'#059669', team:'Engineering' },
    { id:'u5', name:'Fatima Riaz',   role:'QA Engineer',      avatar:'FR', color:'#d97706', team:'QA' },
    { id:'u6', name:'Ali Hassan',    role:'Developer',        avatar:'AH', color:'#0891b2', team:'Engineering' },
  ];
}
function buildSeedData() {
  const D = n => { const d = new Date(); d.setDate(d.getDate() + n); return d.toISOString().split('T')[0]; };
  const NOW = D(0);
  const p1 = uid(), p2 = uid(), p3 = uid(), p4 = uid();
  const m1 = uid(), m2 = uid(), m3 = uid(), m4 = uid(), m5 = uid(), m6 = uid();
  const s1 = uid(), s2 = uid(), s3 = uid();
  const projects = [
    { id:p1, name:'Core Banking Upgrade', code:'CBU-25', description:'Modernise core banking platform to microservices architecture with zero downtime migration.', department:'Technology', client:'Retail Banking', pm:'Hassan Malik', baTeam:'Sarah Ahmed, Omar Farooq', status:'active', priority:'critical', startDate:D(-60), endDate:D(90),  color:'#2563eb', tags:['Backend','Critical'], budget:500000, createdAt:D(-62), updatedAt:NOW },
    { id:p2, name:'Mobile App Revamp',    code:'MAR-25', description:'Full redesign of mobile banking app with biometric auth, new UI and performance improvements.', department:'Digital', client:'Digital Banking', pm:'Ayesha Khan', baTeam:'Sarah Ahmed', status:'active', priority:'high', startDate:D(-30), endDate:D(60),  color:'#7c3aed', tags:['Mobile','UX'], budget:200000, createdAt:D(-32), updatedAt:NOW },
    { id:p3, name:'KYC Digital Onboarding',code:'KYC-25',description:'Digital KYC onboarding to eliminate paper forms and reduce processing time by 80%.', department:'Compliance', client:'Operations', pm:'Omar Farooq', baTeam:'Omar Farooq, Fatima Riaz', status:'active', priority:'high', startDate:D(-15), endDate:D(75),  color:'#059669', tags:['Compliance','KYC'], budget:150000, createdAt:D(-17), updatedAt:NOW },
    { id:p4, name:'UAE Tax Portal',        code:'TAX-25', description:'Automated VAT reporting portal for corporate clients, integrated with FTA APIs.', department:'Finance', client:'Corporate Banking', pm:'Hassan Malik', baTeam:'Sarah Ahmed', status:'planning', priority:'medium', startDate:D(15), endDate:D(120), color:'#d97706', tags:['Tax','Finance'], budget:100000, createdAt:D(-5), updatedAt:NOW },
  ];
  const milestones = [
    { id:m1, projectId:p1, name:'Architecture Sign-off', description:'Final approval of microservices design', dueDate:D(-20), status:'completed', order:1, createdAt:D(-60) },
    { id:m2, projectId:p1, name:'Development Complete',  description:'All APIs and services built and tested',  dueDate:D(30),  status:'inprogress',order:2, createdAt:D(-60) },
    { id:m3, projectId:p1, name:'UAT Sign-off',          description:'User Acceptance Testing completed',       dueDate:D(60),  status:'pending',  order:3, createdAt:D(-60) },
    { id:m4, projectId:p2, name:'UI Design Approval',    description:'All screens approved by stakeholders',    dueDate:D(10),  status:'inprogress',order:1, createdAt:D(-30) },
    { id:m5, projectId:p2, name:'Beta Release',          description:'App released for beta testing',           dueDate:D(40),  status:'pending',  order:2, createdAt:D(-30) },
    { id:m6, projectId:p3, name:'Requirements Freeze',   description:'All requirements collected and frozen',   dueDate:D(5),   status:'inprogress',order:1, createdAt:D(-15) },
  ];
  const sprints = [
    { id:s1, projectId:p1, name:'Sprint 1 — Foundation', goal:'CI/CD setup and service scaffold',         startDate:D(-60), endDate:D(-46), status:'completed', velocity:32, createdAt:D(-62) },
    { id:s2, projectId:p1, name:'Sprint 2 — Core APIs',  goal:'Account management and transaction APIs', startDate:D(-45), endDate:D(-31), status:'completed', velocity:28, createdAt:D(-62) },
    { id:s3, projectId:p1, name:'Sprint 3 — Integration',goal:'Payment gateway and external services',    startDate:D(-14), endDate:D(0),   status:'active',    velocity:0,  createdAt:D(-62) },
  ];
  const users = buildSeedUsers();
  const T = (f) => ({ id:uid(), projectId:'', milestoneId:'', sprintId:'', parentTaskId:'', title:'', description:'', priority:'medium', status:'pending', startDate:'', dueDate:'', ba:'', assignee:'', tags:[], documents:[], dependencies:[], estimatedHours:0, actualHours:0, progress:0, subtasks:[], notes:'', starred:false, pinned:false, createdAt:NOW, updatedAt:NOW, activity:[{ time:NOW, desc:'Task created' }], ...f });
  const tasks = [
    T({ projectId:p1, milestoneId:m2, sprintId:s3, title:'Payment Gateway REST API Integration', description:'Implement REST integration with payment gateway including retries, idempotency and fallback handling.', priority:'critical', status:'inprogress', startDate:D(-10), dueDate:D(3),  ba:'Sarah Ahmed', tags:['API','Backend','Payments'], estimatedHours:40, progress:60, starred:true, subtasks:[{id:uid(),title:'API contract design',done:true},{id:uid(),title:'Implement endpoints',done:true},{id:uid(),title:'JWT middleware',done:false},{id:uid(),title:'Unit tests',done:false},{id:uid(),title:'Swagger docs',done:false}], notes:'Blocked by firewall — escalated to infra team.' }),
    T({ projectId:p1, milestoneId:m2, sprintId:s3, title:'Account Balance Enquiry Service',      description:'Real-time account balance lookup with caching layer.',                                               priority:'high',     status:'inprogress', startDate:D(-8),  dueDate:D(5),  ba:'Omar Farooq', tags:['Backend','Banking'], estimatedHours:24, progress:75, subtasks:[{id:uid(),title:'Service layer',done:true},{id:uid(),title:'Cache integration',done:false}] }),
    T({ projectId:p1, milestoneId:m3,               title:'UAT Test Case Preparation',            description:'Prepare all UAT scenarios covering happy path, edge cases and error flows.',                          priority:'high',     status:'pending',    startDate:D(5),   dueDate:D(20), ba:'Fatima Riaz', tags:['QA','UAT'],      estimatedHours:20, progress:0 }),
    T({ projectId:p1, milestoneId:m1,               title:'Database Schema Migration',            description:'Migrate Oracle schema to PostgreSQL with zero data loss.',                                            priority:'critical', status:'completed',  startDate:D(-45), dueDate:D(-20),ba:'Sarah Ahmed', tags:['Database'],      estimatedHours:60, progress:100, starred:true }),
    T({ projectId:p1, milestoneId:m2,               title:'Fund Transfer API',                    description:'Core fund transfer service with idempotency, limits and dual-approval.',                             priority:'critical', status:'blocked',    startDate:D(-12), dueDate:D(-2), ba:'Omar Farooq', tags:['API','Payments'], estimatedHours:32, progress:40, notes:'Blocked — pending Compliance approval for dual-auth flows.' }),
    T({ projectId:p2, milestoneId:m4,               title:'Dashboard UI Redesign',                description:'Redesign main dashboard with new design system, improved UX and WCAG 2.1 accessibility.',            priority:'high',     status:'inprogress', startDate:D(-8),  dueDate:D(7),  ba:'Sarah Ahmed', assignee:'u3', tags:['Design','Frontend'], estimatedHours:32, progress:80, subtasks:[{id:uid(),title:'Wireframes',done:true},{id:uid(),title:'Hi-fi mockups',done:true},{id:uid(),title:'Dev handoff',done:false}] }),
    T({ projectId:p2, milestoneId:m4,               title:'Biometric Authentication Module',      description:'Fingerprint and Face ID integration for iOS and Android.',                                            priority:'critical', status:'pending',    startDate:D(2),   dueDate:D(14), ba:'Ayesha Khan', tags:['Security','Mobile'], estimatedHours:28, progress:0 }),
    T({ projectId:p2, milestoneId:m5,               title:'Push Notification System',             description:'In-app and OS push notifications for transaction alerts, OTPs and promotions.',                      priority:'medium',   status:'pending',    startDate:D(10),  dueDate:D(30), ba:'Sarah Ahmed', tags:['Mobile','Backend'], estimatedHours:16, progress:0 }),
    T({ projectId:p3, milestoneId:m6,               title:'KYC Workflow Requirements',            description:'Collect and document all functional requirements for digital onboarding.',                            priority:'critical', status:'inprogress', startDate:D(-12), dueDate:D(4),  ba:'Omar Farooq', assignee:'u2', tags:['KYC','Analysis'], estimatedHours:24, progress:55, documents:[{title:'BRD v1.0',url:'https://example.com/brd'},{title:'Process Flow',url:'https://example.com/flow'}] }),
    T({ projectId:p3,                               title:'Document Verification API',            description:'OCR + liveness check integration with third-party document scanning provider.',                     priority:'high',     status:'pending',    startDate:D(8),   dueDate:D(25), ba:'Fatima Riaz', tags:['API','KYC'], estimatedHours:20, progress:0 }),
    T({ projectId:p3,                               title:'AML Compliance Review',                description:'AML workflow sign-off and regulatory compliance gate for KYC onboarding.',                           priority:'critical', status:'blocked',    startDate:D(-5),  dueDate:D(-1), ba:'Omar Farooq', tags:['Compliance','AML'], estimatedHours:16, progress:30, notes:'Awaiting response from Risk & Compliance team. Second escalation sent.' }),
    T({ projectId:p4,                               title:'Tax Portal Business Requirements',     description:'Gather and document all requirements for UAE VAT reporting portal.',                                  priority:'high',     status:'pending',    startDate:D(15),  dueDate:D(30), ba:'Sarah Ahmed', tags:['Tax','Finance'], estimatedHours:20, progress:0 }),
  ];
  return { projects, tasks, milestones, sprints, users };
}
/* ════════════════════════════════════════════════════════════
   UTILITIES
   ════════════════════════════════════════════════════════════ */
function uid() { return '_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }
function today() { return new Date().toISOString().split('T')[0]; }
function fmtDate(d) { if (!d) return '—'; return new Date(d + 'T00:00:00').toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' }); }
function isOverdue(t) { return t.dueDate && t.status !== 'completed' && new Date(t.dueDate) < new Date(new Date().toDateString()); }
function daysUntil(d) { if (!d) return null; return Math.round((new Date(d) - new Date(new Date().toDateString())) / 86400000); }
function esc(s) { return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
function getTagColor(tag) { let h = 0; for (let c of String(tag)) h = (h * 31 + c.charCodeAt(0)) & 0xffffffff; return Math.abs(h) % 8; }
function findTask(id) { return state.tasks.find(t => t.id === id); }
function findProject(id) { return state.projects.find(p => p.id === id); }
function getProjectTasks(pid) { return state.tasks.filter(t => t.projectId === pid); }
function getActiveTasks() { return state.activeProjectId ? getProjectTasks(state.activeProjectId) : state.tasks; }
function getBAList() { return [...new Set(state.tasks.map(t => t.ba).filter(Boolean))].sort(); }
function calcProgress(task) { if (!task.subtasks?.length) return task.progress || 0; const done = task.subtasks.filter(s => s.done).length; return Math.round(done / task.subtasks.length * 100); }
function addActivity(task, desc) { if (!task.activity) task.activity = []; task.activity.push({ time: today(), desc }); }
function openOverlay(id) { document.getElementById(id)?.classList.add('open'); }
function closeOverlay(id) { document.getElementById(id)?.classList.remove('open'); }
function $id(id) { return document.getElementById(id); }
function setVal(id, v) { const el = $id(id); if (el) el.value = v ?? ''; }
/* ════════════════════════════════════════════════════════════
   ROUTING
   ════════════════════════════════════════════════════════════ */
function switchView(name) {
  state.currentView = name;
  document.querySelectorAll('.view').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.nav-link[data-view]').forEach(el => el.classList.remove('active'));
  $id('view-' + name)?.classList.add('active');
  document.querySelector(`.nav-link[data-view="${name}"]`)?.classList.add('active');
  $id('sidebar')?.classList.remove('mobile-open');
  const renders = {
    dashboard: renderDashboard, projects: renderProjects, tasks: renderTaskList,
    kanban: renderKanban, calendar: renderCalendar, gantt: renderGantt,
    analytics: renderAnalytics, team: renderTeam,
  };
  renders[name]?.();
  updateBreadcrumb(name);
  updateNavBadges();
  updateSidebarProjects();
}
function openProjectDetail(pid) {
  state.activeProjectId = pid;
  state.activeProjectTab = 'overview';
  state.currentView = 'project-detail';
  document.querySelectorAll('.view').forEach(el => el.classList.remove('active'));
  $id('view-project-detail')?.classList.add('active');
  $id('sidebar')?.classList.remove('mobile-open');
  renderProjectDetail(pid);
  updateBreadcrumb('project-detail');
  updateNavBadges();
  updateSidebarProjects();
}
function updateBreadcrumb(view) {
  const el = $id('topbarBreadcrumb');
  if (!el) return;
  const labels = { dashboard:'Dashboard', projects:'Projects', tasks:'All Tasks', kanban:'Kanban', calendar:'Calendar', gantt:'Gantt Timeline', analytics:'Analytics', team:'Team' };
  if (view === 'project-detail') {
    const p = findProject(state.activeProjectId);
    el.innerHTML = `<span class="crumb-item" style="cursor:pointer" id="breadProjects">Projects</span><span class="crumb-sep"> › </span><span class="crumb-current" style="color:${p?.color || 'var(--primary)'}">${esc(p?.name || 'Project')}</span>`;
    $id('breadProjects')?.addEventListener('click', () => switchView('projects'));
  } else {
    el.innerHTML = `<span class="crumb-item">${labels[view] || view}</span>`;
  }
}
function updateNavBadges() {
  const pb = $id('navBadgeProjects');
  if (pb) pb.textContent = state.projects.filter(p => p.status === 'active').length;
  const tb = $id('navBadgeTasks');
  if (tb) tb.textContent = state.tasks.filter(t => t.status !== 'completed').length;
}
function updateSidebarProjects() {
  const list = $id('sidebarProjectList');
  if (!list) return;
  $id('clearActiveProjectBtn')?.style && ($id('clearActiveProjectBtn').style.display = state.activeProjectId ? '' : 'none');
  list.innerHTML = state.projects.filter(p => p.status !== 'archived').map(p => {
    const count = getProjectTasks(p.id).filter(t => t.status !== 'completed').length;
    return `<li><div class="nav-project-item${state.activeProjectId === p.id ? ' active' : ''}" data-pid="${esc(p.id)}">
      <div class="nav-project-dot" style="background:${esc(p.color)}"></div>
      <span class="nav-project-name">${esc(p.name)}</span>
      ${count ? `<span class="nav-project-count">${count}</span>` : ''}
    </div></li>`;
  }).join('');
  list.querySelectorAll('.nav-project-item').forEach(el =>
    el.addEventListener('click', () => openProjectDetail(el.dataset.pid))
  );
}
function refreshView() {
  if (state.currentView === 'project-detail') renderProjectDetail(state.activeProjectId);
  else switchView(state.currentView);
}
/* ════════════════════════════════════════════════════════════
   DASHBOARD
   ════════════════════════════════════════════════════════════ */
function renderDashboard() {
  const tasks = getActiveTasks();
  $id('dashDate')?.textContent && ($id('dashDate').textContent = new Date().toLocaleDateString('en-GB', { weekday:'long', day:'numeric', month:'long', year:'numeric' }));
  const s = {
    total: tasks.length,
    pending: tasks.filter(t => t.status === 'pending').length,
    inprogress: tasks.filter(t => t.status === 'inprogress').length,
    completed: tasks.filter(t => t.status === 'completed').length,
    blocked: tasks.filter(t => t.status === 'blocked').length,
  };
  const sg = $id('statsGrid');
  if (sg) sg.innerHTML = [
    { key:'total',      label:'Total Tasks',  color:'#2563eb', emoji:'📋' },
    { key:'pending',    label:'Pending',      color:'#d97706', emoji:'⏰' },
    { key:'inprogress', label:'In Progress',  color:'#2563eb', emoji:'▶️' },
    { key:'completed',  label:'Completed',    color:'#059669', emoji:'✅' },
    { key:'blocked',    label:'Blocked',      color:'#dc2626', emoji:'🚫' },
  ].map(({ key, label, color, emoji }) => `
    <div class="stat-card" style="--stat-color:${color}" data-stat="${key}">
      <div class="stat-label">${label}</div>
      <div class="stat-number">${s[key]}</div>
      <div class="stat-icon" style="font-size:2.2rem;line-height:1">${emoji}</div>
    </div>`).join('');
  const pct = s.total ? Math.round(s.completed / s.total * 100) : 0;
  if ($id('progressFill')) $id('progressFill').style.width = pct + '%';
  if ($id('progressPct'))  $id('progressPct').textContent  = pct + '%';
  // Projects overview
  const pol = $id('projectsOverviewList');
  if (pol) pol.innerHTML = state.projects.filter(p => p.status !== 'archived').map(p => {
    const pt = getProjectTasks(p.id);
    const done = pt.filter(t => t.status === 'completed').length;
    const ppct = pt.length ? Math.round(done / pt.length * 100) : 0;
    return `<div class="mini-task-item" data-pid="${p.id}" style="cursor:pointer">
      <div class="mini-task-dot" style="background:${p.color}"></div>
      <div style="flex:1;min-width:0">
        <div class="mini-task-title">${esc(p.name)}</div>
        <div class="mini-progress-track" style="margin-top:3px;height:3px"><div class="mini-progress-fill" style="width:${ppct}%;background:${p.color}"></div></div>
      </div>
      <span style="font-size:.72rem;color:var(--text-3);white-space:nowrap">${ppct}% · ${pt.length} tasks</span>
    </div>`;
  }).join('') || '<p class="no-data">No projects</p>';
  $id('projectsOverviewList')?.querySelectorAll('[data-pid]').forEach(el =>
    el.addEventListener('click', () => openProjectDetail(el.dataset.pid))
  );
  // Overdue count
  const ov = tasks.filter(isOverdue).length;
  const oc = $id('overdueCount');
  if (oc) { oc.style.display = ov ? '' : 'none'; oc.textContent = ov + ' overdue'; }
  // Upcoming deadlines
  const upcoming = [...tasks].filter(t => t.status !== 'completed' && t.dueDate)
    .sort((a, b) => a.dueDate.localeCompare(b.dueDate)).slice(0, 6);
  const ul = $id('upcomingList');
  if (ul) ul.innerHTML = upcoming.map(t => {
    const days = daysUntil(t.dueDate), over = days < 0;
    const label = over ? `${Math.abs(days)}d overdue` : days === 0 ? 'Today' : `${days}d left`;
    return `<div class="mini-task-item" data-id="${t.id}">
      <div class="mini-task-dot" style="background:${over ? '#f87171' : STATUS_META[t.status].dot}"></div>
      <span class="mini-task-title">${esc(t.title)}</span>
      <span class="mini-task-meta" style="color:${over ? '#dc2626' : 'inherit'}">${label}</span>
    </div>`;
  }).join('') || '<p class="no-data">No upcoming deadlines 🎉</p>';
  // Recent activity
  const allAct = state.tasks.flatMap(t => (t.activity || []).map(a => ({ ...a, taskTitle: t.title, taskId: t.id })))
    .sort((a, b) => b.time.localeCompare(a.time)).slice(0, 8);
  const ral = $id('recentActivityList');
  if (ral) ral.innerHTML = allAct.map(a => `
    <div class="mini-task-item" data-id="${a.taskId}">
      <div class="mini-task-dot" style="background:var(--primary)"></div>
      <div style="flex:1;min-width:0">
        <div class="mini-task-title">${esc(a.taskTitle)}</div>
        <div style="font-size:.72rem;color:var(--text-3)">${esc(a.desc)}</div>
      </div>
      <span class="mini-task-meta">${fmtDate(a.time)}</span>
    </div>`).join('') || '<p class="no-data">No activity yet</p>';
  // Team workload
  const wlMap = {};
  state.tasks.filter(t => t.ba).forEach(t => {
    if (!wlMap[t.ba]) wlMap[t.ba] = { name: t.ba, open: 0, done: 0 };
    t.status === 'completed' ? wlMap[t.ba].done++ : wlMap[t.ba].open++;
  });
  const wlEntries = Object.values(wlMap).sort((a, b) => b.open - a.open).slice(0, 6);
  const maxWl = Math.max(...wlEntries.map(e => e.open + e.done), 1);
  const twl = $id('teamWorkloadList');
  if (twl) twl.innerHTML = wlEntries.map(e => {
    const u = state.users.find(u => u.name === e.name);
    const bPct = Math.round((e.open + e.done) / maxWl * 100);
    return `<div class="mini-task-item">
      <div style="width:28px;height:28px;border-radius:50%;background:${u?.color || '#2563eb'};display:flex;align-items:center;justify-content:center;font-size:.6rem;font-weight:700;color:#fff;flex-shrink:0">${u?.avatar || e.name.slice(0,2).toUpperCase()}</div>
      <div style="flex:1;min-width:0">
        <div style="font-size:.82rem;font-weight:500">${esc(e.name)}</div>
        <div class="workload-bar" style="margin-top:3px"><div class="workload-fill" style="width:${bPct}%;background:${u?.color || '#2563eb'}"></div></div>
      </div>
      <span class="mini-task-meta">${e.open} open</span>
    </div>`;
  }).join('') || '<p class="no-data">No team assignments yet</p>';
  // bind events
  $id('recentActivityList')?.querySelectorAll('[data-id]').forEach(el => el.addEventListener('click', () => openTaskDetail(el.dataset.id)));
  $id('upcomingList')?.querySelectorAll('[data-id]').forEach(el => el.addEventListener('click', () => openTaskDetail(el.dataset.id)));
  $id('statsGrid')?.querySelectorAll('.stat-card').forEach(card => {
    card.addEventListener('click', () => {
      const stat = card.dataset.stat;
      state.filters.status = stat === 'total' ? '' : stat;
      const sel = $id('filterStatus'); if (sel) sel.value = state.filters.status;
      switchView('tasks');
    });
  });
}
/* ════════════════════════════════════════════════════════════
   PROJECTS VIEW
   ════════════════════════════════════════════════════════════ */
function renderProjects() {
  const filter = $id('projectStatusFilter')?.value || '';
  const projects = filter ? state.projects.filter(p => p.status === filter) : state.projects;
  const cl = $id('projectCountLabel');
  if (cl) cl.textContent = `${projects.length} project${projects.length !== 1 ? 's' : ''}`;
  const container = $id('projectsContainer');
  if (!container) return;
  container.className = state.projectViewMode === 'list' ? '' : 'projects-grid';
  if (!projects.length) {
    container.innerHTML = '<p class="no-data" style="padding:48px;text-align:center">No projects yet. Click <strong>+ New Project</strong> to get started.</p>';
    return;
  }
  if (state.projectViewMode === 'list') {
    container.innerHTML = `<div class="table-wrapper"><table class="task-table"><thead><tr>
      <th>Name</th><th>Code</th><th>Status</th><th>Priority</th><th>PM</th><th>Tasks</th><th>Progress</th><th>End Date</th><th>Actions</th>
    </tr></thead><tbody>${projects.map(p => {
      const pt = getProjectTasks(p.id);
      const done = pt.filter(t => t.status === 'completed').length;
      const ppct = pt.length ? Math.round(done / pt.length * 100) : 0;
      return `<tr style="cursor:pointer" data-pid="${p.id}">
        <td><div style="display:flex;align-items:center;gap:8px">
          <div style="width:10px;height:10px;border-radius:50%;background:${p.color};flex-shrink:0"></div>
          <strong>${esc(p.name)}</strong></div></td>
        <td><code style="font-size:.75rem;background:var(--surface-2);padding:2px 6px;border-radius:4px">${esc(p.code || '—')}</code></td>
        <td><span class="badge badge-${p.status}">${p.status}</span></td>
        <td><span class="badge badge-${p.priority}">${p.priority}</span></td>
        <td>${esc(p.pm || '—')}</td>
        <td>${pt.length}</td>
        <td class="cell-progress" style="min-width:80px"><div class="mini-progress-track"><div class="mini-progress-fill" style="width:${ppct}%;background:${p.color}"></div></div><div class="mini-progress-label">${ppct}%</div></td>
        <td>${fmtDate(p.endDate)}</td>
        <td><div class="action-btns">
          <button class="action-btn" data-action="edit" data-pid="${p.id}" title="Edit">✏️</button>
          <button class="action-btn danger" data-action="del" data-pid="${p.id}" title="Delete">🗑️</button>
        </div></td>
      </tr>`;
    }).join('')}</tbody></table></div>`;
  } else {
    container.innerHTML = projects.map(p => {
      const pt = getProjectTasks(p.id);
      const done = pt.filter(t => t.status === 'completed').length;
      const blocked = pt.filter(t => t.status === 'blocked').length;
      const ppct = pt.length ? Math.round(done / pt.length * 100) : 0;
      return `<div class="project-card" data-pid="${p.id}">
        <div class="project-card-stripe" style="background:${p.color}"></div>
        <div class="project-card-body">
          <div class="project-card-header">
            <span class="project-card-title">${esc(p.name)}</span>
            ${p.code ? `<span class="project-card-code">${esc(p.code)}</span>` : ''}
          </div>
          ${p.description ? `<p class="project-card-desc">${esc(p.description)}</p>` : ''}
          <div class="project-card-meta">
            ${p.department ? `<span>📁 ${esc(p.department)}</span>` : ''}
            ${p.pm ? `<span>👤 ${esc(p.pm)}</span>` : ''}
            ${p.endDate ? `<span>📅 ${fmtDate(p.endDate)}</span>` : ''}
            ${blocked ? `<span style="color:#dc2626">🚫 ${blocked}</span>` : ''}
          </div>
          <div class="project-progress-wrap">
            <div class="project-progress-label"><span>${done}/${pt.length} complete</span><span style="font-weight:700">${ppct}%</span></div>
            <div class="project-progress-track"><div class="project-progress-fill" style="width:${ppct}%;background:${p.color}"></div></div>
          </div>
          <div class="project-card-footer">
            <span><span class="badge badge-${p.status}">${p.status}</span> <span class="badge badge-${p.priority}">${p.priority}</span></span>
            <div class="project-card-actions">
              <button class="action-btn" data-action="edit" data-pid="${p.id}" title="Edit">✏️</button>
              <button class="action-btn danger" data-action="del" data-pid="${p.id}" title="Delete">🗑️</button>
            </div>
          </div>
        </div>
      </div>`;
    }).join('');
  }
  container.querySelectorAll('[data-pid]').forEach(el => {
    el.addEventListener('click', e => {
      if (e.target.closest('.action-btn, button')) return;
      openProjectDetail(el.dataset.pid);
    });
  });
  container.querySelectorAll('[data-action="edit"]').forEach(btn =>
    btn.addEventListener('click', e => { e.stopPropagation(); openProjectForm(btn.dataset.pid); })
  );
  container.querySelectorAll('[data-action="del"]').forEach(btn =>
    btn.addEventListener('click', e => { e.stopPropagation(); confirmDeleteProject(btn.dataset.pid); })
  );
}
/* ════════════════════════════════════════════════════════════
   PROJECT DETAIL
   ════════════════════════════════════════════════════════════ */
function renderProjectDetail(pid) {
  const p = findProject(pid);
  if (!p) { switchView('projects'); return; }
  const header = $id('projectDetailHeader');
  if (header) {
    const pt = getProjectTasks(pid);
    const done = pt.filter(t => t.status === 'completed').length;
    const ppct = pt.length ? Math.round(done / pt.length * 100) : 0;
    header.innerHTML = `
      <div class="pdh-top">
        <div class="pdh-color-bar" style="background:${p.color}"></div>
        <div class="pdh-info">
          <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:6px">
            <div class="pdh-title">${esc(p.name)}</div>
            ${p.code ? `<code style="font-size:.75rem;background:var(--surface-2);padding:2px 8px;border-radius:4px;border:1px solid var(--border)">${esc(p.code)}</code>` : ''}
            <span class="badge badge-${p.status}">${p.status}</span>
            <span class="badge badge-${p.priority}">${p.priority}</span>
          </div>
          <div class="pdh-meta">
            ${p.department ? `<span class="pdh-meta-item">📁 ${esc(p.department)}</span>` : ''}
            ${p.pm        ? `<span class="pdh-meta-item">👤 PM: ${esc(p.pm)}</span>` : ''}
            ${p.baTeam    ? `<span class="pdh-meta-item">📊 BA: ${esc(p.baTeam)}</span>` : ''}
            ${p.startDate ? `<span class="pdh-meta-item">📅 ${fmtDate(p.startDate)} → ${fmtDate(p.endDate)}</span>` : ''}
            ${p.budget    ? `<span class="pdh-meta-item">💰 ${Number(p.budget).toLocaleString()}</span>` : ''}
          </div>
        </div>
        <div class="pdh-actions">
          <button class="btn btn-secondary btn-sm" id="pdh-editBtn">Edit</button>
          <button class="btn btn-primary btn-sm" id="pdh-newTaskBtn">+ Task</button>
        </div>
      </div>
      <div class="pdh-stats">
        <div class="pdh-stat"><div class="pdh-stat-num">${pt.length}</div><div class="pdh-stat-lbl">Total</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num">${pt.filter(t=>t.status==='inprogress').length}</div><div class="pdh-stat-lbl">In Progress</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num" style="color:#059669">${done}</div><div class="pdh-stat-lbl">Completed</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num" style="color:#dc2626">${pt.filter(t=>t.status==='blocked').length}</div><div class="pdh-stat-lbl">Blocked</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num" style="color:#d97706">${state.milestones.filter(m=>m.projectId===pid).length}</div><div class="pdh-stat-lbl">Milestones</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num">${state.sprints.filter(s=>s.projectId===pid).length}</div><div class="pdh-stat-lbl">Sprints</div></div>
      </div>
      <div class="pdh-progress" style="margin-top:14px">
        <div style="display:flex;justify-content:space-between;font-size:.82rem;margin-bottom:5px;color:var(--text-3)"><span>Project Completion</span><strong style="color:var(--primary)">${ppct}%</strong></div>
        <div class="progress-track"><div class="progress-fill" style="width:${ppct}%;background:linear-gradient(90deg,${p.color},${p.color}88)"></div></div>
      </div>`;
    $id('pdh-editBtn')?.addEventListener('click', () => openProjectForm(pid));
    $id('pdh-newTaskBtn')?.addEventListener('click', () => openTaskForm(null, pid));
  }
  document.querySelectorAll('.proj-tab').forEach(tab => {
    const clone = tab.cloneNode(true);
    tab.replaceWith(clone);
  });
  document.querySelectorAll('.proj-tab').forEach(tab => {
    const isActive = tab.dataset.ptab === state.activeProjectTab;
    tab.classList.toggle('active', isActive);
    tab.addEventListener('click', () => {
      document.querySelectorAll('.proj-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      state.activeProjectTab = tab.dataset.ptab;
      renderProjectTab(pid, tab.dataset.ptab);
    });
  });
  renderProjectTab(pid, state.activeProjectTab);
}
function renderProjectTab(pid, tab) {
  const el = $id('projTabContent');
  if (!el) return;
  const p = findProject(pid);
  if (!p) return;
  if (tab === 'overview') {
    const pt = getProjectTasks(pid);
    const recent = [...pt].sort((a, b) => (b.updatedAt || '').localeCompare(a.updatedAt || '')).slice(0, 5);
    const open   = pt.filter(t => t.status !== 'completed').slice(0, 5);
    el.innerHTML = `<div class="dashboard-cols">
      <div class="card"><div class="card-header"><h3>Recent Tasks</h3></div>
        <div>${recent.map(t => `<div class="mini-task-item proj-task-link" data-id="${t.id}">
          <div class="mini-task-dot" style="background:${STATUS_META[t.status].dot}"></div>
          <span class="mini-task-title">${esc(t.title)}</span>
          <span class="badge badge-${t.status}" style="font-size:.62rem">${STATUS_META[t.status].label}</span>
        </div>`).join('') || '<p class="no-data">No tasks yet</p>'}</div>
      </div>
      <div class="card"><div class="card-header"><h3>Open Tasks</h3></div>
        <div>${open.map(t => `<div class="mini-task-item proj-task-link" data-id="${t.id}">
          <div class="mini-task-dot" style="background:${STATUS_META[t.status].dot}"></div>
          <span class="mini-task-title">${esc(t.title)}</span>
          <span class="mini-task-meta">${fmtDate(t.dueDate)}</span>
        </div>`).join('') || '<p class="no-data">All tasks complete! 🎉</p>'}</div>
      </div>
    </div>`;
    el.querySelectorAll('.proj-task-link').forEach(item => item.addEventListener('click', () => openTaskDetail(item.dataset.id)));
  }
  if (tab === 'tasks') {
    const pt = getProjectTasks(pid);
    el.innerHTML = `<div style="margin-bottom:10px;display:flex;justify-content:flex-end">
      <button class="btn btn-primary btn-sm" id="ptNewTaskBtn">+ New Task</button>
    </div>
    <div class="table-wrapper">${renderTaskTableHTML(pt)}</div>`;
    $id('ptNewTaskBtn')?.addEventListener('click', () => openTaskForm(null, pid));
    bindTaskTableEvents(el);
  }
  if (tab === 'kanban') {
    el.innerHTML = '<div class="kanban-board" id="projKanban"></div>';
    renderKanbanInto($id('projKanban'), getProjectTasks(pid));
  }
  if (tab === 'milestones') {
    const ms = state.milestones.filter(m => m.projectId === pid).sort((a, b) => a.order - b.order);
    el.innerHTML = `<div style="margin-bottom:10px;display:flex;justify-content:flex-end">
      <button class="btn btn-primary btn-sm" id="newMilestoneBtn">+ Milestone</button>
    </div>
    <div class="milestone-list">
    ${ms.length ? ms.map(m => {
      const mTasks = state.tasks.filter(t => t.milestoneId === m.id);
      const mDone  = mTasks.filter(t => t.status === 'completed').length;
      const icons  = { pending:'⏳', inprogress:'🔄', completed:'✅' };
      return `<div class="milestone-card">
        <div class="milestone-icon ${m.status}">${icons[m.status] || '⏳'}</div>
        <div class="milestone-info">
          <div class="milestone-name">${esc(m.name)}</div>
          <div class="milestone-meta">${m.description ? esc(m.description) + ' · ' : ''}${fmtDate(m.dueDate)}</div>
        </div>
        <span class="milestone-task-count">${mDone}/${mTasks.length} tasks</span>
        <span class="badge badge-${m.status}">${m.status}</span>
        <div class="milestone-actions">
          <button class="action-btn" data-action="edit-ms" data-mid="${m.id}" title="Edit">✏️</button>
          <button class="action-btn danger" data-action="del-ms" data-mid="${m.id}" title="Delete">🗑️</button>
        </div>
      </div>`;
    }).join('') : '<p class="no-data" style="padding:30px">No milestones yet</p>'}
    </div>`;
    $id('newMilestoneBtn')?.addEventListener('click', () => openMilestoneForm(null, pid));
    el.querySelectorAll('[data-action="edit-ms"]').forEach(btn => btn.addEventListener('click', () => openMilestoneForm(btn.dataset.mid, pid)));
    el.querySelectorAll('[data-action="del-ms"]').forEach(btn => btn.addEventListener('click', () => {
      state.milestones = state.milestones.filter(m => m.id !== btn.dataset.mid);
      scheduleSave(); renderProjectTab(pid, 'milestones'); toast('Milestone deleted', 'warning');
    }));
  }
  if (tab === 'sprints') {
    const ss = state.sprints.filter(s => s.projectId === pid).sort((a, b) => a.startDate?.localeCompare(b.startDate));
    const statusColors = { planning: '#7c3aed', active: '#2563eb', completed: '#059669' };
    el.innerHTML = `<div style="margin-bottom:10px;display:flex;justify-content:flex-end">
      <button class="btn btn-primary btn-sm" id="newSprintBtn">+ Sprint</button>
    </div>
    <div class="sprint-list">
    ${ss.length ? ss.map(s => {
      const sTasks = state.tasks.filter(t => t.sprintId === s.id);
      const sDone  = sTasks.filter(t => t.status === 'completed').length;
      const sPct   = sTasks.length ? Math.round(sDone / sTasks.length * 100) : 0;
      return `<div class="sprint-card">
        <div class="sprint-card-header">
          <span class="sprint-name">${esc(s.name)}</span>
          <span class="badge" style="background:${statusColors[s.status]}22;color:${statusColors[s.status]}">${s.status}</span>
          <button class="action-btn" data-action="edit-sp" data-sid="${s.id}" title="Edit">✏️</button>
          <button class="action-btn danger" data-action="del-sp" data-sid="${s.id}" title="Delete">🗑️</button>
        </div>
        ${s.goal ? `<div class="sprint-goal">🎯 ${esc(s.goal)}</div>` : ''}
        <div class="sprint-meta" style="margin-top:6px">
          <span>📅 ${fmtDate(s.startDate)} → ${fmtDate(s.endDate)}</span>
          <span>Tasks: ${sTasks.length}</span>
          ${s.velocity ? `<span>Velocity: ${s.velocity} pts</span>` : ''}
        </div>
        <div style="margin-top:8px">
          <div style="display:flex;justify-content:space-between;font-size:.72rem;color:var(--text-3);margin-bottom:3px"><span>${sDone}/${sTasks.length} done</span><span>${sPct}%</span></div>
          <div class="mini-progress-track" style="height:5px"><div class="mini-progress-fill" style="width:${sPct}%;background:${statusColors[s.status]}"></div></div>
        </div>
      </div>`;
    }).join('') : '<p class="no-data" style="padding:30px">No sprints yet</p>'}
    </div>`;
    $id('newSprintBtn')?.addEventListener('click', () => openSprintForm(null, pid));
    el.querySelectorAll('[data-action="edit-sp"]').forEach(btn => btn.addEventListener('click', () => openSprintForm(btn.dataset.sid, pid)));
    el.querySelectorAll('[data-action="del-sp"]').forEach(btn => btn.addEventListener('click', () => {
      state.sprints = state.sprints.filter(s => s.id !== btn.dataset.sid);
      scheduleSave(); renderProjectTab(pid, 'sprints'); toast('Sprint deleted', 'warning');
    }));
  }
}
/* ════════════════════════════════════════════════════════════
   TASK LIST
   ════════════════════════════════════════════════════════════ */
function getFilteredTasks() {
  let tasks = [...state.tasks];
  const { project, status, priority, ba, milestone, from, to } = state.filters;
  const q = state.searchQuery.toLowerCase();
  if (project)   tasks = tasks.filter(t => t.projectId   === project);
  if (status)    tasks = tasks.filter(t => t.status      === status);
  if (priority)  tasks = tasks.filter(t => t.priority    === priority);
  if (ba)        tasks = tasks.filter(t => t.ba          === ba);
  if (milestone) tasks = tasks.filter(t => t.milestoneId === milestone);
  if (from)      tasks = tasks.filter(t => t.dueDate && t.dueDate >= from);
  if (to)        tasks = tasks.filter(t => t.dueDate && t.dueDate <= to);
  if (q)         tasks = tasks.filter(t =>
    t.title.toLowerCase().includes(q) ||
    (t.ba || '').toLowerCase().includes(q) ||
    (t.description || '').toLowerCase().includes(q) ||
    (t.tags || []).some(tg => tg.toLowerCase().includes(q))
  );
  tasks.sort((a, b) => {
    let va = a[state.sortField] || '', vb = b[state.sortField] || '';
    if (state.sortField === 'priority') { va = PRIORITY_META[va]?.order || 0; vb = PRIORITY_META[vb]?.order || 0; }
    if (va < vb) return state.sortDir === 'asc' ? -1 : 1;
    if (va > vb) return state.sortDir === 'asc' ?  1 : -1;
    return 0;
  });
  tasks.sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
  return tasks;
}
function renderTaskTableHTML(tasks) {
  if (!tasks.length) return '<p class="no-data" style="padding:30px">No tasks</p>';
  return `<table class="task-table"><thead><tr>
    <th class="sortable" data-sort="title">Title ↕</th>
    <th>Project</th>
    <th class="sortable" data-sort="status">Status ↕</th>
    <th class="sortable" data-sort="priority">Priority ↕</th>
    <th class="sortable" data-sort="ba">BA ↕</th>
    <th class="sortable" data-sort="dueDate">Due ↕</th>
    <th>Tags</th>
    <th>Progress</th>
    <th>Actions</th>
  </tr></thead><tbody>
  ${tasks.map(t => renderTaskRow(t)).join('')}
  </tbody></table>`;
}
function renderTaskRow(t) {
  const p = findProject(t.projectId);
  const over = isOverdue(t);
  const prog = calcProgress(t);
  return `<tr class="${over ? 'overdue-row' : ''}" data-id="${t.id}">
    <td class="task-title-cell">
      <span class="task-title-link" data-id="${t.id}">${esc(t.title)}${t.pinned ? ' 📌' : ''}${t.starred ? ' ⭐' : ''}</span>
      ${t.ba ? `<div class="task-ba-sub">👤 ${esc(t.ba)}</div>` : ''}
      ${t.subtasks?.length ? `<div class="task-ba-sub">☑ ${t.subtasks.filter(s=>s.done).length}/${t.subtasks.length} subtasks</div>` : ''}
    </td>
    <td>${p ? `<span class="project-pill" style="background:${p.color}18;color:${p.color};border-color:${p.color}44">${esc(p.name)}</span>` : '<span class="text-muted">—</span>'}</td>
    <td><span class="badge badge-${t.status}">${STATUS_META[t.status].label}</span></td>
    <td><span class="badge badge-${t.priority}">${PRIORITY_META[t.priority].label}</span></td>
    <td>${t.ba ? esc(t.ba) : '<span class="text-muted">—</span>'}</td>
    <td style="color:${over ? '#dc2626' : 'inherit'};white-space:nowrap">${fmtDate(t.dueDate)}</td>
    <td><div class="task-tags">${(t.tags || []).slice(0, 3).map(tg => `<span class="task-tag tag-chip tag-color-${getTagColor(tg)}">${esc(tg)}</span>`).join('')}${t.tags?.length > 3 ? `<span class="task-tag tag-chip tag-color-7">+${t.tags.length - 3}</span>` : ''}</div></td>
    <td class="cell-progress"><div class="mini-progress-track"><div class="mini-progress-fill" style="width:${prog}%"></div></div><div class="mini-progress-label">${prog}%</div></td>
    <td><div class="action-btns">
      <button class="action-btn" data-action="view"   data-id="${t.id}" title="View">👁</button>
      <button class="action-btn" data-action="edit"   data-id="${t.id}" title="Edit">✏️</button>
      <button class="action-btn" data-action="star"   data-id="${t.id}" title="Star" style="color:${t.starred ? '#d97706' : ''}">⭐</button>
      <button class="action-btn danger" data-action="delete" data-id="${t.id}" title="Delete">🗑️</button>
    </div></td>
  </tr>`;
}
function bindTaskTableEvents(container) {
  container.querySelectorAll('.task-title-link').forEach(el =>
    el.addEventListener('click', () => openTaskDetail(el.dataset.id))
  );
  container.querySelectorAll('[data-action]').forEach(btn => {
    btn.addEventListener('click', e => {
      e.stopPropagation();
      const { action, id } = btn.dataset;
      if (action === 'view')   openTaskDetail(id);
      if (action === 'edit')   openTaskForm(id);
      if (action === 'delete') confirmDeleteTask(id);
      if (action === 'star') {
        const t = findTask(id); if (t) { t.starred = !t.starred; scheduleSave(); refreshView(); toast(t.starred ? 'Starred ⭐' : 'Star removed', 'info'); }
      }
    });
  });
  container.querySelectorAll('th.sortable').forEach(th => {
    th.addEventListener('click', () => {
      const field = th.dataset.sort;
      if (state.sortField === field) state.sortDir = state.sortDir === 'asc' ? 'desc' : 'asc';
      else { state.sortField = field; state.sortDir = 'asc'; }
      refreshView();
    });
  });
}
function renderTaskList() {
  refreshProjectFilter();
  refreshBAFilter();
  refreshMilestoneFilter();
  const tasks = getFilteredTasks();
  const cl = $id('taskCountLabel');
  if (cl) cl.textContent = `${tasks.length} task${tasks.length !== 1 ? 's' : ''}`;
  const title = $id('tasksViewTitle');
  if (title) {
    const p = state.activeProjectId ? findProject(state.activeProjectId) : null;
    title.textContent = p ? `${p.name} — Tasks` : 'All Tasks';
  }
  const tbody = $id('taskTableBody'), empty = $id('emptyState');
  if (!tasks.length) {
    if (tbody) tbody.innerHTML = '';
    if (empty) empty.style.display = '';
    return;
  }
  if (empty) empty.style.display = 'none';
  if (tbody) tbody.innerHTML = tasks.map(t => renderTaskRow(t)).join('');
  const wrap = document.querySelector('#view-tasks .table-wrapper');
  if (wrap) bindTaskTableEvents(wrap);
}
function refreshProjectFilter() {
  const sel = $id('filterProject'), ksel = $id('kanbanProjectFilter'), gsel = $id('ganttProjectFilter'), asel = $id('analyticsProjectFilter');
  [sel, ksel, gsel, asel].forEach(s => {
    if (!s) return;
    const cur = s.value;
    s.innerHTML = '<option value="">All Projects</option>' +
      state.projects.map(p => `<option value="${esc(p.id)}" ${cur === p.id ? 'selected' : ''}>${esc(p.name)}</option>`).join('');
  });
}
function refreshBAFilter() {
  const sel = $id('filterBA'); if (!sel) return;
  const cur = sel.value;
  sel.innerHTML = '<option value="">All BAs</option>' + getBAList().map(b => `<option value="${esc(b)}" ${cur === b ? 'selected' : ''}>${esc(b)}</option>`).join('');
}
function refreshMilestoneFilter() {
  const sel = $id('filterMilestone'); if (!sel) return;
  const cur = sel.value;
  sel.innerHTML = '<option value="">All Milestones</option>' + state.milestones.map(m => `<option value="${esc(m.id)}" ${cur === m.id ? 'selected' : ''}>${esc(m.name)}</option>`).join('');
}
/* ════════════════════════════════════════════════════════════
   KANBAN
   ════════════════════════════════════════════════════════════ */
function renderKanban() {
  const pid = $id('kanbanProjectFilter')?.value || '';
  const title = $id('kanbanViewTitle');
  if (title) { const p = pid ? findProject(pid) : null; title.textContent = p ? `${p.name} — Kanban` : 'Kanban Board'; }
  const tasks = pid ? getProjectTasks(pid) : state.tasks;
  renderKanbanInto($id('kanbanBoard'), tasks);
}
function renderKanbanInto(board, tasks) {
  if (!board) return;
  const cols = [
    { id:'pending',    label:'Pending',     color:'#fbbf24' },
    { id:'inprogress', label:'In Progress', color:'#60a5fa' },
    { id:'completed',  label:'Completed',   color:'#34d399' },
    { id:'blocked',    label:'Blocked',     color:'#f87171' },
  ];
  board.innerHTML = cols.map(col => {
    const colTasks = tasks.filter(t => t.status === col.id);
    return `<div class="kanban-column" data-status="${col.id}">
      <div class="kanban-col-header">
        <div class="kanban-col-dot" style="background:${col.color}"></div>
        <span class="kanban-col-title">${col.label}</span>
        <span class="kanban-col-count">${colTasks.length}</span>
      </div>
      <div class="kanban-cards" data-status="${col.id}">
        ${colTasks.map(t => {
          const p = findProject(t.projectId);
          const over = isOverdue(t);
          const prog = calcProgress(t);
          return `<div class="kanban-card" draggable="true" data-id="${t.id}">
            <div class="kanban-card-top">
              <span class="kanban-card-title task-title-link" data-id="${t.id}">${esc(t.title)}</span>
              <span class="badge badge-${t.priority}" style="font-size:.62rem">${PRIORITY_META[t.priority].label}</span>
            </div>
            ${p ? `<div class="kanban-card-project"><span class="project-pill" style="background:${p.color}18;color:${p.color};border-color:${p.color}44;font-size:.65rem">${esc(p.name)}</span></div>` : ''}
            ${t.tags?.length ? `<div class="kanban-card-tags">${t.tags.slice(0,3).map(tg=>`<span class="tag-chip tag-color-${getTagColor(tg)}" style="font-size:.65rem;padding:1px 5px">${esc(tg)}</span>`).join('')}</div>` : ''}
            <div class="kanban-card-meta">
              ${t.ba ? `<span>👤 ${esc(t.ba)}</span>` : '<span></span>'}
              ${t.dueDate ? `<span style="color:${over?'#dc2626':'inherit'}">${over?'⚠️':''} ${fmtDate(t.dueDate)}</span>` : ''}
            </div>
            ${prog ? `<div class="mini-progress-track" style="margin-top:6px"><div class="mini-progress-fill" style="width:${prog}%"></div></div>` : ''}
          </div>`;
        }).join('')}
      </div>
    </div>`;
  }).join('');
  board.querySelectorAll('.kanban-card').forEach(card => {
    card.addEventListener('dragstart', e => { state.draggedTaskId = card.dataset.id; card.classList.add('dragging'); e.dataTransfer.effectAllowed = 'move'; });
    card.addEventListener('dragend', () => { card.classList.remove('dragging'); board.querySelectorAll('.kanban-column').forEach(c => c.classList.remove('drag-over')); });
  });
  board.querySelectorAll('.kanban-cards').forEach(drop => {
    drop.addEventListener('dragover', e => { e.preventDefault(); drop.closest('.kanban-column').classList.add('drag-over'); });
    drop.addEventListener('dragleave', () => drop.closest('.kanban-column').classList.remove('drag-over'));
    drop.addEventListener('drop', e => {
      e.preventDefault();
      drop.closest('.kanban-column').classList.remove('drag-over');
      const newStatus = drop.dataset.status;
      if (state.draggedTaskId) {
        const t = findTask(state.draggedTaskId);
        if (t && t.status !== newStatus) {
          const old = t.status; t.status = newStatus; t.updatedAt = today();
          if (newStatus === 'completed') t.progress = 100;
          addActivity(t, `Status changed from "${STATUS_META[old].label}" to "${STATUS_META[newStatus].label}"`);
          scheduleSave(); renderKanban(); renderDashboard();
          toast(`Moved to ${STATUS_META[newStatus].label}`, 'success');
        }
      }
    });
  });
  board.querySelectorAll('.task-title-link').forEach(el => el.addEventListener('click', () => openTaskDetail(el.dataset.id)));
}
/* ════════════════════════════════════════════════════════════
   CALENDAR
   ════════════════════════════════════════════════════════════ */
function renderCalendar() {
  const d = state.calendarDate;
  const y = d.getFullYear(), m = d.getMonth();
  const lbl = $id('calMonthLabel');
  if (lbl) lbl.textContent = d.toLocaleDateString('en-GB', { month:'long', year:'numeric' });
  const wrap = $id('calendarWrap');
  if (!wrap) return;
  const firstDay = new Date(y, m, 1).getDay();
  const daysInMonth = new Date(y, m + 1, 0).getDate();
  const todayStr = today();
  const days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  let html = `<div class="calendar-grid-header">${days.map(n => `<div class="cal-day-name">${n}</div>`).join('')}</div>`;
  html += `<div class="calendar-grid-body">`;
  for (let i = 0; i < firstDay; i++) html += `<div class="cal-cell other-month"></div>`;
  for (let day = 1; day <= daysInMonth; day++) {
    const ds = `${y}-${String(m+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`;
    const isToday = ds === todayStr;
    const dayTasks = state.tasks.filter(t => t.dueDate === ds);
    html += `<div class="cal-cell${isToday?' today':''}">
      <div class="cal-date">${day}</div>
      ${dayTasks.slice(0,3).map(t=>`<div class="cal-task-dot ${t.status}" data-id="${t.id}" title="${esc(t.title)}">${esc(t.title)}</div>`).join('')}
      ${dayTasks.length>3?`<div class="cal-task-dot" style="color:var(--text-3)">+${dayTasks.length-3} more</div>`:''}
    </div>`;
  }
  html += `</div>`;
  wrap.innerHTML = html;
  wrap.querySelectorAll('.cal-task-dot[data-id]').forEach(el => el.addEventListener('click', () => openTaskDetail(el.dataset.id)));
}
/* ════════════════════════════════════════════════════════════
   GANTT TIMELINE
   ════════════════════════════════════════════════════════════ */
function renderGantt() {
  const container = $id('ganttContainer');
  if (!container) return;
  const filterPid = $id('ganttProjectFilter')?.value || '';
  const months    = parseInt($id('ganttRangeFilter')?.value || '6');
  const todayDate = new Date(); todayDate.setHours(0,0,0,0);
  const ganttStart = new Date(todayDate.getFullYear(), todayDate.getMonth() - 1, 1);
  const ganttEnd   = new Date(ganttStart.getFullYear(), ganttStart.getMonth() + months + 1, 1);
  const totalDays  = (ganttEnd - ganttStart) / 86400000;
  const projects = filterPid ? state.projects.filter(p => p.id === filterPid) : state.projects.filter(p => p.status !== 'archived');
  if (!projects.length) { container.innerHTML = '<div class="gantt-empty">No projects to display</div>'; return; }
  const monthCells = [];
  let cur = new Date(ganttStart);
  while (cur < ganttEnd) {
    const mStart = new Date(cur);
    const mEnd   = new Date(cur.getFullYear(), cur.getMonth() + 1, 1);
    const dStart = Math.max(0, (mStart - ganttStart) / 86400000);
    const dEnd   = Math.min(totalDays, (mEnd - ganttStart) / 86400000);
    const w = ((dEnd - dStart) / totalDays * 100).toFixed(2);
    monthCells.push(`<div class="gantt-month-cell" style="width:${w}%;min-width:60px;flex-shrink:0">${cur.toLocaleDateString('en-GB',{month:'short',year:'2-digit'})}</div>`);
    cur = mEnd;
  }
  const leftRows = [], rightRows = [];
  const barPct = (dateStr) => {
    const d = new Date(dateStr + 'T00:00:00');
    const days = Math.max(0, Math.min(totalDays, (d - ganttStart) / 86400000));
    return (days / totalDays * 100).toFixed(2);
  };
  projects.forEach(p => {
    leftRows.push(`<div class="gantt-row-left project-row"><span style="width:10px;height:10px;border-radius:50%;background:${p.color};flex-shrink:0;display:inline-block"></span><span class="gantt-row-name" title="${esc(p.name)}">${esc(p.name)}</span></div>`);
    const pS = p.startDate ? barPct(p.startDate) : '0';
    const pE = p.endDate   ? barPct(p.endDate)   : '100';
    const pW = Math.max(0.5, parseFloat(pE) - parseFloat(pS));
    rightRows.push(`<div class="gantt-row-right"><div class="gantt-bar" style="left:${pS}%;width:${pW}%;background:${p.color}" title="${esc(p.name)}">${esc(p.name)}</div></div>`);
    state.milestones.filter(m => m.projectId === p.id).forEach(m => {
      leftRows.push(`<div class="gantt-row-left milestone-row">◆ <span class="gantt-row-name" title="${esc(m.name)}">${esc(m.name)}</span></div>`);
      if (m.dueDate) {
        const mPct = barPct(m.dueDate);
        rightRows.push(`<div class="gantt-row-right"><div class="gantt-milestone-marker" style="left:${mPct}%;background:${STATUS_META[m.status]?.dot || '#fbbf24'}" title="${esc(m.name)} — ${fmtDate(m.dueDate)}"></div></div>`);
      } else {
        rightRows.push(`<div class="gantt-row-right"></div>`);
      }
    });
    getProjectTasks(p.id).forEach(t => {
      if (!t.startDate && !t.dueDate) return;
      leftRows.push(`<div class="gantt-row-left task-row"><span class="gantt-row-name" title="${esc(t.title)}" data-id="${t.id}">${esc(t.title)}</span></div>`);
      const tS = t.startDate ? barPct(t.startDate) : barPct(t.dueDate || todayDate.toISOString().split('T')[0]);
      const tE = t.dueDate   ? barPct(t.dueDate)   : tS;
      const tW = Math.max(0.5, parseFloat(tE) - parseFloat(tS));
      const bColor = STATUS_META[t.status]?.color || '#2563eb';
      rightRows.push(`<div class="gantt-row-right"><div class="gantt-bar" style="left:${tS}%;width:${tW}%;background:${bColor};opacity:.85" data-id="${t.id}" title="${esc(t.title)}">${esc(t.title)}</div></div>`);
    });
  });
  const todayPct = ((todayDate - ganttStart) / 86400000 / totalDays * 100).toFixed(2);
  const colLines = monthCells.map((_, i) => {
    const d2 = new Date(ganttStart.getFullYear(), ganttStart.getMonth() + i, 1);
    const pct = ((d2 - ganttStart) / 86400000 / totalDays * 100).toFixed(2);
    return `<div class="gantt-col-line" style="left:${pct}%"></div>`;
  }).join('');
  container.innerHTML = `
    <div style="display:flex;border-bottom:2px solid var(--border)">
      <div class="gantt-left-header">Project / Task</div>
      <div style="flex:1;overflow-x:auto" id="ganttScrollHeader">
        <div class="gantt-month-labels">${monthCells.join('')}</div>
      </div>
    </div>
    <div style="display:flex;overflow-y:auto;max-height:520px">
      <div class="gantt-left-body">${leftRows.join('')}</div>
      <div style="flex:1;overflow-x:auto;position:relative" id="ganttScrollBody">
        <div style="position:relative;min-width:100%">
          ${colLines}
          <div class="gantt-today-line" style="left:${todayPct}%"></div>
          ${rightRows.join('')}
        </div>
      </div>
    </div>`;
  const sh = $id('ganttScrollHeader'), sb2 = $id('ganttScrollBody');
  sb2?.addEventListener('scroll', () => { if (sh) sh.scrollLeft = sb2.scrollLeft; });
  container.querySelectorAll('[data-id]').forEach(el =>
    el.addEventListener('click', () => openTaskDetail(el.dataset.id))
  );
}
/* ════════════════════════════════════════════════════════════
   ANALYTICS
   ════════════════════════════════════════════════════════════ */
function renderAnalytics() {
  const container = $id('analyticsContainer');
  if (!container) return;
  const pid   = $id('analyticsProjectFilter')?.value || '';
  const tasks = pid ? getProjectTasks(pid) : state.tasks;
  const statusCounts = { pending:0, inprogress:0, completed:0, blocked:0 };
  tasks.forEach(t => statusCounts[t.status]++);
  const priCounts = { low:0, medium:0, high:0, critical:0 };
  tasks.forEach(t => priCounts[t.priority]++);
  const baMap = {};
  tasks.forEach(t => { if (t.ba) baMap[t.ba] = (baMap[t.ba] || 0) + 1; });
  const baEntries = Object.entries(baMap).sort((a, b) => b[1] - a[1]).slice(0, 8);
  const projProg = state.projects.filter(p => p.status !== 'archived').map(p => {
    const pt = getProjectTasks(p.id);
    const done = pt.filter(t => t.status === 'completed').length;
    return { name: p.name, pct: pt.length ? Math.round(done / pt.length * 100) : 0, color: p.color, total: pt.length };
  });
  const sCols = { pending:'#fbbf24', inprogress:'#60a5fa', completed:'#34d399', blocked:'#f87171' };
  const pCols = { low:'#34d399', medium:'#60a5fa', high:'#fcd34d', critical:'#f87171' };
  container.innerHTML = `
    <div class="analytics-grid">
      <div class="analytics-card">
        <h3>Tasks by Status</h3>
        ${Object.entries(statusCounts).map(([s, v]) => `
          <div class="hbar-item">
            <div class="hbar-label-row">
              <span class="hbar-label">${STATUS_META[s].label}</span>
              <span class="hbar-value">${v} (${tasks.length ? Math.round(v/tasks.length*100) : 0}%)</span>
            </div>
            <div class="hbar-track"><div class="hbar-fill" style="width:${tasks.length ? v/tasks.length*100 : 0}%;background:${sCols[s]}"></div></div>
          </div>`).join('')}
      </div>
      <div class="analytics-card">
        <h3>Tasks by Priority</h3>
        ${Object.entries(priCounts).map(([p, v]) => `
          <div class="hbar-item">
            <div class="hbar-label-row">
              <span class="hbar-label">${PRIORITY_META[p].label}</span>
              <span class="hbar-value">${v}</span>
            </div>
            <div class="hbar-track"><div class="hbar-fill" style="width:${tasks.length ? v/tasks.length*100 : 0}%;background:${pCols[p]}"></div></div>
          </div>`).join('')}
      </div>
      <div class="analytics-card">
        <h3>Project Progress</h3>
        ${projProg.map(pp => `
          <div class="hbar-item">
            <div class="hbar-label-row">
              <span class="hbar-label">${esc(pp.name)}</span>
              <span class="hbar-value">${pp.pct}% · ${pp.total} tasks</span>
            </div>
            <div class="hbar-track"><div class="hbar-fill" style="width:${pp.pct}%;background:${pp.color}"></div></div>
          </div>`).join('') || '<p class="no-data">No projects</p>'}
      </div>
      <div class="analytics-card">
        <h3>BA Workload</h3>
        ${baEntries.length ? baEntries.map(([name, count]) => {
          const u = state.users.find(u => u.name === name);
          return `<div class="hbar-item">
            <div class="hbar-label-row">
              <span class="hbar-label" style="display:flex;align-items:center;gap:6px">
                <span style="width:20px;height:20px;border-radius:50%;background:${u?.color||'#2563eb'};display:inline-flex;align-items:center;justify-content:center;font-size:.6rem;color:#fff;font-weight:700;flex-shrink:0">${u?.avatar||name.slice(0,2).toUpperCase()}</span>
                ${esc(name)}
              </span>
              <span class="hbar-value">${count}</span>
            </div>
            <div class="hbar-track"><div class="hbar-fill" style="width:${baEntries[0][1]?count/baEntries[0][1]*100:0}%;background:${u?.color||'#2563eb'}"></div></div>
          </div>`;
        }).join('') : '<p class="no-data">No assignments</p>'}
      </div>
      <div class="analytics-card">
        <h3>Summary KPIs</h3>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
          ${[
            { label:'Completion Rate', val: tasks.length ? Math.round(statusCounts.completed/tasks.length*100)+'%' : '—', color:'#059669' },
            { label:'Blocked Rate',    val: tasks.length ? Math.round(statusCounts.blocked/tasks.length*100)+'%'  : '—', color:'#dc2626' },
            { label:'Overdue Tasks',   val: tasks.filter(isOverdue).length, color:'#d97706' },
            { label:'Critical Tasks',  val: tasks.filter(t=>t.priority==='critical').length, color:'#7c3aed' },
            { label:'Total Projects',  val: state.projects.filter(p=>p.status==='active').length+' active', color:'#2563eb' },
            { label:'Total Hours Est', val: tasks.reduce((a,t)=>a+(t.estimatedHours||0),0)+'h', color:'#0891b2' },
          ].map(kpi => `
            <div style="background:var(--surface-2);border:1px solid var(--border);border-radius:var(--radius);padding:12px;text-align:center">
              <div style="font-size:1.4rem;font-weight:800;color:${kpi.color}">${kpi.val}</div>
              <div style="font-size:.68rem;color:var(--text-3);text-transform:uppercase;letter-spacing:.04em;margin-top:3px">${kpi.label}</div>
            </div>`).join('')}
        </div>
      </div>
      <div class="analytics-card">
        <h3>Risk Indicators</h3>
        ${[
          { label: 'Overdue tasks',           count: tasks.filter(isOverdue).length,                          level: tasks.filter(isOverdue).length > 3 ? 'high' : tasks.filter(isOverdue).length > 0 ? 'medium' : 'low' },
          { label: 'Blocked critical tasks',  count: tasks.filter(t=>t.status==='blocked'&&t.priority==='critical').length, level: tasks.filter(t=>t.status==='blocked'&&t.priority==='critical').length > 0 ? 'high' : 'low' },
          { label: 'Tasks without due date',  count: tasks.filter(t=>!t.dueDate&&t.status!=='completed').length, level: 'medium' },
          { label: 'Unassigned critical',     count: tasks.filter(t=>!t.ba&&t.priority==='critical').length,  level: tasks.filter(t=>!t.ba&&t.priority==='critical').length > 0 ? 'high' : 'low' },
        ].map(r => `
          <div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
            <span style="font-size:.82rem;color:var(--text-2)">${r.label}</span>
            <div style="display:flex;align-items:center;gap:8px">
              <span style="font-weight:700;font-size:.9rem">${r.count}</span>
              <span class="risk-badge risk-${r.level}">${r.level}</span>
            </div>
          </div>`).join('')}
      </div>
    </div>`;
}
/* ════════════════════════════════════════════════════════════
   TEAM
   ════════════════════════════════════════════════════════════ */
function renderTeam() {
  const container = $id('teamContainer');
  if (!container) return;
  if (!state.users.length) {
    container.innerHTML = '<p class="no-data" style="padding:40px">No team members yet</p>';
    return;
  }
  const roleColors = { 'Business Analyst':'#2563eb','Senior BA':'#7c3aed','UI/UX Designer':'#db2777','Tech Lead':'#059669','QA Engineer':'#d97706','Developer':'#0891b2' };
  container.innerHTML = `<div class="team-grid">${state.users.map(u => {
    const assigned = state.tasks.filter(t => t.ba === u.name || t.assignee === u.id);
    const open  = assigned.filter(t => t.status !== 'completed').length;
    const done  = assigned.filter(t => t.status === 'completed').length;
    const blkd  = assigned.filter(t => t.status === 'blocked').length;
    const maxTasks = Math.max(...state.users.map(uu => state.tasks.filter(t=>t.ba===uu.name||t.assignee===uu.id).length), 1);
    const wlPct = Math.round(assigned.length / maxTasks * 100);
    const avatarHtml = u.avatarUrl
      ? `<img src="${esc(u.avatarUrl)}" style="width:44px;height:44px;border-radius:50%;object-fit:cover;flex-shrink:0" onerror="this.outerHTML='<div class=\\'team-avatar\\' style=\\'background:${u.color}\\'>${esc(u.avatar)}</div>'">`
      : (u.avatarPreset != null
          ? `<div class="team-avatar" style="background:${u.color}">${AVATAR_PRESETS[u.avatarPreset]?.icon || esc(u.avatar)}</div>`
          : `<div class="team-avatar" style="background:${u.color}">${esc(u.avatar)}</div>`);
    const skillsHtml = u.skills?.length
      ? `<div style="margin-top:8px;display:flex;flex-wrap:wrap;gap:4px">${u.skills.map(s=>`<span class="tag-chip" style="font-size:.65rem;padding:2px 6px">${esc(s)}</span>`).join('')}</div>`
      : '';
    const emailHtml = u.email ? `<a href="mailto:${esc(u.email)}" style="font-size:.68rem;color:var(--accent);text-decoration:none">${esc(u.email)}</a>` : '';
    return `<div class="team-card">
      <div class="team-card-top">
        ${avatarHtml}
        <div style="flex:1;min-width:0">
          <div class="team-name">${esc(u.name)}</div>
          <div class="team-role" style="color:${roleColors[u.role]||'var(--text-3)'}">${esc(u.role || '')}</div>
          <div style="font-size:.7rem;color:var(--text-3)">${esc(u.team || '')}</div>
          ${emailHtml}
        </div>
        <button class="btn btn-ghost btn-sm" onclick="openMemberForm('${u.id}')" style="align-self:flex-start;padding:2px 8px;font-size:.72rem">Edit</button>
      </div>
      <div class="team-stats">
        <div class="team-stat"><div class="team-stat-num">${open}</div><div class="team-stat-lbl">Open</div></div>
        <div class="team-stat"><div class="team-stat-num" style="color:#059669">${done}</div><div class="team-stat-lbl">Done</div></div>
        <div class="team-stat"><div class="team-stat-num" style="color:#dc2626">${blkd}</div><div class="team-stat-lbl">Blocked</div></div>
      </div>
      <div class="team-workload">
        <div class="team-workload-label"><span>Workload</span><span>${wlPct}%</span></div>
        <div class="workload-bar"><div class="workload-fill" style="width:${wlPct}%;background:${wlPct>80?'#dc2626':wlPct>50?'#d97706':u.color}"></div></div>
      </div>
      ${skillsHtml}
    </div>`;
  }).join('')}</div>`;
}
/* ════════════════════════════════════════════════════════════
   MEMBER FORM
   ════════════════════════════════════════════════════════════ */
let memberFormSkills = [];
let memberFormPreset = null;

function openMemberForm(userId) {
  const u = userId ? state.users.find(x => x.id === userId) : null;
  memberFormSkills = u ? [...(u.skills || [])] : [];
  memberFormPreset = u ? (u.avatarPreset ?? null) : null;

  $id('memberFormTitle').textContent = u ? 'Edit Team Member' : 'Add Team Member';
  $id('mbrId').value = u?.id || '';
  setVal('mbrName',      u?.name      || '');
  setVal('mbrRole',      u?.role      || '');
  setVal('mbrTeam',      u?.team      || '');
  setVal('mbrEmail',     u?.email     || '');
  setVal('mbrPhone',     u?.phone     || '');
  setVal('mbrAvatarUrl', u?.avatarUrl || '');

  renderAvatarPresetGrid();
  renderMemberSkillChips();
  openOverlay('memberFormOverlay');
  setTimeout(() => $id('mbrName')?.focus(), 100);
}

function renderAvatarPresetGrid() {
  const grid = $id('avatarPresetGrid');
  if (!grid) return;
  grid.innerHTML = AVATAR_PRESETS.map((p, i) =>
    `<button type="button" class="avatar-preset-btn${memberFormPreset === i ? ' selected' : ''}" data-idx="${i}" style="background:${p.color}" title="Avatar ${i+1}">${p.icon}</button>`
  ).join('');
  grid.querySelectorAll('.avatar-preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      memberFormPreset = parseInt(btn.dataset.idx);
      grid.querySelectorAll('.avatar-preset-btn').forEach(b => b.classList.toggle('selected', b === btn));
      $id('mbrAvatarUrl').value = '';
    });
  });
}

function renderMemberSkillChips() {
  const wrap = $id('mbrSkillChips');
  if (!wrap) return;
  wrap.innerHTML = memberFormSkills.map((s, i) =>
    `<span class="tag-chip">${esc(s)}<button type="button" class="tag-remove" data-i="${i}">×</button></span>`
  ).join('');
  wrap.querySelectorAll('.tag-remove').forEach(btn => {
    btn.addEventListener('click', () => {
      memberFormSkills.splice(parseInt(btn.dataset.i), 1);
      renderMemberSkillChips();
    });
  });
}

function saveMember() {
  const name = $id('mbrName')?.value.trim();
  if (!name) { toast('Name is required', 'error'); return; }

  const avatarUrl  = $id('mbrAvatarUrl')?.value.trim() || '';
  const avatarPreset = avatarUrl ? null : memberFormPreset;
  const color = avatarPreset != null
    ? AVATAR_PRESETS[avatarPreset].color
    : PROJECT_COLORS[state.users.length % PROJECT_COLORS.length];
  const avatar = name.slice(0, 2).toUpperCase();

  const existingId = $id('mbrId')?.value;
  if (existingId) {
    const u = state.users.find(x => x.id === existingId);
    if (u) {
      u.name        = name;
      u.role        = $id('mbrRole')?.value.trim()  || '';
      u.team        = $id('mbrTeam')?.value.trim()  || '';
      u.email       = $id('mbrEmail')?.value.trim() || '';
      u.phone       = $id('mbrPhone')?.value.trim() || '';
      u.avatarUrl   = avatarUrl;
      u.avatarPreset= avatarPreset;
      u.color       = color;
      u.avatar      = avatar;
      u.skills      = [...memberFormSkills];
    }
    toast(`${name} updated`, 'success');
  } else {
    state.users.push({
      id: uid(), name, role: $id('mbrRole')?.value.trim() || '',
      team: $id('mbrTeam')?.value.trim() || '',
      email: $id('mbrEmail')?.value.trim() || '',
      phone: $id('mbrPhone')?.value.trim() || '',
      avatar, color, avatarUrl, avatarPreset,
      skills: [...memberFormSkills],
    });
    toast(`${name} added to team`, 'success');
  }

  closeOverlay('memberFormOverlay');
  scheduleSave();
  renderTeam();
}

/* ════════════════════════════════════════════════════════════
   TASK FORM
   ════════════════════════════════════════════════════════════ */
function openTaskForm(taskId = null, presetProjectId = null) {
  const task = taskId ? findTask(taskId) : null;
  $id('formTitle').textContent = task ? 'Edit Task' : 'New Task';
  $id('fId').value = task?.id || '';
  state.formTags     = task ? [...(task.tags || [])]     : [];
  state.formDocs     = task ? (task.documents||[]).map(d=>({...d})) : [];
  state.formSubtasks = task ? (task.subtasks||[]).map(s=>({...s}))  : [];
  document.querySelectorAll('.form-tab').forEach((t,i) => t.classList.toggle('active', i===0));
  document.querySelectorAll('.form-tab-panel').forEach((p,i) => p.classList.toggle('active', i===0));
  const projSel = $id('fProject');
  if (projSel) {
    projSel.innerHTML = '<option value="">Select project…</option>' +
      state.projects.map(p => `<option value="${esc(p.id)}" ${(task?.projectId||presetProjectId)===p.id?'selected':''}>${esc(p.name)}</option>`).join('');
    updateDependentSelectors(task?.projectId || presetProjectId);
    projSel.addEventListener('change', () => updateDependentSelectors(projSel.value));
  }
  setVal('fTitle',       task?.title       || '');
  setVal('fDesc',        task?.description || '');
  setVal('fPriority',    task?.priority    || 'medium');
  setVal('fStatus',      task?.status      || 'pending');
  setVal('fStartDate',   task?.startDate   || '');
  setVal('fDueDate',     task?.dueDate     || '');
  setVal('fBA',          task?.ba          || '');
  setVal('fHours',       task?.estimatedHours || '');
  setVal('fActualHours', task?.actualHours || '');
  setVal('fProgress',    task?.progress    || 0);
  setVal('fNotes',       task?.notes       || '');
  const pv = $id('fProgressVal'); if (pv) pv.textContent = (task?.progress || 0) + '%';
  const asSel = $id('fAssignee');
  if (asSel) {
    asSel.innerHTML = '<option value="">Unassigned</option>' +
      state.users.map(u => `<option value="${esc(u.id)}" ${task?.assignee===u.id?'selected':''}>${esc(u.name)}</option>`).join('');
  }
  const dl = $id('baDatalist');
  if (dl) dl.innerHTML = getBAList().map(b => `<option value="${esc(b)}">`).join('');
  renderFormTags(); renderFormDocs(); renderFormSubtasks();
  openOverlay('formOverlay');
  setTimeout(() => $id('fTitle')?.focus(), 100);
}
function updateDependentSelectors(pid) {
  const ms = state.milestones.filter(m => m.projectId === pid);
  const ss = state.sprints.filter(s => s.projectId === pid);
  const curTask = $id('fId')?.value;
  const mSel = $id('fMilestone');
  if (mSel) mSel.innerHTML = '<option value="">No milestone</option>' + ms.map(m => `<option value="${esc(m.id)}">${esc(m.name)}</option>`).join('');
  const sSel = $id('fSprint');
  if (sSel) sSel.innerHTML = '<option value="">No sprint</option>' + ss.map(s => `<option value="${esc(s.id)}">${esc(s.name)}</option>`).join('');
  const pSel = $id('fParent');
  if (pSel) pSel.innerHTML = '<option value="">Top-level task</option>' +
    state.tasks.filter(t => t.projectId === pid && t.id !== curTask).map(t => `<option value="${esc(t.id)}">${esc(t.title)}</option>`).join('');
  const dSel = $id('fDeps');
  if (dSel) dSel.innerHTML = state.tasks.filter(t => t.id !== curTask).map(t => `<option value="${esc(t.id)}">${esc(t.title)}</option>`).join('');
}
function renderFormTags() {
  const chips = $id('tagChips');
  if (!chips) return;
  chips.innerHTML = state.formTags.map((tg, i) => `
    <span class="tag-chip tag-color-${getTagColor(tg)}">${esc(tg)}<span class="tag-chip-remove" data-i="${i}">×</span></span>`).join('');
}
function renderFormDocs() {
  const list = $id('docsList');
  if (!list) return;
  list.innerHTML = state.formDocs.map((doc, i) => `
    <div class="doc-row" data-di="${i}">
      <input type="text"  class="doc-title-inp" placeholder="Document title"  value="${esc(doc.title||'')}" style="flex:1;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text);font-size:.85rem;outline:none"/>
      <input type="url"   class="doc-url-inp"   placeholder="https://…"        value="${esc(doc.url||'')}"   style="flex:2;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text);font-size:.85rem;outline:none"/>
      <button type="button" class="doc-remove" data-di="${i}" title="Remove">
        <svg viewBox="0 0 20 20" fill="currentColor" width="13" height="13"><path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/></svg>
      </button>
    </div>`).join('');
}
function renderFormSubtasks() {
  const list = $id('subtaskList');
  if (!list) return;
  list.innerHTML = state.formSubtasks.map((st, i) => `
    <div class="subtask-item">
      <input type="checkbox" class="subtask-checkbox" ${st.done ? 'checked' : ''} data-si="${i}"/>
      <input type="text" class="subtask-input ${st.done ? 'done' : ''}" value="${esc(st.title)}" placeholder="Subtask title…" data-si="${i}"/>
      <button type="button" class="subtask-remove" data-si="${i}" title="Remove">×</button>
    </div>`).join('');
}
function saveTask() {
  const title = $id('fTitle')?.value.trim();
  if (!title) { markError('fTitle', 'Title is required'); return; }
  const projectId = $id('fProject')?.value;
  if (!projectId) { markError('fProject', 'Please select a project'); return; }
  state.formDocs = [];
  document.querySelectorAll('#docsList .doc-row').forEach(row => {
    const t2 = row.querySelector('.doc-title-inp')?.value.trim();
    const u2 = row.querySelector('.doc-url-inp')?.value.trim();
    if (t2 || u2) state.formDocs.push({ title: t2 || '', url: u2 || '' });
  });
  state.formSubtasks = [];
  document.querySelectorAll('#subtaskList .subtask-item').forEach(row => {
    const t2 = row.querySelector('.subtask-input')?.value.trim();
    const d2 = row.querySelector('.subtask-checkbox')?.checked;
    if (t2) state.formSubtasks.push({ id: uid(), title: t2, done: !!d2 });
  });
  const deps = [...($id('fDeps')?.selectedOptions || [])].map(o => o.value);
  const progress = state.formSubtasks.length ? Math.round(state.formSubtasks.filter(s=>s.done).length / state.formSubtasks.length * 100) : parseInt($id('fProgress')?.value || 0);
  const taskId = $id('fId')?.value;
  const existing = taskId ? findTask(taskId) : null;
  const data = {
    id:             existing?.id || uid(),
    title,
    description:    $id('fDesc')?.value.trim()      || '',
    projectId,
    milestoneId:    $id('fMilestone')?.value        || '',
    sprintId:       $id('fSprint')?.value           || '',
    parentTaskId:   $id('fParent')?.value           || '',
    priority:       $id('fPriority')?.value         || 'medium',
    status:         $id('fStatus')?.value           || 'pending',
    startDate:      $id('fStartDate')?.value        || '',
    dueDate:        $id('fDueDate')?.value          || '',
    ba:             $id('fBA')?.value.trim()        || '',
    assignee:       $id('fAssignee')?.value         || '',
    estimatedHours: parseFloat($id('fHours')?.value) || 0,
    actualHours:    parseFloat($id('fActualHours')?.value) || 0,
    tags:           [...state.formTags],
    documents:      [...state.formDocs],
    dependencies:   deps,
    subtasks:       [...state.formSubtasks],
    progress,
    notes:          $id('fNotes')?.value.trim()     || '',
    starred:        existing?.starred               || false,
    pinned:         existing?.pinned                || false,
    createdAt:      existing?.createdAt             || today(),
    updatedAt:      today(),
    activity:       existing?.activity              || [],
  };
  if (existing) {
    addActivity(data, 'Task updated');
    Object.assign(existing, data);
    toast('Task updated', 'success');
  } else {
    data.activity = [{ time: today(), desc: 'Task created' }];
    state.tasks.unshift(data);
    toast('Task created', 'success');
  }
  closeOverlay('formOverlay');
  scheduleSave();
  refreshView();
  updateNavBadges();
}
function markError(id, msg) {
  const el = $id(id);
  if (!el) return;
  const fg = el.closest('.form-group');
  if (fg) {
    fg.classList.add('has-error');
    if (!fg.querySelector('.field-error')) {
      const e = document.createElement('span');
      e.className = 'field-error'; e.textContent = msg;
      fg.appendChild(e);
    }
  }
  el.focus();
}
/* ════════════════════════════════════════════════════════════
   TASK DETAIL MODAL
   ════════════════════════════════════════════════════════════ */
function openTaskDetail(taskId) {
  const t = findTask(taskId);
  if (!t) return;
  $id('detailTitle').textContent = t.title;
  $id('detailStatusBadge').innerHTML = `<span class="badge badge-${t.status}">${STATUS_META[t.status].label}</span>`;
  $id('detailStarBtn').style.opacity = t.starred ? '1' : '0.5';
  const p = findProject(t.projectId);
  const depTasks = (t.dependencies || []).map(id => findTask(id)).filter(Boolean);
  const body = $id('detailBody');
  if (!body) return;
  body.innerHTML = `
    ${p ? `<div style="margin-bottom:14px"><span class="project-pill" style="background:${p.color}18;color:${p.color};border:1px solid ${p.color}44">📁 ${esc(p.name)}</span>${t.milestoneId ? ` <span class="badge badge-info" style="font-size:.72rem">◆ ${esc(state.milestones.find(m=>m.id===t.milestoneId)?.name||'')}</span>` : ''}</div>` : ''}
    <div class="detail-grid">
      <div class="detail-field"><label>Priority</label><span><span class="badge badge-${t.priority}">${PRIORITY_META[t.priority].label}</span></span></div>
      <div class="detail-field"><label>Status</label><span><span class="badge badge-${t.status}">${STATUS_META[t.status].label}</span></span></div>
      <div class="detail-field"><label>Assigned BA</label><span>${t.ba ? esc(t.ba) : '—'}</span></div>
      <div class="detail-field"><label>Assignee</label><span>${t.assignee ? esc(state.users.find(u=>u.id===t.assignee)?.name||t.assignee) : '—'}</span></div>
      <div class="detail-field"><label>Start Date</label><span>${fmtDate(t.startDate)}</span></div>
      <div class="detail-field"><label>Due Date</label><span style="color:${isOverdue(t)?'#dc2626':'inherit'}">${fmtDate(t.dueDate)}${isOverdue(t)?' ⚠️':''}</span></div>
      <div class="detail-field"><label>Estimated Hours</label><span>${t.estimatedHours || 0} hrs</span></div>
      <div class="detail-field"><label>Actual Hours</label><span>${t.actualHours || 0} hrs</span></div>
      <div class="detail-field full">
        <label>Progress — ${calcProgress(t)}%</label>
        <div class="progress-track" style="height:8px;margin-top:4px"><div class="progress-fill" style="width:${calcProgress(t)}%"></div></div>
      </div>
    </div>
    ${t.description ? `<div class="detail-section"><h4>Description</h4><p style="font-size:.85rem;color:var(--text-2);line-height:1.6">${esc(t.description)}</p></div>` : ''}
    ${t.tags?.length ? `<div class="detail-section"><h4>Tags</h4><div style="display:flex;flex-wrap:wrap;gap:6px">${t.tags.map(tg=>`<span class="tag-chip tag-color-${getTagColor(tg)}">${esc(tg)}</span>`).join('')}</div></div>` : ''}
    ${t.subtasks?.length ? `<div class="detail-section"><h4>Subtasks (${t.subtasks.filter(s=>s.done).length}/${t.subtasks.length})</h4>
      ${t.subtasks.map(s=>`<div class="subtask-detail-item ${s.done?'done':''}">
        <span>${s.done?'✅':'⬜'}</span><span>${esc(s.title)}</span>
      </div>`).join('')}</div>` : ''}
    ${t.documents?.length ? `<div class="detail-section"><h4>Reference Documents</h4>
      ${t.documents.map(doc=>`<div class="doc-link-row">
        <span>📄</span>
        <a href="${esc(doc.url)}" target="_blank" rel="noopener">${esc(doc.title||doc.url)}</a>
        <button class="doc-copy-btn" data-url="${esc(doc.url)}">Copy</button>
      </div>`).join('')}</div>` : ''}
    ${depTasks.length ? `<div class="detail-section"><h4>Dependencies (${depTasks.length})</h4>
      ${depTasks.map(dt=>`<div class="dep-item" data-id="${dt.id}">
        <div class="mini-task-dot" style="background:${STATUS_META[dt.status].dot}"></div>
        <span class="dep-item-title">${esc(dt.title)}</span>
        <span class="badge badge-${dt.status}">${STATUS_META[dt.status].label}</span>
      </div>`).join('')}</div>` : ''}
    ${t.notes ? `<div class="detail-section"><h4>Notes</h4><p style="font-size:.85rem;color:var(--text-2);line-height:1.6;white-space:pre-wrap">${esc(t.notes)}</p></div>` : ''}
    <div class="detail-section"><h4>Activity (${t.activity?.length || 0})</h4>
      ${(t.activity||[]).slice().reverse().slice(0,8).map(a=>`<div class="activity-item">
        <span class="activity-time">${fmtDate(a.time)}</span>
        <span style="color:var(--text-2)">${esc(a.desc)}</span>
      </div>`).join('') || '<p class="no-data">No activity</p>'}
    </div>`;
  body.querySelectorAll('.doc-copy-btn').forEach(btn =>
    btn.addEventListener('click', () => navigator.clipboard?.writeText(btn.dataset.url).then(() => toast('Link copied!', 'info')))
  );
  body.querySelectorAll('.dep-item[data-id]').forEach(el =>
    el.addEventListener('click', () => { closeOverlay('detailOverlay'); openTaskDetail(el.dataset.id); })
  );
  $id('detailEditBtn').onclick   = () => { closeOverlay('detailOverlay'); openTaskForm(taskId); };
  $id('detailDeleteBtn').onclick = () => { closeOverlay('detailOverlay'); confirmDeleteTask(taskId); };
  $id('detailStarBtn').onclick   = () => {
    t.starred = !t.starred;
    $id('detailStarBtn').style.opacity = t.starred ? '1' : '0.5';
    scheduleSave(); refreshView();
    toast(t.starred ? 'Starred ⭐' : 'Unstarred', 'info');
  };
  openOverlay('detailOverlay');
}
/* ════════════════════════════════════════════════════════════
   PROJECT FORM
   ════════════════════════════════════════════════════════════ */
let _projectTags = [];
function openProjectForm(projectId = null) {
  const p = projectId ? findProject(projectId) : null;
  $id('projectFormTitle').textContent = p ? 'Edit Project' : 'New Project';
  $id('pfId').value = p?.id || '';
  _projectTags = p ? [...(p.tags || [])] : [];
  setVal('pfName',   p?.name        || '');
  setVal('pfCode',   p?.code        || '');
  setVal('pfDept',   p?.department  || '');
  setVal('pfDesc',   p?.description || '');
  setVal('pfPM',     p?.pm          || '');
  setVal('pfBATeam', p?.baTeam      || '');
  setVal('pfStatus', p?.status      || 'active');
  setVal('pfPriority',p?.priority   || 'medium');
  setVal('pfStart',  p?.startDate   || '');
  setVal('pfEnd',    p?.endDate     || '');
  setVal('pfBudget', p?.budget      || '');
  setVal('pfColor',  p?.color       || '#2563eb');
  const cp = $id('projectColorPicker');
  if (cp) cp.innerHTML = PROJECT_COLORS.map(c => `
    <div class="color-swatch${(p?.color||'#2563eb')===c?' selected':''}" style="background:${c}" data-color="${c}" title="${c}"></div>`).join('');
  renderProjectFormTags();
  openOverlay('projectFormOverlay');
  setTimeout(() => $id('pfName')?.focus(), 80);
}
function renderProjectFormTags() {
  const chips = $id('pTagChips');
  if (!chips) return;
  chips.innerHTML = _projectTags.map((tg, i) => `
    <span class="tag-chip tag-color-${getTagColor(tg)}">${esc(tg)}<span class="tag-chip-remove" data-pi="${i}">×</span></span>`).join('');
}
function saveProject() {
  const name = $id('pfName')?.value.trim();
  if (!name) { markError('pfName', 'Project name is required'); return; }
  const pid = $id('pfId')?.value;
  const existing = pid ? findProject(pid) : null;
  const data = {
    id:          existing?.id   || uid(),
    name,
    code:        $id('pfCode')?.value.trim()   || '',
    description: $id('pfDesc')?.value.trim()   || '',
    department:  $id('pfDept')?.value.trim()   || '',
    pm:          $id('pfPM')?.value.trim()     || '',
    baTeam:      $id('pfBATeam')?.value.trim() || '',
    status:      $id('pfStatus')?.value        || 'active',
    priority:    $id('pfPriority')?.value      || 'medium',
    startDate:   $id('pfStart')?.value         || '',
    endDate:     $id('pfEnd')?.value           || '',
    budget:      parseFloat($id('pfBudget')?.value) || 0,
    color:       $id('pfColor')?.value         || '#2563eb',
    tags:        [..._projectTags],
    createdAt:   existing?.createdAt           || today(),
    updatedAt:   today(),
  };
  if (existing) {
    Object.assign(existing, data);
    toast('Project updated', 'success');
  } else {
    state.projects.push(data);
    toast(`Project "${name}" created`, 'success');
  }
  closeOverlay('projectFormOverlay');
  scheduleSave();
  refreshView();
  updateNavBadges();
  updateSidebarProjects();
}
function confirmDeleteProject(pid) {
  const p = findProject(pid);
  if (!p) return;
  $id('confirmHeading').textContent = 'Delete Project';
  $id('confirmMsg').textContent = `Delete "${p.name}" and all its milestones & sprints? Tasks will remain but lose project association. This cannot be undone.`;
  $id('confirmOkBtn').textContent = 'Delete Project';
  $id('confirmOkBtn').onclick = () => {
    state.projects   = state.projects.filter(x => x.id !== pid);
    state.milestones = state.milestones.filter(m => m.projectId !== pid);
    state.sprints    = state.sprints.filter(s => s.projectId !== pid);
    state.tasks.filter(t => t.projectId === pid).forEach(t => { t.projectId = ''; });
    if (state.activeProjectId === pid) state.activeProjectId = null;
    closeOverlay('confirmOverlay');
    scheduleSave(); updateNavBadges(); updateSidebarProjects();
    switchView('projects');
    toast('Project deleted', 'warning');
  };
  openOverlay('confirmOverlay');
}
/* ════════════════════════════════════════════════════════════
   MILESTONE FORM
   ════════════════════════════════════════════════════════════ */
function openMilestoneForm(milestoneId = null, projectId = null) {
  const m = milestoneId ? state.milestones.find(x => x.id === milestoneId) : null;
  $id('milestoneFormTitle').textContent = m ? 'Edit Milestone' : 'Add Milestone';
  $id('mfId').value        = m?.id        || '';
  $id('mfProjectId').value = m?.projectId || projectId || '';
  setVal('mfName',   m?.name        || '');
  setVal('mfDesc',   m?.description || '');
  setVal('mfDue',    m?.dueDate     || '');
  setVal('mfStatus', m?.status      || 'pending');
  openOverlay('milestoneFormOverlay');
}
function saveMilestone() {
  const name = $id('mfName')?.value.trim();
  if (!name) { toast('Milestone name is required', 'error'); return; }
  const mid = $id('mfId').value;
  const existing = mid ? state.milestones.find(m => m.id === mid) : null;
  const data = {
    id:          existing?.id || uid(),
    projectId:   $id('mfProjectId').value,
    name,
    description: $id('mfDesc')?.value.trim() || '',
    dueDate:     $id('mfDue')?.value || '',
    status:      $id('mfStatus')?.value || 'pending',
    order:       existing?.order ?? state.milestones.filter(m=>m.projectId===$id('mfProjectId').value).length,
    createdAt:   existing?.createdAt || today(),
  };
  if (existing) Object.assign(existing, data);
  else state.milestones.push(data);
  closeOverlay('milestoneFormOverlay');
  scheduleSave(); refreshView();
  toast(existing ? 'Milestone updated' : 'Milestone added', 'success');
}
/* ════════════════════════════════════════════════════════════
   SPRINT FORM
   ════════════════════════════════════════════════════════════ */
function openSprintForm(sprintId = null, projectId = null) {
  const s = sprintId ? state.sprints.find(x => x.id === sprintId) : null;
  $id('sprintFormTitle').textContent = s ? 'Edit Sprint' : 'New Sprint';
  $id('sfId').value        = s?.id        || '';
  $id('sfProjectId').value = s?.projectId || projectId || '';
  setVal('sfName',   s?.name   || '');
  setVal('sfGoal',   s?.goal   || '');
  setVal('sfStart',  s?.startDate || '');
  setVal('sfEnd',    s?.endDate   || '');
  setVal('sfStatus', s?.status    || 'planning');
  openOverlay('sprintFormOverlay');
}
function saveSprint() {
  const name = $id('sfName')?.value.trim();
  if (!name) { toast('Sprint name is required', 'error'); return; }
  const sid = $id('sfId').value;
  const existing = sid ? state.sprints.find(s => s.id === sid) : null;
  const data = {
    id:          existing?.id || uid(),
    projectId:   $id('sfProjectId').value,
    name,
    goal:        $id('sfGoal')?.value.trim() || '',
    startDate:   $id('sfStart')?.value || '',
    endDate:     $id('sfEnd')?.value   || '',
    status:      $id('sfStatus')?.value || 'planning',
    velocity:    existing?.velocity || 0,
    createdAt:   existing?.createdAt || today(),
  };
  if (existing) Object.assign(existing, data);
  else state.sprints.push(data);
  closeOverlay('sprintFormOverlay');
  scheduleSave(); refreshView();
  toast(existing ? 'Sprint updated' : 'Sprint added', 'success');
}
/* ════════════════════════════════════════════════════════════
   DELETE TASK
   ════════════════════════════════════════════════════════════ */
function confirmDeleteTask(taskId) {
  const t = findTask(taskId);
  if (!t) return;
  $id('confirmHeading').textContent = 'Delete Task';
  $id('confirmMsg').textContent = `Delete "${t.title}"? This cannot be undone.`;
  $id('confirmOkBtn').textContent = 'Delete';
  $id('confirmOkBtn').onclick = () => {
    state.tasks = state.tasks.filter(x => x.id !== taskId);
    state.tasks.forEach(x => { x.dependencies = (x.dependencies||[]).filter(id => id !== taskId); });
    closeOverlay('confirmOverlay');
    scheduleSave(); refreshView(); updateNavBadges();
    toast('Task deleted', 'warning');
  };
  openOverlay('confirmOverlay');
}
/* ════════════════════════════════════════════════════════════
   GLOBAL SEARCH
   ════════════════════════════════════════════════════════════ */
function handleSearch(q) {
  state.searchQuery = q;
  const dropdown = $id('searchDropdown');
  if (!dropdown) return;
  if (!q.trim()) { dropdown.classList.remove('open'); return; }
  const results = [
    ...state.tasks.filter(t => t.title.toLowerCase().includes(q.toLowerCase()) || (t.ba||'').toLowerCase().includes(q.toLowerCase())).slice(0, 4).map(t => ({
      type: 'task', id: t.id, label: t.title, sub: `${STATUS_META[t.status].label} · ${PRIORITY_META[t.priority].label}${t.ba?' · '+t.ba:''}`, dot: STATUS_META[t.status].dot,
    })),
    ...state.projects.filter(p => p.name.toLowerCase().includes(q.toLowerCase())).slice(0, 3).map(p => ({
      type: 'project', id: p.id, label: p.name, sub: `Project · ${p.status}`, dot: p.color,
    })),
  ].slice(0, 7);
  if (!results.length) { dropdown.classList.remove('open'); return; }
  dropdown.innerHTML = results.map(r => `
    <div class="search-result-item" data-type="${r.type}" data-id="${r.id}">
      <div class="mini-task-dot" style="background:${r.dot}"></div>
      <div><strong>${esc(r.label)}</strong><br><span>${esc(r.sub)}</span></div>
    </div>`).join('');
  dropdown.classList.add('open');
}
/* ════════════════════════════════════════════════════════════
   COMMAND PALETTE
   ════════════════════════════════════════════════════════════ */
const CMD_LIST = [
  { icon:'📋', label:'Dashboard',      sub:'Go to dashboard',       action:()=>switchView('dashboard'),  kbd:'1' },
  { icon:'📁', label:'Projects',       sub:'Go to projects',        action:()=>switchView('projects'),   kbd:'2' },
  { icon:'✅', label:'All Tasks',      sub:'Go to task list',       action:()=>switchView('tasks'),      kbd:'3' },
  { icon:'📊', label:'Kanban Board',   sub:'Go to kanban',          action:()=>switchView('kanban'),     kbd:'4' },
  { icon:'📅', label:'Calendar',       sub:'Go to calendar',        action:()=>switchView('calendar'),   kbd:'5' },
  { icon:'📏', label:'Gantt Timeline', sub:'Go to gantt',           action:()=>switchView('gantt'),      kbd:'6' },
  { icon:'📈', label:'Analytics',      sub:'Go to analytics',       action:()=>switchView('analytics'),  kbd:'7' },
  { icon:'👥', label:'Team',           sub:'Go to team',            action:()=>switchView('team'),       kbd:'8' },
  { icon:'➕', label:'New Task',        sub:'/newtask',              action:()=>openTaskForm(),           kbd:'N' },
  { icon:'🗂', label:'New Project',    sub:'/newproject',           action:()=>openProjectForm(),        kbd:'P' },
  { icon:'🔒', label:'Blocked Tasks',  sub:'Filter blocked tasks',  action:()=>{ state.filters.status='blocked'; switchView('tasks'); } },
  { icon:'⚠️', label:'Critical Tasks', sub:'Filter critical tasks', action:()=>{ state.filters.priority='critical'; switchView('tasks'); } },
  { icon:'⭐', label:'Starred Tasks',  sub:'Show starred tasks',    action:()=>{ state.searchQuery=''; switchView('tasks'); } },
];
function openCommandPalette() {
  state.cmdIndex = 0;
  $id('commandInput').value = '';
  renderCommandResults('');
  openOverlay('commandOverlay');
  setTimeout(() => $id('commandInput')?.focus(), 60);
}
function renderCommandResults(q) {
  const el = $id('commandResults');
  if (!el) return;
  const query = q.toLowerCase().replace(/^\//, '');
  const cmds = query
    ? CMD_LIST.filter(c => c.label.toLowerCase().includes(query) || c.sub.toLowerCase().includes(query))
    : CMD_LIST;
  const recentTasks = !query ? state.tasks.filter(t => t.status !== 'completed').slice(0, 3).map(t => ({
    icon: STATUS_META[t.status].dot, label: t.title, sub: `Task · ${STATUS_META[t.status].label}`,
    action: () => { closeOverlay('commandOverlay'); openTaskDetail(t.id); }, isTask: true,
  })) : [];
  el.innerHTML = `
    ${cmds.length ? `<div class="command-group-title">Commands</div>
      ${cmds.map((c, i) => `<div class="command-item${i === state.cmdIndex ? ' focused' : ''}" data-ci="${i}">
        <div class="command-item-icon">${c.icon}</div>
        <div><div class="command-item-label">${esc(c.label)}</div><div class="command-item-sub">${esc(c.sub)}</div></div>
        ${c.kbd ? `<span class="command-item-kbd">${c.kbd}</span>` : ''}
      </div>`).join('')}` : ''}
    ${recentTasks.length ? `<div class="command-group-title">Recent Open Tasks</div>
      ${recentTasks.map((r, i) => `<div class="command-item" data-ri="${i}" style="cursor:pointer">
        <div class="command-item-icon" style="background:${r.icon}18">●</div>
        <div><div class="command-item-label">${esc(r.label)}</div><div class="command-item-sub">${esc(r.sub)}</div></div>
      </div>`).join('')}` : ''}
    ${!cmds.length && !recentTasks.length ? '<div class="no-data" style="padding:20px">No results</div>' : ''}`;
  el.querySelectorAll('.command-item[data-ci]').forEach(item => {
    item.addEventListener('click', () => {
      const cmd = cmds[parseInt(item.dataset.ci)];
      if (cmd) { closeOverlay('commandOverlay'); cmd.action(); }
    });
  });
  el.querySelectorAll('.command-item[data-ri]').forEach(item => {
    item.addEventListener('click', () => {
      const t = recentTasks[parseInt(item.dataset.ri)];
      if (t) { closeOverlay('commandOverlay'); t.action(); }
    });
  });
}
/* ════════════════════════════════════════════════════════════
   IMPORT / EXPORT
   ════════════════════════════════════════════════════════════ */
function exportJSON() {
  const d = JSON.stringify({ projects:state.projects, tasks:state.tasks, milestones:state.milestones, sprints:state.sprints, users:state.users, exportedAt: new Date().toISOString() }, null, 2);
  dlFile(d, 'taskflow_export.json', 'application/json');
  toast(`Exported ${state.tasks.length} tasks across ${state.projects.length} projects`, 'success');
}
function exportCSV() {
  const cols = ['id','title','projectName','status','priority','ba','dueDate','startDate','estimatedHours','progress','tags','notes'];
  const rows = [cols.join(',')];
  state.tasks.forEach(t => {
    const p = findProject(t.projectId);
    rows.push(cols.map(c => {
      let v = c === 'tags' ? (t.tags||[]).join(';') : c === 'projectName' ? (p?.name||'') : (t[c] ?? '');
      return `"${String(v).replace(/"/g,'""')}"`;
    }).join(','));
  });
  dlFile(rows.join('\n'), 'taskflow_tasks.csv', 'text/csv');
  toast(`Exported ${state.tasks.length} tasks as CSV`, 'success');
}
function importJSON(file) {
  const reader = new FileReader();
  reader.onload = e => {
    try {
      const d = JSON.parse(e.target.result);
      if (d.projects)   state.projects   = d.projects;
      if (d.tasks)      state.tasks      = d.tasks;
      if (d.milestones) state.milestones = d.milestones;
      if (d.sprints)    state.sprints    = d.sprints;
      if (d.users)      state.users      = d.users;
      scheduleSave(); refreshView(); updateNavBadges(); updateSidebarProjects();
      toast(`Imported ${state.tasks.length} tasks, ${state.projects.length} projects`, 'success');
    } catch(err) { toast('Import failed: ' + err.message, 'error'); }
  };
  reader.readAsText(file);
}
function dlFile(content, name, type) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const a = Object.assign(document.createElement('a'), { href:url, download:name });
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
/* ════════════════════════════════════════════════════════════
   THEME
   ════════════════════════════════════════════════════════════ */
function setTheme(theme) {
  state.settings.theme = theme;
  document.documentElement.setAttribute('data-theme', theme);
  const lbl = $id('themeLabel');
  if (lbl) lbl.textContent = theme === 'dark' ? 'Light Mode' : 'Dark Mode';
}
/* ════════════════════════════════════════════════════════════
   TOAST
   ════════════════════════════════════════════════════════════ */
const TOAST_ICONS = {
  success: `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>`,
  error:   `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>`,
  warning: `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>`,
  info:    `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/></svg>`,
};
function toast(msg, type = 'info', dur = 3500) {
  const c = $id('toastContainer');
  if (!c) return;
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = `${TOAST_ICONS[type] || ''}<span class="toast-msg">${esc(msg)}</span><span class="toast-close">×</span>`;
  el.querySelector('.toast-close').addEventListener('click', () => el.remove());
  c.appendChild(el);
  setTimeout(() => el.remove(), dur + 300);
}
/* ════════════════════════════════════════════════════════════
   EVENT BINDING
   ════════════════════════════════════════════════════════════ */
   
function bindEvents() {

  try {
    document.querySelectorAll('.nav-link[data-view]').forEach(link =>
      link.addEventListener('click', e => { e.preventDefault(); switchView(link.dataset.view); })
    );
    $id('sidebarCollapseBtn')?.addEventListener('click', () =>
      $id('sidebar').classList.toggle('collapsed')
    );
    $id('menuBtn')?.addEventListener('click', () =>
      $id('sidebar').classList.toggle('mobile-open')
    );
    $id('themeToggle')?.addEventListener('click', () => {
      setTheme(state.settings.theme === 'dark' ? 'light' : 'dark');
      scheduleSave();
    });
    ['newTaskBtn','newTaskBtnList','emptyCreateBtn'].forEach(id =>
      $id(id)?.addEventListener('click', () => openTaskForm(null, state.activeProjectId))
    );
    ['newProjectBtn','newProjectTopBtn','newProjectSidebarBtn'].forEach(id =>
      $id(id)?.addEventListener('click', e => { e.preventDefault(); openProjectForm(); })
    );
    $id('formClose')?.addEventListener('click',  () => closeOverlay('formOverlay'));
    $id('formCancel')?.addEventListener('click', () => closeOverlay('formOverlay'));
    $id('formSave')?.addEventListener('click',   saveTask);
    document.querySelectorAll('.form-tab').forEach(tab => {
      tab.addEventListener('click', () => {
        document.querySelectorAll('.form-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.form-tab-panel').forEach(p => p.classList.remove('active'));
        tab.classList.add('active');
        document.querySelector(`.form-tab-panel[data-ftabpanel="${tab.dataset.ftab}"]`)?.classList.add('active');
      });
    });
    $id('fProgress')?.addEventListener('input', e => {
      const pv = $id('fProgressVal'); if (pv) pv.textContent = e.target.value + '%';
    });
    $id('fTagInput')?.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ',') {
        e.preventDefault();
        const val = e.target.value.trim().replace(/,$/, '');
        if (val && !state.formTags.includes(val)) { state.formTags.push(val); renderFormTags(); }
        e.target.value = '';
      }
      if (e.key === 'Backspace' && !e.target.value && state.formTags.length) { state.formTags.pop(); renderFormTags(); }
    });
    $id('tagInputWrap')?.addEventListener('click', () => $id('fTagInput')?.focus());
    $id('tagChips')?.addEventListener('click', e => {
      const btn = e.target.closest('.tag-chip-remove');
      if (btn) { state.formTags.splice(parseInt(btn.dataset.i), 1); renderFormTags(); }
    });
    $id('pfTagInput')?.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ',') {
        e.preventDefault();
        const val = e.target.value.trim().replace(/,$/, '');
        if (val && !_projectTags.includes(val)) { _projectTags.push(val); renderProjectFormTags(); }
        e.target.value = '';
      }
      if (e.key === 'Backspace' && !e.target.value && _projectTags.length) { _projectTags.pop(); renderProjectFormTags(); }
    });
    $id('pTagInputWrap')?.addEventListener('click', () => $id('pfTagInput')?.focus());
    $id('pTagChips')?.addEventListener('click', e => {
      const btn = e.target.closest('.tag-chip-remove');
      if (btn) { _projectTags.splice(parseInt(btn.dataset.pi), 1); renderProjectFormTags(); }
    });
    document.getElementById('projectColorPicker')?.addEventListener('click', e => {
      const sw = e.target.closest('.color-swatch');
      if (sw) {
        document.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
        sw.classList.add('selected');
        setVal('pfColor', sw.dataset.color);
      }
    });
    $id('addDocBtn')?.addEventListener('click', () => { state.formDocs.push({ title:'', url:'' }); renderFormDocs(); });
    $id('docsList')?.addEventListener('click', e => {
      const btn = e.target.closest('.doc-remove');
      if (btn) { state.formDocs.splice(parseInt(btn.dataset.di), 1); renderFormDocs(); }
    });
    $id('addSubtaskBtn')?.addEventListener('click', () => {
      state.formSubtasks.push({ id: uid(), title: '', done: false });
      renderFormSubtasks();
      const inputs = document.querySelectorAll('#subtaskList .subtask-input');
      inputs[inputs.length - 1]?.focus();
    });
    $id('subtaskList')?.addEventListener('change', e => {
      if (e.target.classList.contains('subtask-checkbox')) {
        const i = parseInt(e.target.dataset.si);
        if (state.formSubtasks[i]) {
          state.formSubtasks[i].done = e.target.checked;
          const inp = document.querySelector(`#subtaskList .subtask-input[data-si="${i}"]`);
          if (inp) inp.classList.toggle('done', e.target.checked);
        }
      }
    });
    $id('subtaskList')?.addEventListener('input', e => {
      if (e.target.classList.contains('subtask-input')) {
        const i = parseInt(e.target.dataset.si);
        if (state.formSubtasks[i]) state.formSubtasks[i].title = e.target.value;
      }
    });
    $id('subtaskList')?.addEventListener('click', e => {
      const btn = e.target.closest('.subtask-remove');
      if (btn) { state.formSubtasks.splice(parseInt(btn.dataset.si), 1); renderFormSubtasks(); }
    });
    $id('memberFormClose')?.addEventListener('click',  () => closeOverlay('memberFormOverlay'));
    $id('memberFormCancel')?.addEventListener('click', () => closeOverlay('memberFormOverlay'));
    $id('memberFormSave')?.addEventListener('click',   saveMember);
    $id('mbrSkillInput')?.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ',') {
        e.preventDefault();
        const val = e.target.value.trim();
        if (val && !memberFormSkills.includes(val)) { memberFormSkills.push(val); renderMemberSkillChips(); }
        e.target.value = '';
      }
    });
    $id('projectFormClose')?.addEventListener('click',  () => closeOverlay('projectFormOverlay'));
    $id('projectFormCancel')?.addEventListener('click', () => closeOverlay('projectFormOverlay'));
    $id('projectFormSave')?.addEventListener('click',   saveProject);
    $id('milestoneFormClose')?.addEventListener('click',  () => closeOverlay('milestoneFormOverlay'));
    $id('milestoneFormCancel')?.addEventListener('click', () => closeOverlay('milestoneFormOverlay'));
    $id('milestoneFormSave')?.addEventListener('click',   saveMilestone);
    $id('sprintFormClose')?.addEventListener('click',  () => closeOverlay('sprintFormOverlay'));
    $id('sprintFormCancel')?.addEventListener('click', () => closeOverlay('sprintFormOverlay'));
    $id('sprintFormSave')?.addEventListener('click',   saveSprint);
    $id('detailClose')?.addEventListener('click', () => closeOverlay('detailOverlay'));
    $id('confirmCancelBtn')?.addEventListener('click', () => closeOverlay('confirmOverlay'));
    document.querySelectorAll('.overlay').forEach(overlay =>
      overlay.addEventListener('click', e => { if (e.target === overlay) overlay.classList.remove('open'); })
    );
    const filterMap = { filterProject:'project', filterStatus:'status', filterPriority:'priority', filterBA:'ba', filterMilestone:'milestone', filterFrom:'from', filterTo:'to' };
    Object.entries(filterMap).forEach(([id, key]) =>
      $id(id)?.addEventListener('change', e => { state.filters[key] = e.target.value; renderTaskList(); })
    );
    $id('clearFiltersBtn')?.addEventListener('click', () => {
      state.filters = { project:'', status:'', priority:'', ba:'', milestone:'', from:'', to:'' };
      Object.keys(filterMap).forEach(id => { const el = $id(id); if (el) el.value = ''; });
      renderTaskList();
    });
    $id('projectStatusFilter')?.addEventListener('change', renderProjects);
    $id('projGridBtn')?.addEventListener('click', () => {
      state.projectViewMode = 'grid';
      $id('projGridBtn').classList.add('active');
      $id('projListBtn').classList.remove('active');
      renderProjects();
    });
    $id('projListBtn')?.addEventListener('click', () => {
      state.projectViewMode = 'list';
      $id('projListBtn').classList.add('active');
      $id('projGridBtn').classList.remove('active');
      renderProjects();
    });
    $id('clearActiveProjectBtn')?.addEventListener('click', () => {
      state.activeProjectId = null;
      updateSidebarProjects();
      $id('clearActiveProjectBtn').style.display = 'none';
      switchView('dashboard');
    });
    $id('kanbanProjectFilter')?.addEventListener('change', renderKanban);
    $id('calPrev')?.addEventListener('click', () => {
      state.calendarDate = new Date(state.calendarDate.getFullYear(), state.calendarDate.getMonth() - 1, 1);
      renderCalendar();
    });
    $id('calNext')?.addEventListener('click', () => {
      state.calendarDate = new Date(state.calendarDate.getFullYear(), state.calendarDate.getMonth() + 1, 1);
      renderCalendar();
    });
    $id('ganttProjectFilter')?.addEventListener('change', renderGantt);
    $id('ganttRangeFilter')?.addEventListener('change',   renderGantt);
    $id('analyticsProjectFilter')?.addEventListener('change', renderAnalytics);
    $id('newUserBtn')?.addEventListener('click', () => openMemberForm(null));
    $id('globalSearch')?.addEventListener('input', e => handleSearch(e.target.value));
    $id('searchDropdown')?.addEventListener('click', e => {
      const item = e.target.closest('.search-result-item');
      if (item) {
        $id('globalSearch').value = '';
        $id('searchDropdown').classList.remove('open');
        if (item.dataset.type === 'task')    openTaskDetail(item.dataset.id);
        if (item.dataset.type === 'project') openProjectDetail(item.dataset.id);
      }
    });
    document.addEventListener('click', e => {
      if (!e.target.closest('.search-box'))
        $id('searchDropdown')?.classList.remove('open');
    });
    $id('commandPaletteBtn')?.addEventListener('click', openCommandPalette);
    $id('commandInput')?.addEventListener('input', e => renderCommandResults(e.target.value));
    $id('commandInput')?.addEventListener('keydown', e => {
      const items = document.querySelectorAll('.command-item[data-ci]');
      if (e.key === 'ArrowDown') { e.preventDefault(); state.cmdIndex = Math.min(state.cmdIndex + 1, items.length - 1); }
      if (e.key === 'ArrowUp')   { e.preventDefault(); state.cmdIndex = Math.max(state.cmdIndex - 1, 0); }
      if (e.key === 'Enter' && items[state.cmdIndex]) items[state.cmdIndex].click();
      items.forEach((item, i) => item.classList.toggle('focused', i === state.cmdIndex));
    });
    $id('exportJsonBtn')?.addEventListener('click', e => { e.preventDefault(); exportJSON(); });
    $id('exportCsvBtn')?.addEventListener('click',  e => { e.preventDefault(); exportCSV(); });
    $id('importJsonBtn')?.addEventListener('click', e => { e.preventDefault(); $id('importFileInput').click(); });
    $id('importFileInput')?.addEventListener('change', e => { const f = e.target.files[0]; if (f) { importJSON(f); e.target.value = ''; } });
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') {
        ['formOverlay','detailOverlay','projectFormOverlay','milestoneFormOverlay','sprintFormOverlay','confirmOverlay','commandOverlay'].forEach(closeOverlay);
        $id('searchDropdown')?.classList.remove('open');
        return;
      }
      if (['INPUT','TEXTAREA','SELECT'].includes(e.target.tagName)) return;
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') { e.preventDefault(); $id('globalSearch')?.focus(); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'p') { e.preventDefault(); openCommandPalette(); }
      if ((e.ctrlKey || e.metaKey) && e.key === 'n') { e.preventDefault(); openTaskForm(null, state.activeProjectId); }
      const views = { '1':'dashboard','2':'projects','3':'tasks','4':'kanban','5':'calendar','6':'gantt','7':'analytics','8':'team' };
      if (!e.ctrlKey && !e.metaKey && !e.altKey && views[e.key]) switchView(views[e.key]);
    });
    // ── Notification Bell ──
    $id('notifBellBtn')?.addEventListener('click', () => {
      const panel = $id('notifPanel');
      if (panel) { panel.classList.toggle('open'); if (panel.classList.contains('open')) renderNotifications(); }
    });
    document.addEventListener('click', e => {
      if (!e.target.closest('#notifBellBtn') && !e.target.closest('#notifPanel'))
        $id('notifPanel')?.classList.remove('open');
    });
    $id('notifClearAllBtn')?.addEventListener('click', () => {
      state.notifications = []; scheduleSave(); renderNotifications(); updateNotifBadge();
    });
    $id('notifMarkAllBtn')?.addEventListener('click', () => {
      (state.notifications || []).forEach(n => n.read = true); scheduleSave(); renderNotifications(); updateNotifBadge();
    });
    // ── Saved Views ──
    $id('saveViewBtn')?.addEventListener('click', saveCurrentView);
    $id('savedViewsList')?.addEventListener('click', e => {
      const btn = e.target.closest('[data-svid]');
      if (btn && !e.target.closest('[data-svdel]')) applyView(btn.dataset.svid);
      const del = e.target.closest('[data-svdel]');
      if (del) { e.stopPropagation(); deleteView(del.dataset.svdel); }
    });
    $id('runSmartCheckBtn')?.addEventListener('click', runSmartCheck);
    $id('suggestBalanceBtn')?.addEventListener('click', suggestWorkloadBalance);
    $id('mobileMenuBtn')?.addEventListener('click', () => $id('sidebar')?.classList.toggle('mobile-open'));
    document.addEventListener('click', e => {
      if (window.innerWidth <= 768 && !e.target.closest('#sidebar') && !e.target.closest('#mobileMenuBtn'))
        $id('sidebar')?.classList.remove('mobile-open');
    });
    $id('kbdHelpBtn')?.addEventListener('click', () => { $id('kbdHelpPanel')?.classList.toggle('open'); renderKeyboardHelp(); });
    document.addEventListener('click', e => {
      if (!e.target.closest('#kbdHelpBtn') && !e.target.closest('#kbdHelpPanel'))
        $id('kbdHelpPanel')?.classList.remove('open');
    });
    document.addEventListener('click', e => {
      const btn = e.target.closest('[data-burndown-sprint]');
      if (btn) renderSprintBurndown(btn.dataset.burndownSprint, 'burndownContainer');
    });
  
  } catch (err) {
    console.error("bindEvents FAILED:", err);
  }
}
/* ════════════════════════════════════════════════════════════
   NOTIFICATIONS
   ════════════════════════════════════════════════════════════ */
function buildNotifications() {
  if (!state.notifications) state.notifications = [];
  const notes = [];
  state.tasks.forEach(t => {
    if (isOverdue(t))
      notes.push({ id:'ov-'+t.id, type:'overdue', title:'Overdue Task', body: t.title, taskId: t.id, time: today(), read: false });
    if (t.status === 'blocked')
      notes.push({ id:'bl-'+t.id, type:'blocked', title:'Task Blocked', body: t.title, taskId: t.id, time: today(), read: false });
    const du = daysUntil(t.dueDate);
    if (du === 1 && t.status !== 'completed')
      notes.push({ id:'dd-'+t.id, type:'deadline', title:'Due Tomorrow', body: t.title, taskId: t.id, time: today(), read: false });
  });
  state.milestones.forEach(m => {
    const du = daysUntil(m.dueDate);
    if (du !== null && du >= 0 && du <= 3 && m.status !== 'completed') {
      const proj = findProject(m.projectId);
      notes.push({ id:'ms-'+m.id, type:'milestone', title:`Milestone Due in ${du}d`,
        body: `${m.name}${proj ? ' — ' + proj.name : ''}`, time: today(), read: false });
    }
  });
  const existing = new Set(state.notifications.map(n => n.id));
  const fresh = notes.filter(n => !existing.has(n.id));
  state.notifications = [...fresh, ...state.notifications].slice(0, 50);
}
function renderNotifications() {
  const el = $id('notifList');
  if (!el) return;
  buildNotifications();
  const items = state.notifications || [];
  if (!items.length) { el.innerHTML = '<div class="notif-empty">🎉 All caught up!</div>'; updateNotifBadge(); return; }
  const icons = { overdue:'⚠️', blocked:'🚫', deadline:'📅', milestone:'◆', info:'ℹ️' };
  el.innerHTML = items.slice(0, 20).map(n => `
    <div class="notif-item${n.read ? ' read' : ''}" data-nid="${n.id}" ${n.taskId ? `data-taskid="${n.taskId}"` : ''}>
      <span class="notif-icon">${icons[n.type] || 'ℹ️'}</span>
      <div class="notif-body">
        <div class="notif-title">${esc(n.title)}</div>
        <div class="notif-text">${esc(n.body)}</div>
        <div class="notif-time">${fmtDate(n.time)}</div>
      </div>
      ${!n.read ? '<span class="notif-dot"></span>' : ''}
    </div>`).join('');
  el.querySelectorAll('.notif-item[data-taskid]').forEach(item => {
    item.addEventListener('click', () => {
      const n = items.find(x => x.id === item.dataset.nid);
      if (n) n.read = true;
      scheduleSave(); updateNotifBadge();
      $id('notifPanel')?.classList.remove('open');
      openTaskDetail(item.dataset.taskid);
    });
  });
  updateNotifBadge();
}
function updateNotifBadge() {
  const unread = (state.notifications || []).filter(n => !n.read).length;
  const badge  = $id('notifBadge');
  if (badge) { badge.textContent = unread; badge.style.display = unread ? '' : 'none'; }
}
/* ════════════════════════════════════════════════════════════
   SMART PRODUCTIVITY CHECK
   ════════════════════════════════════════════════════════════ */
function runSmartCheck() {
  const warnings = [], suggestions = [];
  const overdueC = state.tasks.filter(t => isOverdue(t) && t.priority === 'critical');
  if (overdueC.length)
    warnings.push(`🚨 ${overdueC.length} CRITICAL task${overdueC.length > 1 ? 's are' : ' is'} overdue: ${overdueC.map(t => t.title).slice(0, 2).join(', ')}${overdueC.length > 2 ? '…' : ''}`);
  state.tasks.filter(t => t.status === 'blocked').forEach(t => {
    const dependents = state.tasks.filter(x => (x.dependencies || []).includes(t.id));
    if (dependents.length)
      warnings.push(`🔗 "${t.title}" is blocked and is blocking ${dependents.length} other task${dependents.length > 1 ? 's' : ''}`);
  });
  const unassignedC = state.tasks.filter(t => !t.ba && t.priority === 'critical' && t.status !== 'completed');
  if (unassignedC.length)
    warnings.push(`👤 ${unassignedC.length} critical task${unassignedC.length > 1 ? 's are' : ' is'} unassigned`);
  const baMap = {};
  state.tasks.filter(t => t.ba && t.status !== 'completed').forEach(t => { baMap[t.ba] = (baMap[t.ba] || 0) + 1; });
  Object.entries(baMap).filter(([, c]) => c > 5).forEach(([ba, c]) =>
    warnings.push(`🔥 ${ba} has ${c} open tasks — potential overload`)
  );
  state.projects.filter(p => p.status === 'active').forEach(p => {
    if (!getProjectTasks(p.id).length) suggestions.push(`📁 Project "${p.name}" has no tasks yet`);
  });
  const noDue = state.tasks.filter(t => !t.dueDate && t.status !== 'completed').length;
  if (noDue > 0) suggestions.push(`📅 ${noDue} task${noDue > 1 ? 's have' : ' has'} no due date set`);
  const titleCounts = {};
  state.tasks.forEach(t => { const k = t.title.trim().toLowerCase(); titleCounts[k] = (titleCounts[k] || 0) + 1; });
  const dupCount = Object.values(titleCounts).filter(c => c > 1).length;
  if (dupCount) suggestions.push(`🔁 ${dupCount} possible duplicate task title${dupCount > 1 ? 's' : ''} detected`);
  const all = [...warnings, ...suggestions];
  const smartEl = $id('smartCheckResults');
  if (smartEl) {
    smartEl.style.display = '';
    smartEl.innerHTML = all.length
      ? all.map(w => `<div class="smart-check-item">${esc(w)}</div>`).join('')
      : '<div class="smart-check-item ok">✅ No issues detected — your workspace looks healthy!</div>';
  } else {
    alert(all.length ? `Smart Check:\n\n${all.join('\n')}` : '✅ Smart Check: No issues found!');
  }
  if (warnings.length) toast(`Smart Check: ${warnings.length} warning${warnings.length > 1 ? 's' : ''} found`, 'warning');
  else toast('Smart Check passed ✅', 'success');
}
/* ════════════════════════════════════════════════════════════
   SAVED VIEWS
   ════════════════════════════════════════════════════════════ */
function saveCurrentView() {
  const name = prompt('Name this saved view (e.g. "My Critical Tasks"):');
  if (!name?.trim()) return;
  if (!state.savedViews) state.savedViews = [];
  state.savedViews.push({
    id: uid(), name: name.trim(),
    view: state.currentView === 'project-detail' ? 'tasks' : state.currentView,
    filters: { ...state.filters },
    sortField: state.sortField, sortDir: state.sortDir, searchQuery: state.searchQuery, createdAt: today(),
  });
  scheduleSave(); renderSavedViews(); toast(`View "${name}" saved`, 'success');
}
function applyView(svid) {
  const v = (state.savedViews || []).find(x => x.id === svid);
  if (!v) return;
  Object.assign(state.filters, v.filters);
  state.sortField = v.sortField || 'createdAt';
  state.sortDir   = v.sortDir   || 'desc';
  state.searchQuery = v.searchQuery || '';
  const gSearch = $id('globalSearch'); if (gSearch) gSearch.value = state.searchQuery;
  const fMap = { filterProject:'project', filterStatus:'status', filterPriority:'priority', filterBA:'ba', filterMilestone:'milestone', filterFrom:'from', filterTo:'to' };
  Object.entries(fMap).forEach(([elId, fk]) => { const el = $id(elId); if (el) el.value = state.filters[fk] || ''; });
  switchView(v.view || 'tasks'); toast(`Applied: ${v.name}`, 'info');
}
function deleteView(svid) {
  state.savedViews = (state.savedViews || []).filter(x => x.id !== svid);
  scheduleSave(); renderSavedViews(); toast('View deleted', 'warning');
}
function renderSavedViews() {
  const el = $id('savedViewsList');
  if (!el) return;
  const views = state.savedViews || [];
  if (!views.length) { el.innerHTML = '<p class="no-data" style="padding:8px 12px;font-size:.8rem">No saved views</p>'; return; }
  el.innerHTML = views.map(v => `
    <div class="saved-view-item" data-svid="${esc(v.id)}">
      <span class="saved-view-icon">🔖</span>
      <span class="saved-view-name">${esc(v.name)}</span>
      <button class="action-btn" data-svdel="${esc(v.id)}" title="Delete view" style="margin-left:auto;padding:1px 5px">×</button>
    </div>`).join('');
}
/* ════════════════════════════════════════════════════════════
   SPRINT BURNDOWN
   ════════════════════════════════════════════════════════════ */
function renderSprintBurndown(sprintId, containerId) {
  const container = $id(containerId);
  if (!container) return;
  const sprint = state.sprints.find(s => s.id === sprintId);
  if (!sprint) { container.innerHTML = '<p class="no-data">Select a sprint</p>'; return; }
  const sTasks = state.tasks.filter(t => t.sprintId === sprintId);
  if (!sTasks.length) { container.innerHTML = '<p class="no-data">No tasks in this sprint yet</p>'; return; }
  const start = new Date(sprint.startDate + 'T00:00:00'), end = new Date(sprint.endDate + 'T00:00:00');
  const totalDays = Math.max(1, Math.round((end - start) / 86400000)), totalTasks = sTasks.length;
  const points = [];
  for (let d = 0; d <= totalDays; d++) {
    const dayDate = new Date(start); dayDate.setDate(start.getDate() + d);
    const ds = dayDate.toISOString().split('T')[0];
    const done = sTasks.filter(t => t.status === 'completed' && (t.updatedAt || '') <= ds).length;
    points.push({ d, remaining: totalTasks - done });
  }
  const W = 400, H = 170, PL = 36, PR = 16, PT = 24, PB = 24, CW = W-PL-PR, CH = H-PT-PB;
  const xS = d => PL + (d / totalDays) * CW, yS = v => PT + (1 - v / Math.max(totalTasks, 1)) * CH;
  const gridLines = [0,.25,.5,.75,1].map(f => { const v = Math.round(f*totalTasks), y = yS(v);
    return `<line x1="${PL}" y1="${y}" x2="${W-PR}" y2="${y}" stroke="var(--border)" stroke-width="1" stroke-dasharray="3,3"/>
            <text x="${PL-4}" y="${y+4}" text-anchor="end" font-size="9" fill="var(--text-3)">${v}</text>`; }).join('');
  container.innerHTML = `
    <svg viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" style="width:100%;height:auto">
      ${gridLines}
      <path d="M${xS(0)},${yS(totalTasks)} L${xS(totalDays)},${yS(0)}" stroke="#60a5fa" stroke-width="1.5" stroke-dasharray="5,3" fill="none" opacity=".7"/>
      <path d="${points.map((p,i)=>`${i===0?'M':'L'}${xS(p.d)},${yS(p.remaining)}`).join(' ')}" stroke="#34d399" stroke-width="2.5" fill="none" stroke-linejoin="round"/>
      ${points.map(p=>`<circle cx="${xS(p.d)}" cy="${yS(p.remaining)}" r="3" fill="#34d399"/>`).join('')}
      <text x="${W/2}" y="14" font-size="10.5" fill="var(--text-2)" text-anchor="middle" font-weight="600">${esc(sprint.name)} — Burndown</text>
      <text x="${PL}" y="${H-4}" font-size="8" fill="var(--text-3)">Start</text>
      <text x="${W-PR}" y="${H-4}" font-size="8" fill="var(--text-3)" text-anchor="end">End</text>
    </svg>
    <div style="font-size:.72rem;color:var(--text-3);text-align:center;margin-top:4px">
      ${sTasks.filter(t=>t.status==='completed').length}/${totalTasks} tasks complete · Velocity: ${sprint.velocity||0} pts
    </div>`;
}
/* ════════════════════════════════════════════════════════════
   DEADLINE HEALTH SCORE
   ════════════════════════════════════════════════════════════ */
function calcDeadlineHealth(projectId) {
  const tasks = projectId ? getProjectTasks(projectId) : state.tasks;
  const active = tasks.filter(t => t.status !== 'completed');
  if (!active.length) return { score:100, label:'Excellent', color:'#34d399' };
  let penalty = 0;
  active.forEach(t => {
    const du = daysUntil(t.dueDate);
    if (!t.dueDate) penalty += 5; else if (du < 0) penalty += 20; else if (du === 0) penalty += 10; else if (du <= 3) penalty += 5;
    if (t.status === 'blocked') penalty += 15;
    if (t.priority === 'critical' && du !== null && du < 3) penalty += 10;
  });
  const score = Math.round(Math.min(100, Math.max(0, 100 - (penalty / active.length) * 10)));
  const label = score >= 80 ? 'Excellent' : score >= 60 ? 'Good' : score >= 40 ? 'At Risk' : 'Critical';
  const color = score >= 80 ? '#34d399' : score >= 60 ? '#60a5fa' : score >= 40 ? '#fbbf24' : '#f87171';
  return { score, label, color };
}
/* ════════════════════════════════════════════════════════════
   PROJECT HEALTH STRIP
   ════════════════════════════════════════════════════════════ */
function renderProjectHealthStrip(containerId) {
  const el = $id(containerId);
  if (!el) return;
  el.innerHTML = state.projects.filter(p => p.status !== 'archived').map(p => {
    const health = calcDeadlineHealth(p.id), tasks = getProjectTasks(p.id);
    const done = tasks.filter(t => t.status === 'completed').length;
    const pct  = tasks.length ? Math.round(done / tasks.length * 100) : 0;
    return `<div class="health-strip-item" data-pid="${esc(p.id)}" style="cursor:pointer;display:flex;align-items:stretch;border:1px solid var(--border);border-radius:var(--radius);overflow:hidden;margin-bottom:8px">
      <div style="width:8px;background:${p.color};flex-shrink:0"></div>
      <div style="flex:1;padding:8px 12px;min-width:0">
        <div style="font-size:.82rem;font-weight:600;color:var(--text)">${esc(p.name)}</div>
        <div class="mini-progress-track" style="margin-top:4px"><div class="mini-progress-fill" style="width:${pct}%;background:${p.color}"></div></div>
        <div style="font-size:.7rem;color:var(--text-3);margin-top:2px">${pct}% complete · ${tasks.length} tasks</div>
      </div>
      <div style="padding:8px 12px;text-align:right;flex-shrink:0">
        <div style="font-size:1.2rem;font-weight:800;color:${health.color}">${health.score}</div>
        <div style="font-size:.65rem;color:${health.color}">${health.label}</div>
      </div>
    </div>`;
  }).join('') || '<p class="no-data">No projects</p>';
  el.querySelectorAll('[data-pid]').forEach(item => item.addEventListener('click', () => openProjectDetail(item.dataset.pid)));
}
/* ════════════════════════════════════════════════════════════
   AUDIT LOG
   ════════════════════════════════════════════════════════════ */
function renderAuditLog(containerId) {
  const el = $id(containerId);
  if (!el) return;
  const allAct = state.tasks.flatMap(t => (t.activity||[]).map(a=>({...a,taskTitle:t.title,taskId:t.id,projectId:t.projectId})))
    .sort((a,b) => b.time.localeCompare(a.time)).slice(0, 40);
  el.innerHTML = allAct.length ? allAct.map(a => {
    const p = findProject(a.projectId);
    return `<div class="audit-item" data-tid="${esc(a.taskId)}" style="cursor:pointer;display:flex;gap:10px;padding:8px 0;border-bottom:1px solid var(--border)">
      <div style="width:8px;height:8px;border-radius:50%;background:${p?.color||'var(--primary)'};flex-shrink:0;margin-top:4px"></div>
      <div style="flex:1;min-width:0">
        <div style="font-size:.82rem;font-weight:500;color:var(--text)">${esc(a.taskTitle)}</div>
        <div style="font-size:.75rem;color:var(--text-3)">${esc(a.desc)}${p?` · <span style="color:${p.color}">${esc(p.name)}</span>`:''}</div>
      </div>
      <span style="font-size:.7rem;color:var(--text-3);white-space:nowrap">${fmtDate(a.time)}</span>
    </div>`;
  }).join('') : '<p class="no-data" style="padding:20px">No activity recorded yet</p>';
  el.querySelectorAll('.audit-item[data-tid]').forEach(item => item.addEventListener('click', () => openTaskDetail(item.dataset.tid)));
}
/* ════════════════════════════════════════════════════════════
   KEYBOARD HELP
   ════════════════════════════════════════════════════════════ */
function renderKeyboardHelp() {
  const el = $id('kbdHelpContent');
  if (!el) return;
  const shortcuts = [
    { key:'Ctrl/⌘ + K', desc:'Focus global search' },
    { key:'Ctrl/⌘ + P', desc:'Command palette' },
    { key:'Ctrl/⌘ + N', desc:'New task' },
    { key:'1 – 8',       desc:'Switch views (Dashboard … Team)' },
    { key:'Escape',       desc:'Close any modal / overlay' },
  ];
  el.innerHTML = `<div style="display:flex;flex-direction:column;gap:6px">` +
    shortcuts.map(s => `<div style="display:flex;align-items:center;gap:10px">
      <kbd style="background:var(--surface-2);border:1px solid var(--border);border-radius:4px;padding:2px 7px;font-size:.75rem;white-space:nowrap">${esc(s.key)}</kbd>
      <span style="font-size:.82rem;color:var(--text-2)">${esc(s.desc)}</span>
    </div>`).join('') + `</div>`;
}
/* ════════════════════════════════════════════════════════════
   WORKLOAD BALANCE
   ════════════════════════════════════════════════════════════ */
function suggestWorkloadBalance() {
  const baLoad = {};
  state.users.forEach(u => { baLoad[u.name] = { user: u, open: 0 }; });
  state.tasks.filter(t => t.ba && t.status !== 'completed').forEach(t => { if (baLoad[t.ba]) baLoad[t.ba].open++; });
  const entries = Object.values(baLoad).filter(e => e.open > 0).sort((a, b) => b.open - a.open);
  if (entries.length < 2) { toast('Not enough assignment data for suggestions', 'info'); return; }
  const busiest = entries[0], lightest = entries[entries.length - 1];
  if (busiest.open - lightest.open <= 2) { toast('Workload is already balanced ✅', 'success'); return; }
  alert(`Workload Suggestion:\n\n${busiest.user.name} has ${busiest.open} open tasks.\n${lightest.user.name} has ${lightest.open} open tasks.\n\nConsider reassigning some tasks from ${busiest.user.name} to ${lightest.user.name}.`);
}
/* ════════════════════════════════════════════════════════════
   AUTO-NOTIFICATION TICK
   ════════════════════════════════════════════════════════════ */
function startNotificationTick() {
  updateNotifBadge();
  setInterval(() => { buildNotifications(); updateNotifBadge(); }, 5 * 60 * 1000);
}
/* ════════════════════════════════════════════════════════════
   INIT
   FIX 7: init must be async so it can await loadState().
   FIX 8: footerYear moved inside DOMContentLoaded so the
          DOM element exists before we try to write to it.
   ════════════════════════════════════════════════════════════ */
  async function init() {

    try {
      console.log("INIT STARTED");
      console.log("before loadState");
      await loadState();
      console.log("after loadState");

      if (!state.notifications) state.notifications = [];
      if (!state.savedViews) state.savedViews = [];

      setTheme(state.settings.theme);
      console.log("after setTheme");

      bindEvents();
      console.log("bindEvents END");

      refreshProjectFilter();
      updateSidebarProjects();
      updateNavBadges();
      console.log("update END");

      renderDashboard();
      renderSavedViews();
      renderKeyboardHelp();
      console.log("render END");

      startNotificationTick();
      console.log("notification tick END");
      setTimeout(() => {
        buildNotifications();
        updateNotifBadge();
      }, 800);

      toast('Welcome to TaskFlow Pro 🚀', 'info');
      console.log("INIT END");
    } catch (err) {
      console.error("INIT FAILED:", err);
    }
  }
/* ════════════════════════════════════════════════════════════
   BOOTSTRAP (CLEAN + CONSISTENT AUTH FLOW)
   ════════════════════════════════════════════════════════════ */
let appStarted = false;
let initialSessionFired = false; // true once _initialize completes (lock released)

document.addEventListener('DOMContentLoaded', async () => {
  console.log("BOOTSTRAP START");
  // ─────────────────────────────────────────────
  // AUTH STATE LISTENER
  // INITIAL_SESSION fires after _initialize completes — auth lock is released,
  // safe to make DB calls. SIGNED_IN on page refresh fires INSIDE _initialize
  // while the lock is still held, causing DB query deadlocks.
  // ─────────────────────────────────────────────
  sb.auth.onAuthStateChange(async (event, session) => {
    console.log("AUTH EVENT:", event);

    if (event === 'SIGNED_OUT') {
      currentUser = null;
      showLogin();
      appStarted = false;
      // Do NOT reset initialSessionFired — the Supabase internal lock was already
      // released when INITIAL_SESSION fired. Resetting it here prevents SIGNED_IN
      // (from a subsequent manual login) from ever calling startApp().
      return;
    }

    if (event === 'TOKEN_REFRESHED') {
      if (session?.user) currentUser = session.user;
      return;
    }

    // INITIAL_SESSION fires after _initialize finishes — DB calls are safe here
    if (event === 'INITIAL_SESSION') {
      initialSessionFired = true;
      if (session?.user) {
        currentUser = session.user;
        await startApp();
      } else {
        showLogin();
      }
      return;
    }

    // SIGNED_IN: only safe after INITIAL_SESSION has already fired.
    // On page refresh SIGNED_IN fires before INITIAL_SESSION (inside the lock).
    if (event === 'SIGNED_IN' && initialSessionFired && session?.user) {
      currentUser = session.user;
      await startApp();
    }
  });
  // ─────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────
  document.getElementById('loginBtn')?.addEventListener('click', async () => {
    setLoginError('');
    const email = document.getElementById('loginEmail')?.value?.trim();
    const password = document.getElementById('loginPassword')?.value;
    if (!email || !password) { setLoginError('Enter email and password'); return; }
    const { error } = await sb.auth.signInWithPassword({ email, password });
    if (error) { setLoginError(error.message); return; }
    console.log("LOGIN SUCCESS");
  });
  // ─────────────────────────────────────────────
  // SIGNUP
  // ─────────────────────────────────────────────
  document.getElementById('signupBtn')?.addEventListener('click', async () => {
    setLoginError('');
    const email = document.getElementById('loginEmail')?.value?.trim();
    const password = document.getElementById('loginPassword')?.value;
    if (!email || !password) { setLoginError('Enter email and password'); return; }
    const { error } = await sb.auth.signUp({ email, password });
    if (error) { setLoginError(error.message); return; }
    alert('Signup successful. Please verify your email if required.');
  });
  // ─────────────────────────────────────────────
  // GUEST MODE
  // ─────────────────────────────────────────────
  document.getElementById('guestBtn')?.addEventListener('click', async () => {
    console.log("GUEST MODE");
    currentUser = null;
    initialSessionFired = true;
    showApp();
    await startApp();
  });
  // ─────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────
  document.getElementById('logoutBtn')?.addEventListener('click', async () => {
    await sb.auth.signOut();
  });
});
/* ════════════════════════════════════════════════════════════
   SINGLE APP START FUNCTION (IMPORTANT FIX)
   ════════════════════════════════════════════════════════════ */
async function startApp() {
  if (appStarted) {
    console.log("APP ALREADY STARTED");
    return;
  }
  appStarted = true;
  try {
    console.log("START APP");
    showApp();
    // reset runtime state
    state.currentView = 'dashboard';
    state.activeProjectId = null;
    state.searchQuery = '';
    await init();
    // UI refresh AFTER init
    renderDashboard();
    updateSidebarProjects();
    updateNavBadges();
    console.log("APP READY");
  } catch (err) {
    console.error("APP START FAILED:", err);
    appStarted = false;
  }
}