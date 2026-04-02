/**
 * Webhook Receiver API — receives events from external services
 *
 * POST /api/webhooks/:service/:event
 *
 * When an external service (Shopify, Stripe, GitHub, etc.) sends a webhook,
 * this endpoint writes an event file to the target agent's inbox. The existing
 * chokidar file watcher automatically detects the new file and broadcasts
 * a WebSocket event to the dashboard.
 *
 * The target agent is determined by looking up the service in the connector
 * registry (org/connectors/registry.md) or falling back to the CEO.
 */

const fs   = require('fs');
const path = require('path');
const crypto = require('crypto');

module.exports = function (router, orgDir) {

  /**
   * Look up which agent handles events from a given service.
   * Reads org/connectors/registry.md for a target_agent field.
   * Falls back to 'ceo' if not found.
   */
  function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function lookupAgentForService(service) {
    const registryPath = path.join(orgDir, 'connectors', 'registry.md');
    if (!fs.existsSync(registryPath)) return 'ceo';

    try {
      const content = fs.readFileSync(registryPath, 'utf-8');
      // Find the section for this service (escape service name to prevent regex injection)
      const serviceRegex = new RegExp(`## ${escapeRegex(service)}[\\s\\S]*?(?=## |$)`, 'i');
      const match = content.match(serviceRegex);
      if (!match) return 'ceo';

      // Extract target_agent field (handles **bold** markdown formatting)
      const agentMatch = match[0].match(/Target Agent:\*{0,2}\s*(\w[\w-]*)/i);
      if (agentMatch) return agentMatch[1];
    } catch (err) {
      // Registry unreadable — fall back
    }
    return 'ceo';
  }

  /**
   * Generate idempotency key from event data
   */
  function makeIdempotencyKey(service, event, body) {
    const uniqueData = `${service}-${event}-${JSON.stringify(body)}`;
    return `${service}-${event}-${crypto.createHash('md5').update(uniqueData).digest('hex').slice(0, 12)}`;
  }

  /**
   * Check if an event with this idempotency key already exists in the inbox
   */
  function isDuplicate(inboxDir, idempotencyKey) {
    if (!fs.existsSync(inboxDir)) return false;
    const files = fs.readdirSync(inboxDir).filter(f => f.endsWith('.md'));
    for (const file of files) {
      try {
        const content = fs.readFileSync(path.join(inboxDir, file), 'utf-8');
        if (content.includes(`idempotency_key: ${idempotencyKey}`)) return true;
      } catch (err) {
        // Skip unreadable files
      }
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // POST /api/webhooks/:service/:event — receive webhook from external service
  // -------------------------------------------------------------------------
  router.post('/webhooks/:service/:event', (req, res) => {
    const { service, event } = req.params;
    const payload = req.body || {};
    const timestamp = new Date().toISOString();
    const urgency = payload.urgency || 'normal';

    // Determine target agent
    const targetAgent = lookupAgentForService(service);

    // Generate idempotency key
    const idempotencyKey = makeIdempotencyKey(service, event, payload);

    // Check target agent inbox exists
    const inboxDir = path.join(orgDir, 'agents', targetAgent, 'inbox');
    if (!fs.existsSync(inboxDir)) {
      fs.mkdirSync(inboxDir, { recursive: true });
    }

    // Deduplicate
    if (isDuplicate(inboxDir, idempotencyKey)) {
      return res.status(200).json({
        received: true,
        duplicate: true,
        idempotency_key: idempotencyKey,
        message: 'Event already processed'
      });
    }

    // Write event file to agent's inbox
    const filename = `webhook-${service}-${event}-${Date.now()}.md`;
    const filePath = path.join(inboxDir, filename);

    const content = [
      '---',
      'type: external-event',
      `source: ${service}`,
      `event: ${event}`,
      `timestamp: ${timestamp}`,
      `urgency: ${urgency}`,
      `idempotency_key: ${idempotencyKey}`,
      'read: false',
      '---',
      '',
      `## Webhook Event: ${service}/${event}`,
      '',
      '```json',
      JSON.stringify(payload, null, 2),
      '```',
      ''
    ].join('\n');

    try {
      fs.writeFileSync(filePath, content);
    } catch (err) {
      console.error(`[WEBHOOK] Failed to write event file: ${err.message}`);
      return res.status(500).json({ error: 'Failed to write event file' });
    }

    console.log(`[WEBHOOK] ${service}/${event} -> ${targetAgent} (${filename})`);

    res.status(200).json({
      received: true,
      agent: targetAgent,
      file: filename,
      idempotency_key: idempotencyKey,
      urgency
    });
  });

  // -------------------------------------------------------------------------
  // GET /api/webhooks — list registered webhook endpoints (from connector registry)
  // -------------------------------------------------------------------------
  router.get('/webhooks', (req, res) => {
    const registryPath = path.join(orgDir, 'connectors', 'registry.md');
    if (!fs.existsSync(registryPath)) {
      return res.json({ endpoints: [], message: 'No connector registry found' });
    }

    try {
      const content = fs.readFileSync(registryPath, 'utf-8');
      // Extract service sections
      const sections = content.split(/^## /m).filter(s => s.trim() && !s.startsWith('#'));
      const endpoints = sections.map(section => {
        const lines = section.split('\n');
        const name = lines[0].trim();
        const statusMatch = section.match(/Status:\*{0,2}\s*(\w[\w-]*)/i);
        const agentMatch = section.match(/Target Agent:\*{0,2}\s*(\w[\w-]*)/i);
        return {
          service: name,
          status: statusMatch ? statusMatch[1] : 'unknown',
          target_agent: agentMatch ? agentMatch[1] : 'ceo',
          webhook_url: `/api/webhooks/${name.toLowerCase()}/{event}`
        };
      });
      res.json({ endpoints });
    } catch (err) {
      res.status(500).json({ error: 'Failed to read connector registry' });
    }
  });
};
