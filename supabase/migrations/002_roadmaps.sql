-- ParentCompass: AI-generated roadmaps table
-- Run this in the Supabase SQL editor: supabase.com/dashboard/project/izezbdvrqzzerkukmyoy/sql

CREATE TABLE IF NOT EXISTS public.roadmaps (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  grade       SMALLINT    NOT NULL CHECK (grade BETWEEN 9 AND 12),
  school_type TEXT        NOT NULL CHECK (school_type IN ('us', 'hybrid')),
  content     JSONB       NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);

ALTER TABLE public.roadmaps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own roadmap"
  ON public.roadmaps FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own roadmap"
  ON public.roadmaps FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Grant table-level permissions to Supabase roles (required alongside RLS policies)
GRANT SELECT, INSERT ON public.roadmaps TO anon, authenticated;
GRANT USAGE ON SCHEMA public TO anon, authenticated;
