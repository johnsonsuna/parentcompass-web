-- ParentCompass: Family data model
-- Phase 2D.1 — creates families, family_members, section_responses, roadmap_versions
-- Run in Supabase SQL editor: supabase.com/dashboard/project/izezbdvrqzzerkukmyoy/sql

-- ─────────────────────────────────────────────
-- 1. families
--    One row per account. Owned by the primary parent (the Supabase auth user who signed up).
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.families (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  primary_user_id  UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan             TEXT        NOT NULL DEFAULT 'family'
                               CHECK (plan IN ('family', 'plus', 'premium')),
  track            TEXT        NOT NULL DEFAULT 'us'
                               CHECK (track IN ('us', 'hybrid')),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (primary_user_id)
);

ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Primary parent can read own family"
  ON public.families FOR SELECT
  USING (auth.uid() = primary_user_id);

CREATE POLICY "Primary parent can insert own family"
  ON public.families FOR INSERT
  WITH CHECK (auth.uid() = primary_user_id);

CREATE POLICY "Primary parent can update own family"
  ON public.families FOR UPDATE
  USING (auth.uid() = primary_user_id);

GRANT SELECT, INSERT, UPDATE ON public.families TO anon, authenticated;
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- ─────────────────────────────────────────────
-- 2. family_members
--    Primary parent + invited spouse/students.
--    Invitees do NOT get their own Supabase auth users (avoids COPPA for under-13).
--    They are identified by invite_token embedded in a magic-link URL.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.family_members (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id       UUID        NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  type            TEXT        NOT NULL CHECK (type IN ('parent', 'spouse', 'student')),
  display_name    TEXT        NOT NULL,
  invite_email    TEXT,
  invite_token    TEXT        UNIQUE,
  invite_expires_at TIMESTAMPTZ,
  status          TEXT        NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active', 'pending', 'declined')),
  -- grade only applies to student members
  grade           SMALLINT    CHECK (grade BETWEEN 9 AND 12),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Primary parent can read own family members"
  ON public.family_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

CREATE POLICY "Primary parent can insert family members"
  ON public.family_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

CREATE POLICY "Primary parent can update family members"
  ON public.family_members FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

CREATE POLICY "Primary parent can delete family members"
  ON public.family_members FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.family_members TO anon, authenticated;

-- ─────────────────────────────────────────────
-- 3. section_responses
--    Each member's answers to their assigned input sections.
--    Raw inputs are private to the contributor — only the AI-synthesised roadmap is shared.
--    section_type examples: 'parent_goals', 'parent_constraints', 'student_interests',
--    'student_anxieties', 'spouse_priorities' — extensible as TEXT.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.section_responses (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id    UUID        NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  member_id    UUID        NOT NULL REFERENCES public.family_members(id) ON DELETE CASCADE,
  section_type TEXT        NOT NULL,
  responses    JSONB       NOT NULL DEFAULT '{}',
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (family_id, member_id, section_type)
);

ALTER TABLE public.section_responses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Primary parent can read own family section responses"
  ON public.section_responses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

CREATE POLICY "Primary parent can insert section responses"
  ON public.section_responses FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

CREATE POLICY "Primary parent can update section responses"
  ON public.section_responses FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.section_responses TO anon, authenticated;

-- ─────────────────────────────────────────────
-- 4. roadmap_versions
--    Full history of every roadmap regeneration.
--    trigger: what caused the regen (initial / manual / monthly / annual / material_change).
--    diff: JSON diff vs the previous version (null on first generation).
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.roadmap_versions (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id           UUID        NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  content             JSONB       NOT NULL,
  trigger             TEXT        NOT NULL
                                  CHECK (trigger IN ('initial', 'manual', 'monthly', 'annual', 'material_change')),
  version             INTEGER     NOT NULL DEFAULT 1,
  previous_version_id UUID        REFERENCES public.roadmap_versions(id),
  diff                JSONB,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.roadmap_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Primary parent can read own roadmap versions"
  ON public.roadmap_versions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

CREATE POLICY "Primary parent can insert roadmap versions"
  ON public.roadmap_versions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

GRANT SELECT, INSERT ON public.roadmap_versions TO anon, authenticated;
