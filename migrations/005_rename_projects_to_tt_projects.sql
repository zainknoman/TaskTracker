-- Fixes a table-name collision discovered in project zynunureylcdexxhvdth.
--
-- This Supabase project is shared with an unrelated app (a portfolio/showcase
-- site) that already owns a table called `projects` (columns: title, emoji,
-- category, location, year, thumbnail, published — no workspace_id). When
-- migration 001_schema.sql ran, `CREATE TABLE projects (...)` silently
-- collided with that pre-existing table, so TaskTracker's own projects table
-- was never created. `tasks.project_id`, `milestones.project_id`, and
-- `sprints.project_id` may have attached their foreign keys to the WRONG
-- (portfolio) table.
--
-- Fix: create TaskTracker's project table under a distinct name, `tt_projects`,
-- re-point the foreign keys at it, and add matching RLS policies. The other
-- app's `projects` table is never touched.
--
-- Run in Supabase SQL editor: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/sql/new

CREATE TABLE IF NOT EXISTS tt_projects (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name          text NOT NULL,
  code          text,
  description   text,
  department    text,
  client        text,
  pm            text,
  ba_team       text[],
  status        text DEFAULT 'active' CHECK (status IN ('active','planning','onhold','completed','archived')),
  priority      text DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  start_date    date,
  end_date      date,
  budget        numeric,
  color         text,
  tags          text[],
  created_by    uuid NOT NULL REFERENCES auth.users(id),
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS tt_projects_workspace_id_idx ON tt_projects (workspace_id);

-- Re-point FKs that referenced the colliding `projects` table.
-- Default Postgres constraint names; IF EXISTS makes this safe to re-run
-- regardless of whether the original FK ever successfully attached.
--
-- Added as NOT VALID: this project already has live rows in milestones/
-- sprints/tasks whose project_id was checked against the WRONG (portfolio)
-- projects table and does not exist in the new, empty tt_projects table.
-- NOT VALID skips checking existing rows so the migration doesn't get
-- blocked on that pre-existing data; the constraint still applies to all
-- new inserts/updates from this point on. Run the report query at the
-- bottom of this file afterward to see exactly which rows are orphaned,
-- then decide how to fix them (see comment there) before VALIDATE CONSTRAINT.
ALTER TABLE milestones DROP CONSTRAINT IF EXISTS milestones_project_id_fkey;
ALTER TABLE milestones ADD CONSTRAINT milestones_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES tt_projects(id) ON DELETE CASCADE NOT VALID;

ALTER TABLE sprints DROP CONSTRAINT IF EXISTS sprints_project_id_fkey;
ALTER TABLE sprints ADD CONSTRAINT sprints_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES tt_projects(id) ON DELETE CASCADE NOT VALID;

ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_project_id_fkey;
ALTER TABLE tasks ADD CONSTRAINT tasks_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES tt_projects(id) ON DELETE CASCADE NOT VALID;

-- RLS (mirrors 002_rls_policies.sql's original intent for `projects`)
ALTER TABLE tt_projects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members view projects" ON tt_projects;
CREATE POLICY "members view projects" ON tt_projects FOR SELECT USING (is_workspace_member(workspace_id));

DROP POLICY IF EXISTS "non-guests create projects" ON tt_projects;
CREATE POLICY "non-guests create projects" ON tt_projects FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));

DROP POLICY IF EXISTS "non-guests update projects" ON tt_projects;
CREATE POLICY "non-guests update projects" ON tt_projects FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));

DROP POLICY IF EXISTS "owner or creator delete" ON tt_projects;
CREATE POLICY "owner or creator delete" ON tt_projects FOR DELETE USING (get_my_workspace_role(workspace_id) = 'owner' OR created_by = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- Report: rows left dangling by the NOT VALID constraints above (their
-- project_id was only ever valid against the old, wrong `projects` table).
-- Run this next and inspect the output.
select 'tasks' as table_name, id, project_id, title as label, workspace_id, created_at from tasks
where project_id not in (select id from tt_projects)
union all
select 'milestones', id, project_id, name, workspace_id, created_at from milestones
where project_id not in (select id from tt_projects)
union all
select 'sprints', id, project_id, name, workspace_id, created_at from sprints
where project_id not in (select id from tt_projects)
order by table_name, created_at;

-- Once you've decided what to do with those rows (see options below), and
-- the SELECT above returns zero rows for a table, you can tighten the FK
-- back to a fully-checked constraint with:
--   ALTER TABLE tasks VALIDATE CONSTRAINT tasks_project_id_fkey;
--   ALTER TABLE milestones VALIDATE CONSTRAINT milestones_project_id_fkey;
--   ALTER TABLE sprints VALIDATE CONSTRAINT sprints_project_id_fkey;
--
-- Options for orphaned rows, once you know what they are from the report:
--   A) They're real, worth keeping — for each distinct orphaned project_id,
--      insert a matching tt_projects row reusing that same id so the
--      existing rows become valid again, e.g.:
--        INSERT INTO tt_projects (id, workspace_id, name, created_by)
--        VALUES ('a198df0d-3bfe-47b2-b4fc-710af44fe56e', '<real workspace_id>', 'Recovered Project', '<real user_id>');
--   B) They're test/junk data — just delete them:
--        DELETE FROM tasks WHERE project_id NOT IN (SELECT id FROM tt_projects);
--        DELETE FROM milestones WHERE project_id NOT IN (SELECT id FROM tt_projects);
--        DELETE FROM sprints WHERE project_id NOT IN (SELECT id FROM tt_projects);
