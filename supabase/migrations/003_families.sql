-- ParentCompass: Family data model
-- Phase 2D.1 — creates families, family_members, section_responses, roadmap_versions
-- Run in Supabase SQL editor: supabase.com/dashboard/project/izezbdvrqzzerkukmyoy/sql
-- Safe to re-run: TABLE/INDEX use IF NOT EXISTS; policies/triggers use DROP IF EXISTS first.

-- Schema-level usage grant — idempotent; also issued in earlier migrations.
-- Grants schema visibility only; does NOT imply any table access.
-- anon is included here for public endpoints; no table in this migration grants anon any DML.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- ─────────────────────────────────────────────
-- Shared trigger function: auto-updates updated_at columns.
-- CREATE OR REPLACE is intentional — idempotent by design.
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

DROP POLICY IF EXISTS "Primary parent can read own family" ON public.families;
CREATE POLICY "Primary parent can read own family"
  ON public.families FOR SELECT
  USING (auth.uid() = primary_user_id);

-- TODO Phase 2D.3: add access for invited members.
-- NOTE: invited members use magic-link tokens (no Supabase auth account), so auth.jwt()->>'email'
-- will be null for them. Access must be granted server-side via service_role after token
-- validation — do NOT implement as a client-side JWT email claim policy here.

DROP POLICY IF EXISTS "Primary parent can insert own family" ON public.families;
CREATE POLICY "Primary parent can insert own family"
  ON public.families FOR INSERT
  WITH CHECK (auth.uid() = primary_user_id);

-- WITH CHECK prevents changing primary_user_id to another user's uid (family hijacking).
DROP POLICY IF EXISTS "Primary parent can update own family" ON public.families;
CREATE POLICY "Primary parent can update own family"
  ON public.families FOR UPDATE
  USING (auth.uid() = primary_user_id)
  WITH CHECK (auth.uid() = primary_user_id);

-- No DELETE policy: family deletion is handled server-side via the auth.users cascade.

GRANT SELECT, INSERT, UPDATE ON public.families TO authenticated;

DROP TRIGGER IF EXISTS families_updated_at ON public.families;
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
  -- authenticated role has column-level grants excluding this column.
  invite_token      TEXT        UNIQUE
                                CHECK (invite_token IS NULL OR length(invite_token) >= 32),
  invite_expires_at TIMESTAMPTZ,
  -- Pending members (with invite_token) must have an expiry set.
  CONSTRAINT invite_token_requires_expiry
    CHECK (invite_token IS NULL OR invite_expires_at IS NOT NULL),
  -- Primary parent member is always active with no invite (status declared above).
  CONSTRAINT parent_type_always_active
    CHECK (type != 'parent' OR (invite_token IS NULL AND status = 'active')),
  -- grade: US high school grades (9-12). NULL for parent/spouse and non-US-track students.
  grade             SMALLINT    CHECK (grade BETWEEN 9 AND 12),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_family_members_family_id
  ON public.family_members(family_id);

-- Partial index for Phase 2D.3 invite-email-based RLS policy lookups.
CREATE INDEX IF NOT EXISTS idx_family_members_invite_email
  ON public.family_members(invite_email) WHERE invite_email IS NOT NULL;

ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Primary parent can read own family members" ON public.family_members;
CREATE POLICY "Primary parent can read own family members"
  ON public.family_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Primary parent can insert family members" ON public.family_members;
CREATE POLICY "Primary parent can insert family members"
  ON public.family_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

-- WITH CHECK prevents moving a member to a different family.
DROP POLICY IF EXISTS "Primary parent can update family members" ON public.family_members;
CREATE POLICY "Primary parent can update family members"
  ON public.family_members FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

