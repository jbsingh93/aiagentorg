/**
 * GET /api/tasks
 * Reads all task files across every agent workspace.
 * Supports query filters: ?agent=name, ?status=active, ?initiative=slug
 */

const fs     = require('fs');
const path   = require('path');
const matter = require('gray-matter');

module.exports = function (router, orgDir) {
  router.get('/tasks', (req, res, next) => {
    try {
      const agentsDir = path.join(orgDir, 'agents');
      if (!fs.existsSync(agentsDir)) return res.json([]);

      const filterAgent      = req.query.agent      || null;
      const filterStatus     = req.query.status     || null;
      const filterInitiative = req.query.initiative || null;

      const tasks   = [];
      const agents  = fs.readdirSync(agentsDir, { withFileTypes: true })
        .filter(d => d.isDirectory());

      for (const agentEntry of agents) {
        if (filterAgent && agentEntry.name !== filterAgent) continue;

        const tasksRoot = path.join(agentsDir, agentEntry.name, 'tasks');
        if (!fs.existsSync(tasksRoot)) continue;

        for (const status of ['backlog', 'active', 'done']) {
          if (filterStatus && filterStatus !== status) continue;

          const dir = path.join(tasksRoot, status);
          if (!fs.existsSync(dir)) continue;

          const files = fs.readdirSync(dir).filter(f => f.endsWith('.md'));
          for (const file of files) {
            try {
              const raw    = fs.readFileSync(path.join(dir, file), 'utf-8');
              const parsed = matter(raw);
              const data   = parsed.data || {};

              if (filterInitiative && data.initiative !== filterInitiative) continue;

              tasks.push({
                id:          data.id          || file.replace('.md', ''),
                title:       data.title       || file,
                priority:    data.priority    || 'medium',
                status:      data.status      || status,
                assignedTo:  data.assigned_to || agentEntry.name,
                assignedBy:  data.assigned_by || '',
                initiative:  data.initiative  || '',
                created:     data.created     || '',
                started:     data.started     || '',
                completed:   data.completed   || '',
                deadline:    data.deadline    || '',
                _dir:        status,
                _agent:      agentEntry.name,
              });
            } catch (_e) { /* skip unparseable files */ }
          }
        }
      }

      // Sort: active first, then backlog, then done.  Within each group sort by priority.
      const priorityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
      const statusOrder   = { active: 0, backlog: 1, done: 2, blocked: 1 };
      tasks.sort((a, b) => {
        const sd = (statusOrder[a.status] ?? 9) - (statusOrder[b.status] ?? 9);
        if (sd !== 0) return sd;
        return (priorityOrder[a.priority] ?? 9) - (priorityOrder[b.priority] ?? 9);
      });

      res.json(tasks);
    } catch (err) {
      next(err);
    }
  });
};
