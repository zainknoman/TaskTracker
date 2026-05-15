# TaskFlow Pro ⚡

> **Enterprise Work Management System** — A fully client-side, zero-dependency project and task management platform built with vanilla JavaScript, HTML, and CSS.

![Version](https://img.shields.io/badge/version-3.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![JS](https://img.shields.io/badge/JavaScript-ES2020-yellow)
![No Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

---
- Design
<p align="center">
  <img src="/docs/screenshots/01-dashboard.jpeg" alt="Template Design" width="600"/>
</p>
---
## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Views & Navigation](#views--navigation)
- [Data Model](#data-model)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Import & Export](#import--export)
- [Extending the App](#extending-the-app)
- [File Structure](#file-structure)
- [Browser Support](#browser-support)
- [License](#license)

---

## Overview

TaskFlow Pro transforms a flat task tracker into a full enterprise-grade work management platform — similar in concept to Jira, ClickUp, or Asana — but running entirely in the browser with **no backend, no build step, and no dependencies**.

All data is persisted in `localStorage` with auto-save every 1.8 seconds. The entire application ships as three files: `index.html`, `app.js`, and `style.css`.

---

## Features

### Project Management
- Full **Project CRUD** with code, department, client, PM, BA team, budget, status, priority, colour theme, and tags
- Per-project **Dashboard**, **Kanban**, **Task List**, **Milestones**, and **Sprints** tabs
- Project **sidebar navigation** with open-task counters
- Archive, filter, and switch between projects
## Design Templates / Workflow
  
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/02-00-projects.jpeg" alt="Projects" width="100%"/>    
      <br/>
      <sub><b>Projects</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/02-01-project-overview.jpeg" alt="Project Overview" width="100%"/>    
      <br/>
      <sub><b>Project Overview</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/02-02-project-tasks.jpeg" alt="Project Task" width="100%"/>    
      <br/>
      <sub><b>Project Task</b></sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/02-03-project-kanban.jpeg" alt="Project Kanban" width="100%"/>
      <br/>
      <sub><b>Project Kanban</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/02-04-project-milestones.jpeg" alt="Project Milestones" width="100%"/>    
      <br/>
      <sub><b>Project Milestone</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/02-05-project-sprints.jpeg" alt="Project Sprints" width="100%"/>    
      <br/>
      <sub><b>Project Sprints</b></sub>
    </td>
  </tr>
</table>

### Kanban Board
- Four columns: Pending · In Progress · Completed · Blocked
- **Drag-and-drop** between columns with status auto-update
- Filter Kanban by project
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/04-kanban.jpeg" alt="Kanban" width="100%"/>
      <br/>
      <sub><b>Kanban</b></sub>
    </td>
  </tr>
</table>
  
### Gantt Timeline
- Auto-generated horizontal bar chart across all projects
- Configurable date range (3 / 6 / 12 months)
- Milestone markers and task bars colour-coded by project
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/06-ganttTimelines.jpeg" alt="Tasks" width="100%"/>
      <br/>
      <sub><b>Tasks</b></sub>
    </td>
  </tr>
</table>

### Analytics
- Tasks by status and priority (horizontal bar charts)
- Project progress comparison
- BA workload distribution
- Summary KPIs (completion rate, overdue count, blocked rate, estimated hours)
- Risk indicators panel
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/07-analytics.jpeg" alt="Analytics" width="100%"/>
      <br/>
      <sub><b>Analytics</b></sub>
    </td>
  </tr>
</table>

### Task Management
- Tasks are linked to Projects, Milestones, Sprints, and parent tasks
- Rich task fields: title, description, priority, status, BA, assignee, start/due dates, estimated/actual hours, progress, tags, documents, dependencies, subtasks, and notes
- **Subtask checklists** with auto progress calculation
- **Dependency tracking** with cross-task linking
- Star ⭐ and Pin 📌 tasks
- Full **activity audit log** per task
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/03-00-tasks.jpeg" alt="Tasks" width="100%"/>
      <br/>
      <sub><b>Tasks</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/03-01-tasks-view.jpeg" alt="Task View" width="100%"/>
      <br/>
      <sub><b>Task View</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/03-02-tasks-edit-basicInfo.jpeg" alt="Task Basic Info" width="100%"/>
      <br/>
      <sub><b>Task Basic Info</b></sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/03-02-tasks-edit-schedule.jpeg" alt="Task Schedule" width="100%"/>
      <br/>
      <sub><b>Task Schedule</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/03-02-tasks-edit-docs-dependency.jpeg" alt="Task Docs & Dependencies" width="100%"/>
      <br/>
      <sub><b>Task Docs & Dependencies</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/03-02-tasks-edit-subtask.jpeg" alt="Task SubTask" width="100%"/>
      <br/>
      <sub><b>Task SubTask</b></sub>
    </td>
  </tr>
</table>
### Sprint Burndown
- Per-sprint SVG burndown chart (ideal vs actual remaining tasks)
- Sprint velocity tracking

### Notifications
- Auto-built from live data: overdue tasks, blocked tasks, "due tomorrow" alerts, upcoming milestone deadlines
- Bell icon with unread badge count
- Mark all read / clear all
- Refreshes every 5 minutes in the background

### Smart Productivity Check
- One-click workspace audit:
  - 🚨 Overdue critical tasks
  - 🔗 Blocked dependency chains
  - 👤 Unassigned critical tasks
  - 🔥 BA overload detection (>5 open tasks)
  - 📁 Empty active projects
  - 📅 Tasks missing due dates
  - 🔁 Duplicate task title detection

### Saved Views
- Snapshot any combination of filters, sort order, and search query with a custom name
- Re-apply saved views in one click
- Stored per session in `localStorage`

### Deadline Health Score
- 0–100 project health score based on overdue/blocked/undated task penalties
- Colour-coded labels: Excellent · Good · At Risk · Critical

### Team Management
- Team member cards with avatar, role, open/done/blocked counters, and workload bar
- Workload balance suggestion when spread between members exceeds 2 tasks
- **Add / Edit member modal** — replaces the old prompt() flow with a full overlay form containing:
  - Avatar preset grid (12 emoji/icon options, each auto-selects a complementary colour)
  - Custom avatar URL input (overrides preset when set)
  - Dot colour picker
  - Name (required), Role (with datalist), Department / Team, Email, Phone
  - Skills tag-chip input (same pattern as task tags)
- Avatar display priority on cards: custom URL → preset icon → coloured initials
- Email shown as a clickable link below the role; skills displayed as tag chips below the workload bar
- Edit button on each card opens the modal pre-populated with that member's data
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/08-team.jpeg" alt="Team" width="80%"/>
      <br/>
    </td>
  </tr>
</table>

### Calendar
- Monthly calendar with task due-date markers per day
- Click any task dot to open the task detail modal
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/05-calendar.jpeg" alt="Calendar" width="80%"/>
      <br/>
      <sub><b>Calendar</b></sub>
    </td>
  </tr>
</table>

### Command Palette
- `Ctrl/⌘ + P` opens a fuzzy-search command launcher
- Navigate to any view, create tasks/projects, or filter by status in one keystroke
- Arrow key navigation + Enter to execute
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/09-command-palette.jpeg" alt="Command Palette" width="80%"/>
      <br/>
    </td>
  </tr>
</table>

### Global Search
- `Ctrl/⌘ + K` — live dropdown search across tasks and projects
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/10-global-search.jpeg" alt="Calendar" width="80%"/>
      <br/>
    </td>
  </tr>
</table>

### Import / Export
- **Export JSON** — full data dump (projects, tasks, milestones, sprints, users)
- **Export CSV** — flat task list for spreadsheet use
- **Import JSON** — restore a previous export or migrate data

### Dark Mode
- Toggle in the sidebar; preference persisted across sessions
<table>
  <tr>
    <td align="center">
      <img src="/docs/screenshots/dark-01-dashboard.jpeg" alt="Dashboard" width="80%"/>
      <br/>
      <sub><b>Dashboard</b></sub>
    </td>
    <td align="center">
      <img src="/docs/screenshots/dark-02-03-project-kanban.jpeg" alt="Kanban" width="80%"/>
      <br/>
      <sub><b>Kanban</b></sub>
    </td>
  </tr>
</table>

---

## Architecture

```
Workspace (localStorage)
 └── Projects[]
      ├── Milestones[]
      ├── Sprints[]
      └── Tasks[]
           ├── Subtasks[]
           ├── Dependencies → Task IDs
           ├── Documents[]
           └── Activity[]

Users[]
Notifications[]   (transient, rebuilt from live data)
SavedViews[]
Settings { theme }
```

All entities are linked by string IDs. The state object is the single source of truth — every render function reads from `state.*` and every mutation calls `scheduleSave()` which debounces a `localStorage.setItem` write by 1.8 s.

---

## Getting Started

No build step. No npm install.

```bash
# Clone the repo
git clone https://github.com/zainknoman/TaskTracker.git
cd TaskTracker

# Set up Supabase credentials
cp config.example.js config.js
# Edit config.js and fill in your supabaseUrl and supabaseKey

# Open directly in your browser
open index.html
# — or —
npx serve .        # simple static server
python3 -m http.server 8080
```

> **config.js is gitignored** — never commit it. Copy `config.example.js`, fill in your [Supabase](https://supabase.com) project URL and anon key, then reload the page.

On first load, TaskFlow Pro seeds four demo projects (Core Banking Upgrade, Mobile App Revamp, KYC Digital Onboarding, UAE Tax Portal) with realistic tasks, milestones, and sprints so you can explore every feature immediately.

To start fresh, open **DevTools → Application → Local Storage** and delete the `taskflow_pro_v3` key, then refresh.

---

## Views & Navigation

| Key | View | Description |
|-----|------|-------------|
| `1` | Dashboard | Stats, project overview, upcoming deadlines, team workload |
| `2` | Projects | Grid or list view of all projects |
| `3` | Tasks | Full filterable, sortable task table |
| `4` | Kanban | Drag-and-drop status board |
| `5` | Calendar | Monthly due-date calendar |
| `6` | Gantt | Timeline bar chart |
| `7` | Analytics | Charts, KPIs, and risk indicators |
| `8` | Team | Member cards and workload |

Click any project in the sidebar or on the Projects view to enter the **Project Detail** view, which has its own Overview, Tasks, Kanban, Milestones, and Sprints tabs.

---

## Data Model

### Project
```js
{
  id, name, code, description,
  department, client, pm, baTeam,
  status,    // 'active' | 'planning' | 'onhold' | 'completed' | 'archived'
  priority,  // 'low' | 'medium' | 'high' | 'critical'
  startDate, endDate, budget,
  color, tags, createdAt, updatedAt
}
```

### Task
```js
{
  id, title, description,
  projectId, milestoneId, sprintId, parentTaskId,
  priority, status,
  startDate, dueDate,
  ba, assignee,
  estimatedHours, actualHours, progress,
  tags, documents, dependencies,
  subtasks,   // [{ id, title, done }]
  notes, starred, pinned,
  createdAt, updatedAt,
  activity    // [{ time, desc }]
}
```

### Milestone
```js
{ id, projectId, name, description, dueDate, status, order, createdAt }
```

### Sprint
```js
{ id, projectId, name, goal, startDate, endDate, status, velocity, createdAt }
```

### User
```js
{
  id, name, role, avatar, color, team,
  email: '',        // shown as link on team card
  phone: '',
  avatarUrl: '',    // custom image URL — overrides preset
  avatarPreset: null, // index 0–11 into built-in emoji/icon list
  skills: []        // string[] — displayed as tag chips
}
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl/⌘ + K` | Focus global search |
| `Ctrl/⌘ + P` | Open command palette |
| `Ctrl/⌘ + N` | New task |
| `1` – `8` | Switch views |
| `Escape` | Close any modal or overlay |

---

## Import & Export

### Export
Click the **⋯ menu → Export JSON** to download a full backup, or **Export CSV** for a flat spreadsheet-friendly format.

### Import
Click **Import JSON** and select a previously exported `.json` file. This fully replaces the current state including projects, tasks, milestones, sprints, and users.

### JSON Schema
```json
{
  "projects":   [ /* Project[] */ ],
  "tasks":      [ /* Task[]    */ ],
  "milestones": [ /* Milestone[] */ ],
  "sprints":    [ /* Sprint[]  */ ],
  "users":      [ /* User[]    */ ],
  "exportedAt": "ISO 8601 timestamp"
}
```

---

## Extending the App

The codebase is intentionally monolithic and readable. Key extension points:

**Add a new view:**
1. Add a `<section id="view-myview" class="view">…</section>` in `index.html`
2. Add `myview: renderMyView` to the `renders` map in `switchView()`
3. Add a nav link with `data-view="myview"`

**Add a new field to tasks:**
1. Add the HTML input to the task form in `index.html`
2. Read its value in `saveTask()` and include it in the `data` object
3. Display it in `renderTaskRow()` and `openTaskDetail()`

**Replace localStorage with a backend:**
Swap out `Storage.load()` and `Storage.save()` in `app.js` with `fetch()` calls to your API. The rest of the app is unaffected.

---

## File Structure

```
TaskTracker/
├── index.html                        # Full app shell — all views, modals, and overlays
├── app.js                            # ~2,600 lines — complete application engine
│   ├── Constants & config
│   ├── State management
│   ├── Storage layer (localStorage)
│   ├── Seed data (demo projects & tasks)
│   ├── Utilities
│   ├── Routing & navigation
│   ├── View renderers (Dashboard, Projects, Tasks, Kanban, Calendar, Gantt, Analytics, Team)
│   ├── Project Detail & tabs
│   ├── Task / Project / Milestone / Sprint forms & modals
│   ├── Team member modal (add/edit with avatar grid & skills)
│   ├── Notifications engine
│   ├── Smart productivity check
│   ├── Saved views
│   ├── Sprint burndown chart
│   ├── Deadline health scoring
│   ├── Activity audit log
│   ├── Global search & command palette
│   ├── Import / Export
│   ├── Theme engine
│   ├── Toast notifications
│   ├── Supabase auth (login / sign-out)
│   └── Init & event binding
├── style.css                         # Design system — tokens, layout, components, dark mode
├── config.js                         # Supabase credentials — gitignored, create from example
├── config.example.js                 # Credential template committed to the repo
├── .gitignore                        # Excludes config.js
├── .github/
│   └── workflows/
│       └── deploy.yml                # GitHub Actions: injects secrets → deploys to Pages
└── README.md
```

---

## Authentication

TaskFlow Pro uses [Supabase Auth](https://supabase.com/docs/guides/auth) for email/password login. Supabase is used **only for authentication** — all task and project data continues to live in `localStorage`.

### How it works

| Layer | Responsibility |
|-------|---------------|
| Supabase Auth | User login session, sign-out |
| `localStorage` | All app data (projects, tasks, users, etc.) |
| `config.js` | Holds `supabaseUrl` + `supabaseKey` (gitignored) |

### Login flow
1. App loads → checks for an active Supabase session
2. No session → shows `#loginScreen`
3. User submits email + password → `sb.auth.signInWithPassword()`
4. Success → hides login screen, shows `#app`
5. Sign Out button (sidebar footer) → `sb.auth.signOut()` → returns to login

### Missing config.js
If `config.js` is absent (e.g. fresh clone without setup), the app shows a clear error page directing the user to copy `config.example.js` and fill in their credentials.

---

## Deployment (GitHub Pages)

Because `config.js` is gitignored, the GitHub Actions workflow in `.github/workflows/deploy.yml` generates it from repository secrets at deploy time — credentials are injected into the Pages artifact but never committed to git.

### Setup steps

1. **Add repository secrets** in GitHub → Settings → Secrets and variables → Actions:
   - `SUPABASE_URL` — your Supabase project URL
   - `SUPABASE_KEY` — your Supabase anon key

2. **Set Pages source** in GitHub → Settings → Pages → Source → **GitHub Actions**

3. Push to `main` — the workflow triggers automatically, builds `config.js` from secrets, and deploys the site.

### Secret injection flow

```
Git repo (no config.js)
  → Actions runner reads SUPABASE_URL + SUPABASE_KEY secrets
  → Generates config.js
  → Uploads full site (including config.js) as Pages artifact
  → Deploys to https://zainknoman.github.io/TaskTracker/
```

---

## Browser Support

| Browser | Support |
|---------|---------|
| Chrome 90+ | ✅ Full |
| Firefox 88+ | ✅ Full |
| Safari 14+ | ✅ Full |
| Edge 90+ | ✅ Full |

Requires `localStorage` (available in all modern browsers). No Internet connection needed after initial page load.

---

## Author & Developer
Zain Kamali
