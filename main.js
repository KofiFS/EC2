const { app, BrowserWindow, Menu } = require('electron');
const path = require('path');

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

  // Remove menu bar for cleaner look (optional)
  // Menu.setApplicationMenu(null);
}

// Initialize Steam API if available
function initSteam() {
  if (steamworks) {
    try {
      const client = steamworks.init(480); // Replace with your Steam App ID
      console.log('Steam initialized:', client);
      
      // You can add Steam achievements, stats, etc. here
      // Example:
      // client.achievements.activate('ACHIEVEMENT_ID');
    } catch (e) {
      console.log('Steam initialization failed:', e);
    }
  }
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

