import { describe, it, expect, vi, beforeEach } from 'vitest';
import { buildPrompt, generateRoadmap } from '../roadmap';
import type { RoadmapContent } from '../roadmap';

// ---------------------------------------------------------------------------
// buildPrompt tests (pure function — no mocking needed)
// ---------------------------------------------------------------------------

describe('buildPrompt', () => {
  it('includes student name in prompt', () => {
    const prompt = buildPrompt({ studentName: 'Arjun', grade: 9, schoolType: 'us' });
    expect(prompt).toContain('Arjun');
  });

  it('includes current grade and label', () => {
    const prompt = buildPrompt({ studentName: 'Priya', grade: 11, schoolType: 'us' });
    expect(prompt).toContain('Grade 11');
    expect(prompt).toContain('Junior');
  });

  it('includes all grades from current grade to 12 for a grade-9 student', () => {
    const prompt = buildPrompt({ studentName: 'Test', grade: 9, schoolType: 'us' });
    expect(prompt).toContain('"9"');
    expect(prompt).toContain('"10"');
    expect(prompt).toContain('"11"');
    expect(prompt).toContain('"12"');
  });

  it('excludes grades below current for a grade-11 student', () => {
    const prompt = buildPrompt({ studentName: 'Test', grade: 11, schoolType: 'us' });
    expect(prompt).not.toContain('"9"');
    expect(prompt).not.toContain('"10"');
    expect(prompt).toContain('"11"');
    expect(prompt).toContain('"12"');
  });

  it('includes hybrid instructions for hybrid school type', () => {
    const prompt = buildPrompt({ studentName: 'Raj', grade: 10, schoolType: 'hybrid' });
    expect(prompt).toContain('IIT-JEE');
    expect(prompt).toContain('hybrid_actions');
    expect(prompt).toContain('Indian-American');
  });

  it('does not include hybrid instructions for us school type', () => {
    const prompt = buildPrompt({ studentName: 'Alex', grade: 10, schoolType: 'us' });
    expect(prompt).not.toContain('IIT-JEE');
    expect(prompt).not.toContain('hybrid_actions');
  });

  it('asks for JSON-only output', () => {
    const prompt = buildPrompt({ studentName: 'Test', grade: 9, schoolType: 'us' });
    expect(prompt).toContain('valid JSON');
    expect(prompt).toContain('no markdown');
  });
});

// ---------------------------------------------------------------------------
// generateRoadmap tests (Claude API is mocked via vi.hoisted)
// ---------------------------------------------------------------------------

const { mockCreate } = vi.hoisted(() => ({ mockCreate: vi.fn() }));

vi.mock('@anthropic-ai/sdk', () => ({
  default: class {
    messages = { create: mockCreate };
  },
}));

const VALID_ROADMAP: RoadmapContent = {
  grade_tracks: {
    '9': {
      focus: 'Build a strong academic foundation',
      milestones: ['Achieve GPA ≥ 3.8 by end of Grade 9'],
      actions: ['Sign up for Khan Academy SAT prep'],
    },
  },
  immediate_priorities: ['Talk to school counsellor about AP availability'],
};

describe('generateRoadmap', () => {
  beforeEach(() => {
    process.env.ANTHROPIC_API_KEY = 'test-key';
    mockCreate.mockReset();
  });

  it('returns parsed roadmap on valid Claude response', async () => {
    mockCreate.mockResolvedValueOnce({
      content: [{ type: 'text', text: JSON.stringify(VALID_ROADMAP) }],
    });

    const result = await generateRoadmap({ studentName: 'Arjun', grade: 9, schoolType: 'us' });
    expect(result.immediate_priorities).toHaveLength(1);
    expect(result.grade_tracks['9']?.focus).toBe('Build a strong academic foundation');
  });

  it('throws when ANTHROPIC_API_KEY is missing', async () => {
    delete process.env.ANTHROPIC_API_KEY;
    await expect(
      generateRoadmap({ studentName: 'Arjun', grade: 9, schoolType: 'us' })
    ).rejects.toThrow('ANTHROPIC_API_KEY');
  });

  it('throws when Claude returns non-JSON', async () => {
    mockCreate.mockResolvedValueOnce({
      content: [{ type: 'text', text: 'Sorry, I cannot help with that.' }],
    });
    await expect(
      generateRoadmap({ studentName: 'Arjun', grade: 9, schoolType: 'us' })
    ).rejects.toThrow('non-JSON');
  });

  it('throws when response is missing required fields', async () => {
    mockCreate.mockResolvedValueOnce({
      content: [{ type: 'text', text: '{"grade_tracks": {}}' }],
    });
    await expect(
      generateRoadmap({ studentName: 'Arjun', grade: 9, schoolType: 'us' })
    ).rejects.toThrow('required fields');
  });
});
