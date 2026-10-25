import Figure from "./Figure";
import VideoPlayer from "./VideoPlayer";

const TONE = {
  breach: "text-rose-500",
  signal: "text-sky-400",
};

/**
 * Renders body copy, colouring the stage's key term to match its heading so the
 * name reads as the same thing in both places.
 */
function Body({ text, term, tone }) {
  if (!term || !text.includes(term)) return text;

  return text.split(term).flatMap((part, i) =>
    i === 0
      ? [part]
      : [
          <span key={i} className={`font-medium ${TONE[tone]}`}>
            {term}
          </span>,
          part,
        ],
  );
}

export default function Stage({ stage }) {
  const { id, label, tone, heading, lead, body, term, videoUrl, figure } =
    stage;

  return (
    <section
      id={id}
      aria-labelledby={`${id}-heading`}
      className="border-t border-slate-800/70"
    >
      <div className="mx-auto max-w-6xl px-6 py-20">
        <h2
          id={`${id}-heading`}
          className="text-section font-bold tracking-tight text-slate-100"
        >
          <span className={TONE[tone]}>{label}</span>
          <span className="text-slate-400"> — </span>
          <Body text={heading} term={term} tone={tone} />
        </h2>

        <p className="mt-6 max-w-4xl leading-relaxed">
          <Body text={lead} term={term} tone={tone} />
        </p>
        <p className="mt-4 max-w-4xl leading-relaxed">
          <Body text={body} term={term} tone={tone} />
        </p>

        {figure && (
          <div className="mt-9 max-w-4xl">
            <Figure {...figure} />
          </div>
        )}

        {videoUrl && (
          <div className="mt-9 max-w-4xl">
            <VideoPlayer src={videoUrl} label={`${label} demo recording`} />
          </div>
        )}
      </div>
    </section>
  );
}
