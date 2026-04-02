/**
 * Chat API — Bridge between the GUI and Claude Code CLI.
 * Spawns `claude -p` processes, pipes messages, returns responses.
 * Supports multi-turn conversations via --resume.
 */

const { execFile, exec } = require('child_process');
const path = require('path');

module.exports = function (router, orgDir) {
  const projectDir = path.resolve(orgDir, '..');
  let currentSession = null;
  let currentProc = null;  // Track the running claude process

  // POST /api/chat — Send a message to Claude Code and get the response
  router.post('/chat', (req, res) => {
    const { message } = req.body;
    if (!message || !message.trim()) {
      return res.status(400).json({ error: 'No message provided' });
    }

    // Build the full command as a string (more reliable on Windows)
    let cmd = `claude -p ${JSON.stringify(message.trim())} --output-format json`;

    // Resume previous session for multi-turn
    if (currentSession) {
      cmd += ` --resume ${JSON.stringify(currentSession)}`;
    }

    console.log(`[Chat] Executing: ${cmd.substring(0, 100)}...`);
    console.log(`[Chat] CWD: ${projectDir}`);

    const options = {
      cwd: projectDir,
      env: { ...process.env, ORGAGENT_CURRENT_AGENT: 'board' },
      shell: true,
      timeout: 300000, // 5 minute timeout
      maxBuffer: 10 * 1024 * 1024 // 10MB buffer
    };

    currentProc = exec(cmd, options, (error, stdout, stderr) => {
      currentProc = null;
      console.log(`[Chat] Exit code: ${error ? error.code : 0}`);
      console.log(`[Chat] Stdout length: ${stdout ? stdout.length : 0}`);
      console.log(`[Chat] Stderr length: ${stderr ? stderr.length : 0}`);

      if (stderr) {
        console.log(`[Chat] Stderr preview: ${stderr.substring(0, 200)}`);
      }

      // Filter out known CLI warnings from stderr (hook warnings, TTY detection, etc.)
      const filteredStderr = (stderr || '').split('\n')
        .filter(line => !line.match(/Warning.*processing without|Warning.*redirect stdin|Warning.*detected a tty|Warning.*data-access|Warning.*wait longer/i))
        .join('\n').trim();

      // Try to parse JSON from stdout first (even if there was an error exit code)
      if (stdout) {
        const jsonMatch = stdout.match(/\{[\s\S]*"session_id"[\s\S]*\}/);
        if (jsonMatch) {
          try {
            const result = JSON.parse(jsonMatch[0]);
            currentSession = result.session_id || currentSession;
            console.log(`[Chat] Session: ${currentSession}`);
            console.log(`[Chat] Result length: ${(result.result || '').length}`);

            return res.json({
              role: 'assistant',
              content: result.result || '(Claude completed but returned no text)',
              sessionId: result.session_id || currentSession,
              cost: result.cost_usd || 0,
              duration: result.duration_ms || 0,
              turns: result.num_turns || 1,
              isError: result.is_error || false
            });
          } catch (parseErr) {
            console.error(`[Chat] JSON parse error:`, parseErr.message);
          }
        }
      }

      // If claude exited with error and no parseable output
      if (error) {
        console.error(`[Chat] Error:`, error.message);

        // Check for timeout
        if (error.killed || error.signal === 'SIGTERM') {
          return res.json({
            role: 'assistant',
            content: 'Claude is still processing your request. The response is taking longer than expected. Check the Live Feed tab for progress, or try again in a moment.',
            sessionId: currentSession,
            cost: 0,
            isError: false  // Not a real error — just slow
          });
        }

        // Provide user-friendly error (without raw CLI warnings)
        const userMessage = filteredStderr
          ? `Claude encountered an issue:\n\n${filteredStderr}`
          : `Claude encountered an issue. Check the server logs for details.`;

        return res.json({
          role: 'assistant',
          content: userMessage,
          sessionId: currentSession,
          cost: 0,
          isError: true
        });
      }

      // Fallback: return raw stdout (non-JSON response)
      const text = (stdout || '').trim() || 'No response from Claude. Check server logs for details.';
      res.json({
        role: 'assistant',
        content: text,
        sessionId: currentSession,
        cost: 0,
        isError: !stdout
      });
    });
  });

  // POST /api/chat/abort — Kill the running claude process
  router.post('/chat/abort', (_req, res) => {
    if (currentProc) {
      try {
        // On Windows, kill the process tree
        if (process.platform === 'win32') {
          exec(`taskkill /pid ${currentProc.pid} /T /F`, { shell: true });
        } else {
          currentProc.kill('SIGTERM');
        }
        currentProc = null;
        console.log('[Chat] Process aborted by user');
        res.json({ ok: true, message: 'Claude process stopped.' });
      } catch (err) {
        res.json({ ok: false, error: err.message });
      }
    } else {
      res.json({ ok: true, message: 'No process running.' });
    }
  });

  // POST /api/chat/reset — Start a fresh conversation
  router.post('/chat/reset', (_req, res) => {
    currentSession = null;
    res.json({ ok: true, message: 'Chat session reset.' });
  });

  // GET /api/chat/session — Get current session info
  router.get('/chat/session', (_req, res) => {
    res.json({ sessionId: currentSession, hasSession: !!currentSession });
  });

  // GET /api/chat/test — Test if claude CLI is accessible
  router.get('/chat/test', (_req, res) => {
    exec('claude --version', { shell: true, timeout: 10000 }, (error, stdout, stderr) => {
      if (error) {
        return res.json({
          ok: false,
          error: error.message,
          stderr: stderr,
          hint: 'Claude Code CLI not found. Install with: npm install -g @anthropic-ai/claude-code'
        });
      }
      res.json({ ok: true, version: stdout.trim() });
    });
  });
};