-- type='parent' is excluded: deleting the primary parent's own member row while the families
-- row persists would break all RLS subqueries that JOIN on type='parent', locking the account.
DROP POLICY IF EXISTS "Primary parent can delete family members" ON public.family_members;
CREATE POLICY "Primary parent can delete family members"
  ON public.family_members FOR DELETE
  USING (
    type != 'parent'
    AND EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

-- Column-level grants: invite_token, invite_expires_at, and type excluded from UPDATE.
-- invite_token: server-only secret — never readable or writable via authenticated role.
-- invite_expires_at: invite expiry refresh is a server-side operation (service_role only).
-- type: member type is immutable after creation; type changes require server-side validation.
-- Column-level SELECT: excludes invite_token.
-- Column-level INSERT: excludes invite_token, id (auto-generated), created_at (auto-set).
-- Column-level UPDATE: excludes invite_token, type, invite_expires_at, id, family_id, created_at.
-- DELETE is table-level (no sensitive column exposure on DELETE).
GRANT SELECT (id, family_id, type, display_name, invite_email, invite_expires_at, status, grade, created_at)
  ON public.family_members TO authenticated;
GRANT INSERT (family_id, type, display_name, invite_email, status, grade)
  ON public.family_members TO authenticated;
GRANT UPDATE (display_name, invite_email, status, grade)
  ON public.family_members TO authenticated;
GRANT DELETE ON public.family_members TO authenticated;

-- Security-barrier view: service_role-only internal alias excluding invite_token.
-- PURPOSE: used by server-side code (e.g. invite resolution) that runs as service_role
--          and needs a guaranteed invite_token-free projection without relying on column grants.
-- CLIENT ACCESS: authenticated clients query the base table directly via the column-level
--                SELECT grant above — this view is NOT accessible to authenticated users.
-- TypeScript: FamilyMemberPublic in family.ts mirrors this projection; it is populated from
--             the base table column-level grant, not from this view.
CREATE OR REPLACE VIEW public.family_members_safe WITH (security_barrier = true) AS
  SELECT id, family_id, type, display_name, invite_email,
         invite_expires_at, status, grade, created_at
  FROM public.family_members;

-- Restrict access: service_role only. authenticated and PUBLIC have no access to this view.
REVOKE ALL ON public.family_members_safe FROM PUBLIC;
REVOKE ALL ON public.family_members_safe FROM authenticated;
GRANT SELECT ON public.family_members_safe TO service_role;

-- ─────────────────────────────────────────────
-- 3. section_responses
--    PRIVACY MODEL: Raw inputs are private to the contributor.
--    Primary parent reads their own responses via the client API.
--    Spouse/student responses are read server-side (service role) for AI synthesis.
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.section_responses (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id    UUID        NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  member_id    UUID        NOT NULL REFERENCES public.family_members(id) ON DELETE CASCADE,
  -- CHECK mirrors SECTION_TYPES in src/lib/types/family.ts — keep in sync on schema changes.
  section_type TEXT        NOT NULL
                           CHECK (section_type IN (
                             'parent_goals', 'parent_constraints', 'parent_expectations',
                             'spouse_priorities', 'student_interests', 'student_anxieties',
                             'student_career_curiosities', 'student_academic_snapshot'
                           )),
  responses    JSONB       NOT NULL DEFAULT '{}',
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (family_id, member_id, section_type)
);

CREATE INDEX IF NOT EXISTS idx_section_responses_family_member
  ON public.section_responses(family_id, member_id);

ALTER TABLE public.section_responses ENABLE ROW LEVEL SECURITY;

-- SECURITY DEFINER trigger: validates section_responses.family_id matches the member's family_id.
-- An RLS-only check could be bypassed by supplying a valid family_id that belongs to the caller
-- but a member_id from a different family they know about. The trigger enforces the cross-table
-- consistency at the DB level on every INSERT regardless of RLS evaluation order.
-- SET search_path = public prevents search_path hijacking.
CREATE OR REPLACE FUNCTION public.check_section_response_member_family()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF (SELECT family_id FROM public.family_members WHERE id = NEW.member_id) IS DISTINCT FROM NEW.family_id THEN
    RAISE EXCEPTION 'member_id % does not belong to family %', NEW.member_id, NEW.family_id;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.check_section_response_member_family() FROM PUBLIC;

DROP TRIGGER IF EXISTS section_responses_check_member_family ON public.section_responses;
CREATE TRIGGER section_responses_check_member_family
  BEFORE INSERT ON public.section_responses
  FOR EACH ROW EXECUTE FUNCTION public.check_section_response_member_family();

-- Primary parent reads only their own (type='parent') member's responses.
-- Spouse/student raw inputs are never readable by the primary parent via client API.
-- Enforced here at the DB layer by scoping to the 'parent'-type member row for this family.
DROP POLICY IF EXISTS "Primary parent can read own section responses" ON public.section_responses;
DROP POLICY IF EXISTS "Members can read own section responses" ON public.section_responses;
CREATE POLICY "Primary parent can read own section responses"
  ON public.section_responses FOR SELECT
  USING (
    member_id IN (
      SELECT fm.id FROM public.family_members fm
      JOIN public.families f ON f.id = fm.family_id
      WHERE fm.family_id = section_responses.family_id
        AND fm.type = 'parent'
        AND f.primary_user_id = auth.uid()
    )
  );

-- INSERT: restricted to the parent-type member only.
-- Primary parent may only write their own (type='parent') section responses via client API.
-- Spouse/student responses are written server-side (service role) — not through this policy.
DROP POLICY IF EXISTS "Primary parent can insert section responses" ON public.section_responses;
CREATE POLICY "Primary parent can insert section responses"
  ON public.section_responses FOR INSERT
  WITH CHECK (
    member_id IN (
      SELECT fm.id FROM public.family_members fm
      JOIN public.families f ON f.id = fm.family_id
      WHERE fm.family_id = section_responses.family_id
        AND fm.type = 'parent'
        AND f.primary_user_id = auth.uid()
    )
  );

-- UPDATE: scope to parent-type member only, consistent with SELECT and INSERT.
-- Column-level UPDATE grant (section_type, responses) excludes family_id and member_id,
-- preventing a client from moving a response to a different family or member.
DROP POLICY IF EXISTS "Primary parent can update section responses" ON public.section_responses;
CREATE POLICY "Primary parent can update section responses"
  ON public.section_responses FOR UPDATE
  USING (
    member_id IN (
      SELECT fm.id FROM public.family_members fm
      JOIN public.families f ON f.id = fm.family_id
      WHERE fm.family_id = section_responses.family_id
        AND fm.type = 'parent'
        AND f.primary_user_id = auth.uid()
    )
  )
  WITH CHECK (
    member_id IN (
      SELECT fm.id FROM public.family_members fm
      JOIN public.families f ON f.id = fm.family_id
      WHERE fm.family_id = section_responses.family_id
        AND fm.type = 'parent'
        AND f.primary_user_id = auth.uid()
    )
  );

-- No DELETE policy: primary parent cannot delete section responses via client API.
-- Deletion is handled server-side only (service role). Cascade from family/member deletion handles cleanup.

DROP TRIGGER IF EXISTS section_responses_updated_at ON public.section_responses;
CREATE TRIGGER section_responses_updated_at
  BEFORE UPDATE ON public.section_responses
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- UPDATE grant is column-level: excludes family_id and member_id to prevent row hijacking.
GRANT SELECT, INSERT ON public.section_responses TO authenticated;
GRANT UPDATE (section_type, responses) ON public.section_responses TO authenticated;

-- ─────────────────────────────────────────────
-- 4. roadmap_versions — immutable history, no DELETE policy.
-- roadmap_versions has no updated_at: rows are immutable after INSERT (content/diff never patched).
-- created_at is the only timestamp needed; adding updated_at would imply mutability.
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

DROP POLICY IF EXISTS "Primary parent can read own roadmap versions" ON public.roadmap_versions;
CREATE POLICY "Primary parent can read own roadmap versions"
  ON public.roadmap_versions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.families
      WHERE id = family_id AND primary_user_id = auth.uid()
    )
  );

