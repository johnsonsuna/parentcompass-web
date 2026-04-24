import { describe, it, expect } from 'vitest';
import { validateProfileInput, VALID_GRADES, VALID_SCHOOL_TYPES } from '../profile';

describe('validateProfileInput', () => {
  const valid = { studentName: 'Arjun Sharma', grade: 9, schoolType: 'us' as const };

  it('accepts a valid profile', () => {
    expect(validateProfileInput(valid)).toBeNull();
  });

  it('rejects empty student name', () => {
    expect(validateProfileInput({ ...valid, studentName: '' })).toMatch(/name/i);
  });

  it('rejects student name that is only whitespace', () => {
    expect(validateProfileInput({ ...valid, studentName: '   ' })).toMatch(/name/i);
  });

  it('rejects student name longer than 100 characters', () => {
    expect(validateProfileInput({ ...valid, studentName: 'A'.repeat(101) })).toMatch(/name/i);
  });

  it('rejects grade below 9', () => {
    expect(validateProfileInput({ ...valid, grade: 8 })).toMatch(/grade/i);
  });

  it('rejects grade above 12', () => {
    expect(validateProfileInput({ ...valid, grade: 13 })).toMatch(/grade/i);
  });

  it('accepts all valid grades', () => {
    for (const g of VALID_GRADES) {
      expect(validateProfileInput({ ...valid, grade: g })).toBeNull();
    }
  });

  it('rejects invalid school type', () => {
    expect(validateProfileInput({ ...valid, schoolType: 'unknown' as never })).toMatch(/school/i);
  });

  it('accepts all valid school types', () => {
    for (const t of VALID_SCHOOL_TYPES) {
      expect(validateProfileInput({ ...valid, schoolType: t })).toBeNull();
    }
  });
});
