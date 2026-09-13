
/* ════════════════════════════════════════════════════════════
   TEAM
   ════════════════════════════════════════════════════════════ */

import { state, updateEntity } from '../state.js';
import { $id, esc, setVal, openOverlay, closeOverlay, toast, AVATAR_PRESETS } from '../utils.js';
import { updateMember } from '../storage.js';

let memberFormPreset = null;
let memberFormSkills = [];

export function renderTeam() {
  const container = $id('teamContainer'); if (!container) return;
  if (!state.members.length) {
    container.innerHTML = '<p class="no-data" style="padding:40px">No team members yet. Invite someone from Settings.</p>';
    return;
  }
  container.innerHTML = `<div class="team-grid">${state.members.map(u => {
    const assigned = state.tasks.filter(t => t.ba === u.display_name);
    const open  = assigned.filter(t => t.status !== 'completed').length;
    const done  = assigned.filter(t => t.status === 'completed').length;
    const blkd  = assigned.filter(t => t.status === 'blocked').length;
    const maxTasks = Math.max(...state.members.map(uu =>
      state.tasks.filter(t => t.ba === uu.display_name).length), 1);
    const wlPct = Math.round(assigned.length / maxTasks * 100);
    const avatarHtml = u.avatar_url
      ? `<img src="${esc(u.avatar_url)}" style="width:44px;height:44px;border-radius:50%;object-fit:cover;flex-shrink:0">`
      : (u.avatar_preset != null
          ? `<div class="team-avatar" style="background:${u.color || '#2563eb'}">${AVATAR_PRESETS[u.avatar_preset]?.icon || '👤'}</div>`
          : `<div class="team-avatar" style="background:${u.color || '#2563eb'}">👤</div>`);
    return `<div class="team-card">
      <div class="team-card-top">
        ${avatarHtml}
        <div style="flex:1;min-width:0">
          <div class="team-name">${esc(u.display_name || 'Member')}</div>
          <div class="team-role" style="color:var(--text-3)">${esc(u.role || '')}</div>
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
        <div class="workload-bar"><div class="workload-fill" style="width:${wlPct}%;background:${wlPct>80?'#dc2626':wlPct>50?'#d97706':(u.color||'#2563eb')}"></div></div>
      </div>
    </div>`;
  }).join('')}</div>`;
}

export function openMemberForm(memberId) {
  const m = state.members.find(x => x.id === memberId);
  if (!m) return;
  memberFormPreset = m.avatar_preset ?? null;
  memberFormSkills = [...(m.skills || [])];
  setVal('mbrId',        m.id);
  setVal('mbrName',      m.display_name || '');
  setVal('mbrAvatarUrl', m.avatar_url   || '');
  renderAvatarPresetGrid();
  renderMemberSkillChips();
  const skillInp = $id('mbrSkillInput');
  if (skillInp) {
    const fresh = skillInp.cloneNode(true);
    skillInp.replaceWith(fresh);
    fresh.addEventListener('keydown', e => {
      if (e.key !== 'Enter') return;
      e.preventDefault();
      const v = fresh.value.trim();
      if (v && !memberFormSkills.includes(v)) { memberFormSkills.push(v); renderMemberSkillChips(); }
      fresh.value = '';
    });
  }
  openOverlay('memberFormOverlay');
}

export async function saveMember() {
  const memberId = $id('mbrId')?.value;
  const m = state.members.find(x => x.id === memberId);
  if (!m) return;
  const updates = {
    display_name:  $id('mbrName')?.value.trim() || null,
    avatar_url:    $id('mbrAvatarUrl')?.value.trim() || null,
    avatar_preset: memberFormPreset,
    skills:        [...memberFormSkills],
  };
  try {
    await updateMember(memberId, updates);
    updateEntity('members', memberId, updates);
    toast('Member updated', 'success');
    closeOverlay('memberFormOverlay');
    renderTeam();
  } catch (e) { toast(e.message, 'error'); }
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
