/**
 * GET /api/agents
 * Reads all org/agents/{name}/IDENTITY.md files and returns parsed frontmatter.
 */

const fs     = require('fs');
const path   = require('path');
const matter = require('gray-matter');

module.exports = function (router, orgDir) {
  router.get('/agents', (_req, res, next) => {
    try {
      const agentsDir = path.join(orgDir, 'agents');

      if (!fs.existsSync(agentsDir)) {
        return res.json([]);
      }

      const entries = fs.readdirSync(agentsDir, { withFileTypes: true })
        .filter(d => d.isDirectory());

      const agents = [];

      for (const entry of entries) {
        const idPath = path.join(agentsDir, entry.name, 'IDENTITY.md');
        if (!fs.existsSync(idPath)) continue;

        try {
          const raw    = fs.readFileSync(idPath, 'utf-8');
          const parsed = matter(raw);
          const data   = parsed.data || {};

          agents.push({
            name:       data.name       || entry.name,
            title:      data.title      || '',
            status:     data.status     || 'unknown',
            model:      data.model      || '',
            department: data.department || '',
            emoji:      data.emoji      || '',
            reports_to: data.reports_to || '',
            created:    data.created    || '',
            skills:     data.skills     || [],
            tools:      data.tools      || [],
          });
        } catch (_e) {
          // Skip agents with unparseable IDENTITY files
        }
      }

      res.json(agents);
    } catch (err) {
      next(err);
    }
  });
};
