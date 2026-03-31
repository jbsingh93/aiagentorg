/**
 * OrgAgent GUI Dashboard Server
 * Express.js 5 — serves the dark-theme SPA and JSON API routes.
 * Reads the org/ directory (markdown files) and exposes them as REST endpoints.
 */

const express = require('express');
const path    = require('path');

const app  = express();
const PORT = parseInt(process.env.PORT, 10) || 3000;

// ---------------------------------------------------------------------------
// Resolve the org directory (one level up from gui/)
// ---------------------------------------------------------------------------
const orgDir = path.resolve(__dirname, '..', 'org');

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

// JSON body parsing (for POST routes like approvals)
app.use(express.json());

// CORS — allow localhost origins only
app.use((_req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', 'http://localhost:' + PORT);
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
// Start
// ---------------------------------------------------------------------------
app.listen(PORT, '127.0.0.1', () => {
  console.log(`OrgAgent Dashboard running at http://127.0.0.1:${PORT}`);
  console.log(`Org directory: ${orgDir}`);
});
