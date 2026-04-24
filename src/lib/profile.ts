export const VALID_GRADES = [9, 10, 11, 12] as const;
export type Grade = (typeof VALID_GRADES)[number];

export const VALID_SCHOOL_TYPES = ['us', 'hybrid'] as const;
export type SchoolType = (typeof VALID_SCHOOL_TYPES)[number];

export interface ProfileInput {
  studentName: string;
  grade: number;
  schoolType: SchoolType | string;
}

export function validateProfileInput(input: ProfileInput): string | null {
  const name = input.studentName.trim();
  if (!name) return 'Student name is required.';
  if (name.length > 100) return 'Student name must be 100 characters or fewer.';

  if (!VALID_GRADES.includes(input.grade as Grade)) {
    return 'Grade must be between 9 and 12.';
  }

  if (!VALID_SCHOOL_TYPES.includes(input.schoolType as SchoolType)) {
    return 'Please select a valid school type.';
  }

  return null;
}
