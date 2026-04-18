-- =============================================================================
-- Synq App: Core Supabase Tables
-- =============================================================================
-- This migration creates all tables needed for the Synq task/notes app.
-- Run this in the Supabase SQL Editor or via the CLI: supabase db push
--
-- Tables:
--   1. profiles  — User profiles (replaces Firestore users collection)
--   2. notes     — Notes/tasks with CRDT field versions
--   3. folders   — Folder organization with CRDT field versions
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Profiles Table
-- ---------------------------------------------------------------------------
-- Replaces: Firestore > users/{uid}
-- Linked to: auth.users via foreign key

CREATE TABLE IF NOT EXISTS public.profiles (
  id                  UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               TEXT        NOT NULL DEFAULT '',
  name                TEXT        NOT NULL DEFAULT 'User',
  plan_tier           TEXT        NOT NULL DEFAULT 'free',
  is_admin            BOOLEAN     NOT NULL DEFAULT false,
  storage_used_bytes  INTEGER     NOT NULL DEFAULT 0,
  active_device_ids   TEXT[]      NOT NULL DEFAULT '{}',
  active_devices      JSONB       NOT NULL DEFAULT '[]',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'User profiles with plan tier and device management';

-- ---------------------------------------------------------------------------
-- 2. Notes Table
-- ---------------------------------------------------------------------------
-- Replaces: Firestore > users/{uid}/notes/{noteId}
-- CRDT columns: hlc_timestamp, field_versions
-- Soft-delete: is_deleted flag (never physically deleted for sync integrity)

CREATE TABLE IF NOT EXISTS public.notes (
  id                      TEXT        PRIMARY KEY,
  user_id                 UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Core note fields
  title                   TEXT        NOT NULL DEFAULT '',
  body                    TEXT,                          -- Quill Delta JSON
  category                TEXT        NOT NULL DEFAULT 'personal',
  priority                TEXT        NOT NULL DEFAULT 'none',

  -- Task-specific fields
  is_task                 BOOLEAN     NOT NULL DEFAULT false,
  is_all_day              BOOLEAN     NOT NULL DEFAULT false,
  is_completed            BOOLEAN     NOT NULL DEFAULT false,
  is_recurring_instance   BOOLEAN     NOT NULL DEFAULT false,
  is_deleted              BOOLEAN     NOT NULL DEFAULT false,

  -- Rich data (stored as JSONB)
  tags                    JSONB       NOT NULL DEFAULT '[]',
  attachments             JSONB       NOT NULL DEFAULT '[]',
  links                   JSONB       NOT NULL DEFAULT '[]',
  subtasks                JSONB       NOT NULL DEFAULT '[]',

  -- Display
  color                   INTEGER,
  "order"                 INTEGER     NOT NULL DEFAULT 0,

  -- Relationships
  folder_id               TEXT,
  parent_recurring_id     TEXT,

  -- Scheduling
  scheduled_time          TIMESTAMPTZ,
  end_time                TIMESTAMPTZ,
  reminder_time           TIMESTAMPTZ,
  original_scheduled_time TIMESTAMPTZ,
  completed_at            TIMESTAMPTZ,
  recurrence_rule         JSONB,

  -- Device tracking
  device_last_edited      TEXT,

  -- CRDT metadata
  hlc_timestamp           TEXT        NOT NULL DEFAULT '0:0:server',
  field_versions          JSONB       NOT NULL DEFAULT '{}',

  -- Timestamps
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.notes IS 'Notes and tasks with CRDT field-level versioning';
COMMENT ON COLUMN public.notes.hlc_timestamp IS 'Hybrid Logical Clock: last write timestamp';
COMMENT ON COLUMN public.notes.field_versions IS '{"fieldName": "hlc_string"} per-field version map';

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS notes_user_updated_idx
  ON public.notes(user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS notes_user_deleted_idx
  ON public.notes(user_id, is_deleted);

CREATE INDEX IF NOT EXISTS notes_user_scheduled_idx
  ON public.notes(user_id, is_deleted, is_completed, scheduled_time);

CREATE INDEX IF NOT EXISTS notes_user_folder_idx
  ON public.notes(user_id, is_deleted, folder_id);

-- ---------------------------------------------------------------------------
-- 3. Folders Table
-- ---------------------------------------------------------------------------
-- Replaces: Firestore > users/{uid}/folders/{folderId}

CREATE TABLE IF NOT EXISTS public.folders (
  id                TEXT        PRIMARY KEY,
  user_id           UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT        NOT NULL,
  icon_code_point   INTEGER     NOT NULL DEFAULT 59404,  -- Icons.folder
  icon_font_family  TEXT,
  color_value       INTEGER     NOT NULL DEFAULT 4280391411, -- Colors.blue
  is_favorite       BOOLEAN     NOT NULL DEFAULT false,
  is_deleted        BOOLEAN     NOT NULL DEFAULT false,
  parent_id         TEXT,

  -- CRDT metadata
  hlc_timestamp     TEXT        NOT NULL DEFAULT '0:0:server',
  field_versions    JSONB       NOT NULL DEFAULT '{}',

  -- Timestamps
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.folders IS 'Folder organization with CRDT field-level versioning';

CREATE INDEX IF NOT EXISTS folders_user_idx
  ON public.folders(user_id, is_deleted);

-- ---------------------------------------------------------------------------
-- 4. Auto-update updated_at trigger
-- ---------------------------------------------------------------------------
-- Automatically sets updated_at = now() on every UPDATE.

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notes_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER folders_updated_at
  BEFORE UPDATE ON public.folders
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ---------------------------------------------------------------------------
-- 5. Auto-create profile on new auth user
-- ---------------------------------------------------------------------------
-- This trigger creates a profile row whenever a new user signs up.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, created_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    now()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
