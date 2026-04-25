// Public family types — safe to import in any file including client components.
// Does NOT include invite_token. For server-only types, see family.server.ts.

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

// Safe client-facing type — mirrors the family_members_safe DB view.
// invite_token is absent. Use this everywhere except invite creation.
export interface FamilyMemberPublic {
  id: string;
  family_id: string;
  type: MemberType;
  display_name: string;
  invite_email: string | null;
  invite_expires_at: string | null;
  status: MemberStatus;
  grade: number | null;
  created_at: string;
}

// ─── Section responses ────────────────────────────────────────────────────────

export type SectionType =
  | 'parent_goals'
  | 'parent_constraints'
  | 'parent_expectations'
  | 'spouse_priorities'
  | 'student_interests'
  | 'student_anxieties'
  | 'student_career_curiosities'
  | 'student_academic_snapshot';

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

// Discriminated union — maps section_type to its typed response shape.
// Use this in API validation and the AI synthesis prompt builder.
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
  // Loose type intentional for raw DB reads. Use SectionResponseData discriminated
  // union for type-safe access in API validation and AI synthesis prompt building.
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

export interface RoadmapDiff {
  changedGrades: number[];
  addedPriorities: string[];
  removedPriorities: string[];
}

// ─── Composite view ───────────────────────────────────────────────────────────

// Full family context for the AI synthesis route (Phase 2D.4).
// Built server-side using the Supabase service role. See family.server.ts.
export interface FamilyContext {
  family: Family;
  members: FamilyMemberPublic[];
  responses: SectionResponse[];
  latestRoadmap: RoadmapVersion | null;
}
