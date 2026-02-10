module.exports = {
  // Port UI (ok)
  uiPort: 1880,

  // IMPORTANT: répertoire persistant HA (volume)
  userDir: "/data",

  // Ton fichier de flows (tu peux garder flows.json si tu préfères)
  flowFile: "flows.json",

  // IMPORTANT: charge aussi les nodes installés dans l'image (ex: serialport)
  nodesDir: [
    "/opt/node_modules"
  ],

  editorTheme: {
    projects: { enabled: false }
  }
};
