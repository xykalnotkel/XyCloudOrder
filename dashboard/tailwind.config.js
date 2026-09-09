/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        xy: {
          bg: "#100030",
          bg2: "#200050",
          violet: "#7C3AED",
          violet2: "#8B5CF6",
          violet3: "#A855F7",
          indigo: "#7830C0",
          card: "#1A0A3A",
          border: "rgba(124,58,237,0.22)",
        },
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(124,58,237,0.18), 0 8px 32px rgba(124,58,237,0.18)",
        glow2: "0 0 0 1px rgba(124,58,237,0.28), 0 12px 40px rgba(124,58,237,0.32)",
      },
      backgroundImage: {
        "xy-gradient": "linear-gradient(135deg,#100030 0%,#200050 35%,#2D0A5E 55%,#7C3AED 100%)",
        "xy-card": "linear-gradient(135deg,rgba(26,10,58,0.96),rgba(45,10,94,0.92))",
        "xy-btn": "linear-gradient(135deg,#7C3AED 0%,#8B5CF6 45%,#A855F7 100%)",
      },
    },
  },
  plugins: [],
};
