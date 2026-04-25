import { describe, it, expect } from 'vitest';
import { asSectionResponseData } from '../family';
import type { SectionResponse } from '../family';

describe('asSectionResponseData', () => {
  it('returns the same object with discriminated union typing', () => {
    const row: SectionResponse = {
      id: 'r1',
      family_id: 'f1',
      member_id: 'm1',
      section_type: 'parent_goals',
      responses: { target_colleges: 'MIT', desired_outcome: 'engineering' },
      updated_at: '2026-04-25T00:00:00Z',
    };

    const typed = asSectionResponseData(row);
    expect(typed.section_type).toBe('parent_goals');
    expect(typed.responses).toEqual(row.responses);
  });

  it('preserves all response values without mutation', () => {
    const row: SectionResponse = {
      id: 'r2',
      family_id: 'f1',
      member_id: 'm2',
      section_type: 'student_interests',
      responses: { subjects: ['math', 'cs'], activities: ['robotics'] },
      updated_at: '2026-04-25T00:00:00Z',
    };

    const typed = asSectionResponseData(row);
    expect(typed).toBe(row);
  });
});
