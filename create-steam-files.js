/**
 * Helper script to create Steam deployment files
 * Run this after building: node create-steam-files.js
 */

const fs = require('fs');
const path = require('path');

// Load Steam config
let steamConfig = { appId: 0 };
try {
  const configPath = path.join(__dirname, 'steam-config.json');
  if (fs.existsSync(configPath)) {
    steamConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }
} catch (e) {
  console.error('Error reading steam-config.json:', e.message);
  process.exit(1);
}

if (steamConfig.appId === 0) {
  console.error('❌ Error: Steam App ID not set in steam-config.json');
  console.log('Please set your App ID in steam-config.json first!');
  process.exit(1);
}

// Find the build directory
const distPath = path.join(__dirname, 'dist');
const winUnpackedPath = path.join(distPath, 'win-unpacked');

if (!fs.existsSync(winUnpackedPath)) {
  console.error('❌ Error: Build directory not found!');
  console.log('Please run "npm run build-steam" first to create the build.');
  process.exit(1);
}

// Create steam_appid.txt
const steamAppIdPath = path.join(winUnpackedPath, 'steam_appid.txt');
fs.writeFileSync(steamAppIdPath, steamConfig.appId.toString(), 'utf8');
console.log('✅ Created steam_appid.txt with App ID:', steamConfig.appId);

// Check if steam_api64.dll exists
const steamDllPath = path.join(winUnpackedPath, 'steam_api64.dll');
if (!fs.existsSync(steamDllPath)) {
  console.log('');
  console.log('⚠️  Warning: steam_api64.dll not found!');
  console.log('You need to copy steam_api64.dll from Steamworks SDK to:');
  console.log(winUnpackedPath);
  console.log('');
  console.log('Location in Steamworks SDK:');
  console.log('  redistributable_bin\\win64\\steam_api64.dll');
} else {
  console.log('✅ Found steam_api64.dll');
}

console.log('');
console.log('✅ Steam files ready!');
console.log('Build location:', winUnpackedPath);
