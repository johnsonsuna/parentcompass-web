// Family domain types — mirrors the 003_families.sql schema.
// These are used across Phase 2D API routes, UI components, and the AI roadmap generator.

export type FamilyPlan = 'family' | 'plus' | 'premium';
export type FamilyTrack = 'us' | 'hybrid';

export interface Family {
  id: string;
  primary_user_id: string;
  plan: FamilyPlan;
  track: FamilyTrack;
  created_at: string;
  updated_at: string;
}

// ─── Family members ───────────────────────────────────────────────────────────

export type MemberType = 'parent' | 'spouse' | 'student';
export type MemberStatus = 'active' | 'pending' | 'declined';

export interface FamilyMember {
  id: string;
  family_id: string;
  type: MemberType;
  display_name: string;
  invite_email: string | null;
  // invite_token is a server-only secret. Strip it from all client-facing API responses.
  // Only return it once, at creation time, for embedding in the magic-link URL.
  invite_token: string | null;
  invite_expires_at: string | null;
  status: MemberStatus;
  grade: number | null;
  created_at: string;
}

// Safe client-facing projection of FamilyMember — omits invite_token.
export type FamilyMemberPublic = Omit<FamilyMember, 'invite_token'>;

// ─── Section responses ────────────────────────────────────────────────────────

// V1 section types. Extensible — stored as TEXT in the DB.
export type SectionType =
  | 'parent_goals'
  | 'parent_constraints'
  | 'parent_expectations'
  | 'spouse_priorities'
  | 'student_interests'
  | 'student_anxieties'
  | 'student_career_curiosities'
  | 'student_academic_snapshot';

// Per-section response shapes. Add one interface per section_type.
// Used by the API validation layer and the AI synthesis prompt builder.
export interface ParentGoalsResponse {
  target_colleges?: string;
  desired_outcome?: string;
  timeline_pressure?: string;
}

export interface ParentConstraintsResponse {
  budget_range?: string;
  location_preferences?: string;
  financial_aid_needed?: boolean;
}

export interface StudentInterestsResponse {
  subjects?: string[];
  activities?: string[];
  career_curiosities?: string;
}

export interface StudentAnxietiesResponse {
  biggest_concern?: string;
  pressure_sources?: string[];
}

export interface SpousePrioritiesResponse {
  priorities?: string;
  alignment_notes?: string;
}

// Discriminated union mapping section_type → response shape
export type SectionResponseData =
  | { section_type: 'parent_goals'; responses: ParentGoalsResponse }
  | { section_type: 'parent_constraints'; responses: ParentConstraintsResponse }
  | { section_type: 'parent_expectations'; responses: Record<string, string> }
  | { section_type: 'spouse_priorities'; responses: SpousePrioritiesResponse }
  | { section_type: 'student_interests'; responses: StudentInterestsResponse }
  | { section_type: 'student_anxieties'; responses: StudentAnxietiesResponse }
  | { section_type: 'student_career_curiosities'; responses: Record<string, string> }
  | { section_type: 'student_academic_snapshot'; responses: Record<string, string | number> };

export interface SectionResponse {
  id: string;
  family_id: string;
  member_id: string;
  section_type: SectionType;
  responses: Record<string, string | string[] | number | boolean>;
  updated_at: string;
}

// ─── Roadmap versions ─────────────────────────────────────────────────────────

export type RoadmapTrigger = 'initial' | 'manual' | 'monthly' | 'annual' | 'material_change';

export interface RoadmapVersion {
  id: string;
  family_id: string;
  content: RoadmapContent;
  trigger: RoadmapTrigger;
  version: number;
  previous_version_id: string | null;
  diff: RoadmapDiff | null;
  created_at: string;
}

// Matches the existing roadmap content shape from 002_roadmaps.sql / lib/roadmap.ts
export interface RoadmapContent {
  currentGrade: number;
  milestones: GradeMilestone[];
  immediatePriorities: string[];
}

export interface GradeMilestone {
  grade: number;
  label: string;
  focus: string;
  actions: string[];
}

// Surface-level diff: which grades changed between versions
export interface RoadmapDiff {
  changedGrades: number[];
  addedPriorities: string[];
  removedPriorities: string[];
}

// ─── Composite view ───────────────────────────────────────────────────────────

// Full family context passed to the AI roadmap generator in Phase 2D.4.
// Built server-side using the Supabase service role (bypasses RLS to read
// all member section_responses for AI synthesis).
export interface FamilyContext {
  family: Family;
  members: FamilyMemberPublic[];
  responses: SectionResponse[];
  latestRoadmap: RoadmapVersion | null;
}
