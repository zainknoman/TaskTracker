-- Enable RLS on all tables
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE sprints ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_activity ENABLE ROW LEVEL SECURITY;

-- Helper functions
CREATE OR REPLACE FUNCTION is_workspace_member(_workspace_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = _workspace_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION get_my_workspace_role(_workspace_id uuid)
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM workspace_members
  WHERE workspace_id = _workspace_id AND user_id = auth.uid()
  LIMIT 1;
$$;

-- workspaces
CREATE POLICY "members view" ON workspaces FOR SELECT USING (is_workspace_member(id));
CREATE POLICY "auth create" ON workspaces FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND owner_id = auth.uid());
CREATE POLICY "owner update" ON workspaces FOR UPDATE USING (owner_id = auth.uid());
CREATE POLICY "owner delete" ON workspaces FOR DELETE USING (owner_id = auth.uid());

-- workspace_members
CREATE POLICY "members view members" ON workspace_members FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "owner add members" ON workspace_members FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) = 'owner');
CREATE POLICY "owner update roles" ON workspace_members FOR UPDATE USING (get_my_workspace_role(workspace_id) = 'owner');
CREATE POLICY "owner remove or self-leave" ON workspace_members FOR DELETE USING (
  get_my_workspace_role(workspace_id) = 'owner' OR user_id = auth.uid()
);

-- invitations (SELECT open — token is the credential)
CREATE POLICY "anyone read invitations" ON invitations FOR SELECT USING (true);
CREATE POLICY "members create invitations" ON invitations FOR INSERT WITH CHECK (is_workspace_member(workspace_id));
CREATE POLICY "accepting user update" ON invitations FOR UPDATE USING (status = 'pending');
CREATE POLICY "owner cancel" ON invitations FOR DELETE USING (get_my_workspace_role(workspace_id) = 'owner');

-- projects
CREATE POLICY "members view projects" ON projects FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create projects" ON projects FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update projects" ON projects FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "owner or creator delete" ON projects FOR DELETE USING (get_my_workspace_role(workspace_id) = 'owner' OR created_by = auth.uid());

-- milestones
CREATE POLICY "members view milestones" ON milestones FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create milestones" ON milestones FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update milestones" ON milestones FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests delete milestones" ON milestones FOR DELETE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));

-- sprints
CREATE POLICY "members view sprints" ON sprints FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create sprints" ON sprints FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update sprints" ON sprints FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests delete sprints" ON sprints FOR DELETE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));

-- tasks
CREATE POLICY "members view tasks" ON tasks FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create tasks" ON tasks FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "non-guests update tasks" ON tasks FOR UPDATE USING (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "owner or creator delete tasks" ON tasks FOR DELETE USING (get_my_workspace_role(workspace_id) = 'owner' OR created_by = auth.uid());

-- task_comments
CREATE POLICY "members view comments" ON task_comments FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests create comments" ON task_comments FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));
CREATE POLICY "author update comment" ON task_comments FOR UPDATE USING (author_id = auth.uid());
CREATE POLICY "author or owner delete comment" ON task_comments FOR DELETE USING (author_id = auth.uid() OR get_my_workspace_role(workspace_id) = 'owner');

-- task_activity (append-only: no UPDATE or DELETE policies)
CREATE POLICY "members view activity" ON task_activity FOR SELECT USING (is_workspace_member(workspace_id));
CREATE POLICY "non-guests log activity" ON task_activity FOR INSERT WITH CHECK (get_my_workspace_role(workspace_id) IN ('owner','member'));

-- notifications (INSERT via DB trigger only)
CREATE POLICY "own notifications" ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "mark read" ON notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "delete own" ON notifications FOR DELETE USING (user_id = auth.uid());
