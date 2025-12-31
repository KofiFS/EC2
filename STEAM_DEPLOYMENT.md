# Steam Deployment Guide for Bubble Squash

This guide walks you through deploying your Electron game to Steam.

## Prerequisites

1. **Steam Partner Account** ($100 one-time fee)
   - Sign up at: https://partner.steamgames.com/
   - Complete the paperwork and payment

2. **Steam App ID**
   - After creating your app in Steam Partner portal, you'll receive an App ID
   - Update `steam-config.json` with your App ID

3. **Steamworks SDK**
   - Download from: https://partner.steamgames.com/downloads/steamworks_sdk.zip
   - Extract to a location you'll remember (e.g., `C:\SteamworksSDK\`)

## Step 1: Configure Your Steam App ID

1. Open `steam-config.json`
2. Replace `"appId": 0` with your actual Steam App ID
   ```json
   {
     "appId": 1234560,
     "description": "Steam configuration for Bubble Squash Game"
   }
   ```

## Step 2: Test Locally (Without Steam)

```bash
npm start
```

This will run your game in Electron. Test that everything works!

## Step 3: Test with Steam (Optional)

1. Make sure Steam client is running
2. Make sure you have your App ID set in `steam-config.json`
3. Run:
   ```bash
   npm start
   ```
4. Check the console for "Steam initialized" message

## Step 4: Build for Steam

Build your game for Windows (Steam's primary platform):

```bash
npm run build-steam
```

This creates a distributable build in the `dist` folder.

## Step 5: Prepare Steam Build

### Option A: Using SteamCMD (Recommended for Automated Builds)

1. Download SteamCMD: https://developer.valvesoftware.com/wiki/SteamCMD
2. Extract to a folder (e.g., `C:\SteamCMD\`)
3. Create a build script or use Steam Partner portal

### Option B: Using Steam Partner Portal (Easier for First Time)

1. Log into Steam Partner portal
2. Go to your app's "Installation" section
3. Upload your build from the `dist` folder
4. Steam will handle the rest

## Step 6: Steam Build Requirements

Your build must include:

1. **Executable**: The main `.exe` file from your Electron build
2. **Steamworks DLL**: Copy `steam_api64.dll` from Steamworks SDK to your build folder
   - Location: `SteamworksSDK\redistributable_bin\win64\steam_api64.dll`
3. **steam_appid.txt**: Create this file in your build root with your App ID
   - Example: `steam_appid.txt` containing just `1234560`

## Step 7: Create steam_appid.txt

After building, create `steam_appid.txt` in your dist folder:

1. Navigate to `dist\win-unpacked\` (or wherever your exe is)
2. Create a file named `steam_appid.txt`
3. Put only your App ID number in it (no quotes, no extra text)

## Step 8: Copy Steamworks DLL

1. Copy `steam_api64.dll` from Steamworks SDK to your build folder
2. It should be in the same folder as your `.exe` file

## Step 9: Upload to Steam

1. Use Steam Partner portal to upload your build
2. Or use SteamCMD for automated uploads
3. Set up your store page (screenshots, description, etc.)
4. Submit for review

## Important Files Structure

After building, your Steam-ready folder should look like:
```
dist/
└── win-unpacked/
    ├── Bubble Squash.exe
    ├── steam_api64.dll
    ├── steam_appid.txt
    ├── resources/
    │   ├── app.asar (or unpacked files)
    │   └── ...
    └── ... (other Electron files)
```

## Steam Features You Can Implement

### Achievements
```javascript
// In main.js after Steam init
if (steamClient) {
  steamClient.achievements.activate('ACHIEVEMENT_ID');
}
```

### Leaderboards
```javascript
if (steamClient) {
  steamClient.leaderboards.uploadScore('LEADERBOARD_ID', score);
}
```

### Cloud Saves
```javascript
if (steamClient) {
  const saveData = steamClient.cloud.readFile('save.json');
  // Use saveData
}
```

## Troubleshooting

### "Steam initialization failed"
- Make sure Steam client is running
- Verify your App ID in `steam-config.json` is correct
- Check that `steamworks.js` is installed: `npm list steamworks.js`

### Build doesn't include Steam files
- Check `package.json` includes `steamworks.js` in files array
- Rebuild: `npm run build-steam`

### Game crashes on Steam
- Make sure `steam_api64.dll` is in the same folder as your exe
- Verify `steam_appid.txt` exists and has correct App ID
- Check Steam client is running

## Next Steps

1. ✅ Set your Steam App ID in `steam-config.json`
2. ✅ Build your game: `npm run build-steam`
3. ✅ Add `steam_api64.dll` to build folder
4. ✅ Create `steam_appid.txt` with your App ID
5. ✅ Upload to Steam Partner portal
6. ✅ Set up store page
7. ✅ Submit for review

## Resources

- Steam Partner Portal: https://partner.steamgames.com/
- Steamworks Documentation: https://partner.steamgames.com/doc/home
- Steamworks.js GitHub: https://github.com/liamcottle/steamworks.js
- Electron Builder: https://www.electron.build/

Good luck with your Steam release! 🎮
