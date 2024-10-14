/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  images: {
    domains: [process.env.PROCESSED_BUCKET_DOMAIN],
  },
};

export default nextConfig;
