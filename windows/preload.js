const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('cg', {
  init: () => ipcRenderer.invoke('init'),
  setSettings: (p) => ipcRenderer.invoke('set', p),
  resetAnimations: () => ipcRenderer.invoke('reset-anim'),
  onSettings: (cb) => ipcRenderer.on('settings', (_, v) => cb(v)),
  onState: (cb) => ipcRenderer.on('state', (_, v) => cb(v)),
  dragStart: (x, y) => ipcRenderer.send('drag-start', x, y),
  dragMove: (x, y) => ipcRenderer.send('drag-move', x, y),
  menu: () => ipcRenderer.send('menu'),
  openDonate: () => ipcRenderer.send('donate'),
  beep: () => ipcRenderer.send('beep'),
  hooksStatus: () => ipcRenderer.invoke('hooks:status'),
  hooksInstall: () => ipcRenderer.invoke('hooks:install'),
  hooksUninstall: () => ipcRenderer.invoke('hooks:uninstall'),
});
