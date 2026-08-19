-- ============================================================================
-- FULL CHAT FEATURE — MineLink
-- Extends the existing chat_rooms / chat_messages schema with:
--   * org-to-org connection registry (super-admin grant/revoke)
--   * room type + company scoping + created_by
--   * message mentions + delivered/read receipts
--   * per-recipient read receipts (chat_message_reads) for group rooms
--   * chat_directory view + get_chat_contacts() RPC (company-scoped contacts)
--   * send-guard blocking new messages on revoked org connections (history kept)
-- Identity: auth.uid() == profiles.id. participant_ids[] are auth uids.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helper functions
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_is_super_admin(p_uid uuid)
  RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_uid AND platform_role LIKE 'superGlobalSerialAdmin%'
  );
$$;

CREATE OR REPLACE FUNCTION public.chat_user_company_id(p_uid uuid)
  RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT id FROM public.companies WHERE user_id = p_uid LIMIT 1),
    (SELECT company_id FROM public.employees WHERE user_id = p_uid AND company_id IS NOT NULL LIMIT 1)
  );
$$;

-- ---------------------------------------------------------------------------
-- org_connections — undirected org-to-org registry (ordered pair)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.org_connections (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_low_id  uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  company_high_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  status          text NOT NULL DEFAULT 'granted' CHECK (status IN ('granted','revoked')),
  granted_by      uuid,
  granted_at      timestamptz DEFAULT now(),
  revoked_by      uuid,
  revoked_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT org_connections_pair_unique UNIQUE (company_low_id, company_high_id),
  CONSTRAINT org_connections_ordered CHECK (company_low_id < company_high_id)
);
CREATE INDEX IF NOT EXISTS idx_org_connections_low  ON public.org_connections (company_low_id);
CREATE INDEX IF NOT EXISTS idx_org_connections_high ON public.org_connections (company_high_id);

ALTER TABLE public.org_connections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS org_connections_admin_all ON public.org_connections;
CREATE POLICY org_connections_admin_all ON public.org_connections
  FOR ALL TO authenticated
  USING (public.chat_is_super_admin((SELECT auth.uid())))
  WITH CHECK (public.chat_is_super_admin((SELECT auth.uid())));

DROP POLICY IF EXISTS org_connections_member_read ON public.org_connections;
CREATE POLICY org_connections_member_read ON public.org_connections
  FOR SELECT TO authenticated
  USING (
    public.chat_user_company_id((SELECT auth.uid())) IN (company_low_id, company_high_id)
  );

-- ---------------------------------------------------------------------------
-- Extend chat_rooms
-- ---------------------------------------------------------------------------
ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS type         text NOT NULL DEFAULT 'dm',
  ADD COLUMN IF NOT EXISTS company_a_id uuid,
  ADD COLUMN IF NOT EXISTS company_b_id uuid,
  ADD COLUMN IF NOT EXISTS created_by   uuid;
ALTER TABLE public.chat_rooms DROP CONSTRAINT IF EXISTS chat_rooms_type_check;
ALTER TABLE public.chat_rooms ADD CONSTRAINT chat_rooms_type_check
  CHECK (type IN ('dm','group','org_group'));

-- ---------------------------------------------------------------------------
-- Extend chat_messages
-- ---------------------------------------------------------------------------
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS mentions     jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS read_at      timestamptz;
CREATE INDEX IF NOT EXISTS idx_chat_messages_mentions ON public.chat_messages USING gin (mentions) WHERE (mentions <> '[]'::jsonb);

