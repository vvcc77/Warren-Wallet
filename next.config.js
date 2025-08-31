/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true
  // Si luego querés mover headers desde vercel.json:
  // async headers() {
  //   return [
  //     {
  //       source: '/(.*)',
  //       headers: [
  //         { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  //         { key: 'X-Content-Type-Options', value: 'nosniff' },
  //         { key: 'X-Frame-Options', value: 'DENY' },
  //         { key: 'Referrer-Policy', value: 'no-referrer' },
  //         { key: 'Permissions-Policy', value: 'geolocation=(), microphone=(), camera=()' }
  //       ]
  //     }
  //   ];
  // },
};

module.exports = nextConfig;
