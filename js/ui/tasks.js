import { state, findTask, findProject, getActiveTasks, getBAList, updateEntity, addEntity, removeEntity } from '../state.js';
import { $id, esc, fmtDate, isOverdue, calcProgress, getTagColor, setVal, markError, openOverlay, closeOverlay, toast, STATUS_META, PRIORITY_META, copyText, renderMarkdown } from '../utils.js';
import { exportTaskJSON } from '../export-import.js';
import { saveTask as dbSaveTask, deleteTask as dbDeleteTask, logTaskActivity } from '../storage.js';

let _refresh, _updateBadges;
export function setCallbacks(refresh, updateBadges) {
  _refresh = refresh; _updateBadges = updateBadges;
}

/* ════════════════════════════════════════════════════════════
   TASK LIST
   ════════════════════════════════════════════════════════════ */
function getFilteredTasks() {
  let tasks = [...state.tasks];
  const { project, status, priority, ba, milestone, from, to } = state.filters;
  const q = state.searchQuery.toLowerCase();
  if (project)   tasks = tasks.filter(t => t.project_id   === project);
  if (status)    tasks = tasks.filter(t => t.status      === status);
  if (priority)  tasks = tasks.filter(t => t.priority    === priority);
  if (ba)        tasks = tasks.filter(t => t.ba          === ba);
  if (milestone) tasks = tasks.filter(t => t.milestone_id === milestone);
  if (from)      tasks = tasks.filter(t => t.due_date && t.due_date >= from);
  if (to)        tasks = tasks.filter(t => t.due_date && t.due_date <= to);
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

export function renderTaskTableHTML(tasks) {
  if (!tasks.length) return '<p class="no-data" style="padding:30px">No tasks</p>';
  return `<table class="task-table"><thead><tr>
    <th class="sortable" data-sort="title">Title ↕</th>
    <th>Project</th>
    <th class="sortable" data-sort="status">Status ↕</th>
    <th class="sortable" data-sort="priority">Priority ↕</th>
    <th class="sortable" data-sort="ba">BA ↕</th>
    <th class="sortable" data-sort="due_date">Due ↕</th>
    <th>Tags</th>
    <th>Progress</th>
    <th>Actions</th>
  </tr></thead><tbody>
  ${tasks.map(t => renderTaskRow(t)).join('')}
  </tbody></table>`;
}

function renderTaskRow(t) {
  const p = findProject(t.project_id);
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
    <td style="color:${over ? '#dc2626' : 'inherit'};white-space:nowrap">${fmtDate(t.due_date)}</td>
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

export function bindTaskTableEvents(container) {
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
        const t = findTask(id);
        if (t) {
          const newStarred = !t.starred;
          updateEntity('tasks', id, { starred: newStarred });
          dbSaveTask({ ...t, starred: newStarred }).catch(e2 => toast(e2.message, 'error'));
          _refresh?.();
          toast(newStarred ? 'Starred ⭐' : 'Star removed', 'info');
        }
      }
    });
  });
  container.querySelectorAll('th.sortable').forEach(th => {
    th.addEventListener('click', () => {
      const field = th.dataset.sort;
      if (state.sortField === field) state.sortDir = state.sortDir === 'asc' ? 'desc' : 'asc';
      else { state.sortField = field; state.sortDir = 'asc'; }
      _refresh?.();
    });
  });
}

