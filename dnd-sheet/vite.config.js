import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig({
  // Relative base so the build works when served from a project subpath
  // like https://<user>.github.io/<repo>/ (GitHub Pages).
  base: "./",
  plugins: [react()],
});