-- No INSERT policy for authenticated: roadmap generation is a server-side AI operation (Phase 2D.4).
-- Inserts happen via service_role in API routes only. Dropping any prior INSERT policy here.
DROP POLICY IF EXISTS "Primary parent can insert roadmap versions" ON public.roadmap_versions;

-- No DELETE policy: roadmap versions are immutable history.

-- SECURITY DEFINER trigger: validates previous_version_id cross-family integrity on every INSERT.
-- Uses SECURITY DEFINER so the subquery bypasses RLS — without it, rows from other families are
-- invisible under RLS, making the subquery return NULL, which silently rejects valid checks and
-- could allow probing other families' version IDs via NULL-vs-non-NULL responses.
-- SET search_path = public prevents search_path hijacking.
CREATE OR REPLACE FUNCTION public.check_roadmap_previous_version()
  RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.previous_version_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.roadmap_versions
      WHERE id = NEW.previous_version_id AND family_id = NEW.family_id
    ) THEN
      RAISE EXCEPTION 'previous_version_id % does not belong to family %',
        NEW.previous_version_id, NEW.family_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Revoke public execute: prevents anon/authenticated from calling the function directly
-- to probe whether a UUID is a valid previous_version_id in any family.
-- Triggers invoke the function through their own mechanism — no explicit EXECUTE grant needed.
REVOKE EXECUTE ON FUNCTION public.check_roadmap_previous_version() FROM PUBLIC;

DROP TRIGGER IF EXISTS roadmap_versions_check_previous ON public.roadmap_versions;
CREATE TRIGGER roadmap_versions_check_previous
  BEFORE INSERT ON public.roadmap_versions
  FOR EACH ROW EXECUTE FUNCTION public.check_roadmap_previous_version();

-- SELECT only: authenticated clients may read roadmap versions but not insert them.
GRANT SELECT ON public.roadmap_versions TO authenticated;
