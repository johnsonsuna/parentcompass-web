import { useEffect, useState } from 'react';

type Status = 'loading' | 'error';

export default function RoadmapLoader() {
  const [status, setStatus] = useState<Status>('loading');

  useEffect(() => {
    fetch('/api/generate-roadmap', { method: 'POST' })
      .then((res) => {
        if (res.ok) {
          window.location.reload();
        } else {
          setStatus('error');
        }
      })
      .catch(() => setStatus('error'));
  }, []);

  if (status === 'error') {
    return (
      <div className="bg-red-50 border border-red-200 rounded-2xl p-8 text-center max-w-lg mx-auto">
        <p className="text-red-700 text-sm font-sans">
          Roadmap generation failed. Please refresh the page to try again.
        </p>
      </div>
    );
  }

  return (
    <div className="text-center py-16">
      <div className="inline-flex items-center gap-3 text-stone-500">
        <svg
          className="animate-spin h-5 w-5 text-terra-500"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          aria-hidden="true"
        >
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
          />
        </svg>
        <span className="text-sm font-sans">Building your personalised roadmap…</span>
      </div>
      <p className="text-stone-400 text-xs font-sans mt-3">This takes about 10–15 seconds.</p>
    </div>
  );
}
