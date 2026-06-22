-- =============================================================================
-- Migration: Add missing Yjs sync and version columns to notes table
-- =============================================================================

ALTER TABLE public.notes
  ADD COLUMN IF NOT EXISTS workspace_id TEXT,
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS yjs_state INTEGER[],
  ADD COLUMN IF NOT EXISTS yjs_state_vector INTEGER[];
