CREATE OR REPLACE FUNCTION notify_task_changes()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Notify new assignee when assignee_id changes
  IF NEW.assignee_id IS DISTINCT FROM OLD.assignee_id AND NEW.assignee_id IS NOT NULL THEN
    INSERT INTO notifications (workspace_id, user_id, type, title, body, entity_type, entity_id)
    VALUES (
      NEW.workspace_id,
      NEW.assignee_id,
      'task_assigned',
      'You were assigned a task',
      NEW.title,
      'task',
      NEW.id
    );
  END IF;

  -- Notify task creator when status changes (if creator is not the person making the change)
  IF NEW.status IS DISTINCT FROM OLD.status
     AND NEW.created_by IS NOT NULL
     AND NEW.created_by <> auth.uid() THEN
    INSERT INTO notifications (workspace_id, user_id, type, title, body, entity_type, entity_id)
    VALUES (
      NEW.workspace_id,
      NEW.created_by,
      'status_changed',
      'Task status updated',
      NEW.title || ': ' || OLD.status || ' → ' || NEW.status,
      'task',
      NEW.id
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER task_change_notifications
  AFTER UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION notify_task_changes();