const { app, BrowserWindow, Menu, ipcMain, shell } = require('electron');
const path = require('path');
const fs = require('fs');

// Load Steam configuration
let steamConfig = { appId: 0 };
try {
  const configPath = path.join(__dirname, 'steam-config.json');
  if (fs.existsSync(configPath)) {
    steamConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }
} catch (e) {
  console.log('Could not load steam-config.json:', e.message);
}

// Enable Steam integration if available
let steamworks;
try {
  steamworks = require('steamworks.js');
} catch (e) {
  console.log('Steamworks not available (this is normal for development)');
}

let mainWindow;

function createWindow() {
  // Create the browser window
  mainWindow = new BrowserWindow({
    width: 1920,
    height: 1080,
    minWidth: 1280,
    minHeight: 720,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
      webSecurity: true
    },
    icon: path.join(__dirname, 'icon.png'),
    frame: true,
    titleBarStyle: 'default',
    backgroundColor: '#0a0a0a'
  });

  // Load the game
  mainWindow.loadFile('index.html');

  // Open DevTools in development (remove in production)
  // mainWindow.webContents.openDevTools();

  // Handle window closed
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Handle window resize
  mainWindow.on('resize', () => {
    // Game handles its own scaling
  });

  // Remove menu bar for cleaner look
  Menu.setApplicationMenu(null);
}

// Initialize Steam API if available
function initSteam() {
  if (steamworks && steamConfig.appId > 0) {
    try {
      const client = steamworks.init(steamConfig.appId);
      console.log('Steam initialized with App ID:', steamConfig.appId);
      
      // Expose Steam client to renderer process if needed
      // You can add Steam achievements, stats, etc. here
      // Example:
      // client.achievements.activate('ACHIEVEMENT_ID');
      
      return client;
    } catch (e) {
      console.log('Steam initialization failed:', e);
      console.log('Make sure Steam is running and you have a valid App ID in steam-config.json');
    }
  } else if (steamworks && steamConfig.appId === 0) {
    console.log('Steam App ID not configured. Set your App ID in steam-config.json');
  }
  return null;
}

// App event handlers
app.whenReady().then(() => {
  createWindow();
  initSteam();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Handle quit request from renderer
ipcMain.on('app-quit', () => {
  app.quit();
});

// Handle open external URL request from renderer
ipcMain.on('open-external', (event, url) => {
  shell.openExternal(url);
});

// Handle Steam shutdown
app.on('will-quit', () => {
  if (steamworks) {
    try {
      steamworks.shutdown();
    } catch (e) {
      console.log('Steam shutdown error:', e);
    }
  }
});


