-- =============================================================================
-- Migration: Pages, Workspaces & Yjs Support
-- =============================================================================

-- 1. Workspaces & Members
CREATE TABLE IF NOT EXISTS public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references auth.users(id) not null,
  created_at timestamptz not null default now()
);

CREATE TABLE IF NOT EXISTS public.workspace_members (
  workspace_id uuid references public.workspaces(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

-- 2. Pages Table (Replacing Notes)
-- Includes all columns from notes + new Yjs & workspace columns
CREATE TABLE IF NOT EXISTS public.pages (
  id                      TEXT        PRIMARY KEY,
  user_id                 UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id            UUID        REFERENCES public.workspaces(id) ON DELETE CASCADE,

  -- Core note fields
  title                   TEXT        NOT NULL DEFAULT '',
  content                 JSONB       NOT NULL DEFAULT '{"type": "doc", "content": []}',
  
  -- Yjs Sync Fields
  version                 INTEGER     NOT NULL DEFAULT 1,
  yjs_state               BYTEA,
  yjs_state_vector        BYTEA,

  -- Task-specific fields
  category                TEXT        NOT NULL DEFAULT 'personal',
  priority                TEXT        NOT NULL DEFAULT 'none',
  is_task                 BOOLEAN     NOT NULL DEFAULT false,
  is_all_day              BOOLEAN     NOT NULL DEFAULT false,
  is_completed            BOOLEAN     NOT NULL DEFAULT false,
  is_recurring_instance   BOOLEAN     NOT NULL DEFAULT false,
  is_deleted              BOOLEAN     NOT NULL DEFAULT false,

  -- Rich data
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

  -- CRDT metadata (from old notes table)
  hlc_timestamp           TEXT        NOT NULL DEFAULT '0:0:server',
  field_versions          JSONB       NOT NULL DEFAULT '{}',

  -- Timestamps
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Data Migration: Copy from notes to pages
INSERT INTO public.pages (
  id, user_id, title, category, priority, is_task, is_all_day, is_completed, 
  is_recurring_instance, is_deleted, tags, attachments, links, subtasks, 
  color, "order", folder_id, parent_recurring_id, scheduled_time, end_time, 
  reminder_time, original_scheduled_time, completed_at, recurrence_rule, 
  device_last_edited, hlc_timestamp, field_versions, created_at, updated_at,
  content
)
SELECT 
  id, user_id, title, category, priority, is_task, is_all_day, is_completed, 
  is_recurring_instance, is_deleted, tags, attachments, links, subtasks, 
  color, "order", folder_id, parent_recurring_id, scheduled_time, end_time, 
  reminder_time, original_scheduled_time, completed_at, recurrence_rule, 
  device_last_edited, hlc_timestamp, field_versions, created_at, updated_at,
  -- Wrap legacy Delta in a custom node so Dart converter can parse it
  jsonb_build_object(
    'type', 'doc',
    'content', jsonb_build_array(
      jsonb_build_object(
        'type', 'legacy_quill_delta',
        'attrs', jsonb_build_object('raw_delta', COALESCE(body, '{"ops":[]}'))
      )
    )
  )
FROM public.notes
ON CONFLICT (id) DO NOTHING;

-- Trigger for updated_at
CREATE TRIGGER pages_updated_at
  BEFORE UPDATE ON public.pages
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS Policies
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member can access workspaces"
  ON public.workspaces FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members
      WHERE workspace_id = workspaces.id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "user can access personal and workspace pages"
  ON public.pages FOR ALL
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.workspace_members
      WHERE workspace_id = pages.workspace_id
      AND user_id = auth.uid()
    )
  );
