/**
 * Demo recording, served from the site bucket behind CloudFront. The native
 * controls carry play, seek and volume; nothing autoplays and the audio is
 * left at the viewer's own volume.
 */
export default function VideoPlayer({ src, label }) {
  return (
    <video
      controls
      preload="metadata"
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
