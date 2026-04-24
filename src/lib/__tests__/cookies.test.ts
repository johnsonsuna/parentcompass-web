import { describe, it, expect } from 'vitest';
import { parseCookieHeader } from '../supabase';

describe('parseCookieHeader', () => {
  it('parses simple key=value pairs', () => {
    expect(parseCookieHeader('name=value')).toEqual([{ name: 'name', value: 'value' }]);
  });

  it('parses multiple cookies separated by semicolons', () => {
    expect(parseCookieHeader('a=1; b=2; c=3')).toEqual([
      { name: 'a', value: '1' },
      { name: 'b', value: '2' },
      { name: 'c', value: '3' },
    ]);
  });

  it('handles base64 values containing = characters', () => {
    // Supabase JWT tokens are base64url-encoded and may contain trailing =
    const b64 = 'eyJhbGciOiJIUzI1NiJ9.payload==';
    expect(parseCookieHeader(`sb-token=${b64}`)).toEqual([
      { name: 'sb-token', value: b64 },
    ]);
  });

  it('returns empty array for empty string', () => {
    expect(parseCookieHeader('')).toEqual([]);
  });

  it('trims whitespace from names and values', () => {
    expect(parseCookieHeader('  csrf  =  abc123  ')).toEqual([
      { name: 'csrf', value: 'abc123' },
    ]);
  });

  it('skips entries without an equals sign', () => {
    expect(parseCookieHeader('valid=yes; badentry; also=good')).toEqual([
      { name: 'valid', value: 'yes' },
      { name: 'also', value: 'good' },
    ]);
  });

  it('skips entries with empty names', () => {
    expect(parseCookieHeader('=orphanvalue; legit=ok')).toEqual([
      { name: 'legit', value: 'ok' },
    ]);
  });

  it('handles values that are empty strings', () => {
    expect(parseCookieHeader('deleted=')).toEqual([{ name: 'deleted', value: '' }]);
  });
});
