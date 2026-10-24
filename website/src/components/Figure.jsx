/**
 * A diagram or screenshot. Fine detail is unreadable at phone width, so the
 * frame links to the full-size image. `webp` is optional: photographic art and
 * diagrams compress well as WebP, sharp-edged terminal captures do not.
 */
export default function Figure({ src, webp, width, height, alt, caption }) {
  return (
    <figure>
      <a
        href={src}
        target="_blank"
        rel="noreferrer"
        className="group block overflow-hidden rounded border border-slate-800 transition-colors hover:border-slate-400"
      >
        <picture>
          {webp && <source srcSet={webp} type="image/webp" />}
          <img
            src={src}
            width={width}
            height={height}
            alt={alt}
            loading="lazy"
            decoding="async"
            className="h-auto w-full"
          />
        </picture>
      </a>
      {caption && (
        <figcaption className="mt-3 text-sm text-slate-400">{caption}</figcaption>
      )}
    </figure>
  );
}
