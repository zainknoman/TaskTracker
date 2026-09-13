-- Fix bootstrap problems introduced by 002_rls_policies.sql
-- Run in Supabase SQL editor: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/sql/new

-- Problem 1: workspaces SELECT policy requires is_workspace_member(id), but after
-- a fresh INSERT the user hasn't been added to workspace_members yet. PostgREST
-- returns 403 for the entire insert().select() call even though the INSERT succeeded.
-- Fix: also allow the workspace owner to see their own workspace.
DROP POLICY IF EXISTS "members view" ON workspaces;
CREATE POLICY "members view" ON workspaces FOR SELECT USING (
  is_workspace_member(id) OR owner_id = auth.uid()
);

-- Problem 2: workspace_members INSERT policy requires get_my_workspace_role = 'owner',
-- but the user cannot be in workspace_members before inserting the first row.
-- Fix: also allow the workspace owner (via workspaces.owner_id) to insert members,
-- and allow any user to add themselves (needed for invite acceptance).
DROP POLICY IF EXISTS "owner add members" ON workspace_members;
CREATE POLICY "owner add members" ON workspace_members FOR INSERT WITH CHECK (
  get_my_workspace_role(workspace_id) = 'owner'
  OR (SELECT owner_id FROM workspaces WHERE id = workspace_id) = auth.uid()
  OR user_id = auth.uid()
);
