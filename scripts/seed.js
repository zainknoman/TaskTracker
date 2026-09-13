/**
 * Data seeder for TaskFlow Pro — creates real Supabase Auth users, two
 * separate tenant workspaces, and sample projects/tasks/milestones/sprints,
 * so multi-tenant behaviour (workspace isolation, RBAC, invites, realtime,
 * notifications) can be exercised end to end without manual setup.
 *
 * Uses the anon key only (no service_role key required) — this project has
 * `mailer_autoconfirm` enabled, so signUp() returns a usable session
 * immediately. Safe to re-run: each tenant is skipped if a workspace with
 * its slug is already visible to that tenant's owner.
 *
 * Requires migrations 001-005 to already be applied (see migrations/).
 *
 * Usage:
 *   npm install
 *   node scripts/seed.js
 *   # or override credentials explicitly:
 *   SUPABASE_URL=... SUPABASE_ANON_KEY=... node scripts/seed.js
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

const PASSWORD = 'Test1234!';

function loadConfig() {
  if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
    return { url: process.env.SUPABASE_URL, key: process.env.SUPABASE_ANON_KEY };
  }
  const configPath = path.join(__dirname, '..', 'config.js');
  if (!fs.existsSync(configPath)) {
    throw new Error('config.js not found and SUPABASE_URL/SUPABASE_ANON_KEY not set. Copy config.example.js to config.js first.');
  }
  const src = fs.readFileSync(configPath, 'utf8');
  const url = src.match(/supabaseUrl:\s*['"]([^'"]+)['"]/)?.[1];
  const key = src.match(/supabaseKey:\s*['"]([^'"]+)['"]/)?.[1];
  if (!url || !key) throw new Error('Could not parse supabaseUrl/supabaseKey out of config.js');
  return { url, key };
}

const { url: SUPABASE_URL, key: SUPABASE_ANON_KEY } = loadConfig();

function makeClient() {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

// Signs a test user up (or in, if they already exist) and returns a client
// authenticated as that user, plus the user object.
async function ensureUser(email, password, displayName) {
  const client = makeClient();
  const signUp = await client.auth.signUp({ email, password });
  let user = signUp.data?.user;
  if (signUp.error) {
    if (!/registered|exists/i.test(signUp.error.message)) throw signUp.error;
    const signIn = await client.auth.signInWithPassword({ email, password });
    if (signIn.error) throw signIn.error;
    user = signIn.data.user;
  } else if (!signUp.data.session) {
    // Fallback in case autoconfirm is off on some environments.
    const signIn = await client.auth.signInWithPassword({ email, password });
    if (signIn.error) throw new Error(`User ${email} created but needs email confirmation before it can be seeded.`);
    user = signIn.data.user;
  }
  console.log(`  user ready: ${email} (${user.id})`);
  return { client, user, email, displayName };
}

async function ensureWorkspace(owner, name, slug) {
  const { data: existingRows, error: listErr } = await owner.client
    .from('workspace_members')
    .select('workspace_id, workspaces(id, slug, name)')
    .eq('user_id', owner.user.id);
  if (listErr) throw listErr;
  const existing = existingRows?.map(r => r.workspaces).find(w => w?.slug === slug);
  if (existing) {
    console.log(`  workspace "${name}" already seeded (${existing.id}) — skipping tenant`);
    return { workspace: existing, isNew: false };
  }
  const { data: ws, error } = await owner.client
    .from('workspaces')
    .insert({ name, slug, owner_id: owner.user.id })
    .select().single();
  if (error) throw error;
  console.log(`  created workspace "${name}" (${ws.id})`);
  return { workspace: ws, isNew: true };
}

async function addMember(owner, workspaceId, member, role) {
  const { error } = await owner.client.from('workspace_members').insert({
    workspace_id: workspaceId,
    user_id: member.user.id,
    role,
    display_name: member.displayName,
  });
  if (error) throw error;
  console.log(`  added ${member.email} as ${role}`);
}

async function seedProject(owner, workspaceId, project) {
  const { data: p, error } = await owner.client.from('tt_projects').insert({
    workspace_id: workspaceId,
    name: project.name,
    code: project.code,
    description: project.description,
    department: project.department,
    status: project.status,
    priority: project.priority,
    color: project.color,
    tags: project.tags,
    created_by: owner.user.id,
  }).select().single();
  if (error) throw error;

  const { data: milestone } = await owner.client.from('milestones').insert({
    workspace_id: workspaceId, project_id: p.id,
    name: `${project.name} — Kickoff Milestone`,
    due_date: project.milestoneDue, status: 'pending',
  }).select().single();

  const { data: sprint } = await owner.client.from('sprints').insert({
    workspace_id: workspaceId, project_id: p.id,
    name: 'Sprint 1', goal: 'Initial delivery',
    start_date: project.sprintStart, end_date: project.sprintEnd,
    status: 'active', velocity: 0,
  }).select().single();

  for (const t of project.tasks) {
    const { error: tErr } = await owner.client.from('tasks').insert({
      workspace_id: workspaceId,
      project_id: p.id,
      milestone_id: milestone?.id ?? null,
      sprint_id: sprint?.id ?? null,
      title: t.title,
      description: t.description ?? null,
      priority: t.priority ?? 'medium',
      status: t.status ?? 'pending',
      due_date: t.dueDate ?? null,
      assignee_id: t.assignee?.user.id ?? null,
      ba: t.assignee?.displayName ?? null,
      progress: t.progress ?? 0,
      created_by: owner.user.id,
    });
    if (tErr) throw tErr;
  }
  console.log(`  seeded project "${project.name}" with ${project.tasks.length} tasks`);
}

async function main() {
  console.log(`Seeding against ${SUPABASE_URL}\n`);

  console.log('Creating users...');
  const alice = await ensureUser('alice.owner@tasktracker.test', PASSWORD, 'Alice (Owner)');
  const bob   = await ensureUser('bob.member@tasktracker.test', PASSWORD, 'Bob (Member)');
  const carol = await ensureUser('carol.guest@tasktracker.test', PASSWORD, 'Carol (Guest)');
  const dave  = await ensureUser('dave.owner@tasktracker.test', PASSWORD, 'Dave (Owner)');
  const erin  = await ensureUser('erin.member@tasktracker.test', PASSWORD, 'Erin (Member)');

  console.log('\nTenant 1 — Acme Corporation');
  const acme = await ensureWorkspace(alice, 'Acme Corporation', 'acme-corp-demo');
  if (acme.isNew) {
    await addMember(alice, acme.workspace.id, bob, 'member');
    await addMember(alice, acme.workspace.id, carol, 'guest');
    await seedProject(alice, acme.workspace.id, {
      name: 'Core Banking Upgrade', code: 'ACM-CBU', department: 'Engineering',
      status: 'active', priority: 'critical', color: '#2563eb', tags: ['banking', 'backend'],
      milestoneDue: '2026-11-01', sprintStart: '2026-09-01', sprintEnd: '2026-09-14',
      tasks: [
        { title: 'Design new ledger schema', priority: 'critical', status: 'inprogress', assignee: bob, progress: 40, dueDate: '2026-09-20' },
        { title: 'Migrate legacy accounts', priority: 'high', status: 'pending', assignee: bob, progress: 0, dueDate: '2026-10-01' },
        { title: 'Review compliance checklist', priority: 'medium', status: 'pending', assignee: carol, progress: 0, dueDate: '2026-09-25' },
      ],
    });
    await seedProject(alice, acme.workspace.id, {
      name: 'Mobile App Revamp', code: 'ACM-MAR', department: 'Product',
      status: 'planning', priority: 'medium', color: '#16a34a', tags: ['mobile'],
      milestoneDue: '2026-12-01', sprintStart: '2026-09-08', sprintEnd: '2026-09-21',
      tasks: [
        { title: 'Wireframe onboarding flow', priority: 'medium', status: 'completed', assignee: alice, progress: 100, dueDate: '2026-09-10' },
        { title: 'Set up CI for mobile build', priority: 'low', status: 'blocked', assignee: bob, progress: 10, dueDate: '2026-09-30' },
      ],
    });
  }

  console.log('\nTenant 2 — Globex Industries');
  const globex = await ensureWorkspace(dave, 'Globex Industries', 'globex-industries-demo');
  if (globex.isNew) {
    await addMember(dave, globex.workspace.id, erin, 'member');
    // bob also belongs to Acme — added here too, to exercise the workspace switcher
    // and confirm workspace isolation (bob must never see Globex data cross-loaded).
    await addMember(dave, globex.workspace.id, bob, 'member');
    await seedProject(dave, globex.workspace.id, {
      name: 'KYC Digital Onboarding', code: 'GLX-KYC', department: 'Compliance',
      status: 'active', priority: 'high', color: '#dc2626', tags: ['kyc', 'compliance'],
      milestoneDue: '2026-10-15', sprintStart: '2026-09-01', sprintEnd: '2026-09-14',
      tasks: [
        { title: 'Integrate ID verification API', priority: 'high', status: 'inprogress', assignee: erin, progress: 55, dueDate: '2026-09-18' },
        { title: 'Draft data retention policy', priority: 'medium', status: 'pending', assignee: dave, progress: 0, dueDate: '2026-09-28' },
      ],
    });
  }

  console.log('\nDone. Test accounts (password for all: ' + PASSWORD + '):');
  console.table([
    { email: 'alice.owner@tasktracker.test', workspace: 'Acme Corporation', role: 'owner' },
    { email: 'bob.member@tasktracker.test', workspace: 'Acme Corporation + Globex Industries', role: 'member (both)' },
    { email: 'carol.guest@tasktracker.test', workspace: 'Acme Corporation', role: 'guest' },
    { email: 'dave.owner@tasktracker.test', workspace: 'Globex Industries', role: 'owner' },
    { email: 'erin.member@tasktracker.test', workspace: 'Globex Industries', role: 'member' },
  ]);
}

main().catch(err => {
  console.error('\nSeed failed:', err.message || err);
  process.exit(1);
});
