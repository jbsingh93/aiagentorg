/**
 * GET /api/orgchart
 * Parses org/orgchart.md indented list into a JSON tree.
 *
 * Format per 10-FILE-FORMAT-SPECIFICATIONS.md — Format 3:
 *   - 2-space indentation = depth
 *   - **Bold** = display name
 *   - (status, @id) = metadata in parentheses
 *   - Text after " — " (em dash) = title / role description
 */

const fs   = require('fs');
const path = require('path');

module.exports = function (router, orgDir) {
  router.get('/orgchart', (_req, res, next) => {
    try {
      const filePath = path.join(orgDir, 'orgchart.md');

      if (!fs.existsSync(filePath)) {
        return res.json({ tree: null });
      }

      const raw   = fs.readFileSync(filePath, 'utf-8');
      const lines = raw.split('\n').filter(l => l.trimStart().startsWith('- '));

      if (lines.length === 0) {
        return res.json({ tree: null });
      }

      // Parse each line into a flat node with a depth value.
      const nodes = lines.map(line => {
        const leadingSpaces = line.match(/^(\s*)/)[1].length;
        const depth         = Math.floor(leadingSpaces / 2);

        // Extract bold name: **Name**
        const nameMatch = line.match(/\*\*(.+?)\*\*/);
        const name      = nameMatch ? nameMatch[1] : line.trim().replace(/^-\s*/, '');

        // Extract status and agentId from parentheses — e.g. (active, @ceo) or (human)
        const parenMatch = line.match(/\(([^)]+)\)/);
        let status  = 'unknown';
        let agentId = null;
        if (parenMatch) {
          const inner = parenMatch[1];
          const parts = inner.split(',').map(s => s.trim());
          status = parts[0] || 'unknown';
          const idPart = parts.find(p => p.startsWith('@'));
          if (idPart) agentId = idPart.slice(1);
        }

        // Extract title after em-dash " — "
        const dashMatch = line.match(/\s—\s(.+)$/);
        const title     = dashMatch ? dashMatch[1].trim() : '';

        return { depth, name, status, agentId, title, children: [] };
      });

      // Build tree from flat list using depth tracking.
      const root  = nodes[0];
      const stack = [root]; // stack[i] = current node at depth i

      for (let i = 1; i < nodes.length; i++) {
        const node = nodes[i];

        // Find the parent: the most recent node whose depth is exactly node.depth - 1
        while (stack.length > node.depth) stack.pop();

        const parent = stack[stack.length - 1];
        if (parent) parent.children.push(node);

        stack.push(node);
      }

      res.json({ tree: root });
    } catch (err) {
      next(err);
    }
  });
};
