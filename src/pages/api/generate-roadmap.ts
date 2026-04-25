import type { APIRoute } from 'astro';
import { generateRoadmap } from '../../lib/roadmap';
import type { Grade, SchoolType } from '../../lib/roadmap';

export const prerender = false;

export const POST: APIRoute = async ({ locals }) => {
  const user = locals.user;
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const supabase = locals.supabase;

  // Idempotent: return existing roadmap if already generated
  const { data: existing } = await supabase
    .from('roadmaps')
    .select('content')
    .eq('user_id', user.id)
    .maybeSingle();

  if (existing) {
    return new Response(JSON.stringify(existing.content), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('student_name, grade, school_type')
    .eq('user_id', user.id)
    .maybeSingle();

  if (!profile) {
    return new Response(JSON.stringify({ error: 'Profile not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const content = await generateRoadmap({
      studentName: profile.student_name,
      grade: profile.grade as Grade,
      schoolType: profile.school_type as SchoolType,
    });

    const { error: dbError } = await supabase.from('roadmaps').insert({
      user_id: user.id,
      grade: profile.grade,
      school_type: profile.school_type,
      content,
    });

    if (dbError) {
      // Duplicate insert (race condition) — treat as success and return existing
      if (dbError.code === '23505') {
        const { data: retry } = await supabase
          .from('roadmaps')
          .select('content')
          .eq('user_id', user.id)
          .maybeSingle();
        return new Response(JSON.stringify(retry?.content ?? content), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      console.error('[generate-roadmap] Supabase INSERT error:', dbError.code, dbError.message, dbError.details);
      return new Response(JSON.stringify({ error: 'Failed to save roadmap' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(content), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch {
    return new Response(JSON.stringify({ error: 'Roadmap generation failed. Please try again.' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};
