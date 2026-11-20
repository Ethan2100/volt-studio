'use strict';

const { app, BrowserWindow, ipcMain } = require('electron');
const fs = require('fs');
const path = require('path');

app.commandLine.appendSwitch('autoplay-policy', 'no-user-gesture-required');
app.disableHardwareAcceleration();
const profile = path.resolve(__dirname, '../../dist/world-studio-intro-profile');
fs.mkdirSync(path.join(profile, 'Cache'), { recursive: true });
app.setPath('userData', profile);
app.setPath('cache', path.join(profile, 'Cache'));
let mainWindow;
app.on('before-quit', () => console.log('Renderer app is quitting'));

app.whenReady().then(() => {
  console.log('Starting World Studio video renderer');
  ipcMain.once('recording-done', (_event, details) => {
    console.log('Video metadata:', JSON.stringify(details));
    app.quit();
  });
  ipcMain.once('recording-failed', (_event, message) => {
    console.error(message);
    app.exit(1);
  });
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 720,
    show: true,
    backgroundColor: '#090d14',
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      sandbox: false,
      backgroundThrottling: false,
    },
  });
  mainWindow.on('closed', () => console.log('Renderer window closed'));
  mainWindow.webContents.on('did-fail-load', (_event, code, description) => console.error('Page load failed:', code, description));
  mainWindow.webContents.on('console-message', event => console.log('Renderer:', event.message));
  mainWindow.webContents.on('render-process-gone', (_event, details) => console.error('Renderer process ended:', details.reason));
  mainWindow.webContents.once('did-finish-load', () => {
    console.log('Renderer page loaded');
    mainWindow.webContents.executeJavaScript('start()').catch(error => console.error('Could not start render:', error));
  });
  mainWindow.loadFile(path.join(__dirname, 'renderer.html'));
});
