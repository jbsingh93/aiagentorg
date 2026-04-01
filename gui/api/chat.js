/**
 * Chat API — Bridge between the GUI and Claude Code CLI.
 * Spawns `claude -p` processes, pipes messages, returns responses.
 * Supports multi-turn conversations via --resume.
 */

const { spawn } = require('child_process');
const path = require('path');

module.exports = function (router, orgDir) {
  const projectDir = path.resolve(orgDir, '..');
  let currentSession = null;

  // POST /api/chat — Send a message to Claude Code and get the response
  router.post('/chat', (req, res) => {
    const { message } = req.body;
    if (!message || !message.trim()) {
      return res.status(400).json({ error: 'No message provided' });
    }

    // Build claude CLI args
    const args = ['-p', message.trim(), '--output-format', 'json'];

    // Resume previous session for multi-turn (onboarding etc.)
    if (currentSession) {
      args.push('--resume', currentSession);
    }

    const proc = spawn('claude', args, {
      cwd: projectDir,
      env: { ...process.env, ORGAGENT_CURRENT_AGENT: 'board' },
      shell: true
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
    proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });

    proc.on('error', (err) => {
      res.status(500).json({
        error: 'Failed to start Claude Code. Is it installed? Run: npm install -g @anthropic-ai/claude-code',
        details: err.message
      });
    });

    proc.on('close', (code) => {
      try {
        const result = JSON.parse(stdout);
        currentSession = result.session_id || currentSession;
        res.json({
          role: 'assistant',
          content: result.result || '',
          sessionId: result.session_id || currentSession,
          cost: result.cost_usd || 0,
          duration: result.duration_ms || 0,
          turns: result.num_turns || 1,
          isError: result.is_error || false
        });
      } catch (_) {
        // Non-JSON output — return raw text
        const text = stdout.trim() || stderr.trim() || 'No response from Claude.';
        res.json({
          role: 'assistant',
          content: text,
          sessionId: currentSession,
          cost: 0,
          isError: code !== 0
        });
      }
    });

    // If client disconnects, kill the claude process
    req.on('close', () => {
      if (!proc.killed) proc.kill();
    });
  });

  // POST /api/chat/reset — Start a fresh conversation
  router.post('/chat/reset', (_req, res) => {
    currentSession = null;
    res.json({ ok: true, message: 'Chat session reset. Next message starts a new conversation.' });
  });

  // GET /api/chat/session — Get current session info
  router.get('/chat/session', (_req, res) => {
    res.json({ sessionId: currentSession, hasSession: !!currentSession });
  });
};
