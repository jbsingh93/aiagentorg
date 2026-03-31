/**
 * GET /api/messages
 * Reads org/threads/ (**\/*.md) and parses thread frontmatter + message blocks.
 * Message blocks are delimited by: ### [MSG-YYYYMMDD-HHMMSS-sender]
 *
 * Supports: ?department=marketing, ?thread=id
 */

const fs     = require('fs');
const path   = require('path');
const matter = require('gray-matter');

// Regex to split on message headings inside a thread file.
// Format: ### [MSG-20260331-100500-ceo] 2026-03-31T10:05:00 — Emoji Name -> Emoji Name [type]
const MSG_HEADING_RE = /^###\s+\[MSG-([^\]]+)\]\s+(\S+)\s+—\s+(.+)$/;

function parseMessages(content) {
  const lines    = content.split('\n');
  const messages = [];
  let current    = null;

  for (const line of lines) {
    const m = line.match(MSG_HEADING_RE);
    if (m) {
      // Save previous message
      if (current) {
        current.body = current.body.join('\n').trim();
        messages.push(current);
      }

      const msgId     = 'MSG-' + m[1];
      const timestamp = m[2];
      const routing   = m[3]; // "Emoji Sender -> Emoji Recipient [type]"

      // Parse routing: split on the arrow and extract type badge
      let from = '', to = '', type = 'message';
      const arrowSplit = routing.split(/\s*(?:→|->)\s*/);
      if (arrowSplit.length >= 2) {
        from = arrowSplit[0].trim();
        // The second part may end with [type]
        const typeBracket = arrowSplit[1].match(/\[(\w[\w-]*)\]\s*$/);
        if (typeBracket) {
          type = typeBracket[1];
          to   = arrowSplit[1].replace(/\[(\w[\w-]*)\]\s*$/, '').trim();
        } else {
          to = arrowSplit[1].trim();
        }
      }

      current = { msgId, timestamp, from, to, type, body: [] };
    } else if (current) {
      // Skip markdown horizontal rules that are just message separators
      if (line.trim() === '---') continue;
      current.body.push(line);
    }
  }

  // Don't forget the last message
  if (current) {
    current.body = current.body.join('\n').trim();
    messages.push(current);
  }

  return messages;
}

/** Recursively find all .md files under a directory. */
function findMdFiles(dir) {
  const results = [];
  if (!fs.existsSync(dir)) return results;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      results.push(...findMdFiles(full));
    } else if (e.name.endsWith('.md') && e.name !== 'index.md') {
      results.push(full);
    }
  }
  return results;
}

module.exports = function (router, orgDir) {
  router.get('/messages', (req, res, next) => {
    try {
      const threadsDir = path.join(orgDir, 'threads');
      if (!fs.existsSync(threadsDir)) return res.json([]);

      const filterDept   = req.query.department || null;
      const filterThread = req.query.thread     || null;

      const mdFiles = findMdFiles(threadsDir);
      const threads = [];

      for (const filePath of mdFiles) {
        try {
          const raw    = fs.readFileSync(filePath, 'utf-8');
          const parsed = matter(raw);
          const data   = parsed.data || {};

          const threadId   = data.thread_id || path.basename(filePath, '.md');
          const department = data.department || path.basename(path.dirname(filePath));

          if (filterDept && department !== filterDept) continue;
          if (filterThread && threadId !== filterThread) continue;

          const messages = parseMessages(parsed.content);

          threads.push({
            threadId,
            topic:        data.topic        || threadId,
            department,
            participants: data.participants || [],
            status:       data.status       || 'active',
            created:      data.created      || '',
            lastActivity: data.last_activity || '',
            messageCount: data.message_count || messages.length,
            messages,
          });
        } catch (_e) { /* skip unparseable */ }
      }

      // Sort newest thread first
      threads.sort((a, b) => {
        const da = a.lastActivity || a.created || '';
        const db = b.lastActivity || b.created || '';
        return db.localeCompare(da);
      });

      res.json(threads);
    } catch (err) {
      next(err);
    }
  });
};
