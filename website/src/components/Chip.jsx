/** Inline technical term — a product name, a resource, a CVE. */
export default function Chip({ children }) {
  return (
    <code className="whitespace-nowrap rounded bg-rose-500/10 px-1.5 py-0.5 font-mono text-[0.92em] text-rose-400">
      {children}
    </code>
  );
}