export function renderTaskList() {
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
   TASK FORM
   ════════════════════════════════════════════════════════════ */
export function openTaskForm(taskId = null, presetProjectId = null) {
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
      state.projects.map(p => `<option value="${esc(p.id)}" ${(task?.project_id||presetProjectId)===p.id?'selected':''}>${esc(p.name)}</option>`).join('');
    updateDependentSelectors(task?.project_id || presetProjectId);
    projSel.addEventListener('change', () => updateDependentSelectors(projSel.value));
  }
  setVal('fTitle',       task?.title            || '');
  setVal('fDesc',        task?.description      || '');
  setVal('fPriority',    task?.priority         || 'medium');
  setVal('fStatus',      task?.status           || 'pending');
  setVal('fStartDate',   task?.start_date       || '');
  setVal('fDueDate',     task?.due_date         || '');
  setVal('fBA',          task?.ba               || '');
  setVal('fHours',       task?.estimated_hours  || '');
  setVal('fActualHours', task?.actual_hours     || '');
  setVal('fProgress',    task?.progress         || 0);
  setVal('fNotes',       task?.notes            || '');
  const notesPreview = $id('fNotesPreview');
  if (notesPreview) notesPreview.innerHTML = renderMarkdown(task?.notes || '');
  const pv = $id('fProgressVal'); if (pv) pv.textContent = (task?.progress || 0) + '%';
  const asSel = $id('fAssignee');
  if (asSel) {
    asSel.innerHTML = '<option value="">Unassigned</option>' +
      state.members.map(u => `<option value="${esc(u.id)}" ${task?.assignee_id===u.id?'selected':''}>${esc(u.display_name||'Member')}</option>`).join('');
  }
  const dl = $id('baDatalist');
  if (dl) dl.innerHTML = getBAList().map(b => `<option value="${esc(b)}">`).join('');
  renderFormTags(); renderFormDocs(); renderFormSubtasks();
  const tagInp = $id('fTagInput');
  if (tagInp) {
    const freshTagInp = tagInp.cloneNode(true);
    tagInp.replaceWith(freshTagInp);
    freshTagInp.addEventListener('keydown', e => {
      if (e.key !== 'Enter') return;
      e.preventDefault();
      const v = freshTagInp.value.trim();
      if (v && !state.formTags.includes(v)) { state.formTags.push(v); renderFormTags(); }
      freshTagInp.value = '';
    });
  }
  $id('addDocBtn') && ($id('addDocBtn').onclick = () => { state.formDocs.push({ title: '', url: '' }); renderFormDocs(); });
  $id('addSubtaskBtn') && ($id('addSubtaskBtn').onclick = () => { state.formSubtasks.push({ id: crypto.randomUUID(), title: '', done: false }); renderFormSubtasks(); });
  openOverlay('formOverlay');
  setTimeout(() => $id('fTitle')?.focus(), 100);
}

function updateDependentSelectors(pid) {
  const ms = state.milestones.filter(m => m.project_id === pid);
  const ss = state.sprints.filter(s => s.project_id === pid);
  const curTask = $id('fId')?.value;
  const mSel = $id('fMilestone');
  if (mSel) mSel.innerHTML = '<option value="">No milestone</option>' + ms.map(m => `<option value="${esc(m.id)}">${esc(m.name)}</option>`).join('');
  const sSel = $id('fSprint');
  if (sSel) sSel.innerHTML = '<option value="">No sprint</option>' + ss.map(s => `<option value="${esc(s.id)}">${esc(s.name)}</option>`).join('');
  const pSel = $id('fParent');
  if (pSel) pSel.innerHTML = '<option value="">Top-level task</option>' +
    state.tasks.filter(t => t.project_id === pid && t.id !== curTask).map(t => `<option value="${esc(t.id)}">${esc(t.title)}</option>`).join('');
  const dSel = $id('fDeps');
  if (dSel) dSel.innerHTML = state.tasks.filter(t => t.id !== curTask).map(t => `<option value="${esc(t.id)}">${esc(t.title)}</option>`).join('');
}

function renderFormTags() {
  const chips = $id('tagChips');
  if (!chips) return;
  chips.innerHTML = state.formTags.map((tg, i) => `
    <span class="tag-chip tag-color-${getTagColor(tg)}">${esc(tg)}<span class="tag-chip-remove" data-i="${i}">×</span></span>`).join('');
  chips.querySelectorAll('.tag-chip-remove').forEach(btn =>
    btn.addEventListener('click', () => { state.formTags.splice(+btn.dataset.i, 1); renderFormTags(); })
  );
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
  list.querySelectorAll('.doc-remove').forEach(btn =>
    btn.addEventListener('click', () => { state.formDocs.splice(+btn.dataset.di, 1); renderFormDocs(); })
  );
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
  list.querySelectorAll('.subtask-checkbox').forEach(cb =>
    cb.addEventListener('change', () => {
      const i = +cb.dataset.si;
      state.formSubtasks[i].done = cb.checked;
      list.querySelectorAll('.subtask-input')[i]?.classList.toggle('done', cb.checked);
    })
  );
  list.querySelectorAll('.subtask-input').forEach(inp =>
    inp.addEventListener('input', () => { state.formSubtasks[+inp.dataset.si].title = inp.value; })
  );
  list.querySelectorAll('.subtask-remove').forEach(btn =>
    btn.addEventListener('click', () => { state.formSubtasks.splice(+btn.dataset.si, 1); renderFormSubtasks(); })
  );
}

