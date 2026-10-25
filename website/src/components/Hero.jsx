import { REPO_URL } from "../data/content";
import Chip from "./Chip";

export default function Hero() {
  return (
    <section id="top" className="relative isolate overflow-hidden">
      {/* The figure sits right of centre, so the copy takes the clear left
          field. The photograph is already dark: no darkening wash over the
          subject, only a soft scrim on the left to hold the text. */}
      {/* A 16:9 photo cropped to a portrait viewport always lands the figure
          behind the copy, so on small screens it occupies the lower half and
          the text sits on solid ground above it. From lg the figure has its
          own column on the right and the copy takes the clear left field. */}
      <img
        src="/hero.jpg"
        alt=""
        aria-hidden="true"
        fetchPriority="high"
        className="absolute inset-x-0 bottom-0 -z-20 h-[55%] w-full object-cover object-[75%_center] lg:inset-0 lg:h-full lg:object-right"
      />
      <div
        aria-hidden="true"
        className="absolute inset-0 -z-10 bg-gradient-to-b from-slate-950 via-slate-950/70 to-slate-950/25 lg:bg-gradient-to-r lg:from-slate-950/80 lg:via-slate-950/45 lg:to-transparent"
      />
      <div
        aria-hidden="true"
        className="absolute inset-x-0 bottom-0 -z-10 h-28 bg-gradient-to-b from-transparent to-slate-950"
      />

      <div className="mx-auto flex min-h-[34rem] max-w-6xl items-center px-6 py-24 lg:min-h-[42rem]">
        <div className="w-full max-w-xl lg:max-w-xl">
          <p className="font-mono text-sm text-rose-400">CVE-2025-55182</p>

          <h1 className="mt-4 text-hero font-bold leading-[1.08] tracking-tight text-slate-100">
            React2Shell on Amazon EKS
          </h1>

          <p className="mt-5 text-lg leading-7 text-slate-400">
            One vulnerability. Four layers.
            <br />
            Attack, Respond, Harden, Integrate.
          </p>

          <p className="mt-5 leading-relaxed">
            A Kubernetes security project that exploits{" "}
            <Chip>React2Shell</Chip> in a <Chip>Next.js</Chip> application on{" "}
            <Chip>Amazon EKS</Chip>, investigates the breach, tests layered
            defenses, and integrates security into delivery.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <a
              href="#attack"
              className="rounded border border-rose-500 px-5 py-2.5 text-sm font-semibold text-rose-400 transition-colors hover:bg-rose-500 hover:text-white"
            >
              Watch the breach
            </a>
            <a
              href={REPO_URL}
              className="rounded border border-slate-800 bg-slate-900/70 px-5 py-2.5 text-sm font-medium text-slate-100 transition-colors hover:border-slate-400"
            >
              GitHub repository
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
