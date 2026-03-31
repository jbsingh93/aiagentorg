/**
 * GET /api/audit
 * Reads org/board/audit-log.md, parses the markdown table rows.
 * Supports: ?page=1&limit=50
 */

const fs   = require('fs');
const path = require('path');

module.exports = function (router, orgDir) {
  router.get('/audit', (req, res, next) => {
    try {
      const filePath = path.join(orgDir, 'board', 'audit-log.md');

      if (!fs.existsSync(filePath)) {
        return res.json({ entries: [], total: 0, page: 1 });
      }

      const raw   = fs.readFileSync(filePath, 'utf-8');
      const lines = raw.split('\n')
        .map(l => l.trim())
        .filter(l => l.startsWith('|'));

      // Need at least header + separator + one data row
      if (lines.length < 3) {
        return res.json({ entries: [], total: 0, page: 1 });
      }

      // Parse data rows (skip header [0] and separator [1])
      const entries = [];
      for (let i = 2; i < lines.length; i++) {
        const cells = lines[i].split('|').map(c => c.trim()).filter(Boolean);
        if (cells.length < 5) continue;

        entries.push({
          timestamp: cells[0],
          agent:     cells[1],
          action:    cells[2],
          target:    cells[3],
          details:   cells[4],
        });
      }

      // Newest first
      entries.reverse();

      // Pagination
      const page  = Math.max(1, parseInt(req.query.page,  10) || 1);
      const limit = Math.min(200, Math.max(1, parseInt(req.query.limit, 10) || 50));
      const total = entries.length;
      const start = (page - 1) * limit;
      const paged = entries.slice(start, start + limit);

      res.json({ entries: paged, total, page });
    } catch (err) {
      next(err);
    }
  });
};
