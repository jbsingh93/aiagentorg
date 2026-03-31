/**
 * GET /api/agent/:name
 * Returns the full workspace for a single agent:
 *   soul, identity, currentState, tasks, reports
 */

const fs     = require('fs');
const path   = require('path');
const matter = require('gray-matter');
const { marked } = require('marked');

module.exports = function (router, orgDir) {
  router.get('/agent/:name', (req, res, next) => {
    try {
      const name     = req.params.name;
      const agentDir = path.join(orgDir, 'agents', name);

      if (!fs.existsSync(agentDir)) {
        return res.status(404).json({ error: `Agent "${name}" not found` });
      }

      // --- Helper: read + parse a markdown file (frontmatter + html body) ---
      function readMd(filePath) {
        if (!fs.existsSync(filePath)) return null;
        const raw    = fs.readFileSync(filePath, 'utf-8');
        const parsed = matter(raw);
        return {
          data: parsed.data,
          body: parsed.content,
          html: marked(parsed.content),
        };
      }

      // --- Core files ---
      const soul         = readMd(path.join(agentDir, 'SOUL.md'));
      const identity     = readMd(path.join(agentDir, 'IDENTITY.md'));
      const currentState = readMd(path.join(agentDir, 'activity', 'current-state.md'));

      // --- Tasks (backlog + active + done) ---
      const tasks = [];
      for (const status of ['backlog', 'active', 'done']) {
        const dir = path.join(agentDir, 'tasks', status);
        if (!fs.existsSync(dir)) continue;
        const files = fs.readdirSync(dir).filter(f => f.endsWith('.md'));
        for (const file of files) {
          try {
            const raw    = fs.readFileSync(path.join(dir, file), 'utf-8');
            const parsed = matter(raw);
            tasks.push({ ...parsed.data, _status: status, _file: file });
          } catch (_e) { /* skip */ }
        }
      }

      // --- Reports ---
      const reports    = [];
      const reportsDir = path.join(agentDir, 'reports');
      if (fs.existsSync(reportsDir)) {
        const files = fs.readdirSync(reportsDir).filter(f => f.endsWith('.md'));
        for (const file of files) {
          try {
            const raw    = fs.readFileSync(path.join(reportsDir, file), 'utf-8');
            const parsed = matter(raw);
            reports.push({
              file,
              data: parsed.data,
              html: marked(parsed.content),
            });
          } catch (_e) { /* skip */ }
        }
      }

      res.json({ soul, identity, currentState, tasks, reports });
    } catch (err) {
      next(err);
    }
  });
};