export async function saveTask() {
  const title = $id('fTitle')?.value.trim();
  if (!title) { markError('fTitle', 'Title is required'); return; }
  const project_id = $id('fProject')?.value;
  if (!project_id) { markError('fProject', 'Please select a project'); return; }

  const documents = [];
  document.querySelectorAll('#docsList .doc-row').forEach(row => {
    const t2 = row.querySelector('.doc-title-inp')?.value.trim();
    const u2 = row.querySelector('.doc-url-inp')?.value.trim();
    if (t2 || u2) documents.push({ title: t2 || '', url: u2 || '' });
  });
  const subtasks = [];
  document.querySelectorAll('#subtaskList .subtask-item').forEach(row => {
    const t2 = row.querySelector('.subtask-input')?.value.trim();
    const done = row.querySelector('.subtask-checkbox')?.checked;
    if (t2) subtasks.push({ id: crypto.randomUUID(), title: t2, done: !!done });
  });
  const dependencies = [...($id('fDeps')?.selectedOptions || [])].map(o => o.value);
  const progress = subtasks.length
    ? Math.round(subtasks.filter(s=>s.done).length / subtasks.length * 100)
    : parseInt($id('fProgress')?.value || 0);
  const taskId = $id('fId')?.value;
  const existing = taskId ? state.tasks.find(t => t.id === taskId) : null;

  const data = {
    id:              existing?.id,
    title,
    description:     $id('fDesc')?.value.trim() || null,
    project_id,
    milestone_id:    $id('fMilestone')?.value || null,
    sprint_id:       $id('fSprint')?.value || null,
    parent_task_id:  $id('fParent')?.value || null,
    priority:        $id('fPriority')?.value || 'medium',
    status:          $id('fStatus')?.value || 'pending',
    start_date:      $id('fStartDate')?.value || null,
    due_date:        $id('fDueDate')?.value || null,
    ba:              $id('fBA')?.value.trim() || null,
    assignee_id:     null,
    estimated_hours: parseFloat($id('fHours')?.value) || null,
    actual_hours:    parseFloat($id('fActualHours')?.value) || null,
    tags:            [...state.formTags],
    documents,
    dependencies,
    subtasks,
    progress,
    notes:           $id('fNotes')?.value.trim() || null,
    starred:         existing?.starred || false,
    pinned:          existing?.pinned || false,
  };

  try {
    const old_status = existing?.status;
    const saved = await dbSaveTask(data);
    if (existing) {
      updateEntity('tasks', existing.id, saved);
      if (old_status !== saved.status) {
        await logTaskActivity(saved.id, 'status_changed', old_status, saved.status,
          `Status changed from ${old_status} to ${saved.status}`);
      }
      toast('Task updated', 'success');
    } else {
      addEntity('tasks', saved);
      await logTaskActivity(saved.id, 'created', null, null, 'Task created');
      toast('Task created', 'success');
    }
    closeOverlay('formOverlay');
    _refresh?.();
    _updateBadges?.();
  } catch (e) { toast(e.message, 'error'); }
}

/* ════════════════════════════════════════════════════════════
   TASK DETAIL MODAL
   ════════════════════════════════════════════════════════════ */
