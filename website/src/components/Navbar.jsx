import { useState } from "react";
import { REPO_URL, stages } from "../data/content";

const links = [
  { id: "challenge", label: "Challenge" },
  ...stages.map((s) => ({ id: s.id, label: s.label })),
];

export default function Navbar({ activeId }) {
  const [open, setOpen] = useState(false);

  return (
    <header className="fixed inset-x-0 top-0 z-30 border-b border-slate-800/70 bg-slate-950/90 backdrop-blur">
      <nav
        aria-label="Main"
        className="mx-auto flex h-16 max-w-6xl items-center gap-6 px-6"
      >
        <a href="#top" className="flex items-center gap-2.5">
          <img src="/icon.png" alt="" width="38" height="38" className="rounded" />
          <span className="font-semibold text-slate-100">React2Shell·EKS</span>
        </a>

        <ul className="ml-auto hidden items-center gap-6 md:flex">
          {links.map((l) => (
            <li key={l.id}>
              <a
                href={`#${l.id}`}
                aria-current={activeId === l.id ? "true" : undefined}
                className={`text-sm transition-colors ${
                  activeId === l.id ? "text-slate-100" : "text-slate-400 hover:text-slate-100"
                }`}
              >
                {l.label}
              </a>
            </li>
          ))}
          <li>
            <a
              href={REPO_URL}
              className="rounded border border-slate-800 bg-slate-900 px-3.5 py-1.5 text-sm font-medium text-slate-100 transition-colors hover:border-slate-400"
            >
              GitHub
            </a>
          </li>
        </ul>

        <button
          type="button"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          aria-controls="mobile-nav"
          className="ml-auto text-sm text-slate-400 md:hidden"
        >
          {open ? "Close" : "Menu"}
        </button>
      </nav>

      {open && (
        <ul id="mobile-nav" className="border-t border-slate-800/70 px-6 pb-4 pt-2 md:hidden">
          {links.map((l) => (
            <li key={l.id}>
              <a
                href={`#${l.id}`}
                onClick={() => setOpen(false)}
                className="block py-2.5 text-sm text-slate-400"
              >
                {l.label}
              </a>
            </li>
          ))}
          <li>
            <a href={REPO_URL} className="block py-2.5 text-sm text-rose-400">
              GitHub
            </a>
          </li>
        </ul>
      )}
    </header>
  );
}
