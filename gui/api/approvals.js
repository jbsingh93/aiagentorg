/**
 * GET  /api/approvals         — list pending approvals
 * POST /api/approvals/:id/approve
 * POST /api/approvals/:id/reject   { reason: "..." }
 *
 * Reads/writes org/board/approvals/*.md and moves decided files to
 * org/board/decisions/.
 */

const fs     = require('fs');
const path   = require('path');
const matter = require('gray-matter');

module.exports = function (router, orgDir) {
  const approvalsDir = path.join(orgDir, 'board', 'approvals');
  const decisionsDir = path.join(orgDir, 'board', 'decisions');

  // -----------------------------------------------------------------------
  // GET /api/approvals — list pending
  // -----------------------------------------------------------------------
  router.get('/approvals', (_req, res, next) => {
    try {
      if (!fs.existsSync(approvalsDir)) return res.json([]);

      const files = fs.readdirSync(approvalsDir).filter(f => f.endsWith('.md'));
      const list  = [];

      for (const file of files) {
        try {
          const raw    = fs.readFileSync(path.join(approvalsDir, file), 'utf-8');
          const parsed = matter(raw);
          const d      = parsed.data || {};

          if (d.status && d.status !== 'pending') continue; // Only show pending

          list.push({
            id:         d.id          || file.replace('.md', ''),
            type:       d.type        || 'unknown',
            proposedBy: d.proposed_by || '',
            date:       d.proposed_date || '',
            status:     d.status      || 'pending',
            summary:    (parsed.content || '').slice(0, 300),
            _file:      file,
          });
        } catch (_e) { /* skip */ }
      }

      res.json(list);
    } catch (err) {
      next(err);
    }
  });

  // -----------------------------------------------------------------------
  // Helper: find the approval file by id, update frontmatter, move to decisions
  // -----------------------------------------------------------------------
  function decideApproval(id, status, extra) {
    if (!fs.existsSync(approvalsDir)) {
      return { error: 'Approvals directory not found', code: 404 };
    }

    const files    = fs.readdirSync(approvalsDir).filter(f => f.endsWith('.md'));
    let targetFile = null;

    for (const file of files) {
      if (file.replace('.md', '') === id) { targetFile = file; break; }
      // Also try matching by frontmatter id field
      try {
        const raw = fs.readFileSync(path.join(approvalsDir, file), 'utf-8');
        const d   = matter(raw).data || {};
        if (d.id === id) { targetFile = file; break; }
      } catch (_e) { /* skip */ }
    }

    if (!targetFile) {
      return { error: `Approval "${id}" not found`, code: 404 };
    }

    const filePath = path.join(approvalsDir, targetFile);
    const raw      = fs.readFileSync(filePath, 'utf-8');
    const parsed   = matter(raw);

    // Update frontmatter
    parsed.data.status        = status;
    parsed.data.decided_by    = 'board';
    parsed.data.decided_date  = new Date().toISOString();
    if (extra.reason) {
      parsed.data.decision_reason = extra.reason;
    }

    // Rebuild the file
    const updated = matter.stringify(parsed.content, parsed.data);

    // Write back (in case move fails, data is at least saved)
    fs.writeFileSync(filePath, updated, 'utf-8');

    // Move to decisions/
    if (!fs.existsSync(decisionsDir)) {
      fs.mkdirSync(decisionsDir, { recursive: true });
    }
    const destPath = path.join(decisionsDir, targetFile);
    fs.renameSync(filePath, destPath);

    return { ok: true, id, status };
  }

  // -----------------------------------------------------------------------
  // POST /api/approvals/:id/approve
  // -----------------------------------------------------------------------
  router.post('/approvals/:id/approve', (req, res, next) => {
    try {
      const result = decideApproval(req.params.id, 'approved', {});
      if (result.error) return res.status(result.code).json(result);
      res.json(result);
    } catch (err) {
      next(err);
    }
  });

  // -----------------------------------------------------------------------
  // POST /api/approvals/:id/reject
  // -----------------------------------------------------------------------
  router.post('/approvals/:id/reject', (req, res, next) => {
    try {
      const reason = (req.body && req.body.reason) || '';
      const result = decideApproval(req.params.id, 'rejected', { reason });
      if (result.error) return res.status(result.code).json(result);
      res.json(result);
    } catch (err) {
      next(err);
    }
  });
};
