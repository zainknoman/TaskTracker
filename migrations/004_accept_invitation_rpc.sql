-- Run in Supabase SQL editor: https://supabase.com/dashboard/project/zynunureylcdexxhvdth/sql/new
-- Accepts an invitation server-side as SECURITY DEFINER, bypassing RLS edge cases.

CREATE OR REPLACE FUNCTION accept_invitation(p_token text, p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_inv    RECORD;
  v_exists uuid;
  v_ws_name text;
BEGIN
  SELECT * INTO v_inv FROM public.invitations WHERE token = p_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invite link not found';
  END IF;
  IF v_inv.status <> 'pending' THEN
    RAISE EXCEPTION 'This invite link has already been used or cancelled';
  END IF;
  IF v_inv.expires_at < NOW() THEN
    RAISE EXCEPTION 'This invite link has expired';
  END IF;

  SELECT name INTO v_ws_name FROM public.workspaces WHERE id = v_inv.workspace_id;

  -- Already a member? Just mark accepted and return.
  SELECT id INTO v_exists FROM public.workspace_members
  WHERE workspace_id = v_inv.workspace_id AND user_id = p_user_id;

  IF FOUND THEN
    UPDATE public.invitations
    SET status = 'accepted', accepted_by = p_user_id
    WHERE id = v_inv.id;
    RETURN jsonb_build_object(
      'workspace_id',   v_inv.workspace_id,
      'workspace_name', v_ws_name
    );
  END IF;

  -- Add to workspace
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (v_inv.workspace_id, p_user_id, v_inv.role);

  -- Mark accepted
  UPDATE public.invitations
  SET status = 'accepted', accepted_by = p_user_id
  WHERE id = v_inv.id;

  RETURN jsonb_build_object(
    'workspace_id',   v_inv.workspace_id,
    'workspace_name', v_ws_name
  );
END;
$$;
