import { useEffect, useRef, useState } from "react";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Challenge from "./components/Challenge";
import Stage from "./components/Stage";
import Footer from "./components/Footer";
import { stages } from "./data/content";

export default function App() {
  const [activeId, setActiveId] = useState(null);
  const observed = useRef([]);

  // Highlight the nav link for whichever section holds the upper viewport.
  useEffect(() => {
    const els = ["challenge", ...stages.map((s) => s.id)]
      .map((id) => document.getElementById(id))
      .filter(Boolean);
    observed.current = els;

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort(
            (a, b) => a.boundingClientRect.top - b.boundingClientRect.top,
          )[0];
        if (visible) setActiveId(visible.target.id);
      },
      { rootMargin: "-20% 0px -65% 0px" },
    );

    els.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, []);

  return (
    <>
      <a
        href="#challenge"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded focus:bg-slate-100 focus:px-4 focus:py-2 focus:text-sm focus:text-slate-950"
      >
        Skip to content
      </a>

      <Navbar activeId={activeId} />

      <main>
        <Hero />
        <Challenge />
        {stages.map((stage) => (
          <Stage key={stage.id} stage={stage} />
        ))}
      </main>

      <Footer />
    </>
  );
}
