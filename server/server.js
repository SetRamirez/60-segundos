// Servidor local de "60 segundos".
// - Sirve la página de los celulares (carpeta public/).
// - /ws   -> WebSocket de los jugadores (celulares).
// - /host -> WebSocket de Godot (solo acepta conexiones desde esta misma máquina).
const http = require('http');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT) || 3000;
const MAX_PER_TEAM = 20;

const app = express();
app.use(express.static(path.join(__dirname, 'public')));
const server = http.createServer(app);
const wss = new WebSocketServer({ noServer: true });

let host = null;            // socket de Godot
const players = new Map();  // id -> { id, name, team, ws }

const send = (ws, obj) => { if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj)); };
const parse = raw => { try { return JSON.parse(raw.toString()); } catch { return null; } };
const view = p => ({ id: p.id, name: p.name, team: p.team });
const teamCount = t => [...players.values()].filter(p => p.team === t).length;
const sockets = new Set();   // todos los celulares conectados (hayan entrado o no)
const counts = () => ({ type: 'counts', teams: { 1: teamCount(1), 2: teamCount(2) }, max: MAX_PER_TEAM });
const broadcastCounts = () => sockets.forEach(s => send(s, counts()));
const isLocal = addr => ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(addr);

function lanUrl() {
  for (const list of Object.values(os.networkInterfaces())) {
    for (const i of list || []) {
      if ((i.family === 'IPv4' || i.family === 4) && !i.internal) return `http://${i.address}:${PORT}`;
    }
  }
  return `http://localhost:${PORT}`;
}

server.on('upgrade', (req, socket, head) => {
  const role = req.url === '/host' ? 'host' : req.url === '/ws' ? 'player' : null;
  if (!role || (role === 'host' && !isLocal(req.socket.remoteAddress))) return socket.destroy();
  wss.handleUpgrade(req, socket, head, ws => wss.emit('connection', ws, role));
});

wss.on('connection', (ws, role) => (role === 'host' ? onHost(ws) : onPlayer(ws)));

function onHost(ws) {
  if (host && host !== ws) host.close();
  host = ws;
  send(ws, { type: 'info', url: lanUrl() });
  send(ws, { type: 'roster', players: [...players.values()].map(view) });

  ws.on('message', raw => {
    const msg = parse(raw);
    if (!msg) return;
    if (msg.type === 'send') {                       // Godot -> un jugador
      const p = players.get(msg.id);
      if (p) send(p.ws, msg.data);
    } else if (msg.type === 'broadcast') {           // Godot -> todos los jugadores
      for (const p of players.values()) send(p.ws, msg.data);
    }
  });
  ws.on('close', () => { if (host === ws) host = null; });
}

function onPlayer(ws) {
  let me = null;
  sockets.add(ws);
  send(ws, counts());

  const remove = () => {
    if (me && players.get(me.id) === me) {
      players.delete(me.id);
      send(host, { type: 'player_left', id: me.id });
      broadcastCounts();
    }
  };

  ws.on('message', raw => {
    const msg = parse(raw);
    if (!msg) return;

    if (msg.type === 'join') {
      if (me) return;
      const name = String(msg.name || '').trim().slice(0, 16);
      if (!name) return send(ws, { type: 'error', message: 'Escribe tu nombre.' });

      const id = /^[a-f0-9]{12}$/.test(msg.id) ? msg.id : crypto.randomBytes(6).toString('hex');
      const old = players.get(id);
      if (old) {                                      // el jugador recargó la página
        if (old.ws !== ws) { try { old.ws.close(); } catch {} }
        old.ws = ws;
        me = old;
        return send(ws, { type: 'joined', ...view(me) });
      }

      const team = Number(msg.team);
      if (team !== 1 && team !== 2) return send(ws, { type: 'error', message: 'Elige un equipo.' });
      if (teamCount(team) >= MAX_PER_TEAM) {
        return send(ws, { type: 'error', message: 'Ese equipo está lleno.' });
      }
      me = { id, name, team, ws };
      players.set(id, me);
      send(ws, { type: 'joined', ...view(me) });
      send(host, { type: 'player_joined', ...view(me) });
      broadcastCounts();
      return;
    }

    if (!me) return;
    if (msg.type === 'leave') {
      remove();
      me = null;
      return send(ws, { type: 'left' });
    }
    send(host, { type: 'player_message', id: me.id, data: msg }); // jugador -> Godot
  });

  ws.on('close', () => {
    sockets.delete(ws);
    if (me && me.ws === ws) remove();
  });
}

server.listen(PORT, '0.0.0.0', () => {
  console.log('Servidor de 60 segundos listo.');
  console.log(`Los jugadores entran desde: ${lanUrl()}`);
});
