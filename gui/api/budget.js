/**
 * GET /api/budget
 * Reads org/config.md (currency), org/budgets/overview.md, org/budgets/spending-log.md
 * Returns a unified budget summary.
 */

const fs     = require('fs');
const path   = require('path');
const matter = require('gray-matter');

/** Parse a markdown table (pipe-delimited) into an array of row objects. */
function parseTable(content) {
  const lines = content.split('\n')
    .map(l => l.trim())
    .filter(l => l.startsWith('|'));

  if (lines.length < 2) return [];

  // First row = headers
  const headers = lines[0].split('|').map(h => h.trim()).filter(Boolean);

  // Skip separator row (second line)
  const rows = [];
  for (let i = 2; i < lines.length; i++) {
    const cells = lines[i].split('|').map(c => c.trim()).filter(Boolean);
    if (cells.length === 0) continue;
    const row = {};
    headers.forEach((h, idx) => {
      row[h.toLowerCase().replace(/[^a-z0-9]+/g, '_')] = cells[idx] || '';
    });
    rows.push(row);
  }
  return rows;
}

/** Strip currency symbols and parse as float. */
function parseCurrency(val) {
  if (typeof val === 'number') return val;
  if (!val) return 0;
  return parseFloat(String(val).replace(/[^0-9.\-]/g, '')) || 0;
}

module.exports = function (router, orgDir) {
  router.get('/budget', (_req, res, next) => {
    try {
      // --- Currency from config ---
      let currency = 'USD';
      const configPath = path.join(orgDir, 'config.md');
      if (fs.existsSync(configPath)) {
        try {
          const cfg = matter(fs.readFileSync(configPath, 'utf-8'));
          currency = cfg.data.currency || cfg.data.language === 'da' ? 'DKK' : 'USD';
          if (cfg.data.currency) currency = cfg.data.currency;
        } catch (_e) { /* keep default */ }
      }

      // --- Budget overview ---
      let total     = 0;
      let allocated = 0;
      let spent     = 0;
      let remaining = 0;
      let agents    = [];
      const overviewPath = path.join(orgDir, 'budgets', 'overview.md');
      if (fs.existsSync(overviewPath)) {
        try {
          const raw    = fs.readFileSync(overviewPath, 'utf-8');
          const parsed = matter(raw);
          const data   = parsed.data || {};

          total     = parseCurrency(data.total_budget_usd)     || 0;
          allocated = parseCurrency(data.total_allocated_usd)  || 0;
          spent     = parseCurrency(data.total_spent_usd)      || 0;
          remaining = parseCurrency(data.total_remaining_usd)  || 0;

          // Parse the allocations table from body
          const tableRows = parseTable(parsed.content);
          agents = tableRows
            .filter(r => r.agent && r.agent !== '_unallocated_')
            .map(r => ({
              agent:     r.agent    || '',
              role:      r.role     || '',
              budget:    parseCurrency(r.monthly_budget),
              spent:     parseCurrency(r.spent),
              remaining: parseCurrency(r.remaining),
              model:     r.model    || '',
            }));
        } catch (_e) { /* keep defaults */ }
      }

      // --- Recent transactions from spending log ---
      let recentTransactions = [];
      const logPath = path.join(orgDir, 'budgets', 'spending-log.md');
      if (fs.existsSync(logPath)) {
        try {
          const raw  = fs.readFileSync(logPath, 'utf-8');
          const rows = parseTable(raw);
          // Last 20 transactions, newest first
          recentTransactions = rows.slice(-20).reverse().map(r => ({
            timestamp:    r.timestamp     || '',
            agent:        r.agent         || '',
            action:       r.action        || '',
            cost:         parseCurrency(r['cost__usd_'] || r.cost || r['cost_(usd)'] || 0),
            runningTotal: parseCurrency(r.running_total || 0),
          }));
        } catch (_e) { /* keep empty */ }
      }

      res.json({ currency, total, allocated, spent, remaining, agents, recentTransactions });
    } catch (err) {
      next(err);
    }
  });
};
