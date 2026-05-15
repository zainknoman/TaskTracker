# Design: API Key Extraction, Logout Button, Team Member Modal
**Date:** 2026-05-16  
**Project:** TaskFlow Pro (V2-supabase)

---

## 1. API Key Extraction

### Problem
`SUPABASE_URL` and `SUPABASE_KEY` are hardcoded on lines 11–12 of `app.js`, making them visible in any public git repository.

### Solution
Move credentials to a separate `config.js` file that is gitignored.

### Files
| File | Action | Committed |
|---|---|---|
| `config.js` | Created — holds real credentials | No (gitignored) |
| `config.example.js` | Created — placeholder values + instructions | Yes |
| `.gitignore` | Updated — add `config.js` | Yes |
| `index.html` | Updated — add `<script src="config.js">` before `app.js` | Yes |
| `app.js` lines 11–12 | Updated — read from `window.APP_CONFIG` | Yes |

### `config.js` shape
```js
window.APP_CONFIG = {
  supabaseUrl: 'https://<your-ref>.supabase.co',
  supabaseKey: '<your-anon-key>'
};
```

### `app.js` change
```js
const SUPABASE_URL = window.APP_CONFIG.supabaseUrl;
const SUPABASE_KEY = window.APP_CONFIG.supabaseKey;
```

### Error handling
If `window.APP_CONFIG` is missing (e.g. someone cloned the repo without creating `config.js`), the app will show a clear error message directing the user to copy `config.example.js`.

---

## 2. Logout Button

### Placement
Sidebar footer (`#sidebar > .sidebar-footer`), above the existing theme toggle and collapse button.

### Visibility
Shown only when `currentUser !== null` (authenticated session). Hidden in guest mode.

### Behavior
1. User clicks "Sign Out"
2. Calls `await sb.auth.signOut()`
3. Sets `currentUser = null`
4. Hides `#app`, shows `#loginScreen`

### Styling
Uses the same ghost button style as `.theme-toggle-btn` — icon (logout SVG) + "Sign Out" label. Not styled red to avoid alarming users; it is a neutral action.

### HTML addition (sidebar footer)
```html
<button class="theme-toggle-btn" id="logoutBtn" style="display:none">
  <!-- logout SVG icon -->
  <span>Sign Out</span>
</button>
```

---

## 3. Team Member Modal

### Problem
The current "Add Member" flow uses two sequential `prompt()` calls, capturing only name and role. No photo/avatar, no contact info, no edit capability.

### Solution
Replace with a full modal overlay (`#memberFormOverlay`) matching the New Project modal pattern.

### Modal Fields
| Field | Type | Required |
|---|---|---|
| Avatar preset | Grid of ~12 selectable icons | No (defaults to initials) |
| Custom avatar URL | Text input | No (overrides preset if set) |
| Color | Dot color picker (same as projects) | No (auto from preset) |
| Name | Text input | Yes |
| Role | Text input + datalist | No |
| Department / Team | Text input | No |
| Email | Email input | No |
| Phone | Text input | No |
| Skills | Tag chips input (same pattern as task/project tags) | No |

### Preset Avatars
A grid of 12 SVG-based person silhouettes or letter-based illustrated icons. Clicking one sets `avatarPreset` index and auto-picks a complementary `color`. Custom URL input clears the preset selection.

### `state.users` schema (additions)
```js
{
  // existing
  id, name, role, avatar, color, team,
  // new
  email: '',
  phone: '',
  avatarUrl: '',      // custom image URL; overrides preset
  avatarPreset: null, // index 0–11 into preset list
  skills: [],         // string[]
}
```

### Team Card Updates (`renderTeam`)
Avatar display priority:
1. `avatarUrl` set → `<img src="...">` inside avatar bubble
2. `avatarPreset` set → render preset SVG/icon
3. Fallback → existing colored-initials bubble

Additional info shown on card:
- Email (if set) — shown as a small link below role
- Skills — displayed as small tags below the workload bar

### Edit Support
Each team card gains an "Edit" button that opens the modal pre-populated with that member's data, following the same open/save pattern as task and project forms.

---

## Out of Scope
- Real photo file upload (no server-side storage)
- Supabase user management sync (members are local app state only)
- Role-based permissions


## Features Implementation Summary
---  Feature 1 — API Key Extraction
  - config.js — created (gitignored) with your real Supabase credentials  - config.example.js — created with placeholder values for anyone cloning the repo
  - .gitignore — created, excludes config.js
  - index.html — <script src="config.js"> added before app.js
  - app.js lines 11–16 — credentials now read from window.APP_CONFIG; shows a clear error page if config.js is missing

  Feature 2 — Logout Button
  - index.html — "Sign Out" button added to sidebar footer (above theme toggle), hidden by default
  - app.js — showApp() reveals it only when currentUser is set; showLogin() hides it; click handler calls sb.auth.signOut()

  Feature 3 — Team Member Modal
  - index.html — full #memberFormOverlay modal added with avatar grid, URL input, name, role (with datalist), department, email, phone, and
  skills tag input
  - app.js — AVATAR_PRESETS constant (12 emoji options with colors), openMemberForm(), renderAvatarPresetGrid(), renderMemberSkillChips(),
  saveMember() functions added; newUserBtn now opens the modal instead of prompt(); renderTeam() updated to show photo/preset avatar, email
  link, skills tags, and an Edit button on each card
  - style.css — .avatar-preset-grid and .avatar-preset-btn styles added