-- ---------------------------------------------------------------------------
-- chat_message_reads — per-recipient delivered/read receipts (group rooms)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_message_reads (
  message_id   uuid NOT NULL REFERENCES public.chat_messages(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL,
  delivered_at timestamptz DEFAULT now(),
  read_at      timestamptz,
  PRIMARY KEY (message_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_chat_message_reads_user ON public.chat_message_reads (user_id);

ALTER TABLE public.chat_message_reads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS chat_message_reads_participant ON public.chat_message_reads;
CREATE POLICY chat_message_reads_participant ON public.chat_message_reads
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_messages m
      JOIN public.chat_rooms r ON r.id = m.chat_room_id
      WHERE m.id = chat_message_reads.message_id
        AND (SELECT auth.uid()) = ANY (r.participant_ids)
    )
  )
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- chat_directory — every chattable auth user with their company + role
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.chat_directory
  WITH (security_invoker = false) AS
  -- company owners
  SELECT c.user_id AS user_id,
         COALESCE(p.display_name,
                  NULLIF(TRIM(COALESCE(c.ceo_first_name,'') || ' ' || COALESCE(c.ceo_last_name,'')), ''),
                  c.company_name) AS display_name,
         c.logo_url AS avatar_url,
         c.id AS company_id, c.company_name, c.org_type,
         false AS is_super_admin
  FROM public.companies c
  JOIN public.profiles p ON p.id = c.user_id
  UNION
  -- employees
  SELECT e.user_id,
         TRIM(e.first_name || ' ' || e.last_name),
         e.profile_photo_url,
         e.company_id, c.company_name, c.org_type,
         false
  FROM public.employees e
  JOIN public.companies c ON c.id = e.company_id
  JOIN public.profiles p ON p.id = e.user_id
  WHERE e.company_id IS NOT NULL AND COALESCE(e.is_dismissed, false) = false
  UNION
  -- super admins
  SELECT p.id,
         COALESCE(p.display_name, split_part(p.email, '@', 1)),
         NULL, NULL, NULL, NULL, true
  FROM public.profiles p
  WHERE p.platform_role LIKE 'superGlobalSerialAdmin%';

-- ---------------------------------------------------------------------------
-- get_chat_contacts(p_user_id) — company-scoped, grouped contact list
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_chat_contacts(p_user_id uuid)
  RETURNS TABLE(
    user_id uuid, display_name text, avatar_url text,
    company_id uuid, company_name text, org_type text,
    is_super_admin boolean, group_kind text, group_label text, is_blocked boolean
  )
  LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_is_admin boolean := public.chat_is_super_admin(p_user_id);
  v_company  uuid    := public.chat_user_company_id(p_user_id);
BEGIN
  IF v_is_admin THEN
    RETURN QUERY
      SELECT d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false
      FROM public.chat_directory d
      WHERE d.is_super_admin AND d.user_id <> p_user_id
      UNION ALL
      SELECT d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'organization'::text, ('ORGANIZATION · ' || d.company_name), false
      FROM public.chat_directory d
      WHERE NOT d.is_super_admin AND d.company_id IS NOT NULL AND d.user_id <> p_user_id;
    RETURN;
  END IF;

  -- MY COMPANY
  RETURN QUERY
    SELECT d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'my_company'::text, 'MY COMPANY'::text, false
    FROM public.chat_directory d
    WHERE d.company_id = v_company AND d.user_id <> p_user_id AND NOT d.is_super_admin;

  -- MINE-LINK (super admins)
  RETURN QUERY
    SELECT d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false
    FROM public.chat_directory d
    WHERE d.is_super_admin;

  -- CONNECTED · {Company} (revoked -> is_blocked, history kept)
  RETURN QUERY
    SELECT d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'connected'::text, ('CONNECTED · ' || d.company_name),
           (oc.status = 'revoked')
    FROM public.org_connections oc
    JOIN public.chat_directory d
      ON d.company_id = CASE WHEN oc.company_low_id = v_company THEN oc.company_high_id ELSE oc.company_low_id END
    WHERE (oc.company_low_id = v_company OR oc.company_high_id = v_company)
      AND d.user_id <> p_user_id AND NOT d.is_super_admin;
END $$;

GRANT EXECUTE ON FUNCTION public.get_chat_contacts(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- Send-guard: block new messages when an org_group's connection is revoked
-- (history preserved; only new inserts blocked). DM cross-company block is
-- additionally enforced app-side via is_blocked from get_chat_contacts.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.chat_block_revoked_send()
  RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r public.chat_rooms%ROWTYPE;
  v_low uuid; v_high uuid; v_status text;
BEGIN
  SELECT * INTO r FROM public.chat_rooms WHERE id = NEW.chat_room_id;
  IF r.type = 'org_group' AND r.company_a_id IS NOT NULL AND r.company_b_id IS NOT NULL THEN
    v_low  := LEAST(r.company_a_id, r.company_b_id);
    v_high := GREATEST(r.company_a_id, r.company_b_id);
    SELECT status INTO v_status FROM public.org_connections
      WHERE company_low_id = v_low AND company_high_id = v_high;
    IF v_status = 'revoked' THEN
      RAISE EXCEPTION 'ORG_CONNECTION_REVOKED: messaging is blocked between these organizations';
    END IF;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_chat_block_revoked_send ON public.chat_messages;
CREATE TRIGGER trg_chat_block_revoked_send
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.chat_block_revoked_send();

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
ALTER TABLE public.org_connections   REPLICA IDENTITY FULL;
ALTER TABLE public.chat_message_reads REPLICA IDENTITY FULL;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.org_connections;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_message_reads;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
