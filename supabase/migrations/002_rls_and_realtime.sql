-- =============================================================================
-- Synq App: Row Level Security + Realtime Publication
-- =============================================================================
-- This migration:
--   1. Enables RLS on all public tables
--   2. Creates policies so users can only access their own data
--   3. Enables Realtime publication for notes and folders
--
-- IMPORTANT: Run this AFTER 001_core_tables.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enable Row Level Security
-- ---------------------------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.folders  ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 2. RLS Policies: Profiles
-- ---------------------------------------------------------------------------
-- Users can read and update only their own profile.
-- Insert is handled by the on_auth_user_created trigger.

CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- Allow the trigger to insert (runs as SECURITY DEFINER)
CREATE POLICY "Service role can insert profiles"
  ON public.profiles
  FOR INSERT
  WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 3. RLS Policies: Notes
-- ---------------------------------------------------------------------------
-- Users can only CRUD their own notes.

CREATE POLICY "Users can view own notes"
  ON public.notes
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own notes"
  ON public.notes
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own notes"
  ON public.notes
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notes"
  ON public.notes
  FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 4. RLS Policies: Folders
-- ---------------------------------------------------------------------------
-- Users can only CRUD their own folders.

CREATE POLICY "Users can view own folders"
  ON public.folders
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own folders"
  ON public.folders
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own folders"
  ON public.folders
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own folders"
  ON public.folders
  FOR DELETE
  USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 5. Enable Supabase Realtime
-- ---------------------------------------------------------------------------
-- Add notes and folders to the Realtime publication so that
-- postgres_changes events are broadcast to subscribed clients.
--
-- NOTE: This requires the `supabase_realtime` publication to exist.
-- It is created automatically by Supabase. If running locally,
-- you may need to create it first:
--   CREATE PUBLICATION supabase_realtime;

-- Enable replica identity FULL for detailed change payloads
ALTER TABLE public.notes   REPLICA IDENTITY FULL;
ALTER TABLE public.folders REPLICA IDENTITY FULL;

-- Add tables to the publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.notes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.folders;

-- ---------------------------------------------------------------------------
-- 6. Optional: Field-level merge function (server-side)
-- ---------------------------------------------------------------------------
-- This function can be called via RPC to perform server-side field merging.
-- Useful for batch operations or when the client sends partial updates.
--
-- Usage from Dart:
--   await supabase.rpc('merge_note_fields', params: {
--     'p_note_id': noteId,
--     'p_user_id': userId,
--     'p_fields': {'title': {'value': 'New Title', 'hlc': '123:0:device1'}},
--   });

CREATE OR REPLACE FUNCTION public.merge_note_fields(
  p_note_id TEXT,
  p_user_id UUID,
  p_fields  JSONB  -- {"fieldName": {"value": <any>, "hlc": "hlc_string"}}
) RETURNS JSONB AS $$
DECLARE
  existing       RECORD;
  merged_versions JSONB;
  field_key      TEXT;
  incoming_hlc   TEXT;
  existing_hlc   TEXT;
  accepted_fields TEXT[] := '{}';
BEGIN
  -- Fetch existing note
  SELECT * INTO existing
  FROM public.notes
  WHERE id = p_note_id AND user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'not_found');
  END IF;

  merged_versions := COALESCE(existing.field_versions, '{}'::JSONB);

  -- Compare each incoming field's HLC against the stored version
  FOR field_key IN SELECT jsonb_object_keys(p_fields)
  LOOP
    incoming_hlc := p_fields -> field_key ->> 'hlc';
    existing_hlc := merged_versions ->> field_key;

    -- Accept if incoming HLC is lexicographically greater
    IF existing_hlc IS NULL OR incoming_hlc > existing_hlc THEN
      merged_versions := merged_versions || jsonb_build_object(field_key, incoming_hlc);
      accepted_fields := array_append(accepted_fields, field_key);

      -- Dynamically update the field value
      -- Note: This requires building the UPDATE dynamically or handling common fields
      -- For simplicity, we update field_versions and let the client re-upsert
    END IF;
  END LOOP;

  -- Update the field_versions map
  UPDATE public.notes
  SET field_versions = merged_versions,
      updated_at = now()
  WHERE id = p_note_id AND user_id = p_user_id;

  RETURN jsonb_build_object(
    'status', 'merged',
    'accepted_fields', to_jsonb(accepted_fields),
    'merged_versions', merged_versions
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
