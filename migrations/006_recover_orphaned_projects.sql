-- Recovers the 12 pre-existing tasks orphaned by the projects/tt_projects
-- collision fixed in 005_rename_projects_to_tt_projects.sql.
--
-- Those tasks were created around 2026-05-16 (early dev/testing of the
-- workspace features) referencing "projects" that, due to the table
-- collision, were never actually saved as real rows anywhere. This creates
-- 4 placeholder tt_projects rows reusing the EXACT SAME ids the orphaned
-- tasks already point to, so the existing FK becomes satisfiable again with
-- no task data lost. Rename/edit these in the UI afterward as needed.
--
-- Run in Supabase SQL editor: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/sql/new
-- Run AFTER 005_rename_projects_to_tt_projects.sql.

INSERT INTO tt_projects (id, workspace_id, name, status, priority, created_by)
VALUES
  ('71687464-cacb-48b5-abf1-78f19b0f0a05', '8f15d807-774a-425d-afda-390f322e40cd', 'CBS (Recovered)',
   'active', 'medium', (SELECT owner_id FROM workspaces WHERE id = '8f15d807-774a-425d-afda-390f322e40cd')),
  ('a198df0d-3bfe-47b2-b4fc-710af44fe56e', '8f15d807-774a-425d-afda-390f322e40cd', 'MAPP (Recovered)',
   'active', 'medium', (SELECT owner_id FROM workspaces WHERE id = '8f15d807-774a-425d-afda-390f322e40cd')),
  ('ba7056b9-890f-4a56-8029-254a2a158124', 'd28fd283-03f5-49dd-8089-27de9c967171', 'Project A (Recovered)',
   'active', 'medium', (SELECT owner_id FROM workspaces WHERE id = 'd28fd283-03f5-49dd-8089-27de9c967171')),
  ('e6ca2352-d88d-4160-8098-4588ff837aec', 'd28fd283-03f5-49dd-8089-27de9c967171', 'Project B (Recovered)',
   'active', 'medium', (SELECT owner_id FROM workspaces WHERE id = 'd28fd283-03f5-49dd-8089-27de9c967171'))
ON CONFLICT (id) DO NOTHING;

-- Sanity check: should return zero rows now.
select 'tasks' as table_name, id, project_id, title as label from tasks
where project_id not in (select id from tt_projects)
union all
select 'milestones', id, project_id, name from milestones
where project_id not in (select id from tt_projects)
union all
select 'sprints', id, project_id, name from sprints
where project_id not in (select id from tt_projects);

-- Now that no orphans remain, fully validate the constraints (fast — no
-- table rewrite, just an existing-row check now that every row satisfies it).
ALTER TABLE tasks VALIDATE CONSTRAINT tasks_project_id_fkey;
ALTER TABLE milestones VALIDATE CONSTRAINT milestones_project_id_fkey;
ALTER TABLE sprints VALIDATE CONSTRAINT sprints_project_id_fkey;
