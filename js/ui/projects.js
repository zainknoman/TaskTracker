import { saveProject as dbSaveProject, deleteProject as dbDeleteProject, saveMilestone as dbSaveMilestone, deleteMilestone as dbDeleteMilestone, saveSprint as dbSaveSprint, deleteSprint as dbDeleteSprint } from '../storage.js';
import { state, setState, findProject, getProjectTasks, addEntity, updateEntity, removeEntity } from '../state.js';
import { $id, esc, fmtDate, getTagColor, setVal, markError, openOverlay, closeOverlay, toast, STATUS_META, PRIORITY_META, PROJECT_COLORS } from '../utils.js';
import { navigate } from '../router.js';
import { renderTaskTableHTML, bindTaskTableEvents } from './tasks.js';
import { renderKanbanInto } from './kanban.js';

let _refresh, _updateBadges, _updateSidebar;
export function setCallbacks(refresh, updateBadges, updateSidebar) {
  _refresh = refresh; _updateBadges = updateBadges; _updateSidebar = updateSidebar;
}

/* ════════════════════════════════════════════════════════════
   PROJECTS VIEW
   ════════════════════════════════════════════════════════════ */
export function renderProjects() {
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
        <td>${fmtDate(p.end_date)}</td>
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
            ${p.end_date ? `<span>📅 ${fmtDate(p.end_date)}</span>` : ''}
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
      window.openProjectDetail?.(el.dataset.pid);
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
export function renderProjectDetail(pid) {
  const p = findProject(pid);
  if (!p) { navigate('projects'); return; }
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
            ${p.ba_team?.length ? `<span class="pdh-meta-item">📊 BA: ${esc(Array.isArray(p.ba_team) ? p.ba_team.join(', ') : p.ba_team)}</span>` : ''}
            ${p.start_date ? `<span class="pdh-meta-item">📅 ${fmtDate(p.start_date)} → ${fmtDate(p.end_date)}</span>` : ''}
            ${p.budget    ? `<span class="pdh-meta-item">💰 ${Number(p.budget).toLocaleString()}</span>` : ''}
          </div>
        </div>
        <div class="pdh-actions">
          <button class="btn btn-secondary btn-sm" id="pdh-exportBtn">↓ Export JSON</button>
          <button class="btn btn-secondary btn-sm" id="pdh-editBtn">Edit</button>
          <button class="btn btn-primary btn-sm" id="pdh-newTaskBtn">+ Task</button>
        </div>
      </div>
      <div class="pdh-stats">
        <div class="pdh-stat"><div class="pdh-stat-num">${pt.length}</div><div class="pdh-stat-lbl">Total</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num">${pt.filter(t=>t.status==='inprogress').length}</div><div class="pdh-stat-lbl">In Progress</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num" style="color:#059669">${done}</div><div class="pdh-stat-lbl">Completed</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num" style="color:#dc2626">${pt.filter(t=>t.status==='blocked').length}</div><div class="pdh-stat-lbl">Blocked</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num" style="color:#d97706">${state.milestones.filter(m=>m.project_id===pid).length}</div><div class="pdh-stat-lbl">Milestones</div></div>
        <div class="pdh-stat"><div class="pdh-stat-num">${state.sprints.filter(s=>s.project_id===pid).length}</div><div class="pdh-stat-lbl">Sprints</div></div>
      </div>
      <div class="pdh-progress" style="margin-top:14px">
        <div style="display:flex;justify-content:space-between;font-size:.82rem;margin-bottom:5px;color:var(--text-3)"><span>Project Completion</span><strong style="color:var(--primary)">${ppct}%</strong></div>
        <div class="progress-track"><div class="progress-fill" style="width:${ppct}%;background:linear-gradient(90deg,${p.color},${p.color}88)"></div></div>
      </div>`;
    $id('pdh-exportBtn')?.addEventListener('click', () => exportProjectJSON(pid));
    $id('pdh-editBtn')?.addEventListener('click', () => openProjectForm(pid));
    $id('pdh-newTaskBtn')?.addEventListener('click', () => window.openTaskForm?.(null, pid));
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
    const recent = [...pt].sort((a, b) => (b.updated_at || '').localeCompare(a.updated_at || '')).slice(0, 5);
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
          <span class="mini-task-meta">${fmtDate(t.due_date)}</span>
        </div>`).join('') || '<p class="no-data">All tasks complete! 🎉</p>'}</div>
      </div>
    </div>`;
    el.querySelectorAll('.proj-task-link').forEach(item => item.addEventListener('click', () => window.openTaskDetail?.(item.dataset.id)));
  }
  if (tab === 'tasks') {
    const pt = getProjectTasks(pid);
    el.innerHTML = `<div style="margin-bottom:10px;display:flex;justify-content:flex-end">
      <button class="btn btn-primary btn-sm" id="ptNewTaskBtn">+ New Task</button>
    </div>
    <div class="table-wrapper">${renderTaskTableHTML(pt)}</div>`;
    $id('ptNewTaskBtn')?.addEventListener('click', () => window.openTaskForm?.(null, pid));
    bindTaskTableEvents(el);
  }
  if (tab === 'kanban') {
    el.innerHTML = '<div class="kanban-board" id="projKanban"></div>';
    renderKanbanInto($id('projKanban'), getProjectTasks(pid));
  }
  if (tab === 'milestones') {
    const ms = state.milestones.filter(m => m.project_id === pid).sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0));
    el.innerHTML = `<div style="margin-bottom:10px;display:flex;justify-content:flex-end">
      <button class="btn btn-primary btn-sm" id="newMilestoneBtn">+ Milestone</button>
    </div>
    <div class="milestone-list">
    ${ms.length ? ms.map(m => {
      const mTasks = state.tasks.filter(t => t.milestone_id === m.id);
      const mDone  = mTasks.filter(t => t.status === 'completed').length;
      const icons  = { pending:'⏳', inprogress:'🔄', completed:'✅' };
      return `<div class="milestone-card">
        <div class="milestone-icon ${m.status}">${icons[m.status] || '⏳'}</div>
        <div class="milestone-info">
          <div class="milestone-name">${esc(m.name)}</div>
          <div class="milestone-meta">${m.description ? esc(m.description) + ' · ' : ''}${fmtDate(m.due_date)}</div>
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
    el.querySelectorAll('[data-action="del-ms"]').forEach(btn => btn.addEventListener('click', async () => {
      try {
        await dbDeleteMilestone(btn.dataset.mid);
        removeEntity('milestones', btn.dataset.mid);
        renderProjectTab(pid, 'milestones');
        toast('Milestone deleted', 'warning');
      } catch (e) { toast(e.message, 'error'); }
    }));
  }
  if (tab === 'sprints') {
    const ss = state.sprints.filter(s => s.project_id === pid).sort((a, b) => (a.start_date || '').localeCompare(b.start_date || ''));
    const statusColors = { planning: '#7c3aed', active: '#2563eb', completed: '#059669' };
    el.innerHTML = `<div style="margin-bottom:10px;display:flex;justify-content:flex-end">
      <button class="btn btn-primary btn-sm" id="newSprintBtn">+ Sprint</button>
    </div>
    <div class="sprint-list">
    ${ss.length ? ss.map(s => {
      const sTasks = state.tasks.filter(t => t.sprint_id === s.id);
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
          <span>📅 ${fmtDate(s.start_date)} → ${fmtDate(s.end_date)}</span>
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
    el.querySelectorAll('[data-action="del-sp"]').forEach(btn => btn.addEventListener('click', async () => {
      try {
        await dbDeleteSprint(btn.dataset.sid);
        removeEntity('sprints', btn.dataset.sid);
        renderProjectTab(pid, 'sprints');
        toast('Sprint deleted', 'warning');
      } catch (e) { toast(e.message, 'error'); }
    }));
  }
}

/* ════════════════════════════════════════════════════════════
   PROJECT FORM
   ════════════════════════════════════════════════════════════ */
let _projectTags = [];

export function openProjectForm(projectId = null) {
  const p = projectId ? findProject(projectId) : null;
  $id('projectFormTitle').textContent = p ? 'Edit Project' : 'New Project';
  $id('pfId').value = p?.id || '';
  _projectTags = p ? [...(p.tags || [])] : [];
  setVal('pfName',    p?.name        || '');
  setVal('pfCode',    p?.code        || '');
  setVal('pfDept',    p?.department  || '');
  setVal('pfDesc',    p?.description || '');
  setVal('pfPM',      p?.pm          || '');
  setVal('pfBATeam',  Array.isArray(p?.ba_team) ? p.ba_team.join(', ') : (p?.ba_team || ''));
  setVal('pfStatus',  p?.status      || 'active');
  setVal('pfPriority',p?.priority    || 'medium');
  setVal('pfStart',   p?.start_date  || '');
  setVal('pfEnd',     p?.end_date    || '');
  setVal('pfBudget',  p?.budget      || '');
  setVal('pfColor',   p?.color       || '#2563eb');
  const cp = $id('projectColorPicker');
  if (cp) cp.innerHTML = PROJECT_COLORS.map(c => `
    <div class="color-swatch${(p?.color||'#2563eb')===c?' selected':''}" style="background:${c}" data-color="${c}" title="${c}"></div>`).join('');
  renderProjectFormTags();
  if (cp) {
    cp.querySelectorAll('.color-swatch').forEach(swatch =>
      swatch.addEventListener('click', () => {
        $id('pfColor').value = swatch.dataset.color;
        cp.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
        swatch.classList.add('selected');
      })
    );
  }
  const pfTagInp = $id('pfTagInput');
  if (pfTagInp) {
    const freshPfTagInp = pfTagInp.cloneNode(true);
    pfTagInp.replaceWith(freshPfTagInp);
    freshPfTagInp.addEventListener('keydown', e => {
      if (e.key !== 'Enter') return;
      e.preventDefault();
      const v = freshPfTagInp.value.trim();
      if (v && !_projectTags.includes(v)) { _projectTags.push(v); renderProjectFormTags(); }
      freshPfTagInp.value = '';
    });
  }
  openOverlay('projectFormOverlay');
  setTimeout(() => $id('pfName')?.focus(), 80);
}

function renderProjectFormTags() {
  const chips = $id('pTagChips');
  if (!chips) return;
  chips.innerHTML = _projectTags.map((tg, i) => `
    <span class="tag-chip tag-color-${getTagColor(tg)}">${esc(tg)}<span class="tag-chip-remove" data-pi="${i}">×</span></span>`).join('');
  chips.querySelectorAll('.tag-chip-remove').forEach(btn =>
    btn.addEventListener('click', () => { _projectTags.splice(+btn.dataset.pi, 1); renderProjectFormTags(); })
  );
}

export async function saveProject() {
  const name = $id('pfName')?.value.trim();
  if (!name) { markError('pfName', 'Project name is required'); return; }
  const pid = $id('pfId')?.value;
  const existing = pid ? state.projects.find(p => p.id === pid) : null;
  const data = {
    id:          existing?.id,
    name,
    code:        $id('pfCode')?.value.trim() || null,
    description: $id('pfDesc')?.value.trim() || null,
    department:  $id('pfDept')?.value.trim() || null,
    pm:          $id('pfPM')?.value.trim() || null,
    ba_team:     ($id('pfBATeam')?.value.trim() || '').split(',').map(s=>s.trim()).filter(Boolean),
    status:      $id('pfStatus')?.value || 'active',
    priority:    $id('pfPriority')?.value || 'medium',
    start_date:  $id('pfStart')?.value || null,
    end_date:    $id('pfEnd')?.value || null,
    budget:      parseFloat($id('pfBudget')?.value) || null,
    color:       $id('pfColor')?.value || '#2563eb',
    tags:        [..._projectTags],
  };
  try {
    const saved = await dbSaveProject(data);
    if (existing) updateEntity('projects', existing.id, saved);
    else addEntity('projects', saved);
    toast(existing ? 'Project updated' : `Project "${name}" created`, 'success');
    closeOverlay('projectFormOverlay');
    _refresh?.();
    _updateBadges?.();
    _updateSidebar?.();
  } catch (e) { toast(e.message, 'error'); }
}

export function confirmDeleteProject(pid) {
  const p = findProject(pid);
  if (!p) return;
  $id('confirmHeading').textContent = 'Delete Project';
  $id('confirmMsg').textContent = `Delete "${p.name}" and all its milestones & sprints? Tasks will remain but lose project association. This cannot be undone.`;
  $id('confirmOkBtn').textContent = 'Delete Project';
  $id('confirmOkBtn').onclick = async () => {
    closeOverlay('confirmOverlay');
    try {
      await dbDeleteProject(pid);
      removeEntity('projects', pid);
      setState({ milestones: state.milestones.filter(m => m.project_id !== pid) });
      setState({ sprints: state.sprints.filter(s => s.project_id !== pid) });
      state.tasks.filter(t => t.project_id === pid).forEach(t => { t.project_id = ''; });
      if (state.activeProjectId === pid) state.activeProjectId = null;
      _updateBadges?.();
      _updateSidebar?.();
      navigate('projects');
      toast('Project deleted', 'warning');
    } catch (e) { toast(e.message, 'error'); }
  };
  openOverlay('confirmOverlay');
}

/* ════════════════════════════════════════════════════════════
   MILESTONE FORM
   ════════════════════════════════════════════════════════════ */
function openMilestoneForm(milestoneId = null, projectId = null) {
  const m = milestoneId ? state.milestones.find(x => x.id === milestoneId) : null;
  $id('milestoneFormTitle').textContent = m ? 'Edit Milestone' : 'Add Milestone';
  $id('mfId').value        = m?.id         || '';
  $id('mfProjectId').value = m?.project_id || projectId || '';
  setVal('mfName',   m?.name        || '');
  setVal('mfDesc',   m?.description || '');
  setVal('mfDue',    m?.due_date    || '');
  setVal('mfStatus', m?.status      || 'pending');
  openOverlay('milestoneFormOverlay');
}

export async function saveMilestone() {
  const name = $id('mfName')?.value.trim();
  if (!name) { toast('Milestone name is required', 'error'); return; }
  const mid = $id('mfId').value;
  const existing = mid ? state.milestones.find(m => m.id === mid) : null;
  const pid = $id('mfProjectId').value;
  const data = {
    id:          existing?.id,
    project_id:  pid,
    name,
    description: $id('mfDesc')?.value.trim() || null,
    due_date:    $id('mfDue')?.value || null,
    status:      $id('mfStatus')?.value || 'pending',
    sort_order:  existing?.sort_order ?? state.milestones.filter(m => m.project_id === pid).length,
  };
  try {
    const saved = await dbSaveMilestone(data);
    if (existing) updateEntity('milestones', existing.id, saved);
    else addEntity('milestones', saved);
    closeOverlay('milestoneFormOverlay');
    _refresh?.();
    toast(existing ? 'Milestone updated' : 'Milestone added', 'success');
  } catch (e) { toast(e.message, 'error'); }
}

/* ════════════════════════════════════════════════════════════
   SPRINT FORM
   ════════════════════════════════════════════════════════════ */
function openSprintForm(sprintId = null, projectId = null) {
  const s = sprintId ? state.sprints.find(x => x.id === sprintId) : null;
  $id('sprintFormTitle').textContent = s ? 'Edit Sprint' : 'New Sprint';
  $id('sfId').value        = s?.id         || '';
  $id('sfProjectId').value = s?.project_id || projectId || '';
  setVal('sfName',   s?.name       || '');
  setVal('sfGoal',   s?.goal       || '');
  setVal('sfStart',  s?.start_date || '');
  setVal('sfEnd',    s?.end_date   || '');
  setVal('sfStatus', s?.status     || 'planning');
  openOverlay('sprintFormOverlay');
}

export async function saveSprint() {
  const name = $id('sfName')?.value.trim();
  if (!name) { toast('Sprint name is required', 'error'); return; }
  const sid = $id('sfId').value;
  const existing = sid ? state.sprints.find(s => s.id === sid) : null;
  const data = {
    id:         existing?.id,
    project_id: $id('sfProjectId').value,
    name,
    goal:       $id('sfGoal')?.value.trim() || null,
    start_date: $id('sfStart')?.value || null,
    end_date:   $id('sfEnd')?.value   || null,
    status:     $id('sfStatus')?.value || 'planning',
  };
  try {
    const saved = await dbSaveSprint(data);
    if (existing) updateEntity('sprints', existing.id, saved);
    else addEntity('sprints', saved);
    closeOverlay('sprintFormOverlay');
    _refresh?.();
    toast(existing ? 'Sprint updated' : 'Sprint added', 'success');
  } catch (e) { toast(e.message, 'error'); }
}
