-- ParentCompass: Family data model
-- Phase 2D.1 — creates families, family_members, section_responses, roadmap_versions
-- Run in Supabase SQL editor: supabase.com/dashboard/project/izezbdvrqzzerkukmyoy/sql

-- Schema-level usage grant — placed once at the top.
-- Grants schema visibility only; does NOT imply any table access.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- ─────────────────────────────────────────────
-- Shared trigger function: auto-updates updated_at columns.
-- CREATE OR REPLACE is intentional — safe to re-run, idempotent by design.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────
-- 1. families
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

CREATE INDEX IF NOT EXISTS idx_families_primary_user_id
  ON public.families(primary_user_id);

ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Primary parent can read own family"
  ON public.families FOR SELECT
  USING (auth.uid() = primary_user_id);

CREATE POLICY "Primary parent can insert own family"
  ON public.families FOR INSERT
  WITH CHECK (auth.uid() = primary_user_id);

-- WITH CHECK prevents changing primary_user_id to another user's uid (family hijacking).
CREATE POLICY "Primary parent can update own family"
  ON public.families FOR UPDATE
  USING (auth.uid() = primary_user_id)
  WITH CHECK (auth.uid() = primary_user_id);

-- No DELETE policy: family deletion is handled server-side via the auth.users cascade.

GRANT SELECT, INSERT, UPDATE ON public.families TO authenticated;

CREATE TRIGGER families_updated_at
  BEFORE UPDATE ON public.families
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────
-- 2. family_members
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.family_members (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id         UUID        NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  type              TEXT        NOT NULL CHECK (type IN ('parent', 'spouse', 'student')),
  display_name      TEXT        NOT NULL,
  invite_email      TEXT,
  status            TEXT        NOT NULL DEFAULT 'active'
                                CHECK (status IN ('active', 'pending', 'declined')),
  -- invite_token: server-only secret. Min 32 chars enforced at DB level.
  -- Never expose in client responses — authenticated role has no SELECT grant
  -- on this column. Use family_members_safe view for client-facing queries.
  invite_token      TEXT        UNIQUE
                                CHECK (invite_token IS NULL OR length(invite_token) >= 32),
  invite_expires_at TIMESTAMPTZ,
  -- Pending members (with invite_token) must have an expiry set.
  CONSTRAINT invite_token_requires_expiry
    CHECK (invite_token IS NULL OR invite_expires_at IS NOT NULL),
  -- Primary parent member is always active with no invite.
  -- status is declared above so this constraint is valid.
  CONSTRAINT parent_type_always_active
    CHECK (type != 'parent' OR (invite_token IS NULL AND status = 'active')),
  -- grade: US high school grades (9-12). NULL for parent/spouse and non-US-track students.
  grade             SMALLINT    CHECK (grade BETWEEN 9 AND 12),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_family_members_family_id
  ON public.family_members(family_id);

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

-- Column-level SELECT grant: excludes invite_token. authenticated can read all
-- columns except invite_token. INSERT/UPDATE/DELETE on the base table are table-level.
GRANT SELECT (id, family_id, type, display_name, invite_email, invite_expires_at, status, grade, created_at)
  ON public.family_members TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.family_members TO authenticated;

-- Security-barrier view: convenient alias for client-facing queries.
-- Mirrors the column-level grant above; use this in all API SELECT queries.
CREATE VIEW public.family_members_safe WITH (security_barrier = true) AS
  SELECT id, family_id, type, display_name, invite_email,
         invite_expires_at, status, grade, created_at
  FROM public.family_members;

GRANT SELECT ON public.family_members_safe TO authenticated;

-- ─────────────────────────────────────────────
-- 3. section_responses
--    PRIVACY MODEL (Rule 11): Raw inputs are private to the contributor.
--    Primary parent reads only their own responses via the client API.
--    Spouse/student responses are read server-side (service role) for AI synthesis.
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

CREATE INDEX IF NOT EXISTS idx_section_responses_family_member
  ON public.section_responses(family_id, member_id);

ALTER TABLE public.section_responses ENABLE ROW LEVEL SECURITY;

-- Parent reads only their own (type='parent') responses.
-- Uses family_members_safe view so invite_token is never visible in the subquery.
CREATE POLICY "Members can read own section responses"
  ON public.section_responses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members_safe fms
      JOIN public.families f ON f.id = fms.family_id
      WHERE fms.id = member_id
        AND f.primary_user_id = auth.uid()
        AND fms.type = 'parent'
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

CREATE TRIGGER section_responses_updated_at
  BEFORE UPDATE ON public.section_responses
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

GRANT SELECT, INSERT, UPDATE ON public.section_responses TO authenticated;

-- ─────────────────────────────────────────────
-- 4. roadmap_versions — immutable history, no DELETE policy.
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
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (family_id, version)
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

-- No DELETE policy: roadmap versions are immutable history.

GRANT SELECT, INSERT ON public.roadmap_versions TO authenticated;
