-- Run in Supabase SQL editor for project: zynunureylcdexxhvdth

CREATE TABLE workspaces (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text UNIQUE NOT NULL,
  owner_id    uuid NOT NULL REFERENCES auth.users(id),
  plan_type   text DEFAULT 'free',
  settings    jsonb DEFAULT '{}',
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

CREATE TABLE workspace_members (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role          text NOT NULL CHECK (role IN ('owner','member','guest')) DEFAULT 'member',
  display_name  text,
  avatar_url    text,
  avatar_preset int,
  color         text,
  skills        text[],
  joined_at     timestamptz DEFAULT now(),
  UNIQUE (workspace_id, user_id)
);

CREATE TABLE invitations (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  invited_by    uuid NOT NULL REFERENCES auth.users(id),
  token         text UNIQUE NOT NULL,
  role          text NOT NULL CHECK (role IN ('member','guest')) DEFAULT 'member',
  label         text,
  status        text NOT NULL CHECK (status IN ('pending','accepted','cancelled')) DEFAULT 'pending',
  accepted_by   uuid REFERENCES auth.users(id),
  expires_at    timestamptz NOT NULL,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE notifications (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type          text NOT NULL,
  title         text NOT NULL,
  body          text,
  entity_type   text,
  entity_id     uuid,
  read          boolean DEFAULT false,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE projects (
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

CREATE TABLE milestones (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  due_date      date,
  status        text DEFAULT 'pending' CHECK (status IN ('pending','completed')),
  sort_order    int DEFAULT 0,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE sprints (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  project_id    uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  name          text NOT NULL,
  goal          text,
  start_date    date,
  end_date      date,
  status        text DEFAULT 'planning' CHECK (status IN ('planning','active','completed')),
  velocity      int,
  created_at    timestamptz DEFAULT now()
);

CREATE TABLE tasks (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id     uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  project_id       uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  milestone_id     uuid REFERENCES milestones(id) ON DELETE SET NULL,
  sprint_id        uuid REFERENCES sprints(id) ON DELETE SET NULL,
  parent_task_id   uuid REFERENCES tasks(id) ON DELETE SET NULL,
  title            text NOT NULL,
  description      text,
  priority         text DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  status           text DEFAULT 'pending' CHECK (status IN ('pending','inprogress','completed','blocked')),
  start_date       date,
  due_date         date,
  ba               text,
  assignee_id      uuid REFERENCES auth.users(id),
  estimated_hours  numeric,
  actual_hours     numeric,
  progress         int DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  tags             text[],
  documents        jsonb DEFAULT '[]',
  dependencies     uuid[],
  subtasks         jsonb DEFAULT '[]',
  notes            text,
  starred          boolean DEFAULT false,
  pinned           boolean DEFAULT false,
  created_by       uuid NOT NULL REFERENCES auth.users(id),
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

CREATE TABLE task_comments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  task_id       uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  author_id     uuid NOT NULL REFERENCES auth.users(id),
  content       text NOT NULL,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

CREATE TABLE task_activity (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  uuid NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  task_id       uuid NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  actor_id      uuid NOT NULL REFERENCES auth.users(id),
  action        text NOT NULL,
  old_value     text,
  new_value     text,
  description   text,
  created_at    timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX ON workspace_members (workspace_id, user_id);
CREATE INDEX ON workspace_members (user_id);
CREATE INDEX ON projects (workspace_id);
CREATE INDEX ON milestones (project_id);
CREATE INDEX ON sprints (project_id);
CREATE INDEX ON tasks (workspace_id, project_id);
CREATE INDEX ON tasks (assignee_id);
CREATE INDEX ON tasks (status, due_date);
CREATE INDEX ON task_comments (task_id);
CREATE INDEX ON task_activity (task_id, created_at DESC);
CREATE INDEX ON notifications (user_id, read);
CREATE INDEX ON invitations (token);
