import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import express from 'express';
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import os from 'os';

describe('Webhook API', () => {
  let app, tmpDir;

  beforeAll(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'orgagent-webhook-test-'));

    // Create minimal org structure
    fs.mkdirSync(path.join(tmpDir, 'agents', 'ceo', 'inbox'), { recursive: true });
    fs.mkdirSync(path.join(tmpDir, 'agents', 'sales-mgr', 'inbox'), { recursive: true });
    fs.mkdirSync(path.join(tmpDir, 'connectors'), { recursive: true });

    // Create connector registry with sales-mgr as shopify handler
    fs.writeFileSync(path.join(tmpDir, 'connectors', 'registry.md'), `# Connector Registry

## shopify

- **Status:** active
- **Target Agent:** sales-mgr
- **Events:** order-created, order-updated
`);

    app = express();
    app.use(express.json());
    const router = express.Router();
    // Use require for CJS module
    const webhooksModule = require('../../../gui/api/webhooks.js');
    webhooksModule(router, tmpDir);
    app.use('/api', router);
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('POST /api/webhooks/:service/:event creates inbox file', async () => {
    const res = await request(app)
      .post('/api/webhooks/stripe/payment-completed')
      .send({ amount: 100, currency: 'USD' });

    expect(res.status).toBe(200);
    expect(res.body.received).toBe(true);
    expect(res.body.agent).toBe('ceo'); // stripe not in registry, falls back to ceo
    expect(res.body.idempotency_key).toBeDefined();

    // Verify file was created in CEO inbox
    const inboxFiles = fs.readdirSync(path.join(tmpDir, 'agents', 'ceo', 'inbox'));
    const webhookFile = inboxFiles.find(f => f.includes('stripe-payment-completed'));
    expect(webhookFile).toBeDefined();

    // Verify file content
    const content = fs.readFileSync(path.join(tmpDir, 'agents', 'ceo', 'inbox', webhookFile), 'utf-8');
    expect(content).toContain('source: stripe');
    expect(content).toContain('event: payment-completed');
    expect(content).toContain('read: false');
    expect(content).toContain('"amount": 100');
  });

  it('routes to correct agent from connector registry', async () => {
    const res = await request(app)
      .post('/api/webhooks/shopify/order-created')
      .send({ order_id: 1042 });

    expect(res.status).toBe(200);
    expect(res.body.agent).toBe('sales-mgr');

    // Verify file in sales-mgr inbox
    const inboxFiles = fs.readdirSync(path.join(tmpDir, 'agents', 'sales-mgr', 'inbox'));
    expect(inboxFiles.some(f => f.includes('shopify-order-created'))).toBe(true);
  });

  it('deduplicates identical events', async () => {
    const payload = { order_id: 9999, dedup_test: true };

    const res1 = await request(app)
      .post('/api/webhooks/test-service/test-event')
      .send(payload);
    expect(res1.body.duplicate).toBeFalsy();

    const res2 = await request(app)
      .post('/api/webhooks/test-service/test-event')
      .send(payload);
    expect(res2.status).toBe(200);
    expect(res2.body.duplicate).toBe(true);
  });

  it('GET /api/webhooks lists registered endpoints', async () => {
    const res = await request(app).get('/api/webhooks');
    expect(res.status).toBe(200);
    expect(res.body.endpoints).toBeDefined();
    expect(res.body.endpoints.length).toBeGreaterThan(0);
    expect(res.body.endpoints[0].service).toBe('shopify');
    expect(res.body.endpoints[0].target_agent).toBe('sales-mgr');
  });

  it('sets urgency from payload', async () => {
    const res = await request(app)
      .post('/api/webhooks/alerts/critical-error')
      .send({ urgency: 'high', message: 'Server down' });

    expect(res.body.urgency).toBe('high');
  });
});
