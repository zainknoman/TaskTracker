/* ════════════════════════════════════════════════════════════
   CALENDAR
   ════════════════════════════════════════════════════════════ */
import { state, getActiveTasks, findProject } from '../state.js';
import { $id, esc, fmtDate, daysUntil, STATUS_META, PRIORITY_META, toast } from '../utils.js';

export function renderCalendar() {
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