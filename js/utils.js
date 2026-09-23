
export const AVATAR_PRESETS = [
  { icon: '👤', color: '#2563eb' }, { icon: '👩', color: '#db2777' },
  { icon: '👨', color: '#0891b2' }, { icon: '👩‍💼', color: '#7c3aed' },
  { icon: '👨‍💼', color: '#059669' }, { icon: '👩‍💻', color: '#dc2626' },
  { icon: '👨‍💻', color: '#d97706' }, { icon: '👩‍🔬', color: '#65a30d' },
  { icon: '👨‍🔬', color: '#0891b2' }, { icon: '🧑‍🎨', color: '#db2777' },
  { icon: '🧑‍🏫', color: '#7c3aed' }, { icon: '🧑‍💻', color: '#2563eb' },
];

export const PROJECT_COLORS = [
  '#2563eb','#059669','#7c3aed','#d97706',
  '#dc2626','#0891b2','#db2777','#65a30d'
];

export const STATUS_META = {
  pending:    { label: 'Pending',     dot: '#fbbf24', color: '#d97706' },
  inprogress: { label: 'In Progress', dot: '#60a5fa', color: '#2563eb' },
  completed:  { label: 'Completed',   dot: '#34d399', color: '#059669' },
  blocked:    { label: 'Blocked',     dot: '#f87171', color: '#dc2626' },
};

export const PRIORITY_META = {
  low:      { label: 'Low',      order: 1 },
  medium:   { label: 'Medium',   order: 2 },
  high:     { label: 'High',     order: 3 },
  critical: { label: 'Critical', order: 4 },
};

export function uid() { return '_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }
export function today() { return new Date().toISOString().split('T')[0]; }
export function fmtDate(d) {
  if (!d) return '—';
  return new Date(d + 'T00:00:00').toLocaleDateString('en-GB', { day:'2-digit', month:'short', year:'numeric' });
}
export function isOverdue(t) {
  return t.due_date && t.status !== 'completed' && new Date(t.due_date) < new Date(new Date().toDateString());
}
export function daysUntil(d) {
  if (!d) return null;
  return Math.round((new Date(d) - new Date(new Date().toDateString())) / 86400000);
}
export function esc(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
export function getTagColor(tag) {
  let h = 0; for (let c of String(tag)) h = (h * 31 + c.charCodeAt(0)) & 0xffffffff; return Math.abs(h) % 8;
}
export function calcProgress(task) {
  if (!task.subtasks?.length) return task.progress || 0;
  const done = task.subtasks.filter(s => s.done).length;
  return Math.round(done / task.subtasks.length * 100);
}
export function openOverlay(id) { document.getElementById(id)?.classList.add('open'); }
export function closeOverlay(id) { document.getElementById(id)?.classList.remove('open'); }
export function $id(id) { return document.getElementById(id); }
export function setVal(id, v) { const el = $id(id); if (el) el.value = v ?? ''; }
export function markError(id, msg) {
  const el = $id(id); if (!el) return;
  const fg = el.closest('.form-group');
  if (fg) {
    fg.classList.add('has-error');
    if (!fg.querySelector('.field-error')) {
      const e = document.createElement('span');
      e.className = 'field-error'; e.textContent = msg; fg.appendChild(e);
    }
  }
  el.focus();
}

const TOAST_ICONS = {
  success: `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>`,
  error:   `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>`,
  warning: `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>`,
  info:    `<svg class="toast-icon" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/></svg>`,
};
export function toast(msg, type = 'info', dur = 3500) {
  const c = document.getElementById('toastContainer'); if (!c) return;
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = `${TOAST_ICONS[type] || ''}<span class="toast-msg">${esc(msg)}</span><span class="toast-close">×</span>`;
  el.querySelector('.toast-close').addEventListener('click', () => el.remove());
  c.appendChild(el);
  setTimeout(() => el.remove(), dur + 300);
}

export function renderMarkdown(source) {
  if (!source) return '';
  if (typeof marked === 'undefined') return esc(source);
  return marked.parse(source, { breaks: true });
}

export async function copyText(text, successMessage = 'Copied!') {
  const value = String(text ?? '');
  try {
    if (navigator.clipboard?.writeText) await navigator.clipboard.writeText(value);
    else throw new Error('Clipboard API unavailable');
    toast(successMessage, 'info');
    return true;
  } catch {
    const ta = document.createElement('textarea');
    ta.value = value;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand('copy');
    ta.remove();
    if (ok) toast(successMessage, 'info');
    return ok;
  }
}
