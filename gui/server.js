/**
 * OrgAgent GUI Dashboard Server
 * Express.js 5 + WebSocket (ws) + File Watcher (chokidar)
 *
 * Real-time updates: when ANY file in org/ changes, the server pushes
 * a WebSocket event to all connected clients. The dashboard updates instantly.
 */

const express   = require('express');
const path      = require('path');
const http      = require('http');
const { WebSocketServer } = require('ws');
const chokidar  = require('chokidar');

const app  = express();
const PORT = parseInt(process.env.PORT, 10) || 3000;

// ---------------------------------------------------------------------------
// Resolve the org directory (one level up from gui/)
// ---------------------------------------------------------------------------
const orgDir = path.resolve(__dirname, '..', 'org');

// ---------------------------------------------------------------------------
// HTTP Server (shared between Express and WebSocket)
// ---------------------------------------------------------------------------
const server = http.createServer(app);

// ---------------------------------------------------------------------------
// WebSocket Server — real-time push to all connected dashboard clients
// ---------------------------------------------------------------------------
const wss = new WebSocketServer({ server });

const clients = new Set();

wss.on('connection', (ws) => {
  clients.add(ws);
  console.log(`[WS] Client connected (${clients.size} total)`);

  // Send initial connection confirmation
  ws.send(JSON.stringify({ type: 'connected', timestamp: new Date().toISOString() }));

  ws.on('close', () => {
    clients.delete(ws);
    console.log(`[WS] Client disconnected (${clients.size} total)`);
  });

  ws.on('error', (err) => {
    console.error('[WS] Client error:', err.message);
    clients.delete(ws);
  });
});

// Broadcast a message to ALL connected clients
function broadcast(data) {
  const message = JSON.stringify(data);
  for (const client of clients) {
    if (client.readyState === 1) { // WebSocket.OPEN
      client.send(message);
    }
  }
}

// ---------------------------------------------------------------------------
// File Watcher — watch org/ for ANY change, push to WebSocket clients
// ---------------------------------------------------------------------------
let watcherReady = false;

const watcher = chokidar.watch(orgDir, {
  persistent: true,
  ignoreInitial: true,
  depth: 10,
  awaitWriteFinish: { stabilityThreshold: 300, pollInterval: 100 },
  ignored: [
    /(^|[\/\\])\../,        // dotfiles
    '**/node_modules/**',
    '**/.browser-profiles/**'
  ]
});

watcher.on('ready', () => {
  watcherReady = true;
  console.log(`[Watcher] Watching ${orgDir} for changes`);
});

// Determine what CATEGORY of change this is (for targeted UI updates)
function categorize(filePath) {
  const rel = path.relative(orgDir, filePath).replace(/\\/g, '/');

  if (rel.startsWith('threads/'))              return 'threads';
  if (rel.startsWith('board/audit-log'))        return 'audit';
  if (rel.startsWith('board/approvals/'))       return 'approvals';
  if (rel.startsWith('board/decisions/'))        return 'approvals';
  if (rel.startsWith('budgets/'))               return 'budget';
  if (rel.includes('/tasks/'))                  return 'tasks';
  if (rel.includes('/activity/'))               return 'activity';
  if (rel.includes('/inbox/'))                  return 'messages';
  if (rel.includes('/reports/'))                return 'agents';
  if (rel === 'orgchart.md')                    return 'orgchart';
  if (rel.includes('/IDENTITY.md'))             return 'agents';
  if (rel.includes('/SOUL.md'))                 return 'agents';
  if (rel.includes('/current-state.md'))        return 'activity';
  if (rel.startsWith('connectors/'))            return 'connectors';
  if (rel.startsWith('skills/'))                return 'skills';
  return 'general';
}

