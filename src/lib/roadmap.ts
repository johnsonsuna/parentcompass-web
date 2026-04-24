import Anthropic from '@anthropic-ai/sdk';

export type Grade = 9 | 10 | 11 | 12;
export type SchoolType = 'us' | 'hybrid';

export interface GradeTrack {
  focus: string;
  milestones: string[];
  actions: string[];
  hybrid_actions?: string[];
}

export interface RoadmapContent {
  grade_tracks: Partial<Record<string, GradeTrack>>;
  immediate_priorities: string[];
}

export interface GenerateRoadmapInput {
  studentName: string;
  grade: Grade;
  schoolType: SchoolType;
}

const GRADE_LABELS: Record<number, string> = {
  9: 'Freshman',
  10: 'Sophomore',
  11: 'Junior',
  12: 'Senior',
};

export function buildPrompt(input: GenerateRoadmapInput): string {
  const gradesRemaining = Array.from(
    { length: 13 - input.grade },
    (_, i) => input.grade + i
  );
  const isHybrid = input.schoolType === 'hybrid';

  const gradeBlocks = gradesRemaining
    .map(
      (g) => `"${g}": {
      "focus": "one-line theme for Grade ${g}",
      "milestones": ["3–5 major milestones to hit this year"],
      "actions": ["3–5 concrete quarterly actions"]${
        isHybrid
          ? `,
      "hybrid_actions": ["2–3 IIT-JEE/NEET-specific actions for Grade ${g}"]`
          : ''
      }
    }`
    )
    .join(',\n    ');

  return `You are an expert US college counsellor specialised in helping ${
    isHybrid ? 'Indian-American' : 'American'
  } high school students plan their college admissions journey.

Create a personalised Grade 9–12 college planning roadmap for ${input.studentName}, currently a Grade ${input.grade} ${GRADE_LABELS[input.grade]} at a ${
    isHybrid
      ? 'US high school. This family wants a dual-track plan: strong US college outcomes (Common App, SAT/ACT, AP) AND parallel preparation for IIT-JEE/NEET as a backup path'
      : 'US high school following the standard American college admissions path'
  }.

Return ONLY valid JSON matching this structure exactly — no markdown fences, no explanation:
{
  "grade_tracks": {
    ${gradeBlocks}
  },
  "immediate_priorities": ["3–5 specific actions ${input.studentName} should start RIGHT NOW as a Grade ${input.grade} ${GRADE_LABELS[input.grade]}"]
}

Requirements:
- Each string must be under 120 characters
- Be specific and actionable, not generic
- Reference real tools where relevant (Common App, College Board, Khan Academy, Naviance, etc.)
- Milestones are outcomes; actions are tasks the student or parent does`;
}

export async function generateRoadmap(input: GenerateRoadmapInput): Promise<RoadmapContent> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY is not configured');

  const client = new Anthropic({ apiKey });

  const message = await client.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 2048,
    messages: [{ role: 'user', content: buildPrompt(input) }],
  });

  const raw = message.content[0].type === 'text' ? message.content[0].text : '';

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error('Claude returned non-JSON response');
  }

  const content = parsed as RoadmapContent;
  if (!content.grade_tracks || !Array.isArray(content.immediate_priorities)) {
    throw new Error('Roadmap response missing required fields');
  }

  return content;
}
