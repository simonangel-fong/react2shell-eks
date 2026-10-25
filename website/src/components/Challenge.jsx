import { layers, perspectives } from "../data/content";
import Chip from "./Chip";

export default function Challenge() {
  return (
    <section id="challenge" className="mx-auto max-w-6xl px-6 py-20">
      <h2 className="text-section font-bold tracking-tight text-slate-100">
        Security and Business Challenge
      </h2>

      <p className="mt-6 max-w-4xl leading-relaxed">
        AI accelerates application delivery, but security misconfigurations can
        turn a single application flaw into a breach across container, cluster,
        and cloud resources.
      </p>

      <blockquote className="my-8 max-w-4xl border-l-2 border-rose-500 bg-slate-900/60 px-5 py-4">
        <p className="text-lg italic text-slate-100">
          How can teams maintain delivery speed while containing breaches and
          integrating security across all four layers?
        </p>
      </blockquote>

      <p className="max-w-4xl leading-relaxed">
        This project traces a <Chip>React2Shell</Chip> breach on{" "}
        <Chip>Amazon EKS</Chip> and tests the defenses across:
      </p>

      <ul className="mt-6 max-w-4xl space-y-3">
        <li className="flex gap-3">
          <span aria-hidden="true" className="mt-2 h-px w-3 shrink-0 bg-rose-500" />
          <p className="leading-relaxed">
            <span className="font-semibold text-slate-100">Four layers:</span>{" "}
            {layers.join(", ")}.
          </p>
        </li>
        <li className="flex gap-3">
          <span aria-hidden="true" className="mt-2 h-px w-3 shrink-0 bg-rose-500" />
          <p className="leading-relaxed">
            <span className="font-semibold text-slate-100">Four perspectives:</span>{" "}
            {perspectives.join(", ")}.
          </p>
        </li>
      </ul>
    </section>
  );
}
