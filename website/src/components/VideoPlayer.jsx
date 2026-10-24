/**
 * Demo recording, served from S3 behind CloudFront rather than bundled. With
 * no base URL configured the player states that instead of rendering broken.
 */
export default function VideoPlayer({ src, label }) {
  if (!src) {
    return (
      <div className="flex aspect-video w-full items-center justify-center rounded border border-dashed border-slate-800 bg-slate-900/40 px-6 text-center">
        <p className="font-mono text-sm text-slate-400">
          Recording not configured
          <span className="mt-1 block text-xs text-slate-700">
            Set VITE_VIDEO_BASE_URL to the CloudFront distribution
          </span>
        </p>
      </div>
    );
  }

  return (
    <video
      controls
      preload="none"
      playsInline
      aria-label={label}
      className="aspect-video w-full rounded border border-slate-800 bg-black"
    >
      <source src={src} type="video/mp4" />
      Your browser cannot play this recording.{" "}
      <a href={src} className="underline">
        Download it instead
      </a>
      .
    </video>
  );
}
