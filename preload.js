// Preload script - runs in renderer process before page loads
// This allows safe communication between Electron and the web page

const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process
// to use functionality from Electron
contextBridge.exposeInMainWorld('electronAPI', {
  // Add any Electron-specific APIs here if needed
  // For example, file system access, Steam integration, etc.
  
  // Example: Get app version
  getVersion: () => {
    return require('electron').app.getVersion();
  },
  
  // Example: Check if running in Electron
  isElectron: () => {
    return true;
  },
  
  // Quit the application
  quit: () => {
    ipcRenderer.send('app-quit');
  },
  
  // Open external URL in default browser
  openExternal: (url) => {
    ipcRenderer.send('open-external', url);
  }
});


