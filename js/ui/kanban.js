
import { state, findProject, getActiveTasks } from '../state.js';
import { $id, esc, STATUS_META, toast } from '../utils.js';
import { saveTask as dbSaveTask } from '../storage.js';
import { updateEntity } from '../state.js';

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

// Status drop handler (called from inline ondrop in rendered HTML)
window.kanbanDrop = async function(status) {
  if (!state.draggedTaskId) return;
  const task = state.tasks.find(t => t.id === state.draggedTaskId);
  if (!task || task.status === status) return;
  const oldStatus = task.status;
  updateEntity('tasks', task.id, { status });  // optimistic
  renderKanban();
  try {
    await dbSaveTask({ ...task, status });
  } catch(e) {
    updateEntity('tasks', task.id, { status: oldStatus }); // rollback
    renderKanban();
    toast(e.message, 'error');
  }
};

