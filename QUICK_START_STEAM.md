# Quick Start: Steam Release Setup

## ✅ Already Done
- ✅ `steamworks.js` installed
- ✅ Steam configuration file created
- ✅ Build scripts configured
- ✅ Main.js updated for Steam integration

## 🚀 Next Steps (5 minutes)

### 1. Get Your Steam App ID
- Log into Steam Partner portal: https://partner.steamgames.com/
- Create your app (if you haven't already)
- Copy your App ID (it's a number like `1234560`)

### 2. Configure App ID
Open `steam-config.json` and replace `0` with your App ID:
```json
{
  "appId": 1234560,
  "description": "Steam configuration for Bubble Squash Game"
}
```

### 3. Test Locally
```bash
npm start
```
Make sure Steam client is running, then check console for "Steam initialized" message.

### 4. Build for Steam
```bash
npm run build-steam
```

### 5. Prepare Steam Files
```bash
npm run prepare-steam
```
This creates `steam_appid.txt` automatically.

### 6. Add Steam DLL
Copy `steam_api64.dll` from Steamworks SDK to:
```
dist\win-unpacked\steam_api64.dll
```

### 7. Upload to Steam
Follow the detailed guide in `STEAM_DEPLOYMENT.md` for complete instructions.

## 📚 Full Documentation
- **Setup Guide**: `STEAM_SETUP.md` - General setup and testing
- **Deployment Guide**: `STEAM_DEPLOYMENT.md` - Complete deployment walkthrough

## 🎮 Ready to Build?
```bash
npm run build-steam
```
