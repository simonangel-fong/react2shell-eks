/** @type {import('next').NextConfig} */
const nextConfig = {
  /* config options here */
  cacheComponents: true,
  partialPrefetching: true,
  // self-contained prod server: minimal runtime, no dev deps shipped
  output: "standalone",
};

export default nextConfig;