export function openTaskDetail(taskId) {
  const t = findTask(taskId);
  if (!t) return;
  $id('detailTitle').textContent = t.title;
  $id('detailStatusBadge').innerHTML = `<span class="badge badge-${t.status}">${STATUS_META[t.status].label}</span>`;
  $id('detailStarBtn').style.opacity = t.starred ? '1' : '0.5';
  const p = findProject(t.project_id);
  const depTasks = (t.dependencies || []).map(id => findTask(id)).filter(Boolean);
  const body = $id('detailBody');
  if (!body) return;
  body.innerHTML = `
    ${p ? `<div style="margin-bottom:14px"><span class="project-pill" style="background:${p.color}18;color:${p.color};border:1px solid ${p.color}44">📁 ${esc(p.name)}</span>${t.milestone_id ? ` <span class="badge badge-info" style="font-size:.72rem">◆ ${esc(state.milestones.find(m=>m.id===t.milestone_id)?.name||'')}</span>` : ''}</div>` : ''}
    <div class="detail-grid">
      <div class="detail-field"><label>Priority</label><span><span class="badge badge-${t.priority}">${PRIORITY_META[t.priority].label}</span></span></div>
      <div class="detail-field"><label>Status</label><span><span class="badge badge-${t.status}">${STATUS_META[t.status].label}</span></span></div>
      <div class="detail-field"><label>Assigned BA</label><span>${t.ba ? esc(t.ba) : '—'}</span></div>
      <div class="detail-field"><label>Assignee</label><span>${t.assignee_id ? esc(state.members.find(u=>u.id===t.assignee_id)?.display_name||t.assignee_id) : '—'}</span></div>
      <div class="detail-field"><label>Start Date</label><span>${fmtDate(t.start_date)}</span></div>
      <div class="detail-field"><label>Due Date</label><span style="color:${isOverdue(t)?'#dc2626':'inherit'}">${fmtDate(t.due_date)}${isOverdue(t)?' ⚠️':''}</span></div>
      <div class="detail-field"><label>Estimated Hours</label><span>${t.estimated_hours || 0} hrs</span></div>
      <div class="detail-field"><label>Actual Hours</label><span>${t.actual_hours || 0} hrs</span></div>
      <div class="detail-field full">
        <label>Progress — ${calcProgress(t)}%</label>
        <div class="progress-track" style="height:8px;margin-top:4px"><div class="progress-fill" style="width:${calcProgress(t)}%"></div></div>
      </div>
    </div>
    ${t.description ? `<div class="detail-section"><div class="detail-section-header"><h4>Description</h4><button type="button" class="detail-copy-btn" data-copy-type="description">Copy</button></div><p style="font-size:.85rem;color:var(--text-2);line-height:1.6;white-space:pre-wrap">${esc(t.description)}</p></div>` : ''}
    ${t.tags?.length ? `<div class="detail-section"><h4>Tags</h4><div style="display:flex;flex-wrap:wrap;gap:6px">${t.tags.map(tg=>`<span class="tag-chip tag-color-${getTagColor(tg)}">${esc(tg)}</span>`).join('')}</div></div>` : ''}
    ${t.subtasks?.length ? `<div class="detail-section"><h4>Subtasks (${t.subtasks.filter(s=>s.done).length}/${t.subtasks.length})</h4>
      ${t.subtasks.map(s=>`<div class="subtask-detail-item ${s.done?'done':''}">
        <span>${s.done?'✅':'⬜'}</span><span>${esc(s.title)}</span><button type="button" class="detail-copy-btn" data-copy-type="subtask" data-copy-value="${esc(s.title)}">Copy</button>
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
    ${t.notes ? `<div class="detail-section"><div class="detail-section-header"><h4>Notes</h4><button type="button" class="detail-copy-btn" data-copy-type="notes">Copy</button></div><div class="markdown-body task-notes-preview">${renderMarkdown(t.notes)}</div></div>` : ''}
    <div class="detail-section"><h4>Activity</h4><p class="no-data">No activity yet</p></div>`;
  body.querySelectorAll('.detail-copy-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const type = btn.dataset.copyType;
      const value = type === 'description' ? t.description : type === 'notes' ? t.notes : btn.dataset.copyValue;
      copyText(value || '', `${type === 'subtask' ? 'Subtask' : type[0].toUpperCase() + type.slice(1)} copied!`);
    });
  });
  body.querySelectorAll('.doc-copy-btn').forEach(btn =>
    btn.addEventListener('click', () => navigator.clipboard?.writeText(btn.dataset.url).then(() => toast('Link copied!', 'info')))
  );
  body.querySelectorAll('.dep-item[data-id]').forEach(el =>
    el.addEventListener('click', () => { closeOverlay('detailOverlay'); openTaskDetail(el.dataset.id); })
  );
  $id('detailExportBtn')?.addEventListener('click', () => exportTaskJSON(taskId));
  $id('detailEditBtn').onclick   = () => { closeOverlay('detailOverlay'); openTaskForm(taskId); };
  $id('detailDeleteBtn').onclick = () => { closeOverlay('detailOverlay'); confirmDeleteTask(taskId); };
  $id('detailStarBtn').onclick   = () => {
    const newStarred = !t.starred;
    updateEntity('tasks', t.id, { starred: newStarred });
    $id('detailStarBtn').style.opacity = newStarred ? '1' : '0.5';
    dbSaveTask({ ...t, starred: newStarred }).catch(e => toast(e.message, 'error'));
    _refresh?.();
    toast(newStarred ? 'Starred ⭐' : 'Unstarred', 'info');
  };
  openOverlay('detailOverlay');
}

/* ════════════════════════════════════════════════════════════
   DELETE TASK
   ════════════════════════════════════════════════════════════ */
export function confirmDeleteTask(taskId) {
  const t = findTask(taskId);
  if (!t) return;
  $id('confirmHeading').textContent = 'Delete Task';
  $id('confirmMsg').textContent = `Delete "${t.title}"? This cannot be undone.`;
  $id('confirmOkBtn').textContent = 'Delete';
  $id('confirmOkBtn').onclick = async () => {
    closeOverlay('confirmOverlay');
    try {
      await dbDeleteTask(taskId);
      removeEntity('tasks', taskId);
      state.tasks.forEach(x => { x.dependencies = (x.dependencies||[]).filter(id => id !== taskId); });
      _refresh?.();
      _updateBadges?.();
      toast('Task deleted', 'warning');
    } catch (e) { toast(e.message, 'error'); }
  };
  openOverlay('confirmOverlay');
}
