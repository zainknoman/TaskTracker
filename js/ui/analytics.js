/* ════════════════════════════════════════════════════════════
   ANALYTICS
   ════════════════════════════════════════════════════════════ */
import { state, getActiveTasks, getProjectTasks, findProject } from '../state.js';
import { $id, esc, fmtDate, daysUntil, isOverdue, STATUS_META, PRIORITY_META, toast } from '../utils.js';

export function renderAnalytics() {
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
          const u = state.members.find(u => u.display_name === name);
          return `<div class="hbar-item">
            <div class="hbar-label-row">
              <span class="hbar-label" style="display:flex;align-items:center;gap:6px">
                <span style="width:20px;height:20px;border-radius:50%;background:${u?.color||'#2563eb'};display:inline-flex;align-items:center;justify-content:center;font-size:.6rem;color:#fff;font-weight:700;flex-shrink:0">${name.slice(0,2).toUpperCase()}</span>
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
            { label:'Total Hours Est', val: tasks.reduce((a,t)=>a+(t.estimated_hours||0),0)+'h', color:'#0891b2' },
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
          { label: 'Tasks without due date',  count: tasks.filter(t=>!t.due_date&&t.status!=='completed').length, level: 'medium' },
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