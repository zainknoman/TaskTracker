import { state, findProject, findTask, getActiveTasks, getProjectTasks, updateEntity } from '../state.js';
import { $id, esc, fmtDate, isOverdue, calcProgress, getTagColor, today, STATUS_META, PRIORITY_META, toast } from '../utils.js';
import { saveTask as dbSaveTask } from '../storage.js';

/* ════════════════════════════════════════════════════════════
   KANBAN
   ════════════════════════════════════════════════════════════ */
export function renderKanban() {
  const pid = $id('kanbanProjectFilter')?.value || '';
  const title = $id('kanbanViewTitle');
  if (title) { const p = pid ? findProject(pid) : null; title.textContent = p ? `${p.name} — Kanban` : 'Kanban Board'; }
  const tasks = pid ? getProjectTasks(pid) : state.tasks;
  renderKanbanInto($id('kanbanBoard'), tasks);
}

export function renderKanbanInto(board, tasks) {
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
          const p = findProject(t.project_id);
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
              ${t.due_date ? `<span style="color:${over?'#dc2626':'inherit'}">${over?'⚠️':''} ${fmtDate(t.due_date)}</span>` : ''}
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
    drop.addEventListener('drop', async (e) => {
      e.preventDefault();
      drop.closest('.kanban-column').classList.remove('drag-over');
      const newStatus = drop.dataset.status;
      if (!state.draggedTaskId) return;
      const task = findTask(state.draggedTaskId);
      if (!task || task.status === newStatus) return;
      const oldStatus = task.status;
      const updates = { status: newStatus };
      if (newStatus === 'completed') updates.progress = 100;
      updateEntity('tasks', task.id, updates);
      renderKanban();
      try {
        await dbSaveTask({ ...task, ...updates });
        toast(`Moved to ${STATUS_META[newStatus].label}`, 'success');
      } catch (e2) {
        updateEntity('tasks', task.id, { status: oldStatus });
        renderKanban();
        toast(e2.message, 'error');
      }
    });
  });
  board.querySelectorAll('.task-title-link').forEach(el => el.addEventListener('click', () => window.openTaskDetail?.(el.dataset.id)));
}
