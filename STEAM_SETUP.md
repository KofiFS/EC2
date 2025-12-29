# Steam Setup Guide for Bubble Squash Game

## Overview
This guide will help you package your HTML5 game for Steam using Electron.

## Prerequisites

1. **Steam Partner Account**: You need a Steam Partner account ($100 one-time fee)
2. **Node.js**: Install Node.js (v18 or later) from https://nodejs.org/
3. **Steam App ID**: You'll get this when you create your game on Steam

## Step 1: Install Dependencies

```bash
npm install
```

## Step 2: Download PeerJS Locally (Important!)

Since your game uses PeerJS from a CDN, you should download it locally for the desktop version:

1. Download PeerJS: https://unpkg.com/peerjs@1.4.7/dist/peerjs.min.js
2. Save it as `peerjs.min.js` in your project folder
3. Update `index.html` line 7 to use local file:
   ```html
   <script src="./peerjs.min.js"></script>
   ```

## Step 3: Test Locally

```bash
npm start
```

This will open your game in an Electron window. Test everything works!

## Step 4: Build for Distribution

### Windows:
```bash
npm run build-win
```

### Mac:
```bash
npm run build-mac
```

### Linux:
```bash
npm run build-linux
```

Builds will be in the `dist` folder.

## Step 5: Steam Integration

### Install Steamworks.js (Optional but Recommended)

```bash
npm install steamworks.js --save
```

Then update `main.js` with your Steam App ID (you'll get this from Steam).

### Steam Features You Can Add:

1. **Achievements**: Track player achievements
2. **Leaderboards**: Global leaderboards for spike dodge scores
3. **Cloud Saves**: Save player rankings to Steam Cloud
4. **Steam Overlay**: In-game overlay support

## Step 6: Steam Submission Process

1. **Create Steam App**: Go to Steam Partner portal
2. **Upload Build**: Use SteamCMD or Steamworks SDK to upload your build
3. **Set Store Page**: Create store page with screenshots, description, etc.
4. **Set Price**: Set to "Free" for a free game
5. **Submit for Review**: Steam will review your game

## Important Notes:

### For Your Game Specifically:

1. **PeerJS**: The multiplayer uses PeerJS which requires internet. This will work fine in Electron.

2. **localStorage**: Your rankings use localStorage, which works in Electron. Consider adding Steam Cloud saves later.

3. **Window Size**: The game is set to 1920x1080 but scales. You may want to make it fullscreen by default:
   ```javascript
   mainWindow.setFullScreen(true);
   ```

4. **External Links**: The "HomePage" button navigates away. In Electron, you might want to open in external browser:
   ```javascript
   const { shell } = require('electron');
   shell.openExternal('https://www.shangkostudio.com/');
   ```

## Troubleshooting

### Game doesn't load:
- Check that `index.html` is in the same folder as `main.js`
- Check browser console (DevTools) for errors

### Multiplayer doesn't work:
- PeerJS should work fine in Electron
- Make sure internet connection is available

### Build fails:
- Make sure all dependencies are installed: `npm install`
- Check that you have the correct build tools for your platform

## Next Steps:

1. Create icons (icon.ico, icon.icns, icon.png) for your game
2. Update package.json with your actual app details
3. Test thoroughly on target platforms
4. Set up Steam store page
5. Submit to Steam!

## Resources:

- Electron Docs: https://www.electronjs.org/docs
- Electron Builder: https://www.electron.build/
- Steamworks Documentation: https://partner.steamgames.com/doc/home
- Steamworks.js: https://github.com/liamcottle/steamworks.js

Good luck with your Steam release! 🎮

