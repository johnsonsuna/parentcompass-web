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

// ─── Family members ──────────────────────────────────────────────────────────

export type MemberType = 'parent' | 'spouse' | 'student';
export type MemberStatus = 'active' | 'pending' | 'declined';

export interface FamilyMember {
  id: string;
  family_id: string;
  type: MemberType;
  display_name: string;
  invite_email: string | null;
  invite_token: string | null;
  invite_expires_at: string | null;
  status: MemberStatus;
  grade: number | null;
  created_at: string;
}

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

export interface SectionResponse {
  id: string;
  family_id: string;
  member_id: string;
  section_type: SectionType;
  // Keyed by question slug → answer string or structured value.
  // Shape is section-specific; validated at the API layer.
  responses: Record<string, unknown>;
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

// Full family context passed to the AI roadmap generator in Phase 2D.4
export interface FamilyContext {
  family: Family;
  members: FamilyMember[];
  responses: SectionResponse[];
  latestRoadmap: RoadmapVersion | null;
}