// On any file change, broadcast to all clients
watcher.on('all', (event, filePath) => {
  if (!watcherReady) return;

  const rel = path.relative(orgDir, filePath).replace(/\\/g, '/');
  const category = categorize(filePath);

  const payload = {
    type: 'file-change',
    event,
    path: rel,
    category,
    timestamp: new Date().toISOString()
  };

  // For activity stream files: read the LAST entry and include it
  // so the live feed can display it immediately without re-fetching
  if (rel.includes('/activity/') && !rel.includes('current-state') && (event === 'change' || event === 'add')) {
    try {
      const fs = require('fs');
      const lines = fs.readFileSync(filePath, 'utf8').split('\n').filter(l => l.startsWith('|') && !l.startsWith('| Time') && !l.startsWith('|---'));
      const lastLine = lines[lines.length - 1];
      if (lastLine) {
        const parts = lastLine.split('|').map(s => s.trim()).filter(Boolean);
        if (parts.length >= 4) {
          // Extract agent name from path: agents/{name}/activity/...
          const agentMatch = rel.match(/agents\/([^/]+)\/activity/);
          const agent = agentMatch ? agentMatch[1] : 'unknown';
          payload.type = 'live-activity';
          payload.agent = agent;
          payload.time = parts[0];
          payload.tool = parts[1];
          payload.action = parts[2];
          payload.target = parts[3];
          payload.summary = parts[4] || '';
        }
      }
    } catch (_) { /* ignore read errors */ }
  }

  // For current-state.md changes: read the status line
  if (rel.includes('current-state.md') && (event === 'change' || event === 'add')) {
    try {
      const fs = require('fs');
      const content = fs.readFileSync(filePath, 'utf8');
      const statusMatch = content.match(/^## Status:?\s*(.+)$/m);
      const agentMatch = rel.match(/agents\/([^/]+)\/activity/);
      if (statusMatch && agentMatch) {
        payload.type = 'agent-status';
        payload.agent = agentMatch[1];
        payload.status = statusMatch[1].trim();
      }
    } catch (_) { /* ignore */ }
  }

  broadcast(payload);
});

// Dedicated watcher for the live feed file — most reliable real-time source
const liveFeedPath = path.join(orgDir, '.live-feed.log');
const feedWatcher = chokidar.watch(liveFeedPath, {
  persistent: true,
  ignoreInitial: true,
  awaitWriteFinish: { stabilityThreshold: 100, pollInterval: 50 }
});

let lastFeedSize = 0;
feedWatcher.on('change', () => {
  try {
    const fs = require('fs');
    const content = fs.readFileSync(liveFeedPath, 'utf8');
    const lines = content.trim().split('\n');

    // Only broadcast NEW lines (lines added since last check)
    const newLines = lines.slice(Math.max(0, lastFeedSize));
    lastFeedSize = lines.length;

    for (const line of newLines) {
      const parts = line.split('|').map(s => s.trim()).filter(Boolean);
      if (parts.length >= 5) {
        broadcast({
          type: 'live-activity',
          timestamp: new Date().toISOString(),
          time: parts[0],
          agent: parts[1],
          tool: parts[2],
          action: parts[3],
          target: parts[4],
          summary: parts[5] || '',
          category: 'activity'
        });
      }
    }
  } catch (_) { /* ignore read errors — file may not exist yet */ }
});

feedWatcher.on('add', () => { lastFeedSize = 0; });

// ---------------------------------------------------------------------------
// Express Middleware
// ---------------------------------------------------------------------------

// JSON body parsing (for POST routes like approvals)
app.use(express.json());

// CORS — allow localhost origins only
app.use((_req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (_req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// Static files (SPA frontend)
app.use(express.static(path.join(__dirname, 'public')));

// ---------------------------------------------------------------------------
// API routes — each module exports (router, orgDir) => void
// ---------------------------------------------------------------------------
const apiRouter = express.Router();

require('./api/orgchart')(apiRouter, orgDir);
require('./api/agents')(apiRouter, orgDir);
require('./api/agent')(apiRouter, orgDir);
require('./api/tasks')(apiRouter, orgDir);
require('./api/messages')(apiRouter, orgDir);
require('./api/budget')(apiRouter, orgDir);
require('./api/audit')(apiRouter, orgDir);
require('./api/approvals')(apiRouter, orgDir);
require('./api/chat')(apiRouter, orgDir);
require('./api/webhooks')(apiRouter, orgDir);

app.use('/api', apiRouter);

// ---------------------------------------------------------------------------
// SPA fallback — serve index.html for any non-API, non-static route
// ---------------------------------------------------------------------------
app.get('/{*splat}', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ---------------------------------------------------------------------------
// Error handling middleware
// ---------------------------------------------------------------------------
app.use((err, _req, res, _next) => {
  console.error('[OrgAgent GUI]', err);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

// ---------------------------------------------------------------------------
// Start server (HTTP + WebSocket on same port)
// ---------------------------------------------------------------------------
server.listen(PORT, '127.0.0.1', () => {
  console.log(`OrgAgent Dashboard running at http://127.0.0.1:${PORT}`);
  console.log(`WebSocket available at ws://127.0.0.1:${PORT}`);
  console.log(`Org directory: ${orgDir}`);
});
