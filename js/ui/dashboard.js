import { state, getActiveTasks, getProjectTasks, findTask } from '../state.js';
import { $id, esc, fmtDate, isOverdue, daysUntil, openOverlay, closeOverlay, STATUS_META, toast } from '../utils.js';
import { navigate } from '../router.js';

const CMD_LIST = [
  { icon:'📋', label:'All Tasks',   sub:'View all tasks',    action: () => navigate('tasks'),     kbd:'T' },
  { icon:'📁', label:'Projects',    sub:'View all projects', action: () => navigate('projects'),  kbd:'P' },
  { icon:'🗂', label:'Kanban',      sub:'Kanban board',      action: () => navigate('kanban'),    kbd:'K' },
  { icon:'📅', label:'Calendar',    sub:'Calendar view',     action: () => navigate('calendar'),  kbd:'C' },
  { icon:'📊', label:'Analytics',   sub:'Analytics',         action: () => navigate('analytics'), kbd:'A' },
  { icon:'👥', label:'Team',        sub:'Team members',      action: () => navigate('team'),      kbd: '' },
  { icon:'➕', label:'New Task',    sub:'Create a new task', action: () => window.openTaskForm?.()        },
  { icon:'➕', label:'New Project', sub:'Create a project',  action: () => window.openProjectForm?.()     },
];

export function renderDashboard() {
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
    el.addEventListener('click', () => window.openProjectDetail?.(el.dataset.pid))
  );
  // Overdue count
  const ov = tasks.filter(isOverdue).length;
  const oc = $id('overdueCount');
  if (oc) { oc.style.display = ov ? '' : 'none'; oc.textContent = ov + ' overdue'; }
  // Upcoming deadlines
  const upcoming = [...tasks].filter(t => t.status !== 'completed' && t.due_date)
    .sort((a, b) => a.due_date.localeCompare(b.due_date)).slice(0, 6);
  const ul = $id('upcomingList');
  if (ul) ul.innerHTML = upcoming.map(t => {
    const days = daysUntil(t.due_date), over = days < 0;
    const label = over ? `${Math.abs(days)}d overdue` : days === 0 ? 'Today' : `${days}d left`;
    return `<div class="mini-task-item" data-id="${t.id}">
      <div class="mini-task-dot" style="background:${over ? '#f87171' : STATUS_META[t.status].dot}"></div>
      <span class="mini-task-title">${esc(t.title)}</span>
      <span class="mini-task-meta" style="color:${over ? '#dc2626' : 'inherit'}">${label}</span>
    </div>`;
  }).join('') || '<p class="no-data">No upcoming deadlines 🎉</p>';
  // Recent activity (activity is now in separate DB table — show placeholder)
  const ral = $id('recentActivityList');
  if (ral) ral.innerHTML = '<p class="no-data">No activity yet</p>';
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
    const u = state.members.find(u => u.display_name === e.name);
    const bPct = Math.round((e.open + e.done) / maxWl * 100);
    return `<div class="mini-task-item">
      <div style="width:28px;height:28px;border-radius:50%;background:${u?.color || '#2563eb'};display:flex;align-items:center;justify-content:center;font-size:.6rem;font-weight:700;color:#fff;flex-shrink:0">${e.name.slice(0,2).toUpperCase()}</div>
      <div style="flex:1;min-width:0">
        <div style="font-size:.82rem;font-weight:500">${esc(e.name)}</div>
        <div class="workload-bar" style="margin-top:3px"><div class="workload-fill" style="width:${bPct}%;background:${u?.color || '#2563eb'}"></div></div>
      </div>
      <span class="mini-task-meta">${e.open} open</span>
    </div>`;
  }).join('') || '<p class="no-data">No team assignments yet</p>';
  // bind events
  $id('upcomingList')?.querySelectorAll('[data-id]').forEach(el => el.addEventListener('click', () => window.openTaskDetail?.(el.dataset.id)));
  $id('statsGrid')?.querySelectorAll('.stat-card').forEach(card => {
    card.addEventListener('click', () => {
      const stat = card.dataset.stat;
      state.filters.status = stat === 'total' ? '' : stat;
      const sel = $id('filterStatus'); if (sel) sel.value = state.filters.status;
      navigate('tasks');
    });
  });
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
    action: () => { closeOverlay('commandOverlay'); window.openTaskDetail?.(t.id); }, isTask: true,
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

export function openCommandPalette() {
  state.cmdIndex = 0;
  $id('commandInput').value = '';
  renderCommandResults('');
  openOverlay('commandOverlay');
  setTimeout(() => $id('commandInput')?.focus(), 60);
}
