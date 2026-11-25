// Safe bridge between the page and the main process.
// The page can only call the functions listed here.
const { contextBridge, ipcRenderer } = require('electron');

const on = (channel) => (callback) => {
  const handler = (e, data) => callback(data);
  ipcRenderer.on(channel, handler);
  return () => ipcRenderer.removeListener(channel, handler);
};

contextBridge.exposeInMainWorld('volt', {
  // files
  open: () => ipcRenderer.invoke('file:open'),
  openProject: () => ipcRenderer.invoke('project:open'),
  openPath: (p) => ipcRenderer.invoke('file:openPath', p),
  lastFile: () => ipcRenderer.invoke('file:lastFile'),
  save: (opts) => ipcRenderer.invoke('file:save', opts),
  projectFiles: (root) => ipcRenderer.invoke('project:list', { root }),
  readProjectScript: (root, file) => ipcRenderer.invoke('project:readScript', { root, file }),
  writeProjectScript: (root, file, content) => ipcRenderer.invoke('project:writeScript', { root, file, content }),
  createProjectScript: (root, file, content) => ipcRenderer.invoke('project:createScript', { root, file, content }),
  readGameData: (root) => ipcRenderer.invoke('project:readGameData', { root }),
  writeGameData: (root, data) => ipcRenderer.invoke('project:writeGameData', { root, data }),
  projectAssets: (root) => ipcRenderer.invoke('project:listAssets', { root }),
  readProjectAsset: (root, file) => ipcRenderer.invoke('project:readAsset', { root, file }),
  importProjectAssets: (root) => ipcRenderer.invoke('project:importAssets', { root }),
  setDirty: (v) => ipcRenderer.send('app:dirty', v),
  examples: () => ipcRenderer.invoke('examples:list'),
  reference: () => ipcRenderer.invoke('docs:reference'),
  openExternal: (url) => ipcRenderer.invoke('shell:openExternal', url),
  openOutput: (p) => ipcRenderer.invoke('shell:openOutput', p),

  // app
  info: () => ipcRenderer.invoke('app:info'),
  setSettings: (patch) => ipcRenderer.invoke('settings:set', patch),

  // compiler
  compile: (opts) => ipcRenderer.invoke('volt:compile', opts),
  build: (opts) => ipcRenderer.invoke('volt:build', opts),
  upload: (opts) => ipcRenderer.invoke('volt:upload', opts),
  run: (opts) => ipcRenderer.invoke('volt:run', opts),
  stop: () => ipcRenderer.invoke('volt:stop'),
  sendInput: (text) => ipcRenderer.invoke('volt:stdin', text),
  openInBrowser: () => ipcRenderer.invoke('volt:openInBrowser'),
  interpreters: () => ipcRenderer.invoke('tools:interpreters'),

  // boards and tools
  ports: () => ipcRenderer.invoke('ports:list'),
  toolsStatus: () => ipcRenderer.invoke('tools:status'),
  chooseCli: () => ipcRenderer.invoke('tools:chooseCli'),
  installCore: (fqbn) => ipcRenderer.invoke('tools:installCore', fqbn),
  installLib: (name) => ipcRenderer.invoke('tools:installLib', name),

  // serial monitor
  monitorOpen: (opts) => ipcRenderer.invoke('monitor:open', opts),
  monitorClose: () => ipcRenderer.invoke('monitor:close'),
  monitorSend: (text) => ipcRenderer.invoke('monitor:send', text),

  // plugins / addons
  pluginsList: () => ipcRenderer.invoke('plugins:list'),
  pluginsRescan: () => ipcRenderer.invoke('plugins:rescan'),
  pluginsReadFile: (opts) => ipcRenderer.invoke('plugins:readFile', opts),
  pluginsReadAsset: (opts) => ipcRenderer.invoke('plugins:readAsset', opts),
  pluginsListAssets: (opts) => ipcRenderer.invoke('plugins:listAssets', opts),
  pluginsOpenFolder: () => ipcRenderer.invoke('plugins:openFolder'),
  pluginsPanelUrl: (opts) => ipcRenderer.invoke('plugins:panelUrl', opts),

  // AI chat (grounded in the real Volt reference; uses the user's own key)
  aiChat: (messages) => ipcRenderer.invoke('ai:chat', { messages }),
  aiKeyInfo: () => ipcRenderer.invoke('ai:keyInfo'),

  // events from the main process
  onConsole: on('console'),
  onMenu: on('menu'),
  onMonitorData: on('monitor:data'),
  onMonitorState: on('monitor:state'),
  onUploadState: on('upload:state'),
  onRunState: on('run:state'),
  onOpenPath: on('open-path'),
});
