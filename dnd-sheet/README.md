# ⚔ D&D Character Sheet

A medieval-themed **D&D 5e character sheet** built with React + Vite. Everything
you edit **autosaves to your browser** automatically — close the tab, come back
later, and your character is exactly where you left it. Includes a built-in
**dice roller** with crit/fumble flair and a roll history.

![d20](public/d20.svg)

## Features

- **Five tabs** — Stats, Skills, Combat, Spells, Gear.
- **Tap-to-edit everything** — name, abilities, HP, spells, equipment, notes…
- **Autosave** — every change is written to `localStorage` (debounced). A badge
  in the header shows `✶ Saving` → `✓ Saved`, or `⚠ Not saved` if storage is
  unavailable (e.g. private browsing).
- **Dice roller**
  - Tap any **skill**, **saving throw**, or **ability** to roll `d20 + modifier`
    with an animated result, plus **critical (nat 20)** and **fumble (nat 1)**
    styling.
  - Floating **🎲 dice tray** for raw rolls (d4–d100).
  - **📜 Roll history** drawer, also persisted.
- **HP tracker** with ±1/±5/±10 quick buttons, temp HP, hit dice, and death saves.
- **Reset** button to restore the original sheet.

## Run it locally

```bash
npm install
npm run dev
```

Then open the URL Vite prints (usually <http://localhost:5173>).

## Build for production

```bash
npm run build      # outputs to dist/
npm run preview    # preview the production build locally
```

The `dist/` folder is fully static — deploy it to GitHub Pages, Netlify,
Vercel, Cloudflare Pages, or any static host.

## Where is my data stored?

In your browser's `localStorage` under the keys `dnd-char-arc-elf` (the sheet)
and `dnd-char-arc-elf-rolls` (roll history). It never leaves your device. Using
a different browser or device, or clearing site data, starts a fresh sheet.

## Project structure

```
dnd-sheet/
├── index.html
├── package.json
├── vite.config.js
├── public/
│   └── d20.svg            # favicon
└── src/
    ├── main.jsx           # React entry point
    ├── DnDSheet.jsx       # the whole character sheet + dice roller
    ├── storage.js         # localStorage-backed persistence
    └── index.css          # global styles + animations
```
