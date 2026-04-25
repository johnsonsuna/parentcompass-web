// Server-only family types. Import only in API routes and server-side lib files.
// DO NOT import in .astro page templates or React components — use family.ts instead.

import type { FamilyMemberPublic } from './family';

// Full DB row — includes invite_token. Only used server-side for invite creation
// and magic-link generation. Never pass to client responses.
export interface FamilyMember extends FamilyMemberPublic {
  invite_token: string | null;
}

// Full family context for AI synthesis (Phase 2D.4).
// Built using the Supabase service role so all section_responses are readable,
// including spouse and student inputs that are hidden from the client API.
export type { FamilyContext } from './family';
