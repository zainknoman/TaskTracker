/* ════════════════════════════════════════════════════════════
   GANTT TIMELINE
   ════════════════════════════════════════════════════════════ */
import { state, getActiveTasks, findProject } from '../state.js';
import { $id, esc, fmtDate, daysUntil, STATUS_META, PRIORITY_META, toast } from '../utils.js';

export function renderGantt() {
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
    const pS = p.start_date ? barPct(p.start_date) : '0';
    const pE = p.end_date   ? barPct(p.end_date)   : '100';
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