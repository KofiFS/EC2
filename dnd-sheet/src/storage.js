// ──────────────────────────────────────────────────────────────────────────
// Local persistence layer.
//
// The original component talked to `window.storage`, a custom API that only
// exists inside Claude's artifact sandbox. In a real browser that object is
// undefined, so nothing was ever actually saved. This module provides the same
// tiny get/set surface backed by the browser's real `localStorage`, so the
// sheet autosaves and survives reloads, tab closes, and restarts.
// ──────────────────────────────────────────────────────────────────────────

export const storage = {
  get(key) {
    try {
      const value = localStorage.getItem(key);
      return value === null ? null : { value };
    } catch {
      return null;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, value);
      return true;
    } catch {
      // Storage can throw if it's full or disabled (private mode, etc.)
      return false;
    }
  },
  remove(key) {
    try {
      localStorage.removeItem(key);
    } catch {
      /* ignore */
    }
  },
};
